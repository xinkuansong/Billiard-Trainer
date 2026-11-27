#!/usr/bin/env python3
"""Checksum-bound research transforms; never changes the shipping generator."""
import argparse
import hashlib
import json
from pathlib import Path

INPUT_SHA = "ca7cae37f1722967d73caa13f64676f8fe8ce3109303934cae22e8fa03878b04"
FIELD = "E=temporalFieldDiffuse(p,n,temporalField0,temporalField1)*(E/max(unoccludedE,float3(0.000001)));"


def once(source, anchor, replacement):
    if source.count(anchor) != 1:
        raise ValueError(f"Drifted anchor: {anchor[:80]}")
    return source.replace(anchor, replacement)


def layered(source):
    # Preserve operations, precision, parenthesization and ordering of C1/H9/LTC.
    source = once(source, FIELD, """// S: fixed-light field evaluated with current M normal.
    float3 clothStaticIrradiance=temporalFieldDiffuse(p,n,temporalField0,temporalField1);
    // D: two lamps retain their original directional weights and normalization.
    float3 clothDiffuseVisibility=E/max(unoccludedE,float3(0.000001));
    E=clothStaticIrradiance*clothDiffuseVisibility;""")
    source = once(source, "_surface.emission.rgb = (_surface.diffuse.rgb * _surface.multiply.rgb)",
                  """// M: current filtered texture colour; V: nap and S remain view-dependent.
    float3 clothAlbedo=(_surface.diffuse.rgb * _surface.multiply.rgb);
    // C: preserve the original composition, including dynamic railDark below.
    _surface.emission.rgb = clothAlbedo""")
    return source


def bed_fast_domain(source):
    source = layered(source)
    # Fixed lamps: x in [-2.54,2.54], z in [-1.27,1.27], y=3.
    # A strict sufficient condition only; uncertain cases retain all corner tests.
    anchor = " if(!all(isfinite(p)) || p.x<-1.6 || p.x>1.6 || p.z<-0.95 || p.z>0.95 || p.y<0.65 || p.y>0.9) return false;"
    return once(source, anchor, anchor + "\n if(n.y*(3.0-p.y)>abs(n.x)*(2.54+abs(p.x))+abs(n.z)*(1.27+abs(p.z))+0.00001) return true;")


def rail_reuse(source, reuse=True):
    source = layered(source)
    start = "    float3 railSoftNormal=normalize(n+float3(0,0.18,0));"
    end = "    _surface.emission.rgb+=(_surface.diffuse.rgb*_surface.multiply.rgb)*railSoftE*(0.25/3.14159265)*railLip;"
    source = once(source, start, "    if(railLip>0.0) {\n" + start)
    if reuse:
        source = once(source,
            "float3 railSoftE=max(v62PanelDiffuse(p,railSoftNormal)-v62PanelDiffuse(p,n),float3(0.0));",
            """// Only the analytic fallback is identical to the base integral here.
    float3 railBaseE=temporalFieldEligible(p,n) ? v62PanelDiffuse(p,n) : clothStaticIrradiance;
    float3 railSoftE=max(v62PanelDiffuse(p,railSoftNormal)-railBaseE,float3(0.0));""")
    return once(source, end, end + "\n    }")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--variant", choices=["B1","B2","B3","B3-guard"], default="B1")
    args = parser.parse_args()
    source = args.source.read_text()
    if hashlib.sha256(source.encode()).hexdigest() != INPUT_SHA:
        raise ValueError("Unknown baseline or candidate double-application")
    result = {"B1":layered,"B2":bed_fast_domain,"B3":rail_reuse,
              "B3-guard":lambda s:rail_reuse(s,reuse=False)}[args.variant](source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(result)
    args.output.with_suffix(".json").write_text(json.dumps({
        "variant": args.variant, "inputSHA256": INPUT_SHA,
        "outputSHA256": hashlib.sha256(result.encode()).hexdigest(),
        "scope": "research only; same resources, normals, samples, precision and dynamic composition",
    }, indent=2)+"\n")


if __name__ == "__main__":
    main()
