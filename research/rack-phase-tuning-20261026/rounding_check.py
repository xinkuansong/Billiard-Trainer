from analyze import *
folder=OUT/'discovery';bases={r['input']['rackID']:r for r in readraw(folder) if r['input']['variant']=='baseline'};rr=[]
for raw in readraw(folder):
 if raw['input']['variant']!='radial_pure':continue
 p=np.array([[b['x'],b['z']] for b in raw['rack']]);bp=np.array([[b['x'],b['z']] for b in bases[raw['input']['rackID']]['rack']]);r=np.linalg.norm(p-NOM,axis=1);u=(p-NOM)/r[:,None];c=np.mean(np.sum(u*q,axis=1));s=np.mean(np.sum(u*t,axis=1));angle=math.degrees(math.atan2(abs(s),-c))
 if angle>=.05:rr.append(dict(id=raw['input']['id'],angle=angle,minRadiusMM=float(r.min()*1000),maxExpectedCoordinateErrorM=float(np.max(np.abs(p-expected(bp,'radial_pure'))))))
write(OUT/'float-angle-diagnostic.json',rr);print(rr)
