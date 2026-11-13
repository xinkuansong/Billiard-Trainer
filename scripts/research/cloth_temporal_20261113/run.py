from pathlib import Path
import subprocess
import json
import hashlib

root = Path(__file__).resolve().parents[3]
out = root / 'output/render-activity-20261113/c1-temporal'
rows = []
for pose in ['single-low', 'single-near', 'edge-low', 'rack-overview', 'scatter-overview']:
    fixture = root / 'output/render-lowdim-20261113/pixel-lowk-r3' / pose
    for mode in ['strict', 'fast']:
        destination = out / f'{pose}-{mode}'
        args = [str(out / 'benchmark'), str(out / 'temporal.metal'), str(fixture), str(destination), mode]
        if not destination.exists():
            p = subprocess.run(args, capture_output=True, text=True, timeout=120)
            (out / f'{pose}-{mode}.log').write_text(p.stdout + p.stderr)
            if p.returncode:
                raise RuntimeError(f'{pose} {mode}: exit {p.returncode}; retained log')
        validation = json.loads((destination / 'validation.json').read_text())
        row = {'pose': pose, 'mode': mode, 'command': args,
               'inputsSHA256': hashlib.sha256((fixture / 'samples.bin').read_bytes()).hexdigest(),
               'ballsSHA256': hashlib.sha256((fixture / 'balls.bin').read_bytes()).hexdigest(),
               'validation': validation}
        if mode == 'strict':
            result = json.loads((destination / 'result.json').read_text())
            row['result'] = result
            print(pose, result['comparisons']['steady']['pairedChangePercent'], flush=True)
        rows.append(row)
        (out / 'results.json').write_text(json.dumps(rows, indent=2) + '\n')
