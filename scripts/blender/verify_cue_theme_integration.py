"""Check exact shaft preservation and original-art provenance after Blender bake."""
import bpy, pathlib, hashlib, json, numpy as np
root=pathlib.Path.cwd();out=root/'output/cue-stickers';assets=root/'QiuJi/Resources/CueStyles';before=out/'theme-integration/before'
manifest=json.loads((out/'manifest.json').read_text());results=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pixels(p):
 i=bpy.data.images.load(str(p),check_existing=False);w,h=i.size
 a=np.empty(w*h*4,dtype=np.float32);i.pixels.foreach_get(a);bpy.data.images.remove(i)
 return a.reshape(h,w,4)
for item in manifest['styles']:
 name='Cue_'+item['style'];old=pixels(before/(name+'.png'));new=pixels(assets/(name+'.png'))
 cutoff=.4 if item['kind']=='small' else .495
 start=int(np.ceil(cutoff*new.shape[0]))+2
 assert np.array_equal(old[start:],new[start:]),name+' shaft changed'
 assert not np.array_equal(old,new),name+' artwork missing'
 assert sha(before/(name+'_roughness.png'))==sha(assets/(name+'_roughness.png'))
 assert sha(root/item['artwork'])==item['artworkSHA256']
 results.append(dict(style=item['style'],shaftPixelsIdentical=True,roughnessIdentical=True,artworkInputVerified=True))
assert sha(before/'CueUV.usdz')==sha(assets/'CueUV.usdz')
assert sha(root/'QiuJi/Resources/TaiQiuZhuo.usdz')==manifest['sourceSHA256']
(out/'theme-integration/verification.json').write_text(json.dumps(dict(styles=results,sharedUVByteIdentical=True,sourceByteIdentical=True),indent=2))
print('THEME_INTEGRATION_VERIFIED',len(results))
