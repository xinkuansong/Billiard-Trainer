"""Render frozen original trajectories, with an explicitly provisional effort ordering."""
from pathlib import Path
import hashlib, html, json, math, shutil
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, Polygon
from matplotlib.font_manager import fontManager

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/two-ball-execution-five-20261025'
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
DATA=json.loads((OUT/'data.json').read_text())
G=DATA['geometry']; HX=G['length']/2; HZ=G['width']/2; R=G['radius']
NAMES=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
COLORS=['#277A69','#357CAE','#93753A','#9265AC','#B45660']
INK='#203D38'; MUTED='#5E716B'; BG='#F5F5EF'
NOTES=[
 ['中杆，无需叠加高低或侧塞；本题操作负担最低。','只增加少量低杆，侧塞仍为零；排在中杆之后。','不吃库，但低杆幅度明显加深；排在前两条一库路线后。','右塞与低杆叠加；加权打点负担明显高于纯低杆。','左塞更大，同时杆速超过4m/s；本题估计最难。'],
 ['纯高杆，无侧塞，所需偏心量最小；本题先排第一。','纯低杆的幅度比上一条高杆更大，因此暂排第二。','右塞配较深低杆；两项叠加使操作要求增加。','虽杆速更低，但侧塞更大；现有模型下略难于上一条。','左塞达到0.404R并叠加高杆；侧塞项使它排在最后。'],
 ['两库，但只有少量高杆、没有侧塞；初排最容易。','左塞配低杆，即使只吃一库，打点负担也更高。','右塞与低杆幅度都比上一条大；因此继续后排。','高低偏心量较小，但右塞显著增加；侧塞项主导排序。','右塞与上一条接近，低杆幅度更深；本题排最后。'],
 ['无侧塞、低杆幅度小；当前模型的操作负担最低。','仍是纯低杆，但幅度接近上一条的两倍；排第二。','杆速4.252m/s带来加罚；侧塞较小，仍排在后两条前。','杆速虽低，却要左塞加低杆配合；加权打点项更高。','左塞与高杆都较明显；混合打点负担使它排在最后。'],
 ['中杆一库，杆速未超过4m/s；本题估计最容易。','两库，小幅高杆、无侧塞；排在中杆后。','同为两库高杆，打点幅度略大；暂排第三。','三库且杆速超过4m/s；但高杆量小、无需侧塞。','虽然不吃库，却需要较深低杆；当前模型把它排最后。']
]
FOCUS=[
 '看第3名：无库路线没有自动排在一库路线前。',
 '第3/4名很接近；高低杆同权、低速控力尚未单独计入。',
 '看第1名：两库少量高杆，排在一库带塞路线前。',
 '看第3/4名：大力少塞与小力混合打点，哪条更难？',
 '看第4/5名：三库高杆与无库低杆，当前排序是否合理？'
]

def stroke(t):
    x,y=t['spinX'],t['spinY']; parts=[]
    if abs(y)>1e-8: parts.append(('高杆' if y>0 else '低杆')+f' {abs(y):.3f}R')
    if abs(x)>1e-8: parts.append(('左塞' if x>0 else '右塞')+f' {abs(x):.3f}R')
    return ' + '.join(parts) if parts else '中杆 (0, 0)'

