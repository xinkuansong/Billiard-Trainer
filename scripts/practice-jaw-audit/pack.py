"""Assemble complete, keyed simulator results into candidate consumer resources."""
import argparse
import collections
import gzip
import hashlib
import json
import time
from pathlib import Path

def encode(value):
    return json.dumps(value,ensure_ascii=False,separators=(',',':'),allow_nan=False).encode()

def sha(data):
    return hashlib.sha256(data).hexdigest()

def replace_input(item,row):
    n=row['input']
    item.update(v=n['velocity'],sx=n['spinX'],sy=n['spinY'],dir=row['dir'])

def read_rows(work,kind):
    rows={}
    for path in (work/'rows').glob(kind+'-*.json'):
        for row in json.loads(path.read_bytes()):
            key=row['key']
            if key in rows:raise ValueError(f'duplicate result {key}')
            rows[key]=row
    return rows

def stage(work,kind):
    config_dir=work/'settings'
    use_settings=kind=='two' and (config_dir/'plan.json').exists()
    if use_settings:
        while not (config_dir/'complete.json').is_file():time.sleep(30)
    summary=dict(conditionalOriginals=0,alwaysAdjusted=0,byMask={str(m):0 for m in (1,2,3)})
    rows=read_rows(work,kind)
    initial=dict(collections.Counter(row['state'] for row in rows.values()))
    original=work/'Runner.app'
    dest=work/'staged'
    dest.mkdir(exist_ok=True)
    changed=[]
    if kind=='two':
        extra=work/'two-extra-efforts.json'
        efforts=json.loads(extra.read_bytes()) if extra.exists() else {}
    else:efforts={}
    if kind=='bank':
        filename='bank-practice-bank.json'
        bank=json.loads((original/filename).read_bytes())
        for item in bank['questions']:
            row=rows.pop(item['id'])
            if row['state']=='adjusted':
                item['input']=row['input']
                item['direction']=dict(zip(('x','z'),row['dir']))
                changed.append(item['id'])
        data=encode(bank)
        result={filename:sha(data)}
        (dest/filename).write_bytes(data)
    else:
        name={'kball':'KBallBank','two':'TwoBallBank'}[kind]
        source=original/name
        root=dest/name
        root.mkdir(exist_ok=True)
        index=json.loads((source/'index.json').read_bytes())
        old=index.pop('fingerprint')
        layout_indices={v['id']:i for i,v in enumerate(index['layouts'])}
        total_routes=0
        for shard in index['shards']:
            filename=shard['name']+'.jsonl.gz'
            data=(source/filename).read_bytes()
            if sha(data)!=shard['sha256']:raise ValueError('shard changed '+filename)
            layouts=list(map(json.loads,gzip.decompress(data).splitlines()))
            edited=False
            for layout in layouts:
                if kind=='kball':
                    for item in layout['questions']:
                        row=rows.pop(item['id'])
                        if row['state']=='adjusted':
                            replace_input(item,row)
                            changed.append(item['id']);edited=True
                else:
                    from two_variants import rewrite
                    settings={}
                    if use_settings:
                        pos=layout_indices[layout['id']]
                        settings=json.loads((config_dir/f'settings-{pos}.json').read_bytes())
                    edited=rewrite(layout,rows,efforts,settings,summary,changed) or edited
                    total_routes+=len(layout['routes'])
            if edited:
                data=gzip.compress(b''.join(encode(l)+b'\n' for l in layouts),mtime=0)
            shard['sha256']=sha(data);shard['bytes']=len(data)
            (root/filename).write_bytes(data)
        if kind=='two':index['counts']['routes']=total_routes
        index['jawRevision']={'sourceFingerprint':old,'changedReferences':len(changed),'version':1}
        index['fingerprint']=sha(encode(index))
        data=encode(index);(root/'index.json').write_bytes(data)
        result={name:sha(data)}
    if kind=='two':
        summary['replayVariants']=len(changed)
        assert len(set(changed))==len(changed)
        (work/'two-settings-summary.json').write_bytes(encode(summary))
    if rows:raise ValueError(f'unexpected {len(rows)} unconsumed keys')
    (work/(kind+'-changed.json')).write_bytes(encode(changed))
    (work/(kind+'-stage.json')).write_bytes(encode(dict(counts=initial,changed=len(changed),digests=result)))
    print(kind,initial,len(changed),result,flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('work',type=Path)
    parser.add_argument('family',choices=['bank','kball','two'])
    args=parser.parse_args()
    stage(args.work,args.family)
