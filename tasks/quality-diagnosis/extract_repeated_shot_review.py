#!/usr/bin/env python3
"""Extract bounded per-cycle video samples for human review; never assigns pass."""
import bisect
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[2]
name = 'formal-004-repeated-shot-001'
obs = repo / 'build/quality-diagnosis/observations' / name
run = repo / 'build/quality-diagnosis' / name
meta = json.loads((obs / 'observation.json').read_text())
assert meta['recorderExit'] == meta['runnerExit'] == 0
movie = obs / 'continuous.mp4'
probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries',
    'format=duration,start_time,size:stream=width,height,nb_frames', '-of', 'json', str(movie)]))
assert (probe['streams'][0]['width'], probe['streams'][0]['height']) == (1206, 2622)
frames = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
    '-show_entries', 'frame=best_effort_timestamp_time', '-of', 'json', str(movie)]))
pts = [float(f['best_effort_timestamp_time']) for f in frames['frames'] if 'best_effort_timestamp_time' in f]
report = json.loads(next((run / 'screenshots').glob('*ten-operation-cycles-completed-video-verdicts-required.json')).read_text())
assert len(report['samples']) == 10
out = obs / 'review-frames-002'
out.mkdir()
(out / 'extractor-source.py').write_bytes(Path(__file__).read_bytes())
jobs = []
for sample in report['samples']:
    i = sample['iteration']
    times = [('SHOT', sample['shotTapUptime'] + delta) for delta in [-0.3, 0.8, 1.8, 3.2, 5, 6.8]]
    times += [('REPLAY', sample['replayTapUptime'] + delta) for delta in [-0.3, 0.8, 2.5, 4.5, 6.8]]
    times += [('RESET', sample['redoEndObservedUptime'] - 0.2)]
    for j, (stage, uptime) in enumerate(times):
        requested = uptime - meta['recordingConfirmedMonotonic']
        assert 0 <= requested < float(probe['format']['duration'])
        k = bisect.bisect_left(pts, requested)
        selected = pts[k]
        jobs.append({'cycle': i, 'cell': j, 'stage': stage, 'requestedPTS': requested,
                     'selectedSourcePTS': selected, 'sourceFrameIndex': k,
                     'file': f'cycle-{i:02d}-{j:02d}.png', 'verdict': 'pending-human-review'})

def extract(job):
    # Crop observed board bounds only; original full-screen movie remains untouched.
    # This host ffmpeg lacks drawtext. Cell identity/PTS is kept in the manifest.
    filters = 'crop=930:1680:140:520,scale=320:-1,pad=iw+4:ih+4:2:2:color=white'
    subprocess.run(['ffmpeg', '-v', 'error', '-ss', str(job['selectedSourcePTS']), '-i', str(movie),
                    '-frames:v', '1', '-vf', filters, '-threads', '1', str(out / job['file'])], check=True)

with ThreadPoolExecutor(max_workers=3) as pool:
    list(pool.map(extract, jobs))
for i in range(1, 11):
    subprocess.run(['ffmpeg', '-v', 'error', '-framerate', '1', '-i', str(out / f'cycle-{i:02d}-%02d.png'),
                    '-vf', 'tile=4x3', '-frames:v', '1', '-threads', '1', str(out / f'cycle-{i:02d}-contact.png')], check=True)
manifest = {'videoSHA256': hashlib.sha256(movie.read_bytes()).hexdigest(), 'probe': probe,
            'contactOrder': 'Row-major cells 0-5 SHOT, 6-10 REPLAY, 11 RESET; exact PTS in frames.',
            'alignment': 'Host monotonic clock minus first-frame confirmation; small confirmation latency remains. PTS selected from ffprobe frame list.',
            'scope': 'Six shot, five replay, one reset sample per cycle; not every video frame or full physics correctness.',
            'humanVerdict': 'pending', 'frames': jobs}
(out / 'manifest.json').write_text(json.dumps(manifest, indent=2))
print(json.dumps({'frames': len(jobs), 'contacts': 10, 'output': str(out)}))
