from __future__ import annotations

import pytest
from pydantic import ValidationError

from cloud.app.schemas import ProvisioningDevicePayload


VALID_EUI64 = "A8D417FEFF570B00"
VALID_INSTALL_CODE = "83FED3407A939723A5C639B26916D505C3B5"


def test_zigbee_install_code_crc_matches_contract_fixture():
    from cloud.app.provisioning_install_code import append_install_code_crc

    assert (
        append_install_code_crc("83FED3407A939723A5C639B26916D505")
        == VALID_INSTALL_CODE
    )


def test_generate_install_code_returns_16_bytes_plus_little_endian_crc():
    from cloud.app.provisioning_install_code import (
        generate_install_code,
        validate_install_code,
    )

    generated = generate_install_code()

    assert len(generated) == 36
    assert generated == generated.upper()
    assert validate_install_code(generated)


def test_schema_rejects_install_code_with_wrong_crc():
    wrong_crc = VALID_INSTALL_CODE[:-4] + "0000"

    with pytest.raises(ValidationError):
        ProvisioningDevicePayload(
            eui64=VALID_EUI64,
            install_code=wrong_crc,
            device_type="light",
        )
