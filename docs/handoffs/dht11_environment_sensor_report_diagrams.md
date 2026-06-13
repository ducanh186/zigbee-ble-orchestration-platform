# DHT11 Environment Sensor — Report Diagrams

Sơ đồ cho báo cáo tốt nghiệp. Vẽ theo kiến trúc thực tế của repo (gateway
Z3GatewayHost, automation engine, MQTT bridge → EC2 cloud → app/dashboard).

## 1. Luồng dữ liệu cảm biến (data flow)

```text
[DHT11 module]      [EFR32 end device]        [Zigbee PAN 0xCD53]      [Z3Gateway host]            [MQTT broker / bridge]        [EC2 Cloud API]        [Mobile / Dashboard]
   T,RH 1-wire  -->  Z3_DHT11_Sensor      -->  ZCL Report Attrs    -->  telemetry_rx.c          -->  sb/v1/.../devices/...    -->  device state +     -->  temp/humidity widget
   (PD8, 3V3)        dht11.c + env_sensor       0x0402 temp (int16s)     ENV decode + log             (registry, automation         automation store        + rule builder UI
                     report 5s/60s/Δ            0x0405 humidity (uint16)  + automation hook            event)                        (teammate work)         (teammate work)
```

## 2. Luồng demo local (build → bằng chứng)

```text
[Build FW]            [Flash kit]                  [Join gateway]            [Stage rule (MQTT)]            [Sensor crosses threshold]      [Gateway log evidence]
 workspace make  -->  commander flash         -->  IC-derived secure    -->  mosquitto_pub             -->  ENV report >= / <=        -->  AUTO fired +
 Z3_DHT11.s37         --serialno 440121812         join, node 0xA09A         automations/{id}/desired       threshold                      auto_action_sent +
                      (no masserase)               classify=environment      (device_type=environment)                                     light @DATA state on/off
```

## 3. Luồng điều khiển đèn theo rule (automation flow)

```text
[ENV report 0x0402/0x0405]   [telemetry_rx.c]              [automation_rule.c match]            [edge-trigger + cooldown]        [light_ctrl]                 [event out]
   value_centi           -->  automationRule          -->  device_type=environment        -->  fire only on            -->  lightCtrlLocalAction   -->  automations/{id}/event
   from node 0xA09A           OnEnvironmentReport()        device_id + metric match            not-met -> met            ByDeviceId(004F, on/off)     "rule_fired"
                                                            comparator vs threshold             (+500ms cooldown)         => ZCL On/Off to light       trigger=threshold_crossed
```

## 4. Luồng điều tra "đèn tự bật" (Phase-6 investigation, kết luận)

```text
[Light ON observed]
      |
      v
[Check DHT11 firmware]   -> emits only 0x0402/0x0405, no On/Off, no binding  -> NOT the cause
      |
      v
[Check who sends On/Off] -> node 0xEB7B = light EUI ...004F (+ switch/cloud automation)  -> pre-existing subsystem
      |
      v
[Intended path now]      -> environment rule: temp/humidity threshold -> lightCtrl on/off  -> ROOT/desired cause
```

Ghi chú: trước khi có tính năng này, đèn bật là do thiết bị/automation cũ trên
mạng demo dùng chung, KHÔNG phải DHT11. Sau tính năng này, cách *có chủ đích* để
cảm biến tác động đèn là rule ngưỡng môi trường ở trên.
