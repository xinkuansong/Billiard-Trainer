"""Merge only previously open positive-window rows, preserving the first-pass evidence."""
from pathlib import Path
import argparse,gzip,json,os,shutil
from pack import encode,sha,stage

def merge(work,family):
    out=work/'refined'; target=out/'rows'
    target.mkdir(parents=True,exist_ok=True)
    for name in ('Runner.app','compat-build'):
        link=out/('host-build' if name=='compat-build' else name)
        if not link.exists():link.symlink_to(work/name)
    extra={r['key']:r for r in json.loads((work/(family+'-refined.json')).read_bytes())}
    changes={}
    for path in (work/'rows').glob(family+'-*.json'):
        rows=json.loads(path.read_bytes())
        for row in rows:
            if row['key'] in extra:
                assert row['state']=='searchReview'
                update=extra.pop(row['key'])
                if update['state']=='adjusted':row.update(update)
            if row['state']=='adjusted':
                changes[row['key']]=dict(input=row['input'],direction=dict(zip(('x','z'),row['dir'])))
        (target/path.name).write_bytes(encode(rows))
    assert not extra
    stage(out,family)
    resource='bank-practice-bank.json' if family=='bank' else 'KBallBank/index.json'
    previous=(work/'staged'/resource).read_bytes()
    live=Path(__file__).resolve().parents[2]/'QiuJi/Resources'/resource
    assert live.read_bytes()==previous
    delta=dict(source=sha((work/'Runner.app'/resource).read_bytes()),
               result=sha((out/'staged'/resource).read_bytes()),changes=changes)
    (out/(family+'-overlay.json.gz')).write_bytes(gzip.compress(encode(delta),mtime=0))
    (out/(family+'-previous-stage.json')).write_bytes((work/(family+'-stage.json')).read_bytes())

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('work',type=Path)
    parser.add_argument('family',choices=['bank','kball'])
    a=parser.parse_args();merge(a.work.resolve(),a.family)
