#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[3]
work, evidence = Path(os.environ['QIUJI_TEST_WORK']), Path(os.environ['QIUJI_TEST_EVIDENCE'])
source = Path(__file__).with_suffix('.swift')
shutil.copyfile(source, evidence / source.name)
result = subprocess.run(['xcrun', 'swift', '-suppress-warnings', '-module-cache-path', str(work / 'module-cache'),
    str(source), str(root / 'QiuJi/Resources/ModelTrial20261010_TaiQiuZhuo.usdz'), str(evidence / 'geometry.json')],
    stdout=(evidence / 'geometry.log').open('w'), stderr=subprocess.STDOUT)
raise SystemExit(result.returncode)
