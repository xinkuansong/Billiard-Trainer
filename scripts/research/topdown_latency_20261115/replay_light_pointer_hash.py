"""Replay the observed five-node CFDictionary using the installed framework model.

Model source: exact arm64 Simulator CoreFoundation disassembly retained alongside
results. NULL hash callback keeps the pointer integer; 0x2001 selects linear
probing. Size/capacity tables begin [0,3,7,...]/[0,3,6,...]. This models only the
observed five sequential inserts, no removals or general dictionary API.
"""
import json
from pathlib import Path
import sys

def predict(keys):
    if len(keys)!=5 or len(set(keys))!=5:raise ValueError('Expected exactly five distinct pointer keys')
    table=[]
    def insert(key):
        index=key%len(table)
        while table[index] is not None:index=(index+1)%len(table)
        table[index]=key
    for count,key in enumerate(keys):
        if count in (0,3):
            old=table
            table=[None]*(3 if count==0 else 7)
            for previous in old:
                if previous is not None:insert(previous)
        insert(key)
    return [hex(key) for key in table if key is not None]

def analyze(evidence):
    events=[json.loads(s) for s in (evidence/'shader-capture/requests.jsonl').read_text().splitlines()]
    grouped={}
    for event in events:
        if event['event']=='light_add':grouped.setdefault(event['system'],[]).append(event)
    rows=[]
    batches=[]
    for system,all_adds in grouped.items():
        if len(all_adds)%5:raise ValueError('Incomplete registration group')
        for offset in range(0,len(all_adds),5):
            end=all_adds[offset+5]['wall'] if offset+5<len(all_adds) else float('inf')
            batches.append((system,all_adds[offset:offset+5],end))
    for system,adds,end in sorted(batches,key=lambda b:b[1][0]['wall']):
        start=adds[0]['wall']
        visits=[e['node'] for e in events if e['event']=='dictionary_light_visit' and e['system']==system and start<=e['wall']<end][-5:]
        if len(visits)!=5:continue
        keys=[int(e['node'],16) for e in adds]
        observed={'system':system,'input':[hex(k) for k in keys], 'predicted':predict(keys),'observed':visits}
        observed['matches']=observed['predicted']==visits
        g=next((e for e in events if e['event']=='global_light_list' and e['system']==system and start<=e['wall']<end and e.get('dictionaryReplay')),None)
        replays=[]
        if g:
            d=g['dictionaryReplay'];key_input=[int(k,16) for k in d['input']]
            outputs=d.get('sameInputRepeats',[d.get('forward')])
            for output in outputs:
                replays.append({'predicted':predict(key_input),'observed':output,'matches':predict(key_input)==output})
            replays.append({'predicted':predict(key_input[::-1]),'observed':d['reverse'],'matches':predict(key_input[::-1])==d['reverse']})
        observed['temporaryDictionaryReplays']=replays;rows.append(observed)
    result={'run':evidence.parent.name,'model':'NULL-callback pointer hash, linear probing, 3→7 bucket expansion at fourth insert',
            'rows':rows,'allMatch':all(r['matches'] and all(v['matches'] for v in r['temporaryDictionaryReplays']) for r in rows)}
    (evidence/'pointer-hash-replay.json').write_text(json.dumps(result,indent=2))
    print(evidence.parent.name,'actual',len(rows),'replay',sum(len(r['temporaryDictionaryReplays']) for r in rows),'allMatch',result['allMatch'])
    assert rows and result['allMatch']

if __name__=='__main__':
    for arg in sys.argv[1:]:analyze(Path(arg))
