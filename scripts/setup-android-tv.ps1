# TCL 55A30 / A972T01 - Android TV emulator + ADB setup
# Target: E:\AndroidSDK, Android 9 (API 28) Android TV image

$ErrorActionPreference = "Stop"

$SdkRoot = "E:\AndroidSDK"
$CmdlineZip = "$SdkRoot\downloads\commandlinetools-win.zip"
$CmdlineDir = "$SdkRoot\cmdline-tools\latest"
$ExistingPlatformTools = "E:\新建文件夹 (2)\AndroidSDK\platform-tools"

Write-Host "=== TCL Android TV Dev Environment ===" -ForegroundColor Cyan
Write-Host "SDK root: $SdkRoot"

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    Write-Host "[1/5] Installing OpenJDK 17..." -ForegroundColor Yellow
    winget install Microsoft.OpenJDK.17 --accept-package-agreements --accept-source-agreements --silent
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
} else {
    Write-Host "[1/5] JDK OK" -ForegroundColor Green
}

New-Item -ItemType Directory -Force -Path "$SdkRoot\downloads" | Out-Null
New-Item -ItemType Directory -Force -Path $CmdlineDir | Out-Null

if (Test-Path $ExistingPlatformTools) {
    if (-not (Test-Path "$SdkRoot\platform-tools\adb.exe")) {
        Write-Host "[2/5] Copying platform-tools..." -ForegroundColor Yellow
        Copy-Item -Path $ExistingPlatformTools -Destination "$SdkRoot\platform-tools" -Recurse -Force
    }
} else {
    Write-Host "[2/5] platform-tools will be installed via sdkmanager" -ForegroundColor Yellow
}

if (-not (Test-Path "$CmdlineDir\bin\sdkmanager.bat")) {
    Write-Host "[3/5] Downloading command-line tools..." -ForegroundColor Yellow
    $urls = @(
        "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip",
        "https://dl.google.com/android/repository/commandlinetools-win-10406996_latest.zip"
    )
    $downloaded = $false
    foreach ($url in $urls) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $CmdlineZip -UseBasicParsing -TimeoutSec 120
            $downloaded = $true
            break
        } catch {
            Write-Host "  failed: $url" -ForegroundColor DarkYellow
        }
    }
    if (-not $downloaded) { throw "Download failed. Put cmdline-tools under $CmdlineDir" }

    Expand-Archive -Path $CmdlineZip -DestinationPath "$SdkRoot\cmdline-tools\_tmp" -Force
    $inner = Get-ChildItem "$SdkRoot\cmdline-tools\_tmp" -Recurse -Filter "sdkmanager.bat" | Select-Object -First 1
    if ($inner.Directory.Parent.Name -eq "bin") {
        Copy-Item -Path "$($inner.Directory.Parent.Parent.FullName)\*" -Destination $CmdlineDir -Recurse -Force
    } else {
        Copy-Item -Path "$SdkRoot\cmdline-tools\_tmp\*" -Destination $CmdlineDir -Recurse -Force
    }
    Remove-Item "$SdkRoot\cmdline-tools\_tmp" -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "[3/5] cmdline-tools OK" -ForegroundColor Green
}

$env:ANDROID_HOME = $SdkRoot
$env:ANDROID_SDK_ROOT = $SdkRoot
$SdkManager = "$CmdlineDir\bin\sdkmanager.bat"
$AvdManager = "$CmdlineDir\bin\avdmanager.bat"

Write-Host "[4/5] Installing SDK packages (1-2 GB)..." -ForegroundColor Yellow
$packages = @(
    'platform-tools'
    'emulator'
    'platforms;android-28'
    'build-tools;28.0.3'
    'system-images;android-28;android-tv;x86'
)
$yes = ("y" * 8) -join "`n"
$yes | & $SdkManager --sdk_root=$SdkRoot @packages

Write-Host "[5/5] Creating AVD..." -ForegroundColor Yellow
$avdName = "TCL_TV_Android9"
$avdExists = & $AvdManager list avd 2>&1 | Select-String $avdName
if (-not $avdExists) {
    echo "no" | & $AvdManager create avd -n $avdName -k 'system-images;android-28;android-tv;x86' -d "tv_1080p" -f
}

[Environment]::SetEnvironmentVariable("ANDROID_HOME", $SdkRoot, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $SdkRoot, "User")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$addPaths = @(
    "$SdkRoot\platform-tools"
    "$SdkRoot\emulator"
    "$CmdlineDir\bin"
)
foreach ($p in $addPaths) {
    if ($userPath -notlike "*$p*") {
        $userPath = $userPath + ";" + $p
    }
}
[Environment]::SetEnvironmentVariable("Path", $userPath, "User")

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "Restart terminal, then: .\scripts\start-emulator.ps1"
Write-Host ("ADB: " + $SdkRoot + "\platform-tools\adb.exe")
