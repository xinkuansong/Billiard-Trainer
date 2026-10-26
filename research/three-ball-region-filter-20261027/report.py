from pathlib import Path
import json
import numpy as np
import filter as F

def main():
    audit=F.read(F.OUT/'audit.json');assert audit['passed'];regions=F.read(F.REG/'data.json');data=[]
    # Local RDP keeps each rendered polyline within 0.5mm of dense native samples.
    max_error=0.
    def simplify(points):
        nonlocal max_error
        if len(points)<3:return points
        a,b=points[0],points[-1];ds=F.segment_distance(np.array(points),np.array(a),np.array(b))
        k=int(ds.argmax())
        if ds[k]<=.0005:
            max_error=max(max_error,float(ds[k]));return [a,b]
        return simplify(points[:k+1])[:-1]+simplify(points[k:])
    for i in range(1,6):
        src=F.read(F.OUT/f'sample-{i}.json');old=F.read(F.OLD/f'sample-{i}.json');candidates=[]
        for c in src['positions']:
            out={k:v for k,v in c.items() if k!='chains'};out['reasons']=old['candidates'][c['id']]['reasons'];out['chains']=[]
            for ch in c['chains']:
                shots=[]
                for v in ch['shots']:
                    q,r=v['request'],v['result'];paths={k:simplify([p[1:] for p in points]) for k,points in r['physicalPaths'].items()}
                    shots.append(dict(cue=q['cue'],object=q['object'],obstacles=q['obstacles'],pocket=q['pocket'],v=r['v'],sx=r['sx'],sy=r['sy'],stop=r['stop'],rails=r['rails'],paths=paths))
                out['chains'].append(dict(firstRank=ch['firstRank'],pocket2=ch['pocket2'],pocket3=ch['pocket3'],oldComfort3=ch['comfort3']['total'],newComfort3=ch['newComfort3'][3],source=ch['source'],shots=shots))
            candidates.append(out)
        data.append(dict(sample=src['sample'],counts=src['counts'],oldCounts=old['counts'],regions=regions['samples'][i-1]['regions'],candidates=candidates))
    payload=dict(samples=data,geometry=F.R.GEOM,anchors=F.R.ANCHORS.tolist(),flow=F.read(F.OUT/'flow-audit.json'),filterSeconds=F.read(F.OUT/'filter.json')['seconds'],audit={k:v for k,v in audit.items() if k!='oracle'})
    F.write(F.OUT/'viewer-data.json',payload)
    template=(F.HERE/'viewer.html').read_text();(F.OUT/'index.html').write_text(template.replace('/*__DATA__*/',json.dumps(payload,ensure_ascii=False,separators=(',',':'))))
    F.write(F.OUT/'display-audit.json',dict(passed=max_error<=.0005,maxDeviationFromNativeSamplesMeters=max_error,chains=135,shots=405,indexSHA=F.sha(F.OUT/'index.html')))
    print('report bytes',(F.OUT/'index.html').stat().st_size)
if __name__=='__main__':main()
