#!/usr/bin/env python3
"""Compile the independent image auditor in a managed workspace."""
import os
from pathlib import Path
import subprocess
import sys

work = Path(os.environ["QIUJI_TEST_WORK"])
evidence = Path(os.environ["QIUJI_TEST_EVIDENCE"])
binary = work / "image-audit"
command = ["xcrun", "swiftc", "-O", "-module-cache-path", str(work/"module-cache"),
           str(Path(__file__).with_name("image_audit.swift")), "-o", str(binary)]
with (evidence/"compile.log").open("wb") as stream:
    subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, check=True)
subprocess.run([str(binary), sys.argv[1]], check=True)
