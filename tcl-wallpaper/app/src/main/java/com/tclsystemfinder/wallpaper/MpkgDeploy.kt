package com.tclsystemfinder.wallpaper

import android.content.Context
import java.io.File
import java.util.concurrent.Executor

object MpkgDeploy {

    fun isPackage(file: File): Boolean {
        val ext = file.extension.lowercase()
        return ext == "mpkg" || ext == "pkg"
    }

    fun copyToDownload(
        context: Context,
        source: File,
        executor: Executor,
        onResult: (Boolean, String) -> Unit
    ) {
        if (!source.isFile || !isPackage(source)) {
            onResult(false, "不是 mpkg/pkg 文件")
            return
        }
        executor.execute {
            val download = WeEngine.downloadDir()
            if (!download.exists()) download.mkdirs()
            val dest = File(download, source.name)
            try {
                source.inputStream().use { input ->
                    dest.outputStream().use { output -> input.copyTo(output) }
                }
                context.mainExecutor.execute {
                    onResult(true, dest.absolutePath)
                }
            } catch (e: Exception) {
                context.mainExecutor.execute {
                    onResult(false, e.message ?: "复制失败")
                }
            }
        }
    }
}
