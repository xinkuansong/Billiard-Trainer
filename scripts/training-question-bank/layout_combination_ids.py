#!/usr/bin/env python3
"""Add per-layout combination references to the solution-free v3 grid export."""
import collections
import gzip
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import grid_inventory_report as geometry

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'output/accuracy-layout-bank-v3-20261021/grid-layouts-only.json'
INVENTORY = ROOT/'output/accuracy-grid-staggered-v3-20261021/inventory.json'
MIDDLE = ROOT/'output/accuracy-middle-v3-20261021'
OUT = ROOT/'output/accuracy-layout-bank-v3-ids-20261021'
BACKUP = Path('/Users/song/backups/billiard-trainer/accuracy-middle-v3-20261021/layout-bank-with-combination-ids')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def entries(target, distances):
    """Stable layout order; runtime consumers need no classification calculation."""
    ordinal = 0
    for angle_index, mask in enumerate(target['masks']):
        for distance_bit in range(len(distances)):
            if mask & (1 << distance_bit):
                yield ordinal, angle_index, distance_bit
                ordinal += 1


def classify_vectorized(target, data):
    # Same X/Z metres and original classification thresholds as the native inventory.
    o, g, p = (geometry.point(target[k]) for k in ('object', 'ghost', 'aim'))
    backward = (g-o)/np.linalg.norm(g-o)
    betas = np.arange(-85, 86)
    radians = np.deg2rad(betas)
    dirs = np.stack((backward[0]*np.cos(radians)-backward[1]*np.sin(radians),
                     backward[0]*np.sin(radians)+backward[1]*np.cos(radians)), axis=-1)
    cues = g+dirs[:, None, :]*np.array(data['distanceSamples'])[None, :, None]
    co = np.linalg.norm(cues-o, axis=-1)
    op = float(np.linalg.norm(p-o))
    angles = np.select([abs(betas)<=10, abs(betas)<=30, abs(betas)<=50, abs(betas)<=70], [0,1,2,3], default=4)
    gap = geometry.rail_gap(o, data['geometry'])
    rail = 2 if abs(gap)<=geometry.EPSILON else 1 if gap<=.1+geometry.EPSILON else 0
    codes = (((angles[:,None]*2+int(target['pocket']>=4))*3+geometry.band(co))*3+geometry.band(op))*3+rail
    masks = np.array(target['masks'], dtype=np.uint16)
    valid = ((masks[:,None] >> np.arange(len(data['distanceSamples']))) & 1).astype(bool)
    return codes[valid].tolist()


def audit(data, original, inventory):
    assert data['counts']==original['counts'] and data['geometry']==original['geometry']
    assert data['distanceSamples']==original['distanceSamples']
    table = data['combinationTable']
    assert len(table)==270 and len({c['id'] for c in table})==270
    assert table == [dict(id=geometry.cell_id(c['cell']), **c['cell']) for c in inventory['cells']]
    counts = collections.Counter()
    mapping = {}
    example = None
    for old, target in zip(original['targets'], data['targets'], strict=True):
        assert {k:v for k,v in target.items() if k!='combinationIndices'} == old
        codes = target['combinationIndices']
        assert len(codes) == sum(m.bit_count() for m in target['masks'])
        assert all(type(c) is int and 0<=c<len(table) for c in codes)
        mapping[target['inventoryTargetIndex']] = target
        # Independent scalar reconstruction checks every stored code after JSON reload.
        ox,oz=target['object']['x'],target['object']['z']
        gx,gz=target['ghost']['x'],target['ghost']['z']
        px,pz=target['aim']['x'],target['aim']['z']
        length=math.hypot(gx-ox,gz-oz);bx,bz=(gx-ox)/length,(gz-oz)/length
        op=math.hypot(px-ox,pz-oz)
        gaps=[]
        for line in data['geometry']['lines'][:6]:
            ax,az=line['start']['x'],line['start']['z']
            dx,dz=line['end']['x']-ax,line['end']['z']-az
            u=max(0,min(1,((ox-ax)*dx+(oz-az)*dz)/(dx*dx+dz*dz)))
            gaps.append(math.hypot(ox-ax-u*dx,oz-az-u*dz)-data['geometry']['radius'])
        gap=min(gaps);rail=2 if abs(gap)<=4*2**-23 else 1 if gap<=.1+4*2**-23 else 0
        band=lambda distance: 0 if distance<=.600001 else 1 if distance<=1.200001 else 2
        for ordinal,mi,bit in entries(target,data['distanceSamples']):
            beta=mi-85;a=math.radians(beta);d=data['distanceSamples'][bit]
            cx=gx+d*(bx*math.cos(a)-bz*math.sin(a))
            cz=gz+d*(bx*math.sin(a)+bz*math.cos(a))
            ai=next(i for i,lim in enumerate([10,30,50,70,85]) if abs(beta)<=lim)
            cell=dict(angleIndex=ai,pocketType=int(target['pocket']>=4),cueIndex=band(math.hypot(cx-ox,cz-oz)),objectIndex=band(op),railIndex=rail)
            cid=geometry.cell_id(cell)
            assert table[codes[ordinal]]['id']==cid
            counts[cid]+=1
            if target['inventoryTargetIndex']==1927 and mi==79 and bit==1:
                example=dict(inventoryTargetIndex=1927,maskIndex=mi,distanceBit=bit,
                             layoutOrdinal=ordinal,combinationIndex=codes[ordinal],combination=table[codes[ordinal]])
    for c in inventory['cells']:
        if c['cell']['pocketType']==0:
            assert counts[geometry.cell_id(c['cell'])]==c['gridPlacement']+c['boundaryPlacement']
    for c in json.loads((MIDDLE/'cell-results.json').read_text()):
        assert counts[c['cellID']]==c['passed']
    # Compare all successful middle IDs with actual generation/screening records.
    request=json.loads((MIDDLE/'consumed-request.json').read_text())
    lookups={ti:{(mi,bit):t['combinationIndices'][ordinal] for ordinal,mi,bit in entries(t,data['distanceSamples'])}
             for ti,t in mapping.items() if t['pocket']>=4}
    middle_count=0
    for bi,batch in enumerate(request['batches']):
        samples=json.loads((MIDDLE/batch['file']).read_text())['samples']
        results=json.loads((MIDDLE/f'results-{bi:03d}.json').read_text())
        for sample,result in zip(samples,results,strict=True):
            if not result.get('proof'):continue
            assert sample['sampleIndex']==result['sampleIndex']
            ci=lookups[sample['targetIndex']][sample['maskIndex'],sample['distanceBit']]
            assert table[ci]['id']==sample['cellID']==result['cellID']
            middle_count+=1
    assert middle_count==202296 and sum(counts.values())==783100
    forbidden={'centerSpeeds','centerSpeed','speed','proof','trials','events','spinX','spinY','direction'}
    def no_solutions(value):
        if isinstance(value,dict):
            assert not forbidden.intersection(value)
            for v in value.values():no_solutions(v)
        elif isinstance(value,list):
            for v in value:no_solutions(v)
    no_solutions(data)
    return dict(layouts=sum(counts.values()),combinationDefinitions=len(table),
                middleIDsMatchedToOriginalRecords=middle_count,example=example,
                geometryAndMasksUnchanged=True,noSolutions=True)


