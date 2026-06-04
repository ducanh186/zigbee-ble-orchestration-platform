-- Factory-side install-code registry for secure QR provisioning.
-- QR payloads carry only public identity; install_code remains server-side.

CREATE TABLE IF NOT EXISTS factory_devices (
    eui64        VARCHAR     PRIMARY KEY,
    install_code VARCHAR     NOT NULL,
    device_type  VARCHAR     NOT NULL,
    model        VARCHAR,
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
    claimed_at   TIMESTAMP,
    created_at   TIMESTAMP   DEFAULT now(),
    updated_at   TIMESTAMP   DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_factory_devices_type_active
    ON factory_devices (device_type, is_active);

INSERT INTO factory_devices (eui64, install_code, device_type, model, is_active)
VALUES
    (
        '0000000000000053',
        '00112233445566778899AABBCCDDEEFF528F',
        'motion',
        'EFR32MG12_MOTION_KIT',
        TRUE
    ),
    (
        '0000000000000054',
        '102132435465768798A9BACBDCEDFE0F2D18',
        'light',
        'EFR32MG12_LIGHT_KIT',
        TRUE
    ),
    (
        '0000000000000055',
        'FFEEDDCCBBAA99887766554433221100520D',
        'light',
        'EFR32MG12_LIGHT_KIT',
        TRUE
    )
ON CONFLICT (eui64) DO NOTHING;
