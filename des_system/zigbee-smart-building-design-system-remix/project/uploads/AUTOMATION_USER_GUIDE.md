# Hướng Dẫn Sử Dụng Automation Trên App

Tài liệu này dành cho người demo và người mới dùng app.

## Automation Là Gì?

Automation là một luật đơn giản kiểu:

```text
Khi thiết bị A có sự kiện
thì thiết bị B sẽ làm một hành động
```

Ví dụ dễ hiểu:

```text
Khi cảm biến chuyển động báo có người
thì bật đèn phòng lab
```

Trong MVP hiện tại, app không tự chạy logic Automation. App chỉ tạo luật và
hiển thị trạng thái. Cloud lưu luật. Gateway nhận luật và chạy hành động trên
thiết bị Zigbee.

## Trước Khi Dùng

Bạn cần có:

- Cloud API đang chạy
- app đang dùng đúng `API_BASE_URL`
- ít nhất một thiết bị `motion` hoặc `switch`
- ít nhất một thiết bị `light`

Nếu app không thấy device nào, hãy kiểm tra tab Home trước.

## Tạo Rule Mới

1. Mở app.
2. Chọn tab `Automation`.
3. Nhập `Rule name`.
4. Chọn `Template`.
5. Chọn thiết bị trigger, ví dụ motion sensor.
6. Chọn một hoặc nhiều đèn sẽ được điều khiển.
7. Giữ `Enabled` nếu muốn rule có hiệu lực ngay.
8. Bấm `Save rule`.

Sau khi lưu, rule sẽ xuất hiện trong danh sách bên dưới form.

## Các Template MVP

### Motion becomes occupied

Dùng khi bạn muốn bật đèn khi có người.

Ví dụ:

```text
When motion-01 becomes occupied
Turn light-01 and light-02 on
```

### Motion becomes unoccupied

Dùng khi bạn muốn tắt đèn khi không còn người.

Ví dụ:

```text
When motion-01 becomes unoccupied
Turn light-01 and light-02 off
```

### Switch toggles one light

Dùng khi một công tắc điều khiển một đèn.

Ví dụ:

```text
When switch-01 toggles
Toggle light-01
```

### Switch toggles selected lights

Dùng khi một công tắc điều khiển nhiều đèn.

Ví dụ:

```text
When switch-01 toggles
Toggle light-01 and light-02
```

## Hiểu Trạng Thái Rule

### PENDING

Cloud đã lưu rule, nhưng Gateway chưa xác nhận đã nhận rule.

Với MVP hiện tại, trạng thái này là bình thường nếu phần Gateway sync chưa chạy
đầy đủ. App không giả vờ rằng rule đã synced.

### SYNCED

Gateway đã xác nhận nhận rule.

Khi thấy trạng thái này, rule đã sẵn sàng để Gateway chạy khi trigger xảy ra.

### FAILED

Rule không sync được.

Lúc này hãy kiểm tra:

- Cloud API còn chạy không
- Gateway còn online không
- rule có dùng đúng device type không
- Cloud log có báo validation error không

## Hiểu Trạng Thái Chạy Rule

### NEVER RUN

Rule đã được tạo nhưng chưa có sự kiện thật nào kích hoạt.

Ví dụ: bạn tạo rule motion occupied nhưng chưa kích hoạt cảm biến motion.

### EXECUTED

Gateway đã chạy rule thành công.

### FAILED

Gateway cố chạy rule nhưng không thành công.

### TIMEOUT

Gateway hoặc Cloud không nhận được kết quả trong thời gian chờ.

## Demo Khuyến Nghị

Demo dễ hiểu nhất:

```text
Rule name: Motion turns on lab lights
Template: Motion becomes occupied
Motion device: motion-01
Target lights: light-01, light-02
Enabled: on
```

Luồng demo:

1. Mở tab Home để chứng minh app thấy device thật.
2. Mở tab Automation.
3. Tạo rule motion occupied -> lights on.
4. Xem rule xuất hiện trong danh sách.
5. Kiểm tra status `PENDING` hoặc `SYNCED`.
6. Kích hoạt cảm biến motion.
7. Quan sát đèn và event log.

Nếu Gateway sync chưa hoàn chỉnh, hãy nói rõ:

```text
Cloud đã lưu rule thành công. Gateway sync vẫn đang ở trạng thái pending.
```

Đừng nói rule đã chạy thành công nếu chưa có log hoặc trạng thái chứng minh.

## Lỗi Thường Gặp

### Không bấm được Save rule

Nguyên nhân thường gặp:

- chưa nhập rule name
- chưa có trigger device
- chưa chọn light nào
- app đang saving

### Không thấy motion device

Hãy kiểm tra tab Home hoặc Cloud API:

```text
GET /api/devices
```

Device motion phải có `device_type = motion`.

### Rule luôn pending

Điều này nghĩa là Cloud đã lưu rule nhưng chưa có Gateway acknowledgement.

Với MVP hiện tại, đây là trạng thái trung thực. Không phải lỗi app nếu Gateway
sync chưa được implement đầy đủ.

### App báo lỗi Cloud

Kiểm tra:

- điện thoại có mạng không
- `API_BASE_URL` có đúng không
- Cloud API `/health` có trả `200 OK` không
- `/api/automations` có hoạt động không

## API Dành Cho Người Test

Kiểm tra Cloud:

```text
GET /health
GET /api/devices
GET /api/automations
GET /api/events?limit=20
```

Tạo rule thành công thì `/api/automations` sẽ trả về rule mới, ví dụ:

```text
sync_status: pending
last_run_status: never_run
```

Đây là evidence tốt để đưa vào report demo.
