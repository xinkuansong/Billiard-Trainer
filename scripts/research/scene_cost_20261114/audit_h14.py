#!/usr/bin/env python3
"""Audit frozen inputs and all native H14 records; never select fastest samples."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
runs = ['ae6d211920e042adb6499dcf379b5c5c', '55862b0d598d48b98ee66458543c1474',
        'fd6af33e62414eac8819cdadb3c046fb', '0c5bc995f5b64368ba5e2c4eb5701b71']
reports = []
baseline = None
for number, ident in enumerate(runs, 1):
    directory = root/'output/local-test-runs'/ident
    evidence = directory/'evidence'
    state = json.loads((directory/'run.json').read_text())
    assert state['state']=='reclaimed' and state['exit_code']==0
    summary = json.loads((evidence/'test-summary.json').read_text())
    assert (summary['totalTestCount'],summary['passedTests'],summary['failedTests'],summary['skippedTests'])==(1,1,0,0)
    manifest = json.loads((evidence/'snapshot-manifest.json').read_text())['files']
    production = {k:v['sha256'] for k,v in manifest.items() if k.startswith('QiuJi/')}
    if baseline is None: baseline=production
    assert production==baseline, 'Production inputs changed between runs'
    found=[]
    for path in (evidence/'attachments').glob('*.json'):
        value=json.loads(path.read_text())
        if isinstance(value,dict) and value.get('study','').startswith('H14-'): found.append((path,value))
    assert len(found)==1
    path,report=found[0]
    assert report['completed'] is True
    frames=0; rejected=[]
    for row in report['rows']:
        assert row['aaMaximum']==row['restoreMaximum']==0
        if not row['qualityPassed']:
            assert not row['times'];rejected.append([row['pose'],row['group'],row['maximumChannelDifference']]);continue
        assert len(row['times'])==48
        for kind in ['AA','AB']:
            for cycle in range(6):
                for arm in ['A','B']:
                    values=[f for slot in row['times'] if slot['kind']==kind and slot['cycle']==cycle and slot['arm']==arm
                            for f in slot['frames']]
                    assert len(values)==24
                    for f in values:
                        assert f['gpuStartTime']>0 and f['gpuSpanMS']>0
                        assert abs((f['gpuEndTime']-f['gpuStartTime'])*1000-f['gpuSpanMS'])<1e-8
                        assert f['cpuWallMS']>=f['cpuEncodeMS']>=0
                    frames+=len(values)
    for inventory in report['inventory']:
        assert inventory['clothSHA256']=='14a880284fffc793f01d0357b0a625559101609d7986c9ac0cac72e7085efa4f'
        if number>=3:
            for group in ['wood','legs','cloth']:
                assert all(m['doubleSided'] for m in inventory['materialRasterState'][group])
    assert all(r['usesTwoViewPoseControl'] for r in report['cpuRows'] if 'usesTwoViewPoseControl' in r)
    reports.append({'round':number,'run':ident,'study':report['study'],'device':report['device'],
        'rawReport':str(path.relative_to(root)), 'timedFrames':frames,'qualityRejected':rejected,
        'testCount':1,'workReclaimed':True,'actualFreeSpaceDeltaBytes':state.get('free_space_delta')})
for path,digest in baseline.items():
    assert hashlib.sha256((root/path).read_bytes()).hexdigest()==digest, 'Live production drift: '+path
last=root/'output/local-test-runs'/runs[-1]/'evidence/frozen-source/QiuJiTests/ClothSupportPerformanceResearchTests.swift'
assert last.read_bytes()==(root/'QiuJiTests/ClothSupportPerformanceResearchTests.swift').read_bytes()
result={'passed':True,'unchangedCurrentProductionInputs':len(baseline),'lastResearchSourceMatchesBuild':True,
        'actualNativeSelectorsPassed':len(reports),'totalPairedTimedFrames':sum(r['timedFrames'] for r in reports),
        'allAAAndRestoreImagesExact':True,'runs':reports}
(root/'tasks/render-highlight-20261114/H14-CHECKS.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='runs'},indent=2))
