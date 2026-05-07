# Zigbee Smart Building Mobile App

Flutter Android app for operator-style Zigbee LIGHT control through the Cloud REST API.

## Run

Mock mode is the default so UI work can continue without the backend:

```powershell
flutter run
```

Remote Cloud API mode:

```powershell
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For a real phone, replace `API_BASE_URL` with the reachable EC2/API host.

## Structure

```text
lib/
  data/      API models, services, repository implementations
  domain/    clean app models and repository contracts
  ui/        theme, shared widgets, feature views, view models
```

The app calls REST only. It does not speak MQTT or Zigbee directly.
