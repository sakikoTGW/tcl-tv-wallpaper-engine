package com.tclsystemfinder.wallpaper

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import java.io.File

object WeEngine {
    const val PACKAGE = "io.wallpaperengine.weclient"

    /** API28 TV 模拟器为 x86，无法安装官方 WE（仅 ARM 库） */
    fun isX86Device(): Boolean =
        Build.SUPPORTED_ABIS.any { it.equals("x86", true) || it.equals("x86_64", true) }

    fun isInstalled(context: Context): Boolean =
        try {
            context.packageManager.getPackageInfo(PACKAGE, 0)
            true
        } catch (_: Exception) {
            false
        }

    fun launch(context: Context): Boolean {
        if (isX86Device() && !isInstalled(context)) {
            val intent = Intent(context, EmulatorVerifyActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            return true
        }
        enableIfDisabled(context)
        val intent = context.packageManager.getLaunchIntentForPackage(PACKAGE) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        return true
    }

    fun openMpkg(context: Context, file: File): Boolean {
        if (!file.isFile || !MpkgDeploy.isPackage(file)) return false
        enableIfDisabled(context)
        val uri = androidx.core.content.FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.mpkg")
            setPackage(PACKAGE)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return try {
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun enableIfDisabled(context: Context) {
        // Another app cannot pm-enable without root; user may need: adb shell pm enable io.wallpaperengine.weclient
        try {
            context.packageManager.getPackageInfo(PACKAGE, 0)
        } catch (_: Exception) {
        }
    }

    fun downloadDir(): File =
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
}
