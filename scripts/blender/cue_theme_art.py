"""Composite the original ten illustrations in Blender's linear image space.
Two repeats around the circumference put the subject on both viewing sides.
Only decorative regions are touched; shaft pixels and roughness remain intact.
"""
import bpy, numpy as np, hashlib

def apply_theme(color, design, root):
 path=root/'output/cue-stickers/textures'/('albedo_'+design[0]+'.png')
 image=bpy.data.images.load(str(path),check_existing=True)
 w,h=image.size
 pixels=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(pixels)
 art=pixels.reshape(h,w,4)[:,:,:3]
 # Byte-backed PNG Image.pixels exposes normalized sRGB channel values.
 # Decode before mixing with the procedural linear wood colors.
 art=np.where(art<=.04045,art/12.92,((art+.055)/1.055)**2.4)
 height,width=color.shape[:2]
 u,v=np.meshgrid((np.arange(width)+.5)/width,(np.arange(height)+.5)/height)
 def panel(bottom,top,weight=None,crop=(0,1)):
  x=((u*2)%1)*(w-1)
  y=np.clip((v-bottom)/(top-bottom),0,1)
  y=(crop[0]+y*(crop[1]-crop[0]))*(h-1)
  x0=x.astype(int);y0=y.astype(int);x1=np.minimum(x0+1,w-1);y1=np.minimum(y0+1,h-1)
  fx=(x-x0)[...,None];fy=(y-y0)[...,None]
  sampled=(art[y0,x0]*(1-fx)+art[y0,x1]*fx)*(1-fy)+(art[y1,x0]*(1-fx)+art[y1,x1]*fx)*fy
  mask=((v>=bottom)&(v<=top)).astype(float)
  if weight is not None:mask*=weight
  color[:]=color*(1-mask[...,None])+sampled*mask[...,None]
 if design[1]=='small':
  panel(.042,.174)
  # A second artwork inlay follows the existing four splice points.
  distance=np.abs(((u*4+.5)%1)-.5)*2
  panel(.20,.33,(v<(.33-.10*distance**.75)).astype(float),(.20,.80))
 else:
  panel(.294,.470)
  panel(.024,.072,crop=(.32,.68))
 return dict(artwork=str(path.relative_to(root)),artworkSHA256=hashlib.sha256(path.read_bytes()).hexdigest(),circumferenceRepeats=2,shaftUntouched=True)
