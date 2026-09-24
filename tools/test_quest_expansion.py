"""Run the production expansion verifier and PCK mount in an isolated Godot project."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import zipfile
from quest_expansion import split, write_pack, PREFIX

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
a = p.parse_args()
with tempfile.TemporaryDirectory(prefix='quest-expansion-') as tmp:
    folder = Path(tmp)
    (folder / 'project.godot').write_text('[application]\nconfig/name="Expansion test"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    shutil.copy2(ROOT / 'scripts/quest_expansion.gd', folder / 'expansion.gd')
    shutil.copy2(ROOT / 'scripts/quest_bootstrap.gd', folder / 'bootstrap.gd')
    (folder / 'scripts').mkdir()
    shutil.copy2(ROOT / 'scripts/quest_entitlement.gd', folder / 'scripts/quest_entitlement.gd')
    shutil.copy2(ROOT / 'scripts/quest_expansion.gd', folder / 'scripts/quest_expansion.gd')
    payload = b'[gd_resource type="GradientTexture2D" format=3]\n[resource]\nwidth = 7\nheight = 9\n'
    name = PREFIX + hashlib.sha256(payload).hexdigest() + '.tres'
    with zipfile.ZipFile(folder / 'source.apk', 'w') as apk:
        apk.writestr(name, payload)
        apk.writestr('assets/scripts/quest_bootstrap.gd', b'bootstrap')
    # Android keeps a sparse directory entry even after split() moves its payload.
    # Reproduce that stale entry, rather than testing only an empty resource map.
    sparse = folder / 'assets.sparsepck'
    with zipfile.ZipFile(folder / 'source.apk') as apk:
        write_pack(apk, [apk.getinfo(name)], sparse)
    with sparse.open('r+b') as stream:
        stream.seek(20)  # PCK flags: PACK_SPARSE_BUNDLE.
        stream.write(struct.pack('<I', 4))
    with zipfile.ZipFile(folder / 'source.apk', 'a') as apk:
        apk.writestr('assets/assets.sparsepck', sparse.read_bytes())
    record = split(folder / 'source.apk', folder / 'split.apk', 'org.test.game', 17)
    (folder / 'metadata.json').write_text(json.dumps(record))
    script = '''extends SceneTree
const Expansion = preload("res://expansion.gd")
const Bootstrap = preload("res://bootstrap.gd")
class MountBootstrap extends Bootstrap:
    var started := false
    var failure := ""
    func _start_game() -> void:
        started = true
    func _fail(reason: String) -> void:
        failure = reason
func _initialize() -> void:
    _run.call_deferred()
func _run() -> void:
    var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://metadata.json"))
    var path := ProjectSettings.globalize_path("res://" + str(record.file))
    assert(Expansion.metadata_error(record).is_empty())
    assert(not Expansion.verify_file(path + "missing", record).is_empty())
    var wrong: Dictionary = record.duplicate()
    wrong.bytes += 1
    assert(not Expansion.verify_file(path, wrong).is_empty())
    wrong = record.duplicate()
    wrong.sha256 = "0".repeat(64)
    assert(not Expansion.verify_file(path, wrong).is_empty())
    wrong = record.duplicate()
    wrong.file = "../bad.obb"
    assert(not Expansion.metadata_error(wrong).is_empty())
    assert(Expansion.verify_file(path, record).is_empty())
    if OS.get_cmdline_user_args().has("--sparse"):
        assert(ProjectSettings.load_resource_pack(ProjectSettings.globalize_path("res://assets.sparsepck")))
        assert(FileAccess.file_exists("RESOURCE_PATH"))
    else:
        assert(not ResourceLoader.exists("RESOURCE_PATH"))
    # Exercise the real worker completion/mount branch; avoid platform APIs and
    # replace only the final scene switch, so this fails with the old mount flag.
    var bootstrap := MountBootstrap.new()
    bootstrap.expansion_path = path
    assert(bootstrap.worker.start(Expansion.verify_file.bind(path, record)) == OK)
    while bootstrap.worker.is_alive():
        await process_frame
    bootstrap._process(0.0)
    assert(bootstrap.started and bootstrap.failure.is_empty())
    bootstrap.free()
    var texture = load("RESOURCE_PATH")
    if not (texture is GradientTexture2D and texture.width == 7 and texture.height == 9):
        push_error("EXPANSION_RUNTIME_FAILED: moved payload inaccessible")
        quit(1)
        return
    print("EXPANSION_RUNTIME_PASS")
    quit(0)
'''.replace('RESOURCE_PATH', 'res://' + name.removeprefix('assets/'))
    (folder / 'test.gd').write_text(script)
    for flags in [[], ['--', '--sparse']]:
        result = subprocess.run([a.godot, '--headless', '--path', str(folder), '--script', 'test.gd', *flags], capture_output=True, text=True, timeout=60, env=dict(os.environ, XDG_DATA_HOME=str(folder / 'userdata')))
        print('Sparse APK index:', bool(flags))
        print(result.stdout, end='')
        print(result.stderr, end='')
        if result.returncode or 'ERROR:' in result.stderr or 'EXPANSION_RUNTIME_PASS' not in result.stdout:
            raise SystemExit('Expansion runtime test failed')
