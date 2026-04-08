# Flashing bootloader-uart-xmodem

## Device Info

| Field | Value |
|-------|-------|
| Device | Standalone UART XMODEM-CRC Bootloader |
| MCU | EFR32MG12P332F1024GL125 |
| Radio Board | BRD4162A |
| Mainboard | BRD4001A (WSTK) |

## Binary File

| File | Description |
|------|-------------|
| `bootloader-uart-xmodem-combined.s37` | Combined first-stage + main bootloader |

## How to Flash

```bash
commander flash bootloader-uart-xmodem-combined.s37 --device EFR32MG12P332F1024GL125
```

## Flash Order

When setting up a new board from scratch, flash in this order:

1. **Bootloader first**: `commander flash bootloader-uart-xmodem-combined.s37 --device EFR32MG12P332F1024GL125`
2. **Then NCP firmware**: `commander flash ../ncp-uart-hw/ncp-uart-hw.s37 --device EFR32MG12P332F1024GL125`

## Bootloader Usage

Once flashed, connect via UART (115200 baud). The bootloader menu:
- Send `1` — start XMODEM-CRC firmware upload
- Send `2` — boot into the application
