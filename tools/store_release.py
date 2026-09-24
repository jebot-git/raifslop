"""Validate and stage free/no-IAP candidates. Never uploads or publishes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'builds'


def run(*args):
    return subprocess.check_output([str(x) for x in args], cwd=ROOT, text=True)


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify(target, revision):
    record = json.loads((BUILD / f'manifest-{target}.json').read_text())
    if record['commit'] != revision or record['target'] != target:
        raise ValueError(f'{target}: stale build; rebuild from current commit')
    folder = BUILD / target
    actual = {str(p.relative_to(folder)): digest(p) for p in folder.rglob('*') if p.is_file()}
    if actual != record['files']:
        raise ValueError(f'{target}: build files do not match manifest')
    return record


def quest_checks(apk, report_only=False):
    sdk = Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home() / 'Android/Sdk')))
    bt = sdk / 'build-tools/36.1.0'
    badging = run(bt / 'aapt', 'dump', 'badging', apk)
    xml = run(bt / 'aapt', 'dump', 'xmltree', apk, 'AndroidManifest.xml')
    errors = []
    if "targetSdkVersion:'34'" not in badging:
        errors.append('Immersive Store target SDK must be 34')
    if "native-code: 'arm64-v8a'" not in badging:
        errors.append('Expected ARM64-only APK')
    if apk.stat().st_size >= 1_000_000_000:
        errors.append('APK exceeds conservative 1 GB budget; reduce assets or implement expansion delivery')
    # aapt attribute order varies; keep each check inside its XML element.
    elements = re.split(r'(?m)^\s*E: ', xml)
    features = [e for e in elements if e.startswith('uses-feature ') and
                '"android.hardware.vr.headtracking"' in e]
    if len(features) != 1 or not re.search(r'android:required[^\n]*0xffffffff', features[0]):
        errors.append('Head tracking must be required')
    if len(features) != 1 or not re.search(r'android:version[^\n]*\(type 0x10\)0x1(?:\s|$)', features[0]):
        errors.append('Head tracking feature version must be 1')
    activities = [e for e in elements if e.startswith('activity ') and '.GodotApp"' in e]
    if len(activities) != 1 or not re.search(r'android:excludeFromRecents[^\n]*0xffffffff', activities[0]):
        errors.append('Godot activity must be excluded from recents')
    if re.search(r'android:debuggable[^\n]*0xffffffff', xml):
        errors.append('Debuggable APK is forbidden')
    for required in ['android.intent.category.LAUNCHER', 'com.oculus.intent.category.VR', 'com.oculus.supportedDevices']:
        if required not in xml:
            errors.append('Missing manifest entry: ' + required)
    if "install-location:'auto'" not in badging:
        errors.append('Install location must be auto')
    # This is a packaging check, not proof of absence of all payment code.
    if 'com.android.vending.BILLING' in badging:
        errors.append('Billing permission conflicts with free/no-IAP release')
    signing = run(bt / 'apksigner', 'verify', '--verbose', '--min-sdk-version', '21', apk)
    if 'Verified using v1 scheme (JAR signing): true' not in signing:
        errors.append('APK must have a valid v1 signature')
    if 'Verified using v2 scheme (APK Signature Scheme v2): true' not in signing:
        errors.append('APK must have a valid v2 signature')
    run(bt / 'zipalign', '-c', '-P', '16', '4', apk)
    report = {'apk': str(apk.resolve()), 'bytes': apk.stat().st_size,
              'errors': errors, 'manifest': xml, 'signing': signing, 'badging': badging}
    if report_only:
        return report
    if errors:
        raise ValueError('\n'.join(errors))
    return {name: report[name] for name in ['manifest', 'signing', 'badging']}


def positive_id(value):
    if not re.fullmatch(r'[1-9][0-9]*', value):
        raise argparse.ArgumentTypeError('Use an actual positive numeric Steam ID')
    return value


def steam_vdf(app, windows, linux, revision):
    for value in [app, windows, linux]:
        positive_id(value)
    if len({app, windows, linux}) != 3:
        raise ValueError('App and depot IDs must be distinct')
    # Relative paths make the staged candidate relocatable after CI download.
    return f'''"AppBuild"
{{
    "AppID" "{app}"
    "Desc" "Free no-IAP candidate {revision}"
    "BuildOutput" "../steam-output"
    "ContentRoot" "content"
    "Depots"
    {{
        "{windows}" {{ "FileMapping" {{ "LocalPath" "Windows/*" "DepotPath" "." "recursive" "1" }} }}
        "{linux}" {{ "FileMapping" {{ "LocalPath" "Linux/*" "DepotPath" "." "recursive" "1" }} }}
    }}
}}
'''


STEAM_LAUNCH = {
    'vr_required': True,
    'runtime': 'OpenXR',
    'platforms': {
        'Windows': {'executable': 'UltimateBoomerSimulator.exe', 'arguments': '--xr-mode on --rendering-driver vulkan'},
        'Linux': {'executable': 'UltimateBoomerSimulator.x86_64', 'arguments': '--xr-mode on --rendering-driver vulkan'},
    },
    'note': 'Configure these OS-filtered launch options in Steamworks; this file does not change the dashboard.',
}


def steam_checks(folder, target):
    executable = folder / STEAM_LAUNCH['platforms'][target]['executable']
    required = [executable, folder / 'UltimateBoomerSimulator.pck']
    libraries = (['libgodotopenxrvendors.dll', 'libtwovoip.windows.template_release.x86_64.dll']
                 if target == 'Windows' else
                 ['libgodotopenxrvendors.so', 'libtwovoip.linux.template_release.x86_64.so'])
    required.extend(folder / name for name in libraries)
    for path in required:
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f'{target}: missing or empty launch dependency: {path.name}')
    if target == 'Linux' and not executable.stat().st_mode & 0o111:
        raise ValueError('Linux: executable permission is missing')
    for path in folder.rglob('*'):
        if path.is_file() and path not in required:
            raise ValueError(f'{target}: unexpected depot file: {path.relative_to(folder)}')


def copy_notices(destination):
    shutil.copy2(ROOT / 'ASSET_CREDITS.md', destination / 'ASSET_CREDITS.md')
    for folder in ['addons', 'assets/avatars', 'assets/audio', 'source/audio']:
        for source in (ROOT / folder).rglob('*'):
            if source.is_file() and any(word in source.name.upper() for word in
                                      ['LICENSE', 'LICENCE', 'COPYING', 'NOTICE', 'CREDITS', 'REUSE']):
                target = destination / 'notices' / source.relative_to(ROOT)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('store', choices=['quest', 'steam'])
    parser.add_argument('--app-id', type=positive_id, default=os.environ.get('STEAM_APP_ID') or None)
    parser.add_argument('--windows-depot', type=positive_id, default=os.environ.get('STEAM_WINDOWS_DEPOT') or None)
    parser.add_argument('--linux-depot', type=positive_id, default=os.environ.get('STEAM_LINUX_DEPOT') or None)
    parser.add_argument('--check-config', action='store_true', help='Validate store configuration before expensive exports; does not upload')
    parser.add_argument('--inspect-apk', type=Path, help='Quest diagnostic only: inspect an existing APK without staging or asserting provenance')
    args = parser.parse_args()
    if args.inspect_apk:
        if args.store != 'quest' or args.check_config:
            parser.error('--inspect-apk requires quest and cannot be combined with --check-config')
        report = quest_checks(args.inspect_apk, report_only=True)
        print(json.dumps(report, indent=2))
        raise SystemExit(1 if report['errors'] else 0)
    if args.store == 'steam' and not all([args.app_id, args.windows_depot, args.linux_depot]):
        parser.error('Steam requires an assigned AppID and Windows/Linux depot IDs. Set STEAM_APP_ID, STEAM_WINDOWS_DEPOT and STEAM_LINUX_DEPOT or use the flags. Start onboarding at https://partner.steamgames.com/steamdirect')
    if args.store == 'steam':
        steam_vdf(args.app_id, args.windows_depot, args.linux_depot, 'configuration-check')
    if args.check_config:
        if args.store == 'quest':
            from quest_store_config import check_signing, check_app_id
            check_app_id()
            check_signing()
            print('Quest signing identity verified. Account, AppID, entitlement and hardware acceptance remain separate gates.')
        else:
            print('Steam ID syntax and distinctness passed. Ownership/account permissions still require Steamworks verification.')
        return
    if run('git', 'status', '--porcelain').strip():
        raise ValueError('Commit source before staging a Store candidate')
    revision = run('git', 'rev-parse', 'HEAD').strip()
    targets = ['Quest'] if args.store == 'quest' else ['Windows', 'Linux']
    records = [verify(t, revision) for t in targets]
    if args.store == 'steam':
        for target in targets:
            steam_checks(BUILD / target, target)
    artifacts = [BUILD / t / ('UltimateBoomerSimulator.apk' if t == 'Quest' else 'UltimateBoomerSimulator.pck') for t in targets]
    subprocess.run([sys.executable, str(ROOT / 'tools/audit_release.py'), *map(str, artifacts)], cwd=ROOT, check=True)
    checked = quest_checks(artifacts[0]) if args.store == 'quest' else None
    expansion = None
    if args.store == 'quest':
        from quest_expansion import inspect
        expansion = inspect(artifacts[0])
        from quest_store_config import inspect_platform
        inspect_platform(artifacts[0])
        if 'org.godotengine.plugin.v2.GodotMetaToolkit' not in checked['manifest']:
            raise ValueError('Quest APK is missing the Platform SDK Android plugin registration')
        if expansion:
            package = re.search(r"package: name='([^']+)' versionCode='([0-9]+)'", checked['badging'])
            if not package or package[1] != expansion['package'] or int(package[2]) != expansion['version_code']:
                raise ValueError('APK and expansion package/version do not match')
    out = BUILD / 'store' / args.store / revision
    if out.exists():
        raise ValueError(f'Candidate already exists: {out}; retain it or explicitly remove it before restaging')
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=out.parent) as tmp:
        stage = Path(tmp) / 'candidate'
        stage.mkdir()
        if args.store == 'quest':
            shutil.copy2(artifacts[0], stage / 'UltimateBoomerSimulator.apk')
            if expansion:
                shutil.copy2(artifacts[0].parent / expansion['file'], stage / expansion['file'])
                (stage / 'expansion.json').write_text(json.dumps(expansion, indent=2) + '\n')
            for name, value in checked.items():
                (stage / (name + '.txt')).write_text(value)
            copy_notices(stage)
        else:
            for target in targets:
                dest = stage / 'content' / target
                shutil.copytree(BUILD / target, dest)
                copy_notices(dest)
            (stage / 'app_build.vdf').write_text(steam_vdf(args.app_id, args.windows_depot, args.linux_depot, revision))
            (stage / 'steam-launch.json').write_text(json.dumps(STEAM_LAUNCH, indent=2) + '\n')
        shutil.copy2(ROOT / 'docs/STORE_RELEASE.md', stage / 'SUBMISSION.md')
        (stage / 'candidate.json').write_text(json.dumps({
            'commit': revision, 'store': args.store, 'price': 'free', 'iap': False,
            'status': 'packaging-checked; hardware and dashboard review required', 'builds': records,
        }, indent=2) + '\n')
        files = {str(p.relative_to(stage)): digest(p) for p in sorted(stage.rglob('*')) if p.is_file()}
        (stage / 'SHA256SUMS').write_text(''.join(f'{h}  {name}\n' for name, h in files.items()))
        shutil.move(stage, out)
    print(f'Candidate prepared: {out}. No upload or publication performed.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        sys.exit(str(exc))
