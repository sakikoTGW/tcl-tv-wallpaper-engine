package com.tclsystemfinder.wallpaper

import android.app.Activity
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView
import java.io.File
import java.io.RandomAccessFile

/**
 * x86 模拟器无法跑官方 WE；此页验证 mpkg 已在 Download 且魔数正确。
 */
class EmulatorVerifyActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val scroll = ScrollView(this)
        val text = TextView(this).apply {
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 16f
            setPadding(48, 48, 48, 48)
        }
        scroll.addView(text)
        setContentView(scroll)
        text.text = buildReport()
    }

    private fun buildReport(): String {
        val download = WeEngine.downloadDir()
        val pkgs = download.listFiles { f ->
            f.isFile && MpkgDeploy.isPackage(f)
        }?.sortedByDescending { it.lastModified() } ?: emptyList()

        val sb = StringBuilder()
        sb.appendLine("【模拟器验证模式】")
        sb.appendLine("x86 无法安装官方 Wallpaper Engine。")
        sb.appendLine("以下检查通过 = 部署脚本与壁纸助手流程正常。")
        sb.appendLine()
        sb.appendLine("Download: ${download.absolutePath}")
        sb.appendLine("mpkg 数量: ${pkgs.size}")
        sb.appendLine()

        if (pkgs.isEmpty()) {
            sb.appendLine("未找到 mpkg — 请 PC 执行:")
            sb.appendLine("  setup-tcl-wallpaper.ps1 -Target emu -MpkgPath ...")
            return sb.toString()
        }

        for (f in pkgs) {
            val magic = readMagic(f)
            val ok = magic.startsWith("PKGM") || magic.startsWith("PKGV")
            sb.appendLine("文件: ${f.name}")
            sb.appendLine("  大小: ${f.length() / 1024} KB")
            sb.appendLine("  魔数: $magic ${if (ok) "OK" else "INVALID"}")
            sb.appendLine()
        }
        sb.appendLine("真机 (armeabi-v7a) 安装官方 WE 后，同一 mpkg 在 Import file 中导入即可播放。")
        return sb.toString()
    }

    private fun readMagic(file: File): String {
        return try {
            RandomAccessFile(file, "r").use { raf ->
                val buf = ByteArray(8)
                if (raf.read(buf) < 4) return "?"
                String(buf, Charsets.US_ASCII).trim { it <= ' ' || it == '\u0000' }
            }
        } catch (_: Exception) {
            "?"
        }
    }
}
