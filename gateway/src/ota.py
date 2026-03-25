"""
OTA artifact staging for campaign manifests.
"""

from __future__ import annotations

import hashlib
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import urlopen

from .models import OTACampaignManifestPayload


class OTAStageError(RuntimeError):
    """Raised when an artifact cannot be staged safely."""


@dataclass(frozen=True)
class StagedArtifact:
    """A downloaded and verified OTA artifact."""

    campaign_id: str
    local_path: Path
    sha256: str
    size_bytes: int


class OTAArtifactManager:
    """Download, verify, and cache `.ota` artifacts for device rollout."""

    def __init__(self, base_dir: Path):
        self.base_dir = base_dir
        self._staged: dict[str, StagedArtifact] = {}

    def get_staged(self, campaign_id: str) -> StagedArtifact | None:
        """Return a previously staged artifact if one exists."""

        return self._staged.get(campaign_id)

    def stage_manifest(self, manifest: OTACampaignManifestPayload) -> StagedArtifact:
        """Download and verify the artifact referenced by a campaign manifest."""

        existing = self._staged.get(manifest.campaign_id)
        if existing is not None and existing.local_path.exists():
            return existing

        campaign_dir = self.base_dir / manifest.campaign_id
        campaign_dir.mkdir(parents=True, exist_ok=True)

        parsed_url = urlparse(str(manifest.artifact.url))
        target_name = Path(parsed_url.path).name or f"{manifest.campaign_id}.ota"
        final_path = campaign_dir / target_name

        fd, temp_name = tempfile.mkstemp(prefix="artifact-", suffix=".tmp", dir=campaign_dir)
        digest = hashlib.sha256()
        bytes_written = 0

        try:
            with open(fd, "wb", closefd=True) as output_handle:
                with urlopen(str(manifest.artifact.url)) as response:  # noqa: S310
                    while True:
                        chunk = response.read(64 * 1024)
                        if not chunk:
                            break
                        output_handle.write(chunk)
                        digest.update(chunk)
                        bytes_written += len(chunk)

            checksum = digest.hexdigest()
            if checksum != manifest.artifact.sha256:
                raise OTAStageError(
                    f"Artifact checksum mismatch for campaign {manifest.campaign_id}: "
                    f"expected {manifest.artifact.sha256}, got {checksum}"
                )
            if bytes_written != manifest.artifact.size_bytes:
                raise OTAStageError(
                    f"Artifact size mismatch for campaign {manifest.campaign_id}: "
                    f"expected {manifest.artifact.size_bytes}, got {bytes_written}"
                )

            temp_path = Path(temp_name)
            shutil.move(str(temp_path), str(final_path))
            staged = StagedArtifact(
                campaign_id=manifest.campaign_id,
                local_path=final_path,
                sha256=checksum,
                size_bytes=bytes_written,
            )
            self._staged[manifest.campaign_id] = staged
            return staged
        except OTAStageError:
            Path(temp_name).unlink(missing_ok=True)
            raise
        except Exception as exc:
            Path(temp_name).unlink(missing_ok=True)
            raise OTAStageError(
                f"Artifact staging failed for campaign {manifest.campaign_id}: {exc}"
            ) from exc
