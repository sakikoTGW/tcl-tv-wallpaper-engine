# TCL 电视 — Wallpaper Engine 补充说明

[README.md](README.md) 的配套文档，默认你已经能 adb 到电视。

## 设备配置

改 `scripts/tcl-tv-spec.json`：

```json
"adb": { "ip": "192.168.1.100", "port": 5555 }
```

| 字段 | 参考值 |
|------|--------|
| SoC | Amlogic tl1，**armeabi-v7a** |
| Android | 9（API 28） |
| 分辨率 | 1920×1080 |
| WE 包名 | `io.wallpaperengine.weclient` |
| 桥接包名 | `com.tclsystemfinder.wallpaper` |

字段说明见 spec 文件里的 `meta` 段。

## 获取 WE 2.7.4

固定 **4240 / 2.7.4**，不要用当前 Play 版。

1. 从 APKMirror 或自有备份下载 APKM。
2. 解压到 `firmware/apk/we274/`：
   - `base.apk`
   - `split_config.armeabi_v7a.apk`
3. 运行 `scripts/build-we-274-v7a.ps1`。

这些二进制不要提交 git。

## 安装

```powershell
cd scripts
.\install-we-tv.ps1 -Serial 192.168.1.100:5555 -Launch
```

内部走 `install-tv-apk-renew.ps1` → TCL `PackageInstallerService`。

验证：

```powershell
adb shell dumpsys package io.wallpaperengine.weclient | grep versionCode
# versionCode=4240

adb shell am start -n io.wallpaperengine.weclient/.BrowseActivity
# 不应再出现 libscenejni.so 的 UnsatisfiedLinkError
```

## 桥接 APK

`tcl-wallpaper/` — Leanback UI：

- 扫描 `/sdcard`、U 盘路径下的 `*.mpkg`
- 复制到 `/sdcard/Download/`
- 拉起 WE 导入 intent

编译：

```powershell
cd tcl-wallpaper
.\gradlew assembleDebug
# setup-tcl-wallpaper.ps1 会找 app/build/outputs/apk/debug/app-debug.apk
```

## 推送 mpkg

```powershell
adb push your_wallpaper.mpkg /sdcard/Download/
adb shell am start -a android.intent.action.VIEW \
  -d file:///sdcard/Download/your_wallpaper.mpkg \
  -t application/mpkg \
  -n io.wallpaperengine.weclient/.BrowseActivity
```

然后在 WE 里确认导入。

## 模拟器冒烟

```powershell
.\setup-tcl-wallpaper.ps1 -Target emu -Launch
```

桥接和文件拷贝能验；x86 上不装 WE 本体。

## 排错

| 现象 | 原因 |
|------|------|
| `install_switch_flag` / 安装无反应 | 用 renew 脚本，别用 `adb install` |
| `Expected base APK, but found split` | 重新跑 `build-we-274-v7a.ps1`，zip 合并不够 |
| `couldn't find libscenejni.so` | 只装了 base，缺重打包后的单 APK |
| `unknown reloc type 17` | WE 版本错了（2.8.x 在 API 28） |
| `returnCode == 4` | manifest 里还有 split 标记 |
| 装上了还是旧版本 | 先卸：`adb shell pm uninstall io.wallpaperengine.weclient` |

logcat 过滤：`adb logcat -s qinliang:* PackageInstaller:*`

## 已废弃

- `tools/deploy-wallpaper-android9.ps1` → 用 `setup-tcl-wallpaper.ps1`
- `scripts/enable-tcl-install.ps1` → 测过的固件上绕不过 renew
- LightTV 自研 WE 渲染 → 不在范围内，用官方 app
