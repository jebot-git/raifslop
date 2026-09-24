import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from quest_store_config import check_app_id, inspect_platform, validate_app_id

class PlatformTests(unittest.TestCase):
    def test_app_id_required_and_bounded(self):
        for value in ['', '0', '12x', '-1', '001', '9223372036854775808']:
            with self.assertRaises(ValueError): validate_app_id(value)
        with patch.dict(os.environ, {'META_QUEST_APP_ID': '123456'}):
            self.assertEqual(check_app_id(), '123456')

    def test_packaged_configuration_and_libraries_required(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / 'fixture.apk'
            for present, app, required in [(False, '123456', True), (True, '123456', False), (True, '123457', True), (True, '123456', True)]:
                with zipfile.ZipFile(apk, 'w') as archive:
                    archive.writestr('assets/quest_store.json', json.dumps({'format': 1, 'app_id': app, 'entitlement_required': required}))
                    if present:
                        for name in ['libgodot_meta_toolkit.so', 'libovrplatformloader.so']:
                            archive.writestr('lib/arm64-v8a/' + name, b'test fixture')
                with patch.dict(os.environ, {'META_QUEST_APP_ID': '123456'}):
                    if present and required and app == '123456': inspect_platform(apk)
                    else:
                        with self.assertRaises(ValueError): inspect_platform(apk)

if __name__ == '__main__': unittest.main()
