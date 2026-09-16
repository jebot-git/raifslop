"""One-world Marble experiment. Credentials and signed URLs are never printed.

Commands: submit, status, download. Existing operation IDs are always reused.
An ambiguous POST failure leaves a marker: inspect the World Labs dashboard
before clearing it, to avoid charging for a duplicate world.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/splat-experiment'
LOCATION = 'gray_pier'
BASE = 'https://api.worldlabs.ai/marble/v1/'


def save(name, data):
    path = OUT / name
    path.write_text(json.dumps(data, indent=2) + '\n')
    path.chmod(0o600)


def request(url, method='GET', payload=None, headers=None):
    data = json.dumps(payload).encode() if isinstance(payload, dict) else payload
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    with urllib.request.urlopen(req, timeout=180) as response:
        return response.read()


def api(route, method='GET', payload=None):
    key = os.environ.get('WLT_API_KEY')
    if not key:
        path = Path('/tmp/worldlabs-api-key')
        if path.stat().st_mode & 0o077:
            raise RuntimeError('API key file must have permissions 600')
        key = path.read_text().strip()
    if not key or '\n' in key:
        raise RuntimeError('Missing or malformed API key')
    return json.loads(request(BASE + route, method, payload,
                             {'WLT-Api-Key': key, 'Content-Type': 'application/json'}))


def submit():
    op_path = OUT / 'operation.json'
    marker = OUT / 'submission_pending.json'
    if op_path.exists():
        print('Existing operation preserved; use status.')
        return
    if marker.exists():
        raise RuntimeError('Submission outcome uncertain; check dashboard before retrying.')
    image = OUT / (LOCATION + '_pano.png')
    upload = api('media-assets:prepare_upload', 'POST',
                 {'file_name': image.name, 'kind': 'image', 'extension': 'png'})
    info = upload['upload_info']
    headers = dict(info.get('required_headers', {}))
    headers.setdefault('Content-Type', 'image/png')
    request(info['upload_url'], info.get('upload_method', 'PUT'), image.read_bytes(), headers)
    media = upload['media_asset']
    media_id = media.get('media_asset_id') or media.get('id')
    if not media_id:
        raise RuntimeError('Upload response has no media asset ID')
    payload = {
        'display_name': 'Real AI Fishing - ' + LOCATION + ' hybrid test',
        'model': 'marble-1.1', 'permission': {'public': False}, 'seed': 20260916,
        'world_prompt': {'type': 'image', 'image_prompt': {
            'source': 'media_asset', 'media_asset_id': media_id, 'is_pano': True}},
    }
    save('request.json', {'request': payload,
         'input_sha256': hashlib.sha256(image.read_bytes()).hexdigest(),
         'source': 'https://polyhaven.com/a/' + LOCATION, 'source_license': 'CC0'})
    save(marker.name, {'message': 'POST may have been submitted; do not retry blindly'})
    operation = api('worlds:generate', 'POST', payload)
    save(op_path.name, operation)
    marker.unlink()
    print('Generation submitted. Operation ID:', operation['operation_id'])


def status():
    operation = json.loads((OUT / 'operation.json').read_text())
    operation = api('operations/' + operation['operation_id'])
    save('operation.json', operation)
    print(json.dumps({'done': operation['done'], 'error': operation.get('error'),
                      'cost': operation.get('cost')}))
    if operation['done'] and not operation.get('error'):
        world = operation['response']
        world = api('worlds/' + world['world_id'])
        save('world.json', world)
        print('World ready:', world['world_id'])


def download():
    world = json.loads((OUT / 'world.json').read_text())
    assets = world['assets']
    items = [(LOCATION + '_' + label + '.spz', url)
             for label, url in assets['splats']['spz_urls'].items() if url]
    items += [('collider.glb', assets.get('mesh', {}).get('collider_mesh_url')),
              ('generated_pano.png', assets.get('imagery', {}).get('pano_url'))]
    records = []
    for name, url in items:
        if not url:
            continue
        path = OUT / name
        if not path.exists():
            data = request(url)
            temp = path.with_suffix(path.suffix + '.part')
            temp.write_bytes(data)
            temp.replace(path)
        data = path.read_bytes()
        records.append({'file': name, 'bytes': len(data),
                        'sha256': hashlib.sha256(data).hexdigest()})
        print(name, len(data), 'bytes')
    save('downloads.json', records)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['submit', 'status', 'download'])
    parser.add_argument('--location', choices=['gray_pier','lake_pier','simons_town_rocks'], default='gray_pier')
    args = parser.parse_args()
    LOCATION = args.location
    if LOCATION != 'gray_pier': OUT = OUT / LOCATION
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        globals()[args.command]()
    except urllib.error.HTTPError as exc:
        # Do not print response bodies or request headers containing secrets/URLs.
        raise SystemExit(f'World Labs/upload HTTP {exc.code}; request not retried.')
    except urllib.error.URLError:
        raise SystemExit('Network request failed; request not retried.')
