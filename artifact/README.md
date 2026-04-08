# Firmware Artifacts

Flashable firmware binaries for all devices. Each subdirectory contains a manifest, flashing instructions, and `.s37` files.

## Devices

| Device | Type | MCU | Board | Binary Status |
|--------|------|-----|-------|---------------|
| bootloader-uart-xmodem | NCP Bootloader | EFR32MG12P332F1024GL125 | BRD4162A + BRD4001A | Ready |
| ncp-uart-hw | Zigbee NCP (UART EZSP) | EFR32MG12P332F1024GL125 | BRD4162A + BRD4001A | Ready |
| Z3Switch | Zigbee End Device | EFR32MG12P332F1024GL125 | BRD4162A + BRD4001A | Ready |
| Z3Light | Zigbee Router | EFR32MG12P332F1024GL125 | BRD4162A + BRD4001A | Ready |

## Flash Order (new board setup)

### Coordinator board (NCP)
```bash
commander flash artifact/bootloader-uart-xmodem/bootloader-uart-xmodem-combined.s37 --device EFR32MG12P332F1024GL125
commander flash artifact/ncp-uart-hw/ncp-uart-hw.s37 --device EFR32MG12P332F1024GL125
```

### End-device boards
```bash
commander flash artifact/Z3Switch/Z3Switch.s37 --device EFR32MG12P332F1024GL125
commander flash artifact/Z3Light/Z3Light.s37 --device EFR32MG12P332F1024GL125
```

## Common Build Info

| Field | Value |
|-------|-------|
| SDK | Gecko SDK 4.5.0 |
| Toolchain | GNU ARM 12.2.1.20221205 |
| MCU | EFR32MG12P332F1024GL125 |
| Radio Board | BRD4162A (rev A02) |
| Mainboard | BRD4001A (rev A01) |
| IDE | Simplicity Studio v5 |
