"""Check the established Android signing identity without exposing credentials."""
import os
from pathlib import Path
import re
import shutil
import subprocess

# Public certificate digest of the existing main/integrated Quest release key.
RELEASE_CERT_SHA256 = '15f604964c24bd8edc02a2cde8407293c2fdc3b87939c4164ea317e929a9d380'


def check_signing():
    key = Path(os.environ.get('STORE_KEYSTORE') or '/nonexistent')
    alias = os.environ.get('STORE_KEYSTORE_ALIAS') or 'fishing'
    if not key.is_file() or not os.environ.get('STORE_KEYSTORE_PASSWORD'):
        raise ValueError('Quest requires STORE_KEYSTORE and STORE_KEYSTORE_PASSWORD for the existing release key; see docs/QUEST_ONBOARDING.md')
    java = os.environ.get('JAVA_HOME')
    keytool = str(Path(java) / 'bin/keytool') if java else shutil.which('keytool')
    if not keytool:
        raise ValueError('Set JAVA_HOME to the installed JDK before Quest preflight')
    result = subprocess.run([keytool, '-J-Duser.language=en', '-J-Duser.country=US',
                             '-list', '-v', '-keystore', str(key), '-alias', alias,
                             '-storepass:env', 'STORE_KEYSTORE_PASSWORD'],
                            capture_output=True, text=True)
    if result.returncode:
        raise ValueError('Cannot open the release keystore/alias; check the local secret environment')
    match = re.search(r'SHA256:\s*([0-9A-Fa-f:]+)', result.stdout)
    if not match or match[1].replace(':', '').lower() != RELEASE_CERT_SHA256:
        raise ValueError('Signing certificate differs from the established Quest release identity; refusing an incompatible upgrade')
    if 'PrivateKeyEntry' not in result.stdout:
        raise ValueError('The release alias must contain a private signing key')
    return RELEASE_CERT_SHA256


def validate_app_id(value):
    if not isinstance(value, str) or not re.fullmatch(r'[1-9][0-9]{0,18}', value) or int(value) > 9223372036854775807:
        raise ValueError('Quest store builds require the assigned META_QUEST_APP_ID; see docs/QUEST_ONBOARDING.md. Do not use a placeholder.')
    return value


def check_app_id():
    import json
    config = Path(__file__).resolve().parents[1] / 'config/quest_store.json'
    value = os.environ.get('META_QUEST_APP_ID') or json.loads(config.read_text()).get('app_id', '')
    return validate_app_id(value)


def inspect_platform(apk):
    import json
    import zipfile
    with zipfile.ZipFile(apk) as archive:
        names = set(archive.namelist())
        required = {'assets/quest_store.json', 'lib/arm64-v8a/libgodot_meta_toolkit.so',
                    'lib/arm64-v8a/libovrplatformloader.so'}
        if not required <= names:
            raise ValueError('Quest store APK is missing Platform SDK libraries or entitlement configuration')
        config = json.loads(archive.read('assets/quest_store.json'))
        app = config.get('app_id', '')
        if not isinstance(app, str) or not re.fullmatch(r'[1-9][0-9]{0,18}', app) or int(app) > 9223372036854775807 or config.get('entitlement_required') is not True or config.get('format') != 1:
            raise ValueError('Invalid packaged Quest entitlement configuration')
        if app != check_app_id():
            raise ValueError('Packaged Quest AppID differs from META_QUEST_APP_ID')
        return config
