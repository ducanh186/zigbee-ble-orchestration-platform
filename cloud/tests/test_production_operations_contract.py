from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
OPS_RUNBOOK = REPO_ROOT / "docs" / "production" / "production-operations.md"
CHECKLIST = REPO_ROOT / "docs" / "production" / "production-acceptance-checklist.md"
PROGRESS = REPO_ROOT / "docs" / "production" / "production-progress.html"
FINAL_REPORT = REPO_ROOT / "docs" / "production" / "production-final-report.md"
SECURE_COMPOSE = REPO_ROOT / "deploy" / "docker-compose.prod-secure.yml"


def test_operations_runbook_covers_backup_restore_monitoring_and_alerting() -> None:
    runbook = OPS_RUNBOOK.read_text(encoding="utf-8")

    required_terms = [
        "pg_dump",
        "pg_restore",
        "postgres-data",
        "mosquitto-data",
        "MQTT_CERT_DIR",
        "gateway identity",
        "docker compose",
        "/health",
        "pg_isready",
        "mosquitto_sub",
        "alert channel",
        "escalation owner",
        "restore dry-run",
    ]
    for term in required_terms:
        assert term in runbook

    forbidden_terms = [
        ".".join(["98", "83", "4", "87"]),
        ".".join(["52", "199", "233", "62"]),
        "gateway" + "123",
        "bridge" + "123",
        "BEGIN " + "PRIVATE KEY",
    ]
    for term in forbidden_terms:
        assert term not in runbook


def test_secure_compose_has_persistent_state_and_healthchecks() -> None:
    compose = SECURE_COMPOSE.read_text(encoding="utf-8")

    assert "postgres-data:/var/lib/postgresql/data" in compose
    assert "mosquitto-data:/mosquitto/data" in compose
    assert "mosquitto-log:/mosquitto/log" in compose
    assert "pg_isready" in compose
    assert "healthcheck:" in compose


def test_phase6_acceptance_and_dashboard_are_updated() -> None:
    checklist = CHECKLIST.read_text(encoding="utf-8")
    phase6 = checklist.split("## Phase 6 - Backup, Restore, Monitoring, and Alerting")[
        1
    ].split("## Phase 7")[0]
    progress = PROGRESS.read_text(encoding="utf-8")
    final_report = FINAL_REPORT.read_text(encoding="utf-8")

    assert "[x] PostgreSQL backup scope is documented." in phase6
    assert "[x] Restore procedure is documented." in phase6
    assert "[x] Health monitoring is documented." in phase6
    assert "[x] Alerting channel is documented." in phase6
    assert "production-operations.md" in phase6
    assert "88%" in progress
    assert "SCRUM-98" in progress
    assert "production-operations.md" in final_report
