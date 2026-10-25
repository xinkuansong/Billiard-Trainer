"""Render a frozen random deletion sample; never change the corpus or decisions."""
from prepare import *
import math, shutil, html
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import fontManager
from matplotlib.patches import Circle, Rectangle
from verify_geometry import check, point

DEST=OUT/'deleted-random-five'
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False,'font.size':12})
BG='#f6f8f1'; GREEN='#244f41'; RED='#c04e38'; BLUE='#1488b3'; GOLD='#ce8c12'

def nearest(g,hit):
    found=[]
    for i,l in enumerate(g['lines']):
        a=point(l['start']);b=point(l['end']);v=b-a
        q=a+v*np.clip(np.dot(hit-a,v)/np.dot(v,v),0,1)
        found.append((float(np.linalg.norm(hit-q)),'line',i,q))
    for i,a in enumerate(g['arcs']):
        c=point(a['center']);lo=a['start'];hi=a['end']
        if hi<lo:hi+=2*math.pi
        theta=math.atan2(*(hit-c)[::-1]);theta=lo+(theta-lo)%(2*math.pi)
        angles=[lo,hi]
        if theta<=hi:angles.append(theta)
        for theta in angles:
            q=c+a['radius']*np.array([math.cos(theta),math.sin(theta)])
            found.append((float(np.linalg.norm(hit-q)),'arc',i,q))
    return min(found,key=lambda x:x[0])

def draw(ax,g,s,zoom=False):
    p=s['geometry'];b=np.array(p['object']);d=np.array(p['direction']);hit=np.array(s['hit']);r=g['radius'];aim=np.array(p['aim']);cap=b+d*p['captureDistance']
    ax.set_facecolor('#dfecd9')
    for i,l in enumerate(g['lines']):
        a=point(l['start']);z=point(l['end']);ax.plot([a[0],z[0]],[a[1],z[1]],color=RED if i==s['featureIndex'] and s['featureType']=='line' else GREEN,lw=3 if zoom else 2,zorder=3)
    for arc in g['arcs']:
        lo=arc['start'];hi=arc['end'];hi+=2*math.pi if hi<lo else 0
        t=np.linspace(lo,hi,60);c=point(arc['center']);ax.plot(c[0]+arc['radius']*np.cos(t),c[1]+arc['radius']*np.sin(t),color=GREEN,lw=2)
    for i,pk in enumerate(g['pockets']):
        poly=np.array([point(x) for x in pk['lip']]);ax.fill(poly[:,0],poly[:,1],color='#9dbca9',zorder=1)
        ax.add_patch(Circle(point(pk['center']),pk['radius'],color=GREEN,zorder=1))
        if i==p['pocket']:ax.add_patch(Circle(point(pk['center']),pk['radius']+(.008 if zoom else .015),fill=False,color=GOLD,lw=3,zorder=4))
    ax.plot([b[0],hit[0]],[b[1],hit[1]],color=BLUE,lw=2,zorder=4)
    ax.plot([hit[0],cap[0]],[hit[1],cap[1]],color=GOLD,ls='--',lw=2,zorder=4)
    ax.add_patch(Circle(b,r,color=BLUE,zorder=6));ax.text(*b,'B',color='white',ha='center',va='center',fontsize=10,zorder=7,clip_on=True)
    ax.add_patch(Circle(hit,r,facecolor='#ffffffaa',edgecolor=RED,lw=2,zorder=5))
    ax.scatter(*s['contact'],color=RED,s=40,zorder=8)
    ax.scatter(*aim,color=GOLD,marker='+',s=60,zorder=8)
    target=point(g['pockets'][p['pocket']]['center'])
    if zoom:
        ax.set(xlim=(-.235,.235),ylim=(aim[1]+.19,aim[1]-.19),xlabel='X（米）',ylabel='Z（米）')
        ax.annotate('球体先碰长库',xy=s['contact'],xytext=(.04 if hit[0]<0 else -.19,aim[1]+(-.13 if p['pocket']==5 else .15)),arrowprops={'arrowstyle':'->','color':RED},color=RED,fontsize=12,zorder=10)
        ax.text(.02,target[1]+(.10 if p['pocket']==5 else -.10),s['pocketName'],color=GOLD,ha='center',fontsize=12)
        ax.grid(alpha=.15);ax.tick_params(labelsize=9)
    else:
        hx=g['length']/2;hz=g['width']/2
        ax.set(xlim=(-hx-.10,hx+.10),ylim=(hz+.14,-hz-.14));ax.set_xticks([]);ax.set_yticks([])
        ax.text(b[0]+(.06 if b[0]<0 else -.06),b[1]+(-.10 if p['pocket']==5 else .10),'第二球 B',ha='left' if b[0]<0 else 'right',color=BLUE,fontsize=12)
        ax.text(target[0]+.12,target[1]+(-.14 if p['pocket']==5 else .14),s['pocketName'],color=GOLD,ha='center')
        ax.add_patch(Rectangle((-.235,aim[1]-.19),.47,.38,fill=False,ls=':',edgecolor='#617569',lw=1.2))
    ax.set_aspect('equal')

