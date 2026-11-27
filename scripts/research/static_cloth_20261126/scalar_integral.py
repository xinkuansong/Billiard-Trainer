#!/usr/bin/env python3
"""Research candidate: factor the shared lamp colour out of full integrals.

No sample reduction, new approximation, cache, or product installation.
Floating point reassociation is measured against the frozen original.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
source = (ROOT / "output/render-regression-20261126/phone.surface").read_text()
expected = "ca7cae37f1722967d73caa13f64676f8fe8ce3109303934cae22e8fa03878b04"
assert hashlib.sha256(source.encode()).hexdigest() == expected
start = source.index("__attribute__((noinline)) ClothIntegral clothLTCIntegral")
end = source.index("#pragma arguments\ntexture2d<float> bedRailVisibility;", start)
original = source[start:end]
body = original

def replace(old, new, count):
    global body
    assert body.count(old) == count, (old, body.count(old))
    body = body.replace(old, new)

replace("float3 E=0,unoccludedE=0,S=0;", "float E=0,unoccludedE=0,S=0;", 2)
replace("E=float3(1.0);unoccludedE=float3(1.0);", "E=1.0;unoccludedE=1.0;", 1)
replace("float3 weighted=float3(1,0.985,0.96)*", "float weighted=", 2)
replace("S=float3(1,0.985,0.96)*", "S=", 1)
replace("S+=float3(1,0.985,0.96)*", "S+=", 1)
replace("return {E,unoccludedE,S};",
        "return {float3(1,0.985,0.96)*E,float3(1,0.985,0.96)*unoccludedE,float3(1,0.985,0.96)*S};", 2)
candidate = source[:start] + body + source[end:]
out = ROOT / "output/static-cloth-20261126/main-integral"
out.mkdir(parents=True, exist_ok=True)
path = out / "scalar-colour.surface"
path.write_text(candidate)
metadata = {"inputSHA256": expected,
            "outputSHA256": hashlib.sha256(candidate.encode()).hexdigest(),
            "scope": "Factor shared lamp colour out of original 64/8 integrals; retain original sample and ball order, all visibility, BRDF and LTC eligibility.",
            "risk": "Floating point reassociation, compiler register and scheduling effects; not assumed bit-identical or faster.",
            "newResources": 0, "newUploads": 0}
path.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n")
print(json.dumps(metadata))
