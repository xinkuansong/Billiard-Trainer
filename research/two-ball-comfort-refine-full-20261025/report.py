"""Summary only after complete full audit; no partial statistics passed as full."""
import engine as E
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import fontManager
def main():
 s=E.read(E.OUT/'summary.json');assert s['state']=='complete' and s['auditPassed'];t=s['stats']
 fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams['font.family']='Arial Unicode MS';plt.rcParams['axes.unicode_minus']=False
 fig,axs=plt.subplots(1,3,figsize=(17,5));fig.patch.set_facecolor('#f6f8f1')
 x=list(range(10));axs[0].bar([n-.18 for n in x],[t['beforeScoreHistogram'].get(str(n),0) for n in x],width=.36,label='原版');axs[0].bar([n+.18 for n in x],[t['afterScoreHistogram'].get(str(n),0) for n in x],width=.36,label='微调+去重');axs[0].set_xticks(x,[f'{n*10}–{n*10+10}' for n in x],rotation=45);axs[0].set_title('推荐路线舒适度分布');axs[0].legend()
 axs[1].bar(['原版合格','成功修复','未达标保留'],[t['beforeQualified'],t['optimizedQualified'],t['failedKeepOriginal']],color=['#3c8568','#378ca4','#bd8f55']);axs[1].set_title('去重前处理结果')
 hist=t['recommendationCountHistogram'];axs[2].bar(range(6),[hist.get(str(n),0) for n in range(6)]);axs[2].set_title('每道题最终推荐数');axs[2].set_xlabel('0条题目不记作0分')
 fig.suptitle('中袋核验后的原版题库 · 85分最小改动微调（全量审计通过）');fig.tight_layout();fig.savefig(E.OUT/'statistics.png',dpi=140);plt.close(fig)
 text=f'''# 两球舒适度85分全量微调

状态：complete / auditPassed=true。原库和App消费端未修改。

- 输入：{t['layouts']:,}初始布局 / {t['BPositions']:,}第二球位置 / {t['beforeRecommendations']:,}推荐。
- 原版≥85：{t['beforeQualified']:,}；待搜索：{t['lowRecommendations']:,}。
- 搜索达标：{t['optimizedQualified']:,}；未达标保留原推荐：{t['failedKeepOriginal']:,}（均为去重前口径）。
- P2去重后：{t['afterRecommendations']:,}推荐，其中≥85共{t['afterQualified']:,}；有推荐题{t['afterValidB']:,}，有≥85推荐题{t['afterQualifiedB']:,}（原{t['beforeQualifiedB']:,}）。
- P2合并{t['dedupRemoved']:,}条；原版已合格路线损失{t['originalQualifiedDedupRemoved']}。
- 原生新参数模拟{t['newSimulations']:,}次（同布局共用）；原参数重放{t['replaySimulations']:,}次。
- 吃库数量/顺序改变淘汰{t['gridRejects'].get('railStateChanged',0):,}候选-推荐组合（非唯一物理轨迹数）。
- 本次全量运行计算写入{s['computeAndWriteSeconds']/3600:.3f}小时，审计{s['auditSeconds']/60:.2f}分钟；已提交试跑分片跳过，试跑耗时另见pilot-summary.json，不能把断点续跑时间当首次总耗时。
- final gzip {s['finalGzipBytes']/1e9:.3f}GB；refinement gzip {s['refinementGzipBytes']/1e9:.3f}GB。

## 数据使用

final/*.jsonl.gz按布局分行，candidates.top5保存第二球位置下最终推荐，routes由comboIndex关联真实2mm轨迹。推荐comfort内含三分项、总分、球距、离库、切角；refinementStatus区分originalQualified、optimizedQualified、unqualifiedOriginalRetained。原score仍保留旧OP/cos指标，不能当舒适度总分。每道题的分数为保留推荐comfort.totalScore最大值；空推荐题不计0分。

refinement/*.jsonl.gz按同布局保存原routes、全部原生扰动候选（可用轨迹2mm）、完整网格索引、每个原推荐的选择/淘汰计数/最佳未达标候选、P2去重前后引用。same参数只存一次，按comboIndex共享；无成功轨迹的失败模拟保留原失败事件/原因，不编造轨迹。未达标原路线可能因与更优保留路线P2≥60而合并，原数据与选择过程仍完整可追溯。

## 冻结规则

速度±0.3步0.1、高低±0.15步0.05、左右±0.10步0.05，最多245点，杆速0.6–4.5/打点圆盘0.5。同第二球与袋口；吃库数量和顺序必须保持，改变直接淘汰不评分；无库去侧塞规则核查原库为0违规，候选无库非零侧塞直接拒绝。首球进指定袋/不自杀/不碰袋角/2mm路径碰B检查沿用既有程序。

球距放缓版/空间最新版/15°内满分、之后30°尺度衰减的角度分；三项等权几何平均。未舍入≥85达标，不再施加18°硬限制。达标后选归一化参数扰动平方和最小，平局先少侧塞、再高分；未达标不自动用最高分替换原路线。P2≥60去重，原版合格优先，其次优化达标，再次原版低分；各组按原顺序。保留≤5条。

完整SHA、冻结源、恢复与审计信息见manifest.json、parts-index.json、summary.json；资源收尾另见cleanup.json/closure.json。最终切角>18°有{t['afterCutAbove18']:,}条，是综合评分策略允许的结果，不表示每个分项均≥85。历史网格18°版不作为本次输入。
'''
 (E.OUT/'README.md').write_text(text)
if __name__=='__main__':main()
