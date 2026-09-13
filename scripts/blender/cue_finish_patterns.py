"""Seamless cue finishes authored as Blender images, in linear color.
V runs from butt to tip; U is circumference. All dimensions below are UV regions.
No model coordinates or physics values are edited here.
"""
import numpy as np

# Persistent IDs stay stable; display names describe the revised wood/inlay designs.
DESIGNS = [
 ('inkDragon','small','墨龙','#171814','#e7c796','#77613d'),
 ('porcelain','small','青花','#181a19','#a9c8ca','#344d55'),
 ('landscape','small','山水','#573125','#e5ba82','#9d643d'),
 ('blackGold','small','黑金几何','#141713','#cda65e','#5e3825'),
 ('heritage','small','复古台球','#271a15','#8f3d35','#d4b17d'),
 ('wave','large','浪潮','#bd8d52','#428ab0','#1c3446'),
 ('orbit','large','星轨','#151b22','#c9d3cf','#364755'),
 ('racing','large','赛车条纹','#ba8c53','#4a8a62','#183b30'),
 ('koi','large','锦鲤','#542d22','#e4d7b6','#823a2a'),
 ('circuit','large','赛博电路','#171b1e','#b18b51','#3c434a'),
]

def linear(hexcolor):
 a=np.array([int(hexcolor[i:i+2],16)/255 for i in (1,3,5)],dtype=np.float32)
 return np.where(a<=.04045,a/12.92,((a+.055)/1.055)**2.4)

def patterns(design,width=512,height=4096):
 sid,kind,name,base,accent,inner=design
 u,v=np.meshgrid(np.arange(width,dtype=np.float32)/width,np.linspace(0,1,height,dtype=np.float32))
 rng=np.random.default_rng(420+list(d[0] for d in DESIGNS).index(sid))
 # Growth-ring contours on the cylindrical surface: long natural cathedrals,
 # with unequal spacing, subordinate latewood lines and fine longitudinal pores.
 phase=15.4*v + .72*np.cos(2*np.pi*(u-.25)) + .09*np.sin(v*31)+.045*np.sin(4*np.pi*u+v*7)
 dist=np.abs(np.sin(np.pi*phase))
 main_width=.10 if kind=='small' else .06
 sub_width=.07 if kind=='small' else .045
 late=np.exp(-(dist/main_width)**2)
 sub=np.exp(-(np.abs(np.sin(np.pi*(phase+.075)))/sub_width)**2)
 pores=(.5+.5*np.sin(2*np.pi*u*89+.4*np.sin(v*37)))**12
 fine=np.exp(-(np.abs(np.sin(np.pi*(phase*6.8+.07*np.sin(v*61))))/.1)**2)
 main_depth,sub_depth=(.92,.48) if kind=='small' else (.79,.36)
 grain=1-main_depth*late-sub_depth*sub-.15*fine-.075*pores + rng.normal(0,.005,u.shape)
 tone=['#dec596','#e3cdab','#d8b784','#e5c997','#d8bd93'][list(d[0] for d in DESIGNS).index(sid)%5]
 color=linear(tone)[None,None,:]*grain[:,:,None]
 rough=np.full(u.shape,.38,dtype=np.float32)
 def paint(mask,tint,texture=1):
  nonlocal color
  c=linear(tint) if isinstance(tint,str) else tint
  layer=np.broadcast_to(c,color.shape)*np.asarray(texture)[...,None]
  color=np.where(mask[...,None],layer,color)
 def ring(at,thickness,tint): paint(np.abs(v-at)<thickness/2,tint)
 def diamond(at,width,length,tint,count=4):
  d=np.abs(((u*count+.5)%1)-.5)/count
  paint(d/width+np.abs(v-at)/length<1,tint)
 darkgrain=.87+.13*np.sin(u*2*np.pi*29+np.sin(v*23))**2
 if kind=='small':
  # Four long, curved splices with pointed tips; narrow veneer outlines.
  distance=np.abs(((u*4+.5)%1)-.5)*2
  top=.38-.19*distance**.75
  paint(v<top,accent)
  paint(v<top-.006,'#dfc69b')
  paint(v<top-.010,base,darkgrain)
  if sid!='inkDragon':
   # A second hardwood front splice is restrained to the butt.
   secondary=.23-.14*distance**.72
   paint(v<secondary,accent)
   paint(v<secondary-.004,inner,darkgrain)
  paint(v<.018,'#171917')
  ring(.024,.004,'#bc995c')
  # Warm ash continues to the brass ferrule. No theme art on the shaft.
 else:
  # Maple shaft has quiet fibers, without prominent ash cathedrals.
  maple=linear('#ead7ad')*(.98-.025*pores)[...,None]
  paint(v>.495,maple)
  paint(v<.492,base,darkgrain if sid in ['koi','orbit'] else 1-.05*np.cos(v*200+u*8*np.pi))
  # Eight points, alternating heights, physically plausible forearm subdivision.
  section=np.floor(u*8).astype(int)
  distance=np.abs(((u*8+.5)%1)-.5)*2
  top=np.where(section%2==0,.47,.445)-.165*distance
  mask=(v>.267)&(v<top)
  paint(mask,'#161c20')
  paint((v>.267)&(v<top-.008),accent)
  paint((v>.267)&(v<top-.016),'#e5d5ae')
  paint((v>.267)&(v<top-.023),inner,darkgrain)
  # Leather or linen wrap, bounded by rings, separate tail sleeve.
  wrap=(v>.084)&(v<.259)
  if sid in ['wave','koi']:
   weave=.62+.25*(np.sin(u*2*np.pi*96)*np.sin(v*2*np.pi*1450))**2
   paint(wrap,'#454039' if sid=='koi' else '#282c2c',weave)
  else:
   leather=.78+.16*np.sin(u*2*np.pi*65+v*290)**2 + rng.normal(0,.025,u.shape)
   paint(wrap,'#202426',leather)
  rough=np.where(wrap,.52,rough)
  # Matching butt sleeve diamonds and three fine collar rings.
  diamond(.047,.018,.018,accent)
  diamond(.047,.010,.012,'#e7dabc')
  for at in [.08,.263,.485]:
   ring(at,.009,'#161c20');ring(at,.002,accent)
  paint(v<.016,'#ddd2b7' if sid in ['wave','koi','racing'] else '#222a2c')
  ring(.018,.002,accent)
  if sid=='circuit':
   # Modern carbon appearance is a material option, same underlying shaft.
   weave=.85+.1*np.cos(2*np.pi*(u*48+v*520))*np.cos(2*np.pi*(u*48-v*520))
   paint(v>.495,'#363b3c',weave)
   rough=np.where(v>.495,.36,rough)
 return np.clip(color,0,1).astype(np.float32),rough
