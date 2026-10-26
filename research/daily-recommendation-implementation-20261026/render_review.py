from pathlib import Path
import json,math,html,sys
root=Path(__file__).resolve().parents[2]
out=root/'output/daily-recommendation-implementation-20261026'
source=Path(sys.argv[1]) if len(sys.argv)>1 else out/'pipe.log'
rows=[json.loads(line.split('DAILY_RECOMMENDATION_FIXTURE ',1)[1]) for line in source.read_text().splitlines() if line.startswith('DAILY_RECOMMENDATION_FIXTURE ')]
assert len(rows)==7
(out/'comparison.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
m=json.loads((root/'output/middle-pocket-angle-20261026/tangent-check/metadata.json').read_text())
names=['贴库中袋排除','近球与好打程度','较远目标更好打','路径遮挡','全桌仅低分路线','规则限定目标','无可用直进路线']
pockets=['左上袋','右上袋','左下袋','右下袋','上中袋','下中袋']
notes=['上中袋被排除，仍可推荐角袋','同一球袋也保留实际采用的瞄点','新方案选择1号：W更高，而非优先较近的2号','其他球占据线路时，只比较剩余候选','低分仍可入选；不设置85分门槛','只在规则允许的1号球中选择','候选为空，进入临时自由模式']
width,height=1600,1970
s=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">','<rect width="100%" height="100%" fill="#f4f2eb"/>','<g font-family="PingFang SC,Heiti SC,sans-serif" fill="#183b32">']
def text(x,y,t,size=21,color='#183b32',weight='normal'):
 s.append(f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{weight}">{html.escape(t)}</text>')
text(52,60,'每日清台 · 新旧推荐对照',36,weight='bold')
text(52,102,'同一盘面、同一合法球集合；W越高越好。连线为候选瞄准线，不是物理运动轨迹。',23)
for i,row in enumerate(rows):
 col=i%2;line=i//2;ox=52+col*778;oy=140+line*440
 s.append(f'<rect x="{ox-12}" y="{oy-22}" width="754" height="424" rx="15" fill="#ffffff"/>')
 text(ox,oy+6,f'{i+1:02d}  {names[i]}',23,weight='bold')
 scale=214;cx=ox+365;cy=oy+180
 def xy(p):return (cx+p[0]*scale,cy+p[1]*scale)
 def path(points,color,stroke=1.6,dash=''):
  coords=' '.join(f'{xy(p)[0]:.3f},{xy(p)[1]:.3f}' for p in points)
  s.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="{stroke}" stroke-dasharray="{dash}" stroke-linecap="round"/>')
 s.append(f'<rect x="{cx-1.27*scale}" y="{cy-.635*scale}" width="{2.54*scale}" height="{1.27*scale}" fill="#246a51"/>')
 for p in m['pockets']:
  x,y=xy([p['center'][0],p['center'][2]])
  s.append(f'<circle cx="{x}" cy="{y}" r="{p["radius"]*scale}" fill="#122c24"/>')
 for seg in m['linear']:path([[seg['start'][0],seg['start'][2]],[seg['end'][0],seg['end'][2]]],'#ccb990',2.5)
 for arc in m['circular']:
  a=arc['startAngle'];d=(arc['endAngle']-a)%(2*math.pi)
  path([[arc['center'][0]+arc['radius']*math.cos(a+d*j/30),arc['center'][2]+arc['radius']*math.sin(a+d*j/30)] for j in range(31)],'#ccb990',2.5)
 if i==0:
  path([[-1.24,-.635+.00926358+.29983165*1.24],[0,-.635+.00926358],[1.24,-.635+.00926358+.29983165*1.24]],'#e8d2ce',1,'4 4')
 for kind,color,dash in [('old','#7bbef1','7 5'),('new','#ffbc58','')]:
  chosen=row[kind]
  if chosen:
   ball=row['balls'][chosen['target']];aim=chosen['aim'];dx=aim[0]-ball[0];dz=aim[1]-ball[1];dist=math.hypot(dx,dz)
   ghost=[ball[0]-2*m['radius']*dx/dist,ball[1]-2*m['radius']*dz/dist]
   path([row['cue'],ghost],color,2.4,dash);path([ball,aim],color,2.4,dash)
   x,y=xy(aim);s.append(f'<circle cx="{x}" cy="{y}" r="5" fill="{color}"/>')
 for key,p in [('cue',row['cue'])]+list(row['balls'].items()):
  x,y=xy(p);r=m['radius']*scale;number=key.lstrip('_')
  fill='#faf6df' if key=='cue' else '#f6cc4b' if key in ['_1','_9'] else '#417bd6' if key=='_2' else '#333b38'
  s.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="#eee8d6" stroke-width=".7"/>')
  if key!='cue':s.append(f'<text x="{x}" y="{y+3.5}" text-anchor="middle" fill="{"#172d25" if key in ["_1","_9"] else "#fff"}" font-size="10">{number}</text>')
 for j,kind in enumerate(['old','new']):
  c=row[kind];label='旧' if kind=='old' else '新'
  desc='无候选' if not c else f'{c["target"].lstrip("_")}号 → {pockets[c["pocket"]]}   W {c["W"]:.1f}'
  text(ox+j*363,oy+371,label+'  '+desc,19,'#427eac' if kind=='old' else '#a75f0c',weight='bold')
 text(ox,oy+397,notes[i],17,'#5f7368')
text(830,1525,'读图说明',24,weight='bold')
for j,t in enumerate(['蓝色虚线：旧推荐；橙色实线：新推荐。','两个结果均按各自实际瞄点评估W，便于比较。','只排除某个袋口，不把整颗球排除。','评分不代表进球概率；力度、旋转与实际运动','继续由选中这一杆的原生物理预测处理。','图中球、袋口与圆角均使用生产坐标和比例。']):text(830,1570+j*38,t,20,'#5f7368')
text(52,1940,'来源：生产Swift候选函数的7个固定球形；仅每日启用。旧题库、历史成绩和轨迹P2保持。',21)
s.append('</g></svg>');(out/'comparison.svg').write_text('\n'.join(s))
print(out/'comparison.svg')
