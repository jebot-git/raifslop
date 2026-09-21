"""Map photographed flanks around a closed body without collapsing the back UVs.

A side projection has zero texture width at the top of a round fish. Hard
clamping it to the silhouette inset makes a whole band sample one image row,
turning scales into stripes. Arc-length mapping keeps that band two-dimensional.
"""
import numpy as np


class BodyUVSampler:
    def __init__(self, pixels, anatomy, threshold=.92):
        self.height, self.width = pixels.shape[:2]
        profile = np.asarray(anatomy['body'], dtype=float)
        # Match the cubic silhouette used by the body generator.
        dense = []
        steps = anatomy.get('profile_steps', 6)
        for i in range(len(profile) - 1):
            a, b, c, d = [profile[k] for k in (max(0, i - 1), i, i + 1, min(len(profile) - 1, i + 2))]
            for j in range(steps):
                t = j / steps
                dense.append(.5 * (2*b + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t*t*t))
        dense.append(profile[-1]); dense = np.asarray(dense)
        columns = np.arange(self.width)
        self.contour = np.column_stack([np.interp(columns, dense[:, 0], dense[:, k]) for k in (1, 2)])
        self.widths = np.interp(columns, dense[:, 0], dense[:, 3])
        self.eye_start = anatomy['eye'][0] - anatomy['eye'][2] * 1.5
        self.face_blend = max(24, anatomy['eye'][2] * 3)
        bounds = []
        for x, (top, bottom) in enumerate(self.contour):
            colored = pixels[:, x, :3].min(axis=1) < threshold
            band = min(16, (bottom - top) * .12)
            rows = np.arange(max(0, int(top - 8)), min(self.height, int(top + band) + 1))
            white = rows[~colored[rows]]
            if len(white): top = max(top, white[-1] + 1)
            rows = np.arange(max(0, int(bottom - band)), min(self.height, int(bottom + 8) + 1))
            white = rows[~colored[rows]]
            if len(white): bottom = min(bottom, white[0] - 1)
            margin = min(4, (bottom - top) * .15)
            bounds.append((top + margin, bottom - margin))
        bounds = np.asarray(bounds)
        self.bounds = np.asarray([(bounds[max(0, x-6):x+7, 0].max(), bounds[max(0, x-6):x+7, 1].min()) for x in columns])

    def sample(self, x, y, side=None):
        if x >= self.eye_start:
            return x, y  # Preserve eye/mouth landmarks and separate lip strips.
        columns = np.arange(self.width)
        top, bottom = [np.interp(x, columns, self.contour[:, k]) for k in (0, 1)]
        lo, hi = [np.interp(x, columns, self.bounds[:, k]) for k in (0, 1)]
        t = np.clip((y - top) / max(bottom - top, 1), 0, 1)
        arc = .5 + np.arcsin(2*t - 1) / np.pi
        if side is not None:
            width = max(np.interp(x, columns, self.widths), 1e-8)
            vertical = ((top+bottom)*.5-y) / max((bottom-top)*.5, 1)
            # Actual cross-section angle stays distinct even where retained
            # mesh vertices lie slightly outside the authored silhouette.
            arc = .5 - np.arctan2(vertical, abs(side)/width) / np.pi
        mapped = lo + (hi-lo)*arc
        blend = np.clip((self.eye_start - x) / self.face_blend, 0, 1)
        blend = blend*blend*(3-2*blend)
        return x, float(y + (mapped-y)*blend)


def inside_region(x, y, polygon):
    inside = False
    for i, (ax, ay) in enumerate(polygon):
        bx, by = polygon[i - 1]
        if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
            inside = not inside
    return inside
