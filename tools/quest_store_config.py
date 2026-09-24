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
