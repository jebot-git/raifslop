#!/usr/bin/env python3
"""Connect mapped golf tees and greens with mown, tree-free playing lanes.

Offline authoring: requires numpy, Pillow and shapely, like build_reference_courses.
Original mapped outlines/routes are retained; play lanes are a gameplay adaptation.
"""
import argparse
import heapq
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from shapely import distance, points
from shapely.geometry import LineString, Point, Polygon
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parents[1] / 'addons/golfminus'
COURSES = ['spyglass', 'pebble', 'cypress', 'poppy']
LANE_RADIUS = 10.0
GRID_STEP = 2
VERSION = 1


def raster(geometry, origin, shape):
    image = Image.new('L', (shape[1], shape[0]))
    draw = ImageDraw.Draw(image)
    for polygon in geometry:
        draw.polygon([(x-origin[0], z-origin[1]) for x, z in polygon['points']], fill=1)
        for ring in polygon.get('holes', []):
            draw.polygon([(x-origin[0], z-origin[1]) for x, z in ring], fill=0)
    return np.array(image, dtype=bool)


def polygons(geometry):
    parts = [geometry] if geometry.geom_type == 'Polygon' else geometry.geoms
    return [{'points': [[round(x, 3), round(z, 3)] for x, z in p.exterior.coords],
             'holes': [[[round(x, 3), round(z, 3)] for x, z in ring.coords] for ring in p.interiors]}
            for p in parts if p.geom_type == 'Polygon']


def search(cost, start, goal):
    """A* on a 2 m grid; forbid diagonal corner cutting through hazards."""
    height, width = cost.shape
    sx, sz = start; ex, ez = goal
    assert math.isfinite(cost[sz, sx]) and math.isfinite(cost[ez, ex]), (start, goal, 'Blocked endpoint')
    best = np.full(cost.shape, np.inf)
    best[sz, sx] = 0
    previous = {}
    queue = [(math.hypot(ex-sx, ez-sz), 0.0, sz, sx)]
    while queue:
        _, travelled, z, x = heapq.heappop(queue)
        if travelled != best[z, x]:
            continue
        if (x, z) == goal:
            path = [(x, z)]
            while (x, z) != start:
                x, z = previous[z*width+x]
                path.append((x, z))
            return path[::-1]
        for dx, dz in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
            nx, nz = x+dx, z+dz
            if not (0 <= nx < width and 0 <= nz < height) or not math.isfinite(cost[nz, nx]):
                continue
            if dx and dz and (not math.isfinite(cost[z, nx]) or not math.isfinite(cost[nz, x])):
                continue
            candidate = travelled + (cost[z,x]+cost[nz,nx])*.5*(math.sqrt(2) if dx and dz else 1)
            if candidate < best[nz, nx]:
                best[nz, nx] = candidate
                previous[nz*width+nx] = (x, z)
                heapq.heappush(queue, (candidate+math.hypot(ex-nx, ez-nz), candidate, nz, nx))
    raise ValueError('No dry playing lane between tee and green')


