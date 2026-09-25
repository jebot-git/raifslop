#!/usr/bin/env python3
"""Install pinned native dependencies into the lab, or explicitly into the game.

Release archives include Epic's SDK; use is subject to its license. This tool does
not configure portals, install APKs, launch VR or write credentials.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / "experiments/eos_meta"
COMMIT = "56238973e2cd7ac9ac99ca14f88934465f0a8997"
CHECKSUMS = {
    "linux": "76f7afcd01247abbba140d0f6f9d8d4e3524a20e84e08af0acd124238d2575d4",
    "android": "c29489008369a6f695d261f2e378c79e67fbb9bedb45cda102c6949afe58f851",
    "windows": "929d1fcb24c9f10834408f5c9fb80d76a6c942b2deadff553ff3f0ff57a30ee1",
}


def install(platform, cache, project=LAB):
    name = f"epic-online-services-godot-{platform}-{COMMIT}.zip"
    archive = cache / name
    if not archive.exists():
        urllib.request.urlretrieve(
            f"https://github.com/3ddelano/epic-online-services-godot/releases/download/2.3.1/{name}", archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != CHECKSUMS[platform]:
        raise SystemExit(f"Checksum mismatch: {archive}")
    target = project / "addons/epic-online-services-godot"
    prefix = "epic-online-services-godot/addons/epic-online-services-godot/"
    with zipfile.ZipFile(archive) as bundle:
        for info in bundle.infolist():
            if info.is_dir() or not info.filename.startswith(prefix):
                continue
            relative = PurePosixPath(info.filename[len(prefix):])
            if relative.is_absolute() or ".." in relative.parts:
                raise SystemExit("Unsafe archive path")
            # Only native bindings. The lab owns ticking and options; no HEOS autoloads.
            if not (str(relative).startswith("bin/") or str(relative) == "eosg.gdextension"
                    or "license" in str(relative).lower() or "notice" in str(relative).lower()):
                continue
            output = target.joinpath(*relative.parts)
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(bundle.read(info))
    (target / f"PROVENANCE-{platform}.json").write_text(json.dumps({
        "release": "2.3.1", "commit": COMMIT, "sha256": CHECKSUMS[platform],
        "source": "https://github.com/3ddelano/epic-online-services-godot",
    }, indent=2) + "\n")
    print(f"Installed EOSG 2.3.1 native {platform} bindings in {project.name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=CHECKSUMS, action="append", dest="platforms")
    parser.add_argument("--cache", type=Path, default=ROOT / "builds/eos-sdk-cache")
    parser.add_argument("--game", action="store_true", help="Install native EOSG in the gameplay project instead of the isolated lab")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    for platform in args.platforms or ["linux"]:
        install(platform, args.cache, ROOT if args.game else LAB)
    if not args.game:
        shutil.copytree(ROOT / "addons/godot_meta_toolkit", LAB / "addons/godot_meta_toolkit", dirs_exist_ok=True)
    print("Native setup complete. No account configuration or headset launch performed.")


if __name__ == "__main__":
    main()
