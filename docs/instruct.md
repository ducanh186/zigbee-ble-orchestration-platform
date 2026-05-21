# Runbook Vận hành — IoT Smart Building Platform

Đây là tài liệu thực hành duy nhất để bring-up, vận hành và debug toàn bộ repo
từ đầu đến cuối. Nội dung được tham chiếu trực tiếp từ mã nguồn và artifact có
thật trong cây repo. Ở những chỗ repo chưa tự động hóa, tài liệu nói rõ điều đó.

> Quy ước:
>
> - `REPO` = đường dẫn gốc repo trên máy Ubuntu của bạn (trong setup của dự án
>   này là `/home/phu/Repo/zigbee-ble-orchestration-platform`).
> - *verify in local environment* = cần tự kiểm tra lại trong môi trường của bạn
>   trước khi tin tưởng.
> - *current repo gap / manual step* = repo chưa tự động hóa phần này, phải
>   thao tác tay.

---

## A. Tổng quan dự án

### Đây là gì

Một stack IoT smart-building nhỏ, điều khiển đèn Zigbee và đọc công tắc /
cảm biến occupancy Zigbee từ cloud. Stack gồm:

```
Flutter App ──HTTP──▶ Cloud API (FastAPI :8000) ◄──▶ Mosquitto (:1883) ◄──MQTT──▶ Z3Gateway ◄──EZSP/ASH──▶ EFR32 NCP ◄──Zigbee──▶ End Devices
                          │                                                     │
                          ▼                                                     ├─ MQTT client (libmosquitto, direct)
                       PostgreSQL                                               ├─ Command lifecycle
                                                                                ├─ Device registry
                                                                                └─ Rule engine (local automation)
```

Nguồn chính xác của kiến trúc: [README.md](../README.md), [docs/plan.md](plan.md),
[docs/MQTT_CONTRACT.md](MQTT_CONTRACT.md), [docs/UART_FRAME_FORMAT.md](UART_FRAME_FORMAT.md).

### Phân chia trách nhiệm

| Tầng | Thành phần | Trách nhiệm |
|---|---|---|
| End devices | Z3Light, Z3Switch, Z3_Occupancy_Sensor (board EFR32MG12) | Zigbee cluster servers/clients. Z3Light expose On/Off + Level Control. Z3Switch bắn On/Off commands. |
| Coordinator/NCP | Một board EFR32MG12 flash bootloader + NCP firmware | Chỉ là Zigbee radio. Expose EZSP qua UART ở 115200 baud. **Không** chạy logic ứng dụng. |
| Gateway host | `gateway/Z3Gateway/Z3GatewayHost/` (binary trên Ubuntu) | Sở hữu UART (`/dev/ttyACM0`), form Zigbee network, nói MQTT, giữ command lifecycle, quan sát + forward state. |
| MQTT broker | `sb-mosquitto` (podman), dùng `mqtt/config/mosquitto.conf` | Auth, ACL, optional bridge đến prod broker qua `mqtt/config/conf.d/bridge.conf`. |
| Cloud backend | `cloud/app/` FastAPI + Postgres | REST API, dịch command, lưu device/state/command, sub/pub MQTT. |

### Phân loại các flow (ai là authority cho action nào)

| Flow | Authority | Cách thực hiện |
|---|---|---|
| **Bấm công tắc tại chỗ** (Z3Switch → đèn bật/tắt) | **Zigbee direct binding** (switch client → light server) | Commission ở tầng device. Gateway chỉ quan sát, không relay. Xem §G. |
| **Cloud command** (REST API → đèn bật/tắt) | Gateway (Z3Gateway) | Cloud publish `sb/v1/.../commands/{cmd_id}/request`, gateway gửi ZCL On/Off/Level đến đèn và reply qua `sb/v1/.../commands/{cmd_id}/reply`. |
| **Forward state/event lên trên** (light/switch/PIR → cloud) | Gateway | Gateway subscribe ZCL attribute reports + client-to-server commands, publish lên `sb/v1/.../devices/{type}/{id}/{reported|event}`. |
| **Occupancy → light automation** | *current repo gap* | Chưa có rule nào ở gateway hay cloud. Device type occupancy sensor chỉ có trong seed cloud; rule-engine skeleton được giữ ở gateway cho tương lai. |

### Luật thiết kế áp dụng trong gateway (tại thời điểm runbook này)

Gateway **KHÔNG** relay switch → light toggle theo mặc định. Zigbee direct
binding là authority duy nhất cho đường local đó. Rule engine vẫn được giữ
lại để thêm các automation không qua binding trong tương lai (ví dụ
occupancy → light) mà không phải đi lại dây điện. Hành vi được bật/tắt
bằng một env var — xem §G.

---

## B. Hardware / software prerequisites

### Hardware

| Item | Vai trò | Ghi chú |
|---|---|---|
| WSTK Mainboard BRD4001A × N | Đế cắm cho mỗi board radio EFR32 | Mỗi role một cái |
| Radio board EFR32MG12 BRD4162A (rev A02) × N | MCU cho mọi role | Part: `EFR32MG12P332F1024GL125` |
| Board Coordinator | Chạy `bootloader-uart-xmodem` + `ncp-uart-hw` | Cắm USB vào máy Ubuntu. Hiện ra ở `/dev/ttyACM0`. |
| Board Z3Light | Flash `artifact/Z3Light/Z3Light.s37` | Build matrix + flash how-to: [docs/FLASHING.md](FLASHING.md). |
| Board Z3Switch | Flash `artifact/Z3Switch/Z3Switch.s37` | Cùng tài liệu. |
| Board Z3_Occupancy_Sensor | Flash `artifact/Z3_Occupancy_Sensor/Z3_Occupancy_Sensor.s37` | Build matrix + flash how-to: [docs/FLASHING.md](FLASHING.md). |

USB connections bắt buộc:

- Coordinator WSTK → máy Ubuntu (đây là UART duy nhất mà gateway dùng)
- Các board khác → máy Ubuntu chỉ trong lúc flash (dùng Commander). Sau khi
  flash xong, có thể cấp nguồn bằng bất cứ USB 5 V nào.

### Máy Ubuntu

