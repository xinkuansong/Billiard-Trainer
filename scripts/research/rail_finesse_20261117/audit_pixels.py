from pathlib import Path
from PIL import Image,ImageChops,ImageStat
import json,sys
root=Path(sys.argv[1]);rows=[]
def maximum_channel(im):
 r,g,b=im.split();return ImageChops.lighter(ImageChops.lighter(r,g),b)
for view in ['low','oblique','detail','top']:
 def read(v):return Image.open(root/f'rail-finesse-{view}-{v}.png').convert('RGB')
 a=read('A-original');m=read('diagnostic-surfaceMask')
 mask=maximum_channel(ImageChops.difference(a,m)).point(lambda v:255 if v else 0)
 inverse=ImageChops.invert(mask)
 baselineMean=ImageStat.Stat(a,mask).mean
 for variant in ['B-fiber','C-finesse']:
  b=read(variant);delta=maximum_channel(ImageChops.difference(a,b))
  outside=ImageChops.multiply(delta,inverse)
  histogram=outside.histogram();count=sum(histogram[1:]);maximum=outside.getextrema()[1]
  row={'view':view,'variant':variant,'railMeanBeforeRGB':baselineMean,'railMeanAfterRGB':ImageStat.Stat(b,mask).mean,'outsideRailChangedPixels':count,'outsideRailMax8BitDelta':maximum,'changedPixelsOver2':sum(delta.histogram()[3:])}
  rows.append(row);print(json.dumps(row))
(root/'finesse-pixel-audit.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
