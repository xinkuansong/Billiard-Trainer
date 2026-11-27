from pathlib import Path
import copy,gzip,json,unittest
from audit import audit
OUT=Path(__file__).resolve().parents[2]/'output/defense-multisolution-full-20261106'
class RejectCorruption(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.payload=next(v for p in (OUT/'pilot/records').glob('*.json.gz') if (v:=json.loads(gzip.decompress(p.read_bytes())))['record']['result']['retainedCount']>=2)
 def check_rejects(self,mutate):
  payload=copy.deepcopy(self.payload);record=payload['record'];expected=copy.deepcopy(record['question']);mutate(record)
  with self.assertRaises(AssertionError):audit(record,payload['metrics'],expected,record['identity'])
 def test_original_passes(self):
  p=self.payload;r=p['record'];audit(r,p['metrics'],r['question'],r['identity'])
 def test_duplicate_route_is_not_multiple(self):
  def mutate(r):r['result']['routes']=[r['result']['routes'][0]]*r['result']['retainedCount']
  self.check_rejects(mutate)
 def test_fixed_ball_move_rejected(self):
  def mutate(r):r['result']['routes'][0]['finalPositions']['_'+str(r['question']['opponentBallNumber'])][0]+=.01
  self.check_rejects(mutate)
 def test_wrong_opponent_metadata_rejected(self):
  self.check_rejects(lambda r:r['result']['routes'][0]['effect'].update(opponentBallNumber=15))
 def test_failing_probe_rejected(self):
  self.check_rejects(lambda r:r['result']['routes'][0]['probes'][0].update(passes=False))
 def test_jaw_contact_rejected(self):
  def mutate(r):
   next(e for e in r['result']['routes'][0]['events'] if e['kind']=='cushion')['index']=6
  self.check_rejects(mutate)
 def test_coordinate_change_rejected(self):
  self.check_rejects(lambda r:r['question']['cue'].__setitem__(0,1.234))
if __name__=='__main__':unittest.main()
