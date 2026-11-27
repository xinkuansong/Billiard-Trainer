"""Compile the production Swift implementation with a read-only initial-position driver."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = Path(os.environ.get("DEFENSE_OPENING_OUTPUT", ROOT / "output" / HERE.name)).resolve()
work = Path(os.environ["QIUJI_TEST_WORK"])
evidence = Path(os.environ["QIUJI_TEST_EVIDENCE"])
manifest = {}
paths = []
for path in sorted((ROOT / "QiuJi").rglob("*.swift")):
    data = path.read_bytes()
    rel = path.relative_to(ROOT)
    manifest[str(rel)] = hashlib.sha256(data).hexdigest()
    if b"@main" in data:
        assert path.name == "QiuJiApp.swift"
        data = data.replace(b"@main", b"// Research entry point")
    dest = work / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    paths.append(str(dest))
sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True).strip()
binary = work / "OpeningChoice"
main = work / "main.swift"
main.write_bytes((HERE / "main.swift").read_bytes())
manifest["driver"] = hashlib.sha256(main.read_bytes()).hexdigest()
with (evidence / "build.log").open("w") as log:
    result = subprocess.run(["xcrun", "swiftc", "-O", "-whole-module-optimization", "-num-threads", "4",
                             "-D", "DEBUG", "-swift-version", "5", "-sdk", sdk, "-target",
                             "arm64-apple-ios17.0-simulator", *paths, str(main), "-lz", "-o", str(binary)],
                            env=dict(os.environ, SDKROOT=sdk), stdout=log, stderr=subprocess.STDOUT)
if result.returncode:
    sys.exit((evidence / "build.log").read_text()[-4000:])
manifest["binary"] = hashlib.sha256(binary.read_bytes()).hexdigest()
(OUT / "native-source.json").write_text(json.dumps(manifest, indent=2))
subprocess.run([sys.executable, str(ROOT / "scripts/simulator_fleet.py"), "run", "--role", os.environ.get("DEFENSE_OPENING_ROLE", "large-phone"),
                "--task", OUT.name, "--", sys.executable, str(HERE / "scan.py"), "{udid}", str(binary)], check=True)
