"""Associate actual SceneKit dictionary visits, global list, shaders and compiler requests."""
import json
from pathlib import Path
import re
import sys

def analyze(evidence):
    capture=evidence/'shader-capture'
    events=[json.loads(s) for s in (capture/'requests.jsonl').read_text().splitlines()]
    sessions=[]
    for f in (evidence/'samples').glob('*.json'):
        sample=json.loads(f.read_text())
        begin=next(x for x in sample if x['event']=='begin')
        end=next(x for x in sample if x['event']=='close')
        sessions.append((begin['activation'],begin['wallUnix'],begin['wallUnix']+end['ms']/1000))
    types={0:'ambient',1:'directional',3:'spot',6:'area_rectangle'}
    results=[]
    for activation,start,end in sorted(sessions):
        window=[e for e in events if start<=e['wall']<=end]
        adds=[e for e in window if e['event']=='light_add']
        systems=set(e['system'] for e in adds)
        globals=[e for e in window if e['event']=='global_light_list' and e['system'] in systems]
        libraries=[e for e in window if e['event']=='library' and e.get('marker') and e['marker']['activation']==activation]
        comparisons=[]
        for g in globals:
            order=[types.get(x.get('lightTypeRaw'),str(x.get('lightTypeRaw'))) for x in g['rows']]
            nodes=[x['node'] for x in g['rows']]
            visits=[e['node'] for e in events if e['event']=='dictionary_light_visit' and e['system']==g['system'] and start<=e['wall']<g['wall']][-5:]
            filtered=[n for n in visits if n in nodes]
            matched=[]
            for lib in libraries:
                source=(capture/(lib['sourceSHA256']+'.metal')).read_text()
                observed=re.findall(r'_lightingContribution\.add_(\w+)\(scn_lights\[\d+\]',source)
                if observed==order:matched.append(lib['sourceSHA256'])
            comparisons.append({'system':g['system'],'order':order,'programHashes':[x['programHash'] for x in g['rows']],
                                'nodes':nodes,'dictionaryVisit':visits,'filteredVisitMatches':filtered==nodes,
                                'matchedLibrarySources':matched,'dictionaryReplay':g.get('dictionaryReplay')})
        compilers=[e for e in window if e['event']=='compiler_request' and any('MTLLibraryBuilder::newLibraryWithSource' in s for s in e['stack'])]
        results.append({'activation':activation,'copySourceOrder':[e['source'] for e in window if e['event']=='light_copy'],
                        'addedTypeOrder':[types[e['lightTypeRaw']] for e in adds],
                        'globals':comparisons,'libraryCalls':len(libraries),'sourceCompilerCallbacks':len(compilers),
                        'compiledSourceSHAs':sorted(set(e['lastSourceOnThread'] for e in compilers if e.get('lastSourceOnThread')))})
    result={'run':evidence.parent.name,'scope':'External debugger input evidence, not timing benchmark',
            'captureErrors':[e for e in events if e['event']=='capture_error'],
            'libraryCalls':sum(e['event']=='library' for e in events),
            'compilerCallbacks':sum(e['event']=='compiler_request' for e in events),'activations':results}
    (evidence/'light-dictionary-analysis.json').write_text(json.dumps(result,indent=2))
    for r in results:
        print(r['activation'],r['addedTypeOrder'],[(g['order'],g['filteredVisitMatches'],len(g['matchedLibrarySources'])) for g in r['globals']],r['libraryCalls'],len(r['compiledSourceSHAs']))
    return result

if __name__=='__main__':
    for arg in sys.argv[1:]:analyze(Path(arg))
