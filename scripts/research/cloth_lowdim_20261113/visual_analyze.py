from pathlib import Path
import hashlib,json,sys
import numpy as np
from PIL import Image,ImageDraw
p=Path(sys.argv[1]);caps=json.loads((p/'captures.json').read_text());rows=[];pairs=[];actual=[]
q=[0,.01,.5,.95,.99,1]
def quant(a):return dict(zip(['min','p01','p50','p95','p99','max'],np.quantile(a,q).tolist()))
for rec in caps['records']:
 name=rec['id'];r=np.asarray(Image.open(p/f'{name}-reference.png').convert('RGB')).astype(float);variants={k:np.asarray(Image.open(p/f'{name}-k{k}.png').convert('RGB')).astype(float) for k in [2,4,8]};d=np.abs(r-variants[8])
 c=np.asarray(Image.open(p/f'{name}-coverage.png').convert('RGB'));active=(c[...,0]<2)&(c[...,1]>253)&(c[...,2]<2);fallback=(c[...,0]>253)&(c[...,1]<2)&(c[...,2]<2);cloth=active|fallback
 def diff(mask):
  v=d[mask];return {'pixels':int(mask.sum()),'rmse_8bit_channels':float(np.sqrt(np.mean(v*v))),'max_8bit_channels':float(v.max()),'mae_8bit_channels':float(v.mean()),'changed_pixels':int(np.any(v!=0,axis=-1).sum())}
 row={'id':name,'all':diff(np.ones(active.shape,bool)),'cloth':diff(cloth),'candidate':diff(active),'fallback':diff(fallback),'candidate_fraction_cloth':float(active.sum()/cloth.sum()),'reference_repeat_pixel_equal':np.array_equal(r,np.asarray(Image.open(p/f'{name}-repeat.png').convert('RGB'))),'reference_restored_pixel_equal':np.array_equal(r,np.asarray(Image.open(p/f'{name}-restored.png').convert('RGB'))),'red_control_changed_pixels':int(np.any(r!=np.asarray(Image.open(p/f'{name}-red-control.png').convert('RGB')),axis=-1).sum())}
 row['variants']={}
 for kval,image in variants.items():
  d=np.abs(r-image)
  row['variants'][f'k{kval}']={'all':diff(np.ones(active.shape,bool)),'cloth':diff(cloth),'candidate':diff(active),'fallback':diff(fallback)}
 d=np.abs(r-variants[8])
 def raw(s):return np.fromfile(p/f'{name}-{s}.rgba32f','<f4').reshape(400,600,4)
 ca=raw('calibration');black=raw('mask-black');mask=np.max(abs(ca-black),axis=-1)>.1
 assert mask.any();err=float(abs(ca[mask]-[.25,.5,.75,1]).max());assert err<1e-6
 nr=raw('normal-roughness');n=2*nr[...,:3]-1;g=2*raw('geometry-normal')[...,:3]-1;pos=raw('world-position')[...,:3]
 assert abs(np.linalg.norm(n[mask],axis=-1)-1).max()<1e-5
 bed=mask&(g[...,1]>.999)&(abs(pos[...,1]-.8)<.0005);assert bed.any()
 row['float_diagnostic']={'cloth_pixels':int(mask.sum()),'bed_pixels':int(bed.sum()),'calibration_max_abs':err,'normal_length_max_abs':float(abs(np.linalg.norm(n[mask],axis=-1)-1).max()),'bed_world_y':quant(pos[bed,1]),'bed_world_tilt_degrees':quant(np.degrees(np.arccos(np.clip(n[bed,1],-1,1)))),'bed_roughness':quant(nr[bed,3])}
 tangent=2*raw('tangent')[...,:3]-1;bitangent=2*raw('bitangent')[...,:3]-1
 row['float_diagnostic']['bed_tangent_median']=np.median(tangent[bed],axis=0).tolist()
 row['float_diagnostic']['bed_bitangent_median']=np.median(bitangent[bed],axis=0).tolist()
 row['float_diagnostic']['bed_tangent_handedness']=quant(np.sum(np.cross(tangent[bed],bitangent[bed])*g[bed],axis=-1))
 flat=np.flatnonzero(mask.ravel());pp=pos.reshape(-1,3)[flat];vv=np.array(rec['eye'])-pp;vv/=np.linalg.norm(vv,axis=-1,keepdims=True)
 full=np.c_[pp,n.reshape(-1,3)[flat],vv,nr.reshape(-1,4)[flat,3]].astype('<f4')
 np.save(p/f'{name}-actual-inputs.npy',full);np.save(p/f'{name}-pixel-indices.npy',flat.astype('<i4'));np.save(p/f'{name}-bed-mask.npy',bed.ravel()[flat])
 row['full_input_file']=f'{name}-actual-inputs.npy';row['full_input_count']=len(full)
 # Deterministic raster samples retain actual paired filtered roughness and world normal.
 ids=np.flatnonzero(bed.ravel());take=ids[np.linspace(0,len(ids)-1,384).astype(int)]
 selected=np.c_[n.reshape(-1,3)[take],nr.reshape(-1,4)[take,3]].astype('<f4');pairs.append(selected)
 pp=pos.reshape(-1,3)[take];v=np.array(rec['eye'])-pp;v/=np.linalg.norm(v,axis=-1,keepdims=True)
 actual.append(np.c_[pp,selected[:,:3],v,selected[:,3]].astype('<f4'))
 row['sample_rows']=[len(rows)*384,(len(rows)+1)*384]
 rows.append(row)
 # PNG heat map displays max channel difference, scaled 32x; preserve exact source PNGs.
 heat=np.zeros_like(r,dtype=np.uint8);heat[...,0]=np.minimum(d.max(axis=-1)*32,255).astype(np.uint8)
 Image.fromarray(heat).save(p/f'{name}-diff-x32.png')
 montage=Image.new('RGB',(1200,830),'#151515');draw=ImageDraw.Draw(montage)
 for j,(suffix,label) in enumerate([('reference','R production cloth'),('k8','K8 per lamp'),('coverage','Green: candidate / Red: fallback'),('diff-x32','Difference x32')]):
  tile=Image.open(p/f'{name}-{suffix}.png').convert('RGB').resize((600,400));x=(j%2)*600;y=(j//2)*415;montage.paste(tile,(x,y+15));draw.text((x+8,y+2),label,fill='white')
 montage.save(p/f'{name}-comparison.png')
 variants_montage=Image.new('RGB',(1200,830),'#151515');vd=ImageDraw.Draw(variants_montage)
 for j,(suffix,label) in enumerate([('reference','R production cloth'),('k2','K2 per lamp / 4 BRDF total'),('k4','K4 per lamp / 8 BRDF total'),('k8','K8 per lamp / 16 BRDF total')]):
  tile=Image.open(p/f'{name}-{suffix}.png').convert('RGB').resize((600,400));x=(j%2)*600;y=(j//2)*415;variants_montage.paste(tile,(x,y+15));vd.text((x+8,y+2),label,fill='white')
 variants_montage.save(p/f'{name}-variants.png')
np.save(p/'scenekit-paired.npy',np.concatenate(pairs));np.save(p/'scenekit-actual-inputs.npy',np.concatenate(actual))
report={'scope':'Isolated macOS SceneKit with actual USDZ cloth, complete production cloth surface and geometry modifiers, native PBR/environment/lights/exposure. Not complete App or mobile performance. K2/4/8 compute moments inside surface shader, diffuse retains original E/unoccludedE; assesses specular representation with exact guard fallback only.','float_diagnostic_format':'600x400 rgba32Float, no MSAA; constant shader calibration exact; shader outputs after SceneKit actual mesh/texture/normal intensity, not raw texel assumptions.','sample_formats':{'<fixture>-actual-inputs.npy':'N x10 all visible cloth row-major, p n v roughness; <fixture>-pixel-indices.npy maps rows to y*600+x and <fixture>-bed-mask.npy tags horizontal physical bed, not near selection.','scenekit-paired.npy':'1920x4 float32, nx ny nz roughness; 384 raster-spaced bed samples per camera, no inferred tangent basis.','scenekit-actual-inputs.npy':'1920x10 float32, px py pz nx ny nz vx vy vz roughness, normalized world view vector.'},'pixel_metrics':'Final PNG RGB code values 0..255, not linear radiance; candidate/fallback masks exclude blended MSAA boundaries by pure red/green diagnostic.','artifacts':'White bed dot and transverse line belong to source Plane_001 White faces606..610; native other table finishes/balls are simplified, so overall image is not app look acceptance.','rows':rows,'hashes':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in p.iterdir() if f.suffix in ['.png','.surface','.hdr','.npy']}}
(p/'pixel-fixtures.json').write_text(json.dumps({'dimensions':[600,400],'schema':['px','py','pz','nx','ny','nz','vx','vy','vz','roughness'],'space':'world','order':'row-major visible TaiNi; indexes separately supplied; no near-only filtering','records':caps['records']},indent=2)+'\n')
(p/'analysis.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps([{k:r[k] for k in ['id','variants','candidate_fraction_cloth','float_diagnostic']} for r in rows],indent=2))
