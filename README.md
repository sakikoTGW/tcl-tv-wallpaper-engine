# tcl-tv-wallpaper-engine

Scripts and a small Android TV bridge app for running [Wallpaper Engine](https://www.wallpaperengine.io/) on TCL sets where normal sideloading is blocked.

Developed against a **TCL 55A30-7CD6** (A972T01, Android 9 / API 28, **armeabi-v7a**, 1920×1080). Your mileage may vary on other TCL firmware, but the same `PackageInstallerService` hook shows up on several hotel/commercial builds.

This repo does **not** ship Wallpaper Engine binaries. You need a legitimate copy of the 2.7.4 APKM yourself.

---

## Why this exists

Getting WE onto this TV fails in three independent places:

**1. Install gate**

`adb install` and `pm install` hit `install_switch_flag: 0`. Developer options and various Sita P property writes did not flip the flag on our unit — `getprop` never reflected the change, and PackageInstaller’s silent path still read `0`.

**Workaround:** call TCL’s system service `com.tcl.packageinstaller.service.renew/.PackageInstallerService` (runs as system uid). See `scripts/install-tv-apk-renew.ps1`.

**2. Wrong WE version**

2.8.x targets newer APIs. On API 28 the app either dies in AndroidX (Trace, EdgeToEdge, …) or, if you patch past that, in native code:

```
dlopen failed: unknown reloc type 17   # libscenejni.so on API 28
```

Use **2.7.4** (`versionCode` **4240**, `minSdk` 27).

**3. APKM split layout**

APKMirror’s 2.7.4 download is an APKM bundle, not a single APK:

| Part | Contents |
|------|----------|
| `base.apk` | dex, resources (~74 MB) |
| `split_config.armeabi_v7a.apk` | `lib/armeabi-v7a/libscenejni.so` |

Installing only `base.apk` succeeds but `BrowseActivity` crashes with `UnsatisfiedLinkError: libscenejni.so`.

Zip-merging base + split is not enough. The split carries its own `AndroidManifest.xml`; if that wins, PackageParser sees `split config.armeabi_v7a` instead of a base APK. Even keeping the base manifest, `android:requiredSplitTypes="base__abi"` makes a monolithic install fail with parser error **-202** / session status **4**.

**Workaround:** decode base with apktool, strip split metadata, copy in the v7a `.so`, rebuild, sign. See `scripts/build-we-274-v7a.ps1`.

---

## Requirements

- Windows + PowerShell 5.1+
- [Android SDK platform-tools](https://developer.android.com/tools/releases/platform-tools) (`adb` on PATH or at `%ANDROID_HOME%\platform-tools`)
- JDK 11+ (apktool build step)
- `apktool.jar` in `tools/` ([releases](https://ibotpeaches.github.io/Apktool/)) — or let `build-we-274-v7a.ps1` fail loudly if missing
- Android build-tools (`zipalign`, `apksigner`) — script defaults to `%ANDROID_HOME%\build-tools\30.0.3`
- TV: USB debugging or wireless ADB (Hotel Menu → enable ADB on some A972 units)
- Wallpaper Engine **2.7.4 APKM** — [APKMirror](https://www.apkmirror.com/apk/wallpaper-engine-team/wallpaper-engine/wallpaper-engine-2-7-4-release/) or official source if you already own it

Edit `scripts/tcl-tv-spec.json` with your TV’s IP/port before running TV-targeted scripts.

---

## Quick start

```powershell
cd scripts

# 1. Fetch APKM (CDN direct link, resumable)
.\fetch-we-274.ps1
# unpack manually: firmware/apk/we274/base.apk + split_config.armeabi_v7a.apk
#   (fetch script may leave bundle.zip — extract with Expand-Archive or 7z)

# 2. Build installable monolithic v7a APK
.\build-we-274-v7a.ps1
# -> firmware/apk/wallpaper-engine-2.7.4-v7a.apk

# 3. Deploy bridge + WE + optional mpkg
.\setup-tcl-wallpaper.ps1 -Target tv -Launch
# or install WE alone:
.\install-we-tv.ps1 -Launch
```

On the TV: open Wallpaper Engine → **Import file** → pick your `.mpkg` under `/sdcard/Download/`.

The bridge app (`tcl-wallpaper/`) is optional — it scans storage for `.mpkg`, copies to Download, and gives a lean launcher on the TV app row.

---

## `install-tv-apk-renew.ps1`

Pushes an APK to `/sdcard/Download/` and starts:

```
am startservice \
  -a com.tcl.packageinstaller.service.renew.PackageInstallerService \
  -n com.tcl.packageinstaller.service.renew/.PackageInstallerService \
  --es uri file:///sdcard/Download/<apk> \
  --es currentPackageName <package> \
  --es version_code <code>
```

`install_mode` 16 is what we saw on API 28 builds. Success shows up in logcat as `returnCode == 0` from `InstallAppProgressAPI28`.

This is **not** a generic Android workaround — it depends on TCL shipping this renew installer with system privileges.

---

## `build-we-274-v7a.ps1`

Pipeline:

1. `apktool d` on `we274/base.apk`
2. Remove from manifest: `requiredSplitTypes`, `splitTypes`, `com.android.vending.splits*`
3. Set `android:extractNativeLibs="true"`
4. Extract `lib/armeabi-v7a/libscenejni.so` from the v7a split
5. `apktool b` → zipalign → sign with debug keystore (replace with your own key if you care)

Output: `firmware/apk/wallpaper-engine-2.7.4-v7a.apk` — single base APK, no split markers, ~82 MB.

---

## Emulator

The bundled AVD setup (`setup-android-tv.ps1`, `start-emulator-tcl.ps1`) is x86. Official WE won’t run there, but you can validate the bridge + mpkg copy path:

```powershell
.\setup-tcl-wallpaper.ps1 -Target emu -Launch
```

Expect `[OK] bridge installed` and mpkg magic `PKGM` on the verify screen. Real WE rendering needs the ARM TV.

---

## Layout

```
scripts/
  install-tv-apk-renew.ps1   # TCL system installer hook
  build-we-274-v7a.ps1       # APKM → monolithic v7a APK
  fetch-we-274.ps1           # download APKM bundle
  install-we-tv.ps1          # fetch/build if needed + renew install
  setup-tcl-wallpaper.ps1    # bridge + WE + mpkg deploy
  adb-tv.ps1                 # adb wrapper (emu/tv targets)
  tcl-tv-spec.json           # device constants — edit IP here

tcl-wallpaper/               # bridge APK source (Kotlin, leanback UI)

firmware/apk/                # put downloaded APKM parts here; APK outputs gitignored

tools/apktool.jar            # not included — download separately
```

More detail: [TCL_WALLPAPER.md](TCL_WALLPAPER.md).

---

## Known limits

- Android TV has no standard live-wallpaper slot on most OEM launchers; practical use is **WE full-screen**, not “set as system wallpaper”.
- Re-signed APK ≠ Play signature; in-app purchase / Steam linking may behave differently. Rendering local `.mpkg` files is what we tested.
- 2.8.x is a dead end on API 28 unless someone rebuilds native libs — we didn’t.
- Only tested on one TCL firmware (`V8-A972T01-LF1V424` family). Renew service package name must match.
- Do **not** `pm uninstall --user 0` system apps or run storage-wipe scripts on a hotel TV you don’t own.

---

## Legal

Wallpaper Engine is © Wallpaper Engine Team / Krafton. Workshop content belongs to its authors.

This project provides installation tooling only. Obtain WE and `.mpkg` files through channels you’re entitled to use. Do not commit APKs or decompiled WE trees to public forks.

---

## References

- [TCL_WALLPAPER.md](TCL_WALLPAPER.md) — bridge app behaviour, remote workflow
- [Apktool](https://ibotpeaches.github.io/Apktool/) — split manifest surgery
- Reverse-engineering notes for `PackageInstallerService` under `tools/tv-pir-decode/` (optional read)
