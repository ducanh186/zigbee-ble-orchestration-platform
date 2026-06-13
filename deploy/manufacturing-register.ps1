[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Eui64,

    [Parameter(Mandatory = $true)]
    [string]$InstallCode,

    [Parameter(Mandatory = $true)]
    [ValidateSet("light", "switch", "motion")]
    [string]$DeviceType,

    [string]$Model,

    [string]$OutputDirectory,

    [string]$ApiBaseUrl
)

$ErrorActionPreference = "Stop"

function Invoke-CloudPost {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [hashtable]$Body,

        [Parameter(Mandatory = $true)]
        [string]$Purpose,

        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )

    try {
        return Invoke-RestMethod `
            -Method Post `
            -Uri $Uri `
            -Headers @{ Authorization = "Bearer $AccessToken" } `
            -ContentType "application/json" `
            -Body ($Body | ConvertTo-Json -Compress)
    }
    catch {
        $statusCode = "unknown"
        if ($null -ne $_.Exception.Response) {
            try {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            catch {
                $statusCode = "unknown"
            }
        }
        throw "$Purpose failed (HTTP $statusCode)."
    }
}

function Write-Utf8WithoutBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

try {
    $accessToken = $env:SB_MANUFACTURING_ACCESS_TOKEN
    if ([string]::IsNullOrWhiteSpace($accessToken)) {
        throw "SB_MANUFACTURING_ACCESS_TOKEN is required."
    }

    $normalizedEui64 = $Eui64.Trim().ToUpperInvariant()
    if ($normalizedEui64 -notmatch "^[0-9A-F]{16}$") {
        throw "Eui64 must be exactly 16 hexadecimal characters."
    }

    $normalizedInstallCode = $InstallCode.Trim().ToUpperInvariant()
    $validInstallCodeLengths = @(16, 20, 28, 36)
    if (
        $normalizedInstallCode -notmatch "^[0-9A-F]+$" -or
        $validInstallCodeLengths -notcontains $normalizedInstallCode.Length
    ) {
        throw "InstallCode must be hexadecimal with a supported Zigbee length."
    }

    if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
        $ApiBaseUrl = $env:SB_API_BASE_URL
    }
    if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
        $ApiBaseUrl = "https://dashboard.iot-building.app"
    }
    $ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")

    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $OutputDirectory = Join-Path (Get-Location) "manufacturing-output\$normalizedEui64"
    }
    $resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
    $payloadPath = Join-Path $resolvedOutputDirectory "payload.json"
    $labelPath = Join-Path $resolvedOutputDirectory "label.svg"
    if ((Test-Path -LiteralPath $payloadPath) -or (Test-Path -LiteralPath $labelPath)) {
        throw "Output files already exist. Choose a new OutputDirectory."
    }

    [Net.ServicePointManager]::SecurityProtocol = (
        [Net.ServicePointManager]::SecurityProtocol -bor
        [Net.SecurityProtocolType]::Tls12
    )

    $factoryBody = @{
        eui64 = $normalizedEui64
        install_code = $normalizedInstallCode
        device_type = $DeviceType
    }
    if (-not [string]::IsNullOrWhiteSpace($Model)) {
        $factoryBody.model = $Model.Trim()
    }

    $factoryDevice = Invoke-CloudPost `
        -Uri "$ApiBaseUrl/api/provisioning/factory-devices" `
        -Body $factoryBody `
        -Purpose "Factory registration" `
        -AccessToken $accessToken
    if ($factoryDevice.has_install_code -ne $true) {
        throw "Factory registration did not confirm Install Code storage."
    }

    $label = Invoke-CloudPost `
        -Uri "$ApiBaseUrl/api/provisioning/labels" `
        -Body @{
            eui64 = $normalizedEui64
            device_type = $DeviceType
        } `
        -Purpose "Public label creation" `
        -AccessToken $accessToken

    if (
        [string]::IsNullOrWhiteSpace([string]$label.payload_json) -or
        [string]::IsNullOrWhiteSpace([string]$label.qr_svg)
    ) {
        throw "Public label response is missing payload_json or qr_svg."
    }
    if ([string]$label.payload_json -match '"install_code"\s*:') {
        throw "Cloud returned a forbidden Install Code field in the QR payload."
    }

    New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force | Out-Null
    Write-Utf8WithoutBom -Path $payloadPath -Content ([string]$label.payload_json)
    Write-Utf8WithoutBom -Path $labelPath -Content ([string]$label.qr_svg)

    Write-Output "Factory device registered: $normalizedEui64"
    Write-Output "Public QR payload: $payloadPath"
    Write-Output "Public QR label: $labelPath"
}
catch {
    [Console]::Error.WriteLine("Manufacturing registration failed: $($_.Exception.Message)")
    exit 1
}
