"""Trace continuous fin boundaries for a reviewed photographic fish (Pillow/numpy).

Run: python3 tools/trace_fish_fins.py
Keeps the source image intact and records reproducible UV-space contours in anatomy.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / 'source/fish_references/roster_expansion'


def simplify(points, tolerance=.85):
    if len(points) < 3:
        return points
    start, end = np.array(points[0]), np.array(points[-1])
    delta = end - start
    offsets = np.array(points) - start
    if np.dot(delta, delta):
        projection = np.clip(offsets @ delta / np.dot(delta, delta), 0, 1)
        distances = np.linalg.norm(offsets - projection[:, None] * delta, axis=1)
    else:
        distances = np.linalg.norm(offsets, axis=1)
    index = int(np.argmax(distances))
    if distances[index] <= tolerance:
        return [points[0], points[-1]]
    return simplify(points[:index + 1], tolerance)[:-1] + simplify(points[index:], tolerance)


def trace(name='leervis'):
    path = REF / 'anatomy.json'
    anatomy = json.loads(path.read_text())
    data = anatomy[name]
    image = np.array(Image.open(REF / (name + '.png')).convert('RGB'))
    height, width = image.shape[:2]
    silhouettes = image.min(axis=2) < 239
    x = np.arange(width)
    body = np.array(data['body'])
    top = np.interp(x, body[:, 0], body[:, 1])
    bottom = np.interp(x, body[:, 0], body[:, 2])
    y = np.arange(height)[:, None]
    # Extend membranes under the skin; do not leave a gap at the fin roots.
    interior = ((y > top + 8) & (y < bottom - 8)
                & (x >= body[0, 0]) & (x <= body[-1, 0]))
    outlines = []
    for region in data['fin_regions']:
        region_image = Image.new('1', (width, height))
        ImageDraw.Draw(region_image).polygon([tuple(p) for p in region], fill=1)
        mask = silhouettes & np.array(region_image) & ~interior
        edges = {}
        for yy, xx in zip(*np.where(mask)):
            xx, yy = int(xx), int(yy)
            for adjacent, a, b in [
                ((yy-1, xx), (xx, yy), (xx+1, yy)),
                ((yy, xx+1), (xx+1, yy), (xx+1, yy+1)),
                ((yy+1, xx), (xx+1, yy+1), (xx, yy+1)),
                ((yy, xx-1), (xx, yy+1), (xx, yy)),
            ]:
                if not (0 <= adjacent[0] < height and 0 <= adjacent[1] < width and mask[adjacent]):
                    edges.setdefault(a, []).append(b)
        while edges:
            start = next(iter(edges))
            contour, point = [], start
            while point in edges:
                contour.append(point)
                next_point = edges[point].pop()
                if not edges[point]:
                    del edges[point]
                point = next_point
                if point == start:
                    break
            area = sum(a[0]*b[1]-b[0]*a[1] for a, b in zip(contour, contour[1:]+contour[:1])) / 2
            if area < 100:  # Omit holes and isolated background speckles.
                continue
            contour = simplify(contour + contour[:1])[:-1]
            # Bound root edge lengths so attachment and swimming deformation stay smooth.
            dense = []
            for a, b in zip(contour, contour[1:]+contour[:1]):
                count = max(1, int(np.ceil(np.linalg.norm(np.array(b)-a)/6)))
                dense.extend([[round(a[0]+(b[0]-a[0])*t/count, 3), round(a[1]+(b[1]-a[1])*t/count, 3)] for t in range(count)])
            outlines.append(dense)
    data['fin_outline_file'] = name + '_fins.json'
    (REF / data['fin_outline_file']).write_text(json.dumps(outlines, separators=(',', ':')) + '\n')
    path.write_text(json.dumps(anatomy, indent=2) + '\n')
    print(name, len(outlines), 'continuous fins;', sum(map(len, outlines)), 'boundary vertices')


if __name__ == '__main__':
    trace()
