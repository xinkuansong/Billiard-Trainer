"""Fingerprint captured shader inputs; preserve exact and light-order-only differences."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re

def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()

def analyze(root):
    events=[json.loads(s) for s in (root/'shader-capture/requests.jsonl').read_text().splitlines()]
    libraries=[]
    for event in events:
        if event['event']!='library':continue
        source=(root/'shader-capture'/(event['sourceSHA256']+'.metal')).read_text()
        assert digest(source)==event['sourceSHA256']
        calls=re.findall(r'^.*_lightingContribution\.add_.*$',source,re.M)
        order=re.findall(r'_lightingContribution\.add_(\w+)\(scn_lights\[(\d+)\]', '\n'.join(calls))
        normalized=re.sub(r'u_shadowTexture\d+','u_shadowTexture_INDEX',source)
        normalized=re.sub(r'^.*_lightingContribution\.add_.*$','',normalized,flags=re.M)
        macros={}
        for line in (event.get('macros') or '').splitlines():
            match=re.fullmatch(r'\s*(?:"([^"]+)"|([^ =]+)) = (.*);',line)
            if match:macros[match[1] or match[2]]=match[3]
            elif line.strip() not in ['{','}']:raise ValueError('Unparsed macro: '+line)
        description=event.get('options') or ''
        options_tail=description[description.index('    mathMode ='):] if '    mathMode =' in description else description
        options={'macros':macros,'otherOptionsDescription':options_tail}
        key=digest(json.dumps({'source':event['sourceSHA256'],'options':options},sort_keys=True))
        label='generic PBR/other'
        if 'clothFiber' in source and 'QiuJiContactUniforms' in source:label='TaiNi cloth/contact AO'
        elif 'pocketVolume.sample' in source:label='White/pocket volume AO'
        elif '_output.color *= cueFadeOpacity' in source:label='cue fade'
        libraries.append({**event,'inputFingerprint':key,'optionsNormalized':options,
                          'lightOrder':order,'lightOrderNormalizedSHA':digest(normalized),'family':label})
    compilers=[e for e in events if e['event']=='compiler_request']
    grouped=collections.defaultdict(list)
    for l in libraries:grouped[l['lightOrderNormalizedSHA']].append(l)
    groups=[]
    for key, values in grouped.items():
        groups.append({'normalizedSHA':key,'family':values[0]['family'],
            'exactSourceVariants':sorted({v['sourceSHA256'] for v in values}),
            'inputVariants':sorted({v['inputFingerprint'] for v in values}),
            'lightOrders':sorted({tuple(x[0] for x in v['lightOrder']) for v in values}),
            'markers':[v.get('marker') for v in values]})
    report={'counts':dict(collections.Counter(e['event'] for e in events)),
        'libraries':libraries,'compilerCallbacks':compilers,'groups':groups,
        'limits':'Fingerprints are explicit source+observed-option identities, not a claimed private Metal cache key. Callback counts include scheduler overloads. Normalization removes only observed light contribution lines/shadow indices; it is for grouping, not shader equivalence or execution.'}
    (root/'shader-analysis.json').write_text(json.dumps(report,indent=2))
    print(root.parent.name,report['counts'],'sourceVariants',len({e['sourceSHA256'] for e in libraries}),
          'overlayLibraryCalls',sum(bool(e.get('marker')) for e in libraries))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('evidence',type=Path,nargs='+');a=p.parse_args()
    for root in a.evidence:analyze(root)
