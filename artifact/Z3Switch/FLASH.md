# Flashing Z3Switch

## Device Info

| Field | Value |
|-------|-------|
| Device | Z3Switch — Zigbee 3.0 End Device |
| MCU | EFR32MG12P332F1024GL125 |
| Radio Board | BRD4162A |
| Mainboard | BRD4001A (WSTK) |
| Source | `end_devices/Z3Switch/` |

## Binary Location

```
artifact/Z3Switch/Z3Switch.s37
```

> **Status:** Binary ready (806 KB).

## How to Flash

### Using Simplicity Commander (CLI)

```bash
commander flash artifact/Z3Switch/Z3Switch.s37 --device EFR32MG12P332F1024GL125
```

### Using Simplicity Commander (GUI)

1. Open Simplicity Commander
2. Select the connected WSTK (BRD4001A + BRD4162A)
3. Go to **Flash** tab
4. Browse to `artifact/Z3Switch/Z3Switch.s37`
5. Click **Flash**

### Erase before flashing (optional, recommended for clean state)

```bash
commander device masserase --device EFR32MG12P332F1024GL125
commander flash artifact/Z3Switch/Z3Switch.s37 --device EFR32MG12P332F1024GL125
```

## How to Build (if binary is missing)

1. Install **Simplicity Studio v5** with **Gecko SDK 4.5.0**
2. Install **GNU ARM Toolchain 12.2.1.20221205**
3. Import `end_devices/Z3Switch/Z3Switch.slcp`
4. Build (Release configuration)
5. Copy the `.s37` output into `artifact/Z3Switch/`
