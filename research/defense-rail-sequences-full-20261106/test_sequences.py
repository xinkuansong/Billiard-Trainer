import unittest,json
from pathlib import Path
from audit import rail_sequences

def c(ball,index):return dict(kind='cushion',ball=ball,index=index)
def key(events):
 s=rail_sequences(events,'_8');return tuple(s['cue']),tuple(s['target'])
class RailSequenceTests(unittest.TestCase):
 def test_both_empty(self):self.assertEqual(key([]),((),()))
 def test_interleaving_is_irrelevant(self):self.assertEqual(key([c('cueBall',2),c('_8',5),c('cueBall',4)]),key([c('_8',5),c('cueBall',2),c('cueBall',4)]))
 def test_each_order_matters(self):self.assertNotEqual(key([c('cueBall',2),c('cueBall',4)]),key([c('cueBall',4),c('cueBall',2)]))
 def test_target_order_matters(self):self.assertNotEqual(key([c('_8',2),c('_8',4)]),key([c('_8',4),c('_8',2)]))
 def test_repeated_contact_counts(self):self.assertNotEqual(key([c('cueBall',5),c('cueBall',5)]),key([c('cueBall',5)]))
 def test_balls_are_not_swappable(self):self.assertNotEqual(key([c('cueBall',5)]),key([c('_8',5)]))
 def test_contacts_do_not_add_classes(self):self.assertEqual(key([{'kind':'ballBall','balls':['cueBall','_8']},c('_8',5)]),key([c('_8',5)]))
 def test_user_g0042(self):
  p=Path(__file__).resolve().parents[2]/'output/defense-multisolution-gallery-20261106/cases/G0042/routes.json';r=json.loads(p.read_text())['result']['routes'];groups={}
  for x in r:groups.setdefault(key(x['events']),[]).append(x['id'])
  self.assertEqual(groups,{((),(5,)):[1],((5,),(5,)):[2,3,4,5,6]})
if __name__=='__main__':unittest.main()
