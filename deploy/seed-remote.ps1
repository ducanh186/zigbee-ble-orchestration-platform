# Run seed script on EC2
# Usage: powershell -File deploy\seed-remote.ps1
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $ScriptDir ".env.deploy"
$config = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line -split "=", 2
        if ($parts.Length -eq 2) { $config[$parts[0].Trim()] = $parts[1].Trim() }
    }
}

$EC2_KEY = $config["EC2_KEY"]
if ($EC2_KEY.StartsWith("~")) { $EC2_KEY = $EC2_KEY.Replace("~", $env:USERPROFILE) }
$SSH_OPTS = @("-i", $EC2_KEY, "-o", "StrictHostKeyChecking=no")
$REMOTE = "$($config["EC2_USER"])@$($config["EC2_HOST"])"

Write-Host "Running seed on EC2..." -ForegroundColor Yellow
ssh @SSH_OPTS $REMOTE "docker exec sb-cloud-api python -m cloud.app.seed"
Write-Host "Seed complete." -ForegroundColor Green