| Yêu cầu | Mục đích | Cách kiểm tra |
|---|---|---|
| Quyền truy cập `/dev/ttyACM0` | Gateway đọc UART NCP | `ls -la /dev/ttyACM0` — user phải thuộc group `dialout` (hoặc chạy với sudo) |
| `podman` + `podman-compose` (hoặc docker) | Chạy `sb-mosquitto` và `sb-postgres` | `podman --version` |
| `mosquitto-clients` | `mosquitto_sub` / `mosquitto_pub` để trace | `mosquitto_sub --help` |
| `libmosquitto-dev` | Gateway link với `-lmosquitto` | `dpkg -l libmosquitto-dev` *(verify in local environment)* |
| Python 3.11+ có venv | Cloud backend | `python3 --version`, `.venv/bin/python --version` |
| `gcc` / `make` (GNU ARM toolchain cho firmware, host gcc cho gateway binary) | Build binary gateway | `gcc --version` |

### Simplicity Studio / Gecko SDK / ARM toolchain

Theo [docs/FLASHING.md](FLASHING.md) (section "Artifacts"):

- Simplicity Studio v5 (SSv5, dựa trên Eclipse CDT).
- Gecko SDK 4.5.0 đã cài trong SSv5.
- GNU ARM 12.2.1.20221205 (đi kèm SSv5).
- Simplicity Commander (CLI `commander` — nằm dưới
  `developer/adapter_packs/commander/` của SSv5; cần thêm vào `PATH`).

Bản thân Z3Gateway **không phải** là firmware EFR32 — nó là binary host Linux
build bằng `gcc` thường. Đường build xem §E.

### Virtualenv Python của repo

*verify in local environment:* runtime kỳ vọng có `REPO/.venv/` đã cài
dependency của cloud:

```bash
cd "$REPO"
python3 -m venv .venv
source .venv/bin/activate
pip install -r cloud/requirements.txt
```

### `.env`

Cloud đọc `.env` ở gốc repo. Các key thực sự được đọc (xem
`cloud/app/config.py`) gồm tối thiểu:

```
SB_MQTT_HOST=localhost
SB_MQTT_PORT=1883
SB_MQTT_USERNAME=client
SB_MQTT_PASSWORD=client123
SB_TENANT_ID=hust
SB_SITE_ID=lab01
SB_GATEWAY_ID=gw-ubuntu-01
SB_API_HOST=0.0.0.0
SB_API_PORT=8000
```

Database URL và password Postgres cũng được cloud đọc — *verify in local
environment* dựa vào `cloud/app/config.py`.

---

## C. Đi qua cấu trúc repository

```
REPO/
├─ README.md              — tổng quan
├─ CLAUDE.md              — ghi chú cho AI assistant (lịch sử)
├─ .env                   — config runtime, cloud đọc
├─ artifact/              — file firmware .s37 đã build sẵn, sẵn sàng flash
│   ├─ bootloader-uart-xmodem/   — NCP bootloader
│   ├─ ncp-uart-hw/              — NCP Zigbee radio
│   ├─ Z3Light/                  — firmware đèn (kiểm tra có .s37 chưa)
│   └─ Z3Switch/                 — firmware công tắc (kiểm tra có .s37 chưa)
├─ end_devices/           — NGUỒN firmware; project SSv5
│   ├─ ncp-uart-hw-fresh/
│   ├─ Z3Light/
│   ├─ Z3Switch/
│   └─ Z3_Occupancy_Sensor/
├─ gateway/
│   └─ Z3Gateway/Z3GatewayHost/
│       ├─ app.c                 — entry point Z3Gateway framework
│       ├─ app/                  — code gateway custom
│       │   ├─ app_mqtt.c/h      — MQTT client (libmosquitto)
│       │   ├─ cmd_handler.c/h   — parser command sb/v1
│       │   ├─ device_dispatch.c — route command theo device_type
│       │   ├─ device_registry.c — auto-pair khi TC join / report đầu tiên
│       │   ├─ light_ctrl.c/h    — gửi ZCL On/Off + command lifecycle
│       │   ├─ rule_engine.c/h   — local automation (hiện chỉ có gated
│       │   │                      switch->light, giữ cho rule tương lai)
│       │   ├─ telemetry_rx.c    — callback attribute report + switch cmd
│       │   └─ ...               — helpers (app_log, app_utils, v.v.)
│       ├─ build/debug/Z3Gateway — binary Linux đã build (repo track)
│       ├─ Z3Gateway.Makefile    — glue build
│       └─ Z3Gateway.project.mak — source list
├─ cloud/
│   ├─ app/                  — FastAPI app (main, routers, mqtt_client, models)
│   ├─ tests/                — pytest suite
│   ├─ scripts/              — smoke test, e2e script
│   └─ requirements.txt
├─ mqtt/
│   ├─ docker/docker-compose.yml — stack broker local (định nghĩa `sb-mosquitto`)
│   ├─ config/mosquitto.conf     — config listener + auth
│   ├─ config/acl.conf           — quyền topic cho từng user
│   ├─ config/conf.d/bridge.conf — bridge đến prod broker từ xa (optional)
│   └─ passwords/passwd          — credential hash cho user gateway/client/monitor
├─ deploy/
│   └─ docker-compose.prod.yml   — compose production (postgres + broker)
├─ docs/
│   ├─ MQTT_CONTRACT.md, AUTOMATION_MQTT_CONTRACT.md, DEVICE_CAPABILITY_MATRIX.md,
│   │  FLASHING.md, plan.md, ...
│   └─ instruct.md           — file này
└─ scripts/                  — start-gateway.sh + deploy/ (debug helpers
                                live under testing_tools/, gitignored)
```

Nguồn chính xác vs file sinh tự động:

| Loại | Coi như |
|---|---|
| `end_devices/**/*.slcp`, `config/zcl/*.zap`, `app.c`, `app/*.c` | Nguồn chính — sửa ở đây |
| `end_devices/**/autogen/` | Sinh bởi SSv5 từ `.slcp` + `.zap` — không sửa tay |
| `artifact/**/*.s37`, `*.hex`, `*.gbl` | Artifact build — regenerate bằng SSv5 |
| `gateway/Z3Gateway/Z3GatewayHost/app/*` | Nguồn chính |
| `gateway/Z3Gateway/Z3GatewayHost/autogen/` | Sinh bởi SSv5 Z3Gateway sample — tránh sửa tay |
| `gateway/Z3Gateway/Z3GatewayHost/build/debug/Z3Gateway` | Artifact build (binary host) |

---

## D. Firmware artifacts và thứ tự flash

