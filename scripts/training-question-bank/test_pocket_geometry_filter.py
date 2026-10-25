import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from pocket_geometry_filter import (
    Geometry, PocketMetrics, Thresholds, clearly_better, evaluate_layout,
    layouts, pocket_metrics, validate_bank,
)


class PocketGeometryFilterTests(unittest.TestCase):
    def metric(self, angle, distance, pocket=0):
        return PocketMetrics(pocket, angle, distance)

    def test_inclusive_angle_and_distance_boundaries(self):
        self.assertTrue(clearly_better(self.metric(50, 1.2), self.metric(35, .9, 1)))
        self.assertFalse(clearly_better(self.metric(50, 1.2), self.metric(35.0001, .9, 1)))
        self.assertFalse(clearly_better(self.metric(50, 1.2), self.metric(35, .900001, 1)))

    def test_both_distance_tests_required(self):
        # 40 cm but only 20%; 25% but only 20 cm. Neither qualifies.
        self.assertFalse(clearly_better(self.metric(50, 2), self.metric(20, 1.6, 1)))
        self.assertFalse(clearly_better(self.metric(50, .8), self.metric(20, .6, 1)))

    def test_ratio_denominator_is_original_distance(self):
        # 30 cm / 1.4 m < 25%, although 30 cm / 1.1 m > 25%.
        self.assertFalse(clearly_better(self.metric(50, 1.4), self.metric(20, 1.1, 1)))

    def test_tradeoffs_and_single_improvement_keep(self):
        a = self.metric(50, 1.2)
        for b in (self.metric(20, 1.5, 1), self.metric(60, .5, 1),
                  self.metric(50, .5, 1), self.metric(20, 1.2, 1)):
            with self.subTest(candidate=b):
                self.assertFalse(clearly_better(a, b))

    def test_same_pocket_never_eliminates_itself(self):
        self.assertFalse(clearly_better(self.metric(50, 1.2), self.metric(20, .5)))

    def test_invalid_metrics_and_thresholds_raise(self):
        for angle, distance in ((float('nan'), 1), (20, float('inf')), (-1, 1), (20, 0)):
            with self.subTest(angle=angle, distance=distance), self.assertRaises(ValueError):
                clearly_better(self.metric(50, 1.2), self.metric(angle, distance, 1))
        for kwargs in ({'angle_improvement_degrees': 0}, {'distance_reduction_fraction': 1},
                       {'distance_improvement_metres': float('nan')}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                Thresholds(**kwargs)

    def test_custom_thresholds_are_used(self):
        a, b = self.metric(40, 1), self.metric(30, .8, 1)
        self.assertFalse(clearly_better(a, b))
        self.assertTrue(clearly_better(a, b, Thresholds(10, .2, .2)))

    def test_generation_anchors_and_ids(self):
        g = Geometry(2.54, 1.27, .028575)
        expected = ((-1.241425, -.606425), (1.241425, -.606425),
                    (-1.241425, .606425), (1.241425, .606425), (0, -.635), (0, .635))
        for actual, wanted in zip(g.anchors(), expected):
            self.assertLess(math.dist(actual, wanted), 1e-14)

    def test_analytic_cut_angles_both_sides(self):
        radius = .028575
        for angle in (0, 15, 30, 45, 70, 85):
            for sign in (-1, 1):
                a = math.radians(angle * sign)
                cue = (-2 * radius - .5 * math.cos(a), -.5 * math.sin(a))
                m = pocket_metrics(cue, (0, 0), (1, 0), radius, 0)
                self.assertAlmostEqual(m.cut_degrees, angle, places=11)
                self.assertEqual(m.object_distance_metres, 1)

    def test_cut_uses_ghost_not_object_center(self):
        r = .028575
        cue = (-2 * r - .3 / math.sqrt(2), -.3 / math.sqrt(2))
        m = pocket_metrics(cue, (0, 0), (1, 0), r, 0)
        self.assertAlmostEqual(m.cut_degrees, 45)
        center_angle = math.degrees(math.atan2(-cue[1], -cue[0]))
        self.assertGreater(abs(center_angle - m.cut_degrees), 5)

    def test_degenerate_geometry_raises(self):
        with self.assertRaises(ValueError):
            pocket_metrics((0, 0), (1, 0), (1, 0), .03, 0)
        with self.assertRaises(ValueError):
            pocket_metrics((-.06, 0), (0, 0), (1, 0), .03, 0)
        with self.assertRaises(ValueError):
            evaluate_layout((0, 0), (.01, 0), 0, Geometry(2.54, 1.27, .028575))

    def test_mirror_preserves_all_decisions_and_metrics(self):
        g = Geometry(2.54, 1.27, .028575)
        xmap, zmap = (1, 0, 3, 2, 4, 5), (2, 3, 0, 1, 5, 4)
        for sx, sz, mapping in ((-1, 1, xmap), (1, -1, zmap)):
            for pid in range(6):
                a = evaluate_layout((-.7, .2), (.3, -.1), pid, g)
                b = evaluate_layout((-.7*sx, .2*sz), (.3*sx, -.1*sz), mapping[pid], g)
                self.assertEqual(a.status, b.status)
                self.assertEqual({mapping[m.pocket] for m in a.alternatives},
                                 {m.pocket for m in b.alternatives})
                for m in a.metrics:
                    mirrored = b.metrics[mapping[m.pocket]]
                    self.assertAlmostEqual(m.cut_degrees, mirrored.cut_degrees)
                    self.assertAlmostEqual(m.object_distance_metres, mirrored.object_distance_metres)

    def test_current_bank_contract_and_reconstruction_sample(self):
        root = Path(__file__).resolve().parents[2]
        bank = json.loads((root/'QiuJi/Resources/training-grid-bank.json').read_text())
        g = Geometry(**{k: bank['geometry'][k] for k in ('length', 'width', 'radius')})
        validate_bank(bank, g)
        # One real layout per target, retaining all six pockets and target positions.
        seen = set()
        for lid, cue, target, pid, expected in layouts(bank):
            inventory = lid.split(':')[1]
            if inventory in seen:
                continue
            seen.add(inventory)
            d = evaluate_layout(cue, target, pid, g)
            self.assertAlmostEqual(d.original.cut_degrees, expected, places=9)
        self.assertEqual(len(seen), len(bank['targets']))
        bank['targets'][0]['aim']['x'] += .001
        with self.assertRaisesRegex(ValueError, 'anchor'):
            validate_bank(bank, g)

    def test_actual_cli_preserves_source_and_refuses_overwrite(self):
        script = Path(__file__).with_name('pocket_geometry_filter.py')
        source = script.parents[2]/'QiuJi/Resources/training-grid-bank.json'
        before = source.read_bytes()
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)/'result'
            command = [sys.executable, str(script), '--limit', '25', '--output', str(output)]
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            summary = json.loads((output/'summary.json').read_text())
            self.assertEqual(sum(summary['counts'].values()), 25)
            self.assertFalse(summary['complete'])
            saved = (output/'summary.json').read_bytes()
            repeated = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(repeated.returncode, 0)
            self.assertEqual((output/'summary.json').read_bytes(), saved)
        self.assertEqual(source.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
