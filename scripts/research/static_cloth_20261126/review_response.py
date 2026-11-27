#!/usr/bin/env python3
import os,subprocess,sys
from pathlib import Path
w=Path(os.environ['QIUJI_TEST_WORK']);e=Path(os.environ['QIUJI_TEST_EVIDENCE']);binary=w/'review-response'
with (e/'compile.log').open('wb') as log:
 subprocess.run(['xcrun','swiftc','-O','-module-cache-path',str(w/'module-cache'),str(Path(__file__).with_suffix('.swift')),'-o',str(binary)],stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run([str(binary),*sys.argv[1:]],check=True)
