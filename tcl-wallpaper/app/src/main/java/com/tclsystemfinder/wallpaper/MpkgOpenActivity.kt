package com.tclsystemfinder.wallpaper

import android.app.Activity
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import java.io.File
import java.util.concurrent.Executors

/** 从文件管理器 / U 盘打开 .mpkg 时导入 Download 并启动官方 WE */
class MpkgOpenActivity : Activity() {

    private val worker = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val path = intent.data?.path
        if (path.isNullOrBlank()) {
            finish()
            return
        }
        val file = File(path)
        if (!MpkgDeploy.isPackage(file)) {
            Toast.makeText(this, "无效文件", Toast.LENGTH_SHORT).show()
            finish()
            return
        }
        MpkgDeploy.copyToDownload(this, file, worker) { ok, _ ->
            if (ok) {
                WeEngine.launch(this)
                Toast.makeText(this, "请在 Wallpaper Engine 中 Import", Toast.LENGTH_LONG).show()
            } else {
                Toast.makeText(this, "导入失败", Toast.LENGTH_LONG).show()
            }
            finish()
        }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }
}
