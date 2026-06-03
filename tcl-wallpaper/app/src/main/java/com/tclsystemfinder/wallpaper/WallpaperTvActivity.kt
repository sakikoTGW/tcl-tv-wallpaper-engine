package com.tclsystemfinder.wallpaper

import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import java.io.File
import java.util.concurrent.Executors

class WallpaperTvActivity : AppCompatActivity() {

    private val worker = Executors.newSingleThreadExecutor()
    private lateinit var status: TextView
    private lateinit var deviceInfo: TextView
    private lateinit var list: RecyclerView
    private lateinit var adapter: MpkgAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_wallpaper_tv)

        status = findViewById(R.id.status)
        deviceInfo = findViewById(R.id.device_info)
        list = findViewById(R.id.mpkg_list)

        deviceInfo.text = "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}) · ${Build.SUPPORTED_ABIS.joinToString()}"

        adapter = MpkgAdapter { entry -> importEntry(entry) }
        list.layoutManager = LinearLayoutManager(this)
        list.adapter = adapter

        findViewById<Button>(R.id.btn_open_we).setOnClickListener {
            if (!WeEngine.launch(this) && !WeEngine.isX86Device()) {
                Toast.makeText(this, "请先安装 Wallpaper Engine", Toast.LENGTH_LONG).show()
            }
        }
        findViewById<Button>(R.id.btn_install_we).setOnClickListener { installWeApk() }
        findViewById<Button>(R.id.btn_rescan).setOnClickListener { refresh() }

        refresh()
        findViewById<Button>(R.id.btn_open_we).requestFocus()
    }

    override fun onResume() {
        super.onResume()
        refreshStatus()
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun refreshStatus() {
        status.text = when {
            WeEngine.isInstalled(this) -> getString(R.string.status_we_ok)
            WeEngine.isX86Device() -> "模拟器 x86：官方 WE 不可装，用「打开」进入验证页"
            else -> getString(R.string.status_we_missing)
        }
    }

    private fun refresh() {
        refreshStatus()
        worker.execute {
            val items = StorageScan.findAllPackages()
            runOnUiThread {
                adapter.submit(items)
                if (items.isEmpty()) {
                    Toast.makeText(this, "未找到 mpkg，可放入 Download 或 U 盘", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun importEntry(entry: MpkgEntry) {
        val src = entry.file
        val inDownload = try {
            WeEngine.downloadDir().canonicalPath == src.parentFile?.canonicalPath
        } catch (_: Exception) {
            src.absolutePath.contains("/Download/")
        }
        if (inDownload) {
            if (WeEngine.openMpkg(this, src)) {
                Toast.makeText(this, "正在打开 Wallpaper Engine…", Toast.LENGTH_SHORT).show()
            } else {
                WeEngine.launch(this)
                Toast.makeText(this, "请在 WE 中 Import file", Toast.LENGTH_LONG).show()
            }
            return
        }
        MpkgDeploy.copyToDownload(this, src, worker) { ok, msg ->
            if (ok) {
                val dest = File(WeEngine.downloadDir(), src.name)
                if (WeEngine.openMpkg(this, dest)) {
                    Toast.makeText(this, "已导入并打开 WE", Toast.LENGTH_LONG).show()
                } else {
                    WeEngine.launch(this)
                    Toast.makeText(this, "已复制到 Download", Toast.LENGTH_LONG).show()
                }
                refresh()
            } else {
                Toast.makeText(this, msg, Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun installWeApk() {
        val apks = StorageScan.findWeApksInDownload()
        if (apks.isEmpty()) {
            Toast.makeText(
                this,
                "请把 wallpaper-engine*.apk 放到 Download（armeabi-v7a）",
                Toast.LENGTH_LONG
            ).show()
            return
        }
        ApkInstall.promptInstall(this, apks.first())
    }
}

private class MpkgAdapter(
    private val onPick: (MpkgEntry) -> Unit
) : RecyclerView.Adapter<MpkgAdapter.VH>() {

    private var items = emptyList<MpkgEntry>()

    fun submit(list: List<MpkgEntry>) {
        items = list
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: android.view.ViewGroup, viewType: Int): VH {
        val v = android.view.LayoutInflater.from(parent.context)
            .inflate(R.layout.item_mpkg_row, parent, false)
        return VH(v)
    }

    override fun onBindViewHolder(holder: VH, position: Int) = holder.bind(items[position], onPick)

    override fun getItemCount() = items.size

    class VH(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val name = itemView.findViewById<TextView>(R.id.name)
        private val path = itemView.findViewById<TextView>(R.id.path)

        fun bind(entry: MpkgEntry, onPick: (MpkgEntry) -> Unit) {
            name.text = entry.label
            path.text = entry.file.absolutePath
            itemView.isFocusable = true
            itemView.isFocusableInTouchMode = true
            itemView.setOnClickListener { onPick(entry) }
            itemView.setOnKeyListener { _, keyCode, event ->
                if (event.action == android.view.KeyEvent.ACTION_UP &&
                    (keyCode == android.view.KeyEvent.KEYCODE_DPAD_CENTER ||
                        keyCode == android.view.KeyEvent.KEYCODE_ENTER)
                ) {
                    onPick(entry)
                    true
                } else false
            }
        }
    }
}
