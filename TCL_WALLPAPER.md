# 组件说明

## tcl-tv-spec.json

| 键 | 值 |
|----|-----|
| `adb.ip` / `adb.port` | 电视 adb 地址 |
| `wallpaper.wePackage` | `io.wallpaperengine.weclient` |
| `wallpaper.weVersionCode` | `4240` |
| `wallpaper.bridgePackage` | `com.tclsystemfinder.wallpaper` |
| `wallpaper.cpuAbi` | `armeabi-v7a` |
| `install.renewService` | `com.tcl.packageinstaller.service.renew/.PackageInstallerService` |

## install-tv-apk-renew.ps1

参数：`-ApkPath`、`-PackageName`、`-VersionCode`、`-Serial`、`-WaitSeconds`。

推送 APK 到 `/sdcard/Download/`，启动 renew service，轮询 `pm path`。

## build-we-274-v7a.ps1

输入：`firmware/apk/we274/base.apk`、`split_config.armeabi_v7a.apk`。

apktool 解包 → 改 manifest → 拷 native lib → 构建 → zipalign → apksigner。

## tcl-wallpaper

| 类 | 作用 |
|----|------|
| `WallpaperTvActivity` | 主界面，mpkg 列表 |
| `StorageScan` | 扫描 sdcard / USB |
| `MpkgDeploy` | 复制到 Download |
| `MpkgOpenActivity` / `WeEngine` | 调 WE |
| `EmulatorVerifyActivity` | x86 验证页（PKGM 魔数） |
| `ApkInstall` | 设备端安装逻辑（备用） |

## renew service intent

```
action: com.tcl.packageinstaller.service.renew.PackageInstallerService
component: com.tcl.packageinstaller.service.renew/.PackageInstallerService
extras: uri, currentPackageName, version_code
```

测试固件上 `install_mode` 为 16。
