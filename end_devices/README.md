# End Devices

Firmware source and configuration for Zigbee end devices. Flashable binaries are in `/artifact/`.

## Devices

| Device | Zigbee Role | MCU | Board |
|--------|------------|-----|-------|
| Z3Switch | End Device | EFR32MG12P332F1024GL125 | BRD4162A + BRD4001A |
| Z3Light | Router | EFR32MG12P332F1024GL125 | BRD4162A + BRD4001A |

## Directory Layout (per device)

```
Z3Switch/
  Z3Switch.slcp        # project config (SDK, components, board)
  Z3Switch.slps        # project descriptor (toolchain, part ID)
  Z3Switch.pintool     # pin assignments
  main.c / app.c       # entry points
  app/                 # application logic (buttons, net_mgr)
  config/              # component configuration headers + ZCL config
```

## Build & Flash

See `artifact/Z3Switch/FLASH.md` or `docs/FLASHING.md` for flashing instructions.
