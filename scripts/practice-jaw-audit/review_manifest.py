"""Export keyed open cases separately from clean or physically corrected references."""
from collections import Counter
import gzip
import json
from pathlib import Path
import sys

work=Path(sys.argv[1])
output=work/'review'
output.mkdir(exist_ok=True)
counts={}
ledgers={'bank':work/'refined/refined/rows','kball':work/'refined/rows',
         'two':work/'refined/rows','sep':work/'sep/rows'}
for family,ledger in ledgers.items():
    totals=Counter()
    files=sorted(ledger.glob(family+'-*.json'),key=lambda p:int(p.stem.split('-')[-1]))
    with gzip.open(output/(family+'.ndjson.gz'),'wt',encoding='utf-8') as stream:
        for path in files:
            settings={}
            if family=='two':
                group=path.stem.split('-')[-1]
                settings=json.loads((work/'refined/settings'/f'settings-{group}.json').read_bytes())['choices']
            for row in json.loads(path.read_bytes()):
                state=row.get('result',row.get('state'))
                if state in ('adjusted','clean'):continue
                if family=='sep':
                    item={k:row[k] for k in ('board','axes','seed')}
                    if 'jawCount' in row:item['targetJawHits']=row['jawCount']
                else:
                    item={'id':row['key']}
                    if 'hits' in row:item['targetJawHits']=row['hits']
                    if row.get('reason'):item['reason']=row['reason']
                    if state=='searchReview' and row['key'] in settings:
                        state='partiallyAdjustedBySetting'
                        masks=set()
                        for option in settings[row['key']]:
                            n=option['input']
                            axes=int(n['spinY']!=0)+2*int(n['spinX']!=0)
                            masks.update(mask for mask in range(4) if axes & ~mask==0)
                        item['cleanInMasks']=sorted(masks)
                item['state']=state
                totals[state]+=1
                stream.write(json.dumps(item,separators=(',',':'))+'\n')
    counts[family]=dict(totals)
(output/'counts.json').write_text(json.dumps(counts,indent=2)+'\n')
print(counts)
