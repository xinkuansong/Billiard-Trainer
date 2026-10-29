"""Five-column, 100-question contact sheet for the fixed random sample."""
from pathlib import Path


def transform(page):
    page=page.replace('<title>K球 · 全库筛选</title>','<title>K球 · 随机100题 · 5列图册</title>')
    page=page.replace('随机100题 · 分布预览','随机100题 · 每行5题 / 每页20行')
    page=page.replace('Math.ceil(data.total/6)','Math.ceil(data.total/100)').replace('(page+1)*6>=data.total','(page+1)*100>=data.total')
    page=page.replace('<section class="panel"><p><b>','<details class="panel"><summary>筛选规则与抽样说明</summary><p><b>',1)
    page=page.replace('</section>\n<section class="panel"><h2>样本与全库分布</h2>','</details>\n<details class="panel"><summary>样本与全库分布</summary>',1)
    page=page.replace('</section><section class="panel"><div class="filters">','</details><section class="panel"><div class="filters">',1)
    # Preserve existing metadata, collapse it below the thumbnail for scanning.
    page=page.replace('<p class="meta">${esc(s.routeKey)}','${drawing(s)}<details class="metadata"><summary>参数与来源</summary><p class="meta">${esc(s.routeKey)}')
    page=page.replace('${drawing(s)}<p>杆速','<p>杆速')
    page=page.replace('查看这条路线的保留题</a></article>','查看这条路线的保留题</a></details></article>')
    css='''
main{max-width:none;min-width:1000px;padding:18px 18px 45px;box-sizing:border-box}h1{font-size:26px;margin:12px 0}main>p{margin:8px 0}.panel{padding:12px 16px;margin:12px 0}.panel summary{cursor:pointer;font-weight:600;padding:6px 0}.filters{gap:12px}.filters label{font-size:13px}select,input,button{padding:6px 10px}.pager{gap:12px}#count{min-height:0;margin:10px 0}#cards{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:12px;align-items:start}#cards article{min-width:0;margin:0;padding:9px;border-radius:9px}#cards h2{font-size:14px;line-height:1.55;margin:0 0 5px}#cards svg{width:100%;height:auto}#cards .metadata{font-size:12px;overflow-wrap:anywhere}#cards .metadata summary{cursor:pointer;color:#9bb4bc;padding:6px 0}#cards .metadata p{font-size:12px;margin:6px 0}#cards article:target{outline:2px solid #80d8ee}
'''
    return page.replace('</style>',css+'</style>')


if __name__=='__main__':
    out=Path(__file__).resolve().parents[2]/'output/k-ball-random100-20261029'
    original=out/'index-six-per-page.html'
    if not original.exists():original.write_bytes((out/'index.html').read_bytes())
    (out/'index.html').write_text(transform(original.read_text()))
