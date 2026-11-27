#!/usr/bin/env python3
"""Research-only current noinline LTC domain test; no production gate changes."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
source = (ROOT / "output/render-regression-20261126/phone.surface").read_text()
expected = "ca7cae37f1722967d73caa13f64676f8fe8ce3109303934cae22e8fa03878b04"
assert hashlib.sha256(source.encode()).hexdigest() == expected
old = "if(clothLTCCloseView && _surface.roughness>=0.4 && shadowPossible){"
assert source.count(old) == 1
candidate = source.replace(old, "if(_surface.roughness>=0.4 && shadowPossible){")
out = ROOT / "output/static-cloth-20261126/main-integral"
out.mkdir(parents=True, exist_ok=True)
path = out / "ltc-domain-research.surface"
path.write_text(candidate)
metadata = {"inputSHA256": expected,
            "outputSHA256": hashlib.sha256(candidate.encode()).hexdigest(),
            "scope": "Offscreen evaluation of final noinline LTC on current P01; existing roughness and shadowPossible eligibility retained. Not production authorisation.",
            "newResources": 0, "newUploads": 0}
path.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n")
print(json.dumps(metadata))
