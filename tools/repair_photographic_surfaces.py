"""Repair retained photographic GLBs without rebaking or changing body geometry.

Run with Python, NumPy and Pillow. Fresh Blender builds use the same UV sampler
and reviewed fin regions. Embedded textures and body positions are retained.
The repair changes body UVs, trims false fin strips and seats missed cornea
rim vertices on the skin, updating their normals.
"""
import json
import struct
from pathlib import Path
import numpy as np
from fish_surface_sampling import BodyUVSampler, inside_region

ROOT = Path(__file__).resolve().parents[1]


def closest_surface(point, triangles):
    a, b, c = triangles[:, 0], triangles[:, 1], triangles[:, 2]
    ab, ac = b - a, c - a
    normals = np.cross(ab, ac)
    square = np.einsum('ij,ij->i', normals, normals)
    valid = square > 1e-16
    a, b, c, ab, ac, normals, square = [v[valid] for v in (a, b, c, ab, ac, normals, square)]
    projected = point - normals * (np.einsum('ij,ij->i', point - a, normals) / square)[:, None]
    offset = projected - a
    u = np.einsum('ij,ij->i', np.cross(offset, ac), normals) / square
    v = np.einsum('ij,ij->i', np.cross(ab, offset), normals) / square
    inside = (u >= 0) & (v >= 0) & (u + v <= 1)
    candidates = [projected[inside]]
    for start, end in ((a, b), (b, c), (c, a)):
        edge = end - start
        t = np.clip(np.einsum('ij,ij->i', point - start, edge) / np.einsum('ij,ij->i', edge, edge), 0, 1)
        candidates.append(start + edge * t[:, None])
    points = np.concatenate(candidates)
    return points[np.argmin(np.linalg.norm(points - point, axis=1))]


def repair_cornea(glb, primitive, body):
    positions = glb.array(primitive['attributes']['POSITION'])
    low, high = positions.min(axis=0), positions.max(axis=0)
    body = body[(body[:, :, 0].max(axis=1) >= low[0] - .03) & (body[:, :, 0].min(axis=1) <= high[0] + .03)]
    a, b, c = body[:, 0], body[:, 1], body[:, 2]
    ab, ac = b[:, :2] - a[:, :2], c[:, :2] - a[:, :2]
    determinant = ab[:, 0] * ac[:, 1] - ab[:, 1] * ac[:, 0]
    valid = np.abs(determinant) > 1e-12
    # The source ray misses just above the reviewed body contour. The old
    # fallback used half the fish's width and built a tube above the eye.
    # Only repair misses; the successfully inset iris remains unchanged.
    changed = 0
    for point in positions:
        ap = point[:2] - a[:, :2]
        u = np.zeros(len(body)); v = u.copy()
        u[valid] = (ap[valid, 0] * ac[valid, 1] - ap[valid, 1] * ac[valid, 0]) / determinant[valid]
        v[valid] = (ab[valid, 0] * ap[valid, 1] - ab[valid, 1] * ap[valid, 0]) / determinant[valid]
        if np.any(valid & (u >= -1e-5) & (v >= -1e-5) & (u + v <= 1.00001)):
            continue
        query = np.array([point[0], point[1], 0.0])
        nearest = closest_surface(query, body)
        outward = query - nearest
        length = np.linalg.norm(outward)
        if length > 1e-8:
            point[:] = nearest + outward / length * .0003
            changed += 1
    if changed:
        faces = glb.array(primitive['indices']).reshape(-1, 3)
        normals = np.zeros_like(positions)
        face_normals = np.cross(positions[faces[:, 1]] - positions[faces[:, 0]], positions[faces[:, 2]] - positions[faces[:, 0]])
        for corner in range(3):
            np.add.at(normals, faces[:, corner], face_normals)
        lengths = np.linalg.norm(normals, axis=1)
        valid = lengths > 1e-12
        glb.array(primitive['attributes']['NORMAL'])[valid] = normals[valid] / lengths[valid, None]
    return changed


