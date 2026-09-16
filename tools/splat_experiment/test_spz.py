"""Analytic records exercise quantization, signed positions and SH ordering."""
import gzip
import math
from pathlib import Path
import struct
import tempfile
import unittest
from spz_to_ply import convert, quaternion, decode


class SpzTests(unittest.TestCase):
    def test_smallest_three_identity_and_axis(self):
        self.assertEqual(quaternion((3 << 30).to_bytes(4, 'little'), 3), [1, 0, 0, 0])
        self.assertEqual(quaternion(bytes(4), 3), [0, 1, 0, 0])
        q = quaternion(((3 << 30) | 511).to_bytes(4, 'little'), 3)
        self.assertAlmostEqual(q[0], math.sqrt(0.5))
        self.assertAlmostEqual(q[3], math.sqrt(0.5))

    def test_v2_coordinates_and_coefficients(self):
        with tempfile.TemporaryDirectory() as temp:
            source, target = Path(temp)/'test.spz', Path(temp)/'test.ply'
            raw = struct.pack('<IIIBBBB', 0x5053474E, 2, 1, 1, 8, 0, 0)
            raw += b''.join(x.to_bytes(3, 'little', signed=True) for x in [-256, 512, -128])
            raw += bytes([128]) + bytes([128, 64, 255]) + bytes([160, 144, 128])
            raw += bytes([128, 128, 128]) + bytes(range(128, 137))
            source.write_bytes(gzip.compress(raw))
            info = convert(source, target)
            self.assertEqual(info['center'], [-1, 2, -0.5])
            payload = target.read_bytes().split(b'end_header\n')[1]
            row = struct.unpack('<23f', payload)
            self.assertEqual(list(row[:3]), [-1, 2, -0.5])
            self.assertEqual(list(row[6:15]), [v/128 for v in [0,3,6,1,4,7,2,5,8]])
            self.assertEqual(list(row[16:19]), [0, -1, -2])
            self.assertAlmostEqual(sum(x*x for x in row[19:23]), 1, places=6)
            source.write_bytes(gzip.compress(raw[:-1]))
            with self.assertRaises(ValueError): decode(source)


if __name__ == '__main__':
    unittest.main()