def table(ax,s,t=None,q=None,color='#277A69',labels=True):
    b=s['board']; c=s['candidate']; ax.axis('off'); ax.set_aspect('equal')
    ax.add_patch(Rectangle((-HX-.045,-HZ-.045),2*HX+.09,2*HZ+.09,color='#35594E'))
    ax.add_patch(Rectangle((-HX,-HZ),2*HX,2*HZ,color='#D8E6D9'))
    for p in G['pockets']:
        ax.add_patch(Polygon([(v['x'],v['z']) for v in p['lip']],fc='#173C32'))
        ax.add_patch(Circle((p['center']['x'],p['center']['z']),p['radius'],fc='#173C32'))
    for line in G['lines']:
        ax.plot([line['start']['x'],line['end']['x']],[line['start']['z'],line['end']['z']],color='#2B5949',lw=.65)
    pocket=G['pockets'][b['pocket']]['center']
    ax.add_patch(Circle((pocket['x'],pocket['z']),.069,fill=False,ec='#D69A22',lw=2))
    # Generation anchor, deliberately a direction reference, not a measured A trajectory.
    ax.plot([b['object'][0],b['aim'][0]],[b['object'][1],b['aim'][1]],'--',color='#BB882B',lw=1.1)
    if t is not None:
        xy=[p[1:] for p in t['trajectory2mm']['points']]
        ax.plot([b['cue'][0],xy[0][0]],[b['cue'][1],xy[0][1]],':',color='#74877D',lw=1.3)
        ax.plot([p[0] for p in xy],[p[1] for p in xy],color=color,lw=2.1)
        for a,v in zip(xy,xy[1:]):
            if math.dist(a,v)>.22:
                ax.annotate('',xy=[a[j]+.61*(v[j]-a[j]) for j in range(2)],xytext=[a[j]+.48*(v[j]-a[j]) for j in range(2)],arrowprops=dict(arrowstyle='->',color=color,lw=1.1))
        for event in t['trajectory2mm']['cushions']:
            p=xy[event['pointIndex']]; ax.plot(*p,'o',ms=3,color=color)
        ax.add_patch(Circle(t['cueStop'],R,fc='white',ec=color,lw=2,zorder=8))
        if labels: ax.annotate('停',t['cueStop'],xytext=(7,-12),textcoords='offset points',fontsize=9,color=color,zorder=12,bbox=dict(fc='white',ec='none',alpha=.85,pad=.5))
        if q:
            p=G['pockets'][q['pocket']]['center']; ax.add_patch(Circle((p['x'],p['z']),.063,fill=False,ec='#4A96B2',lw=1.3,ls=':'))
    for pos,fc,ec,label in [(b['cue'],'#FFFDF6','#66746B','C'),(b['object'],'#EABC52','#87621B','A'),(c['position'],'#368DA9','#1D6279','B')]:
        ax.add_patch(Circle(pos,R,fc=fc,ec=ec,lw=1.1,zorder=10));ax.text(*pos,label,ha='center',va='center',fontsize=8,color='white' if label=='B' else '#263F35',zorder=11)
    ax.set_xlim(-HX-.13,HX+.13); ax.set_ylim(HZ+.13,-HZ-.13)

def spin(ax,t):
    ax.axis('off');ax.set_aspect('equal')
    ax.add_patch(Circle((0,0),1,fc='white',ec='#B3C1B7',lw=1))
    ax.add_patch(Circle((0,0),.5,fill=False,ec='#CCD5CF',lw=1,ls='--'))
    ax.plot([-.6,.6],[0,0],color='#D6DDD7',lw=.6);ax.plot([0,0],[-.6,.6],color='#D6DDD7',lw=.6)
    ax.plot(-t['spinX'],t['spinY'],'o',color='#C7444C',ms=5)
    ax.text(0,1.18,'高',ha='center',fontsize=8,color=MUTED);ax.text(-1.22,0,'左',ha='center',va='center',fontsize=8,color=MUTED)
    ax.set_xlim(-1.5,1.5);ax.set_ylim(-1.1,1.5)