def main():
    OUT.mkdir(exist_ok=True)
    original=json.loads(SOURCE.read_text());inventory=json.loads(INVENTORY.read_text())
    assert original['schema']=='layout-bank-grid-v1'
    assert original['inventorySHA256']==sha(INVENTORY)
    data=json.loads(SOURCE.read_text())
    data['schema']='layout-bank-grid-v2-combination-ids'
    data['sourceLayoutBankSHA256']=sha(SOURCE)
    data['combinationTable']=[dict(id=geometry.cell_id(c['cell']), **c['cell']) for c in inventory['cells']]
    # Ensure the numeric reference formula matches the persisted definition order.
    for index,c in enumerate(data['combinationTable']):
        assert index==(((c['angleIndex']*2+c['pocketType'])*3+c['cueIndex'])*3+c['objectIndex'])*3+c['railIndex']
    data['combinationEncoding']=dict(field='combinationIndices',reference='zero-based index into combinationTable',
        order='Ascending masks array index, then ascending set distance bit; one combination index per valid layout',
        classificationVersion='v3-native-CO-OP-rail-contact-roundoff',
        angleLabels=geometry.ANGLES,pocketLabels=geometry.POCKETS,distanceLabels=geometry.DISTANCES,railLabels=geometry.RAILS,
        distanceMeaning=dict(cue='CO: cue center to object center',object='OP: object center to generation anchor'),
        distanceBandUpperMetres=[.6,1.2,1.8],distanceBoundaryToleranceMetres=1e-6,
        railContactRoundoffMetres=geometry.EPSILON,nearRailMaximumGapMetres=.1)
    for t in data['targets']:t['combinationIndices']=classify_vectorized(t,data)
    path=OUT/'grid-layouts-with-combinations.json'
    raw=json.dumps(data,ensure_ascii=False,separators=(',',':')).encode()
    path.write_bytes(raw)
    compressed=gzip.compress(raw,compresslevel=9,mtime=0)
    gz=OUT/(path.name+'.gz');gz.write_bytes(compressed)
    assert gzip.decompress(gz.read_bytes())==path.read_bytes()
    checked=audit(json.loads(path.read_text()),original,inventory)
    report=dict(**checked,jsonBytes=len(raw),gzipBytes=len(compressed),
                previousJsonBytes=SOURCE.stat().st_size,
                previousGzipBytes=Path(str(SOURCE)+'.gz').stat().st_size,
                jsonSHA256=sha(path),gzipSHA256=sha(gz),sourceSHA256=sha(SOURCE),appBundleChanged=False)
    report['jsonIncreaseBytes']=report['jsonBytes']-report['previousJsonBytes']
    report['gzipIncreaseBytes']=report['gzipBytes']-report['previousGzipBytes']
    (OUT/'combination-id-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    BACKUP.mkdir(parents=True,exist_ok=True)
    checks={}
    for p in [path,gz,OUT/'combination-id-report.json',Path(__file__)]:
        dst=BACKUP/p.name
        if dst.exists():assert sha(dst)==sha(p), 'Never replace a different backup'
        else:dst.write_bytes(p.read_bytes())
        assert sha(dst)==sha(p);checks[p.name]=sha(p)
    (BACKUP/'SHA256SUMS.txt').write_text(''.join(f'{h}  {p}\n' for p,h in checks.items()))
    print(json.dumps(report,ensure_ascii=False,indent=2))


if __name__=='__main__':main()
