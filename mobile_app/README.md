# Zigbee Smart Building Mobile App

Flutter Android app for operator-style Zigbee LIGHT control through the Cloud REST API.

## Run

Cloud API mode is the default:

```powershell
$token = [Environment]::GetEnvironmentVariable('SB_API_AUTH_TOKEN', 'User')
flutter run `
  --dart-define=API_BASE_URL=https://your-api-domain.example.com `
  --dart-define=API_AUTH_TOKEN=$token
```

Remote Cloud API mode requires HTTPS and `API_AUTH_TOKEN`.

Mock mode for UI-only work:

```powershell
flutter run --dart-define=USE_MOCK_API=true
```

Alternative Cloud API host:

```powershell
flutter run `
  --dart-define=USE_MOCK_API=false `
  --dart-define=API_BASE_URL=https://your-host.example.com `
  --dart-define=API_AUTH_TOKEN=$token
```

Local HTTP is allowed only for local development:

```powershell
flutter run `
  --dart-define=USE_MOCK_API=false `
  --dart-define=API_BASE_URL=http://localhost:8000 `
  --dart-define=ALLOW_INSECURE_API=true `
  --dart-define=API_AUTH_TOKEN=$token
```

## Structure

```text
lib/
  data/      API models, services, repository implementations
  domain/    clean app models and repository contracts
  ui/        theme, shared widgets, feature views, view models
```

The app calls REST only. It does not speak MQTT or Zigbee directly.
