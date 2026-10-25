#!/usr/bin/env python3
"""Build an independent second-round review from the original 1000 samples."""
import hashlib
import json
from pathlib import Path
from analyze_pocket_filter_feedback import score, candidates

ROOT = Path(__file__).resolve().parents[2]


def main():
    base=ROOT/'output/two-ball-pocket-filter-20261024'
    old=base/'review-1000'
    data=json.loads((old/'samples.json').read_text())
    raw=(old/'feedback.json').read_bytes()
    feedback=json.loads(raw)
    assert feedback['sourceSHA256']==data['sourceSHA256']
    assert feedback['thresholds']==data['thresholds']
    assert feedback['meaning']=='agreement_with_filter_verdict'
    counts={'keep':0,'drop':0};conflicts=[]
    for s in data['samples']:
        s['previousStatus']=s['status']
        for m in s['metrics']:
            m['score']=score(m) if m['cut_degrees']<90 else None
        a=s['metrics'][s['original']['pocket']]
        s['original']=a
        ranked=sorted(candidates(s),key=lambda m:(m['score'],m['pocket']))
        s['bestOtherPocket']=ranked[0]['pocket'] if ranked else None
        s['alternatives']=[m for m in ranked if m['score']<=a['score']*.7]
        s['status']='drop' if s['alternatives'] else 'keep'
        s['previousFeedback']=feedback['records'].get(s['id'])
        prior=s['previousFeedback']
        if prior:
            assert prior['algorithmStatus']==s['previousStatus'] and prior['number']==s['number']
        s['newConflict']=bool(prior and prior['agrees'] and prior['expectedStatus']!=s['status'])
        if s['newConflict']:conflicts.append(s['number'])
        counts[s['status']]+=1
        assert a['cut_degrees']<90
    data.update(reviewId='pocket-score-r2-30pct-20261024', counts=counts,
                thresholds={'score_ratio_max':.7,'score_definition':'distance_metres/cos(cut_degrees)'},
                conflictNumbers=conflicts,previousFeedbackSHA256=hashlib.sha256(raw).hexdigest())
    out=base/'review-r2-30pct'
    out.mkdir(exist_ok=False)
    (out/'previous-feedback-snapshot.json').write_bytes(raw)
    (out/'samples.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    template=Path(__file__).with_name('pocket_filter_review_r2.html').read_text()
    assert template.count('__PAYLOAD__')==1
    (out/'index.html').write_text(template.replace('__PAYLOAD__',json.dumps(data,ensure_ascii=False,separators=(',',':'))))
    verification=dict(counts=counts,conflicts=conflicts,reviewedPrior=len(feedback['records']),
                      previousFeedbackUnchanged=(old/'feedback.json').read_bytes()==raw,
                      bankUnchanged=hashlib.sha256((ROOT/'QiuJi/Resources/training-grid-bank.json').read_bytes()).hexdigest()==data['sourceSHA256'])
    (out/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(verification,ensure_ascii=False))


if __name__=='__main__':main()
