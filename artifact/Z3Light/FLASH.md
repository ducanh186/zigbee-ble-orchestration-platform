# Flashing Z3Light

## Device Info

| Field | Value |
|-------|-------|
| Device | Z3Light — Zigbee 3.0 Router |
| MCU | EFR32MG12P332F1024GL125 |
| Radio Board | BRD4162A |
| Mainboard | BRD4001A (WSTK) |
| Source | `end_devices/Z3Light/` |

## Binary Location

```
artifact/Z3Light/Z3Light.s37
```

> **Status:** Binary ready (936 KB).

## How to Flash

### Using Simplicity Commander (CLI)

```bash
commander flash artifact/Z3Light/Z3Light.s37 --device EFR32MG12P332F1024GL125
```

### Using Simplicity Commander (GUI)

1. Open Simplicity Commander
2. Select the connected WSTK (BRD4001A + BRD4162A)
3. Go to **Flash** tab
4. Browse to `artifact/Z3Light/Z3Light.s37`
5. Click **Flash**

### Erase before flashing (optional, recommended for clean state)

```bash
commander device masserase --device EFR32MG12P332F1024GL125
commander flash artifact/Z3Light/Z3Light.s37 --device EFR32MG12P332F1024GL125
```

## How to Build (if binary is missing)

1. Install **Simplicity Studio v5** with **Gecko SDK 4.5.0**
2. Install **GNU ARM Toolchain 12.2.1.20221205**
3. Import `end_devices/Z3Light/Z3Light.slcp`
4. Build (Release configuration)
5. Copy the `.s37` output into `artifact/Z3Light/`
