"""Attach authored fin roots and give membranes a thin, two-sided volume.
Only use on the authored roach/tench and photographic reconstructions, not scans.
Blender coordinates: +X mouth, Z up, Y body thickness.
"""
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def repair_fins(obj, photographic=False, anchor_roots=True):
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    # UVs remain per-loop; welding coincident triangle corners makes fin islands
    # explicit without welding across a real anatomical gap.
    weld = list(bm.verts)
    if photographic:
        weld = list({v for f in bm.faces if 'fin membranes' in mesh.materials[f.material_index].name for v in f.verts})
    bmesh.ops.remove_doubles(bm, verts=weld, dist=1e-6)
    bm.verts.ensure_lookup_table()
    unseen = set(bm.verts)
    components = []
    while unseen:
        todo = [unseen.pop()]
        group = []
        while todo:
            vertex = todo.pop()
            group.append(vertex)
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other in unseen:
                    unseen.remove(other)
                    todo.append(other)
        lo = Vector(tuple(min(v.co[k] for v in group) for k in range(3)))
        hi = Vector(tuple(max(v.co[k] for v in group) for k in range(3)))
        components.append((group, hi - lo))
    body, size = max(components, key=lambda part: part[1].x * part[1].y * part[1].z)
    body_set = set(body)
    body_faces = [f for f in bm.faces if f.verts[0] in body_set]
    indices = {v: i for i, v in enumerate(body)}
    tree = BVHTree.FromPolygons([v.co for v in body], [[indices[v] for v in f.verts] for f in body_faces])
    length = max(v.co.x for v in bm.verts) - min(v.co.x for v in bm.verts)
    repaired = 0
    discarded = 0
    fin_faces = []
    for group, extent in components:
        if group is body:
            continue
        faces = set(f for v in group for f in v.link_faces)
        if photographic:
            if not faces or not all('fin membranes' in mesh.materials[f.material_index].name for f in faces):
                continue
        elif extent.y > 1e-5:
            continue  # Barbels are volumetric; keep their authored placement.
        nearest = {v: tree.find_nearest(v.co) for v in group}
        gap = min(value[3] for value in nearest.values())
        if photographic and len(group) < 20 and extent.y < 1e-5:
            bmesh.ops.delete(bm, geom=group, context='VERTS')
            discarded += 1
            continue
        # Extend only the root band into skin; fin tips and their UVs stay put.
        band = min(gap + length * .014, length * .045)
        if anchor_roots:
            for vertex, (point, normal, _, distance) in nearest.items():
                if distance <= band:
                    vertex.co = point - normal * length * .0008
        fin_faces.extend(faces)
        repaired += 1
    if fin_faces:
        # Solidify after anchoring; a millimetre on a 1 m specimen is enough
        # to retain the dorsal silhouette in an edge-on view.
        # Constant-axis extrusion avoids unbounded mitres at the tiny, jagged
        # corners of traced membranes (normal-based solidify can form spikes).
        originals = set(v for face in fin_faces for v in face.verts)
        result = bmesh.ops.extrude_face_region(bm, geom=fin_faces, use_keep_orig=True)
        for vertex in originals:
            vertex.co.y -= length * .00075
        for item in result['geom']:
            if isinstance(item, bmesh.types.BMVert):
                item.co.y += length * .00075
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return {'fin_islands': repaired, 'discarded_speckles': discarded}
