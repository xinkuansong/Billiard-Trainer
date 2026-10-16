#!/usr/bin/env python3
"""Read-only evidence mapping and candidate validation; never writes learner content."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from tutorial_digest import aim_angle, aim_caption, digest


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def token(path):
    return path.stem.split('__', 1)[1].split('-', 1)[0]


def sections(data):
    t = data['tutorial']
    return [(f['id'], f['sections']) for f in t.get('formations', [])] or [('single', t.get('sections', []))]


def resolve_image(key, drill_id, sequences):
    match = re.fullmatch(re.escape(drill_id) + r'_(?:(.+)_)?(initial|s\d+|final)', key)
    if not match:
        raise ValueError(f'Unrecognized image identity: {key}')
    claim, frame = match.groups()
    chosen = sequences.get(claim) if claim else (next(iter(sequences.values())) if len(sequences) == 1 else sequences.get('manual01'))
    if chosen is None:
        raise ValueError(f'Ambiguous image mapping: {key}')
    return chosen, frame


def collect(root, path):
    d = json.loads(path.read_text()); id = d['id']
    sequences = {token(p): p for p in (root/'content/position_play/sequences').glob(id+'__*.json')}
    if len(sequences) != len(list((root/'content/position_play/sequences').glob(id+'__*.json'))):
        raise ValueError(f'Duplicate sequence tokens: {id}')
    result = {'id': id, 'name':d['nameZh'], 'source':str(path.relative_to(root)), 'sourceSHA256':sha(path),
              'standardCriteria':d['standardCriteria'], 'sets':d['sets'], 'intentRows':[], 'formations':[], 'oldParameterMismatches':[], 'issues':[]}
    for line in (root/'docs/research/20260819-动作库球形训练意图.md').read_text().splitlines():
        if re.match(r'\|\s*'+re.escape(id.removeprefix('drill_'))+r'\s*\|',line):result['intentRows'].append(line)
    seen = set()
    for fid, secs in sections(d):
        form={'id':fid,'images':[],'shots':[]}; result['formations'].append(form)
        for si, sec in enumerate(secs):
            key=sec.get('image')
            if not key:continue
            seqpath, frame=resolve_image(key,id,sequences)
            seq=json.loads(seqpath.read_text());proofpath=root/'build/position_play_export'/seqpath.stem/'render-input.json'
            proof=json.loads(proofpath.read_text()); stripped=json.loads(seqpath.read_text())
            for step in stripped['steps']:step.pop('analysis',None)
            if stripped!=proof['sequence']:raise ValueError(f'Stale render input: {seqpath}')
            png=root/'QiuJi/Resources/DrillTutorials'/(key+'.png');heic=root/'QiuJi/Resources/TutorialFigures'/(key+'.heic')
            native=frame+'_still.png' if frame.startswith('s') else frame+'.png'
            if not heic.is_file() or sha(png)!=proof['framesSHA256'][native]:raise ValueError(f'Image missing/stale: {key}')
            form['images'].append({'key':key,'png':str(png),'heic':str(heic),'sha256':sha(png),'sectionIndex':si,'sequence':str(seqpath.relative_to(root)),'frame':frame})
            if not re.fullmatch(r's\d+',frame):continue
            n=int(frame[1:]);step=seq['steps'][n-1];identity=(token(seqpath),n)
            if identity in seen:raise ValueError(f'Duplicate shot: {id} {identity}')
            seen.add(identity); value,reason=aim_angle(step)
            if reason and reason!='freeAimHasNoPocketLine':result['issues'].append({'shot':identity,'reason':reason})
            params={k:step['shot'][k] for k in ['spinX','spinY','velocity']}
            if params!=sec.get('params'):result['oldParameterMismatches'].append({'shot':identity,'old':sec.get('params'),'current':params})
            form['shots'].append({'stepId':step['id'],'number':n,'token':token(seqpath),'sectionIndex':si,'image':key,'sequence':str(seqpath.relative_to(root)),'sequenceSHA256':sha(seqpath),'params':params,'aimAngleDegrees':value,'noAimReason':reason,'caption':aim_caption(step,n),'targetKey':step['shot'].get('targetKey'),'pocket':step['shot'].get('pocket'),'before':step['before'],'after':step['after'],'potted':step.get('potted',[]),'cuePocketed':step.get('cuePocketed'), 'firstContact':{k:v for k,v in step.get('analysis',{}).get('firstContact',{}).items() if k in ['ballKey','cueMotionState']},'cueCushionContacts':step.get('analysis',{}).get('cueCushionContacts',[])})
    expected={(t,i+1) for t,p in sequences.items() for i in range(len(json.loads(p.read_text())['steps']))}
    if seen!=expected:raise ValueError(f'Shot coverage mismatch {id}: missing={expected-seen}, extra={seen-expected}')
    return result


def validate_candidate(original, candidate, facts):
    errors=[];allowed={'description','coachingPoints','standardCriteria','tutorial'}
    if {k:v for k,v in original.items() if k not in allowed}!={k:v for k,v in candidate.items() if k not in allowed}:errors.append('Protected top-level fields changed')
    if candidate['tutorial'].get('tutorialKind')!=original['tutorial'].get('tutorialKind'):errors.append('Tutorial kind changed')
    groups=dict(sections(candidate)); oldgroups=dict(sections(original))
    if set(groups)!=set(oldgroups):errors.append('Formation identities changed')
    expected_images={x['key'] for f in facts['formations'] for x in f['images']}
    actual_images=[s['image'] for _,ss in sections(candidate) for s in ss if s.get('image')]
    if set(actual_images)!=expected_images or len(actual_images)!=len(expected_images):errors.append('Image coverage changed')
    for f in facts['formations']:
        shots=f['shots'];ss=groups.get(f['id'],[])
        shotsecs=[s for s in ss if re.match(r'^第.+杆',s.get('title',''))]
        if len(shotsecs)!=len(shots):errors.append(f'{f["id"]}: shot section count')
        for row,sec in zip(shots,shotsecs):
            where=f'{f["id"]}/{row["number"]}'
            if sec.get('image')!=row['image']:errors.append(where+': image/step order mismatch')
            if sec.get('params')!=row['params']:errors.append(where+': params mismatch')
            if sec.get('caption')!=row['caption']:errors.append(where+': aim caption mismatch')
            prose=json.dumps([sec.get('content'),sec.get('items')],ensure_ascii=False)
            if '°' in prose or '瞄准角约' in prose:errors.append(where+': angle repeated in prose')
    text=json.dumps(candidate.get('tutorial'),ensure_ascii=False)
    for word in ['actualCutAngleDegrees','实际切角','实际切球角','cueForwardRollRatio','engineVersion','analysis.']:
        if word in text:errors.append('Internal analysis exposed: '+word)
    return errors


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);ap.add_argument('--output',type=Path,required=True);args=ap.parse_args();root=args.root.resolve();out=args.output;out.mkdir(parents=True,exist_ok=True)
    index=json.loads((root/'QiuJi/Resources/Drills/index.json').read_text());report=[]
    for c in index['categories']:
        for id in c['drills']:
            path=next((root/'QiuJi/Resources/Drills').glob('*/'+id+'.json'));facts=collect(root,path);dest=out/id;dest.mkdir(exist_ok=True)
            (dest/'facts.json').write_text(json.dumps(facts,ensure_ascii=False,indent=2)+'\n')
            for p in (root/'content/position_play/sequences').glob(id+'__*.json'):(dest/(token(p)+'.md')).write_text(digest(p))
            report.append({'id':id,'shots':sum(len(f['shots']) for f in facts['formations']),'images':sum(len(f['images']) for f in facts['formations']),'oldParameterMismatches':len(facts['oldParameterMismatches']),'issues':facts['issues']})
    (out/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print({'actions':len(report),'shots':sum(x['shots'] for x in report),'images':sum(x['images'] for x in report),'oldParameterMismatches':sum(x['oldParameterMismatches'] for x in report),'issues':sum(len(x['issues']) for x in report)})

if __name__=='__main__':main()
