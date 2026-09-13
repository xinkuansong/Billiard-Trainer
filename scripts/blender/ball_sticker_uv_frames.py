"""Record original USD mesh-local UV frames for SceneKit close-up QA only."""
import pathlib,json
import numpy as np
from pxr import Usd,UsdGeom
root=pathlib.Path.cwd()
stage=Usd.Stage.Open(str(root/'QiuJi/Resources/TaiQiuZhuo.usdz'))
frames={}
for p in stage.Traverse():
    name=p.GetParent().GetName()
    if p.GetTypeName()!='Mesh' or not name.startswith('_') or not name[1:].isdigit():continue
    mesh=UsdGeom.Mesh(p);points=np.array(mesh.GetPointsAttr().Get())
    pv=UsdGeom.PrimvarsAPI(p).GetPrimvar('st');uv=np.array(pv.ComputeFlattened())
    indices=np.array(mesh.GetFaceVertexIndicesAttr().Get())
    if pv.GetInterpolation()=='faceVarying':positions=points[indices]
    elif pv.GetInterpolation() in ('vertex','varying'):positions=points
    else:raise ValueError(pv.GetInterpolation())
    mask=(np.abs(uv[:,0]-.5)<.12)&(np.abs(uv[:,1]-.5)<.15)
    a=uv[mask];positions=positions[mask]
    fit=np.linalg.lstsq(np.column_stack([a[:,0]-.5,a[:,1]-.5,np.ones(len(a))]),positions,rcond=None)[0]
    right=fit[0]/np.linalg.norm(fit[0]);up=fit[1]-right*np.dot(fit[1],right);up/=np.linalg.norm(up)
    front=np.cross(right,up)
    center=(points.min(axis=0)+points.max(axis=0))/2
    assert np.dot(front,fit[2]-center)>0
    frames[name]={'front':front.tolist(),'up':up.tolist()}
(root/'output/ball-stickers-20260913/uv-frames.json').write_text(json.dumps(frames,indent=2))
fixture=root/'QiuJiTests/Fixtures/BallStickerUVFrames.json'
fixture.parent.mkdir(parents=True,exist_ok=True)
fixture.write_text(json.dumps(frames,indent=2)+'\n')
print('UV_FRAMES',len(frames))
