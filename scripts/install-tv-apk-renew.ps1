# Install APK on TCL TV when adb/pm install is blocked (install_switch_flag: 0).
# Uses com.tcl.packageinstaller.service.renew/.PackageInstallerService (system uid).
#
#   .\install-tv-apk-renew.ps1 -ApkPath ..\tcl-wallpaper\app\build\outputs\apk\debug\app-debug.apk -PackageName com.tclsystemfinder.wallpaper

param(
    [Parameter(Mandatory = $true)]
    [string]$ApkPath,
    [Parameter(Mandatory = $true)]
    [string]$PackageName,
    [string]$Serial = "",
    [int]$WaitSeconds = 30,
    [string]$VersionCode = "4240"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Spec = Get-Content (Join-Path $PSScriptRoot "tcl-tv-spec.json") -Raw -Encoding UTF8 | ConvertFrom-Json

$SdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "E:\AndroidSDK" }
$Adb = "$SdkRoot\platform-tools\adb.exe"
if (-not (Test-Path $Adb)) { throw "adb not found: $Adb" }
if (-not (Test-Path $ApkPath)) { throw "APK not found: $ApkPath" }

if (-not $Serial) {
    & (Join-Path $PSScriptRoot "adb-tv.ps1") connect-tv -Target tv | Out-Null
    $Serial = "$($Spec.adb.ip):$($Spec.adb.port)"
}

$name = [IO.Path]::GetFileName($ApkPath)
$remote = "/sdcard/Download/$name"

Write-Host "Push -> $remote" -ForegroundColor Cyan
& $Adb -s $Serial push $ApkPath $remote
if ($LASTEXITCODE -ne 0) { throw "adb push failed" }

Write-Host "Install via PackageInstallerRenew..." -ForegroundColor Yellow
& $Adb -s $Serial shell @(
    "am", "startservice",
    "-a", "com.tcl.packageinstaller.service.renew.PackageInstallerService",
    "-n", "com.tcl.packageinstaller.service.renew/.PackageInstallerService",
    "--es", "uri", "file://$remote",
    "--es", "currentPackageName", $PackageName,
    "--es", "version_code", $VersionCode
) | Out-Null

Start-Sleep -Seconds $WaitSeconds
$raw = & $Adb -s $Serial shell "pm path $PackageName" 2>$null
$path = if ($raw) { ($raw | Out-String).Trim() } else { "" }
if ($path) {
    Write-Host "[OK] $PackageName installed: $path" -ForegroundColor Green
    exit 0
}

Write-Host "[FAIL] $PackageName not found after install" -ForegroundColor Red
exit 1
