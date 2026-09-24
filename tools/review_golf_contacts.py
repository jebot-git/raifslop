#!/usr/bin/env python3
"""Make an offline contact replay overlay from golf JSONL or rec4 contact fixtures.

Shows actual contact point, ball centre and vectors in the clubhead's local frame.
Arrows show direction at a common display length; numerical speeds remain in SI.
"""
import argparse
import html
import json
import math
from pathlib import Path


def sub(a, b):
    return [x - y for x, y in zip(a, b)]


def local(basis, vector):
    return [sum(x * y for x, y in zip(axis, vector)) for axis in basis]


def length(v):
    return math.sqrt(sum(x*x for x in v))


def region(n):
    if n[2] < -.65:
        return 'face'
    if abs(n[1]) >= max(abs(n[0]), abs(n[2])):
        return 'crown' if n[1] > 0 else 'sole'
    if abs(n[0]) > abs(n[2]):
        return 'toe' if n[0] > 0 else 'heel'
    return 'back' if n[2] > 0 else 'face edge'


def read_contacts(path):
    text = path.read_text()
    rows = json.loads(text) if text.lstrip().startswith('[') else [json.loads(line) for line in text.splitlines() if line.strip()]
    result = []
    for row in rows:
        if 'type' in row:
            if row['type'] != 'contact_attempt' or not row['data'].get('accepted'):
                continue
            data = dict(row['data'], engine_s=row['monotonic_us'] / 1e6)
        else:
            data = row
        result.append(data)
    return result


def overlay(row):
    basis = row['head_basis']
    contact = local(basis, sub(row['contact'], row['head_center']))
    ball = local(basis, sub(row['ball_center'], row['head_center']))
    normal = local(basis, row['normal'])
    impact = row.get('impact', {})
    incoming_world = impact.get('contact_velocity', row.get('contact_velocity', row['filtered_velocity']))
    outgoing_world = impact.get('velocity', row.get('original_launch', [0, 0, 0]))
    incoming, outgoing = local(basis, incoming_world), local(basis, outgoing_world)
    label = f"{row['engine_s']:.3f}s · club {int(row['club'])} · {region(normal)}"
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 470" role="img">',
             f'<title>{html.escape(label)}</title>', '<rect width="960" height="470" fill="#101925"/>',
             '<g fill="#edf1f5" font-family="sans-serif" font-size="16">',
             f'<text x="20" y="28">{html.escape(label)}</text>',
             f'<text x="20" y="55">Incoming {length(incoming):.2f} m/s · outgoing {length(outgoing):.2f} m/s</text></g>']
    for panel, (a, b, name) in enumerate([(0, 1, 'Front: X / Y'), (2, 1, 'Side: Z / Y'), (0, 2, 'Top: X / Z')]):
        cx, cy, scale = panel*320+160, 235, 1300
        def point(v):
            return cx+v[a]*scale, cy-v[b]*scale
        px, py = point(contact)
        bx, by = point(ball)
        parts.extend([f'<text x="{panel*320+20}" y="96" fill="#edf1f5" font-family="sans-serif">{name}</text>',
                      f'<path d="M{cx-125} {cy}h250 M{cx} {cy-115}v230" stroke="#344355"/>',
                      f'<circle cx="{bx:.2f}" cy="{by:.2f}" r="{.021335*scale}" fill="none" stroke="#e8edf2"/>',
                      f'<circle cx="{px:.2f}" cy="{py:.2f}" r="4" fill="#ed526c"/>'])
        for vector, color in [(incoming, '#69aaff'), (outgoing, '#ffb15b'), (normal, '#57dcc1')]:
            norm = max(length(vector), .00001)
            dx, dy = vector[a]/norm*70, -vector[b]/norm*70
            ex, ey = px+dx, py+dy
            theta = math.atan2(dy, dx)
            hx, hy = math.cos(theta)*9, math.sin(theta)*9
            parts.append(f'<path d="M{px:.2f} {py:.2f}L{ex:.2f} {ey:.2f} M{ex-hx-hy*.5:.2f} {ey-hy+hx*.5:.2f}L{ex:.2f} {ey:.2f}L{ex-hx+hy*.5:.2f} {ey-hy-hx*.5:.2f}" fill="none" stroke="{color}" stroke-width="2"/>')
    parts.append('<text x="20" y="450" fill="#edf1f5" font-family="sans-serif" font-size="13">Blue: incoming · orange: outgoing · mint: normal · red: contact · white: ball · cross: head centre</text></svg>')
    return label, ''.join(parts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inputs', nargs='+', type=Path)
    parser.add_argument('--output', type=Path, default=Path('test-results/golf-contact-review.html'))
    args = parser.parse_args()
    rows = [row for path in args.inputs for row in read_contacts(path)]
    if not rows:
        raise SystemExit('No accepted contact records found')
    rows.sort(key=lambda row: row['engine_s'])
    frames = [overlay(row) for row in rows]
    options = ''.join(f'<option value="{i}">{html.escape(label)}</option>' for i, (label, _) in enumerate(frames))
    data = json.dumps([svg for _, svg in frames]).replace('</', '<\\/')
    document = '''<!doctype html><html lang="en"><meta charset="utf-8"><title>Golf contact replay</title>
<style>body{background:#101925;color:#edf1f5;font:16px system-ui;max-width:1100px;margin:30px auto;padding:15px}select{font:inherit;padding:10px;max-width:100%}svg{width:100%}p{line-height:1.5}</style>
<h1>Golf contact replay</h1><p>Contact geometry and direction in the measured clubhead frame. Select an impact to compare three projections. Arrow lengths are normalized; speeds are listed separately. This overlay does not infer the player's intended face orientation.</p>
<label>Recorded impact <select id="shot">''' + options + '''</select></label><div id="view"></div>
<script>const frames=''' + data + ''';const shot=document.getElementById('shot');const view=document.getElementById('view');function show(){view.innerHTML=frames[Number(shot.value)];}shot.addEventListener('change',show);show();</script></html>'''
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(document)
    args.output.with_suffix('.svg').write_text(frames[0][1])
    print(f'{len(rows)} contact overlays: {args.output}')


if __name__ == '__main__':
    main()
