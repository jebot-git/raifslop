import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from eos.android_export import FIELDS, configure, read_config

class AndroidEosTests(unittest.TestCase):
    def test_config_rejects_wrong_identity_and_filters_extra_credentials(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'eos.cfg'
            values = {s: {k: 'fixture' for k in keys} for s, keys in FIELDS.items()}
            values['eos']['relay'] = 'auto'
            values['identity']['provider'] = 'meta'
            values['meta'].update(app_id='123', app_secret='must-not-export')
            def write():
                path.write_text('\n'.join('['+s+']\n'+'\n'.join(k+'='+json.dumps(v) for k,v in items.items()) for s,items in values.items()))
            write()
            self.assertNotIn('app_secret', read_config(path, '123')['meta'])
            with self.assertRaises(ValueError): read_config(path, '456')
            self.assertFalse(read_config(path, '123')['leaderboards']['enabled'])
            values['leaderboards'] = {'enabled': True}
            write()
            self.assertTrue(read_config(path, '123')['leaderboards']['enabled'])
            values['leaderboards']['enabled'] = 'true'
            write()
            with self.assertRaises(ValueError): read_config(path, '123')
            values['leaderboards']['enabled'] = False
            values['identity']['provider'] = 'device'
            write()
            with self.assertRaises(ValueError): read_config(path, '123')

    def test_bootstrap_precedes_godot_and_can_be_removed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            android = root / 'android/build'
            activity = android / 'src/main/java/com/godot/game/GodotApp.java'
            activity.parent.mkdir(parents=True)
            original = 'void onCreate() {\n\t\tsuper.onCreate(savedInstanceState);\n}\n'
            activity.write_text(original)
            gradle = android / 'build.gradle'
            gradle.write_text('// template\n')
            native = root / 'addons/epic-online-services-godot/bin/android'
            native.mkdir(parents=True)
            for name in ['eossdk-StaticSTDC-release.aar', 'libeosg.android.template_release.arm64.so']:
                (native / name).touch()
            configure(android, root, {'eos': {'client_id': 'ABC'}})
            first = activity.read_text(), gradle.read_text()
            self.assertLess(first[0].index('EOSSDK.init'), first[0].index('super.onCreate'))
            configure(android, root, {'eos': {'client_id': 'ABC'}})
            self.assertEqual(first, (activity.read_text(), gradle.read_text()))
            configure(android, root)
            self.assertEqual(activity.read_text(), original)
            self.assertNotIn('eossdk', gradle.read_text())
            self.assertFalse((android / 'res/values/ubs_eos.xml').exists())

if __name__ == '__main__': unittest.main()
