"""Run: python tests/photographic_surfaces.py (NumPy and Pillow required)."""
import json
import sys
import unittest
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from fish_surface_sampling import BodyUVSampler
from repair_photographic_surfaces import GLB, closest_surface


class PhotographicSurfaces(unittest.TestCase):
    def test_reference_background_does_not_replace_bright_scale_markings(self):
        pixels = np.ones((100, 120, 3))
        pixels[20:80] = .3
        pixels[45:55, 45:55] = 1  # A real bright marking inside the body.
        anatomy = {'body': [[0, 20, 79, .1], [119, 20, 79, .1]], 'eye': [105, 50, 5]}
        sampler = BodyUVSampler(pixels, anatomy)
        self.assertGreater(sampler.sample(50, 20)[1], 20)
        self.assertTrue(45 < sampler.sample(50, 50)[1] < 55)
        self.assertEqual(sampler.sample(105, 20), (105, 20))

    def test_back_samples_remain_distinct_around_the_cross_section(self):
        pixels = np.ones((100, 120, 3)); pixels[20:80] = .3
        anatomy = {'body': [[0, 20, 79, .1], [119, 20, 79, .1]], 'eye': [105, 50, 5]}
        sampler = BodyUVSampler(pixels, anatomy)
        angles = np.linspace(np.pi/2, np.pi/4, 17)
        samples = np.array([sampler.sample(50, 49.5-29.5*np.sin(a), .1*np.cos(a))[1] for a in angles])
        self.assertTrue((np.diff(samples) > .5).all(), 'Clamped rows stretch markings into stripes')
        self.assertGreater(samples[0], 20)

    def test_rear_back_triangles_have_texture_area(self):
        for name in json.loads((ROOT / 'source/fish_references/anatomy.json').read_text()):
            with self.subTest(fish=name):
                glb = GLB(ROOT / 'assets/models/fish' / (name + '.glb'))
                skin = glb.doc['meshes'][0]['primitives'][0]
                faces = glb.array(skin['indices']).reshape(-1, 3)
                positions = glb.array(skin['attributes']['POSITION'])[faces]
                uv = glb.array(skin['attributes']['TEXCOORD_0'])[faces]
                # Exclude the end cap (a side projection has no UV area there).
                rear = (positions.mean(axis=1)[:, 0] < 0) & (np.ptp(positions[:, :, 0], axis=1) > 1e-6)
                valid = np.linalg.norm(np.cross(positions[:, 1]-positions[:, 0], positions[:, 2]-positions[:, 0]), axis=1) > 1e-8
                ab, ac = uv[:, 1]-uv[:, 0], uv[:, 2]-uv[:, 0]
                area = np.abs(ab[:, 0]*ac[:, 1] - ab[:, 1]*ac[:, 0])
                self.assertTrue((area[rear & valid] > 1e-10).all(), 'Collapsed back UVs produce stripes')

    def test_exported_bodies_are_closed(self):
        names = json.loads((ROOT / 'source/fish_references/anatomy.json').read_text())
        for name in names:
            with self.subTest(fish=name):
                glb = GLB(ROOT / 'assets/models/fish' / (name + '.glb'))
                primitive = glb.doc['meshes'][0]['primitives'][0]
                positions = glb.array(primitive['attributes']['POSITION'])
                self.assertTrue(np.isfinite(positions).all())
                _, weld = np.unique(np.round(positions, 5), axis=0, return_inverse=True)
                faces = weld[glb.array(primitive['indices']).reshape(-1, 3)]
                adjacent = {}
                for face in faces:
                    for index in face:
                        adjacent.setdefault(index, set()).update(face)
                unseen = set(adjacent)
                parts = []
                while unseen:
                    part = {unseen.pop()}
                    todo = list(part)
                    while todo:
                        for other in adjacent[todo.pop()]:
                            if other in unseen:
                                unseen.remove(other); part.add(other); todo.append(other)
                    parts.append(part)
                body = max(parts, key=len)  # Exclude separate lip/barbel strips.
                faces = faces[np.isin(faces, list(body)).all(axis=1)]
                faces = faces[(faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) & (faces[:, 0] != faces[:, 2])]
                edges = np.sort(np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]), axis=1)
                _, counts = np.unique(edges, axis=0, return_counts=True)
                self.assertTrue((counts == 2).all(), 'Open or nonmanifold body edge')

    def test_cornea_rims_stay_on_the_skin(self):
        for name in ['pike', 'gudgeon', 'grayling']:
            with self.subTest(fish=name):
                glb = GLB(ROOT / 'assets/models/fish' / (name + '.glb'))
                skin, _, eye = glb.doc['meshes'][0]['primitives']
                body = glb.array(skin['attributes']['POSITION'])[glb.array(skin['indices']).reshape(-1, 3)]
                positions = glb.array(eye['attributes']['POSITION'])
                low, high = positions.min(axis=0), positions.max(axis=0)
                body = body[(body[:, :, 0].max(axis=1) >= low[0] - .03) & (body[:, :, 0].min(axis=1) <= high[0] + .03)]
                gap = max(np.linalg.norm(point - closest_surface(point, body)) for point in positions)
                self.assertLess(gap, .0026, 'Eye rim forms a protruding tube')


if __name__ == '__main__':
    unittest.main()
