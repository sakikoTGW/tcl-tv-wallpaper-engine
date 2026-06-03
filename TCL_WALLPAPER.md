# TCL TV — Wallpaper Engine notes

Companion doc for [README.md](README.md). Assumes you already have ADB to the TV.

## Device spec

Edit `scripts/tcl-tv-spec.json`:

```json
"adb": { "ip": "192.168.1.100", "port": 5555 }
```

| Field | Value (reference hardware) |
|-------|----------------------------|
| SoC | Amlogic tl1, **armeabi-v7a** |
| Android | 9 (API 28) |
| Display | 1920×1080 |
| WE package | `io.wallpaperengine.weclient` |
| Bridge | `com.tclsystemfinder.wallpaper` |

## Obtain WE 2.7.4

We use **4240 / 2.7.4**, not current Play builds.

1. Download APKM from APKMirror (or your own backup).
2. Extract to `firmware/apk/we274/`:
   - `base.apk`
   - `split_config.armeabi_v7a.apk`
3. Run `scripts/build-we-274-v7a.ps1`.

Do not commit those files to git.

## Install

```powershell
cd scripts
.\install-we-tv.ps1 -Serial 192.168.1.100:5555 -Launch
```

Internally: `install-tv-apk-renew.ps1` → TCL `PackageInstallerService`.

Verify:

```powershell
adb shell dumpsys package io.wallpaperengine.weclient | grep versionCode
# versionCode=4240

adb shell am start -n io.wallpaperengine.weclient/.BrowseActivity
# no UnsatisfiedLinkError for libscenejni.so
```

## Bridge app

`tcl-wallpaper/` — leanback UI that:

- scans `/sdcard`, USB paths for `*.mpkg`
- copies selections to `/sdcard/Download/`
- opens WE import intent

Build:

```powershell
cd tcl-wallpaper
.\gradlew assembleDebug
# scripts/setup-tcl-wallpaper.ps1 picks up app/build/outputs/apk/debug/app-debug.apk
```

## mpkg on device

```powershell
adb push your_wallpaper.mpkg /sdcard/Download/
adb shell am start -a android.intent.action.VIEW \
  -d file:///sdcard/Download/your_wallpaper.mpkg \
  -t application/mpkg \
  -n io.wallpaperengine.weclient/.BrowseActivity
```

Then confirm import inside WE.

## Emulator smoke test

```powershell
.\setup-tcl-wallpaper.ps1 -Target emu -Launch
```

Bridge + file copy works; WE binary install is skipped on x86.

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| `install_switch_flag` / install silently fails | Use renew script, not `adb install` |
| `Expected base APK, but found split` | Re-run `build-we-274-v7a.ps1` — merged zip without manifest fix |
| `couldn't find libscenejni.so` | Installed base only; need rebuilt monolithic APK |
| `unknown reloc type 17` | Wrong WE version (2.8.x on API 28) |
| `returnCode == 4` | Split metadata still in manifest |
| `returnCode == 0` but app old version | Uninstall first: `adb shell pm uninstall io.wallpaperengine.weclient` |

Logcat filter we used: `adb logcat -s qinliang:* PackageInstaller:*`

## Deprecated

- `tools/deploy-wallpaper-android9.ps1` — superseded by `setup-tcl-wallpaper.ps1`
- `scripts/enable-tcl-install.ps1` — does not bypass renew gate on tested firmware
- LightTV custom WE renderer — out of scope; use official app
