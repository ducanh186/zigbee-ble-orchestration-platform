# Production Final Report

Last updated: 2026-06-02 15:13:36 +07:00

Jira: SCRUM-90

Status: NOT_PRODUCTION_READY

This file is intentionally created in Phase 0 as the final evidence container. It must not claim production readiness until every required acceptance item has current evidence.

## Current Conclusion

The platform is not production ready yet.

Reason:

- Local hardening evidence is complete through Phase 7.
- The platform remains NOT_PRODUCTION_READY because live production evidence is still pending.
- The current EC2 deploy is healthy, but it uses the legacy deploy compose path rather than the secure compose cutover path.

## RBAC MVP Conclusion

Trong phạm vi MVP, hệ thống sử dụng ba vai trò chính: admin, parent và viewer. admin dùng cho vận hành kỹ thuật và cấu hình hệ thống; parent đại diện cho chủ nhà, có quyền quản lý thiết bị trong phạm vi home của mình, bao gồm thêm thiết bị mới, xóa thiết bị, điều khiển đèn và tạo automation; viewer chỉ có quyền quan sát trạng thái thiết bị và lịch sử sự kiện. Cách phân quyền này phù hợp với mô hình smart home dạng family nhưng vẫn giữ phạm vi đủ nhỏ cho đồ án tốt nghiệp.

## Evidence Index

| Evidence | Path |
|---|---|
| Security audit | `docs/production/production-security-audit.md` |
| Hardening plan | `docs/production/production-hardening-plan.md` |
| Acceptance checklist | `docs/production/production-acceptance-checklist.md` |
| Progress dashboard | `docs/production/production-progress.html` |
| Production env example | `deploy/.env.prod.example` |
| Production networking runbook | `docs/production/production-networking.md` |
| Secure production compose | `deploy/docker-compose.prod-secure.yml` |
| Nginx production config | `deploy/nginx/prod.conf` |
| Production REST auth evidence | `docs/production/production-auth.md` |
| Production MQTT TLS/ACL evidence | `docs/production/production-mqtt.md` |
| Production gateway config evidence | `docs/production/production-gateway.md` |
| Production secure commissioning evidence | `docs/production/production-commissioning.md` |
| Gateway and local Zigbee security requirements | `docs/production/gateway-localzigbee-security-requirements.md` |
| Production operations runbook | `docs/production/production-operations.md` |
| Production release runbook | `docs/production/production-release.md` |
| Release notes | `docs/production/release-notes-v0.9.0-rc.1.md` |

## Final Readiness Gate

Before this report can say `READY`, all of the following must be true:

1. The acceptance checklist is complete.
2. Required tests pass.
3. Local-only checks and not-testable items are clearly separated.
4. Live deployment assumptions are verified or explicitly accepted by the release owner.
5. No real secret is present in repository docs/config.
6. Each merged phase has a linked PR and Jira evidence.

## Release Candidate Evidence

```text
Release candidate: v0.9.0-rc.1
EC2 deploy source: main after PR #70, commit ea188b4
EC2 health: GET /health -> {"status":"ok","version":"0.1.0"}
Container state: sb-cloud-api healthy, sb-mosquitto healthy, sb-postgres healthy
```

## Current Open Items

- Phase 1: HTTPS reverse proxy and exposure lockdown is locally verified, but live EC2 security group state still needs release-owner confirmation.
- Phase 2: Cloud-App REST API auth/RBAC and Mobile release guard are locally verified; live validation remains pending.
- Phase 3: MQTT TLS/mTLS and ACL config is locally verified; live broker negative tests need approved certificates/environment.
- Phase 4: Gateway production config hardening is locally verified; live gateway startup on hardware remains pending.
- Phase 5: Zigbee secure commissioning is locally verified; live default global key rejection evidence remains pending on gateway hardware.
- Gateway/local Zigbee: implementation requirements and evidence checklist are documented; owner evidence remains pending.
- Phase 6: Backup, restore, monitoring, and alerting are locally documented and verified; real backup/restore dry-run evidence remains pending in an approved production-like environment.
- Phase 7: CI/CD, release, rollback, and final evidence are locally verified for the release candidate.
- Stable production release is deferred until secure compose cutover and live validation items are complete.
