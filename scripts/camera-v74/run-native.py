#!/usr/bin/env python3
"""Run one prepared B3 group against the verified immutable B2 build."""
import json,shlex,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2];base=root/'output/camera-v74'
group,device,attempt=sys.argv[1:4]
sourceJob=sys.argv[4] if len(sys.argv)>4 else 'camera-v74-b2-host-r3'
tests=json.loads((base/'b3-selectors.json').read_text())[group]
name='camera-v74-b3-'+group+'-'+attempt
env=['env','V74_RECORD_VIDEO='+('1' if group=='phone-timing' else '0')]
if group=='reduced':env+=['V74_REDUCE_MOTION_TOOL=/Users/song/simulator-work/camera-v74-tools/reduce-motion']
remote=env+['python3','/Users/song/simulator-work/camera-v74-tools/retry-native.py',
 '/Users/song/simulator-work/queue/jobs/'+sourceJob,
 '/Users/song/simulator-work/'+name,device,*tests]
cmd=['ssh','-S','/tmp/camera-v74-ssh','song@fengchuibuchuifengdeMac-mini.local',shlex.join(remote)]
(base/(name+'-launch.json')).write_text(json.dumps({'command':cmd,'tests':tests},indent=2))
sys.exit(subprocess.run(cmd).returncode)