Chi tiết đầy đủ trong [docs/FLASHING.md](FLASHING.md). Tóm tắt để dùng
hàng ngày:

### Thứ tự flash board Coordinator (quan trọng)

```bash
# 1. Bootloader TRƯỚC (phải có trước khi NCP chạy được)
commander flash artifact/bootloader-uart-xmodem/bootloader-uart-xmodem-combined.s37 \
  --device EFR32MG12P332F1024GL125

# 2. Firmware NCP
commander flash artifact/ncp-uart-hw/ncp-uart-hw.s37 \
  --device EFR32MG12P332F1024GL125
```

Sau bước 2, board coordinator expose EZSP-over-ASH ở `/dev/ttyACM0`
(115200 8N1).

### End devices (mỗi role một board; flash một lần)

```bash
commander flash artifact/Z3Light/Z3Light.s37     --device EFR32MG12P332F1024GL125
commander flash artifact/Z3Switch/Z3Switch.s37   --device EFR32MG12P332F1024GL125
# Occupancy sensor: current repo gap — build từ end_devices/Z3_Occupancy_Sensor
```

### Mỗi firmware bật tính năng gì

| Firmware | Cho phép |
|---|---|
| bootloader-uart-xmodem | Đường reflash không cần Commander, qua XMODEM trên UART (update field tùy chọn) |
| ncp-uart-hw | NCP EZSP-over-ASH ở 115200 baud; là firmware duy nhất gateway nói chuyện |
| Z3Light | On/Off cluster server (0x0006), Level Control server (0x0008), attribute reporting |
| Z3Switch | On/Off cluster client (gửi On/Off/Toggle). **Bind phía client đến Z3Light** để điều khiển local qua direct binding. |
| Z3_Occupancy_Sensor | Occupancy Sensing cluster server (0x0406) *verify in local environment* |

### Làm sao biết flash thành công

1. `commander device info` sau khi flash — phải in ra part + reset firmware
   không lỗi.
2. Cắm board coordinator vào máy Ubuntu và check `ls /dev/ttyACM0`. Nếu
   cặp bootloader + NCP đúng, `Z3Gateway` sẽ in
   `ezsp ver 0x0D stack type 0x02 stack ver. [7.5.1 GA ...]` trong 2 s
   kể từ lúc launch (xem `/tmp/z3gw.log`).
3. Z3Light / Z3Switch: sau khi join network của coordinator, bấm switch và
   quan sát `@DBG PRE_CMD cluster=0x0006 cmd=0x02 src=0x...` trong log
   gateway, cộng với attribute report `@DBG ONOFF_REPORT` tới trong ~1 s.

---

## E. Hướng dẫn build / regenerate

### Gateway (binary host Linux)

Gateway build bằng `make` thường, dựa vào cây mẫu Z3Gateway đã có autogen
sẵn. Workflow production trong repo này dùng một workspace song song để
SSv5 không auto-regenerate đè lên file sửa tay:

```bash
# 1. Copy source đã sửa từ repo này sang bản copy trong SSv5 workspace
cp gateway/Z3Gateway/Z3GatewayHost/app/*.c \
   ~/SimplicityStudio/v5_workspace/Z3GatewayHost2/app/

# 2. Build ở đó
(cd ~/SimplicityStudio/v5_workspace/Z3GatewayHost2 && make -f Z3Gateway.Makefile debug)

# 3. Copy binary trở lại vào cây build/debug của repo này
cp ~/SimplicityStudio/v5_workspace/Z3GatewayHost2/build/debug/Z3Gateway \
   gateway/Z3Gateway/Z3GatewayHost/build/debug/Z3Gateway
```

Lưu ý:

- `make` không có `-f` sẽ fail: project này giữ makefile tên là
  `Z3Gateway.Makefile`. Luôn truyền `-f`.
- Nếu binary đích báo "Text file busy" khi copy, vẫn còn process gateway
  đang chạy bản cũ — dừng trước (xem §G).

### Firmware end-device (Z3Light, Z3Switch, occupancy)

Mở `.slcp` trong Simplicity Studio v5, build Release, copy `.s37` output
vào `artifact/<role>/`. Không sửa tay bất cứ gì dưới
`end_devices/**/autogen/`.

### Cloud backend

```bash
cd "$REPO"
python3 -m venv .venv && source .venv/bin/activate
pip install -r cloud/requirements.txt
pytest cloud/tests/ -v              # unit + integration tests
```

---

## F. MQTT / cloud — setup và chạy

### Start broker

```bash
# Container đã tạo, tên sb-mosquitto:
podman start sb-mosquitto
# Bring-up lần đầu (nếu container chưa tồn tại):
cd mqtt/docker && podman-compose up -d
```

### Kiểm tra broker sống

```bash
mosquitto_sub -h localhost -p 1883 -u monitor -P monitor123 \
  -t '$SYS/broker/version' -C 1 -W 3
# kỳ vọng: "mosquitto version 2.0.22"  (version có thể khác)

podman ps --format '{{.Names}} {{.Status}} {{.Ports}}' | grep sb-mosquitto
# kỳ vọng: "Up", ports có 0.0.0.0:1883->1883/tcp và 0.0.0.0:9001->9001/tcp
```

### Start cloud backend

```bash
cd "$REPO" && source .venv/bin/activate

# Nếu dùng postgres do podman quản:
podman start sb-postgres
# chờ đến khi ready:
until podman exec sb-postgres pg_isready -U sb_user | grep -q accepting; do sleep 1; done

# Chạy FastAPI app:
nohup env $(grep -v '^#' .env | xargs) \
  python -m uvicorn cloud.app.main:app --host 0.0.0.0 --port 8000 \
  > /tmp/cloud.log 2>&1 &
```

### Kiểm tra cloud API

```bash
curl -s http://localhost:8000/health
# kỳ vọng: {"status":"ok","version":"0.1.0"}

curl -s http://localhost:8000/api/devices/ | head
# kỳ vọng: JSON array chứa các device đã seed
```

### Inspect MQTT traffic

Credential monitor chỉ đọc, an toàn để trace:

```bash
mosquitto_sub -h localhost -u monitor -P monitor123 -v \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/commands/+/request' \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/commands/+/reply' \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/devices/+/+/reported' \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/devices/+/+/desired' \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/devices/+/+/event' \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/gateway/+'
```

(Local helper script với cùng command này nằm ở `testing_tools/debug/mqtt-trace.sh`
— gitignored, không vào push.)

