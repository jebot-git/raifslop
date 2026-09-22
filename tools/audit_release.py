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
    assert not any('hand_probe' in name for name in names), 'Hand-tracking diagnostic leaked into release'
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
    for required in ['scripts/bbq/activity.gd','scripts/bbq/model.gd','scripts/bbq/network.gd',
                     'scripts/bbq/sites.gd','scripts/bbq/food.gd','scripts/bbq/tongs.gd',
                     'shaders/bbq_food.gdshader','assets/audio/bbq/can_open.wav',
                     'assets/audio/bbq/grill_sizzle.wav',
                     *['assets/models/bbq/'+asset+'.glb' for asset in
                       ['station','cooler','cooler_lid','beer_can','fish_burger','tongs_handle','tongs_jaw','sausage','corn','mushroom']],
                     'ASSET_CREDITS.md','assets/models/locations/manifest.json',
                     'assets/textures/lighting/panorama_lighting.json',
                     'scripts/rear_parallax.gd','assets/environment/rear_parallax.gdshader',
                     'assets/environment/shore_details/fishing_plan_poster.svg',
                     'scripts/voice/shoulder_radio.gd','scripts/network/threaded_peer.gd',
                     'scripts/controller_calibration.gd','scripts/fish_water_boundary.gd',
                     'scripts/client_diagnostics.gd','scripts/network/loading.gd',
                     'scripts/fly_fishing.gd','scripts/hooked_fish.gd','scripts/river_foreground.gd',
                     'scripts/ui/vr_item_list.gd','assets/models/rods/fly_handle.glb',
                     'assets/models/fish/wels_catfish.glb','assets/models/fish/bronze_whaler.glb',
                     'assets/models/fish/huchen.glb','assets/models/fish/raggedtooth_shark.glb',
                     'assets/models/fish/silver_bream.glb','assets/models/fish/ruffe.glb',
                     'assets/models/fish/ide.glb','assets/models/fish/asp.glb',
                     'assets/models/fish/leervis.glb','assets/models/fish/atlantic_chub_mackerel.glb',
                     'assets/models/fish/dusky_kob.glb','assets/models/fish/white_stumpnose.glb',
                     'assets/models/fish/zebra_seabream.glb','assets/models/fish/cape_horse_mackerel.glb',
                     'assets/environment/rivers/river_shrubs.png','assets/environment/rivers/river_alder.png',
                     'assets/environment/rivers/river_bank.png',
                     'assets/environment/shore_details/lakeshore_reeds.png',
                     'assets/environment/shore_details/simons_granite.png',
                     'assets/environment/shore_details/coastal_dune_grass.png',
                     'assets/environment/shore_details/coastal_wrack.png',
                     'assets/models/locations/lit/secluded_beach.glb',
                     'assets/models/locations/lit/fish_hoek_beach.glb',
                     'assets/audio/ambience/secluded_beach.ogg','assets/audio/ambience/fish_hoek_beach.ogg',
                     'assets/audio/ambience/meadow_bend.ogg','assets/audio/ambience/boulder_run.ogg',
                     'assets/avatars/vita.vrm','assets/avatars/victoria.vrm','assets/avatars/sharkperson.vrm']:
        assert required in names or required in remaps, ('Missing runtime file', required)
    lighting = json.loads(pack.read('assets/textures/lighting/panorama_lighting.json'))
    expected_lighting = {p.name.removesuffix('_8k.hdr') for p in (ROOT / 'assets/environment/locations').glob('*_8k.hdr')}
    assert set(lighting) == expected_lighting and all(record['sun_energy'] > 0 for record in lighting.values()), 'Missing measured lighting'
    for tier in ['willow', 'reed', 'heron', 'kingfisher']:
        for mode in ['', '_fly', '_feeder', '_lure']:
            for state in ['', '_folded']:
                required = f'assets/models/rods/{tier}{mode}{state}.glb'
                assert required in names or required in remaps, ('Missing tackle model', required)
    panoramas = {}
    for source, target in remaps.items():
        if not source.endswith(('.hdr','.exr')): continue
        data = pack.read(target)
        if mobile or '/textures/lighting/' in source or source.startswith('addons/golfminus/'):
            config = (ROOT / (source + '.import')).read_text()
            imported = re.search(r'^path="res://([^"]+)"', config, re.M)[1]
            assert hashlib.sha256(data).digest() == hashlib.sha256((ROOT/imported).read_bytes()).digest(), ('Lossless HDR changed', source)
        else:
            assert target.endswith('.res'), ('Desktop HDR not compressed', source)
        if source.endswith('_8k.hdr'): panoramas[source] = len(data)
    expected_panoramas = {str(p.relative_to(ROOT)) for p in (ROOT / "assets/environment/locations").glob("*_8k.hdr")}
    expected_panoramas.update(str(p.relative_to(ROOT)) for p in (ROOT/'addons/golfminus/assets/panoramas').glob('*_8k.hdr'))
    assert set(panoramas) == expected_panoramas, panoramas
    for course in ['spyglass', 'pebble']:
        for required in [f'addons/golfminus/courses/{course}.json', *[f'addons/golfminus/assets/course_data/{course}/{file}' for file in ['height.bin', 'lies.bin', 'outlines.json']]]:
            assert required in names and pack.size(required)>0, ('Missing golf course data', required)
    result = {'artifact':str(path),'entries':len(names),'asset_bytes':sum(sizes.values()),
              'unique_texture_payloads':len(hashes),'texture_aliases':len([v for v in remaps.values() if v in hashes.values()]),
              'panoramas':panoramas,'largest':sorted(sizes.items(), key=lambda p:-p[1])[:20]}
    print(json.dumps(result,indent=2))
    return result

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('artifacts',nargs='+',type=Path);parser.add_argument('--report',type=Path)
    args=parser.parse_args();results=[audit(p) for p in args.artifacts]
    if args.report: args.report.write_text(json.dumps(results,indent=2)+'\n')
