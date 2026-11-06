"""Independent structural replay of the two-ball reference rewrite, including free placement."""
import gzip,hashlib,json,shutil,sys,tempfile
from pathlib import Path

def layouts(root,shard):
    raw=(root/(shard['name']+'.jsonl.gz')).read_bytes()
    assert len(raw)==shard['bytes'] and hashlib.sha256(raw).hexdigest()==shard['sha256']
    return list(map(json.loads,gzip.decompress(raw).splitlines()))

def verify(work):
    old=work/'Runner.app/TwoBallBank'; new=work/'staged/TwoBallBank'
    original=json.loads((old/'index.json').read_bytes())
    candidate=json.loads((new/'index.json').read_bytes())
    assert candidate['layouts']==original['layouts']
    counts=dict(layouts=0,questions=0,recommendations=0,routes=0)
    changed=set()
    changes={}
    masks_checked=0
    extra=work/'two-extra-efforts.json'
    efforts=json.loads(extra.read_bytes()) if extra.exists() else {}
    layout_index={entry["id"]:i for i,entry in enumerate(original["layouts"])}
    for src,dst in zip(original['shards'],candidate['shards'],strict=True):
        for a,b in zip(layouts(old,src),layouts(new,dst),strict=True):
            assert a['id']==b['id'] and a['board']==b['board']
            assert b['routes'][:len(a['routes'])] == a['routes']
            by_cell={q['id']:q['trajectoryRefs'] for q in b['questions'] if 'trajectoryRefs' in q}
            settings={q['id']:q['trajectoryRefsByAxes'] for q in b['questions'] if 'trajectoryRefsByAxes' in q}
            position=layout_index[a['id']]
            ledger=work/'rows'/f'two-{position}.json'
            proofs={row['key']:row for row in json.loads(ledger.read_bytes())}
            options=work/'settings'/f'settings-{position}.json'
            options=json.loads(options.read_bytes()) if options.exists() else {}
            if by_cell or settings:
                delta=dict(routes=b['routes'][len(a['routes']):],questions=by_cell)
                if settings:delta['settings']=settings
                changes.setdefault(src['name'],{})[a['id']]=delta
            new_lookup={r['id']:r for r in b['routes']}
            assert len(new_lookup)==len(b['routes'])
            for r in a['routes']:assert r==new_lookup[r['id']]
            counts['layouts']+=1;counts['routes']+=len(new_lookup)
            used=set()
            for old_q,new_q in zip(a['questions'],b['questions'],strict=True):
                assert {k:v for k,v in new_q.items() if k not in ('trajectoryRefs','trajectoryRefsByAxes')}==old_q
                source=old_q['refs']
                prefix=f"{a['id']}#{old_q['id']}/"
                default=new_q.get('trajectoryRefs',source)
                overrides=new_q.get('trajectoryRefsByAxes',{})
                assert set(overrides)<=set('123')
                states=[proofs[prefix+str(i)] for i,_ in source]
                alternatives=[options.get('choices',{}).get(row['key'],[]) if row['state']=='searchReview' else [] for row in states]
                standard=any(row['state']=='adjusted' for row in states)
                assert ('trajectoryRefs' in new_q)==standard
                counts['questions']+=1;counts['recommendations']+=len(source)
                if not standard and not any(alternatives):
                    assert not overrides
                    continue
                for mask in range(4):
                    actual=overrides.get(str(mask),default)
                    assert len(actual)==len(source)==len({i for i,_ in actual})
                    expected=[]
                    sortable=[]
                    requires_override=False
                    source_admitted=0
                    for slot,((i,pocket),row,choices) in enumerate(zip(source,states,alternatives)):
                        r=new_lookup[i]
                        source_axes=int(r['sy']!=0)+2*int(r['sx']!=0)
                        source_admitted+=int((source_axes & ~mask)==0)
                        allowed=[]
                        for option in choices:
                            n=option['input']
                            axes=int(n['spinY']!=0)+2*int(n['spinX']!=0)
                            assert source_axes & ~axes==0
                            if (axes & ~mask)==0:
                                allowed.append((option['rms'],option['effort'],axes,option))
                        witness=row if row['state']=='adjusted' else None
                        if allowed:
                            requires_override=True
                            witness=min(allowed,key=lambda x:x[:3])[-1]
                        direction=r['dir']
                        v,sx,sy=r['v'],r['sx'],r['sy']
                        if witness is not None:
                            n=witness['input']
                            v,sx,sy=n['velocity'],n['spinX'],n['spinY']
                            direction=witness['dir']
                            assert witness['key']==row['key'] and witness['hits']>0 and 0<=witness['rms']<=0.5
                            assert r['rails'] or sx==0
                        sig=(v,sx,sy,tuple(direction),tuple(r['rails']),pocket)
                        expected.append(sig)
                        if (standard or requires_override or str(mask) in overrides) and row['state'] not in ('filtered','baselineFailure'):
                            key=row['key']
                            e=witness['effort'] if witness else row.get('effort',efforts.get(key,options.get('originalEfforts',{}).get(key)))
                            assert e is not None,key
                            sortable.append((e,slot,sig))
                    assert requires_override==(str(mask) in overrides)
                    for (_,slot,_),(_,_,sig) in zip(sortable,sorted(sortable,key=lambda x:x[0])):
                        expected[slot]=sig
                    observed=[]
                    admitted=0
                    for i,pocket in actual:
                        r=new_lookup[i]
                        observed.append((r['v'],r['sx'],r['sy'],tuple(r['dir']),tuple(r['rails']),pocket))
                        admitted+=int((r['sy']==0 or mask & 1!=0) and (r['sx']==0 or mask & 2!=0))
                        if [i,pocket] not in source:
                            used.add(i)
                            changed.add(prefix+str(i))
                    assert expected==observed,(prefix,mask)
                    assert admitted==source_admitted,(prefix,mask)
                    masks_checked+=1
            assert used=={r['id'] for r in b['routes'][len(a['routes']):]}
    assert counts==candidate['counts']
    assert changed==set(json.loads((work/'two-changed.json').read_bytes()))
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'two-ball-consumer'))
    from jaw_revision import encode,apply_revision
    delta=dict(sourceFingerprint=original['fingerprint'],finalFingerprint=candidate['fingerprint'],
               changedReferences=len(changed),shards=changes)
    patch=work/'two-adjustment-overlay.json.gz'
    patch.write_bytes(gzip.compress(encode(delta),mtime=0))
    with tempfile.TemporaryDirectory(dir=work) as scratch:
        projection=Path(scratch)/'TwoBallBank'
        shutil.copytree(old,projection)
        apply_revision(projection,patch)
        assert (projection/'index.json').read_bytes()==(new/'index.json').read_bytes()
    (work/'two-package-audit.json').write_text(json.dumps(dict(counts=counts,verifiedChanges=len(changed),affectedCellSettingsChecked=masks_checked,originalFreeReferences=counts['recommendations']),indent=2))
if __name__=='__main__':verify(Path(sys.argv[1]))
