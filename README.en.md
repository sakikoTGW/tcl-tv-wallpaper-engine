# tcl-tv-wallpaper-engine

Scripts and a small Android TV bridge app for running [Wallpaper Engine](https://www.wallpaperengine.io/) on TCL sets where normal sideloading is blocked.

Developed against a **TCL 55A30-7CD6** (A972T01, Android 9 / API 28, **armeabi-v7a**, 1920×1080). Your mileage may vary on other TCL firmware, but the same `PackageInstallerService` hook shows up on several hotel/commercial builds.

This repo does **not** ship Wallpaper Engine binaries. You need a legitimate copy of the 2.7.4 APKM yourself.

Chinese docs (primary): [README.md](README.md)

---

## Why this exists

Getting WE onto this TV fails in three independent places:

**1. Install gate** — `adb install` / `pm install` hit `install_switch_flag: 0`. Workaround: TCL `PackageInstallerService` renew. See `scripts/install-tv-apk-renew.ps1`.

**2. Wrong WE version** — 2.8.x native libs fail on API 28. Use **2.7.4** (versionCode **4240**).

**3. APKM splits** — base-only install misses `libscenejni.so`; naive zip-merge fails on split manifest. Workaround: `scripts/build-we-274-v7a.ps1`.

---

## Quick start

```powershell
cd scripts
.\fetch-we-274.ps1
.\build-we-274-v7a.ps1
.\setup-tcl-wallpaper.ps1 -Target tv -Launch
```

Edit `scripts/tcl-tv-spec.json` for your TV IP.

See [README.md](README.md) for full Chinese documentation.
