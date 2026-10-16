import copy
import json
import unittest
from pathlib import Path
from tutorial_digest import aim_angle, aim_caption
from tutorial_copy_facts import resolve_image, validate_candidate, sections

ROOT = Path(__file__).resolve().parents[1]

class CopyFactsTests(unittest.TestCase):
    def setUp(self):
        self.step = {'shot': {'targetKey': '_1', 'pocket': 'topLeft'}, 'analysis': {
            'schemaVersion': 1, 'engineVersion': 'qiuji-planar-reference-20261015',
            'aim': {'targetBallKey': '_1', 'pocket': 'topLeft', 'aimAngleDegrees': 30.25},
            'firstContact': {'actualCutAngleDegrees': 40}}}

    def test_caption_uses_only_aim(self):
        self.assertEqual(aim_caption(self.step, 2), '第2杆：瞄准角约 30.2°')
        self.step['analysis']['aim']['aimAngleDegrees'] = 0
        self.assertEqual(aim_caption(self.step, 2), '第2杆：瞄准角约 0.0°')

    def test_missing_is_not_actual_cut_or_zero(self):
        for value in [None, {}, {'aimAngleDegrees': 30}]:
            with self.subTest(value=value):
                self.step['analysis']['aim'] = value
                self.assertIsNone(aim_angle(self.step)[0])
                self.assertEqual(aim_caption(self.step, 1), '第1杆')

    def test_invalid_angle_rejected(self):
        for value in [True, '30', float('nan'), float('inf'), -1, 181]:
            with self.subTest(value=value):
                self.step['analysis']['aim']['aimAngleDegrees'] = value
                self.assertIsNone(aim_angle(self.step)[0])

    def test_identity_version_free_aim(self):
        for path, value in [('schemaVersion', 2), ('engineVersion', 'old')]:
            s = copy.deepcopy(self.step); s['analysis'][path] = value
            self.assertIsNone(aim_angle(s)[0])
        self.step['analysis']['aim']['pocket'] = 'bottomRight'
        self.assertIsNone(aim_angle(self.step)[0])
        self.step['shot']['freeAim'] = {'x':1,'y':0}
        self.assertEqual(aim_angle(self.step)[1], 'freeAimHasNoPocketLine')

    def test_image_token_with_underscores(self):
        seqs = {'Snipaste_2026_06_19': Path('seq.json'), 'manual01': Path('other.json')}
        self.assertEqual(resolve_image('drill_c035_Snipaste_2026_06_19_s01', 'drill_c035', seqs), (Path('seq.json'),'s01'))
        with self.assertRaises(ValueError): resolve_image('drill_c011_s01', 'drill_c035', seqs)

    def test_candidate_catches_mislabelled_or_changed_inputs(self):
        f = json.loads((ROOT/'output/drill-copy-rewrite-20261015/facts/drill_c011/facts.json').read_text())
        original = json.loads((ROOT/f['source']).read_text()); candidate = copy.deepcopy(original)
        group = dict(sections(candidate))
        for form in f['formations']:
            for row in form['shots']:
                s = group[form['id']][row['sectionIndex']]
                s['params'] = row['params']; s['caption'] = row['caption']
        self.assertEqual(validate_candidate(original,candidate,f), [])
        for key, value in [('caption','第1杆：约 5°'), ('params',{}), ('image','wrong')]:
            c = copy.deepcopy(candidate); dict(sections(c))['single'][f['formations'][0]['shots'][0]['sectionIndex']][key] = value
            self.assertTrue(validate_candidate(original,c,f),key)
        c = copy.deepcopy(candidate); c['sets']['defaultSets'] += 1
        self.assertIn('Protected top-level fields changed',validate_candidate(original,c,f))

if __name__ == '__main__': unittest.main()
