"""Audit actual PCK/APK entries, texture aliases, and Android HDR preservation."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]

class Pack:
    def __init__(self, path):
        self.file = path.open('rb')
        magic, version, major, minor, patch, flags = struct.unpack('<6I', self.file.read(24))
        assert magic == 0x43504447 and version in (2, 3, 4) and not flags & 1
        base, = struct.unpack('<Q', self.file.read(8))
        if version >= 3:
            directory, = struct.unpack('<Q', self.file.read(8)); self.file.seek(directory)
        else:
            self.file.read(64)
        count, = struct.unpack('<I', self.file.read(4))
        self.entries = {}
        for _ in range(count):
            length, = struct.unpack('<I', self.file.read(4))
            name = self.file.read(length).rstrip(b'\0').decode().removeprefix('res://')
            offset, size, digest, file_flags = struct.unpack('<QQ16sI', self.file.read(36))
            assert file_flags == 0 and name not in self.entries, name
            self.entries[name] = (offset + base, size, digest)
    def names(self): return self.entries.keys()
    def read(self, name):
        offset, size, digest = self.entries[name]
        self.file.seek(offset); data = self.file.read(size)
        assert len(data) == size and hashlib.md5(data).digest() == digest, name
        return data
    def size(self, name): return self.entries[name][1]

class APK:
    def __init__(self, path):
        self.file = zipfile.ZipFile(path)
        assert self.file.testzip() is None
        self.entries = {i.filename.removeprefix('assets/'): i for i in self.file.infolist()
                        if i.filename.startswith('assets/') and not i.is_dir()}
    def names(self): return self.entries.keys()
    def read(self, name): return self.file.read(self.entries[name])
    def size(self, name): return self.entries[name].file_size


def audit(path):
    mobile = path.suffix == '.apk'
    pack = APK(path) if mobile else Pack(path)
    names = set(pack.names()); remaps = {}; hashes = {}; sizes = {}
    for name in sorted(names):
        parts = PurePosixPath(name).parts
        assert parts[0] not in {'docs','source','tests','tools','builds','data','.release-signing'}, name
        assert not PurePosixPath(name).name.lower().startswith('readme'), name
        assert PurePosixPath(name).name not in {'export_presets.cfg','plugin.cfg'}, name
        assert not name.startswith(('addons/godot_ai/','addons/fishing_export/')), name
        data = pack.read(name); sizes[name] = len(data)
        if name.endswith(('.remap','.import')):
            target = re.search(r'^path="res://([^"]+)"', data.decode(), re.M)
            assert target and target[1] in names, ('Dangling remap',name)
            remaps[name.removesuffix('.remap').removesuffix('.import')] = target[1]
        if name.startswith('.godot/fishing_export/'):
            digest = hashlib.sha256(data).hexdigest()
            assert PurePosixPath(name).stem == digest, ('Texture hash mismatch',name)
            assert digest not in hashes, ('Duplicate texture payload',name)
            hashes[digest] = name
    assert set(hashes.values()) <= set(remaps.values()), 'Orphan texture payload'
    for required in ['ASSET_CREDITS.md','assets/models/locations/manifest.json',
                     'scripts/voice/shoulder_radio.gd','scripts/network/threaded_peer.gd',
                     'assets/avatars/vita.vrm','assets/avatars/victoria.vrm','assets/avatars/sharkperson.vrm']:
        assert required in names or required in remaps, ('Missing runtime file', required)
    panoramas = {}
    for source, target in remaps.items():
        if not source.endswith(('.hdr','.exr')): continue
        data = pack.read(target)
        if mobile:
            config = (ROOT / (source + '.import')).read_text()
            imported = re.search(r'^path="res://([^"]+)"', config, re.M)[1]
            assert hashlib.sha256(data).digest() == hashlib.sha256((ROOT/imported).read_bytes()).digest(), ('Android HDR changed', source)
        else:
            assert target.endswith('.res'), ('Desktop HDR not compressed', source)
        if source.endswith('_8k.hdr'): panoramas[source] = len(data)
    expected_panoramas = {str(p.relative_to(ROOT)) for p in (ROOT / "assets/environment/locations").glob("*_8k.hdr")}
    assert set(panoramas) == expected_panoramas and len(panoramas) == 6, panoramas
    result = {'artifact':str(path),'entries':len(names),'asset_bytes':sum(sizes.values()),
              'unique_texture_payloads':len(hashes),'texture_aliases':len([v for v in remaps.values() if v in hashes.values()]),
              'panoramas':panoramas,'largest':sorted(sizes.items(), key=lambda p:-p[1])[:20]}
    print(json.dumps(result,indent=2))
    return result

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('artifacts',nargs='+',type=Path);parser.add_argument('--report',type=Path)
    args=parser.parse_args();results=[audit(p) for p in args.artifacts]
    if args.report: args.report.write_text(json.dumps(results,indent=2)+'\n')
