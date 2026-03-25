# ============================================================
# Auto-Deploy to EC2 from Windows
#
# Usage:
#   cp deploy\.env.deploy.example deploy\.env.deploy
#   # edit deploy\.env.deploy
#   powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1
# ============================================================
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

# ----------------------------------------------------------
# Helper: run bash on EC2 without CRLF issues
# ----------------------------------------------------------
function Invoke-EC2 {
    param([string]$Script)
    # Write script to temp file with Unix LF (no BOM), upload, execute, clean up
    $tmp = Join-Path $env:TEMP "ec2-cmd-$([guid]::NewGuid().ToString('N').Substring(0,8)).sh"
    $clean = $Script -replace "`r`n", "`n" -replace "`r", "`n"
    [System.IO.File]::WriteAllText($tmp, $clean, (New-Object System.Text.UTF8Encoding $false))
    scp @SSH_OPTS $tmp "${REMOTE}:/tmp/_deploy_cmd.sh" 2>&1 | Out-Null
    # Use 2>&1 to merge stderr into stdout so PS doesn't treat warnings as errors
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = ssh @SSH_OPTS $REMOTE "bash /tmp/_deploy_cmd.sh 2>&1; echo EXIT_CODE=`$?" 2>&1
    $ErrorActionPreference = $prevPref
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    # Parse exit code from last line
    $lines = @($output | ForEach-Object { "$_" })
    $exitLine = $lines | Where-Object { $_ -match '^EXIT_CODE=(\d+)$' } | Select-Object -Last 1
    $exitCode = if ($exitLine -match '=(\d+)') { [int]$Matches[1] } else { 1 }
    $lines | Where-Object { $_ -notmatch '^EXIT_CODE=\d+$' } | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) {
        Write-Host "ERROR: Remote command failed (exit=$exitCode)" -ForegroundColor Red
        exit 1
    }
}

# ----------------------------------------------------------
# Load config
# ----------------------------------------------------------
$EnvFile = Join-Path $ScriptDir ".env.deploy"
if (-not (Test-Path $EnvFile)) {
    Write-Host "ERROR: $EnvFile not found." -ForegroundColor Red
    Write-Host "  cp deploy\.env.deploy.example deploy\.env.deploy"
    Write-Host "  # then fill in your EC2 details"
    exit 1
}

