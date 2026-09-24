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
                            '<application android:debuggable="true"><profileable android:enabled="true"/>'
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
            self.assertIsNone(root.find('application').get(manifest.A + 'debuggable'))

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

    def test_steam_checks_launch_dependencies_and_permissions(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            names = ['UltimateBoomerSimulator.x86_64', 'UltimateBoomerSimulator.pck',
                     'libgodotopenxrvendors.so', 'libtwovoip.linux.template_release.x86_64.so']
            for name in names:
                (folder / name).write_bytes(b'fixture')
            exe = folder / names[0]
            exe.chmod(0o644)
            with self.assertRaisesRegex(ValueError, 'permission'):
                store.steam_checks(folder, 'Linux')
            exe.chmod(0o755)
            store.steam_checks(folder, 'Linux')
            (folder / 'player.cfg').write_text('private data')
            with self.assertRaisesRegex(ValueError, 'unexpected depot file'):
                store.steam_checks(folder, 'Linux')
            (folder / 'player.cfg').unlink()
            (folder / names[-1]).unlink()
            with self.assertRaisesRegex(ValueError, 'missing or empty'):
                store.steam_checks(folder, 'Linux')

    def test_steam_config_preflight_without_builds(self):
        import subprocess
        import sys
        script = str(ROOT / 'tools/store_release.py')
        with patch.dict('os.environ', {'STEAM_APP_ID': '', 'STEAM_WINDOWS_DEPOT': '', 'STEAM_LINUX_DEPOT': ''}):
            missing = subprocess.run([sys.executable, script, 'steam', '--check-config'], capture_output=True, text=True)
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn('steamdirect', missing.stderr)
        good = subprocess.run([sys.executable, script, 'steam', '--check-config', '--app-id', '100', '--windows-depot', '101', '--linux-depot', '102'], capture_output=True, text=True)
        self.assertEqual(good.returncode, 0, good.stderr)
        bad = subprocess.run([sys.executable, script, 'steam', '--check-config', '--app-id', '100', '--windows-depot', '100', '--linux-depot', '102'], capture_output=True, text=True)
        self.assertNotEqual(bad.returncode, 0)
        self.assertIn('distinct', bad.stderr)

    def test_quest_required_attributes_are_scoped_and_order_independent(self):
        badging = "targetSdkVersion:'34'\nnative-code: 'arm64-v8a'\ninstall-location:'auto'"
        xml = ('E: manifest (line=1)\n'
               '  E: uses-feature (line=2)\n'
               '    A: android:version(0x0101021b)=(type 0x10)0x1\n'
               '    A: android:required(0x0101028e)=(type 0x12)0xffffffff\n'
               '    A: android:name(0x01010003)="android.hardware.vr.headtracking"\n'
               '  E: application (line=3)\n'
               '    E: activity (line=4)\n'
               '      A: android:name(0x01010003)="com.godot.game.GodotApp"\n'
               '      A: android:excludeFromRecents(0x01010017)=(type 0x12)0xffffffff\n'
               '      E: category (line=5)\n'
               '        A: android:name="android.intent.category.LAUNCHER"\n'
               '      E: category (line=6)\n'
               '        A: android:name="com.oculus.intent.category.VR"\n'
               '    E: meta-data (line=7)\n'
               '      A: android:name="com.oculus.supportedDevices"\n')
        signing = ('Verified using v1 scheme (JAR signing): true\n'
                   'Verified using v2 scheme (APK Signature Scheme v2): true')
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / 'game.apk'
            apk.write_bytes(b'fixture')
            with patch.object(store, 'run', side_effect=[badging, xml, signing, '']):
                store.quest_checks(apk)
            wrong = xml.replace('com.godot.game.GodotApp', 'com.other.Activity')
            with patch.object(store, 'run', side_effect=[badging, wrong, signing, '']):
                with self.assertRaisesRegex(ValueError, 'excluded from recents'):
                    store.quest_checks(apk)
            with patch.object(store, 'run', side_effect=[badging, xml, signing.replace('v1 scheme (JAR signing): true', 'v1 scheme (JAR signing): false'), '']):
                report = store.quest_checks(apk, report_only=True)
                self.assertEqual(report['errors'], ['APK must have a valid v1 signature'])
            with apk.open('r+b') as stream:
                stream.truncate(1_000_000_001)
            with patch.object(store, 'run', side_effect=[badging, xml, signing, '']):
                with self.assertRaisesRegex(ValueError, '1 GB'):
                    store.quest_checks(apk)

    def test_quest_signing_identity_preflight(self):
        config = module('quest_store_config')
        import subprocess
        with tempfile.TemporaryDirectory() as tmp:
            key = Path(tmp) / 'key'
            key.touch()
            with patch.dict('os.environ', {'STORE_KEYSTORE': str(key), 'STORE_KEYSTORE_PASSWORD': 'test-only', 'JAVA_HOME': tmp}):
                for output in ['SHA256: ' + config.RELEASE_CERT_SHA256, 'PrivateKeyEntry\nSHA256: 00:11']:
                    with patch.object(config.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, output, '')):
                        with self.assertRaises(ValueError):
                            config.check_signing()
                with patch.object(config.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'PrivateKeyEntry\nSHA256: ' + config.RELEASE_CERT_SHA256, '')):
                    self.assertEqual(config.check_signing(), config.RELEASE_CERT_SHA256)

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
