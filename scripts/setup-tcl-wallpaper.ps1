# Deploy TCL wallpaper bridge to emulator (-Target emu) or TV (-Target tv)
#   .\setup-tcl-wallpaper.ps1 -Target emu -Launch

param(
    [ValidateSet("tv", "emu", "auto")]
    [string]$Target = "emu",
    [string]$MpkgPath = "",
    [string]$WeApkPath = "",
    [switch]$SkipBridge,
    [switch]$SkipWe,
    [switch]$Launch,
    [switch]$VerifyOnly
)

# adb writes progress to stderr; use Continue + explicit exit code checks
$ErrorActionPreference = "Continue"
function Invoke-AdbQuiet {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$AdbArgs)
    $null = & $Adb @AdbArgs 2>$null
    if ($LASTEXITCODE -ne 0) { throw "adb failed ($LASTEXITCODE): $AdbArgs" }
}
function Require-ZeroExit($msg) {
    if ($LASTEXITCODE -ne 0) { throw $msg }
}
$Root = Split-Path $PSScriptRoot -Parent
$SpecPath = Join-Path $PSScriptRoot "tcl-tv-spec.json"
$Spec = Get-Content $SpecPath -Raw -Encoding UTF8 | ConvertFrom-Json

$SdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "E:\AndroidSDK" }
$Adb = "$SdkRoot\platform-tools\adb.exe"
if (-not (Test-Path $Adb)) { throw "adb not found: $Adb" }

function Get-EmuSerial {
    foreach ($line in (& $Adb devices 2>&1)) {
        if ($line -match "^(emulator-\d+)\s+device") { return $Matches[1] }
    }
    return $null
}

function Wait-DeviceBoot {
    Write-Host "Waiting for emulator boot..." -ForegroundColor Yellow
    & $Adb wait-for-device | Out-Null
    $deadline = (Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $deadline) {
        $boot = (& $Adb shell getprop sys.boot_completed 2>$null).Trim()
        if ($boot -eq "1") { return }
        Start-Sleep -Seconds 2
    }
    throw "Emulator boot timeout"
}

if ($Target -eq "auto") {
    $emu = Get-EmuSerial
    if ($emu) { $Target = "emu" } else { $Target = "tv" }
}

if ($Target -eq "emu") {
    $serial = Get-EmuSerial
    if (-not $serial) {
        Write-Host "Starting AVD $($Spec.avdName) ..." -ForegroundColor Yellow
        $emuExe = "$SdkRoot\emulator\emulator.exe"
        if (-not (Test-Path $emuExe)) { throw "emulator.exe missing" }
        Start-Process -FilePath $emuExe -ArgumentList @("-avd", $Spec.avdName, "-netdelay", "none", "-netspeed", "full") -WindowStyle Minimized
        Wait-DeviceBoot
        $serial = Get-EmuSerial
        if (-not $serial) { throw "Emulator not ready" }
    }
    $env:ANDROID_SERIAL = $serial
    Write-Host "Target: emulator $serial" -ForegroundColor Cyan
}
else {
    & (Join-Path $PSScriptRoot "adb-tv.ps1") connect-tv -Target tv | Out-Null
    $env:ANDROID_SERIAL = "$($Spec.adb.ip):$($Spec.adb.port)"
    Write-Host "Target: TV $env:ANDROID_SERIAL" -ForegroundColor Cyan
}

$abi = (& $Adb shell getprop ro.product.cpu.abi 2>$null).Trim()
$sdk = (& $Adb shell getprop ro.build.version.sdk 2>$null).Trim()
$model = (& $Adb shell getprop ro.product.model 2>$null).Trim()
Write-Host "Device: $model | SDK $sdk | ABI $abi" -ForegroundColor Cyan

if ([int]$sdk -lt 27) { throw "API $sdk too low (need 27+)" }

$isEmuX86 = $abi -match "x86"

if (-not $MpkgPath) {
    $candidates = @(
        "C:\Users\Brs\Desktop\3428398966.mpkg",
        (Join-Path $Root "picture\3428398966.pkg"),
        (Join-Path $Root "picture\3629379075\scene.pkg")
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $MpkgPath = $c; break }
    }
}

