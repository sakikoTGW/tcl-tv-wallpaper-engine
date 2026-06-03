# tcl-tv-wallpaper-engine

在 TCL 电视上安装并运行 [Wallpaper Engine](https://www.wallpaperengine.io/) 的脚本和小桥接 APK。

参考机型 **TCL 55A30-7CD6**（A972T01，Android 9 / API 28，**armeabi-v7a**，1920×1080）。酒店版、商用版 TCL 上如果也有 `PackageInstallerService` renew 服务，有可能同样适用；其他品牌别指望。

本仓库**不包含** Wallpaper Engine 安装包，2.7.4 APKM 需自行合法获取。

---

## 背景

在这台电视上，WE 会在三个地方分别挂掉：

**1. 装不上**

`adb install`、`pm install` 返回 `install_switch_flag: 0`。开发者选项、Sita P 属性写入在我们这台机上都不生效——`getprop` 读不到变化，PackageInstaller 静默分支仍然看到 `0`。

**绕过：** 调 TCL 系统服务 `com.tcl.packageinstaller.service.renew/.PackageInstallerService`（system uid）。见 `scripts/install-tv-apk-renew.ps1`。

**2. 版本不对**

2.8.x 面向更高 API。在 API 28 上，Java 层会死在 AndroidX（Trace、EdgeToEdge 等），就算 patch 过去，native 也会报：

```
dlopen failed: unknown reloc type 17   # libscenejni.so
```

用 **2.7.4**（`versionCode` **4240**，`minSdk` 27）。

**3. APKM 分包**

APKMirror 下的 2.7.4 是 APKM，不是单 APK：

| 文件 | 内容 |
|------|------|
| `base.apk` | dex、资源（约 74 MB） |
| `split_config.armeabi_v7a.apk` | `lib/armeabi-v7a/libscenejni.so` |

只装 base 能装上，但 `BrowseActivity` 启动即 `UnsatisfiedLinkError: libscenejni.so`。

把两个 zip 简单合并也不行：split 自带 `AndroidManifest.xml`，覆盖 base 后 PackageParser 会报 `Expected base APK, but found split config.armeabi_v7a`；就算保留 base manifest，`requiredSplitTypes="base__abi"` 也会让安装失败（错误码 **-202**，session status **4**）。

**绕过：** apktool 解 base，去掉 split 相关 manifest/meta，拷入 v7a 的 `.so`，重打包签名。见 `scripts/build-we-274-v7a.ps1`。

---

## 环境

- Windows + PowerShell 5.1+
- [Android SDK platform-tools](https://developer.android.com/tools/releases/platform-tools)（`adb` 在 PATH 或 `%ANDROID_HOME%\platform-tools`）
- JDK 11+（apktool 构建）
- `tools/apktool.jar`（[下载](https://ibotpeaches.github.io/Apktool/)，仓库未附带）
- Android build-tools（`zipalign`、`apksigner`），脚本默认 `%ANDROID_HOME%\build-tools\30.0.3`
- 电视：USB 或无线 ADB（部分 A972 需在 Hotel Menu 里开 ADB）
- WE **2.7.4 APKM**（[APKMirror](https://www.apkmirror.com/apk/wallpaper-engine-team/wallpaper-engine/wallpaper-engine-2-7-4-release/) 或自有备份）

跑电视相关脚本前，先改 `scripts/tcl-tv-spec.json` 里的 IP/端口。

---

## 快速开始

```powershell
cd scripts

# 1. 下载 APKM（CDN 直链，支持断点续传）
.\fetch-we-274.ps1
# 解压到 firmware/apk/we274/：base.apk + split_config.armeabi_v7a.apk
#   （脚本可能留下 bundle.zip，用 7z 或 Expand-Archive 解压）

# 2. 打成可安装的单 APK
.\build-we-274-v7a.ps1
# 输出 firmware/apk/wallpaper-engine-2.7.4-v7a.apk

# 3. 部署桥接 + WE + mpkg（可选）
.\setup-tcl-wallpaper.ps1 -Target tv -Launch
# 或只装 WE：
.\install-we-tv.ps1 -Launch
```

电视上：打开 Wallpaper Engine → **Import file** → 选 `/sdcard/Download/` 下的 `.mpkg`。

桥接 APK（`tcl-wallpaper/`）可选，负责扫盘找 mpkg、复制到 Download、给 TV 一个入口。

---

## install-tv-apk-renew.ps1

把 APK 推到 `/sdcard/Download/`，然后：

```
am startservice \
  -a com.tcl.packageinstaller.service.renew.PackageInstallerService \
  -n com.tcl.packageinstaller.service.renew/.PackageInstallerService \
  --es uri file:///sdcard/Download/<apk> \
  --es currentPackageName <包名> \
  --es version_code <版本号>
```

API 28 上看到的 `install_mode` 是 16。成功时 logcat 里 `InstallAppProgressAPI28` 的 `returnCode == 0`。

这是 **TCL 专用** 路子，不是通用 Android 解法。

---

## build-we-274-v7a.ps1

流程：

1. `apktool d` 解 `we274/base.apk`
2. 从 manifest 删掉 `requiredSplitTypes`、`splitTypes`、`com.android.vending.splits*`
3. `android:extractNativeLibs="true"`
4. 从 v7a split 提取 `lib/armeabi-v7a/libscenejni.so`
5. `apktool b` → zipalign → debug keystore 签名（要正式签名自己换 key）

输出 `firmware/apk/wallpaper-engine-2.7.4-v7a.apk`，单包、无 split 标记，约 82 MB。

---

## 模拟器

`setup-android-tv.ps1` / `start-emulator-tcl.ps1` 建的是 x86 AVD，官方 WE 跑不起来，但可以验桥接和 mpkg 拷贝：

```powershell
.\setup-tcl-wallpaper.ps1 -Target emu -Launch
```

看到 `[OK] bridge installed` 和魔数 `PKGM` 即流程 OK。真渲染还得 ARM 电视。

---

## 目录

```
scripts/
  install-tv-apk-renew.ps1   # TCL renew 安装
  build-we-274-v7a.ps1       # APKM → 单 APK
  fetch-we-274.ps1           # 下载 APKM
  install-we-tv.ps1          # 构建 + 安装 WE
  setup-tcl-wallpaper.ps1    # 桥接 + WE + mpkg
  adb-tv.ps1                 # adb 封装
  tcl-tv-spec.json           # 设备配置，改 IP

tcl-wallpaper/               # 桥接 APK 源码

firmware/apk/                # 本地放 APKM 解包文件，产物 gitignore
```

细节见 [TCL_WALLPAPER.md](TCL_WALLPAPER.md)。英文说明：[README.en.md](README.en.md)。

---

## 已知限制

- 多数 Android TV 桌面没有标准动态壁纸槽，实际用法是 **WE 全屏常开**，不是「设为系统壁纸」。
- 重签名 ≠ Play 签名，内购/Steam 联动行为可能不同；我们测的是本地 `.mpkg` 渲染。
- 2.8.x 在 API 28 上 native 过不去，除非有人重编 `libscenejni.so`。
- 只在 `V8-A972T01-LF1V424` 一类固件上验过，renew 服务包名要对得上。
- 别在别人的酒店电视上 `pm uninstall --user 0` 卸系统包，也别跑清存储脚本。

---

## 版权

Wallpaper Engine © Wallpaper Engine Team / Krafton。Workshop 内容归原作者。

本仓库只提供安装工具链。WE 和 `.mpkg` 请通过你有权使用的渠道获取；别把 APK 或解包目录 commit 到 fork。
