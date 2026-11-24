"""Build conforming decals from the source USDZ and approved H artwork/layout. Run with Blender --background.
Source Z-up metres; vertices written in Plane_001 local coordinates. No source edits.
"""
import bpy, json, math, sys, hashlib, argparse
from pathlib import Path
from mathutils import Vector, Matrix
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
SRC=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,default=ROOT/'CuePhys/Resources/TableBranding')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=args.output;OUT.mkdir(parents=True,exist_ok=True)
manifest=json.loads((SRC/'layout.json').read_text())
source=ROOT/'CuePhys/Resources/ModelTrial20261010_TaiQiuZhuo.usdz'
assert hashlib.sha256(source.read_bytes()).hexdigest()==manifest['source_sha256'],'Source mesh changed; revalidate decal layout before rebuilding'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.usd_import(filepath=str(source),import_textures_mode='IMPORT_PACK')
obj=bpy.data.objects['Plane_001'];mesh=obj.data;mesh.calc_loop_triangles()
obj.matrix_world=Matrix(manifest['projectionMatrix'])
inverse=obj.matrix_world.inverted()
normal_to_world=obj.matrix_world.to_3x3().inverted().transposed()
# One RGBA mask atlas, with isolated padded rows for mipmapping.
atlas=np.zeros((512,1024,4),dtype=np.float32);regions={}
for row,name in enumerate(['H_singleline','H_domain','D_rail']):
 im=bpy.data.images.load(str(SRC/'artwork'/(name+'.png')));w,h=im.size;factor=min(1008/w,152/h);im.scale(round(w*factor),round(h*factor));w,h=im.size
 x=(1024-w)//2;y=row*168+(160-h)//2
 atlas[y:y+h,x:x+w]=np.array(im.pixels[:]).reshape(h,w,4)
 regions[name]=(x,y,w,h)
a=bpy.data.images.new('TableBrandingMask',width=1024,height=512,alpha=True);a.pixels.foreach_set(atlas.ravel());a.filepath_raw=str(OUT/'TableBrandingMask.png');a.file_format='PNG';a.save()
# Sutherland-Hodgman clipping preserves the actual underlying triangles.
def clip(points,axis,limit,keep_above):
 result=[]
 for i,p in enumerate(points):
  q=points[(i+1)%len(points)];dp=p[axis]-limit;dq=q[axis]-limit
  inside=dp>=0 if keep_above else dp<=0;other=dq>=0 if keep_above else dq<=0
  if inside:result.append(p)
  if inside!=other:result.append(p+(q-p)*(dp/(dp-dq)))
 return result
parts=[]
for item in manifest['placements']:
 center=Vector(item['center']);u=Vector(item['u']);v=Vector(item['v']);normal=u.cross(v);width=item['width'];height=item['height'];verts=[];normals=[];uv=[]
 x,y,w,h=regions[item['artwork']]
 for tri in mesh.loop_triangles:
  face_normal=(normal_to_world@tri.normal).normalized()
  if mesh.materials[tri.material_index].name!=item['material'] or face_normal.dot(normal)<=item['normal_threshold']:continue
  points=[obj.matrix_world@mesh.vertices[i].co for i in tri.vertices]
  if max(p.dot(normal) for p in points)<center.dot(normal)-.03:continue
  # Clip in projector space, retaining depth to conform to the curved leather.
  poly=[Vector(((p-center).dot(u)/width+.5,(p-center).dot(v)/height+.5,(p-center).dot(normal))) for p in points]
  for axis,bound,above in [(0,0,True),(0,1,False),(1,0,True),(1,1,False)]:
   if not poly:break
   poly=clip(poly,axis,bound,above)
  for i in range(1,len(poly)-1):
   for p in [poly[0],poly[i],poly[i+1]]:
    position=center+u*((p.x-.5)*width)+v*((p.y-.5)*height)+normal*p.z+face_normal*.00015
    verts.extend(inverse@position);normals.extend(tri.normal)
    # SceneKit UIImage texture origin is top-left.
    uv.extend(((x+p.x*w)/1024,1-(y+p.y*h)/512))
 assert verts,item['label']
 parts.append(dict(name=item['label'],kind='pocket' if item['material']=='Leather' else 'rail',vertices=verts,normals=normals,uv=uv))
result=dict(version=1,sourceSHA256=manifest['source_sha256'],coordinateSpace='Plane_001 local Z-up metres',offsetMeters=.00015,parts=parts)
(OUT/'TableBrandingMesh.json').write_text(json.dumps(result,separators=(',',':')))
print('DECALS',[(p['name'],len(p['vertices'])//9) for p in parts]);print('TRIANGLES',sum(len(p['vertices'])//9 for p in parts))
