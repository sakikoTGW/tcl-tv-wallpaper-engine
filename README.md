# tcl-tv-wallpaper-engine

PowerShell 脚本 + Android TV 桥接 APK。在 TCL **Android 9 / armeabi-v7a** 上 sideload Wallpaper Engine **2.7.4**。

**实测机型：** TCL 55A30-7CD6（A972T01），API 28，1920×1080，固件 `V8-A972T01-LF1V424`。

仓库不含 WE 安装包，自行准备 2.7.4 APKM。

## 依赖

- Windows，PowerShell 5.1+
- Android SDK `platform-tools`、`build-tools`（脚本写死 30.0.3 路径，按本机改）
- JDK 11+
- `tools/apktool.jar`（[Apktool releases](https://github.com/iBotPeaches/Apktool/releases)）

## 配置

`scripts/tcl-tv-spec.json` — 部署前改 `adb.ip`、`adb.port`。

## 命令

```powershell
cd scripts

# 下载 APKM → firmware/apk/，解包到 we274/
.\fetch-we-274.ps1

# 需要 we274/base.apk + we274/split_config.armeabi_v7a.apk
.\build-we-274-v7a.ps1

# 桥接 + WE + mpkg（可选）
.\setup-tcl-wallpaper.ps1 -Target tv -Launch
```

只装 WE：

```powershell
.\install-we-tv.ps1 -Launch
```

电视上：WE → Import file → `/sdcard/Download/*.mpkg`。

## 安装通道

本机固件上 `adb install` 被拦：

```
install_switch_flag: 0
```

走 `install-tv-apk-renew.ps1`：推到 `/sdcard/Download/`，调系统服务：

```
am startservice \
  -a com.tcl.packageinstaller.service.renew.PackageInstallerService \
  -n com.tcl.packageinstaller.service.renew/.PackageInstallerService \
  --es uri file:///sdcard/Download/<apk> \
  --es currentPackageName <pkg> \
  --es version_code <code>
```

成功标志：logcat 里 `InstallAppProgressAPI28` 的 `returnCode == 0`。依赖包名 `com.tcl.packageinstaller.service.renew`，非通用 Android 接口。

`enable-tcl-install.ps1` 在测试机上未改变上述行为。

## APKM 处理

APKMirror 的 2.7.4 是 APKM：

| 文件 | |
|------|---|
| `base.apk` | dex，约 74 MB |
| `split_config.armeabi_v7a.apk` | `lib/armeabi-v7a/libscenejni.so` |

| 现象 | 原因 |
|------|------|
| `UnsatisfiedLinkError: libscenejni.so` | 只装了 base |
| `Expected base APK, but found split config.armeabi_v7a` | 合并时 split manifest 覆盖 base |
| 安装 session status **4** | manifest 仍带 `requiredSplitTypes="base__abi"` |
| `unknown reloc type 17` | WE 2.8.x + API 28 |

与只 zip 合并不清 manifest 的工具同类问题，参考 [AntiSplit-M](https://github.com/AbdurazaaqMohammed/AntiSplit-M) 关于 split metadata 的说明。

`build-we-274-v7a.ps1` 步骤：

1. `apktool d` base
2. 删 `requiredSplitTypes`、`splitTypes`、`com.android.vending.splits*`
3. `extractNativeLibs="true"`
4. 从 v7a split 拷 `libscenejni.so`
5. `apktool b` → zipalign → sign

版本固定 **4240**。API 28 不要用 Play 当前 2.8.x。

产物：`firmware/apk/wallpaper-engine-2.7.4-v7a.apk`（约 82 MB，gitignore）。

## 模拟器

`setup-android-tv.ps1` 建的是 x86 AVD，WE 本体跑不了；桥接和 mpkg 拷贝可测：

```powershell
.\setup-tcl-wallpaper.ps1 -Target emu -Launch
```

## 目录

```
scripts/
  tcl-tv-spec.json
  fetch-we-274.ps1
  build-we-274-v7a.ps1
  merge-we-apkm-v7a.py          # 仅 zip 合并，单独用不够
  install-tv-apk-renew.ps1
  install-we-tv.ps1
  setup-tcl-wallpaper.ps1
  adb-tv.ps1
tcl-wallpaper/
firmware/apk/                   # 本地 APKM 目录，见 README.txt
```

运维细节：[TCL_WALLPAPER.md](TCL_WALLPAPER.md)。

## 验证

```powershell
adb shell dumpsys package io.wallpaperengine.weclient | findstr versionCode
adb shell am start -n io.wallpaperengine.weclient/.BrowseActivity
adb logcat -s qinliang:* PackageInstaller:*
```

## License

MIT（脚本与桥接 APK）。Wallpaper Engine 及 workshop 资源需自行合法获取。
