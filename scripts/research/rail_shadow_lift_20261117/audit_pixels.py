from pathlib import Path
from PIL import Image,ImageChops,ImageStat
import json,sys
root=Path(sys.argv[1]);previous=root.parent/'rail-finesse-20261117';rows=[]
def max_channel(im):
 r,g,b=im.split();return ImageChops.lighter(ImageChops.lighter(r,g),b)
for view in ['low','oblique','detail','top']:
 def read(v):return Image.open(root/f'rail-shadow-lift-{view}-{v}.png').convert('RGB')
 original=read('A-original');a=read('B-finesse');b=read('C-shadowLift');m=read('diagnostic-surfaceMask')
 old=Image.open(previous/f'rail-finesse-{view}-C-finesse.png').convert('RGB')
 baselineDifference=max_channel(ImageChops.difference(a,old))
 mask=max_channel(ImageChops.difference(original,m)).point(lambda v:255 if v else 0)
 delta=max_channel(ImageChops.difference(a,b));outside=ImageChops.multiply(delta,ImageChops.invert(mask))
 negative=max_channel(ImageChops.subtract(a,b))
 row={'view':view,'previousFinesseExactlyReproduced':baselineDifference.getbbox() is None,'baselineMaximumDelta':baselineDifference.getextrema()[1],'railMeanBeforeRGB':ImageStat.Stat(a,mask).mean,'railMeanAfterRGB':ImageStat.Stat(b,mask).mean,'changedPixels':sum(delta.histogram()[1:]),'maximumDelta':delta.getextrema()[1],'outsideRailChangedPixels':sum(outside.histogram()[1:]),'outsideRailMaximumDelta':outside.getextrema()[1],'darkenedPixelsOverOne':sum(negative.histogram()[2:])}
 rows.append(row);print(json.dumps(row))
(root/'shadow-lift-pixel-audit.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
