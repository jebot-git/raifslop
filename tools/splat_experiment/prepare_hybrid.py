"""Run in Blender's Python (NumPy included). Crop the existing 500k PLY.

No cloud calls and no random downsampling: retain useful nearby splats at
their original density. Source is Marble's OpenCV coordinates.
"""
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/splat-experiment/viewer'


def prepare():
    source = OUT / 'gray_pier_500k.ply'
    with source.open('rb') as stream:
        header = []
        while True:
            line = stream.readline().decode().strip()
            header.append(line)
            if line == 'end_header': break
        props = [x.split()[-1] for x in header if x.startswith('property float ')]
        rows = np.frombuffer(stream.read(), dtype='<f4').reshape(-1, len(props)).copy()
    assert props == ['x','y','z','f_dc_0','f_dc_1','f_dc_2','opacity',
                     'scale_0','scale_1','scale_2','rot_0','rot_1','rot_2','rot_3']
    xyz = rows[:, :3] * np.array([1, -1, -1])
    radius = np.linalg.norm(xyz[:, [0, 2]], axis=1)
    opacity = 1 / (1 + np.exp(-rows[:, 6]))
    scale = np.exp(rows[:, 7:10]).max(axis=1)
    # The source capture's ground estimate is 0.729 source units below camera.
    # Match that to our authored 1.63 m eye height, not an unverified survey.
    calibration = 1.63 / 0.7292459011077881
    keep = np.ones(len(rows), dtype=bool)
    stages = {}
    def apply(name, criterion):
        nonlocal keep
        before = int(keep.sum())
        keep &= criterion
        stages[name] = {'removed': before-int(keep.sum()), 'remaining': int(keep.sum())}
    apply('finite_and_nontransparent', np.isfinite(rows).all(axis=1) & (opacity >= 0.06))
    apply('near_scenery_only', (radius < 12.0) & (xyz[:, 1] < 8.0))
    world = xyz * calibration
    # Keep dry rear-bank splats down to the waterline to overlap the mesh apron.
    rear_land = ((world[:, 2] > 5.35) | ((world[:, 0] > 6.0) & (world[:, 2] > -15.0))) & (world[:, 1] > -1.98)
    apply('remove_water_and_reflections', (xyz[:, 1] > -0.62) | rear_land)
    apply('remove_large_sky_floaters', scale < 0.22)
    apply('remove_blurred_ground_splats', (world[:, 1] >= 0.5) | (scale < 0.025))
    # Exclude the UNION of the authored floor footprints at every height.
    # Bound each Gaussian by 4.25 times its largest sigma: conservative for
    # the raster's 3-sigma quad (including its sqrt(2) diagonal), plus 15 cm.
    manifest = json.loads((ROOT/'assets/models/locations/manifest.json').read_text())['gray_pier']
    clearance = np.full(len(rows), np.inf)
    footprints = []
    for proxy in manifest['colliders']:
        if proxy['role'] != 'floor' or not proxy.get('enabled', True): continue
        center = np.array(proxy['position'])[[0, 2]] + [0, -0.65]
        half = np.array(proxy['size'])[[0, 2]] * 0.5
        yaw = proxy.get('yaw', 0)
        c, sn = np.cos(yaw), np.sin(yaw)
        local = (world[:, [0, 2]]-center) @ np.array([[c, sn], [-sn, c]])
        outside = np.maximum(np.abs(local)-half, 0)
        distance = np.linalg.norm(outside, axis=1)
        clearance = np.minimum(clearance, distance-4.25*scale*calibration)
        footprints.append({'center_xz':center.tolist(),'half_size_xz':half.tolist(),'yaw':yaw})
    apply('clear_walkable_splat_support', clearance > 0.15)
    # The lake is open in this central sector. Marble left raised dock/water
    # fragments here, above the height cutoff; they have no physical surface.
    open_water = (xyz[:, 1] < 0) & (xyz[:, 2] < 0) & (np.abs(xyz[:, 0]) < -xyz[:, 2]*0.35)
    apply('clear_central_open_water', ~open_water)
    # Captured side view reveals a detached generated boardwalk over water.
    # Keep actual right/rear banks, remove the low corridor beside our dock.
    water_corridor = (np.abs(world[:, 0]) < 6.0) & (world[:, 2] < 5.35) & (world[:, 1] < 0.5)
    apply('detached_boardwalk_over_water', ~water_corridor)
    selected = rows[keep].copy()
    distance = radius[keep]
    outer = np.clip((12-distance)/3, 0, 1)
    outer = outer*outer*(3-2*outer)
    inner = np.clip((clearance[keep]-0.15)/0.6, 0, 1)
    inner = inner*inner*(3-2*inner)
    alpha = np.clip(opacity[keep]*outer*inner, 1e-6, 1-1e-6)
    selected[:, 6] = np.log(alpha/(1-alpha))
    visible = alpha >= 0.01
    selected = selected[visible]
    safe_clearance = clearance[keep][visible]
    assert len(selected) and np.isfinite(selected).all() and safe_clearance.min() > 0.15
    checks = {'points':len(selected), 'walkable_support_overlaps':int((safe_clearance <= 0).sum()),
              'minimum_support_clearance_metres':float(safe_clearance.min()),
              'support_sigma_multiplier':4.25, 'safety_margin_metres':0.15,
              'water_corridor_points':int(water_corridor[keep][visible].sum()),
              'footprints':footprints, 'all_finite':bool(np.isfinite(selected).all())}
    (OUT/'hybrid_filter_checks.json').write_text(json.dumps(checks,indent=2)+'\n')
    name = 'gray_pier_near.ply'
    header = [f'element vertex {len(selected)}' if line.startswith('element vertex ') else line for line in header]
    with (OUT/name).open('wb') as stream:
        stream.write(('\n'.join(header)+'\n').encode())
        stream.write(selected.astype('<f4').tobytes())
    placement_path = OUT/'placement.json'
    placement = json.loads(placement_path.read_text())
    placement[name] = {'center': selected[:, :3].mean(axis=0, dtype=np.float64).tolist(),
                       'count': len(selected), 'coordinates': 'Marble OpenCV'}
    placement_path.write_text(json.dumps(placement, indent=2)+'\n')
    report = {'source_count':len(rows), 'kept_count':len(selected),
              'removed_percent':100*(1-len(selected)/len(rows)), 'stages': stages,
              'scale_to_eye_height':calibration, 'near_radius_metres':12*calibration,
              'source_water_cutoff_y':-0.62, 'ply_bytes':(OUT/name).stat().st_size}
    (OUT/'hybrid_cleanup.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__ == '__main__': prepare()
