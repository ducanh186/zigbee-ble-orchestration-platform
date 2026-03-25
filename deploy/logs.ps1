# View logs from EC2 containers
# Usage: powershell -File deploy\logs.ps1 [cloud-api|mosquitto]
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
$REMOTE_DIR = $config["REMOTE_DIR"]

$Service = if ($args.Length -gt 0) { $args[0] } else { "" }

ssh @SSH_OPTS $REMOTE "cd $REMOTE_DIR/deploy && docker compose -f docker-compose.prod.yml logs -f --tail=100 $Service"