def main():
    selection=read(DEST/'selection.json');g=read(OUT/'geometry.json');summary=read(OUT/'summary.json');assert summary['auditPassed']
    gp={p['key']:p for p in read(OUT/'geometry-proofs.json')};dec={p['key']:p for p in read(OUT/'entry-decisions.json')};nat={p['key']:p for p in read(OUT/'native-validation/proofs.json')};wit=read(OUT/'existing-pot-witnesses.json')
    idx={p['stem']:p for p in read(OUT/'parts-index.json')};samples=[];sourceHashes={}
    for n,selected in enumerate(selection['samples'],1):
        deletion=selected['deletion'];k=deletion['geometryProofKey'];p=gp[k];native=nat[k]
        assert not dec[k]['passed'] and not p['passed'] and not native['passed'] and k not in wit
        assert p['object']==deletion['position'] and p['pocket']==deletion['recommendation']['pocket']
        original=SRC/'final'/(selected['stem']+'.jsonl.gz');assert sha(original)==idx[selected['stem']]['sourceSHA256'];sourceHashes[str(original)]=sha(original)
        row=next(r for r in rows(original) if r['id']==selected['id']);cand=next(c for c in row['candidates'] if c['cellID']==deletion['cellID']);assert deletion['recommendation'] in cand['top5']
        df=OUT/'deletions'/(selected['stem']+'.jsonl.gz');assert sha(df)==idx[selected['stem']]['deletionsSHA256'];assert deletion in next(r for r in rows(df) if r['id']==row['id'])['deleted'];sourceHashes[str(df)]=sha(df)
        passed,cap,solid,_=check(g,[p['object']],[p['pocket']]);assert not passed[0] and abs(solid[0]-p['solidDistance'])<1e-6
        b=np.array(p['object']);d=np.array(p['direction']);hit=b+d*p['solidDistance'];distance,kind,index,contact=nearest(g,hit)
        assert abs(distance-g['radius'])<1e-6 and p['solidDistance']<p['captureDistance']
        # These randomly selected cases all hit a finite main-rail segment before the mouth.
        assert kind=='line' and index<4
        for t in native['trials']:
            assert t['settled'] and not t['passed'] and t['events'][0]['kind']=='cushion' and t['events'][0]['index']==index
        side='上' if p['pocket']==4 else '下';half='左' if contact[0]<0 else '右'
        s={**selected,'number':n,'geometry':p,'native':native,'hit':hit.tolist(),'contact':contact.tolist(),'featureType':kind,'featureIndex':index,'railName':f'{side}长库{half}段','pocketName':side+'中袋','entryDegrees':math.degrees(math.atan2(abs(d[1]),abs(d[0]))),'blockedBeforeCaptureCM':100*(p['captureDistance']-p['solidDistance']),'contactRadiusErrorMeters':abs(distance-g['radius'])}
        samples.append(s)
        fig,axes=plt.subplots(1,2,figsize=(15,6.7),gridspec_kw={'width_ratios':[1.55,1]},facecolor=BG)
        draw(axes[0],g,s);draw(axes[1],g,s,True)
        axes[0].set_title('完整球桌 · 第二球与目标袋',pad=14);axes[1].set_title('袋口放大 · 实际球径 5.715 cm',pad=14)
        fig.suptitle(f'样本 {n} · {s["pocketName"]} · 入袋方向与长库夹角 {s["entryDegrees"]:.2f}°',fontsize=19,y=.97)
        fig.text(.035,.115,f'删除原因：到达捕获边界前 {s["blockedBeforeCaptureCM"]:.2f} cm，球体先碰到{s["railName"]}。',fontsize=14,color=RED)
        fig.text(.035,.068,'蓝实线：碰库前的原指定方向；红空心球：首次碰库时的球体；橙虚线：忽略碰库后的延长线。',fontsize=11)
        fig.text(.035,.027,'这是指定方向的几何示意；5档单球核验均未直接入指定袋，不代表所有瞄点和杆法均无解。',fontsize=11,color='#58655d')
        fig.subplots_adjust(left=.035,right=.975,bottom=.20,top=.85,wspace=.18)
        for ext in ['png','svg']:fig.savefig(DEST/f'sample-{n}.{ext}',dpi=150)
        plt.close(fig)
    write(DEST/'data.json',dict(geometry=g,selection=selection,samples=samples))
    fig,axes=plt.subplots(3,2,figsize=(15,13),facecolor=BG)
    for ax,s in zip(axes.flat,samples):draw(ax,g,s);ax.set_title(f'{s["number"]} · {s["pocketName"]} · 贴长库方向 {s["entryDegrees"]:.2f}°',fontsize=14)
    axes[2,1].axis('off');axes[2,1].text(.04,.76,'本次随机5例\n\n均先碰到长库，而非直接穿过袋口。\n\n进入详情可看球径、接触点与5档核验。\n\n入袋夹角与原第二杆切角不是同一个角。',va='top',fontsize=15,color=GREEN,linespacing=1.8)
    fig.suptitle('删除的中袋推荐 · 随机5个不同球形',fontsize=23);fig.tight_layout(rect=[0,0,1,.96]);fig.savefig(DEST/'overview.png',dpi=120);plt.close(fig)
    cards=[]
    for s in samples:
        q=s['deletion']['recommendation'];tr=[]
        for i,t in enumerate(s['native']['trials'],1):
            pockets=[e['pocket'] for e in t['events'] if e['kind']=='pocket'];outcome='未落袋' if not pockets else '落入'+', '.join({'pocket_0':'左上角袋','pocket_1':'右上角袋','pocket_2':'左下角袋','pocket_3':'右下角袋','pocket_4':'上中袋','pocket_5':'下中袋'}[x] for x in pockets)+'（已先碰主库）'
            tr.append(f'<tr><td>{i}</td><td>{t["speed"]:.6f}</td><td>{s["railName"]} · {t["events"][0]["time"]:.4f}s</td><td>{outcome}</td></tr>')
        b=s['geometry']['object'];n=s['number']
        cards.append(f'''<section id="sample-{n}"><h2>样本 {n} · {s['pocketName']}</h2><p class="identity">{html.escape(s['id'])} · B{s['deletion']['cellID']} · 原组合 {q['comboIndex']}</p>
        <div class="metrics"><span>入袋方向与长库夹角 <b>{s['entryDegrees']:.2f}°</b></span><span>原第二杆切角 <b>{q['angle']:.2f}°</b></span><span>B坐标 <b>({100*b[0]:.2f}, {100*b[1]:.2f}) cm</b></span></div>
        <a href="sample-{n}.svg" target="_blank"><img src="sample-{n}.png" alt="样本{n}完整球桌与中袋放大：球体先碰{s['railName']}"></a>
        <p class="reason">删除依据：原指定方向的球体先碰到{s['railName']}，碰撞早于捕获边界 {s['blockedBeforeCaptureCM']:.2f} cm；5档单球验证均未直接入指定袋，也无既有直进正例。</p>
        <p>原第二杆切角描述母球如何撞B；入袋夹角描述B往袋口走时有多贴库。切角很小仍可能撞库挡住袋口。同一B＋袋口在本库共删除 {s['deletedRouteCount']} 条推荐。</p>
        <details><summary>展开5档单球验证记录</summary><p>仅B运动、固定原方向、零自旋。速度是B的初速度，不是第一杆杆速；这些是已保存的原生事件，不是本页推测。</p><table><thead><tr><th>次数</th><th>B初速度 m/s</th><th>首个事件</th><th>最终入袋记录</th></tr></thead><tbody>{''.join(tr)}</tbody></table></details></section>''')
    nav=''.join(f'<a href="#sample-{i}">样本{i}</a>' for i in range(1,6))
    page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>中袋删除复核 · 随机5例</title><style>
    *{{box-sizing:border-box}}body{{margin:0;background:{BG};color:#243f32;font:17px/1.75 system-ui}}main{{max-width:1450px;padding:28px 24px;margin:auto}}h1{{line-height:1.3}}h2{{margin-bottom:0}}p{{margin:10px 0}}nav{{position:sticky;top:0;background:#f6f8f1f5;border-bottom:1px solid #ccd8c9;padding:12px 24px;z-index:2;display:flex;gap:14px;flex-wrap:wrap}}a{{color:#216c59}}nav a{{padding:4px 13px;border:1px solid #bdcbb7;border-radius:7px;text-decoration:none}}section{{background:white;border:1px solid #cbd8c6;border-radius:12px;margin:28px 0;padding:24px;scroll-margin-top:85px}}img{{width:100%;display:block}}.metrics{{display:flex;flex-wrap:wrap;gap:12px 30px;margin:18px 0}}.identity{{color:#617569;font-size:14px}}.reason{{background:#fff2ed;border-left:4px solid {RED};padding:12px 16px}}table{{width:100%;border-collapse:collapse;font-size:15px}}td,th{{padding:10px;border:1px solid #ccd8c9;text-align:left}}summary{{cursor:pointer;padding:10px 0}}details{{overflow:auto}}@media(max-width:650px){{main{{padding:18px 10px}}section{{padding:12px}}nav{{padding:8px;gap:8px}}}}
    </style><nav>{nav}<a href="../comfort-middle-geometry/">全量统计</a></nav><main><h1>中袋删除复核 · 随机5个球形</h1>
    <p>从本次50,830条删除推荐对应的17,197个不同B位置＋目标中袋中，等概率无放回抽5个，避免相同球形重复展示；未按角度或删除原因挑选。抽样种子：<code>{selection['seed']}</code>。</p>
    <p>蓝球是第二颗球，金圈是原目标中袋；全桌旁放大实际袋口。只展示原有删除证据，题库与过滤规则未改。点击图可打开矢量图放大。</p>
    <p><b>注意：</b>橙虚线是假设忽略碰撞后的直线延长，不是实际反弹轨迹。本轮判定限于原指定方向和已做的有限速度核验；不能据此断言其他瞄点、旋转或翻袋打法全部不可行。</p>{''.join(cards)}
    <p><a href="data.json">5例完整证据</a> · <a href="selection.json">抽样记录</a> · <a href="overview.png">五例总览图</a></p></main></html>'''
    (DEST/'index.html').write_text(page)
    for f in ['geometry.json','geometry-proofs.json','entry-decisions.json','native-validation/proofs.json','existing-pot-witnesses.json','summary.json','parts-index.json']:sourceHashes[str(OUT/f)]=sha(OUT/f)
    write(DEST/'verification.json',dict(passed=True,samples=5,uniqueKeys=len({s['geometry']['key'] for s in samples}),sourceHashes=sourceHashes,sourceRecommendationsMatched=True,deletionRecordsMatched=True,independentGeometryMatched=True,contactRadiusMaxErrorMeters=max(s['contactRadiusErrorMeters'] for s in samples),nativeFirstEventsMatchDrawnRail=True,corpusModified=False))
    served=ROOT/'output/two-ball-multi-position-top10-20261024/middle-deleted-five';served.mkdir(exist_ok=True)
    for p in DEST.iterdir():
        if p.is_file():shutil.copy2(p,served/p.name)
    print(json.dumps([dict(sample=s['number'],angle=s['entryDegrees'],rail=s['railName'],beforeCM=s['blockedBeforeCaptureCM']) for s in samples],ensure_ascii=False))

if __name__=='__main__':main()
