# ADB 便捷脚本 — 电视 / 模拟器双目标
param(
    [Parameter(Position = 0)]
    [string]$Command = "devices",
    [string]$Target = "auto",   # auto | tv | emu
    [string]$TvIp = "",
    [int]$TvPort = 0
)

$specPath = Join-Path $PSScriptRoot "tcl-tv-spec.json"
if (Test-Path $specPath) {
    $tclSpec = Get-Content $specPath -Raw | ConvertFrom-Json
    if (-not $TvIp) { $TvIp = $tclSpec.adb.ip }
    if (-not $TvPort) { $TvPort = [int]$tclSpec.adb.port }
}
if (-not $TvIp) { $TvIp = "192.168.1.8" }
if (-not $TvPort) { $TvPort = 5555 }

$SdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "E:\AndroidSDK" }
$Adb = "$SdkRoot\platform-tools\adb.exe"
if (-not (Test-Path $Adb)) {
    $Adb = "E:\新建文件夹 (2)\AndroidSDK\platform-tools\adb.exe"
}

function Connect-Tv {
    Write-Host "尝试连接电视 $TvIp`:$TvPort ..." -ForegroundColor Yellow
    & $Adb connect "${TvIp}:${TvPort}"
}

function Get-EmuSerial {
    $lines = & $Adb devices 2>&1
    foreach ($line in $lines) {
        if ($line -match "^(emulator-\d+)\s+device") { return $Matches[1] }
    }
    return $null
}

switch ($Target) {
    "tv" {
        Connect-Tv
        $env:ANDROID_SERIAL = "${TvIp}:${TvPort}"
    }
    "emu" {
        $serial = Get-EmuSerial
        if (-not $serial) {
            Write-Host "未检测到运行中的模拟器，请先 start-emulator.ps1" -ForegroundColor Red
            exit 1
        }
        $env:ANDROID_SERIAL = $serial
    }
    "auto" {
        $emu = Get-EmuSerial
        if ($emu) {
            $env:ANDROID_SERIAL = $emu
            Write-Host "使用模拟器: $emu" -ForegroundColor Cyan
        } else {
            Connect-Tv
            $env:ANDROID_SERIAL = "${TvIp}:${TvPort}"
        }
    }
}

if ($Command -eq "devices") {
    & $Adb devices -l
} elseif ($Command -eq "shell") {
    & $Adb shell
} elseif ($Command -eq "connect-tv") {
    Connect-Tv
    & $Adb devices -l
} elseif ($Command -eq "install" -and $args.Count -gt 0) {
    & $Adb install -r $args[0]
} else {
    & $Adb @($Command.Split(" ") + $args)
}
