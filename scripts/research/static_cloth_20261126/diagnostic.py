#!/usr/bin/env python3
"""Destructive OFFSCREEN cost probes, never shipping quality candidates."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
source = (ROOT / "output/render-regression-20261126/phone.surface").read_text()
expected = "ca7cae37f1722967d73caa13f64676f8fe8ce3109303934cae22e8fa03878b04"
assert hashlib.sha256(source.encode()).hexdigest() == expected


def replace_count(text, old, new, count):
    assert text.count(old) == count, "Diagnostic source drift"
    return text.replace(old, new)


def remove_ray_visibility(text):
    anchor = "   if(nearLampMasks[panel]!=0u) {"
    assert text.count(anchor) == 2
    for _ in range(2):
        start = text.index(anchor)
        opening = text.index("{", start)
        depth, end = 1, opening + 1
        while depth:
            if text[end] == "{": depth += 1
            elif text[end] == "}": depth -= 1
            end += 1
        removed = text[start:end]
        assert "visibility *=" in removed and "remainingShadowBalls" in removed
        text = text[:start] + "   // OFFSCREEN DIAGNOSTIC: ray visibility forced to one.\n" + text[end:]
    return text


variants = {
    "no-integrated-specular": replace_count(source, "return {E,unoccludedE,S};",
        "return {E,unoccludedE,float3(0.0)};", 2),
    "no-direct-ball-visibility": remove_ray_visibility(source),
    "no-contact-ao": replace_count(source, "_surface.ambientOcclusion = contactVisibility;",
        "_surface.ambientOcclusion = 1.0;", 1),
    "bypass-integral": replace_count(source, "E=result.E;unoccludedE=result.unoccludedE;S=result.S;",
        "E=float3(1.0);unoccludedE=float3(1.0);S=float3(0.0);", 2),
}
for call in [
    "ClothIntegral result=clothLTCIntegral(p,n,v,nv,_surface.roughness,nearLampMasks,contactUniforms,h18Table0,h18Table1);",
    "ClothIntegral result=clothReferenceIntegral(p,n,v,nv,a2,shadowPossible,nearLampMasks,contactUniforms);",
]:
    variants["bypass-integral"] = replace_count(variants["bypass-integral"], call, "", 1)
out = ROOT / "output/static-cloth-20261126/primary-cost"
out.mkdir(parents=True, exist_ok=True)
for name, text in variants.items():
    path = out / (name + ".surface")
    path.write_text(text)
    path.with_suffix(".json").write_text(json.dumps({"probe": name, "inputSHA256": expected,
        "outputSHA256": hashlib.sha256(text.encode()).hexdigest(),
        "scope": "Destructive offscreen cost sensitivity; NOT equivalent quality or releasable savings. Shared work makes probes non-additive.",
        "preserved": "Scene, camera, geometry, resolution, MSAA, ball inputs, 64/8 selection and LTC eligibility"}, indent=2) + "\n")
    print(name, hashlib.sha256(text.encode()).hexdigest())
