#!/usr/bin/env python3
"""Verify media dimensions, timing and matching production geometry ledgers."""
import argparse
import hashlib
import json
import math
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('output', type=Path)
args = parser.parse_args()
out = args.output.resolve()
resolutions = {'4k': (2160, 3840), '2k': (1440, 2560), '1k': (1080, 1920)}
ledgers = {m: json.loads((out / f'{m}-frames.json').read_text()) for m in ('2d', '3d')}
checks = {}
for mode, rows in ledgers.items():
    assert len(rows) == 900, (mode, len(rows))
    min_diameter = float('inf')
    max_error = 0
    initial_camera = rows[0]['projection']['cameraPosition']
    for index, row in enumerate(rows):
        assert row['frame'] == index
        assert abs(row['time'] - index/60) < 1e-9
        expected = max(0, min(89, (index/60-1)*89/12))
        error = abs(row['measuredDegrees'] - expected)
        max_error = max(max_error, error)
        assert error <= .01, (mode, index, error)
        assert row['projection']['cameraPosition'] == initial_camera
        for ball in ('cue', 'target'):
            min_diameter = min(min_diameter, row['projection'][ball]['diameter4K']/2)
    assert min_diameter >= 28
    checks[mode] = {'frameCount': len(rows), 'maxAngleErrorDegrees': max_error,
                    'minProjectedBallDiameter1080': min_diameter,
                    'cameraPosition': initial_camera}
max_position_difference = 0
for a, b in zip(ledgers['2d'], ledgers['3d']):
    for name in ('cue', 'target', 'aim'):
        delta = math.dist(a[name], b[name])
        assert delta <= .0001
        max_position_difference = max(max_position_difference, delta)
    assert abs(a['measuredDegrees'] - b['measuredDegrees']) <= .01
checks['maxCrossModePositionDifferenceMeters'] = max_position_difference
media = []
for mode in ('2d', '3d'):
    for tier, dimensions in resolutions.items():
        path = out / f'angle-aiming-{mode}-{tier}.mp4'
        probe = json.loads(subprocess.check_output([
            'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)
        ], text=True))
        streams = probe['streams']
        assert len(streams) == 1 and streams[0]['codec_type'] == 'video'
        stream = streams[0]
        assert (stream['width'], stream['height']) == dimensions
        assert stream['codec_name'] == 'h264'
        assert stream['avg_frame_rate'] == '60/1'
        assert int(stream['nb_frames']) == 900
        assert abs(float(stream['duration']) - 15) <= .02
        media.append({'file': path.name, 'sizeBytes': path.stat().st_size,
                      'width': stream['width'], 'height': stream['height'],
                      'fps': stream['avg_frame_rate'], 'frames': int(stream['nb_frames']),
                      'durationSeconds': float(stream['duration']), 'codec': stream['codec_name'],
                      'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
report = {'passed': True, 'checks': checks, 'media': media}
(out / 'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(report, ensure_ascii=False, indent=2))
