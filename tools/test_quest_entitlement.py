"""Exercise the real entitlement gate without an account or network calls."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='quest-entitlement-') as tmp:
    folder = Path(tmp)
    (folder / 'scripts').mkdir()
    (folder / 'project.godot').write_text('[application]\nconfig/name="Entitlement test"\n')
    shutil.copy2(ROOT / 'scripts/quest_entitlement.gd', folder / 'scripts/quest_entitlement.gd')
    shutil.copy2(ROOT / 'tests/quest_entitlement.gd', folder / 'test.gd')
    result = subprocess.run([os.environ.get('GODOT_BIN', 'godot'), '--headless', '--path', str(folder), '--script', 'test.gd'], capture_output=True, text=True, timeout=30, env=dict(os.environ, XDG_DATA_HOME=str(folder / 'userdata')))
    output = result.stdout + result.stderr
    print(output)
    if result.returncode or 'ENTITLEMENT_TEST_PASS' not in output or 'SCRIPT ERROR' in output or 'ENTITLEMENT_TEST_FAILED' in output:
        raise SystemExit(1)
