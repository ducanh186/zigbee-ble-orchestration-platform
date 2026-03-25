# ============================================================
# EC2 First-Time Setup (run from Windows)
# Installs Docker, Docker Compose, Python 3.12 on the EC2.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File deploy\ec2-setup.ps1
# ============================================================
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $ScriptDir ".env.deploy"

if (-not (Test-Path $EnvFile)) {
    Write-Host "ERROR: $EnvFile not found." -ForegroundColor Red
    exit 1
}

$config = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line -split "=", 2
        if ($parts.Length -eq 2) { $config[$parts[0].Trim()] = $parts[1].Trim() }
    }
}

$EC2_HOST = $config["EC2_HOST"]
$EC2_USER = $config["EC2_USER"]
$EC2_KEY  = $config["EC2_KEY"]
if ($EC2_KEY.StartsWith("~")) { $EC2_KEY = $EC2_KEY.Replace("~", $env:USERPROFILE) }

$SSH_OPTS = @("-i", $EC2_KEY, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10")
$REMOTE = "$EC2_USER@$EC2_HOST"

Write-Host "=== Setting up EC2 at $EC2_HOST ===" -ForegroundColor Cyan

$setupScript = @'
set -euo pipefail

echo "=== [1/4] Updating system ==="
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

echo "=== [2/4] Installing Docker ==="
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "Docker installed. Re-login needed for group."
else
    echo "Docker already installed."
fi

echo "=== [3/4] Installing Docker Compose plugin ==="
if ! docker compose version &>/dev/null; then
    sudo apt-get install -y -qq docker-compose-plugin
else
    echo "Docker Compose already installed."
fi

echo "=== [4/4] Checking firewall ==="
echo "Make sure AWS Security Group allows inbound:"
echo "  - 22   (SSH)"
echo "  - 1883 (MQTT)"
echo "  - 8000 (API)"
echo "  - 9001 (MQTT WebSocket)"

echo ""
echo "=== EC2 Setup Complete ==="
echo "Log out and back in, then run deploy.ps1"
'@

ssh @SSH_OPTS $REMOTE $setupScript

Write-Host ""
Write-Host "EC2 setup done! Now run: deploy\deploy.ps1" -ForegroundColor Green
