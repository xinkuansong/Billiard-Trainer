from pathlib import Path
import json,gzip,hashlib,collections,copy,sys
import audit
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/bank-variants-20261101';BASE=ROOT/'output/bank-full-20261101'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(name,value):(OUT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2))
g=json.loads((OUT/'geometry.json').read_text());tree={r['id']:r for r in json.loads((OUT/'route-tree.json').read_text())};binding=json.loads((OUT/'identity.json').read_text())
assert sha(BASE/'formations.jsonl.gz')==binding['baseSHA256']
audit.ns['tree_audit'](tree,g)
sources=json.loads((OUT/'source-binding.json').read_text())
drift=[v['path'] for v in sources['sources'] if v['currentProduction'] and sha(ROOT/v['path'])!=v['sha256']]
assert not drift,drift
assert sha(Path(__file__).parent/'main.swift')==sources['entrySHA256']
with gzip.open(BASE/'formations.jsonl.gz','rt') as f:bases={r['id']:r for r in map(json.loads,f)}
seen=set();ids=[];duplicates=[];counts=collections.Counter();kindCounts=collections.Counter();kindBreakdown=collections.Counter();failed=collections.Counter();pertFailures=collections.Counter();decisions=[];sample=[];sampleGroups=collections.Counter();sampleDistances=collections.defaultdict(set);negatives=[];nativeCount=0;original0=0;pertCanonical=0;expectedOriginal=0
export=OUT/'formations.jsonl.gz';tmp=OUT/'formations.jsonl.tmp'
with gzip.open(tmp,'wt',encoding='utf8',compresslevel=6) as destination:
 for i in range((len(bases)+15)//16):
  p=OUT/'batches'/f'{i:03d}.json.gz';receipt=json.loads((OUT/'batches'/f'{i:03d}.receipt.json').read_text())
  assert receipt['sha256']==sha(p) and receipt['identity']==binding and receipt['verified']
  with gzip.open(p,'rt') as f:packet=json.load(f)
  rows=packet['rows'];ds=packet['decisions'];v=packet['verification'];audit.audit_rows(rows,g,v,tree,bases,ds);assert len(rows)==receipt['rows']
  nativeCount+=len(rows);decisions.extend(ds)
  if rows and not negatives:
   for name in ['wrong-count','wrong-pocket','fake-score','missing-replay','missing-decision']:
    bad=copy.deepcopy(rows);bv=copy.deepcopy(v);bd=copy.deepcopy(ds)
    if name=='wrong-count':bad[0]['n']=9
    elif name=='wrong-pocket':bad[0]['pocket']=(bad[0]['pocket']+1)%6
    elif name=='fake-score':bad[0]['bankComfort']['total']+=1
    elif name=='missing-replay':bv.pop()
    else:bd.pop()
    try:audit.audit_rows(bad,g,bv,tree,bases,bd)
    except (AssertionError,KeyError):negatives.append(name)
    else:raise AssertionError('negative accepted '+name)
  if 'perturbation-bound' not in negatives and any(r['variantKind']=='perturbation' for r in rows):
   for name in ['perturbation-bound','off-ray-target']:
    bad=copy.deepcopy(rows);r=next(r for r in bad if r['variantKind']=='perturbation')
    if name=='perturbation-bound':r['perturbation']['targetDeltaMeters']=.1
    else:r['canonicalTarget'][0]+=.05
    try:audit.audit_rows(bad,g,v,tree,bases,ds)
    except AssertionError:negatives.append(name)
    else:raise AssertionError('negative accepted '+name)
  byid={r['id']:r for r in rows}
  for d in ds:
   b=bases[d['baseID']];expectedOriginal+=2 if b['type']=='middle' else 4
   if d['canonicalPerturbationID']:pertCanonical+=1
   for a in d['perturbationAttempts']:
    if 'rejected' in a:pertFailures[a['rejected']]+=1
   for o in d['outcomes']:
    if 'rejected' in o:failed[o['kind']+':'+o['rejected']]+=1
   # Two triplets per group: original, its position variant, the reflected variant.
   group=(b['n'],b['type']);pid=d['canonicalPerturbationID']
   wanted=[b['id']+'-S0',str(pid)+'-S0',str(pid)+'-S2']
   if pid and all(x in byid for x in wanted) and sampleGroups[group]<2 and b['distanceBand'] not in sampleDistances[group]:
    sampleGroups[group]+=1;sampleDistances[group].add(b['distanceBand'])
    for x in wanted:sample.append(byid[x])
  for r in rows:
   key=(tuple(r['cue']),tuple(r['target']),r['pocket'],tuple(r['walls']))
   if key in seen:duplicates.append(r['id']);continue
   seen.add(key);ids.append(r['id']);counts[f"{r['n']}-{r['type']}"]+=1;kindCounts[r['variantKind']]+=1;kindBreakdown[f"{r['n']}-{r['type']}-{r['variantKind']}"]+=1
   if r['variantKind']=='original' and r['transform']==0:original0+=1
   destination.write(json.dumps(r,separators=(',',':'))+'\n')
assert len(decisions)==len(bases)==3993 and len({d['baseID'] for d in decisions})==3993
assert original0==3993 and expectedOriginal==12972 and len(ids)==len(set(ids))
assert len(sample)==36 and all(v==2 for v in sampleGroups.values())
tmp.replace(export)
manifest={'state':'complete','workers':8,'bases':len(bases),'selected':len(ids),'counts':dict(counts),'kindCounts':dict(kindCounts),'kindBreakdown':dict(kindBreakdown),'selectedBeforeDedup':nativeCount,'duplicateIDs':duplicates,'retainedIDs':ids,'dedup':'exact actual coordinates + pocket + rail sequence; mirrored orientations retained','originalMirrorCandidates':expectedOriginal,'perturbationAttempts':2*len(bases),'canonicalPerturbations':pertCanonical,'perturbationRejections':dict(pertFailures),'mirrorRejections':dict(failed),'physicalReplays':2*nativeCount,'independentAudit':True,'negativeCasesRejected':negatives,'identity':binding,'lowerCushionAlternativesChecked':False,'positionVariantsChecked':True,'strikeToleranceChecked':False}
write('harness-binding.json',{str(p.relative_to(ROOT)):sha(p) for p in sorted(Path(__file__).parent.glob('*')) if p.is_file()});write('manifest.json',manifest);write('review-sample.json',sample);write('export.json',{'file':export.name,'rows':len(ids),'sha256':sha(export),'bytes':export.stat().st_size})
with gzip.open(OUT/'decisions.json.gz','wt') as f:json.dump(decisions,f,separators=(',',':'))
s=json.loads((OUT/'status.json').read_text());s.update(state='complete',selected=len(ids),auditPassed=True);write('status.json',s)
print('COMPLETE',json.dumps({k:v for k,v in manifest.items() if k not in ['retainedIDs','identity','duplicateIDs']},ensure_ascii=False))
