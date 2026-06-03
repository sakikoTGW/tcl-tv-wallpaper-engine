# 启动与 TCL 55A30-7CD6 参数对齐的 Android TV 模拟器
# 日常开发用 start-emulator.ps1
# 要改 /system/build.prop 注入 TCL 标识请用 start-emulator-tcl.ps1（带 -writable-system）
$SdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "E:\AndroidSDK" }
$Emulator = "$SdkRoot\emulator\emulator.exe"
$spec = Get-Content (Join-Path $PSScriptRoot "tcl-tv-spec.json") -Raw | ConvertFrom-Json
$AvdName = $spec.avdName

if (-not (Test-Path $Emulator)) {
    Write-Host "未找到模拟器，请先运行 setup-android-tv.ps1" -ForegroundColor Red
    exit 1
}

$configIni = Join-Path $env:USERPROFILE ".android\avd\$AvdName.avd\config.ini"
if (-not (Test-Path $configIni)) {
    Write-Host "AVD 未配置，正在重建..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "recreate-tcl-avd.ps1")
}

$props = @(
    "-prop", "ro.product.manufacturer=TCL"
    "-prop", "ro.product.brand=TCL"
    "-prop", "ro.product.model=$($spec.model)"
    "-prop", "ro.product.device=$($spec.chipset)"
    "-prop", "ro.product.name=$($spec.chipset)"
    "-prop", "ro.build.version.release=$($spec.androidVersion)"
    "-prop", "ro.build.version.sdk=$($spec.apiLevel)"
    "-prop", "ro.build.display.id=$($spec.firmware)"
    "-prop", "ro.build.product=$($spec.chipset)"
)

$args = @(
    "-avd", $AvdName
    "-memory", "$($spec.ramMb)"
    "-netdelay", "none"
    "-netspeed", "full"
    "-gpu", "auto"
    "-skin", "$($spec.display.width)x$($spec.display.height)"
) + $props

Write-Host "启动 $AvdName | Android $($spec.androidVersion) | $($spec.ramMb)MB | $($spec.display.width)x$($spec.display.height)" -ForegroundColor Cyan
Write-Host "注: AOSP TV 镜像，非 TCL ROM；CPU 为 x86 非 ARM" -ForegroundColor DarkYellow
& $Emulator @args