class GLB:
    def __init__(self, path):
        data = path.read_bytes()
        magic, version, size = struct.unpack_from('<III', data)
        assert magic == 0x46546c67 and version == 2 and size == len(data)
        length, kind = struct.unpack_from('<II', data, 12)
        assert kind == 0x4e4f534a
        self.doc = json.loads(data[20:20 + length])
        self.raw = bytearray(data[28 + length:])

    def array(self, index):
        accessor = self.doc['accessors'][index]
        view = self.doc['bufferViews'][accessor['bufferView']]
        columns = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
        dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2'}[accessor['componentType']]
        assert 'byteStride' not in view, 'Expected packed Blender accessors'
        return np.frombuffer(self.raw, dtype=dtype, count=accessor['count'] * columns,
                             offset=view.get('byteOffset', 0) + accessor.get('byteOffset', 0)).reshape(-1, columns)

    def save(self, path):
        doc = json.dumps(self.doc, separators=(',', ':')).encode()
        doc += b' ' * (-len(doc) % 4)
        path.write_bytes(struct.pack('<III', 0x46546c67, 2, 28 + len(doc) + len(self.raw))
                         + struct.pack('<II', len(doc), 0x4e4f534a) + doc
                         + struct.pack('<II', len(self.raw), 0x004e4942) + self.raw)


def repair(path, pixels, anatomy, force=False):
    glb = GLB(path)
    version = glb.doc['asset'].get('extras', {}).get('photographic_surface_repair', 0)
    if version == 2 and not force:
        return 0, 0, 0
    sampler = BodyUVSampler(pixels, anatomy)
    dimensions = np.array([sampler.width, sampler.height])
    changed = removed = eyes = 0
    for mesh in glb.doc['meshes']:
        skin = next(p for p in mesh['primitives'] if 'photographic skin' in glb.doc['materials'][p['material']]['name'])
        body = glb.array(skin['attributes']['POSITION'])[glb.array(skin['indices']).reshape(-1, 3)]
        for primitive in mesh['primitives']:
            material = glb.doc['materials'][primitive['material']]['name']
            uv = glb.array(primitive['attributes']['TEXCOORD_0'])
            if 'photographic skin' in material:
                positions = glb.array(primitive['attributes']['POSITION'])
                xmin, xmax = anatomy['extent']; length = xmax-xmin
                for point, position in zip(uv, positions):
                    old = point.copy()
                    # Recover the untouched side projection from geometry, not
                    # the v1 clamped UVs; this also makes repair upgrades safe.
                    x = position[0]*length + (xmin+xmax)/2
                    y = anatomy['center'] - position[1]*length/anatomy.get('height_scale', 1)
                    if x >= sampler.eye_start: continue
                    point[:] = np.array(sampler.sample(x, y, position[2])) / dimensions
                    changed += int(not np.array_equal(point, old))
            elif version < 1 and 'fin membranes' in material and anatomy.get('fin_regions'):
                indices = glb.array(primitive['indices'])
                faces = indices.reshape(-1, 3)
                centers = uv[faces].mean(axis=1) * dimensions
                keep = [any(inside_region(x, y, region) for region in anatomy['fin_regions']) for x, y in centers]
                retained = faces[keep].ravel().copy()
                removed += len(faces) - sum(keep)
                indices[:len(retained), 0] = retained
                glb.doc['accessors'][primitive['indices']]['count'] = len(retained)
            elif version < 1 and 'wet cornea' in material:
                eyes += repair_cornea(glb, primitive, body)
    if changed or removed or eyes:
        glb.doc['asset'].setdefault('extras', {})['photographic_surface_repair'] = 2
        for index, accessor in enumerate(glb.doc['accessors']):
            if 'min' in accessor or 'max' in accessor:
                values = glb.array(index)
                accessor['min'] = values.min(axis=0).tolist()
                accessor['max'] = values.max(axis=0).tolist()
        glb.save(path)
    return changed, removed, eyes


if __name__ == '__main__':
    from PIL import Image
    import sys
    reference = ROOT / 'source/fish_references'
    for name, anatomy in json.loads((reference / 'anatomy.json').read_text()).items():
        pixels = np.asarray(Image.open(reference / (name + '.png')).convert('RGB')) / 255.0
        print(name, repair(ROOT / 'assets/models/fish' / (name + '.glb'), pixels, anatomy, force='--force' in sys.argv))
