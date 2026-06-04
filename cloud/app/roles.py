from __future__ import annotations

CANONICAL_ROLES = {"admin", "parent", "viewer"}
LEGACY_ROLE_MAP = {
    "operator": "parent",
    "user": "parent",
    "member": "viewer",
}


def canonical_role(role: str | None) -> str:
    normalized = (role or "").strip().lower()
    if normalized in CANONICAL_ROLES:
        return normalized
    return LEGACY_ROLE_MAP.get(normalized, "viewer")


def is_admin_role(role: str | None) -> bool:
    return canonical_role(role) == "admin"


def is_parent_role(role: str | None) -> bool:
    return canonical_role(role) == "parent"


def is_parent_or_admin_role(role: str | None) -> bool:
    return canonical_role(role) in {"admin", "parent"}
