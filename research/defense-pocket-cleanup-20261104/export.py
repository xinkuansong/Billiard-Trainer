from pathlib import Path
import csv,gzip,hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'output/defense-approved-filter-20261104';OUT=ROOT/'output/defense-pocket-cleanup-20261104'
read=lambda p:json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
key=lambda q:f"{q['bank']}|{q['sourceID']}|{q['own']}"
decisions={q['key']:q for q in read(OUT/'decisions.json')}
assert read(OUT/'score-audit.json')['passed']
oldSamples=read(ROOT/'output/defense-random-review-20261104/samples.json')
for q in oldSamples:
    if q['sampleID'] in ['R01-02','R01-03','R01-05','R01-18']:assert decisions[key(q)]['remove'],q['sampleID']
assert not decisions[key(oldSamples[0])]['remove']
folder=OUT/'catalogs';folder.mkdir(exist_ok=True)
summary=read(BASE/'catalog-summary.json');counts={};removed={};sources={};removedRecords=[]
for kind,previous in summary['uniqueRoleCounts'].items():
    path=BASE/'catalogs'/f'{kind}.jsonl.gz';sources[str(path.relative_to(ROOT))]=sha(path)
    with gzip.open(path,'rt') as f:rows=[json.loads(line) for line in f]
    kept=[q for q in rows if not decisions[key(q)]['remove']]
    dropped=[q for q in rows if decisions[key(q)]['remove']]
    assert len(kept)+len(dropped)==previous
    counts[kind]=len(kept);removed[kind]=len(dropped)
    removedRecords.extend(dict(kind=kind,formationID=q['formationID'],sourceID=q['sourceID'],own=q['own'],witnesses=decisions[key(q)]['witnesses']) for q in dropped)
    with gzip.open(folder/f'{kind}.jsonl.gz','wt') as f:
        for q in kept:f.write(json.dumps(q,ensure_ascii=False,separators=(',',':'))+'\n')
    ids={q['formationID'] for q in kept}
    with (BASE/'catalogs'/f'{kind}.csv').open(encoding='utf-8-sig',newline='') as source,(folder/f'{kind}.csv').open('w',encoding='utf-8-sig',newline='') as dest:
        reader=csv.DictReader(source);writer=csv.DictWriter(dest,fieldnames=reader.fieldnames);writer.writeheader();n=0
        for row in reader:
            if row['formationID'] in ids:writer.writerow(row);n+=1
        assert n==len(kept)
    with gzip.open(folder/f'{kind}.jsonl.gz','rt') as f:assert [json.loads(line) for line in f]==kept
report=dict(passed=True,previousRoleCounts=summary['uniqueRoleCounts'],uniqueRoleCounts=counts,removedRoleCounts=removed,total=sum(counts.values()),removedTotal=sum(removed.values()),sourceCatalogs=sources,scoreThresholdsUnchanged=True,rule='Unrepresented alternative corner pocket, clear of other balls with in-table ghost, has smaller pocket-centre cut, shorter pocket-centre pot distance, and production comfort above existing maximum; remove entire candidate as pocket-selection ambiguous. Middle-pocket no-window regions stay excluded from alternate-pocket checks.',notPotFeasibilityProof=True)
(OUT/'catalog-summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
(OUT/'removed.json').write_text(json.dumps(removedRecords,ensure_ascii=False,separators=(',',':')))
(OUT/'sample-dispositions.json').write_text(json.dumps([dict(sampleID=q['sampleID'],removed=decisions[key(q)]['remove'],witnesses=decisions[key(q)]['witnesses']) for q in oldSamples],ensure_ascii=False,indent=2))
(OUT/'geometry.json').write_bytes((BASE/'geometry.json').read_bytes())
(OUT/'protocol.json').write_text(json.dumps(dict(parent=str(BASE.relative_to(ROOT)),widthUpperInclusive=.008,comfortUpperExclusive=10,additionalExclusion=report['rule'],sourceHashes=sources,swiftSHA256=sha(Path(__file__).parent/'main.swift')),indent=2))
text=['# 防守候选库：剔除选袋存疑球形','', '依据用户标出的R01-02/03/05/18，删除整类“较顺手角袋未纳入评估，改用另一极薄路线算难题”的候选。','', '| 类型 | 原数量 | 删除 | 保留 |','|---|---:|---:|---:|']
for k in counts:text.append(f'| {k} | {summary["uniqueRoleCounts"][k]} | {removed[k]} | {counts[k]} |')
text+=['','原0.008°/舒适分<10门槛不变。新增的是保守排错条件：另一个未有直进窗口的角袋，袋心路线切角更小、目标球行程更短、正式舒适分高于原六袋最高分；其假想球须在台内，两段路线不能被其他球遮挡。三条件同时成立才剔除。','', '袋心方向仅作排错探针，不宣称可碰jaw进袋，不修复/改变干净进袋算法，也不改画成未经验证的替代路线。中袋无窗口的不可进区域不作为替代袋口，保留此前中袋讨论边界。防守打法未验证。','', '原候选文件保留作来源证据；本目录catalogs为剔除后的新版，球位/球号/原指标不改。removed.json保留删除依据，sample-dispositions.json记录原80题去留。review/review.html保留未删样题，替补21号起，仍每类20题/每行5个。']
(OUT/'README.md').write_text('\n'.join(text)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