$config = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line -split "=", 2
        if ($parts.Length -eq 2) {
            $config[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
}

$EC2_HOST   = $config["EC2_HOST"]
$EC2_USER   = $config["EC2_USER"]
$EC2_KEY    = $config["EC2_KEY"]
$REMOTE_DIR = $config["REMOTE_DIR"]

# Expand ~ in key path
if ($EC2_KEY.StartsWith("~")) {
    $EC2_KEY = $EC2_KEY.Replace("~", $env:USERPROFILE)
}

foreach ($var in @("EC2_HOST", "EC2_USER", "EC2_KEY", "REMOTE_DIR")) {
    if (-not $config[$var]) {
        Write-Host "ERROR: $var is not set in .env.deploy" -ForegroundColor Red
        exit 1
    }
}

$SSH_OPTS = @("-i", $EC2_KEY, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10")
$REMOTE = "$EC2_USER@$EC2_HOST"

Write-Host ""
Write-Host "=== Deploying to $EC2_HOST ($REMOTE_DIR) ===" -ForegroundColor Cyan

# ----------------------------------------------------------
# Step 1: Sync files via scp (Windows-friendly, no rsync)
# ----------------------------------------------------------
Write-Host ""
Write-Host "--- [1/6] Packing project files ---" -ForegroundColor Yellow

$TempZip = Join-Path $env:TEMP "iot-platform-deploy.tar.gz"

# Use tar (available on Windows 10+) to pack, excluding unnecessary files
Push-Location $ProjectDir
tar -czf $TempZip `
    --exclude='.git' `
    --exclude='__pycache__' `
    --exclude='*.pyc' `
    --exclude='.env' `
    --exclude='.env.deploy' `
    --exclude='cloud.db' `
    --exclude='ota-files' `
    --exclude='node_modules' `
    --exclude='.claude' `
    .
Pop-Location

Write-Host "Packed project: $([math]::Round((Get-Item $TempZip).Length / 1KB)) KB"

# ----------------------------------------------------------
# Step 2: Upload to EC2
# ----------------------------------------------------------
Write-Host ""
Write-Host "--- [2/6] Uploading to EC2 ---" -ForegroundColor Yellow

ssh @SSH_OPTS $REMOTE "mkdir -p $REMOTE_DIR"
scp @SSH_OPTS $TempZip "${REMOTE}:${REMOTE_DIR}/deploy-payload.tar.gz"

Invoke-EC2 @"
cd $REMOTE_DIR
tar -xzf deploy-payload.tar.gz
rm -f deploy-payload.tar.gz
echo 'Files extracted.'
"@

Remove-Item $TempZip -Force
Write-Host "Files uploaded and extracted."

# ----------------------------------------------------------
# Step 3: Prepare directory structure
# ----------------------------------------------------------
Write-Host ""
Write-Host "--- [3/6] Preparing remote directories ---" -ForegroundColor Yellow

Invoke-EC2 @"
set -e
cd $REMOTE_DIR
mkdir -p deploy/mosquitto/config
mkdir -p deploy/mosquitto/passwords
mkdir -p deploy/cloud
cp -f mqtt/config/mosquitto.conf deploy/mosquitto/config/
cp -f mqtt/config/acl.conf       deploy/mosquitto/config/
echo 'Directories prepared.'
"@

# ----------------------------------------------------------
# Step 4: Generate MQTT passwords
# ----------------------------------------------------------
Write-Host ""
Write-Host "--- [4/6] Generating MQTT passwords ---" -ForegroundColor Yellow

$gwPass  = if ($config["MQTT_GATEWAY_PASS"]) { $config["MQTT_GATEWAY_PASS"] } else { "gateway123" }
$cliPass = if ($config["MQTT_CLIENT_PASS"])  { $config["MQTT_CLIENT_PASS"] }  else { "client123" }
$monPass = if ($config["MQTT_MONITOR_PASS"]) { $config["MQTT_MONITOR_PASS"] } else { "monitor123" }

Invoke-EC2 @"
set -e
cd $REMOTE_DIR
PASSDIR=`$(pwd)/deploy/mosquitto/passwords
docker run --rm -v "`$PASSDIR:/passwords" eclipse-mosquitto:2.0 sh -c "
  touch /passwords/passwd
  mosquitto_passwd -b /passwords/passwd gateway '$gwPass'
  mosquitto_passwd -b /passwords/passwd client  '$cliPass'
  mosquitto_passwd -b /passwords/passwd monitor '$monPass'
"
echo 'MQTT passwords generated.'
"@

# ----------------------------------------------------------
# Step 5: Write cloud .env
# ----------------------------------------------------------
Write-Host ""
Write-Host "--- [5/6] Writing cloud .env on EC2 ---" -ForegroundColor Yellow

$pgUser     = if ($config["POSTGRES_USER"])     { $config["POSTGRES_USER"] }     else { "sb_user" }
$pgPass     = if ($config["POSTGRES_PASSWORD"]) { $config["POSTGRES_PASSWORD"] } else { "sb_pass" }
$pgDb       = if ($config["POSTGRES_DB"])       { $config["POSTGRES_DB"] }       else { "sb_cloud" }
$sbDbUrl    = if ($config["SB_DATABASE_URL"])  { $config["SB_DATABASE_URL"] }  else { "postgresql+asyncpg://${pgUser}:${pgPass}@postgres:5432/${pgDb}" }
$sbMqttHost = if ($config["SB_MQTT_HOST"])     { $config["SB_MQTT_HOST"] }     else { "mosquitto" }
$sbMqttUser = if ($config["SB_MQTT_USERNAME"]) { $config["SB_MQTT_USERNAME"] } else { "client" }
$sbMqttPass = if ($config["SB_MQTT_PASSWORD"]) { $config["SB_MQTT_PASSWORD"] } else { "client123" }
$sbTenant   = if ($config["SB_TENANT_ID"])     { $config["SB_TENANT_ID"] }     else { "hust" }
$sbSite     = if ($config["SB_SITE_ID"])       { $config["SB_SITE_ID"] }       else { "lab01" }
$sbGw       = if ($config["SB_GATEWAY_ID"])    { $config["SB_GATEWAY_ID"] }    else { "gw-ubuntu-01" }

Invoke-EC2 @"
cat > $REMOTE_DIR/deploy/cloud/.env << 'ENVEOF'
SB_DATABASE_URL=$sbDbUrl
SB_MQTT_HOST=$sbMqttHost
SB_MQTT_PORT=1883
SB_MQTT_USERNAME=$sbMqttUser
SB_MQTT_PASSWORD=$sbMqttPass
SB_TENANT_ID=$sbTenant
SB_SITE_ID=$sbSite
SB_GATEWAY_ID=$sbGw
SB_API_HOST=0.0.0.0
SB_API_PORT=8000
ENVEOF
echo 'cloud/.env written.'
"@

# ----------------------------------------------------------
# Step 6: Docker compose up
# ----------------------------------------------------------
Write-Host ""
Write-Host "--- [6/6] Building and starting containers ---" -ForegroundColor Yellow

Invoke-EC2 @"
set -e
cd $REMOTE_DIR/deploy

# Copy cloud source into deploy context for Docker build
rm -rf cloud/app cloud/requirements.txt cloud/Dockerfile cloud/__init__.py cloud/__main__.py 2>/dev/null || true
cp -r ../cloud/app         cloud/
cp    ../cloud/requirements.txt cloud/
cp    ../cloud/Dockerfile  cloud/
cp    ../cloud/__init__.py cloud/
cp    ../cloud/__main__.py cloud/

# Export PostgreSQL credentials for docker-compose interpolation
export POSTGRES_USER='$pgUser'
export POSTGRES_PASSWORD='$pgPass'
export POSTGRES_DB='$pgDb'

# Build and start
docker compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true
docker compose -f docker-compose.prod.yml up --build -d

echo ''
echo 'Waiting for services to start...'
sleep 10

docker compose -f docker-compose.prod.yml ps

echo ''
if curl -sf http://localhost:8000/health; then
    echo ''
    echo 'API is healthy!'
else
    echo 'WARNING: API not responding yet. Check logs with:'
    echo '  docker compose -f docker-compose.prod.yml logs cloud-api'
fi
"@

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  Deploy complete!" -ForegroundColor Green
Write-Host "  API Swagger: http://${EC2_HOST}:8000/docs" -ForegroundColor Green
Write-Host "  MQTT Broker: ${EC2_HOST}:1883" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
