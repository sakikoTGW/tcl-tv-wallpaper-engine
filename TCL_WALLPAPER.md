# TCL Wallpaper Engine — 运维

## tcl-tv-spec.json

```json
"adb": { "ip": "192.168.1.100", "port": 5555 }
```

| 键 | 值 |
|----|-----|
| `wallpaper.wePackage` | `io.wallpaperengine.weclient` |
| `wallpaper.weVersionCode` | `4240` |
| `wallpaper.bridgePackage` | `com.tclsystemfinder.wallpaper` |
| `wallpaper.cpuAbi` | `armeabi-v7a` |
| `install.renewService` | `com.tcl.packageinstaller.service.renew/.PackageInstallerService` |

## APKM 目录

```
firmware/apk/we274/
  base.apk
  split_config.armeabi_v7a.apk
```

```powershell
.\build-we-274-v7a.ps1
```

APK 不进 git。

## 安装

```powershell
.\install-we-tv.ps1 -Serial 192.168.1.100:5555 -Launch
```

降级先卸用户包：

```powershell
adb shell pm uninstall io.wallpaperengine.weclient
```

## 桥接 APK

```powershell
cd tcl-wallpaper
.\gradlew assembleDebug
```

`setup-tcl-wallpaper.ps1` 读 `app/build/outputs/apk/debug/app-debug.apk`。

功能：扫 `*.mpkg` → 复制到 `/sdcard/Download/` → 调 WE import intent。

## mpkg

```powershell
adb push foo.mpkg /sdcard/Download/
adb shell am start -a android.intent.action.VIEW ^
  -d file:///sdcard/Download/foo.mpkg -t application/mpkg ^
  -n io.wallpaperengine.weclient/.BrowseActivity
```

## logcat

```powershell
adb logcat -s qinliang:* PackageInstaller:*
```

| 日志 | 含义 |
|------|------|
| `returnCode == 0` | renew 安装成功 |
| `returnCode == 4` | APK 无效 / split manifest 未清 |
| `UnsatisfiedLinkError: libscenejni.so` | 缺 v7a so |
| `unknown reloc type 17` | 2.8.x on API 28 |

## 废弃

- `tools/deploy-wallpaper-android9.ps1` → `setup-tcl-wallpaper.ps1`
- `enable-tcl-install.ps1` — 测试机无效
- LightTV WE 渲染 — 仓库外
