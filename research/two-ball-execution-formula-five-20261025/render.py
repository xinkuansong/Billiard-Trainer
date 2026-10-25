"""Render the new formula without changing any source route or prior preview."""
from pathlib import Path
import importlib.util,json,html
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/two-ball-execution-formula-five-20261025'
spec=importlib.util.spec_from_file_location('old_preview',ROOT/'research/two-ball-execution-five-20261025/render.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
D=json.loads((OUT/'data.json').read_text())
INK=base.INK;MUTED=base.MUTED;BG=base.BG
REVIEWS=[
 ('排序不变：中杆、轻低杆、深低杆、带塞大力杆依次后排。','我的初步判断：结构较顺；新增力度与路线项没有压过明显的杆法差异。'),
 ('原路线4从旧第3降到新第5：较大力度、两库与深低杆一起加分。','我的保留：新第4/5仅差约1个难度分，不宜把这个先后看成很确定。'),
 ('排序不变：两库少量高杆仍排第一，一库带塞没有仅凭库数占优。','我的初步判断：侧塞与高低杆仍是主要区分，暂未发现明显的排序倒置。'),
 ('原路线3：4.252m/s、三库、走8.30m，从旧第3降到新第5。','我的保留：速度、长度、库数会共同增加分数，要防止对长路线重复重罚。'),
 ('变化最大：无库低杆从旧第5升到新第1；三库大力高杆降到最后。','我的保留：短路线升名次有理由，但低杆压过中杆是否合适，需要重点看图。')
]
NOTES=[
 {2:'中杆项为0；力度与一库短路线只带来较小附加难度。',3:'比中杆多了轻低杆要求；路线略短，仍不足以抵消杆法差异。',5:'深低杆增加杆法分，无库短路线则降低路线分；保持第3。',1:'侧塞、低杆与较高杆速叠加；四项合计明显升高。',4:'侧塞更大、杆速更高，组合项也增加；仍排最后。'},
 {5:'纯高杆、低杆速、单库短路线；四项合计最低。',3:'纯低杆比上一条偏心更大，杆速也更高；保持第2。',1:'虽有侧塞，但杆速低、路程短；从旧第4升到新第3。',2:'较大侧塞使杆法与组合项较高；总分略低于下一条。',4:'深低杆配侧塞，另有3.640m/s和两库；从旧第3降至第5。'},
 {2:'两库和2.11m行程增加路线分；少量高杆仍让总分最低。',1:'少量侧塞配低杆，杆法项明显高于上一条；仍排第2。',5:'路程很短、力度较小，但侧塞与低杆量较大；仍排第3。',3:'右塞量大，叠加两库的侧塞组合项；仍排第4。',4:'侧塞与上一条相近，低杆更深、杆速更高；仍排最后。'},
 {4:'轻低杆、较低杆速；虽有两库，四项合计仍最低。',5:'混合打点提高杆法分，但低杆速、短路线把它推到第2。',2:'纯低杆免去侧塞组合项；4.08m路程使它落到第3。',1:'混合打点较难，但力度与长度均低于下一条；暂排第4。',3:'侧塞小，但力度0.714、路线0.858两项较高；降至第5。'},
 {5:'低杆项0.411；无库、0.83m短路线抵消部分操作负担。',4:'少量高杆，力度较温和；两库路线项占比较大。',2:'中杆项为0，但3.543m/s的力度项使它排到第3。',1:'比新第2的高杆更浅，但速度更高、路程更长；排第4。',3:'高杆量不大，4.371m/s与三库长路线使总分最高。'}
]
KEYS=['stroke','power','route','interaction'];LABELS=['杆法','力度','路线','组合']
def note(s,q):return NOTES[s['number']-1][q['originalRank']]
def draw(s):
 n=s['number'];fig=plt.figure(figsize=(16,20),facecolor=BG)
 fig.text(.04,.968,f'{n:02d}  {s["title"]} · 新公式重排',fontsize=25,color=INK)
 fig.text(.04,.941,'新排 = 本轮公式；旧排 = 上一版击打难度；原路线 = 题库编号。全部由易到难。',fontsize=12,color=MUTED)
 fig.text(.04,.918,REVIEWS[n-1][0],fontsize=12,color='#895C30')
 fig.text(.04,.898,REVIEWS[n-1][1],fontsize=11,color='#895C30')
 for i,q in enumerate(s['newRanking']):
  t=next(t for t in s['routes'] if t['comboIndex']==q['comboIndex'])
  source=next(t for t in s['candidate']['top5'] if t['comboIndex']==q['comboIndex'])
  old=next(t for t in s['ranking'] if t['comboIndex']==q['comboIndex'])
  color=base.COLORS[old['rank']-1] # Keep each trajectory's color identical to the prior images.
  y=.714-i*.154
  fig.add_artist(Rectangle((.03,y-.003),.94,.148,transform=fig.transFigure,fc='white',ec='#DCE3DA',lw=.8,zorder=0))
  base.table(fig.add_axes([.035,y+.005,.425,.133]),s,t,source,color)
  fig.text(.48,y+.122,f'新 {q["rank"]}  ←  旧 {q["previousRank"]}     原路线 {q["originalRank"]}',fontsize=18,color=color)
  fig.text(.48,y+.099,f'{t["velocity"]:.3f} m/s   ·   {t["cueMainRailsAfterContact"]} 库   ·   路长 {q["lengthMeters"]:.2f} m',fontsize=12.5,color=INK)
  fig.text(.48,y+.078,base.stroke(t),fontsize=12,color=INK)
  fig.text(.48,y+.055,f'难度 D = {q["difficulty"]:.1f}    /    合计 E = {q["effort"]:.3f}',fontsize=15,color=INK)
  fig.text(.48,y+.033,'   '.join(f'{label} {q["components"][k]:.3f}' for k,label in zip(KEYS,LABELS)),fontsize=11,color=INK)
  fig.text(.48,y+.011,note(s,q),fontsize=10.2,color=MUTED)
  base.spin(fig.add_axes([.90,y+.077,.052,.056]),t)
 fig.text(.04,.067,'C初始母球 / A第一球 / B第二球；彩线、球位、停点、杆速与打点均沿用旧图，颜色也保持一致。',fontsize=10,color=MUTED)
 fig.text(.04,.050,'四项为对E的可加贡献：杆法 + 力度 + 路线 + 组合 = E；D = 100E/(E+1)，越低越容易，不是失败概率。',fontsize=10,color=MUTED)
 fig.text(.04,.033,'E = 2.5s + 0.8h + 1.2d + 0.8u² + 0.12N + 0.06L + 0.6su + 0.15Ns；u = 杆速/4.5。',fontsize=10,color=MUTED)
 fig.text(.04,.016,'L按首碰后原2mm关键点折线估算；打点单位R。无扰动模拟，第二杆舒适度未计入，旧图与全量题库未改。',fontsize=10,color=MUTED)
 fig.savefig(OUT/f'sample-{n}.png',dpi=135);plt.close(fig)

def main():
 for s in D['samples']:draw(s)
 fig=plt.figure(figsize=(16,13),facecolor=BG)
 fig.text(.04,.955,'同样5题 · 新旧难度排名对照',fontsize=26,color=INK)
 fig.text(.04,.918,'下列顺序均使用“原路线编号”，从易到难；四项贡献和真实轨迹详见分题图。',fontsize=12,color=MUTED)
 for i,s in enumerate(D['samples']):
  y=.75-i*.15
  fig.text(.04,y+.08,f'{i+1:02d}  {s["title"]}',fontsize=17,color=INK)
  fig.text(.04,y+.045,'旧：'+' → '.join(str(q['originalRank']) for q in s['ranking']),fontsize=15,color=MUTED)
  fig.text(.04,y+.008,'新：'+' → '.join(str(q['originalRank']) for q in s['newRanking']),fontsize=15,color='#277A69')
  fig.text(.44,y+.067,REVIEWS[i][0],fontsize=11.5,color=INK)
  fig.text(.44,y+.027,REVIEWS[i][1],fontsize=10.5,color=MUTED)
 fig.text(.04,.035,'自评：第1/3题稳定，第2/4题改善了力度差异，第5题提示短路线优势可能补偿过多低杆难度。',fontsize=12,color='#895C30')
 fig.text(.04,.012,'这是看图后的初步判断，未据此调整任何系数；不是实测成功率或真人难度验证。',fontsize=11,color=MUTED)
 fig.savefig(OUT/'comparison.png',dpi=135);plt.close(fig)
 oldhtml=(ROOT/'output/two-ball-execution-five-20261025/index.html').read_text()
 style=oldhtml.split('<style>',1)[1].split('</style>',1)[0]
 nav=''.join(f'<button data-n="{i}" aria-pressed="{str(i==0).lower()}">{i+1} · {html.escape(s["title"])}</button>' for i,s in enumerate(D['samples']))
 sections=[]
 for i,s in enumerate(D['samples']):
  rows=[]
  for q in s['newRanking']:
   t=next(t for t in s['routes'] if t['comboIndex']==q['comboIndex'])
   vals=[q['rank'],q['previousRank'],q['originalRank'],f'{q["difficulty"]:.1f}',*[f'{q["components"][k]:.3f}' for k in KEYS],f'{q["effort"]:.3f}',f'{t["velocity"]:.3f}',base.stroke(t),t['cueMainRailsAfterContact'],f'{q["lengthMeters"]:.3f}']
   rows.append('<tr>'+''.join(f'<td>{v}</td>' for v in vals)+'</tr>')
  heads=['新排','旧排','原路线','难度D',*LABELS,'合计E','杆速','打点','库数','路长m']
  sections.append(f'<section data-panel="{i}" '+('' if i==0 else 'hidden')+f'><p class="focus">{REVIEWS[i][0]}<br>{REVIEWS[i][1]}</p><a href="sample-{i+1}.png" target="_blank"><img src="sample-{i+1}.png" alt="第{i+1}题新旧排名与四项难度分"></a><details><summary>展开参数与四项分数表</summary><div class="scroll"><table><tr>'+''.join(f'<th>{v}</th>' for v in heads)+'</tr>'+''.join(rows)+'</table></div></details></section>')
 script=oldhtml.split('<script>',1)[1].split('</script>',1)[0]
 page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>五题新公式：分项与新旧排名</title><style>'+style+'</style><main><h1>同样5题，按新公式重新排序</h1><p>四项相加得到E，再转换为难度分D；分数越低越容易。新旧排名与原路线编号分别保留。</p><p class="muted">系数严格沿用刚才提出的公式，未因看图调整。仅对25条旧轨迹重新评分，无扰动模拟，全量题库未改。</p><p><a href="comparison.png" target="_blank">五题总对照图</a> · <a href="../execution-five/" target="_blank">上一版图册</a></p><nav>'+nav+'</nav>'+''.join(sections)+'<details><summary>公式、单位和自评结论</summary><p>E = 2.5s + 0.8h + 1.2d + 0.8u² + 0.12N + 0.06L + 0.6su + 0.15Ns；D=100E/(E+1)。s=|spinX|，h=max(spinY,0)，d=max(-spinY,0)，u=杆速/4.5，N=首碰后库数，L=首碰后路长（米）。</p><p>四项分数是可直接相加的E贡献，不是分别转换的百分制分数。显示值取三位小数，按未舍入E排序，同分保留原题库顺序。L由原2mm关键点折线估算；2mm空间误差并不意味着总路长误差也小于2mm。</p><p>看图初评：第1/3题排序稳定；第2/4题把较大力度或更长路线排后，变化可解释；第5题短路线低杆由末位升到首位，可能是纠正旧模型，也可能是力度和路线项补偿过多，值得重点校准。第2、4题末两名仅约1分差，不应当作确定的能力等级差。现阶段没有依据仅凭图就改权重。</p><p>低速精细控力、具体低杆效果、库上出杆空间和轨迹容差未在本式建模；第二杆舒适度保持独立。</p><p><a href="data.json">冻结参数与新旧评分</a></p></details></main><script>'+script+'</script></html>'
 (OUT/'index.html').write_text(page)
 print('rendered five route sheets and comparison')
if __name__=='__main__':main()