Ad-hoc một dòng:

```bash
mosquitto_sub -h localhost -u monitor -P monitor123 -v \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/#'
```

### Tóm tắt account / ACL

Từ `mqtt/config/acl.conf` / `mqtt/passwords/passwd`:

| User | Password | Vai trò | Ghi chú |
|---|---|---|---|
| `gateway` | `gateway123` | Gateway publish dữ liệu device, subscribe command. | Dùng bởi Z3Gateway `SB_MQTT_USERNAME`. |
| `client` | `client123` | Cloud backend. Publish command và desired, subscribe reply/report. | Dùng bởi FastAPI `.env`. |
| `monitor` | `monitor123` | Chỉ đọc. | Dùng bởi script trace. |

### Namespace MQTT chính thức (KHÔNG đổi tên)

```
sb/v1/{tenant_id}/{site_id}/{gateway_id}/...
  ├─ gateway/online                        (retain, LWT)
  ├─ devices/{type}/{id}/reported          (retain; gateway -> cloud)
  ├─ devices/{type}/{id}/desired           (retain; cloud -> gateway)
  ├─ devices/{type}/{id}/event             (no retain; gateway -> cloud)
  ├─ commands/{cmd_id}/request             (no retain; cloud -> gateway)
  └─ commands/{cmd_id}/reply               (no retain; gateway -> cloud)
```

Deployment của project này: `tenant_id=hust`, `site_id=lab01`,
`gateway_id=gw-ubuntu-01`. Các id này được hardcode trong gateway
(`app_mqtt.c`) và cấu hình trong `.env` của cloud. Chi tiết envelope xem
[docs/MQTT_CONTRACT.md](MQTT_CONTRACT.md).

---

## G. Gateway — setup và vận hành

### Cách start gateway DUY NHẤT đúng

Dùng helper script:

```bash
"$REPO/scripts/start-gateway.sh"
```

Script này pin các env var quan trọng (xem bảng phía dưới) gồm
`SB_AUTOMATION_SWITCH_HOOK=1` và `SB_RULES_SWITCH_TO_LIGHT=0` — cấu hình
production cho switch → light routing đi qua cloud automation rule (không
qua Zigbee direct binding, không qua legacy wildcard relay).

Nếu cần chạy thủ công, đây là dạng inline tương đương:

```bash
cd "$REPO/gateway/Z3Gateway/Z3GatewayHost/build/debug"
( sleep infinity | env SB_MQTT_HOST=localhost SB_MQTT_PORT=1883 \
                       SB_MQTT_USERNAME=gateway SB_MQTT_PASSWORD=gateway123 \
                       SB_AUTOMATION_SWITCH_HOOK=1 \
                       SB_RULES_SWITCH_TO_LIGHT=0 \
       ./Z3Gateway -p /dev/ttyACM0 -b 115200 > /tmp/z3gw.log 2>&1 ) &
disown
echo $(pgrep -fx './Z3Gateway -p /dev/ttyACM0 -b 115200') > /tmp/z3gw.pid
```

> **Tại sao `sleep infinity | ...`?** Z3GatewayHost dùng `sl_iostream`
> + `sl_cli` để nhận CLI input. Nếu chạy bằng `nohup ... &` (stdin =
> `/dev/null`), helper thread của `sl_iostream` sẽ busy-loop đọc EOF
> 100% CPU và chặn `emberAfMainTickCallback` — quan sát thấy
> `MQTT: rx ...commands/{id}/request` xuất hiện trong log nhưng
> **không bao giờ có** `MQTT: processing` / `CMD parsed` / `DISPATCH`,
> command timeout ở phía cloud. Cấp một stdin pipe không bao giờ EOF
> (`sleep infinity | ...`) khiến thread đó block bình thường, main
> loop tick chạy đúng, queue MQTT được drain. Đừng tự ý đổi sang
> `nohup ... </dev/null` hoặc `setsid ... </dev/null` — cả hai đều
> dẫn về cùng triệu chứng.

### Runtime flags / env vars quan trọng

| Flag / env | Default | Tác dụng |
|---|---|---|
| `-p /dev/ttyACM0` | — | UART device của NCP. Bắt buộc. |
| `-b 115200` | — | Baud UART. Phải khớp firmware NCP. |
| `SB_MQTT_HOST` | compiled default `98.83.4.87` | Host broker. Override thành `localhost` khi dev. |
| `SB_MQTT_PORT` | `1883` | Port broker. |
| `SB_MQTT_USERNAME` | `gateway` | User MQTT. |
| `SB_MQTT_PASSWORD` | `gateway123` | Password MQTT. |
| `SB_RULES_SWITCH_TO_LIGHT` | `0` qua `scripts/start-gateway.sh` (legacy off) | Nếu `=1`, gateway sẽ cài rule wildcard relay mỗi switch toggle đến đèn đã đăng ký. Hiện không dùng vì switch → light đi qua cloud automation rule (xem flag phía dưới). Production phải `=0`. |
| `SB_AUTOMATION_SWITCH_HOOK` | `1` qua `scripts/start-gateway.sh` | Bật Phase 3 switch automation hook trong `automation_rule.c`: khi switch toggle đến, gateway match rule trong bảng in-memory (do cloud push qua `automations/{id}/desired`) và thực thi action tương ứng. **Yêu cầu**: Zigbee direct binding switch → light phải đã được gỡ (xem §H.2), nếu không sẽ double-toggle. AUTO init log phải có `skip_switch:false,hook:true`. |
| `SB_AUTOMATION_EXECUTE` | *unset* → `1` (execute) | Đặt `=0` để gateway vẫn store/ack rule nhưng không bắn action — dùng cho staged rollouts. |
| `SB_DEBUG_VERBOSE` | *unset* → quiet | Nếu `=1`, bật các dòng log TEMP DEBUG (SUBACK, preview payload rx, tick heartbeat, rule entry/cooldown, timing snap-back). |

### Log đi đâu

`/tmp/z3gw.log` (theo redirect `> /tmp/z3gw.log 2>&1` ở trên). Mọi thứ
stdout/stderr đều vào file này. Không có systemd unit, không có log
rotate — file sẽ phình ra đến khi bạn restart process hoặc tự truncate.

### Inspect gateway đang chạy **mà không** start thêm một cái mới

