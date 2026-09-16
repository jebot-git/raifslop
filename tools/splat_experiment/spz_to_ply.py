"""Convert legacy SPZ v2/v3 to Gaussian PLY, preserving source coordinates.

Format reference: https://github.com/nianticlabs/spz (MIT).
Explicitly rejects unsupported versions/extensions instead of guessing axes.
No external dependencies. PLY output retains all SH coefficients through degree 3.
"""
import argparse
import gzip
import json
import math
from pathlib import Path
import struct


def decode(path):
    raw = gzip.decompress(Path(path).read_bytes())
    magic, version, count, degree, fractional, flags, reserved = struct.unpack_from('<IIIBBBB', raw)
    if magic != 0x5053474E or version not in (2, 3):
        raise ValueError('Only legacy SPZ v2/v3 supported')
    if degree > 3 or flags & ~1 or reserved or fractional > 24 or not 0 < count <= 5_000_000:
        raise ValueError('Unsupported SPZ header, extensions, or point count')
    sh_dim = (degree + 1) ** 2 - 1
    sizes = [9, 1, 3, 3, 3 if version == 2 else 4, sh_dim * 3]
    if len(raw) != 16 + count * sum(sizes):
        raise ValueError('SPZ payload length mismatch')
    data = memoryview(raw)
    arrays, offset = [], 16
    for size in sizes:
        arrays.append(data[offset:offset + count * size])
        offset += count * size
    return {'count': count, 'version': version, 'degree': degree,
            'fractional_bits': fractional, 'antialiased': bool(flags & 1)}, arrays


def quaternion(values, version):
    if version == 2:
        xyz = [v / 127.5 - 1 for v in values]
        return [math.sqrt(max(0, 1 - sum(v*v for v in xyz))), *xyz]
    packed = int.from_bytes(values, 'little')
    largest = packed >> 30
    q = [0.0] * 4
    for i in range(3, -1, -1):
        if i != largest:
            q[i] = (packed & 511) / 511 / math.sqrt(2) * (-1 if (packed >> 9) & 1 else 1)
            packed >>= 10
    q[largest] = math.sqrt(max(0, 1 - sum(v*v for v in q)))
    return [q[3], *q[:3]]


def convert(source, destination):
    info, arrays = decode(source)
    count, version = info['count'], info['version']
    positions, alphas, colors, scales, rotations, harmonics = arrays
    sh_dim = (info['degree'] + 1) ** 2 - 1
    properties = ['x', 'y', 'z', 'f_dc_0', 'f_dc_1', 'f_dc_2']
    properties += ['f_rest_' + str(i) for i in range(sh_dim * 3)]
    properties += ['opacity', 'scale_0', 'scale_1', 'scale_2', 'rot_0', 'rot_1', 'rot_2', 'rot_3']
    header = ['ply', 'format binary_little_endian 1.0',
              'comment Source axes preserved; apply provider coordinate convention in viewer',
              'comment antialiased ' + str(int(info['antialiased'])),
              f'element vertex {count}']
    header += ['property float ' + p for p in properties]
    header += ['end_header', '']
    pack = struct.Struct('<' + 'f' * len(properties))
    center = [0.0, 0.0, 0.0]
    bounds = [[float('inf')] * 3, [float('-inf')] * 3]
    rotation_stride = 3 if version == 2 else 4
    with Path(destination).open('wb') as out:
        out.write('\n'.join(header).encode())
        for i in range(count):
            pos = [int.from_bytes(positions[i*9+j*3:i*9+j*3+3], 'little', signed=True)
                   / (1 << info['fractional_bits']) for j in range(3)]
            for j in range(3):
                center[j] += pos[j] / count
                bounds[0][j] = min(bounds[0][j], pos[j])
                bounds[1][j] = max(bounds[1][j], pos[j])
            dc = [(v / 255 - 0.5) / 0.15 for v in colors[i*3:i*3+3]]
            # SPZ is coefficient-major RGB; PLY is channel-major coefficients.
            sh = [(harmonics[i*sh_dim*3+k*3+c] - 128) / 128
                  for c in range(3) for k in range(sh_dim)]
            alpha = min(1 - 1e-6, max(1e-6, alphas[i] / 255))
            scale = [v / 16 - 10 for v in scales[i*3:i*3+3]]
            q = quaternion(rotations[i*rotation_stride:(i+1)*rotation_stride], version)
            out.write(pack.pack(*pos, *dc, *sh, math.log(alpha / (1-alpha)), *scale, *q))
    info.update(center=center, bounds=bounds, coordinates='source-unchanged', source=Path(source).name)
    return info


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    info = convert(args.source, args.destination)
    placement_path = args.destination.parent / 'placement.json'
    placement = json.loads(placement_path.read_text()) if placement_path.exists() else {}
    placement[args.destination.name] = info
    placement_path.write_text(json.dumps(placement, indent=2) + '\n')
    print(json.dumps(info))
