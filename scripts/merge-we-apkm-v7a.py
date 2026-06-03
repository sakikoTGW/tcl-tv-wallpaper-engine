"""Merge APKM base + armeabi-v7a split into one installable APK."""
import sys
import zipfile
from pathlib import Path

base_apk = Path(sys.argv[1])
split_apk = Path(sys.argv[2])
out_apk = Path(sys.argv[3])

with zipfile.ZipFile(base_apk, "r") as zbase, zipfile.ZipFile(split_apk, "r") as zsplit:
    split_names = {i.filename for i in zsplit.infolist()}
    skip_from_split = {"AndroidManifest.xml", "META-INF/MANIFEST.MF", "META-INF/CERT.SF", "META-INF/CERT.RSA"}
    with zipfile.ZipFile(out_apk, "w") as zout:
        for info in zbase.infolist():
            # Keep base manifest; only skip base entries replaced by split libs/assets.
            if info.filename in split_names and info.filename != "AndroidManifest.xml":
                continue
            data = zbase.read(info.filename)
            new = zipfile.ZipInfo(filename=info.filename, date_time=info.date_time)
            new.compress_type = info.compress_type
            new.external_attr = info.external_attr
            zout.writestr(new, data)
        for info in zsplit.infolist():
            if info.filename in skip_from_split or info.filename.startswith("META-INF/"):
                continue
            data = zsplit.read(info.filename)
            new = zipfile.ZipInfo(filename=info.filename, date_time=info.date_time)
            new.compress_type = info.compress_type
            new.external_attr = info.external_attr
            zout.writestr(new, data)

print(f"merged -> {out_apk} ({out_apk.stat().st_size} bytes)")
