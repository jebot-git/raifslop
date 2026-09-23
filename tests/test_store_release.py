"""Release regression checks: immutable provenance and safe Store configuration."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


store = module('store_release')
manifest = module('quest_store_manifest')


class StoreReleaseTests(unittest.TestCase):
    def test_manifest_merges_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'AndroidManifest.xml'
            path.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
                            '<application><profileable android:enabled="true"/>'
                            '<activity android:name=".GodotApp" android:excludeFromRecents="false"/>'
                            '</application></manifest>')
            manifest.configure(path)
            first = path.read_bytes()
            manifest.configure(path)
            self.assertEqual(first, path.read_bytes())
            root = manifest.ET.parse(path).getroot()
            self.assertEqual(root.find('uses-feature').get(manifest.A + 'required'), 'true')
            self.assertEqual(root.find('application/activity').get(manifest.A + 'excludeFromRecents'), 'true')
            self.assertIsNone(root.find('application/profileable'))

    def test_manifest_rejects_unknown_template(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'AndroidManifest.xml'
            path.write_text('<manifest><application/></manifest>')
            with self.assertRaises(ValueError):
                manifest.configure(path)

    def test_stale_and_tampered_builds_rejected(self):
        old = store.BUILD
        try:
            with tempfile.TemporaryDirectory() as tmp:
                store.BUILD = Path(tmp)
                folder = store.BUILD / 'Linux'
                folder.mkdir()
                file = folder / 'game'
                file.write_bytes(b'original')
                (store.BUILD / 'manifest-Linux.json').write_text(json.dumps({
                    'target': 'Linux', 'commit': 'revision', 'files': {'game': store.digest(file)}}))
                store.verify('Linux', 'revision')
                with self.assertRaises(ValueError):
                    store.verify('Linux', 'other')
                file.write_bytes(b'tampered')
                with self.assertRaises(ValueError):
                    store.verify('Linux', 'revision')
        finally:
            store.BUILD = old

    def test_steam_upload_does_not_promote_public_build(self):
        vdf = store.steam_vdf('100', '101', '102', 'abc')
        self.assertNotIn('SetLive', vdf)
        self.assertIn('Windows/*', vdf)
        self.assertIn('Linux/*', vdf)
        with self.assertRaises(ValueError):
            store.steam_vdf('100', '100', '102', 'abc')
        with self.assertRaises(Exception):
            store.positive_id('100"\n"SetLive" "default')

    def test_quest_rejects_old_manifest_and_billing(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / 'game.apk'
            apk.write_bytes(b'fixture')
            badging = "targetSdkVersion:'36'\nnative-code: 'arm64-v8a'\ninstall-location:'auto'\ncom.android.vending.BILLING"
            with patch.object(store, 'run', side_effect=[badging, '',
                    'Verified using v2 scheme (APK Signature Scheme v2): true', '']):
                with self.assertRaises(ValueError) as error:
                    store.quest_checks(apk)
                self.assertIn('SDK must be 34', str(error.exception))
                self.assertIn('Billing permission', str(error.exception))
                self.assertIn('Head tracking must be required', str(error.exception))


if __name__ == '__main__':
    unittest.main()
