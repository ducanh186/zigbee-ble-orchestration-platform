# Production Release Runbook

Last updated: 2026-06-01 04:22:00 +07:00

Jira: SCRUM-99

Status: RELEASE_CANDIDATE_NOT_PRODUCTION_READY

Release candidate: `v0.9.0-rc.1`

## Scope

This document closes the local production-hardening plan with CI, release, rollback, final evidence, and GitHub pre-release instructions. It does not claim the platform is production ready. The release candidate is for review and operator validation.

## CI Verification

Run these commands from the repository root before creating the tag:

```text
python -m pytest cloud/tests -q
git diff --check
```

Run this secure compose config check from `deploy/` with a temporary `.env.prod` copied from `.env.prod.example`:

```text
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml config
```

Expected local evidence for this release candidate:

```text
python -m pytest cloud/tests -q -> 153 passed, 21 skipped
git diff --check -> exit 0
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml config -> PASS
```

## Release Steps

1. Confirm `main` points at the merged Phase 7 commit.
2. Confirm `docs/production/production-final-report.md` says `NOT_PRODUCTION_READY`.
3. Confirm release notes are present at `docs/production/release-notes-v0.9.0-rc.1.md`.
4. Create the GitHub release as a pre-release:

```text
gh release create v0.9.0-rc.1 --target main --title "v0.9.0-rc.1 Production hardening RC" --notes-file docs/production/release-notes-v0.9.0-rc.1.md --prerelease
```

## EC2 deploy evidence

The EC2 deploy requested during Phase 7 used the existing deploy script:

```text
deploy/deploy.ps1
```

Verified evidence:

```text
GET http://<EC2_HOST>:8000/health -> {"status":"ok","version":"0.1.0"}
sb-cloud-api -> healthy
sb-mosquitto -> healthy
sb-postgres -> healthy
```

Important limitation: the current EC2 deploy path still uses legacy `docker-compose.prod.yml`, not the secure compose cutover path. That is why this release is a release candidate and not production ready.

## Rollback

Fast rollback options:

1. Re-deploy the previous known-good tag or commit using `deploy/deploy.ps1`.
2. Revert the merge commit that introduced the faulty change:

```text
git revert -m 1 <merge_commit_sha>
git push origin main
```

3. Re-run `deploy/deploy.ps1` from the reverted `main`.
4. Verify `/health`, container health, and MQTT gateway event flow.

Data rollback requires explicit operator approval. Do not restore PostgreSQL or Mosquitto volumes on production without following `docs/production/production-operations.md`.

## Release Gate

This release candidate can be published when:

- CI commands pass.
- Release notes exist.
- Rollback steps are documented.
- Final report links every evidence document.
- Deferred operator validation items are explicitly listed.

This release candidate must not be promoted to stable until secure compose cutover, real restore dry-run, live MQTT mTLS negative tests, live gateway startup, and Zigbee default global key rejection evidence are captured.
