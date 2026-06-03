# 重建与 TCL 55A30-7CD6 规格对齐的 Android TV AVD
$ErrorActionPreference = "Stop"

$SdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "E:\AndroidSDK" }
$spec = Get-Content (Join-Path $PSScriptRoot "tcl-tv-spec.json") -Raw | ConvertFrom-Json
$AvdManager = "$SdkRoot\cmdline-tools\latest\bin\avdmanager.bat"
$package = "system-images;android-28;android-tv;x86"

$env:ANDROID_HOME = $SdkRoot
$env:ANDROID_SDK_ROOT = $SdkRoot

if (-not (Test-Path $AvdManager)) {
    Write-Host "请先完成 SDK 安装 (setup-android-tv.ps1)" -ForegroundColor Red
    exit 1
}

$oldNames = @("TCL_TV_Android9", $spec.avdName)
foreach ($name in $oldNames) {
    $list = & $AvdManager list avd 2>&1 | Out-String
    if ($list -match [regex]::Escape($name)) {
        Write-Host "删除旧 AVD: $name"
        echo "yes" | & $AvdManager delete avd -n $name 2>&1 | Out-Null
    }
}

Write-Host "创建 AVD: $($spec.avdName) [$($spec.display.profile), API $($spec.apiLevel)]"
echo "no" | & $AvdManager create avd `
    -n $spec.avdName `
    -k $package `
    -d $spec.display.profile `
    -f

& (Join-Path $PSScriptRoot "apply-tcl-profile.ps1")
Write-Host "完成。启动: .\start-emulator.ps1" -ForegroundColor Cyan