Lỗi hay gặp: chạy `./Z3Gateway ...` trong terminal mới để "xem nó đang
làm gì". Điều đó start một process thứ hai, xung đột client id MQTT và
UART device — xem §I "Lỡ start gateway instance thứ hai". **Đừng làm
vậy.** Dùng các lệnh này:

```bash
# 1. Gateway còn sống không? PID bao nhiêu?
pgrep -af 'Z3Gateway -p /dev/ttyACM0'
# hoặc, nếu đã ghi lại:
cat /tmp/z3gw.pid

# 2. Đúng một process đang giữ NCP chứ?
fuser /dev/ttyACM0
# kỳ vọng: đúng một PID, trùng với bước 1.

# 3. Đọc tiếp log hiện có:
tail -f /tmp/z3gw.log
# hoặc filter:
tail -f /tmp/z3gw.log | grep -E 'MQTT:|DISPATCH|LIGHT|RULE|@DBG'

# 4. Kiểm tra subscription MQTT còn sống từ phía broker:
mosquitto_sub -h localhost -u monitor -P monitor123 -v \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/gateway/+'
# kỳ vọng thấy envelope "online" gần đây.

# 5. Xem open file descriptor của gateway (xác nhận stdio + UART):
ls -la /proc/$(cat /tmp/z3gw.pid)/fd/{0,1,2,7}
```

### Dừng và restart sạch

```bash
# Dừng
kill "$(cat /tmp/z3gw.pid)" 2>/dev/null
# chờ process thoát và nhả /dev/ttyACM0
while fuser /dev/ttyACM0 >/dev/null 2>&1; do sleep 1; done

# Start (cùng "cách duy nhất đúng" ở trên)
```

Nếu `kill` không dừng được trong vài giây, `kill -9` chấp nhận được —
process này không giữ state bền vững trên host; mọi state device nằm ở
cloud DB + chính end device. Registry device trong RAM sẽ auto-pair lại
khi attribute report đầu tiên đến sau restart.

### Biết gateway thực sự hoạt động end-to-end

- `/tmp/z3gw.log` có đúng một dòng `MQTT: connected` và một dòng
  `MQTT: subscribed`, **không** có dòng `unexpected disconnect rc=7`
  lặp đi lặp lại.
- `mosquitto_sub` trên `commands/+/reply` trả về `status:"executed"` cho
  một command bạn publish (xem §H.1).
- `fuser /dev/ttyACM0` trả về đúng một PID.

### Anti-pattern: start gateway thứ hai

**Không bao giờ** chạy `Z3Gateway` thứ hai khi đã có một cái đang chạy.
Triệu chứng và recovery ở §I.

---

## H. Kiểm tra tính năng end-to-end

Mọi case giả định: broker + postgres + cloud đã up (§F), và đúng một
gateway đang chạy (§G). `mosquitto_sub` trace (§F "Inspect MQTT traffic")
đang subscribe trong terminal khác.

### H.1 Cloud → gateway → light command

Cần flash gì: Z3Light trên board đèn, NCP + bootloader trên coordinator.
Cần chạy gì: broker, postgres, cloud, gateway.

Trigger:

```bash
curl -s -X POST http://localhost:8000/api/devices/000000000000004F/command \
  -H 'Content-Type: application/json' \
  -d '{"op":"set","target":{"power":"on"}}'
```

Bằng chứng hoạt động:

- MQTT trace thấy request trên `commands/{id}/request` rồi reply
  `accepted → queued → sent → executed` trên `commands/{id}/reply`.
- `/tmp/z3gw.log` có `MQTT: rx [...commands/.../request]`,
  `DISPATCH accepted`, `LIGHT tx_started`, `LIGHT executed_tx`.
- Z3Light vật lý bật lên. Một message `devices/light/.../reported` theo
  sau với `state.power=on`.
- `curl http://localhost:8000/api/commands/<id>` trả
  `"status":"executed"`.

### H.2 Switch local direct binding → light

Cần flash gì: Z3Light và Z3Switch. Lúc commission (bước một lần, theo
quy trình chuẩn Silicon Labs Z3), phải **bind** On/Off client của switch
đến On/Off server của đèn. *current repo gap:* binding này chưa được
script trong repo; làm theo các bước tiêu chuẩn Simplicity Studio /
Commander / ZCL CLI để thêm entry binding.

Cần chạy gì: gateway. Gateway chỉ để quan sát sự kiện; bản thân toggle
không đi qua gateway trong mode này.

Trigger: bấm Z3Switch.

Bằng chứng hoạt động:

- Z3Light đổi trạng thái ngay lập tức (< 100 ms với một lần bấm vừa
  phải, không quá nhanh).
- `/tmp/z3gw.log` hiện `@DBG PRE_CMD cluster=0x0006 cmd=0x02 src=0x...`
  (frame switch cũng tới coordinator) và
  `SWITCH: toggle event from 0x... (EUI64)`.
- MQTT trace có `devices/switch/<eui64>/event` với `event:"toggle"`.
- MQTT trace có `devices/light/<eui64>/reported` với `state.power` mới.
- `/tmp/z3gw.log` khi start in ra `RULE: engine init, 0 binding(s),
  switch->light relay disabled (direct binding)` và **không** có dòng
  `LIGHT local_toggle_sent` nào sau khi bấm switch (gateway không gửi
  toggle song song).

Nếu vẫn thấy `LIGHT local_toggle_sent` theo sau một lần bấm switch với
config mặc định, nghĩa là feature gate bị set sai; check
`env | grep SB_RULES_SWITCH_TO_LIGHT` xem có bị gán `=1` dư không.

### H.3 Gateway forward state / report lên trên

Là side-effect của §H.1 và §H.2. Cũng áp dụng cho Z3Light level change,
Z3Switch battery report, và bất cứ occupancy sensor report nào. Tất cả
đều vào `sb/v1/.../devices/{type}/{eui64}/reported` có cờ `retain`.

### H.4 Motion → light occupancy automation

*current repo gap.* Không có rule automation nào ở gateway
(`rule_engine.c`) hay ở cloud. Scaffold rule engine vẫn giữ trong
gateway (§B / §G) để sau này thêm rule tại cùng entry point. Những gì
**đang** hoạt động hôm nay:

- Firmware occupancy sensor (khi đã flash) sẽ gửi
  `occupancy → occupied/unoccupied` dưới dạng ZCL attribute report.