if (-not $SkipBridge -and -not $VerifyOnly) {
    $BridgeDir = Join-Path $Root "tcl-wallpaper"
    $ApkDebug = Join-Path $BridgeDir "app\build\outputs\apk\debug\app-debug.apk"
    $Gradlew = Join-Path $Root "lighttv\gradlew.bat"

    if (-not (Test-Path $ApkDebug)) {
        Write-Host "Building tcl-wallpaper (x86 + armeabi-v7a debug)..." -ForegroundColor Yellow
        Push-Location $BridgeDir
        & $Gradlew assembleDebug
        Pop-Location
        Require-ZeroExit "Gradle build failed"
    }

    if (-not (Test-Path $ApkDebug)) { throw "APK missing: $ApkDebug" }

    if ($Target -eq "tv") {
        & (Join-Path $PSScriptRoot "install-tv-apk-renew.ps1") `
            -ApkPath $ApkDebug `
            -PackageName $Spec.wallpaper.bridgePackage `
            -Serial $env:ANDROID_SERIAL
    }
    else {
        $installOut = & $Adb install -r $ApkDebug 2>&1 | Out-String
        if ($installOut -notmatch "Success") {
            Write-Host $installOut -ForegroundColor Red
            throw "adb install failed"
        }
    }
    Write-Host "Bridge APK installed." -ForegroundColor Green
}

if ($MpkgPath -and (Test-Path $MpkgPath)) {
    $name = [IO.Path]::GetFileName($MpkgPath)
    if ($name -notmatch '\.(mpkg|pkg)$') { $name = "$name.mpkg" }
    & $Adb shell "mkdir -p /sdcard/Download"
    Write-Host "Push -> /sdcard/Download/$name" -ForegroundColor Green
    Invoke-AdbQuiet push $MpkgPath "/sdcard/Download/$name"
}
elseif (-not $VerifyOnly) {
    Write-Warning "No mpkg found; pass -MpkgPath"
}

if (-not $SkipWe -and $WeApkPath -ne "") {
    if ($isEmuX86) {
        Write-Warning "Skipping official WE on x86 emulator (ARM only)"
    }
    elseif (-not (Test-Path $WeApkPath)) { throw "WE APK not found: $WeApkPath" }
    elseif ($Target -eq "tv") {
        & (Join-Path $PSScriptRoot "install-tv-apk-renew.ps1") `
            -ApkPath $WeApkPath `
            -PackageName $Spec.wallpaper.wePackage `
            -Serial $env:ANDROID_SERIAL `
            -WaitSeconds 60
    }
    else {
        & $Adb install -r $WeApkPath
    }
}

$bridgePkg = $Spec.wallpaper.bridgePackage

if ($Launch) {
    Invoke-AdbQuiet shell am start -n "$bridgePkg/.WallpaperTvActivity" | Out-Null
    Start-Sleep -Seconds 2
    if ($isEmuX86) {
        Invoke-AdbQuiet shell am start -n "$bridgePkg/.EmulatorVerifyActivity" | Out-Null
    }
}

Write-Host ""
Write-Host "=== Verify ===" -ForegroundColor Cyan
$pkgInstalled = & $Adb shell pm path $bridgePkg 2>$null
if ($pkgInstalled) { Write-Host "[OK] bridge installed" -ForegroundColor Green }
else { Write-Host "[FAIL] bridge not installed" -ForegroundColor Red }

$ls = & $Adb shell "ls -la /sdcard/Download/*.mpkg /sdcard/Download/*.pkg 2>/dev/null; true" 2>$null
if ($ls) {
    Write-Host "[OK] wallpaper in Download:" -ForegroundColor Green
    $ls | ForEach-Object { Write-Host "  $_" }
}
else {
    Write-Host "[WARN] no mpkg in Download" -ForegroundColor Yellow
}

if ($isEmuX86) {
    Write-Host ""
    Write-Host "Emulator flow OK. Open bridge app -> verify page shows PKGM magic." -ForegroundColor Green
    Write-Host "Real WE playback needs ARM TV: -Target tv -WeApkPath ..." -ForegroundColor DarkYellow
}
else {
    Write-Host "TV: open bridge -> pick mpkg -> official WE Import" -ForegroundColor Green
}

exit 0
