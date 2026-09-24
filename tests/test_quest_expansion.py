"""Verify lossless splitting, signed metadata binding and corrupted/missing OBB rejection."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from quest_expansion import split, inspect, PREFIX, METADATA
from audit_release import Pack


class ExpansionTests(unittest.TestCase):
    def test_split_preserves_payloads_and_binds_the_pair(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            source, output = folder / 'original.apk', folder / 'split.apk'
            data = bytes(range(256)) * 37
            name = PREFIX + hashlib.sha256(data).hexdigest() + '.ctex'
            logo_name = PREFIX + hashlib.sha256(b'logo pixels').hexdigest() + '.ctex'
            with zipfile.ZipFile(source, 'w') as apk:
                apk.writestr(name, data)
                apk.writestr(logo_name, b'logo pixels')
                apk.writestr('assets/assets/ui/store_logo.png.import',
                             '[remap]\npath="res://' + logo_name.removeprefix('assets/') + '"\n')
                apk.writestr('assets/scripts/quest_bootstrap.gd', b'bootstrap')
                apk.writestr('lib/arm64-v8a/libgodot.so', b'native')
                apk.writestr('META-INF/CERT.RSA', b'old signature')
            metadata = split(source, output, 'org.test.game', 17)
            obb = folder / metadata['file']
            pack = Pack(obb)
            self.assertEqual(pack.read(name.removeprefix('assets/')), data)
            pack.file.close()
            with zipfile.ZipFile(output) as apk:
                self.assertNotIn(name, apk.namelist())
                self.assertEqual(apk.read(logo_name), b'logo pixels')
                self.assertNotIn(logo_name.removeprefix('assets/'), pack.entries)
                self.assertNotIn('META-INF/CERT.RSA', apk.namelist())
                self.assertEqual(apk.read('lib/arm64-v8a/libgodot.so'), b'native')
                self.assertEqual(json.loads(apk.read(METADATA)), metadata)
            self.assertEqual(inspect(output), metadata)
            with obb.open('r+b') as stream:
                stream.seek(-1, 2); stream.write(b'!')
            with self.assertRaisesRegex(ValueError, 'hash mismatch'): inspect(output)
            obb.unlink()
            with self.assertRaisesRegex(ValueError, 'Missing'): inspect(output)

    def test_rejects_apk_without_bootstrap(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            with zipfile.ZipFile(folder / 'old.apk', 'w') as apk:
                apk.writestr(PREFIX + 'texture.ctex', b'pixels')
            with self.assertRaisesRegex(ValueError, 'bootstrap'):
                split(folder / 'old.apk', folder / 'split.apk', 'org.test.game', 17)


if __name__ == '__main__': unittest.main()
