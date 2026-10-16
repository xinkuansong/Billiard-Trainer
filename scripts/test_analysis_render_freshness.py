"""Metadata-only freshness must still reject changed shot inputs and stale images."""
import hashlib
import json
import os
import tempfile
import unittest
from pathlib import Path
import verify_tutorial_sync as v

class AnalysisFreshnessTests(unittest.TestCase):
    def check(self, change=None, proof=True):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); paths = v.Paths(root)
            source = paths.sequences/'drill_c001__manual01.json'
            source.parent.mkdir(parents=True)
            directory = paths.export/source.stem; directory.mkdir(parents=True)
            original = {'steps':[{'before':{'x':0.2},'after':{'x':0.3},'shot':{'velocity':2},'recordedDirection':{'x':1,'z':0}}]}
            hashes = {}
            for name in ['initial.png','s01_still.png','final.png']:
                p = directory/name; p.write_bytes(name.encode());os.utime(p,(1,1))
                hashes[name] = hashlib.sha256(p.read_bytes()).hexdigest()
            stamp = {'schemaVersion':1,'sequence':original,'framesSHA256':hashes}
            if proof: (directory/'render-input.json').write_text(json.dumps(stamp))
            current = json.loads(json.dumps(original));current['steps'][0]['analysis']={'aim':{'aimAngleDegrees':35}}
            if change == 'shot':current['steps'][0]['shot']['velocity']=3
            if change == 'before':current['steps'][0]['before']['x']=0.21
            if change == 'after':current['steps'][0]['after']['x']=0.4
            if change == 'direction':current['steps'][0]['recordedDirection']['x']=0
            if change == 'image':(directory/'s01_still.png').write_bytes(b'wrong')
            if change == 'proof':(directory/'render-input.json').write_text('{}')
            source.write_text(json.dumps(current))
            return v.check_export_freshness({'drill_c001':[{'shots':1,'stem':source.stem,'path':source}]},paths)
    def test_metadata_only_is_valid_with_evidence(self):self.assertEqual(self.check()['ok'],1)
    def test_all_physical_changes_are_rejected(self):
        for change in ['shot','before','after','direction']:
            with self.subTest(change=change):self.assertEqual(len(self.check(change)['fail']),1)
    def test_bad_image_and_proof_are_rejected(self):
        for change in ['image','proof']:
            with self.subTest(change=change):self.assertEqual(len(self.check(change)['fail']),1)
    def test_missing_proof_retains_old_freshness_check(self):self.assertEqual(len(self.check(proof=False)['fail']),1)

if __name__ == '__main__': unittest.main()
