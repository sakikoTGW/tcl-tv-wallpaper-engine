# Wait for TV ADB without kill-server
param(
    [string]$Ip = '192.168.1.8',
    [int]$Port = 5555,
    [int]$MaxWaitSec = 300,
    [string]$Then = ''
)

$Adb = if ($env:ANDROID_HOME) { "$env:ANDROID_HOME\platform-tools\adb.exe" } else { 'E:\AndroidSDK\platform-tools\adb.exe' }
$Serial = "${Ip}:${Port}"
$deadline = (Get-Date).AddSeconds($MaxWaitSec)

while ((Get-Date) -lt $deadline) {
    & $Adb connect $Serial 2>&1 | Out-Null
    $d = (& $Adb devices 2>&1) -join "`n"
    if ($d -match ([regex]::Escape($Serial) + '\s+device')) {
        Write-Host "OK: $Serial device" -ForegroundColor Green
        if ($Then) {
            Invoke-Expression $Then
        } else {
            & $Adb -s $Serial shell 'id; getprop ro.product.model; ls -la /sdcard/Download/magisk_patched-rootsys.img 2>&1'
        }
        exit 0
    }
    Start-Sleep 5
}

Write-Host "Timeout: $Serial not device after ${MaxWaitSec}s" -ForegroundColor Red
& $Adb devices -l
exit 1
