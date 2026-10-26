"""Admission contract for the approved 4/5/6/9/15-ball break bank."""
import math, random, statistics

KINDS = (4, 5, 6, 9, 15)
VERSION = 'mean-nearest-finite-table-v1'
THRESHOLD = 1.20

def numbers(n):
    assert n in KINDS
    return list(range(1, n + 1)) if n in (9, 15) else list(range(1, n)) + [9]

def job(meta, n, shard, attempt, epoch):
    rng = random.Random(f'multiball-full-v1/{n}/{shard}/{epoch}/{attempt}')
    return dict(id=f'full-{n:02}-{shard:03}-{epoch:02}-{attempt:07}', n=n,
        seed=str(rng.getrandbits(63)),
        x=rng.uniform(meta['length']/4, meta['length']/2-meta['radius']),
        z=rng.uniform(-meta['width']/2+meta['radius'], meta['width']/2-meta['radius']),
        power=rng.uniform(9.5, 10))

def classify(row, meta, cal):
    inp = row['input']; n = inp['n']; L, W, R = (meta[k] for k in ('length','width','radius'))
    assert 9.5 <= inp['power'] <= 10
    assert L/4 <= inp['x'] <= L/2-R and abs(inp['z']) <= W/2-R
    expected = {'_'+str(i) for i in numbers(n)}
    assert len(row['rack']) == n and {b['number'] for b in row['rack']} == set(numbers(n))
    if row['status'] == 'invalid_input': return 'invalid_input', None
    if row['status'] != 'settled': return 'incomplete', None
    board, potted = row['board'], set(row['pocketed'])
    assert set(board) | potted == expected | {'cueBall'}
    assert not set(board) & potted
    assert bool(row['cueScratched']) == ('cueBall' in potted)
    if potted & expected: return 'target_potted', None
    assert set(board)-{'cueBall'} == expected
    balls = [dict(number=i, x=board['_'+str(i)][0]*L-L/2,
                  z=board['_'+str(i)][1]*L-W/2) for i in numbers(n)]
    assert all(math.isfinite(b[k]) for b in balls for k in ('x','z'))
    ds = [min(math.hypot(a['x']-b['x'], a['z']-b['z']) for b in balls if b is not a) for a in balls]
    if min(ds) < 2*R-1e-5 or any(abs(b['x']) > L/2+R or abs(b['z']) > W/2+R for b in balls):
        return 'invalid_geometry', None
    mean = statistics.mean(ds)
    index = mean/cal['reference'][str(n)]['expectedMeanM']
    base = dict(id=inp['id'], kind='base', n=n, balls=balls,
        index=index, meanNearestCM=mean*100, metricVersion=VERSION,
        cueScratched=row['cueScratched'], power=inp['power'], cueStart=[inp['x'],inp['z']],
        seed=inp['seed'], boardNormalized={k:v for k,v in board.items() if k!='cueBall'},
        input=inp)
    return ('accepted' if index >= THRESHOLD else 'below_threshold'), base

def signature(base):
    return (base['n'], tuple(sorted((b['number'], round(b['x'],6), round(b['z'],6)) for b in base['balls'])))

def verify_base(base, meta, cal):
    """Separate distance-matrix and normalized-coordinate audit of final consumers."""
    n = base['n']; balls = base['balls']; L, W, R = (meta[k] for k in ('length','width','radius'))
    assert len(balls) == n and {b['number'] for b in balls} == set(numbers(n))
    points = [(b['x'],b['z']) for b in balls]
    assert all(math.isfinite(c) for p in points for c in p)
    matrix = [[math.dist(p,q) if i!=j else math.inf for j,q in enumerate(points)] for i,p in enumerate(points)]
    nearest = [min(r) for r in matrix]
    assert min(nearest) >= 2*R-1e-5
    assert all(abs(x)<=L/2+R and abs(z)<=W/2+R for x,z in points)
    score = math.fsum(nearest)/n/cal['reference'][str(n)]['expectedMeanM']
    assert abs(score-base['index']) < 1e-12 and base['index'] >= THRESHOLD
    assert base['metricVersion'] == VERSION and 9.5<=base['power']<=10
    for b in balls:
        v = base['boardNormalized']['_'+str(b['number'])]
        assert abs((b['x']+L/2)/L-v[0]) < 1e-12
        assert abs((b['z']+W/2)/L-v[1]) < 1e-12
    return score
