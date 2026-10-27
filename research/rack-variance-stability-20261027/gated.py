from pathlib import Path
import gzip,json,hashlib
from study import ROOT,positions
from diagnose import features

OUT=ROOT/'output/rack-variance-stability-20261027'
def main(folder):
    frozen=json.loads((OUT/'gated-rule-frozen.json').read_text());assert frozen['thresholdMicrometers']==0
    for p,h in frozen['sourceSHA'].items():assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h
    rows=json.loads((folder/'scalars.json').read_text());source={(r['id'],r['policy']):r for r in rows if r['cohort']=='holdout' and r['condition']=='original'}
    choices=[];derived=[]
    for line in gzip.open(folder/'layouts.jsonl.gz','rt'):
        g=json.loads(line)
        if g['input']['cohort']!='holdout':continue
        fs={};ps={}
        for p in ['B','C']:
            pos=positions(g,p);ps[p]=pos
            fs[p]=features(dict(g,rack=[dict(b,x=q[0],z=q[1]) for b,q in zip(g['rack'],pos)]))
        switch=any(fs['B'][k]<=0 and fs['C'][k]>0 for k in ['branchPlus','branchMinus'])
        p='C' if switch else 'B';rid=g['input']['rackID'];ref=source[rid,p]
        choices.append(dict(id=rid,selected=p,margins={p:{k:fs[p][k] for k in ['branchPlus','branchMinus']} for p in ['B','C']},rackXZ=ps[p]))
        derived.append(dict(ref,policy='geometry_gated_C',selectedPolicy=p))
    # Prove the chosen geometry was actually simulated, rather than infer its outcome.
    byid={c['id']:c for c in choices};checked=0
    for line in gzip.open(folder/'raw.jsonl.gz','rt'):
        r=json.loads(line);q=r['input']
        if q['cohort']!='holdout' or q['condition']!='original':continue
        choice=byid[q['rackID']]
        if q['policy']!=choice['selected']:continue
        assert [[b['x'],b['z']] for b in r['rack']]==choice['rackXZ'];checked+=1
    assert checked==len(derived)==200
    for name,obj in [('gated-rows.json',derived),('gated-selections.json',choices)]:
        (folder/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
    print(folder.name,'selected C',sum(c['selected']=='C' for c in choices),'exact geometry matches',checked)
if __name__=='__main__':
    for folder in [OUT,OUT/'stage2']:
        if (folder/'closure.json').exists() and json.loads((folder/'closure.json').read_text())['success']:main(folder)
