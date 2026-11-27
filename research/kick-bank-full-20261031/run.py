"""Complete finite kick-bank sweep; bounded per-cell memory and resumable evidence."""
from pathlib import Path
import collections, gzip, hashlib, importlib.util, json, os, subprocess, sys, time
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/kick-bank-full-20261031'
SOURCE=ROOT/'output/kick-grid-sample-20261030'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def main():
    if len(sys.argv)==1:
        spec=importlib.util.spec_from_file_location('builder',ROOT/'research/k-ball-placement-20261029/build.py')
        builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
        builder.HERE=HERE;builder.OUT=OUT
        app=builder.build()
        subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone',
            '--task','kick-bank-full-20261031','--',sys.executable,__file__,'worker','{udid}',str(app/'Worker')],check=True)
        return
    _,uid,worker=sys.argv[1:]
    run=lambda *args: subprocess.run(['xcrun','simctl','spawn',uid,worker,*map(str,args)],check=True)
    subprocess.run(['xcrun','simctl','boot',uid],check=True)
    started=time.time()
    try:
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
        run('geometry',OUT/'geometry.json')
        assert json.loads((OUT/'geometry.json').read_text())==json.loads((SOURCE/'geometry.json').read_text())
        binding={name:{'path':str(SOURCE/name),'sha256':sha(SOURCE/name)} for name in ['seeds.json','sampling.json']}
        dump(OUT/'input-binding.json',binding)
        (OUT/'sampling.json').write_bytes((SOURCE/'sampling.json').read_bytes())
        run('selftest',OUT/'native-selftest.json')
        run('verify',ROOT/'output/kick-grid-filtered-20261030/accepted.json',OUT/'sample-regression.json')
        seeds=json.loads((SOURCE/'seeds.json').read_text())
        assert len(seeds)==103680 and len({s['id'] for s in seeds})==103680
        cells=collections.defaultdict(list)
        for s in seeds:cells[s['cell']].append(s)
        assert set(cells)==set(range(72)) and all(len(s)==1440 for s in cells.values())
        identity={'executable':sha(Path(worker)),'input':binding,'entry':sha(HERE/'main.swift')}
        receipts=[]
        for cell in range(72):
            folder=OUT/'cells'/f'{cell:02d}';folder.mkdir(parents=True,exist_ok=True)
            receipt=folder/'receipt.json'
            if receipt.exists():
                prior=json.loads(receipt.read_text())
                assert prior['identity']==identity and all(sha(folder/name)==digest for name,digest in prior['files'].items())
                receipts.append(prior);continue
            seedfile=Path(os.environ['QIUJI_TEST_WORK'])/f'seeds-{cell:02d}.json'
            dump(seedfile,cells[cell])
            run('generate',seedfile,folder)
            run('verify',folder/'accepted.json',folder/'verification.json')
            summary=json.loads((folder/'generation-summary.json').read_text())
            assert summary['processedSeeds']==1440 and summary['fullScan']
            rows=json.loads((folder/'accepted.json').read_text())
            assert len({(r['seed']['id'],r['n']) for r in rows})==len(rows)
            for name in ['accepted.json','baselines.json','trials.json','contrasts.json','rejected-routes.json','verification.json']:
                source=folder/name; raw=source.read_bytes(); target=folder/(name+'.gz')
                target.write_bytes(gzip.compress(raw,mtime=0))
                assert gzip.decompress(target.read_bytes())==raw
                source.unlink()
            result={'cell':cell,'identity':identity,'summary':summary,
                    'files':{p.name:sha(p) for p in folder.iterdir() if p.is_file() and p.name!='receipt.json'}}
            dump(receipt,result);receipts.append(result)
            dump(OUT/'progress.json',{'completedCells':len(receipts),'totalCells':72,'processedSeeds':1440*len(receipts),
                'accepted':sum(r['summary']['accepted'] for r in receipts),'seconds':time.time()-started})
            print('CELL COMPLETE',cell+1,'/72',json.loads((OUT/'progress.json').read_text()),flush=True)
        dump(OUT/'generation-complete.json',{'processedSeeds':sum(r['summary']['processedSeeds'] for r in receipts),
             'accepted':sum(r['summary']['accepted'] for r in receipts),'cells':72,'seconds':time.time()-started})
    finally:
        subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if __name__=='__main__':main()
