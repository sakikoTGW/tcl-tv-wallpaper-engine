# Wait for TCL TV adb (USB or WiFi) then deploy wallpaper bridge + mpkg.
# Usage:
#   .\connect-tv-deploy.ps1
#   .\connect-tv-deploy.ps1 -TvIp 192.168.1.10 -WeApkPath "D:\we.apk"

param(
    [string]$TvIp = "",
    [int]$Port = 5555,
    [string]$MpkgPath = "",
    [string]$WeApkPath = "",
    [int]$MaxWaitSec = 600,
    [switch]$Launch
)

$ErrorActionPreference = "Continue"
$Root = Split-Path $PSScriptRoot -Parent
$SpecPath = Join-Path $PSScriptRoot "tcl-tv-spec.json"
$Spec = Get-Content $SpecPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $TvIp) { $TvIp = $Spec.adb.ip }

$SdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "E:\AndroidSDK" }
$Adb = "$SdkRoot\platform-tools\adb.exe"
$Serial = "${TvIp}:${Port}"
$deadline = (Get-Date).AddSeconds($MaxWaitSec)

Write-Host "Waiting for TV adb (USB or $Serial) ..." -ForegroundColor Cyan
Write-Host "PC and TV must be on same WiFi. If wireless fails, use USB data cable." -ForegroundColor DarkYellow

while ((Get-Date) -lt $deadline) {
    $devs = (& $Adb devices -l 2>&1) -join "`n"

    # USB device (no colon in serial)
    $usbLine = ($devs -split "`n") | Where-Object {
        $_ -match '\tdevice' -and $_ -notmatch ':' -and $_ -notmatch 'emulator'
    } | Select-Object -First 1

    if ($usbLine) {
        $usbSerial = ($usbLine -split "`t")[0].Trim()
        Write-Host "USB: $usbSerial -> enabling tcpip $Port" -ForegroundColor Green
        & $Adb -s $usbSerial tcpip $Port 2>&1 | Out-Null
        Start-Sleep 3
        & $Adb connect $Serial 2>&1 | Out-Null
    }

    & $Adb connect $Serial 2>&1 | Out-Null
    $devs = (& $Adb devices -l 2>&1) -join "`n"

    if ($devs -match ([regex]::Escape($Serial) + '\s+device')) {
        Write-Host "Connected: $Serial" -ForegroundColor Green
        & $Adb -s $Serial shell "getprop ro.product.model; getprop ro.product.cpu.abi; getprop ro.build.version.release" 2>$null
        $setupArgs = @("-Target", "tv", "-Launch")
        if ($MpkgPath) { $setupArgs += @("-MpkgPath", $MpkgPath) }
        if ($WeApkPath) { $setupArgs += @("-WeApkPath", $WeApkPath) }
        if (-not $Launch) { $setupArgs = $setupArgs | Where-Object { $_ -ne "-Launch" } }
        & (Join-Path $PSScriptRoot "setup-tcl-wallpaper.ps1") @setupArgs
        exit $LASTEXITCODE
    }

    # Any authorized device except emulator
    $any = ($devs -split "`n") | Where-Object {
        $_ -match '\tdevice' -and $_ -notmatch 'emulator'
    } | Select-Object -First 1
    if ($any -and $any -match '^([^\s]+)\s+device') {
        $s = $Matches[1]
        Write-Host "Using device $s (not spec IP - update tcl-tv-spec.json if needed)" -ForegroundColor Yellow
        $env:ANDROID_SERIAL = $s
        $setupArgs = @("-Target", "tv", "-Launch")
        if ($MpkgPath) { $setupArgs += @("-MpkgPath", $MpkgPath) }
        if ($WeApkPath) { $setupArgs += @("-WeApkPath", $WeApkPath) }
        & (Join-Path $PSScriptRoot "setup-tcl-wallpaper.ps1") @setupArgs
        exit $LASTEXITCODE
    }

    Write-Host "  ... still waiting ($(Get-Date -Format HH:mm:ss))" -ForegroundColor DarkGray
    Start-Sleep 5
}

Write-Host "Timeout. Checklist:" -ForegroundColor Red
Write-Host "  1. TV: Settings -> Developer -> USB debugging ON"
Write-Host "  2. USB cable: accept 'Allow USB debugging' on TV"
Write-Host "  3. TV IP: Settings -> Network -> note IP, run: .\connect-tv-deploy.ps1 -TvIp <IP>"
Write-Host "  4. Same WiFi as PC (PC is on 192.168.1.x)"
& $Adb devices -l
exit 1
