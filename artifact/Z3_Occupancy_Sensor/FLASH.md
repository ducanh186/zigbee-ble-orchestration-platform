# Flashing Z3_Occupancy_Sensor

## Device Info

| Field | Value |
|-------|-------|
| Device | Z3_Occupancy_Sensor — Zigbee 3.0 Router (PIR + Buttons) |
| MCU | EFR32MG12P332F1024GL125 |
| Radio Board | BRD4162A |
| Mainboard | BRD4001A (WSTK) |
| Source | `end_devices/Z3_Occupancy_Sensor/` |

## Binary Location

```
artifact/Z3_Occupancy_Sensor/Z3_Occupancy_Sensor.s37
```

> **Status:** Binary ready (701 KB).

## How to Flash

### Using Simplicity Commander (CLI)

```bash
commander flash artifact/Z3_Occupancy_Sensor/Z3_Occupancy_Sensor.s37 --device EFR32MG12P332F1024GL125
```

If multiple kits are connected, pass `--serialno <J-Link serial>` to disambiguate.

### Using Simplicity Commander (GUI)

1. Open Simplicity Commander
2. Select the connected WSTK (BRD4001A + BRD4162A)
3. Go to **Flash** tab
4. Browse to `artifact/Z3_Occupancy_Sensor/Z3_Occupancy_Sensor.s37`
5. Click **Flash**

### Erase before flashing (optional, recommended for clean state)

```bash
commander device masserase --device EFR32MG12P332F1024GL125
commander flash artifact/Z3_Occupancy_Sensor/Z3_Occupancy_Sensor.s37 --device EFR32MG12P332F1024GL125
```

### Power-switch note

If `commander` reports `Target voltage too low (~0.37 V)`, flip the
mainboard power switch on BRD4001A from **BAT** to **AEM** (or **USB**)
so the target MCU receives power.

## How to Build (Linux CLI workflow)

1. Install ARM toolchain and udev rule for J-Link:
   ```bash
   sudo apt-get install -y gcc-arm-none-eabi binutils-arm-none-eabi libnewlib-arm-none-eabi git-lfs
   echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="1366", MODE="0660", GROUP="plugdev"' \
     | sudo tee /etc/udev/rules.d/99-jlink.rules
   sudo udevadm control --reload-rules && sudo udevadm trigger
   ```

2. Pull Gecko SDK LFS binaries (one-time):
   ```bash
   (cd ~/SimplicityStudio/SDKs/gecko_sdk && git lfs install --skip-repo && git lfs pull)
   ```

3. Workspace layout (one-time setup; mirrors Z3GatewayHost convention):
   ```
   ~/ss_v5/v5_workspace/Z3_Occupancy_Sensor/
     app.c  main.c  app/  autogen/  config/      (copied from end_devices/Z3_Occupancy_Sensor/)
     GNU ARM v12.2.1 - Default/                  (Studio-generated build dir, paths fixed for Linux)
       gecko_sdk_4.5.0/                          (bundled tree, missing files rsynced from ~/SimplicityStudio/SDKs/gecko_sdk)
   ```

4. Build:
   ```bash
   cd ~/ss_v5/v5_workspace/Z3_Occupancy_Sensor/'GNU ARM v12.2.1 - Default'
   make all -j$(nproc)
   ```

5. Copy the `.s37` back into `artifact/Z3_Occupancy_Sensor/`.

> The build dir is the source of truth for the *build*, the repo is the
> source of truth for the *application source*. After editing files in
> `end_devices/Z3_Occupancy_Sensor/`, re-copy them into the workspace
> root before re-building.
