"""Losslessly split Quest texture payloads into a Godot PCK carried as a Meta OBB."""
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile

PREFIX = 'assets/.godot/fishing_export/'
METADATA = 'assets/quest_expansion.json'
APK_LIMIT = 1_000_000_000
OBB_LIMIT = 4_000_000_000


def sha256(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write_pack(source, entries, destination):
    """Write portable PCK v2 with streamed payloads and patched directory hashes."""
    names = [i.filename.removeprefix('assets/').encode() for i in entries]
    padded = [n + b'\0' * (-len(n) % 4) for n in names]
    directory_size = 100 + sum(4 + len(n) + 36 for n in padded)
    offset = (directory_size + 15) & ~15
    with destination.open('w+b') as out:
        out.write(struct.pack('<6IQ', 0x43504447, 2, 4, 0, 0, 0, 0))
        out.write(bytes(64))
        out.write(struct.pack('<I', len(entries)))
        records = []
        for entry, name in zip(entries, padded):
            out.write(struct.pack('<I', len(name)))
            out.write(name)
            records.append((out.tell() + 16, offset))
            out.write(struct.pack('<QQ16sI', offset, entry.file_size, bytes(16), 0))
            offset = (offset + entry.file_size + 15) & ~15
        for entry, (hash_position, position) in zip(entries, records):
            out.seek(position)
            digest = hashlib.md5()
            with source.open(entry) as stream:
                while chunk := stream.read(1024 * 1024):
                    digest.update(chunk)
                    out.write(chunk)
            out.seek(hash_position)
            out.write(digest.digest())


def split(apk, unsigned, package, version):
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+', package) or int(version) <= 0:
        raise ValueError('Invalid APK package/version for expansion filename')
    obb = unsigned.parent / f'main.{int(version)}.{package}.obb'
    with zipfile.ZipFile(apk) as source:
        if METADATA in source.namelist():
            raise ValueError('APK already contains expansion metadata')
        if 'assets/scripts/quest_bootstrap.gd' not in source.namelist() and 'assets/scripts/quest_bootstrap.gd.remap' not in source.namelist():
            raise ValueError('APK has no expansion bootstrap')
        # Godot may resolve the window icon before the bootstrap runs.
        keep = set()
        if 'assets/assets/icon.svg.import' in source.namelist():
            icon = source.read('assets/assets/icon.svg.import').decode()
            match = re.search(r'^path="res://([^"]+)"', icon, re.M)
            if match: keep.add('assets/' + match[1])
        entries = sorted((i for i in source.infolist() if i.filename.startswith(PREFIX) and i.filename not in keep and not i.is_dir()), key=lambda i: i.filename)
        moved = {i.filename for i in entries}
        if not entries or sum(i.file_size for i in entries) + 1024 * 1024 >= OBB_LIMIT:
            raise ValueError('Expansion is empty or exceeds the 4 GB budget')
        write_pack(source, entries, obb)
        metadata = {'format': 1, 'file': obb.name, 'package': package, 'version_code': int(version),
                    'bytes': obb.stat().st_size, 'sha256': sha256(obb), 'entries': len(entries)}
        with zipfile.ZipFile(unsigned, 'w', compresslevel=9) as dest:
            for info in source.infolist():
                upper = info.filename.upper()
                if info.filename in moved or (upper.startswith('META-INF/') and upper.endswith(('.RSA', '.DSA', '.EC', '.SF', '.MF'))):
                    continue
                dest.writestr(info, source.read(info), compress_type=info.compress_type, compresslevel=9)
            dest.writestr(METADATA, json.dumps(metadata, sort_keys=True).encode(), compress_type=zipfile.ZIP_DEFLATED)
    if unsigned.stat().st_size >= APK_LIMIT:
        raise ValueError('APK still exceeds 1 GB after splitting textures')
    return metadata


def inspect(apk):
    """Check the signed metadata binding before audits/staging; never guess an OBB."""
    with zipfile.ZipFile(apk) as archive:
        if METADATA not in archive.namelist():
            if list(apk.parent.glob('*.obb')):
                raise ValueError('Unexpected OBB beside a monolithic APK')
            return None
        record = json.loads(archive.read(METADATA))
        expected = f"main.{record['version_code']}.{record['package']}.obb"
        if record.get('format') != 1 or record['file'] != expected or Path(expected).name != expected:
            raise ValueError('Invalid expansion metadata')
        obb = apk.parent / expected
        if set(apk.parent.glob('*.obb')) != {obb}:
            raise ValueError('Missing or unexpected expansion file')
        if not 0 < record['bytes'] < OBB_LIMIT or obb.stat().st_size != record['bytes'] or sha256(obb) != record['sha256']:
            raise ValueError('Expansion size/hash mismatch')
        return record
