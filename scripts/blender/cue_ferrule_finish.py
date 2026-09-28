"""Repair the exposed wood sleeve at the ferrule/tip junction without moving vertices."""
import math

def finish_ferrule(obj):
    mesh=obj.data
    copper=next(i for i,m in enumerate(mesh.materials) if m.name.split('.')[0]=='copp')
    wood=[i for i,m in enumerate(mesh.materials) if m.name.split('.')[0] in ('White_Wood','black_2')]
    copper_faces=[f for f in mesh.polygons if f.material_index==copper]
    rear=min(mesh.vertices[v].co.y for f in copper_faces for v in f.vertices)
    front=max(mesh.vertices[v].co.y for f in copper_faces for v in f.vertices)
    repaired=[]
    for f in mesh.polygons:
        ys=[mesh.vertices[v].co.y for v in f.vertices]
        if f.material_index in wood and min(ys)>=rear and max(ys)>front:
            f.material_index=copper;repaired.append(f.index)
    # Copper-only cylindrical UVs: horizontal circumference, vertical axial distance.
    faces=[f for f in mesh.polygons if f.material_index==copper]
    front=max(mesh.vertices[v].co.y for f in faces for v in f.vertices)
    cz=(max(v.co.z for v in mesh.vertices)+min(v.co.z for v in mesh.vertices))/2
    for f in faces:
        coords=[]
        for li in f.loop_indices:
            v=mesh.vertices[mesh.loops[li].vertex_index].co
            coords.append(((math.atan2(v.z-cz,v.x)/(2*math.pi)+.5)%1,(v.y-rear)/(front-rear)))
        seam=max(u for u,v in coords)-min(u for u,v in coords)>.5
        for li,(u,v) in zip(f.loop_indices,coords):mesh.uv_layers.active.data[li].uv=(u+1 if seam and u<.5 else u,v)
    return dict(reassignedFaces=len(repaired),ferruleStart=rear,ferruleEnd=front)