def draw_sample(s):
    n=s['number']; fig=plt.figure(figsize=(16,18),facecolor=BG)
    fig.text(.045,.966,f'{n:02d}  {s["title"]}',fontsize=26,color=INK,weight='bold')
    fig.text(.045,.936,f'第一球 → {NAMES[s["board"]["pocket"]]}  ·  生成角 {s["board"]["angle"]}°  ·  B{s["candidate"]["cellID"]}  ·  现有5条全部保留',fontsize=13,color=MUTED)
    fig.text(.045,.908,'由易到难 ↓    原路线 = 当前过滤库中的顺序；只在本题内比较。',fontsize=12,color=INK)
    fig.text(.045,.883,FOCUS[n-1],fontsize=13,color='#9A612D')
    for i,rank in enumerate(s['ranking']):
        t=next(t for t in s['routes'] if t['comboIndex']==rank['comboIndex'])
        q=next(q for q in s['candidate']['top5'] if q['comboIndex']==rank['comboIndex'])
        y=.705-i*.153; col=COLORS[i]
        fig.add_artist(Rectangle((.032,y-.003),.936,.145,transform=fig.transFigure,fc='white',ec='#DCE3DA',lw=.8,zorder=0))
        table(fig.add_axes([.045,y,.435,.139]),s,t,q,col)
        fig.text(.505,y+.113,f'{i+1}  原路线 {rank["originalRank"]}',fontsize=20,color=col,weight='bold')
        fig.text(.505,y+.085,f'杆速 {t["velocity"]:.3f} m/s    ·    吃库 {t["cueMainRailsAfterContact"]} 次',fontsize=14,color=INK)
        fig.text(.505,y+.059,stroke(t),fontsize=13,color=INK)
        fig.text(.505,y+.034,NOTES[n-1][i],fontsize=11.1,color=MUTED)
        fig.text(.505,y+.010,f'初排指标 {rank["effort"]:.3f}   ·   第二球 → {NAMES[q["pocket"]]}   ·   组合 {t["comboIndex"]}',fontsize=10,color=MUTED)
        spin(fig.add_axes([.883,y+.066,.060,.067]),t)
    fig.text(.045,.060,'C 初始母球  /  A 第一球  /  B 第二球  /  彩线为首碰后原轨迹  /  空心白球为停点',fontsize=10.5,color=MUTED)
    fig.text(.045,.043,'灰点线：首碰前连线示意；金虚线：第一球入袋方向参考。打点以球半径R为单位；小盘虚圈为0.5R。',fontsize=10,color=MUTED)
    fig.text(.045,.026,'初排指标 = 2.5×侧塞量 + 高低杆量 + 0.25×超出4m/s的杆速；越小越容易。库数、第二杆舒适度不计入。',fontsize=10,color=MUTED)
    fig.text(.045,.010,'估计排序，未做扰动容错或真人验证；高低杆同权、低速控力与出杆空间未单独建模。源题库与App未改。',fontsize=10,color=MUTED)
    fn=f'sample-{n}.png';fig.savefig(OUT/fn,dpi=135);plt.close(fig)
    return fn

