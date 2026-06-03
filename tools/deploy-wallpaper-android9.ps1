# 已弃用：请用 scripts\setup-tcl-wallpaper.ps1（TCL 真机专用）
# Deploy Wallpaper Engine (.mpkg) to Android 8.1+ / 9 / TV via adb.
# Official WE mobile app minSdk is API 27 (8.1); Android 9 is supported when sideloading the APK.
#
# Usage:
#   .\deploy-wallpaper-android9.ps1 -MpkgPath "C:\Users\Brs\Desktop\3428398966.mpkg"
#   .\deploy-wallpaper-android9.ps1 -MpkgPath "..." -WeApkPath "D:\Downloads\wallpaper-engine-2.7.4.apkm"
#
# Get APK: https://www.apkmirror.com/apk/wallpaper-engine-team/wallpaper-engine/
# Pick arm64-v8a split or universal bundle for real TV/phone (not x86 emulator).

param(
    [Parameter(Mandatory = $false)]
    [string]$MpkgPath = "",
    [string]$WeApkPath = "",
    [string]$Adb = "E:\AndroidSDK\platform-tools\adb.exe",
    [switch]$LightTvPreview,
    [switch]$SkipWeInstall
)

$ErrorActionPreference = "Stop"

$tclSetup = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\setup-tcl-wallpaper.ps1"
if (Test-Path $tclSetup) {
    $fwd = @{ MpkgPath = $MpkgPath }
    if ($WeApkPath) { $fwd["WeApkPath"] = $WeApkPath }
    if ($SkipWeInstall) { $fwd["SkipWe"] = $true }
    if ($MpkgPath) { & $tclSetup @fwd; exit $LASTEXITCODE }
}

if (-not $MpkgPath) { throw "请使用 scripts\setup-tcl-wallpaper.ps1 或提供 -MpkgPath" }
if (-not (Test-Path $MpkgPath)) { throw "mpkg not found: $MpkgPath" }
if (-not (Test-Path $Adb)) { throw "adb not found: $Adb" }

$abi = & $Adb shell getprop ro.product.cpu.abi 2>$null
$abi = ($abi -join "").Trim()
$release = (& $Adb shell getprop ro.build.version.release 2>$null).Trim()
$sdk = (& $Adb shell getprop ro.build.version.sdk 2>$null).Trim()
Write-Host "Device: Android $release (SDK $sdk), ABI $abi"

if ([int]$sdk -lt 27) {
    Write-Warning "SDK $sdk < 27: official Wallpaper Engine requires Android 8.1+. Use LightTV (-LightTvPreview) instead."
}

$mpkgName = [IO.Path]::GetFileName($MpkgPath)
Write-Host "Pushing $mpkgName -> /sdcard/Download/ (official app import path)..."
& $Adb shell "mkdir -p /sdcard/Download"
& $Adb push $MpkgPath "/sdcard/Download/$mpkgName"

if (-not $SkipWeInstall -and $WeApkPath -ne "") {
    if (-not (Test-Path $WeApkPath)) { throw "APK not found: $WeApkPath" }
    Write-Host "Installing Wallpaper Engine APK..."
    if ($WeApkPath -match '\.(xapk|apkm)$') {
        Write-Warning "Bundle install: install APKMirror Installer or extract base APK from bundle first."
        Write-Warning "  Or: adb install-multiple base.apk split_config.*.apk"
    } else {
        & $Adb install -r $WeApkPath
    }
}

$wePkg = "io.wallpaperengine.weclient"
$installed = & $Adb shell pm path $wePkg 2>$null
if ($installed) {
    Write-Host "Wallpaper Engine installed. Launch app -> Import file -> /sdcard/Download/$mpkgName"
    & $Adb shell monkey -p $wePkg -c android.intent.category.LAUNCHER 1 2>$null | Out-Null
} else {
    Write-Host "Wallpaper Engine (io.wallpaperengine.weclient) not installed."
    Write-Host "Sideload arm64 APK from APKMirror (Android 8.1+), then re-run with -WeApkPath"
}

if ($LightTvPreview) {
    $weRust = "E:\TCL_system_finder\we-rust-ref\target\release\linux-wallpaper-engine.exe"
    $outDir = "E:\TCL_system_finder\picture\mpkg_deploy_$([IO.Path]::GetFileNameWithoutExtension($mpkgName))"
    $pkgCopy = Join-Path $env:TEMP "deploy_scene.pkg"
    Copy-Item $MpkgPath $pkgCopy -Force
    if (Test-Path $weRust) {
        if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
        & $weRust parser -p $pkgCopy -x $outDir 2>&1 | Out-Null
        $id = [IO.Path]::GetFileNameWithoutExtension($mpkgName)
        $remote = "/sdcard/lightos/wallpapers/$id"
        & $Adb shell "mkdir -p /sdcard/lightos/wallpapers"
        & $Adb push $outDir $remote
        & $Adb shell "echo $remote > /sdcard/lightos/wallpapers/active"
        $apk = "E:\TCL_system_finder\lighttv\app\build\outputs\apk\full\debug\app-full-debug.apk"
        if (Test-Path $apk) {
            & $Adb install -r $apk 2>$null | Out-Null
            & $Adb shell am start -n com.lighttv.system/.ScenePreviewActivity --es wallpaper_dir $remote
            Write-Host "LightTV preview started: $remote"
        }
    }
}

Write-Host "Done. On device: open Wallpaper Engine -> Import -> pick Download\$mpkgName"