def build(course_id):
    course_path = ROOT / 'courses' / f'{course_id}.json'
    folder = ROOT / 'assets/course_data' / course_id
    course = json.loads(course_path.read_text())
    outlines = json.loads((folder / 'outlines.json').read_text())
    surface = course['layout']['surface']
    origin = np.array(surface['origin'])
    shape = (surface['height'], surface['width'])
    original = np.fromfile(folder/'lies.bin', dtype=np.uint8).reshape(shape)
    # Always regenerate from unmodified source outlines, so reruns cannot widen
    # their own previous results or progressively move the chosen route.
    lies = np.zeros(shape, dtype=np.uint8)
    for kind, value in [('fairway',1), ('tee',1)]:
        lies[raster(outlines[kind], origin, shape)] = value
    green = unary_union([Polygon(p['points'], p.get('holes', [])) for p in outlines['green']])
    lies[raster(polygons(green.buffer(2.2)), origin, shape)] = 2
    for kind, value in [('green',3), ('bunker',4), ('water',5)]:
        lies[raster(outlines[kind], origin, shape)] = value
    # The archived outlines are rounded for JSON. Preserve the exact existing
    # hazard cells rather than shifting their raster edges by a pixel on rebake.
    lies[lies >= 4] = 0
    lies[original >= 4] = original[original >= 4]
    hazards = lies >= 4
    # A 2 m guaranteed core plus a broader preferred clearance. Narrow real tee
    # pads can join the lane without deleting nearby bunkers or moving the tee.
    hazard_image = Image.fromarray(hazards.astype(np.uint8)*255)
    blocked = np.array(hazard_image.filter(ImageFilter.MaxFilter(5))) > 0
    tight = np.array(hazard_image.filter(ImageFilter.MaxFilter(23))) > 0
    clubhouse = np.array(course['layout']['clubhouse']) - origin
    zz, xx = np.ogrid[:shape[0], :shape[1]]
    blocked |= (abs(xx-clubhouse[0]) < 12) & (abs(zz-clubhouse[1]) < 10)
    lanes = []
    report = []
    for number, hole in enumerate(course['holes'], 1):
        route = hole['routing']
        reference = LineString(route['path'])
        coords = np.array([*route['path'], *route['tees'].values()]) - origin
        lo = np.maximum(0, (coords.min(axis=0)-220).astype(int)//GRID_STEP*GRID_STEP)
        hi = np.minimum(np.array(shape[::-1])-1, (coords.max(axis=0)+220).astype(int)//GRID_STEP*GRID_STEP)
        x0, z0 = lo; x1, z1 = hi
        x, z = np.meshgrid(np.arange(x0,x1+1,GRID_STEP), np.arange(z0,z1+1,GRID_STEP))
        sample = lies[z,x]
        deviation = distance(reference, points(x+origin[0], z+origin[1]))
        cost = 1.0 + np.where((sample>=1)&(sample<=3), 0.0, 2.0) + (deviation/45)**2
        cost += tight[z,x]*4.0
        cost[blocked[z,x]] = np.inf
        # Keep the corridor off other putting greens, even if a neighbouring
        # fairway would otherwise be a cheap shortcut.
        for other in course['holes']:
            if other is hole:
                continue
            px,pz = other['routing']['pin']
            cost[((x+origin[0]-px)**2+(z+origin[1]-pz)**2 < 12**2)] = np.inf
        def grid_at(at):
            local = (np.array(at)-origin-lo)/GRID_STEP
            return tuple(np.rint(local).astype(int))
        def route_between(start, end):
            path = search(cost, grid_at(start), grid_at(end))
            world = [tuple(origin+lo+np.array(p)*GRID_STEP) for p in path]
            # Remove only exactly collinear grid vertices. Simplifying across
            # a bend could cut through a bunker or break the clear core.
            keep = [world[0]]
            for i in range(1,len(world)-1):
                dx,dz = np.array(world[i])-world[i-1]
                ex,ez = np.array(world[i+1])-world[i]
                if dx*ez-dz*ex != 0:
                    keep.append(world[i])
            keep.append(world[-1])
            return [[float(a),float(b)] for a,b in [tuple(start),*keep,tuple(end)]]
        try:
            main = route_between(route['tees']['back'], route['pin'])
            branches = {}
            main_line = LineString(main)
            for kind in ['club','forward']:
                at = route['tees'][kind]
                join = main_line.interpolate(main_line.project(Point(at)))
                branches[kind] = route_between(at, [join.x,join.y])
        except (AssertionError, ValueError) as exc:
            raise ValueError(f'{course_id} hole {number}: {exc}') from exc
        route['play_path'] = main
        route['tee_paths'] = branches
        hole_lines = [LineString(p) for p in [main,*branches.values()]]
        lanes.extend(hole_lines)
        report.append({'hole':number,'lane_metres':round(main_line.length,1),
                       'mapped_metres':hole['length']})
    corridor = unary_union(lanes).buffer(LANE_RADIUS)
    mask = raster(polygons(corridor), origin, shape)
    added = mask & (lies == 0)
    lies[added] = 1
    # Clip the displayed adaptation polygons to preserved sand/water outlines.
    hazards_shape = unary_union([Polygon(p['points'],p.get('holes',[])) for k in ['bunker','water'] for p in outlines[k]])
    outlines['play_lanes'] = polygons(corridor.difference(hazards_shape))
    centre_lines = unary_union(lanes)
    before = course['layout']['trees']
    course['layout']['trees'] = [t for t in before if centre_lines.distance(Point(t[:2])) > LANE_RADIUS+3.75*t[2]+2]
    layout = course['layout']
    if layout.get('play_lanes',{}).get('version') != VERSION:
        layout['revision'] += 1
    layout['play_lanes'] = {'version':VERSION, 'preferred_width':LANE_RADIUS*2,
                            'minimum_core_width':4, 'canopy_margin':2,
                            'note':'Gameplay fairway connections around mapped hazards; original routes/outlines retained.'}
    course_path.write_text(json.dumps(course,indent=2)+'\n')
    (folder/'lies.bin').write_bytes(lies.tobytes())
    (folder/'outlines.json').write_text(json.dumps(outlines,separators=(',',':'))+'\n')
    print(course_id, '18 connected lanes;',int(added.sum()),'m² additional fairway;',len(before)-len(layout['trees']),'trees cleared',flush=True)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--course', choices=COURSES, action='append')
    args = parser.parse_args()
    for cid in args.course or COURSES:
        build(cid)
