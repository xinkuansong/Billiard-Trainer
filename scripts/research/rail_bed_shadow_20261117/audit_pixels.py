from pathlib import Path
from PIL import Image,ImageChops,ImageStat,ImageFilter
import json,sys
root=Path(sys.argv[1]);previous=root.parent/'rail-shadow-lift-20261117';rows=[]
def maximum(im):
 r,g,b=im.split();return ImageChops.lighter(ImageChops.lighter(r,g),b)
for view in ['low','oblique','detail','pocket','top']:
 def read(v):return Image.open(root/f'rail-bed-shadow-{view}-{v}.png').convert('RGB')
 original=read('A-original');a=read('B-lift');b=read('C-bedShadow');mask=read('diagnostic-surfaceMask')
 # Exclude shared antialiased boundary pixels when checking the raised cushion itself.
 rail=maximum(ImageChops.difference(original,mask)).point(lambda v:255 if v else 0).filter(ImageFilter.MinFilter(3))
 delta=maximum(ImageChops.difference(a,b));railDelta=ImageChops.multiply(delta,rail)
 row={'view':view,'changedPixels':sum(delta.histogram()[1:]),'maximumChannelDelta':delta.getextrema()[1],'raisedRailInteriorChanges':sum(railDelta.histogram()[1:]),'raisedRailInteriorMaxDelta':railDelta.getextrema()[1]}
 if view!='pocket':
  prev=Image.open(previous/f'rail-shadow-lift-{view}-C-shadowLift.png').convert('RGB');d=maximum(ImageChops.difference(a,prev));row.update(previousLightLiftExactlyReproduced=d.getbbox() is None,previousBaselineMaximumDelta=d.getextrema()[1])
 rows.append(row);print(json.dumps(row))
(root/'bed-shadow-pixel-audit.json').write_text(json.dumps(rows,indent=2))
