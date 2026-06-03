# Build installable WE 2.7.4 monolithic armeabi-v7a APK from APKM parts.
param(
    [string]$ApkmDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "firmware\apk\we274"),
    [string]$OutApk = (Join-Path (Split-Path $PSScriptRoot -Parent) "firmware\apk\wallpaper-engine-2.7.4-v7a.apk")
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Base = Join-Path $ApkmDir "base.apk"
$Split = Join-Path $ApkmDir "split_config.armeabi_v7a.apk"
$Decode = Join-Path $ApkmDir "..\we274_decode"
$Apktool = Join-Path $Root "tools\apktool.jar"
$Bt = "E:\AndroidSDK\build-tools\30.0.3"
$Unsigned = "$OutApk.unsigned"
$Aligned = "$OutApk.aligned"

foreach ($p in @($Base, $Split, $Apktool, "$Bt\apksigner.bat")) {
    if (-not (Test-Path $p)) { throw "Missing: $p" }
}

if (Test-Path $Decode) { Remove-Item -Recurse -Force $Decode }
java -jar $Apktool d -f -o $Decode $Base | Out-Null

$manifest = Join-Path $Decode "AndroidManifest.xml"
$xml = Get-Content $manifest -Raw -Encoding UTF8
$xml = $xml -replace ' android:requiredSplitTypes="[^"]*"', ''
$xml = $xml -replace ' android:splitTypes="[^"]*"', ''
$xml = $xml -replace 'android:extractNativeLibs="false"', 'android:extractNativeLibs="true"'
$xml = $xml -replace '\s*<meta-data android:name="com\.android\.vending\.splits\.required"[^/]*/>\s*', "`n"
$xml = $xml -replace '\s*<meta-data android:name="com\.android\.vending\.splits"[^/]*/>\s*', "`n"
Set-Content $manifest $xml -Encoding UTF8 -NoNewline

$libDir = Join-Path $Decode "lib\armeabi-v7a"
New-Item -ItemType Directory -Force -Path $libDir | Out-Null
python -c "import zipfile; z=zipfile.ZipFile(r'$Split'); z.extract('lib/armeabi-v7a/libscenejni.so', r'$Decode')"

java -jar $Apktool b $Decode -o $Unsigned | Out-Null
& "$Bt\zipalign.exe" -f 4 $Unsigned $Aligned | Out-Null
& "$Bt\apksigner.bat" sign --ks "$env:USERPROFILE\.android\debug.keystore" --ks-pass pass:android --key-pass pass:android --out $OutApk $Aligned | Out-Null
Remove-Item -Force $Unsigned, $Aligned -ErrorAction SilentlyContinue

Write-Host "[OK] $OutApk ($((Get-Item $OutApk).Length) bytes)" -ForegroundColor Green
