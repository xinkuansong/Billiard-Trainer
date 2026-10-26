#!/usr/bin/env python3
"""Export audited full break banks to the app's coordinate-only consumer format."""
import argparse, gzip, hashlib, importlib.util, json, pathlib, tempfile, os
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('multi_ball_admission', ROOT/'research/multi-ball-full-20261026/bank.py')
bank = importlib.util.module_from_spec(spec); spec.loader.exec_module(bank)
def read(path): return json.loads(path.read_text())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser(); parser.add_argument('source',type=pathlib.Path)
    parser.add_argument('--pilot',action='store_true'); args=parser.parse_args()
    source=args.source.resolve(); summary=read(source/'summary.json'); audit=read(source/'audit.json')
    assert summary['complete'] and summary['auditPassed'] and audit['passed']
    assert summary['threshold']==bank.THRESHOLD
    if not args.pilot: assert summary['formalBank'] and summary['count']==50000
    assert not summary['currentProductionDrift'], 'Review production physics drift before exporting'
    calibration=read(source/'calibration.json'); seen=set(); output={}; sources={}
    for n in bank.KINDS:
        path=source/f'bank-{n:02}.json.gz'; receipt=audit['files'][path.name]
        assert sha(path)==receipt['sha256']
        value=json.loads(gzip.decompress(path.read_bytes()))
        assert value['schemaVersion']==1 and value['n']==n and value['threshold']==1.2
        assert value['metricVersion']==bank.VERSION and value['calibrationSHA256']==sha(source/'calibration.json')
        rows=value['boards']; assert len(rows)==receipt['count']==summary['kinds'][str(n)]['count']
        if not args.pilot: assert len(rows)==10000
        part=next(p for p in summary['parts'] if p['n']==n)
        meta=read(source/part['folder']/'metadata.json')
        for row in rows:
            bank.verify_base(row,meta,calibration)
            assert row['id'] not in seen; seen.add(row['id'])
            assert set(row['boardNormalized'])=={'_'+str(k) for k in bank.numbers(n)}
        consumer={'version':1,'count':n,'threshold':1.2,'boards':[{'id':r['id'],'balls':r['boardNormalized']} for r in rows]}
        # Exact JSON numeric round trip: no coordinate quantization or further selection.
        raw=json.dumps(consumer,separators=(',',':')).encode()
        assert json.loads(raw)==consumer
        output[f'bank-{n}.json']=raw
        sources[path.name]={'sha256':sha(path),'count':len(rows),'bytes':len(raw),'consumerSHA256':hashlib.sha256(raw).hexdigest()}
    manifest={'version':1,'formalBank':not args.pilot,'total':len(seen),'metric':bank.VERSION,'threshold':1.2,
              'source':str(source.relative_to(ROOT)),'summarySHA256':sha(source/'summary.json'),
              'auditSHA256':sha(source/'audit.json'),'calibrationSHA256':sha(source/'calibration.json'),
              'coordinates':'Canvas u=(X+L/2)/L, v=(Z+W/2)/L; metres XZ, Y up','files':sources}
    output['manifest.json']=json.dumps(manifest,ensure_ascii=False,indent=2).encode()
    target=ROOT/'QiuJi/Resources/MultiBallBank'; target.mkdir(exist_ok=True)
    for name,raw in output.items():
        with tempfile.NamedTemporaryFile(dir=target,delete=False) as f: f.write(raw); temp=f.name
        os.replace(temp,target/name)
    print(json.dumps(manifest,ensure_ascii=False,indent=2))
if __name__=='__main__': main()
