# v1.1.1 HTTPS Hotfix

## Current HTTPS endpoint

Temporary client HTTPS endpoint:

```text
https://mb6k0h7mn8.execute-api.us-east-1.amazonaws.com
```

This endpoint is an AWS API Gateway HTTP API in account `934568647022`.
It forwards HTTPS client traffic to the current EC2 Cloud API at:

```text
http://98.83.4.87:8000
```

## Why this exists

Direct Let's Encrypt HTTPS on the EC2 public IP was prepared in
`deploy/setup-https.sh`, but certificate issuance is currently blocked by the
EC2 security group in account `185369505994`.

The blocked group is:

```text
sg-06d4d43711670ab89 / launch-wizard-1
```

Certbot failed because Let's Encrypt could not reach port `80` on
`98.83.4.87`. Open inbound TCP `80` and `443` on that security group, then rerun
`deploy/deploy.ps1` to enable direct EC2 HTTPS.

## v1.1.1 APK build

The v1.1.1 hotfix APK was built with:

```powershell
flutter build apk --release `
  --dart-define=USE_MOCK_API=false `
  --dart-define=HIDE_LOGIN=false `
  --dart-define=API_BASE_URL=https://mb6k0h7mn8.execute-api.us-east-1.amazonaws.com
```

Smoke evidence:

- `GET /health` over HTTPS returned `200`.
- `POST /auth/login` over HTTPS returned `username`, `user_id`, `role`,
  `home_id`, and `expires_at`.
- Protected provisioning label endpoint returned `401` without token and `201`
  with an admin bearer token.
