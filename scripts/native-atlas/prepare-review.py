#!/usr/bin/env python3
"""Prepare unapproved review manifests and 1x contact sheets; never self-approve images."""
import argparse, json, re
from pathlib import Path
from PIL import Image, ImageDraw

p=argparse.ArgumentParser()
p.add_argument('--run',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--batch',required=True)
p.add_argument('--exclude-reviewed',nargs='*',type=Path,default=[])
p.add_argument('--include-valid-partials',action='store_true',help='Expose individually validated captures from failed jobs for manual review; never claim the failed workflow is complete')
a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=False)
source=json.loads(Path('output/app-interface-redesign/B02/r4/coverage/coverage.json').read_text())['entries']
titles={e['id']:e['title'] for e in source}
for e in source:titles.setdefault(e['family_id'],e['title'])
pages={'10':'10｜训练首页与计划','11':'11｜训练过程与总结','20':'20｜动作库与精讲','30':'30｜练习与理论','40':'40｜记录与统计','50':'50｜我的与设置','60':'60｜账号与订阅','70':'70｜每日清台','71':'71｜其他球桌与训练工具','80':'80｜系统与内部工具'}
def page_for(page):
    n=int(page[1:3])
    return pages['10' if n in [2,3,4,5,6,13] else '11' if 7<=n<=11 else '20' if n in [14,15,16,27] else '30' if n in [17,18] else '40' if 19<=n<=23 else '60' if n in [28,29,30,31] else '50' if n in [12,24,25,26,32,33,34,35] else '70' if n==36 else '71' if n==37 else '80']
reviewed={(e['path'],e['sha256']) for path in a.exclude_reviewed for e in json.loads(path.read_text())['images'] if e['status']=='VALIDATED'}
images=[];duplicates=[];failed=[]
for file in sorted(a.run.glob('*/*/result.json')):
    j=json.loads(file.read_text())
    partial=j['status']!='CAPTURED_NEEDS_VISUAL_REVIEW'
    if partial:
        failed.append(str(file))
        if not a.include_valid_partials:continue
    flow_file=file.parent/'flow.json'
    catalog=json.loads(flow_file.read_text()).get('catalog',{}) if flow_file.exists() else {}
    seen={}
    for e in j['images']:
        name=Path(e['metadata']).stem
        group=re.sub(r'-scroll\d+$','',name)
        duplicate_key=(group,e['sha256'])
        if duplicate_key in seen:
            duplicates.append({'path':e['path'],'sameAs':seen[duplicate_key],'sha256':e['sha256'],'reason':'exact repeated end viewport; raw retained'})
            continue
        seen[duplicate_key]=e['path']
        if (e['path'],e['sha256']) in reviewed:continue
        identity=catalog.get(group)
        page=identity['id'].split('/')[-1] if identity else re.match(r'P\d\d(?:-\d\d)?',name)[0]
        page_id=identity['id'] if identity else 'APP/'+page
        page_title=identity['title'] if identity else titles.get(page,page)
        figma_page=pages[identity['figmaPage']] if identity else page_for(page)
        device=j['worker'];orientation=j['orientation'];theme=j['theme'];state=group[len(page):].lstrip('-')
        if identity:state=identity['state']
        slice_match=re.search(r'-scroll(\d+)$',name);slice_index=int(slice_match[1]) if slice_match else 0
        meta=json.loads(Path(e['metadata']).read_text());premium='-forcePremium' in meta['launchArguments']
        fixture=meta['fixture']+('-debug-premium' if premium else '-free')
        if '-v53.authenticatedProfileFixture' in meta['launchArguments']:fixture+='-offline-account'
        if meta.get('storeKitFixture'):fixture+='-local-storekit'
        images.append({**e,'status':'UNREVIEWED','userReview':'PENDING','page':figma_page,'pageId':page_id,'pageName':page_title,'slotId':f'{page_id}/{state}/{fixture}/{device}/{orientation}/{theme}/scroll{slice_index:02}',
                       'captureId':a.batch+'/'+device+'/'+j['id']+'/'+name,'width':e['window'][0],'height':e['window'][1],
                       'x':80,'y':200,'label':f'{page_title} · {state} · {device} {e["window"][0]}×{e["window"][1]} · {theme} · {slice_index:02} · 待评审',
                       'layoutGroup':group,'device':device,'orientation':orientation,'theme':theme,'slice':slice_index,
                       'workflowStatus':j['status'],'partialWorkflow':partial,'resultEvidence':str(file.resolve())})
manifest={'batch':a.batch,'userAcceptance':False,'images':images,'duplicates':duplicates,'failedJobs':failed}
(a.output/'review.pending.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
contacts=[]
# Group by actual window so every viewport is displayed at its real logical size.
for size in sorted({tuple(e['window']) for e in images}):
    group=[e for e in images if tuple(e['window'])==size]
    w,h=size;columns=max(1,min(3,1300//w))
    for start in range(0,len(group),columns):
        chunk=group[start:start+columns];canvas=Image.new('RGB',(w*len(chunk),h+46),'#ddd');draw=ImageDraw.Draw(canvas)
        for i,e in enumerate(chunk):
            im=Image.open(e['path'])
            # Review derivative only. Original PNG and hash are never modified.
            canvas.paste(im.resize((w,h),Image.Resampling.LANCZOS),(i*w,46))
            draw.text((i*w+4,4),Path(e['metadata']).stem,fill='black');draw.text((i*w+4,23),e['device']+'/'+e['orientation']+'/'+e['theme'],fill='black')
        target=a.output/f'contact-{w}x{h}-{start//columns:03}.jpg';canvas.save(target,quality=94)
        contacts.append({'path':str(target.resolve()),'captures':[e['captureId'] for e in chunk]})
(a.output/'contact-index.json').write_text(json.dumps(contacts,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'images':len(images),'duplicates':len(duplicates),'failedJobs':len(failed),'contacts':len(contacts)}))
