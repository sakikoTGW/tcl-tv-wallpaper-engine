# Fast fetch WE 2.7.4 (API 27+, armeabi-v7a in universal build) — direct CDN, no apk.now HTML hop.
param(
    [string]$Out = "",
    [switch]$StripV7aOnly
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
if (-not $Out) { $Out = Join-Path $Root "firmware\apk\wallpaper-engine-2.7.4.apk" }

$Url = "https://download.apk.now/apks/wallpaper-engine/4240/wallpaper-engine-2-7-4-android-apk-download.apk"
$Expected = 84517232

$part = "$Out.part"
if ((Test-Path $Out) -and ((Get-Item $Out).Length -lt 1MB)) { Remove-Item $Out -Force }
if ((Test-Path $part) -and ((Get-Item $part).Length -lt 1MB)) { Remove-Item $part -Force }

Write-Host "CDN: $Url" -ForegroundColor Cyan
Write-Host " -> $Out ($([math]::Round($Expected/1MB,1)) MB)" -ForegroundColor Cyan

if (Test-Path $Out) {
    $sz = (Get-Item $Out).Length
    if ($sz -eq $Expected) {
        Write-Host "[OK] already complete" -ForegroundColor Green
        exit 0
    }
    if ($sz -gt 1MB -and $sz -lt $Expected) {
        Move-Item -Force $Out $part
        Write-Host "Resume from $([math]::Round($sz/1MB,1)) MB" -ForegroundColor Yellow
    }
}

$curl = "curl.exe"
if (-not (Get-Command $curl -ErrorAction SilentlyContinue)) { throw "curl.exe not found" }

$args = @(
    "-L", "-C", "-", "--retry", "5", "--retry-delay", "2",
    "--connect-timeout", "20", "--speed-time", "120", "--speed-limit", "1024",
    "-A", "Mozilla/5.0",
    "-o", $Out,
    $Url
)
if (Test-Path $part) {
    Move-Item -Force $part $Out
}

& $curl @args
if ($LASTEXITCODE -ne 0) { throw "curl failed ($LASTEXITCODE)" }

$final = (Get-Item $Out).Length
if ($final -ne $Expected) {
    throw "Size mismatch: got $final expected $Expected"
}

$Bt = if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME "build-tools\30.0.3\aapt.exe" } else { "E:\AndroidSDK\build-tools\30.0.3\aapt.exe" }
if (Test-Path $Bt) {
    & $Bt dump badging $Out | Select-String "package:|versionName|sdkVersion|native-code"
}

if ($StripV7aOnly) {
    $v7a = Join-Path (Split-Path $Out) "wallpaper-engine-2.7.4-v7a.apk"
    python (Join-Path $Root "scripts\strip-we-apk-v7a.py") $Out $v7a
    Write-Host "v7a-only: $v7a" -ForegroundColor Green
}

Write-Host "[OK] $Out" -ForegroundColor Green
