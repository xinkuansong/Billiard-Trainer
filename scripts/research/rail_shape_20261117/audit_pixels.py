from pathlib import Path
from PIL import Image
import json,sys
p=Path(sys.argv[1]);rows=[]
for view in ['low','oblique','top']:
    def pixels(name):return list(Image.open(p/f'rail-shape-{view}-{name}.png').convert('RGB').getdata())
    a=pixels('A-original');mask=pixels('diagnostic-surfaceMask');old=pixels('B-bounce')
    for variant in ['B-bounce','C-soft','D-softPlus']:
        b=pixels(variant);outside=[];incremental=[]
        for i,(base,current,tag,previous) in enumerate(zip(a,b,mask,old)):
            if base==tag:
                if base!=current:outside.append({'xy':[i%1600,i//1600],'original':base,'candidate':current})
                if previous!=current:incremental.append(i)
        maximum=max((abs(x-y) for r in outside for x,y in zip(r['original'],r['candidate'])),default=0)
        # Do not reinterpret the failed original-zero assertion as a pass.
        # Independently prove that the NEW fill adds no changes outside the rail.
        assert len(outside)==2 and maximum==1
        assert not incremental
        rows.append({'view':view,'variant':variant,'originalZeroPassed':False,'outsidePixels':outside,'maximumOutside8BitDelta':maximum,'outsideChangesVersusPreviousBounce':len(incremental)})
result={'originalStrictTest':'failed; preserved','newFillVersusPreviousBounceOutsideRail':'zero for all views','rows':rows}
(p/'pixel-mask-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in result.items() if k!='rows'},ensure_ascii=False))