- Gateway sẽ publish report đó đến
  `sb/v1/.../devices/occupancy_sensor/<eui64>/reported` qua đường
  telemetry chung — *verify in local environment*: xác nhận bằng cách
  đi qua trước sensor và xem MQTT trace.

Hành động theo report đó (bật đèn) CHƯA implement.

### H.5 Cloud → gateway commissioning (open / close permit-join)

Cần chạy gì: broker, postgres, cloud, gateway.

Trigger (mở permit-join 60s):

```bash
curl -s -X POST http://localhost:8000/api/gateways/gw-ubuntu-01/commissioning/open \
  -H 'Content-Type: application/json' \
  -d '{"duration_sec":60}'
```

Đóng ngay trước khi hết hạn (tuỳ chọn):

```bash
curl -s -X POST http://localhost:8000/api/gateways/gw-ubuntu-01/commissioning/close \
  -H 'Content-Type: application/json' \
  -d '{}'
```

Bằng chứng hoạt động:

- MQTT trace thấy `commands/{id}/request` với `payload.op =
  "gateway.open_network"`, `targethttps://github.com/ducanh186/zigbee-ble-orchestration-platform/pull/21/conflict?name=gateway%252FZ3Gateway%252FZ3GatewayHost%252Fapp%252Fapp_mqtt.c&ancestor_oid=7fec2b63b36c49f00314d8fa23593b4cf4e3faa5&base_oid=f9efff3435290b07393f4fa38d60e608e845783f&head_oid=b77adba5c9b5862814a8df02cc9874210faa5814.duration_sec = 60`, **không có**
  `payload.device_id` (đó là gateway-scoped op).
- `/tmp/z3gw.log` có `MQTT: rx [...commands/...]`,
  `CMD parsed op=gateway.open_network device_id=""`,
  `DISPATCH accepted_gw`, `NET open_join_cmd zstatus=0x00 duration_s=60`.
- `commands/{id}/reply` qua chuỗi `accepted → queued → sent → executed`.
  Reply có `payload.device_id = null`.
- `gateway/event` publish `permit_join_opened` với `duration_sec`.
- Sau `duration_sec` giây gateway tự đóng, `gateway/event` publish
  `permit_join_closed reason=timeout zstatus=0x00`. Nếu user gọi close
  sớm thì reason=`command`.
- `curl http://localhost:8000/api/commands/<id>` trả `"status":"executed"`,
  `"target_kind":"gateway"`, `"device_id":null`.

Failure thường gặp:

- `reason=not_formed` — gateway chưa join network nào, không thể mở
  permit-join. Form network trước (xem `cmd_handler` op `net_form` hoặc
  CLI `plugin network-creator form`).
- `duration_sec` cap ở `1..180` (validation pydantic). Vượt ngưỡng
  trả 422 ở cloud, request không bao giờ chạm gateway.

### H.6 Hiển thị command reply lifecycle

Với mỗi command từ cloud, bạn phải thấy trên `commands/{cmd_id}/reply`
một chuỗi tăng đơn điệu:

1. `accepted` — request đúng cú pháp và đã route.
2. `queued` — dispatcher chấp nhận để gửi.
3. `sent` — frame ZCL đã handoff cho stack.
4. `executed` — APS-level TX success (lưu ý: TX-level, không phải xác
   nhận bulb đã đổi trạng thái; xem block comment quanh
   `emberAfMessageSentCallback` trong
   [light_ctrl.c](../gateway/Z3Gateway/Z3GatewayHost/app/light_ctrl.c)).

Terminal failure là `failed` (kèm field `reason`) hoặc `timeout` (do
cloud `command_timeout.py` sweep phát ra khi không có terminal status
trong `timeout_ms`).

---

## I. Troubleshooting

Nhìn triệu chứng từ dưới lên: hardware → flashing → gateway process →
MQTT → cloud → registry. Bảng dưới giả định `/tmp/z3gw.log` tồn tại
(xem §G).

### Không có `/dev/ttyACM0`

| Kiểm tra | Nguyên nhân thường gặp |
|---|---|
| `ls /dev/ttyACM0` báo "No such file or directory" | NCP chưa cắm, cable lỏng, hoặc thiếu firmware NCP. Rút cắm lại; nếu vẫn không có, reflash bootloader + NCP theo §D. |
| `dmesg \| tail -20` show một device `cdc_acm` mới ở số khác | OS enumerate thành `/dev/ttyACM1`... Update flag `-p` khi launch gateway. |

### `commander` not found

Commander ở trong Simplicity Studio: thêm
`$SSv5_ROOT/developer/adapter_packs/commander` vào `PATH`. Không có nó
thì không flash firmware qua CLI được.

### Commander không nhận board

`commander device info` báo lỗi: check cable USB J-Link, thử cổng USB
khác (tránh USB hub). Xác nhận mặt trước WSTK hiện rev board.

### NCP không phản hồi

`/tmp/z3gw.log` dừng ở `MQTT: config ...` và không bao giờ in
`ezsp ver ...` trong vài giây. Gần như luôn do:

- Firmware NCP thiếu / hỏng — reflash theo §D.
- Thiếu bootloader — binary NCP cần bootloader; flash bootloader
  **trước**.
- Process khác đang giữ `/dev/ttyACM0` — xem "Lỡ start gateway instance
  thứ hai" phía dưới.

### Gateway không subscribe được MQTT

`/tmp/z3gw.log` hiện `MQTT: subscribe failed: ...`. Thường do sai
user/password hoặc thiếu entry ACL. Verify:

```bash
mosquitto_sub -h localhost -u gateway -P gateway123 \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/commands/+/request' -v
```

Nếu cái này cũng fail, broker hoặc password file sai. Xem
`podman logs sb-mosquitto` tìm `not authorised`.

### Cloud API không healthy

`curl http://localhost:8000/health` fail → check:

- Process đang chạy: `pgrep -af 'uvicorn cloud.app.main'`.
- Postgres up: `podman ps | grep sb-postgres`.
- `/tmp/cloud.log` tìm exception startup (DB URL, lỗi MQTT connect).

### Device unknown / not paired / not registered

Log gateway hiện `LIGHT reject reason=unknown_device`. Registry trong
RAM của gateway rỗng. Nguyên nhân:

- Gateway vừa restart; registry rỗng đến khi attribute report đầu tiên
  từ đèn đến (auto-pair trigger trong
  [telemetry_rx.c](../gateway/Z3Gateway/Z3GatewayHost/app/telemetry_rx.c)).
