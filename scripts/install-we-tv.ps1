# Install Wallpaper Engine on TCL Android 9 TV (API 28, armeabi-v7a)
param(
    [string]$Serial = "192.168.1.11:5555",
    [switch]$SkipFreeSpace,
    [switch]$Launch
)

$ErrorActionPreference = "Continue"
$Root = Split-Path $PSScriptRoot -Parent
$Adb = "E:\AndroidSDK\platform-tools\adb.exe"
$Apk = Join-Path $Root "firmware\apk\wallpaper-engine-2.7.4-v7a.apk"
$BuildScript = Join-Path $PSScriptRoot "build-we-274-v7a.ps1"

function Require-Adb($cmd) {
    $null = & $Adb -s $Serial @cmd 2>$null
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $cmd" }
}

& $Adb connect $Serial 2>$null | Out-Null

if (-not (Test-Path $Apk)) {
    if (-not (Test-Path $BuildScript)) { throw "Run fetch-we-274.ps1 then build-we-274-v7a.ps1 first" }
    & $BuildScript
}

& $Adb connect $Serial 2>$null | Out-Null

& $Adb -s $Serial shell pm enable io.wallpaperengine.weclient 2>$null | Out-Null

Write-Host "Installing WE via PackageInstallerRenew (bypasses install_switch)..." -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "install-tv-apk-renew.ps1") -ApkPath $Apk -PackageName io.wallpaperengine.weclient -Serial $Serial -WaitSeconds 60

if ($Launch) {
    & $Adb -s $Serial shell monkey -p io.wallpaperengine.weclient -c android.intent.category.LAUNCHER 1 2>$null
    & $Adb -s $Serial shell am start -n com.tclsystemfinder.wallpaper/.WallpaperTvActivity 2>$null
}

Write-Host "Import: WE -> Import file -> /sdcard/Download/3428398966.mpkg" -ForegroundColor Yellow
