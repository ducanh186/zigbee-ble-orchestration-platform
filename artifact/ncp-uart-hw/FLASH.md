# Flashing ncp-uart-hw

## Device Info

| Field | Value |
|-------|-------|
| Device | Zigbee NCP (Network Co-Processor) with UART EZSP |
| MCU | EFR32MG12P332F1024GL125 |
| Radio Board | BRD4162A |
| Mainboard | BRD4001A (WSTK) |

## Binary Files

| File | Description |
|------|-------------|
| `ncp-uart-hw.s37` | NCP firmware (656 KB) |

## Prerequisites

The bootloader must be flashed first. See `../bootloader-uart-xmodem/FLASH.md`.

## How to Flash

```bash
commander flash ncp-uart-hw.s37 --device EFR32MG12P332F1024GL125
```

## Full Setup (new board from scratch)

```bash
# 1. Flash bootloader
commander flash ../bootloader-uart-xmodem/bootloader-uart-xmodem-combined.s37 --device EFR32MG12P332F1024GL125

# 2. Flash NCP firmware
commander flash ncp-uart-hw.s37 --device EFR32MG12P332F1024GL125
```

## What This Firmware Does

This is the radio-side firmware for the Zigbee coordinator. It runs on the EFR32 and exposes the Zigbee stack over UART using the EZSP (EmberZNet Serial Protocol). The gateway host application (`Z3GatewayHost`) connects to this NCP over the serial port to form/manage the Zigbee network.