- Đèn chưa bao giờ join network Zigbee của gateway này. Verify bằng cách
  xem `@DBG PRE_CMD` trong log gateway khi bấm bất cứ device nào. Nếu
  không hiện gì, device đang ở network khác — rejoin về coordinator này.

### **Lỡ start gateway instance thứ hai**

Triệu chứng: cloud command chờ hàng phút mới "accepted" hoặc không bao
giờ "executed"; `/tmp/z3gw.log` hiện block **lặp đi lặp lại**:

```
@DBG MQTT onConnect rc=0 text="Connection Accepted."
MQTT: unexpected disconnect rc=7 text="The connection was lost."
```

`podman logs sb-mosquitto` hiện dòng như `Client z3gw-host already
connected, closing old connection.` mỗi ~1 giây.

Nguyên nhân: có hai (hoặc nhiều hơn) process `Z3Gateway`. Cả hai dùng
client id MQTT hardcode `z3gw-host` — broker chấp nhận cái mới nhất và
đá cái cũ, lặp vô hạn. Về phía UART, cả hai process cũng đồng thời đẩy
ASH lên `/dev/ttyACM0`, dần dần làm stack mất đồng bộ.

Recovery:

```bash
# Xác định:
pgrep -af 'Z3Gateway -p /dev/ttyACM0'
fuser /dev/ttyACM0          # show toàn bộ process đang giữ

# Kill mọi process gateway:
pkill -f 'Z3Gateway -p /dev/ttyACM0'
# xác nhận UART đã free:
while fuser /dev/ttyACM0 >/dev/null 2>&1; do sleep 1; done

# Start đúng một cái (xem §G).
```

Sau restart sạch, `/tmp/z3gw.log` phải có đúng một
`@DBG MQTT onConnect rc=0` và **không có** dòng `unexpected disconnect`
nào.

### Switch local path bị gateway rule engine can thiệp / duplicate

Triệu chứng: bấm switch thì đèn nhấp nháy — đổi đúng trạng thái trong
chốc lát rồi trở lại ("snap back"). Đây là BUG 2 trong điều tra trước.

Nguyên nhân: gateway đang relay switch event đến đèn song song với
direct binding. `env | grep SB_RULES_SWITCH_TO_LIGHT` in `=1`, hoặc log
gateway hiện `RULE: engine init, 1 binding(s), switch->light relay
ENABLED`.

Khắc phục: unset `SB_RULES_SWITCH_TO_LIGHT` (hoặc set `=0`), rồi restart
gateway (§G "Dừng và restart sạch"). Verify sau restart:

```
RULE: engine init, 0 binding(s), switch->light relay disabled (direct binding)
```

### Motion automation không kích hoạt

Repo hiện tại không implement. Xem §H.4. Nếu bạn tưởng nó đã hoạt động
trước đây, rất có thể đó là do rule wildcard cũ routing các ZCL traffic
không liên quan vào `lightCtrlLocalToggle` — mà giờ đã bị tắt.

### Tin nhắn MQTT retained cũ gây nhầm lẫn

`mosquitto_sub` hiện message `.../reported` với timestamp rõ ràng trong
quá khứ sau khi vừa start sạch. Đó là state retained từ session trước,
không phải gateway vừa publish. Xem field `msg_id`: gateway mới start
có counter bắt đầu từ 1 và tăng dần mỗi lần publish, nên retained
message có `msg_id >= 10` gần như chắc chắn là cũ.

Để xóa retained message cũ:

```bash
mosquitto_pub -h localhost -u client -P client123 -r -q 1 \
  -t 'sb/v1/hust/lab01/gw-ubuntu-01/devices/light/<eui>/reported' -n
```

### Bảng triage — biết tầng nào đang hỏng

| Test | Nếu PASS, không phải ở: | Nếu FAIL, xem: |
|---|---|---|
| `ls /dev/ttyACM0` | — | Hardware / flashing (§D) |
| `/tmp/z3gw.log` có `ezsp ver …` trong 2 s sau start | NCP firmware | Flashing / UART |
| `/tmp/z3gw.log` có `MQTT: subscribed` và không lặp disconnect | MQTT user/ACL | Xung đột second-instance (§trên) |
| `curl /health` OK | Cloud process | Khởi động cloud / DB |
| `curl /api/devices/` liệt kê device | Seed DB cloud | Cloud `seed.py` hoặc schema DB |
| `@DBG PRE_CMD` hiện khi bấm switch | Radio / joining | Device join / cấu hình PAN |
| `LIGHT executed_tx` sau cloud command | Gateway dispatch / ZCL | Registry (unknown device?) |

---

## J. Checklist kiểm tra

### J.1 Bring-up lần đầu

- [ ] Board coordinator đã flash: bootloader trước, NCP sau (§D).
- [ ] `/dev/ttyACM0` tồn tại và user có quyền truy cập (§B).
- [ ] Board Z3Light và Z3Switch đã flash (§D).
- [ ] Direct Zigbee binding giữa On/Off client của Z3Switch và On/Off
      server của Z3Light đã cấu hình lúc commission (§H.2 — *current
      repo gap: bước tay*).
- [ ] `podman start sb-mosquitto sb-postgres` cả hai `Up` (§F).
- [ ] `.venv` cloud tồn tại và `cloud/requirements.txt` đã cài (§B).
- [ ] `python -m uvicorn cloud.app.main:app ...` đang chạy; `/health`
      trả ok (§F).
- [ ] Đúng một gateway launch theo lệnh §G. `/tmp/z3gw.log` có một
      `onConnect`, một `subscribed`, không có disconnect.
- [ ] Device seed `000000000000004F` xuất hiện trong
      `GET /api/devices/`.
- [ ] `mosquitto_sub -u monitor -P monitor123 -C 1 -W 3 -t 'sb/v1/hust/lab01/gw-ubuntu-01/gateway/online'`
      hiện envelope với timestamp gần đây.
- [ ] §H.1 cloud command đạt `executed`; đèn đổi trạng thái vật lý.
- [ ] §H.2 bấm switch → đèn đổi trạng thái trong 100 ms, và log gateway
      không có `LIGHT local_toggle_sent`.

### J.2 Vận hành hàng ngày

