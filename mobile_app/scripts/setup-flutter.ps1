<#
.SYNOPSIS
    Checks the development environment for Flutter mobile app development.

.DESCRIPTION
    This script verifies that all required tools (Git, Flutter SDK, Android Studio,
    Android SDK) are installed and configured. It does NOT install anything automatically;
    it only reports what is present, what is missing, and where to get it.

.NOTES
    Run from PowerShell:
        powershell -ExecutionPolicy Bypass -File mobile_app\scripts\setup-flutter.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ─── Helpers ──────────────────────────────────────────────────────────────────

function Write-Check {
    param(
        [string]$Label,
        [bool]$Passed,
        [string]$Detail = ""
    )
    if ($Passed) {
        Write-Host "  [OK]   " -ForegroundColor Green -NoNewline
    } else {
        Write-Host "  [MISS] " -ForegroundColor Red -NoNewline
    }
    Write-Host "$Label" -NoNewline
    if ($Detail) {
        Write-Host "  ($Detail)" -ForegroundColor DarkGray
    } else {
        Write-Host ""
    }
}

function Find-Executable {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Find-InPaths {
    param(
        [string]$Executable,
        [string[]]$Candidates
    )
    foreach ($dir in $Candidates) {
        $full = Join-Path $dir $Executable
        if (Test-Path $full) { return $full }
    }
    return $null
}

# ─── Banner ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Flutter Development Environment Check" -ForegroundColor Cyan
Write-Host "  Zigbee/BLE Orchestration Platform — Mobile App" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# ─── 1. Git ───────────────────────────────────────────────────────────────────

Write-Host "--- 1. Git ---" -ForegroundColor Yellow

$gitPath = Find-Executable "git"
$gitOk = [bool]$gitPath
if ($gitOk) {
    $gitVersion = & git --version 2>&1
    Write-Check "Git" $true "$gitVersion — $gitPath"
} else {
    Write-Check "Git" $false
    $allPassed = $false
}

Write-Host ""

# ─── 2. Flutter SDK ──────────────────────────────────────────────────────────

Write-Host "--- 2. Flutter SDK ---" -ForegroundColor Yellow

$flutterPath = Find-Executable "flutter"

# If not on PATH, search common locations
if (-not $flutterPath) {
    $commonFlutterDirs = @(
        "C:\src\flutter\bin",
        "D:\flutter\bin",
        "C:\flutter\bin",
        "$env:USERPROFILE\flutter\bin",
        "$env:USERPROFILE\dev\flutter\bin",
        "$env:LOCALAPPDATA\flutter\bin",
        "C:\tools\flutter\bin",
        "D:\tools\flutter\bin"
    )
    $flutterPath = Find-InPaths "flutter.bat" $commonFlutterDirs
}

$flutterOk = [bool]$flutterPath
if ($flutterOk) {
    $flutterVersion = & "$flutterPath" --version 2>&1 | Select-Object -First 1
    Write-Check "Flutter SDK" $true "$flutterVersion — $flutterPath"

    # Check if flutter is on PATH (warn if found only by scanning directories)
    $flutterOnPath = [bool](Find-Executable "flutter")
    if (-not $flutterOnPath) {
        Write-Host "         WARNING: Flutter was found but is NOT on your PATH." -ForegroundColor DarkYellow
        $parentDir = Split-Path (Split-Path $flutterPath)
        Write-Host "         Add this to your PATH: $parentDir\bin" -ForegroundColor DarkYellow
    }
} else {
    Write-Check "Flutter SDK" $false
    Write-Host "         Download: https://docs.flutter.dev/get-started/install/windows/mobile" -ForegroundColor DarkYellow
    $allPassed = $false
}

Write-Host ""

# ─── 3. Dart SDK (bundled with Flutter) ──────────────────────────────────────

Write-Host "--- 3. Dart SDK ---" -ForegroundColor Yellow

$dartPath = Find-Executable "dart"
$dartOk = [bool]$dartPath
if ($dartOk) {
    $dartVersion = & dart --version 2>&1
    Write-Check "Dart SDK" $true "$dartVersion"
} elseif ($flutterOk) {
    Write-Check "Dart SDK" $false "Should be bundled with Flutter; check your Flutter installation"
    $allPassed = $false
} else {
    Write-Check "Dart SDK" $false "Install Flutter SDK first (Dart is bundled)"
    $allPassed = $false
}

Write-Host ""

# ─── 4. Android Studio ───────────────────────────────────────────────────────

Write-Host "--- 4. Android Studio ---" -ForegroundColor Yellow

$androidStudioPaths = @(
    "${env:ProgramFiles}\Android\Android Studio\bin\studio64.exe",
    "${env:ProgramFiles(x86)}\Android\Android Studio\bin\studio64.exe",
    "$env:LOCALAPPDATA\Programs\Android Studio\bin\studio64.exe",
    "C:\Program Files\Android\Android Studio\bin\studio64.exe",
    "D:\Program Files\Android\Android Studio\bin\studio64.exe",
    "$env:USERPROFILE\AppData\Local\Android\android-studio\bin\studio64.exe"
)

$androidStudioExe = $null
foreach ($p in $androidStudioPaths) {
    if ($p -and (Test-Path $p)) {
        $androidStudioExe = $p
        break
    }
}

$androidStudioOk = [bool]$androidStudioExe
if ($androidStudioOk) {
    Write-Check "Android Studio" $true "$androidStudioExe"
} else {
    Write-Check "Android Studio" $false
    Write-Host "         Download: https://developer.android.com/studio" -ForegroundColor DarkYellow
    $allPassed = $false
}

Write-Host ""

# ─── 5. Android SDK / Environment Variables ──────────────────────────────────

Write-Host "--- 5. Android SDK ---" -ForegroundColor Yellow

$androidHome = $env:ANDROID_HOME
$androidSdkRoot = $env:ANDROID_SDK_ROOT

$androidHomeOk = [bool]$androidHome
$androidSdkRootOk = [bool]$androidSdkRoot

if ($androidHomeOk) {
    $androidHomeExists = Test-Path $androidHome
    Write-Check "ANDROID_HOME" $androidHomeExists "$androidHome$(if (-not $androidHomeExists) { ' (path does not exist!)' })"
    if (-not $androidHomeExists) { $allPassed = $false }
} else {
    Write-Check "ANDROID_HOME" $false "Environment variable not set"
    $allPassed = $false
}

if ($androidSdkRootOk) {
    $androidSdkRootExists = Test-Path $androidSdkRoot
    Write-Check "ANDROID_SDK_ROOT" $androidSdkRootExists "$androidSdkRoot$(if (-not $androidSdkRootExists) { ' (path does not exist!)' })"
    if (-not $androidSdkRootExists) { $allPassed = $false }
} else {
    Write-Check "ANDROID_SDK_ROOT" $false "Environment variable not set"
    $allPassed = $false
}

# Try to locate Android SDK in default locations if env vars are missing
if (-not $androidHomeOk -and -not $androidSdkRootOk) {
    $defaultSdkPaths = @(
        "$env:LOCALAPPDATA\Android\Sdk",
        "$env:USERPROFILE\AppData\Local\Android\Sdk",
        "C:\Android\Sdk",
        "D:\Android\Sdk"
    )
    foreach ($sdkPath in $defaultSdkPaths) {
        if ($sdkPath -and (Test-Path $sdkPath)) {
            Write-Host "         HINT: Android SDK found at $sdkPath" -ForegroundColor DarkYellow
            Write-Host "         Set ANDROID_HOME and ANDROID_SDK_ROOT to this path." -ForegroundColor DarkYellow
            break
        }
    }
}

# Check for key SDK components
$sdkBase = if ($androidHome) { $androidHome } elseif ($androidSdkRoot) { $androidSdkRoot } else { "$env:LOCALAPPDATA\Android\Sdk" }
if ($sdkBase -and (Test-Path $sdkBase)) {
    $platformToolsOk = Test-Path (Join-Path $sdkBase "platform-tools")
    $buildToolsOk   = Test-Path (Join-Path $sdkBase "build-tools")
    $emulatorOk      = Test-Path (Join-Path $sdkBase "emulator")

    Write-Check "  platform-tools" $platformToolsOk ""
    Write-Check "  build-tools" $buildToolsOk ""
    Write-Check "  emulator" $emulatorOk ""

    if (-not $platformToolsOk -or -not $buildToolsOk) { $allPassed = $false }
}

Write-Host ""

# ─── 6. Java / JDK ───────────────────────────────────────────────────────────

Write-Host "--- 6. Java / JDK ---" -ForegroundColor Yellow

$javaPath = Find-Executable "java"
$javaOk = [bool]$javaPath
if ($javaOk) {
    $javaVersion = & java -version 2>&1 | Select-Object -First 1
    Write-Check "Java" $true "$javaVersion"
} else {
    Write-Check "Java" $false "Android builds require a JDK (usually bundled with Android Studio)"
    $allPassed = $false
}

$javaHome = $env:JAVA_HOME
if ($javaHome) {
    $javaHomeExists = Test-Path $javaHome
    Write-Check "JAVA_HOME" $javaHomeExists "$javaHome"
} else {
    Write-Check "JAVA_HOME" $false "Not set (may be required by Gradle)"
}

Write-Host ""

# ─── 7. Flutter Doctor ───────────────────────────────────────────────────────

if ($flutterOk) {
    Write-Host "--- 7. Flutter Doctor (verbose) ---" -ForegroundColor Yellow
    Write-Host ""
    & "$flutterPath" doctor -v 2>&1 | ForEach-Object { Write-Host "  $_" }
    Write-Host ""

    Write-Host "--- 8. Android Licenses ---" -ForegroundColor Yellow
    Write-Host "  Running: flutter doctor --android-licenses" -ForegroundColor DarkGray
    Write-Host "  (You may need to accept licenses interactively)" -ForegroundColor DarkGray
    Write-Host ""
    & "$flutterPath" doctor --android-licenses 2>&1 | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}

# ─── Summary ──────────────────────────────────────────────────────────────────

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if ($allPassed) {
    Write-Host "  All checks passed! Your environment looks ready." -ForegroundColor Green
} else {
    Write-Host "  Some checks failed. Please install the missing tools:" -ForegroundColor Red
    Write-Host ""
    if (-not $gitOk)           { Write-Host "    - Git:            https://git-scm.com/download/win" -ForegroundColor Yellow }
    if (-not $flutterOk)       { Write-Host "    - Flutter SDK:    https://docs.flutter.dev/get-started/install/windows/mobile" -ForegroundColor Yellow }
    if (-not $androidStudioOk) { Write-Host "    - Android Studio: https://developer.android.com/studio" -ForegroundColor Yellow }
    if (-not $androidHomeOk)   { Write-Host "    - Set ANDROID_HOME env var to your Android SDK path" -ForegroundColor Yellow }
    if (-not $androidSdkRootOk){ Write-Host "    - Set ANDROID_SDK_ROOT env var to your Android SDK path" -ForegroundColor Yellow }
    if (-not $javaOk)          { Write-Host "    - Java JDK:       Bundled with Android Studio or https://adoptium.net/" -ForegroundColor Yellow }
}

Write-Host ""
Write-Host "  Download URLs:" -ForegroundColor DarkGray
Write-Host "    Flutter SDK:    https://docs.flutter.dev/get-started/install/windows/mobile" -ForegroundColor DarkGray
Write-Host "    Android Studio: https://developer.android.com/studio" -ForegroundColor DarkGray
Write-Host ""
