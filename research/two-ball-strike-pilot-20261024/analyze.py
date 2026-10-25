from pathlib import Path
import json,collections,math,statistics,hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from matplotlib.colors import ListedColormap
from matplotlib.patches import Patch
OUT=Path(__file__).resolve().parent
r=json.loads((OUT/'results.json').read_text());rows=r['rows'];inp=json.loads((OUT/'input.json').read_text())
assert len(rows)==630 and len({(x['tipID'],x['speedID']) for x in rows})==630
for x,c in zip(rows,inp['combinations']):
    assert all(x[k]==float(np.float32(c[k])) for k in ['spinX','spinY','velocity'])
    assert x['targetPottedSelected']==(x['targetActualPocket']=='pocket_3')
    assert ('cueStop' in x)==x['cueStopValid']
    assert x['cueCushionTotal']==sum(e['kind']=='cushion' and e['ball']=='cueBall' for e in x['events'])
    assert all(math.isfinite(n) for k in ['cueEndPosition','cueStop'] for n in x.get(k,[]))
    assert 'recorder' not in x and 'cuePath' not in x
for x in rows:
    x['parameterStatus'] = 'legal' if x['cueAccessAvailable'] else ('illegal' if 'strikeDirection' in x else 'undetermined')
    x['status'] = ('illegal_parameters' if x['parameterStatus']=='illegal' else ('success' if x['usableForPositionMatch'] else ('unresolved' if not x['resolved'] else ('scratch' if x['cuePocketed'] else ('target_miss' if not x['targetPottedSelected'] else 'no_valid_stop')))))
with (OUT/'records.jsonl').open('w') as f:
    for x in rows: f.write(json.dumps({'layoutID':r['board']['id'],**x},ensure_ascii=False,separators=(',',':'))+'\n')
valid=[x for x in rows if x['usableForPositionMatch']]
counts=dict(sorted(collections.Counter(x['cueMainRailsAfterContact'] for x in valid).items()))
reasons=dict(collections.Counter(v for x in rows for v in x['failureReasons']))
summary={'layout':r['board']['id'],'total':len(rows),'usable':len(valid),'failureReasonsNonexclusive':reasons,'termination':dict(collections.Counter(x['termination'] for x in rows)),'parameterStatus':dict(collections.Counter(x['parameterStatus'] for x in rows)),'status':dict(collections.Counter(x['status'] for x in rows)),'selectedPocketPots':sum(x['targetPottedSelected'] for x in rows),'scratches':sum(x['cuePocketed'] for x in rows),'cueAccessUnavailable':sum(not x['cueAccessAvailable'] for x in rows),'validStopsRegardlessOfPot':sum(x['cueStopValid'] for x in rows),'usableMainRailCountDistribution':counts,'rowsWithCueJawAfterContact':sum(x['cueJawsAfterContact']>0 for x in rows),'usableWithCueJawAfterContact':sum(x['cueJawsAfterContact']>0 for x in valid),'elapsedSeconds':r['elapsedSeconds'],'medianTrialMilliseconds':statistics.median(x['wallMilliseconds'] for x in rows),'accessElevationDegreesRange':[min(x.get('accessElevationRadians',0) for x in rows)*180/math.pi,max(x.get('accessElevationRadians',0) for x in rows)*180/math.pi],'dataBytes':(OUT/'results.json').stat().st_size,'resultSHA256':hashlib.sha256((OUT/'results.json').read_bytes()).hexdigest()}
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2));print(json.dumps(summary,ensure_ascii=False,indent=2))
font=FontProperties(fname='/Library/Fonts/Arial Unicode.ttf');plt.rcParams['font.family']=font.get_name();plt.rcParams['axes.unicode_minus']=False
fig,axes=plt.subplots(1,2,figsize=(15,8),gridspec_kw={'width_ratios':[1.35,1]})
colors=['#218a71','#d89a36','#ca5b65','#7c6ca9','#536d82'];labels=['可用于走位匹配','目标球未进指定袋','母球落袋','非法参数（不可出杆）','未完成 / 无有效停点']
m=np.zeros((45,14))
for x in rows:
    code=0 if x['usableForPositionMatch'] else (4 if not x['resolved'] else (3 if not x['cueAccessAvailable'] else (2 if x['cuePocketed'] else (1 if not x['targetPottedSelected'] else 4))))
    m[x['tipID']-1,x['speedID']-1]=code
ax=axes[0];ax.imshow(m,aspect='auto',interpolation='none',cmap=ListedColormap(colors),vmin=-.5,vmax=4.5)
speeds=[x['velocity'] for x in rows if x['tipID']==1]
ax.set_xticks(range(14),[f'{x:.2f}' for x in speeds],rotation=60);ax.set_yticks([0,4,9,14,19,24,29,34,39,44],[1,5,10,15,20,25,30,35,40,45]);ax.set_xlabel('随机杆速（m/s）');ax.set_ylabel('随机打点编号');ax.set_title('630组参数的实际结果')
ax.legend(handles=[Patch(facecolor=c,label=l) for c,l in zip(colors,labels)],loc='upper center',bbox_to_anchor=(.5,-.2),ncol=2,frameon=False,fontsize=10)
ax=axes[1];xs=list(counts);ys=list(counts.values());ax.bar(xs,ys,color='#218a71',width=.65)
for x,y in zip(xs,ys):ax.text(x,y+max(ys)*.025,str(y),ha='center')
ax.set_ylim(0,max(ys)*1.15);ax.set_xticks(xs);ax.set_xlabel('碰到第一颗目标球后的主库碰撞次数');ax.set_ylabel('有效参数组合数');ax.set_title(f'可用组合 {len(valid)} / 630 的吃库分布');ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.16);ax.set_axisbelow(True)
fig.suptitle('单球形 · 随机打点 × 杆速试跑',fontsize=22,y=.98)
fig.text(.5,.925,f"{r['board']['id']}  ·  原始切角17°  ·  保留全部输入及成败结果，不保存轨迹",ha='center',color='#576570',fontsize=12)
fig.subplots_adjust(top=.85,bottom=.26,wspace=.28)
fig.savefig(OUT/'pilot-summary.png',dpi=170,facecolor='white');fig.savefig(OUT/'pilot-summary.svg',facecolor='white');plt.close(fig)
# One example per observed rail count, preferring the speed nearest 2 m/s.
examples=[min([x for x in valid if x['cueMainRailsAfterContact']==k],key=lambda x:abs(x['velocity']-2)) for k in counts]
(OUT/'examples.json').write_text(json.dumps(examples,ensure_ascii=False,indent=2))