- [ ] `pgrep -af 'Z3Gateway -p /dev/ttyACM0'` — đúng một PID.
- [ ] `fuser /dev/ttyACM0` — cùng một PID duy nhất đó.
- [ ] `tail -20 /tmp/z3gw.log | grep unexpected\ disconnect` — rỗng.
- [ ] `curl -s http://localhost:8000/health` — ok.
- [ ] `mosquitto_sub -u monitor -P monitor123 -C 1 -W 3 -t 'sb/v1/hust/lab01/gw-ubuntu-01/gateway/online'`
      — có envelope "online" gần đây.

### J.3 Debugging

- [ ] Start MQTT trace lâu dài trong terminal riêng — dùng lệnh
      `mosquitto_sub -h localhost -u monitor -P monitor123 -v -t 'sb/v1/#'`
      (full topic tree) hoặc copy đoạn `mosquitto_sub` chi tiết hơn ở §F
      "Inspect MQTT traffic".
- [ ] Bật verbose log gateway: dừng gateway, restart với
      `SB_DEBUG_VERBOSE=1` trong env. Check `/tmp/z3gw.log` tìm các
      dòng `@DBG ...`.
- [ ] **Không** launch gateway thứ hai. Dùng `/tmp/z3gw.log` + MQTT
      trace + `curl /api/...` + `pgrep`/`fuser` để quan sát (§G, §I).
- [ ] Nếu switch-local bị duplicate, check
      `env | grep SB_RULES_SWITCH_TO_LIGHT` và dòng `RULE: engine init`;
      production phải là `0 binding(s)` và `relay disabled`.
- [ ] Nếu reported state trông bị đứng, kiểm tra xem có phải message
      retained từ session trước không (§I "Tin nhắn MQTT retained cũ").
- [ ] Dừng bằng `kill "$(cat /tmp/z3gw.pid)"`, chờ `fuser /dev/ttyACM0`
      không in gì nữa, rồi restart.

---

## Session 2026-05-22 — Firmware LED scheme, switch binding clear, motion reported, dashboard canonical

Tóm tắt những thay đổi đã chốt trong session 2026-05-22 và đã merge vào nhánh
trước khi push. Nếu bạn pull từ remote và thấy hành vi mới so với runbook
phía trên, đây là chỗ tra cứu nguồn gốc.

### Z3Switch firmware

- `netMgrInit()` (file `end_devices/Z3Switch/app/net_mgr.c`) gọi
  `emberClearBindingTable()` mỗi lần boot khi `SWITCH_AUTO_FIND_BIND=0`
  (default). Mục đích: xoá NVM3 binding cũ tồn lại từ những lần flash
  có `SWITCH_AUTO_FIND_BIND=1` — nếu giữ binding, switch sẽ gửi ZCL
  Toggle thẳng đến light qua radio (binding-table-send) song song với
  cloud rule, gây double-toggle.
- Reflash sau patch:
  `commander flash artifact/Z3Switch/Z3Switch.s37 --serialno 440124173`.

### Z3_Occupancy_Sensor firmware

- LED0 = network status, scheme đồng nhất với Z3Switch:
  off khi chưa joined → blink 500 ms khi đang network steering → solid
  khi đã joined.
- LED1 = PIR motion detection. Sáng khi `state.occupancy == "occupied"`,
  tắt khi clear. Độc lập với LED0.
- Auto-search network on boot nếu chưa joined (giống Switch) — user không
  cần bấm PB0 cho lần commissioning đầu.
- Để hỗ trợ 2 LED, đã thêm `led1` vào `simple_led` instances trong
  `.slcp`, tạo mới `config/sl_simple_led_led1_config.h` (PF5,
  active-high), regenerate `autogen/sl_simple_led_instances.{c,h}`
  bằng tay. SSv5 sẽ rewrite autogen nếu re-import; check diff.
- Reflash:
  `commander flash artifact/Z3_Occupancy_Sensor/Z3_Occupancy_Sensor.s37 --serialno 440121812`.

### Gateway — motion reported publish

- `appMqttPublishMotionReported()` mới trong
  `gateway/Z3Gateway/Z3GatewayHost/app/app_mqtt.c`: mỗi lần PIR
  transition, gateway publish thêm `devices/motion/{eui}/reported`
  (QoS 1, retained) với payload `state.occupancy = "occupied"|"unoccupied"`,
  `state.reachable = true`. Cloud `_handle_reported` ghi `DeviceState`
  → dashboard mới hiển thị được current occupancy. Trước session này
  gateway chỉ publish `event`, UI luôn rỗng cho motion device.

### Cloud / dashboard

- Canonical local dev flow là **manual uvicorn + cloud/webdev/dev_server.py**
  trên Linux. `cloud/webdev/start_dev.py` (Windows-flavoured one-shot
  launcher) hạ xuống mức alternative. Chi tiết trong
  `cloud/webdev/README.md`.
- `cloud/app/seed.py._LEGACY_PLACEHOLDER_IDS` mở rộng cho 6 EUI test
  (`00124b0001aa22bb`, `00124b0002cc33dd`, `00124b0003ee44ff`,
  `0xPROBE`, `0xTEST`, `0xPROBE2`) — `start_dev.py` tự dọn nếu tái xuất
  hiện trong DB.
- `cloud/scripts/smoke_test.py` và `cloud/scripts/test_phase3_phase4.py`
  thêm guard: refuse to run nếu `SB_API_URL` không chứa `test` / `localhost`
  / `127.0.0.1`. Override bằng `SB_SMOKE_FORCE=1` cho CI / known-test
  database. Lý do: lần đầu chạy bị insert vào production-shaped DB,
  để lại 6 placeholder device gây rối dashboard.

### Repo housekeeping

- `evidence/`, `scripts/debug/`, `docs/samples/real/` đã được hợp nhất
  vào `testing_tools/` (gitignored) — đây là Claude / dev workspace,
  không lên remote. Các debug helper script
  (`mqtt-trace.sh`, `mqtt-cmd.sh`, `DEBUG.md`) vẫn dùng được local,
  chỉ không vào commit nữa.
- 3 file md trong `docs/` đã consolidate:
  `FIRMWARE_ARTIFACTS.md` merge vào `FLASHING.md` (section "## Artifacts");
  `iot_zigbee_sprint_plan.md` và `CLOUD_IMPLEMENTATION_PLAN.md` xoá
  hẳn (stale / historical).
- `docs/AUTOMATION_MQTT_CONTRACT.md` được promote thành tracked
  (`git add -f`) — `**/*.md` rule ignore nó mặc định nhưng đây là
  contract material, reviewers cần.
