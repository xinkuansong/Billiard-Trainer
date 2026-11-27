from pathlib import Path
HERE=Path(__file__).resolve().parent;OLD=HERE.parent/'defense-threshold-comparison-20261105'
s=(OLD/'audit.py').read_text().replace('defense-threshold-comparison-20261105',HERE.name)
s=s.replace("out/'F01/geometry.json'","out/'85-01/geometry.json'")
s=s.replace('[70,80,90]','[75,80,85]').replace('70<=','75<=').replace('>=70','>=75').replace('<70','<75').replace('stable(c,70)','stable(c,75)').replace('below-70','below-75').replace('pass-70','pass-75')
s=s.replace("'stratum':case['stratum'],'railGapCM':case['railSurfaceGapMeters']*100,", "'initialMaximum':case['maximum'],")
s=s.replace("r['stratum'],round(r['railGapCM'],1),", "round(r['initialMaximum'],2),")
s=s.replace("assert math.dist(p['finalPositions']['_9'],enemy)<1e-6", "assert math.dist(p['finalPositions']['_9'],enemy)<1e-6\n            assert math.dist(p['finalPositions']['cueBall'],enemy)>=.30-1e-6")
s=s.replace("assert math.dist(r['finalPositions']['_9'],enemy)<1e-6", "assert math.dist(r['finalPositions']['_9'],enemy)<1e-6\n        assert math.dist(r['finalPositions']['cueBall'],enemy)>=.30-1e-6")
s=s.replace("w=c['own']['bestClearDegrees'];", "assert math.dist(c['finalPositions']['cueBall'],enemy)>=.30-1e-6\n        w=c['own']['bestClearDegrees'];")
s=s.replace("q=case['question'];enemy=case['target'];", "assert hashlib.sha256((d/'scan-adaptive.json').read_bytes()).hexdigest()==case['scanSHA256']\n    q=case['question'];enemy=case['target'];")
s=s.replace("'deliberate geometry sample, no population inference'", "'ten selected 85-bin cases, no population inference', 'search stops at first spin tier with robust primary goal 80; 85 is diagnostic only', 'own window nondecline is provisional, not a calibrated comfort threshold'")
(HERE/'audit.py').write_text(s)
