# Enable APK install on TCL hotel firmware via setprop (no ROOT required on many builds)
param(
    [string]$Serial = "192.168.1.8:5555",
    [switch]$SkipConnect
)

$SdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "E:\AndroidSDK" }
$Adb = "$SdkRoot\platform-tools\adb.exe"

function Invoke-Adb([string[]]$AdbArgs, [switch]$NoSerial) {
    $cmd = if ($NoSerial) { @($AdbArgs) } else { @("-s", $Serial) + @($AdbArgs) }
    & $Adb $cmd 2>&1 | ForEach-Object { "$_" }
}

if (-not $SkipConnect -and $Serial -match ":") {
    Invoke-Adb "connect", $Serial -NoSerial | Out-Null
    Start-Sleep 1
}

Write-Host "Enabling TCL APK install flags..." -ForegroundColor Cyan
Invoke-Adb "shell", "setprop persist.tcl.debug.installapk 1"
Invoke-Adb "shell", "setprop persist.tcl.installapk.enable 1"

$p1 = (Invoke-Adb "shell", "getprop persist.tcl.debug.installapk") -join ""
$p2 = (Invoke-Adb "shell", "getprop persist.tcl.installapk.enable") -join ""
Write-Host "  persist.tcl.debug.installapk = $p1"
Write-Host "  persist.tcl.installapk.enable = $p2"

if ($p1 -eq "1" -and $p2 -eq "1") {
    Write-Host "Install gate open (non-launcher APKs)." -ForegroundColor Green
} else {
    Write-Host "setprop failed — need Sita P / ROOT." -ForegroundColor Yellow
}