def main():
    files=[draw_sample(s) for s in DATA['samples']]
    fig=plt.figure(figsize=(15,15.4),facecolor=BG)
    fig.text(.045,.965,'同一球形，哪条路线更容易打出来？',fontsize=25,color=INK,weight='bold')
    fig.text(.045,.935,'5题 · 25条原轨迹 · 操作要求初排 / 尚未测试容错',fontsize=14,color=MUTED)
    for i,s in enumerate(DATA['samples']):
        y=.745-i*.168
        table(fig.add_axes([.035,y,.39,.15]),s)
        fig.text(.45,y+.119,f'{i+1:02d}  {s["title"]}',fontsize=19,color=INK,weight='bold')
        order=' → '.join(str(q['originalRank']) for q in s['ranking'])
        fig.text(.45,y+.082,'原路线：'+order+'  （由易到难）',fontsize=16,color=COLORS[0])
        fig.text(.45,y+.048,FOCUS[i],fontsize=11,color=MUTED)
        fig.text(.45,y+.015,f'{NAMES[s["board"]["pocket"]]} · 生成角{s["board"]["angle"]}° · B{s["candidate"]["cellID"]}',fontsize=11,color=MUTED)
    fig.text(.045,.038,'角袋2题 + 中袋3题；有意选取不同对比场景，不代表全库比例。每题另有完整逐路线大图。',fontsize=11,color=MUTED)
    fig.text(.045,.014,'当前模型：侧塞权重2.5 / 高低杆权重1 / 超过4m/s加罚；吃库次数仅标注，第二杆舒适度独立。',fontsize=11,color=MUTED)
    fig.savefig(OUT/'overview.png',dpi=135);plt.close(fig)
    nav=''.join(f'<button data-n="{i}" aria-pressed="{str(i==0).lower()}">{i+1} · {html.escape(s["title"])}</button>' for i,s in enumerate(DATA['samples']))
    sections=[]
    for i,s in enumerate(DATA['samples']):
        rows=[]
        for j,q in enumerate(s['ranking']):
            t=next(t for t in s['routes'] if t['comboIndex']==q['comboIndex'])
            rows.append(f'<tr><td>{j+1}</td><td>{q["originalRank"]}</td><td>{t["velocity"]:.3f} m/s</td><td>{stroke(t)}</td><td>{t["cueMainRailsAfterContact"]}</td><td>{NOTES[i][j]}</td></tr>')
        sections.append(f'<section data-panel="{i}" '+('' if i==0 else 'hidden')+f'><p class="focus">{FOCUS[i]}</p><a href="sample-{i+1}.png" target="_blank"><img src="sample-{i+1}.png" alt="球形{i+1}：五条原轨迹由易到难排序，含杆速打点与理由"></a><details><summary>查看可复制的参数与理由</summary><div class="scroll"><table><tr><th>新排</th><th>原路线</th><th>杆速</th><th>打点</th><th>库数</th><th>排序理由</th></tr>'+''.join(rows)+f'</table></div><p>题目标识：{s["id"]} / B{s["candidate"]["cellID"]}</p></details></section>')
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>5题轨迹击打难度初排</title><style>*{box-sizing:border-box}body{margin:0;background:#f5f5ef;color:#203d38;font:16px/1.7 system-ui,sans-serif}main{max-width:1200px;margin:auto;padding:32px 24px}h1{font-size:32px;margin:0 0 8px}p{margin:8px 0}nav{display:flex;gap:8px;flex-wrap:wrap;margin:22px 0}button{font:inherit;background:white;color:#203d38;padding:10px 16px;border:1px solid #bdcfc3;border-radius:8px;cursor:pointer}button[aria-pressed=true]{background:#277a69;color:white;border-color:#277a69}img{display:block;width:100%;height:auto;border-radius:8px}.focus{padding:14px 18px;background:#ece4d6;color:#775229;border-radius:8px}details{margin:16px 0;padding:12px;background:white}table{border-collapse:collapse;width:100%;white-space:nowrap}td,th{text-align:left;padding:12px;border-bottom:1px solid #dce3da}td:last-child{white-space:normal;min-width:280px}.scroll{overflow:auto}.muted{color:#5e716b}a{color:#277a69}@media(max-width:600px){main{padding:20px 12px}h1{font-size:25px}button{font-size:14px;padding:8px}}</style><main><h1>哪条路线更容易打出来？</h1><p>5道代表题，保留全部25条现有路线。新排名从容易到困难，原路线编号保留。</p><p class="muted">这轮是基于现有执行难度模型的初排，不是容错成功率；原题库、杆速、打点和轨迹均未修改。</p><nav>'''+nav+'</nav>'+''.join(sections)+'''<details><summary>初排规则与边界</summary><p>指标 = 2.5 × |左右打点| + |高低打点| + 0.25 × max(0, 杆速 − 4)。采用项目现有 DifficultyModel.executionEffort；越小越容易，同分保留原顺序。</p><p>同题的基础球形不变，第二杆舒适度和库数不并入指标。高低杆暂按相同幅度同权，低速精细控力、出杆空间、轨迹与落点容错均未测。因此相近名次尤其适合人工校准，不能将差值解读为实测能力差距。</p><p>从过滤库每10个分片取1个，查看1306初始布局，按五类对比条件挑选不同布局；不是随机分布样本，也没有寻找现有五条之外的新解。</p><p>打点是接触偏移/球半径R；正X为左塞、正Y为高杆。小盘红点沿用App朝向。彩线来自原生模拟的2mm误差关键点，不是重新生成的示意轨迹。</p><p><a href="overview.png" target="_blank">五题总览图</a> · <a href="data.json">原始参数与来源</a></p></details></main><script>function choose(n){document.querySelectorAll('[data-panel]').forEach(x=>x.hidden=x.dataset.panel!==String(n));document.querySelectorAll('[data-n]').forEach(x=>x.setAttribute('aria-pressed',x.dataset.n===String(n)));history.replaceState(null,'','#'+(Number(n)+1))}document.querySelectorAll('[data-n]').forEach(x=>x.addEventListener('click',()=>choose(x.dataset.n)));const n=Number(location.hash.slice(1))-1;if(n>=0&&n<5)choose(n);</script></html>'''
    (OUT/'index.html').write_text(page)
    print('rendered',len(files),'detail images + overview + HTML')

if __name__=='__main__':main()
