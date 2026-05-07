# Zigbee Smart Building Mobile App

Flutter Android app for operator-style Zigbee LIGHT control through the Cloud REST API.

## Run

Cloud API mode is the default:

```powershell
flutter run
```

The default API base URL is `http://98.83.4.87:8000`.

Mock mode for UI-only work:

```powershell
flutter run --dart-define=USE_MOCK_API=true
```

Alternative Cloud API host:

```powershell
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://your-host:8000
```

## Structure

```text
lib/
  data/      API models, services, repository implementations
  domain/    clean app models and repository contracts
  ui/        theme, shared widgets, feature views, view models
```

The app calls REST only. It does not speak MQTT or Zigbee directly.
