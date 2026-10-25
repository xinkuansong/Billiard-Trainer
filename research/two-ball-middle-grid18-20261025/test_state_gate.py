"""Constructive control-flow regression: changed rail state never reaches scoring."""
import copy,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import pipeline as P
class GateTests(unittest.TestCase):
 def test_count_and_order_changes_are_not_scored(self):
  root={'comboIndex':7,'velocity':2.,'spinX':P.common.f32(.1),'spinY':0.,'strokeCategory':'horizontal','cueStop':[.2,.1],'cueMainRailsAfterContact':2,'cueJawsAfterContact':0,'cueOtherCushionsAfterContact':0,'trajectory2mm':{'points':[[0,0,0],[1,.3,.2],[2,.2,.1]],'cushions':[{'cushionID':0},{'cushionID':1}]}}
  old={'id':'gate-test','board':{'id':'gate-test','cue':[-.3,.3],'object':[0,0]},'routes':[root],'candidates':[{'cellID':1,'position':[-.3,-.3],'top5':[{'comboIndex':7,'score':1.,'pocket':0,'angle':10.}]}]}
  seen=[];generated=[]
  class Worker:
   def run(self,board,cs):
    rows=[]
    for c in cs:
     r=copy.deepcopy(root);r.update(c,status='success',simulationCalls=1)
     if c['comboIndex']!=7:
      # Both changed count and same count/different order must fail.
      ids=[0] if c['comboIndex']%2 else [1,0]
      r['cueMainRailsAfterContact']=len(ids);r['trajectory2mm']['cushions']=[{'cushionID':i} for i in ids];generated.append(r['comboIndex'])
     rows.append(r)
    return {'rows':rows}
  def scoring(r,b,board):
   seen.append(r['comboIndex']);self.assertEqual(P.seq(r),(0,1))
   return [{'pocket':0,'angle':10.,'distance':.5,'score':.5}],None
  with tempfile.TemporaryDirectory() as td,patch.object(P.C,'normalize',lambda r:None),patch.object(P.C,'reason',lambda r:None),patch.object(P,'candidate_options',scoring),patch.object(P.C,'independent_angle',lambda *a:10.):
   result,trace,stats=P.stage_b(old,Worker(),Path(td))
  self.assertEqual(seen,[7]);self.assertEqual(len(generated),244)
  self.assertEqual(stats['rejectedBeforeScoring']['railStateChanged'],244)
  self.assertEqual(result['candidates'][0]['top5'][0]['comboIndex'],7)
  self.assertEqual(trace['candidates'][0]['roots'][0]['optimal']['comboIndex'],7)
if __name__=='__main__':unittest.main()
