# Compare emulator props vs TCL 55A30-7CD6 target
$SdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "E:\AndroidSDK" }
$Adb = "$SdkRoot\platform-tools\adb.exe"
$spec = Get-Content (Join-Path $PSScriptRoot "tcl-tv-spec.json") -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "=== TCL target vs emulator ===" -ForegroundColor Cyan

$rows = @(
    @("manufacturer", "TCL", (& $Adb shell getprop ro.product.manufacturer).Trim()),
    @("brand", "TCL", (& $Adb shell getprop ro.product.brand).Trim()),
    @("model", $spec.model, (& $Adb shell getprop ro.product.model).Trim()),
    @("device/chip", $spec.chipset, (& $Adb shell getprop ro.product.device).Trim()),
    @("Android", $spec.androidVersion, (& $Adb shell getprop ro.build.version.release).Trim()),
    @("API", "$($spec.apiLevel)", (& $Adb shell getprop ro.build.version.sdk).Trim()),
    @("firmware id", $spec.firmware, (& $Adb shell getprop ro.build.display.id).Trim()),
    @("CPU ABI", "armeabi-v7a/arm64", (& $Adb shell getprop ro.product.cpu.abi).Trim())
)

foreach ($r in $rows) {
    $tag = if ($r[1] -eq $r[2]) { "[OK]" } else { "[!!]" }
    $c = if ($tag -eq "[OK]") { "Green" } else { "Yellow" }
    Write-Host ("{0,-14} target={1,-22} actual={2} {3}" -f $r[0], $r[1], $r[2], $tag) -ForegroundColor $c
}

Write-Host ""
Write-Host "MemTotal: $((& $Adb shell cat /proc/meminfo 2>$null | Select-String MemTotal).Line)"
$wm = & $Adb shell wm size 2>$null
if ($wm) { Write-Host "Screen  : $($wm.Trim())" } else { Write-Host "Screen  : (wm not ready)" }
Write-Host "Storage : config.ini dataPartition=8192MB (emulator userdata)"
Write-Host ""
