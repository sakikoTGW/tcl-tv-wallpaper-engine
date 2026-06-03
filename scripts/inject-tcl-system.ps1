# Pull system apps from TV via ADB, or extract from dropped firmware, then inject into emulator.
# Requires: emulator running with -writable-system (see start-emulator-tcl.ps1)

$ErrorActionPreference = "Stop"

function Invoke-Adb {
    param([string[]]$AdbArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & $Adb @AdbArgs 2>&1
    $ErrorActionPreference = $prev
    return $out
}

$Root = Split-Path $PSScriptRoot -Parent
$FirmwareDir = Join-Path $Root "firmware"
$ExtractDir = Join-Path $Root "extracted"
$ApkDir = Join-Path $Root "tcl-apks"
$SdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "E:\AndroidSDK" }
$Adb = "$SdkRoot\platform-tools\adb.exe"
$spec = Get-Content (Join-Path $PSScriptRoot "tcl-tv-spec.json") -Raw | ConvertFrom-Json

$tclPackages = @(
    "com.tcl.tv"
    "com.tcl.dashboard"
    "com.tcl.ui_mediaCenter"
    "com.tcl.hotelmenu"
    "com.tcl.guard"
    "com.tcl.partnercustomizer"
    "com.tcl.channelplus"
    "com.tcl.waterfall.overseas"
    "com.tcl.useragreement"
    "com.tcl.initsetup"
    "com.tcl.system.server"
    "com.tcl.providers.config"
    "com.tcl.ttvs"
    "com.tvos"
)

New-Item -ItemType Directory -Force -Path $FirmwareDir, $ExtractDir, $ApkDir | Out-Null

function Ensure-EmulatorWritable {
    $dev = & $Adb devices 2>&1 | Out-String
    if ($dev -notmatch "emulator-\d+\s+device") {
        throw "No emulator online. Run start-emulator-tcl.ps1 first."
    }
    & $Adb root 2>&1 | Out-Null
    Start-Sleep 2
    $rem = (Invoke-Adb @("remount")) -join "`n"
    if ($rem -match "Permission denied|failed") {
        throw "adb remount failed. Restart emulator with: start-emulator-tcl.ps1 (uses -writable-system)"
    }
}

function Patch-BuildProp {
    Write-Host "[1/4] Patching /system/build.prop ..." -ForegroundColor Cyan
    $localProp = Join-Path $ExtractDir "build.prop"
    $null = Invoke-Adb @("pull", "/system/build.prop", $localProp)
    if (-not (Test-Path $localProp)) {
        $null = Invoke-Adb @("pull", "/default.prop", $localProp)
    }
    if (-not (Test-Path $localProp)) { throw "Cannot pull build.prop" }

    $lines = Get-Content $localProp
    $overrides = [ordered]@{
        "ro.product.manufacturer" = "TCL"
        "ro.product.brand"        = "TCL"
        "ro.product.model"        = $spec.model
        "ro.product.device"       = $spec.chipset
        "ro.product.name"         = $spec.chipset
        "ro.build.product"        = $spec.chipset
        "ro.build.display.id"     = $spec.firmware
        "ro.build.description"    = "$($spec.chipset)-user 9 $($spec.firmware) release-keys"
        "ro.build.fingerprint"    = "TCL/$($spec.chipset)/$($spec.chipset):9/$($spec.firmware)/user/release-keys"
    }
    foreach ($k in $overrides.Keys) {
        $v = $overrides[$k]
        $found = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "^$([regex]::Escape($k))=") {
                $lines[$i] = "$k=$v"
                $found = $true
                break
            }
        }
        if (-not $found) { $lines += "$k=$v" }
    }
    $lines | Set-Content $localProp -Encoding ASCII
    $null = Invoke-Adb @("push", $localProp, "/system/build.prop")
    $null = Invoke-Adb @("shell", "chmod", "644", "/system/build.prop")
    Write-Host "  build.prop patched" -ForegroundColor Green
}

function Disable-GoogleLauncher {
    Write-Host "[2/4] Disable Google launcher (only if TCL/alt launcher installed)..." -ForegroundColor Cyan
    $hasHome = (Invoke-Adb @("shell", "pm", "query-activities", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.HOME")) -join "`n"
    $alt = @("me.efesser.flauncher", "com.tcl.dashboard", "com.tcl.ui_mediaCenter", "com.dangbei.tvlauncher")
    $hasAlt = $false
    foreach ($p in $alt) { if ($hasHome -match $p) { $hasAlt = $true; break } }
    if (-not $hasAlt) {
        Write-Host "  Skip disable - no replacement launcher ready" -ForegroundColor Yellow
        return
    }
    $launchers = @(
        "com.google.android.tvlauncher"
        "com.google.android.apps.tv.launcherx"
        "com.google.android.leanbacklauncher"
    )
    foreach ($pkg in $launchers) {
        $null = Invoke-Adb @("shell", "pm", "disable-user", "--user", "0", $pkg)
    }
}

function Install-TclApks {
    Write-Host "[3/4] Install TCL APKs from $ApkDir ..." -ForegroundColor Cyan
    $apks = Get-ChildItem $ApkDir -Filter "*.apk" -ErrorAction SilentlyContinue
    if (-not $apks) {
        Write-Host "  No APKs in tcl-apks/ - drop extracted apps or run extract-tcl-firmware.ps1" -ForegroundColor Yellow
        return 0
    }
    $n = 0
    foreach ($apk in $apks) {
        $r = (Invoke-Adb @("install", "-r", "-g", $apk.FullName)) -join " "
        if ($r -match "Success") {
            Write-Host "  OK $($apk.Name)" -ForegroundColor Green
            $n++
        } else {
            Write-Host "  FAIL $($apk.Name): $($r.Trim())" -ForegroundColor DarkYellow
        }
    }
    return $n
}

function Set-TclLauncher {
    param([string]$Package, [string]$Activity)
    if (-not $Package) {
        foreach ($c in @("com.tcl.dashboard", "com.tcl.ui_mediaCenter", "com.tcl.tv")) {
            $act = (Invoke-Adb @("shell", "cmd", "package", "resolve-activity", "--brief", $c)) -join "`n"
            if ($act -match "$c/") {
                $Package = $c
                $Activity = ($act -split "\s+")[-1]
                break
            }
        }
    }
    if ($Package -and $Activity) {
        Write-Host "[4/4] Set home: $Activity" -ForegroundColor Cyan
        $null = Invoke-Adb @("shell", "cmd", "package", "set-home-activity", $Activity)
    } else {
        Write-Host "[4/4] No TCL launcher found - keep Google launcher or install APK to tcl-apks/" -ForegroundColor Yellow
    }
}

Ensure-EmulatorWritable
Patch-BuildProp
Disable-GoogleLauncher
$installed = Install-TclApks
Set-TclLauncher

Write-Host ""
Write-Host "Done. Reboot emulator to apply build.prop fully:" -ForegroundColor Green
Write-Host "  adb reboot"
Write-Host "Verify: .\verify-tcl-match.ps1"
