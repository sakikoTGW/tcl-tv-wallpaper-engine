# Start emulator with writable /system for TCL build.prop + priv-app injection
$SdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "E:\AndroidSDK" }
$Emulator = "$SdkRoot\emulator\emulator.exe"
$spec = Get-Content (Join-Path $PSScriptRoot "tcl-tv-spec.json") -Raw | ConvertFrom-Json
$AvdName = $spec.avdName

if (-not (Test-Path $Emulator)) {
    Write-Host "Run setup-android-tv.ps1 first" -ForegroundColor Red
    exit 1
}

$configIni = Join-Path $env:USERPROFILE ".android\avd\$AvdName.avd\config.ini"
if (-not (Test-Path $configIni)) {
    & (Join-Path $PSScriptRoot "recreate-tcl-avd.ps1")
}

$args = @(
    "-avd", $AvdName
    "-writable-system"
    "-memory", "$($spec.ramMb)"
    "-no-snapshot-save"
    "-netdelay", "none"
    "-netspeed", "full"
    "-gpu", "auto"
    "-skin", "$($spec.display.width)x$($spec.display.height)"
)

Write-Host "Starting $AvdName with -writable-system (for TCL injection)" -ForegroundColor Cyan
Start-Process -FilePath $Emulator -ArgumentList $args -WindowStyle Normal

$Adb = "$SdkRoot\platform-tools\adb.exe"
Write-Host "Waiting for ADB..."
for ($i = 0; $i -lt 60; $i++) {
    $d = & $Adb devices 2>&1 | Out-String
    if ($d -match "emulator-\d+\s+device") { break }
    Start-Sleep 3
}

Write-Host "Run: .\inject-tcl-system.ps1" -ForegroundColor Green
