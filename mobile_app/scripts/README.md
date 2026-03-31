# Mobile App Scripts

## setup-flutter.ps1

Pre-flight check for Flutter mobile development on Windows. The script verifies that all required tools are installed and configured, then prints a clear pass/fail checklist.

**What it checks:**

1. Git
2. Flutter SDK (PATH + common install locations)
3. Dart SDK (bundled with Flutter)
4. Android Studio
5. `ANDROID_HOME` / `ANDROID_SDK_ROOT` environment variables and SDK components
6. Java / JDK and `JAVA_HOME`
7. `flutter doctor -v` (if Flutter is found)
8. `flutter doctor --android-licenses` (if Flutter is found)

**What it does NOT do:**

- It does not download or install anything automatically.
- It does not modify environment variables or system configuration.

### Usage

From the repository root, run:

```powershell
powershell -ExecutionPolicy Bypass -File mobile_app\scripts\setup-flutter.ps1
```

Or from any PowerShell prompt:

```powershell
.\mobile_app\scripts\setup-flutter.ps1
```

If checks fail, the script prints download URLs and guidance for each missing tool.
