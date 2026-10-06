"""Bake bounded luminance sharpening and gentle grading into production HDRs.

Requires numpy and OpenImageIO. Original HDRs are retained under source/ (excluded
from exports). Reruns always read those originals, never sharpen an output twice.
Longitude neighbors wrap; latitude neighbors clamp. Normal import mip generation
filters the bounded sharpening at smaller scales; this approximates the former
screen-derivative fade rather than promising bit-identical rendering at all FOVs.
"""
from pathlib import Path
import hashlib
import json
import shutil
import numpy as np
import OpenImageIO as oiio

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/environment/locations'
RAW = ROOT / 'source/panorama_originals'

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def smooth(a, b, value):
    t = np.clip((value-a)/(b-a), 0, 1)
    return t*t*(3-2*t)

def process(source, target):
    reader = oiio.ImageInput.open(str(source))
    if reader is None:
        raise RuntimeError(oiio.geterror())
    rgb = reader.read_image(format=oiio.FLOAT)[:, :, :3]
    reader.close()
    height, width, _ = rgb.shape
    if not np.isfinite(rgb).all() or rgb.min() < 0:
        raise ValueError('Invalid HDR input: ' + str(source))
    temporary = target.with_name(target.stem + '.pending.hdr')
    writer = oiio.ImageOutput.create(str(temporary))
    if not writer.open(str(temporary), oiio.ImageSpec(width, height, 3, oiio.FLOAT)):
        raise RuntimeError(writer.geterror())
    weights = np.array([.2126, .7152, .0722], dtype=np.float32)
    max_gain = 0.0
    for y in range(0, height, 64):
        end = min(y+64, height)
        center = rgb[y:end]
        surround = (np.roll(center, 1, axis=1) + np.roll(center, -1, axis=1)
                    + rgb[np.maximum(np.arange(y, end)-1, 0)]
                    + rgb[np.minimum(np.arange(y, end)+1, height-1)]) * .25
        luma = center @ weights
        detail = (luma - surround @ weights) * .5 * smooth(.008, .045, luma)
        gain = np.clip(detail / np.maximum(luma, .001), -.06, .06)
        max_gain = max(max_gain, float(np.abs(gain).max()))
        color = center * (1 + gain[:, :, None])
        # Match panorama_grade(), evaluated after sharpening in linear HDR.
        luma = color @ weights
        color *= np.clip(np.maximum(luma, .001)**(-.015), .97, 1.08)[:, :, None]
        luma = color @ weights
        color = np.maximum(luma[:, :, None] + (color-luma[:, :, None])*1.025, 0)
        if not writer.write_scanlines(y, end, 0, np.ascontiguousarray(color)):
            raise RuntimeError(writer.geterror())
    writer.close()
    temporary.replace(target)
    return {'width': width, 'height': height, 'raw_sha256': digest(source),
            'processed_sha256': digest(target), 'max_sharpen_gain': max_gain,
            'raw_peak': float(rgb.max())}

def main():
    RAW.mkdir(parents=True, exist_ok=True)
    records = {}
    for target in sorted(ASSETS.glob('*.hdr')):
        source = RAW / target.name
        if not source.exists():
            shutil.copy2(target, source)
        records[target.name] = process(source, target)
        print('PANORAMA_PREPROCESSED', target.name, flush=True)
    (RAW / 'manifest.json').write_text(json.dumps({
        'algorithm': 'bounded-luma-sharpen-and-grade-v1',
        'script_sha256': digest(Path(__file__)), 'textures': records,
    }, indent=2) + '\n')

if __name__ == '__main__':
    main()
