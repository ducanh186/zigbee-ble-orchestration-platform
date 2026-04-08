# Flashing End-Device Firmware

## Prerequisites

- **Simplicity Commander** (CLI or GUI) — included with Simplicity Studio v5, or download standalone from Silicon Labs
- **Hardware**: WSTK Mainboard (BRD4001A) + EFR32MG12 Radio Board (BRD4162A)
- **USB connection** to the WSTK via the J-Link debug port

## Quick Reference

| Device | Type | Flash Command |
|--------|------|---------------|
| Bootloader | NCP Bootloader | `commander flash artifact/bootloader-uart-xmodem/bootloader-uart-xmodem-combined.s37 --device EFR32MG12P332F1024GL125` |
| NCP | Zigbee Coordinator Radio | `commander flash artifact/ncp-uart-hw/ncp-uart-hw.s37 --device EFR32MG12P332F1024GL125` |
| Z3Switch | End Device | `commander flash artifact/Z3Switch/Z3Switch.s37 --device EFR32MG12P332F1024GL125` |
| Z3Light | Router | `commander flash artifact/Z3Light/Z3Light.s37 --device EFR32MG12P332F1024GL125` |

## Full Board Setup (from scratch)

### Coordinator board (runs NCP firmware, connects to gateway host via UART)

```bash
# 1. Flash bootloader (must be first)
commander flash artifact/bootloader-uart-xmodem/bootloader-uart-xmodem-combined.s37 --device EFR32MG12P332F1024GL125

# 2. Flash NCP firmware
commander flash artifact/ncp-uart-hw/ncp-uart-hw.s37 --device EFR32MG12P332F1024GL125
```

### End-device boards

```bash
commander flash artifact/Z3Switch/Z3Switch.s37 --device EFR32MG12P332F1024GL125
# or
commander flash artifact/Z3Light/Z3Light.s37 --device EFR32MG12P332F1024GL125
```

## Step-by-Step

1. Connect the WSTK board via USB
2. Verify Commander sees the board:
   ```bash
   commander device info
   ```
3. (Optional) Erase the device for a clean state:
   ```bash
   commander device masserase --device EFR32MG12P332F1024GL125
   ```
4. Flash the firmware:
   ```bash
   commander flash <path-to-s37> --device EFR32MG12P332F1024GL125
   ```
5. The device resets automatically after flashing

## Where Are the Binaries?

```
artifact/
  bootloader-uart-xmodem/    <- 3 .s37 files (ready)
  ncp-uart-hw/               <- 1 .s37 file  (ready)
  Z3Switch/                  <- not built yet
  Z3Light/                   <- not built yet
```

Each directory contains `manifest.json` (build metadata) and `FLASH.md` (device-specific instructions).

## How to Build Missing Binaries (Z3Switch / Z3Light)

1. Open Simplicity Studio v5
2. Ensure Gecko SDK 4.5.0 is installed
3. Import `end_devices/Z3Switch/Z3Switch.slcp` (or Z3Light)
4. Build (Release configuration)
5. Copy the `.s37` output into `artifact/Z3Switch/` (or Z3Light)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Commander not found | Add Simplicity Studio's `developer/adapter_packs/commander/` to PATH |
| No device detected | Check USB cable, try different port, verify J-Link drivers |
| Flash verification failed | Try mass erase first, then re-flash |
| NCP not responding after flash | Ensure bootloader was flashed first |
