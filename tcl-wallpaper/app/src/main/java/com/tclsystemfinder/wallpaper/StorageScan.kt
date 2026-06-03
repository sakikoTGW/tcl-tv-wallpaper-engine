package com.tclsystemfinder.wallpaper

import java.io.File

data class MpkgEntry(val file: File, val label: String)

object StorageScan {

    private val scanRoots = listOf(
        "/sdcard/Download",
        "/storage/emulated/0/Download",
        "/sdcard",
        "/storage"
    )

    fun findAllPackages(): List<MpkgEntry> {
        val seen = linkedSetOf<String>()
        val out = ArrayList<MpkgEntry>()
        for (root in scanRoots) {
            val dir = File(root)
            if (!dir.isDirectory) continue
            walk(dir, depth = 0, maxDepth = if (root == "/storage") 2 else 4, seen, out)
        }
        return out.sortedByDescending { it.file.lastModified() }
    }

    private fun walk(
        dir: File,
        depth: Int,
        maxDepth: Int,
        seen: MutableSet<String>,
        out: MutableList<MpkgEntry>
    ) {
        if (depth > maxDepth) return
        val files = try {
            dir.listFiles() ?: return
        } catch (_: Exception) {
            return
        }
        for (f in files) {
            if (f.name.startsWith(".")) continue
            if (f.isDirectory) {
                if (f.name in skipDirNames) continue
                walk(f, depth + 1, maxDepth, seen, out)
            } else if (MpkgDeploy.isPackage(f)) {
                val key = f.canonicalPath
                if (seen.add(key)) {
                    val where = when {
                        f.parentFile?.name.equals("Download", true) -> "Download"
                        f.absolutePath.contains("media_rw") -> "U盘"
                        else -> f.parent ?: "?"
                    }
                    out.add(MpkgEntry(f, "${f.name} ($where)"))
                }
            }
        }
    }

    fun findWeApksInDownload(): List<File> {
        val download = WeEngine.downloadDir()
        if (!download.isDirectory) return emptyList()
        return download.listFiles { f ->
            f.isFile && f.name.endsWith(".apk", ignoreCase = true) &&
                f.name.contains("wallpaper", ignoreCase = true)
        }?.sortedByDescending { it.lastModified() } ?: emptyList()
    }

    private val skipDirNames = setOf(
        "emulated", "self", "Android", "data", "obb", "cache", "lost+found"
    )
}
