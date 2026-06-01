from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
RELEASE_DOC = REPO_ROOT / "docs" / "production" / "production-release.md"
RELEASE_NOTES = REPO_ROOT / "docs" / "production" / "release-notes-v0.9.0-rc.1.md"
CHECKLIST = REPO_ROOT / "docs" / "production" / "production-acceptance-checklist.md"
PROGRESS = REPO_ROOT / "docs" / "production" / "production-progress.html"
FINAL_REPORT = REPO_ROOT / "docs" / "production" / "production-final-report.md"


def test_release_runbook_documents_ci_release_rollback_and_deploy_evidence() -> None:
    runbook = RELEASE_DOC.read_text(encoding="utf-8")

    required_terms = [
        "v0.9.0-rc.1",
        "release candidate",
        "python -m pytest cloud/tests -q",
        "docker compose --env-file .env.prod -f docker-compose.prod-secure.yml config",
        "gh release create",
        "--prerelease",
        "rollback",
        "git revert",
        "deploy/deploy.ps1",
        "EC2 deploy evidence",
        "/health",
        "not production ready",
    ]
    for term in required_terms:
        assert term in runbook


def test_phase7_acceptance_dashboard_and_final_report_are_closed() -> None:
    checklist = CHECKLIST.read_text(encoding="utf-8")
    phase7 = checklist.split("## Phase 7 - CI/CD, Release, Rollback, and Final Evidence")[
        1
    ]
    progress = PROGRESS.read_text(encoding="utf-8")
    final_report = FINAL_REPORT.read_text(encoding="utf-8")

    assert "[x] CI commands are documented." in phase7
    assert "[x] Release steps are documented." in phase7
    assert "[x] Rollback procedure is documented." in phase7
    assert "[x] Final report links all evidence." in phase7
    assert "operator validation items" in phase7
    assert "100%" in progress
    assert "SCRUM-99" in progress
    assert "production-release.md" in progress
    assert "production-release.md" in final_report
    assert "release-notes-v0.9.0-rc.1.md" in final_report
    assert "NOT_PRODUCTION_READY" in final_report


def test_release_notes_are_ready_for_github_prerelease() -> None:
    notes = RELEASE_NOTES.read_text(encoding="utf-8")

    assert "v0.9.0-rc.1" in notes
    assert "Pre-release" in notes
    assert "Not production ready" in notes
    assert "PR #66" in notes
    assert "PR #70" in notes
    assert "EC2 deploy" in notes
