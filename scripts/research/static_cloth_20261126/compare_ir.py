#!/usr/bin/env python3
"""Compare optimized Metal IR for the complete surface operation, not SceneKit's final pipeline."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def wrapper(source):
    declarations, body = source.split("#pragma body\n")
    declarations = re.sub(r"^#pragma .*\n", "", declarations, flags=re.M)
    declarations = re.sub(r"^texture\w+<float> \w+;\n", "", declarations, flags=re.M)
    declarations = declarations.replace("QiuJiContactUniforms contactUniforms;\n", "")
    fields = set(re.findall(r"_surface\.(\w+)",body))
    expected = {"position","normal","geometryNormal","roughness","ambientOcclusion","diffuse","multiply","emission","metalness"}
    if fields != expected:
        raise ValueError(f"Surface contract drift: {fields}")
    return """#include <metal_stdlib>
using namespace metal;
struct Surface { float3 position,normal,geometryNormal; float roughness,ambientOcclusion,metalness; float4 diffuse,multiply,emission; };
struct Frame { float4x4 inverseViewTransform; };
"""+declarations+"""
kernel void surfaceStudy(const device Surface *inputs [[buffer(0)]], device Surface *outputs [[buffer(1)]],
constant Frame &scn_frame [[buffer(2)]], constant QiuJiContactUniforms &contactUniforms [[buffer(3)]],
texture2d<float> h18Table0 [[texture(0)]],texture2d<float> h18Table1 [[texture(1)]],
texture3d<float> temporalField0 [[texture(2)]],texture3d<float> temporalField1 [[texture(3)]],
texture2d<float> bakedRailAO [[texture(4)]],texture2d<float> bedRailVisibility [[texture(5)]],uint index [[thread_position_in_grid]]) {
Surface _surface=inputs[index];
"""+body+"\noutputs[index]=_surface;\n}\n"


def main():
    work, evidence = Path(os.environ["QIUJI_TEST_WORK"]), Path(os.environ["QIUJI_TEST_EVIDENCE"])
    generated = work / "surface.metal"
    reports = []
    for label, path in zip(("A","B"), map(Path,sys.argv[1:3])):
        source = path.read_text()
        wrapped = source if "--captured" in sys.argv else wrapper(source)
        generated.write_text(wrapped)
        (evidence/(label+".metal")).write_text(wrapped)
        command = ["xcrun","-sdk","macosx","metal","-O3","-std=metal3.1","-S","-emit-llvm",str(generated),"-o",str(evidence/(label+".ll"))]
        if "--captured" in sys.argv:
            command += ["-D"+macro for macro in ["USE_SHADER_MODIFIERS","USE_SURFACE_MODIFIER","USE_FRAGMENT_MODIFIER",
                "USE_SURFACE_EXTRA_DECL","USE_FRAGMENT_EXTRA_ARGUMENTS","USE_PBR","USE_NORMAL=2","USE_POSITION=2","USE_VIEW=2",
                "HAS_NORMAL","HAS_OR_GENERATES_NORMAL","USE_ROUGHNESS_COLOR","USE_DIFFUSE_COLOR","USE_MULTIPLY_COLOR","USE_EMISSION_COLOR","USE_MODELVIEWTRANSFORM",
                "USE_EMISSION","USE_MULTIPLY","USE_DIFFUSE","USE_LIGHTING","USE_PER_PIXEL_LIGHTING","USE_AMBIENT_LIGHTING","C3DLightIndexType=ushort"]]
        with (evidence/(label+".log")).open("wb") as stream:
            subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,check=True)
        ir = (evidence/(label+".ll")).read_text()
        if "clothReferenceIntegral" not in ir or "clothLTCIntegral" not in ir or "air.sample_texture_3d" not in ir:
            raise ValueError("Compiler did not retain the actual cloth runtime branches")
        if "--captured" in sys.argv:
            fragment = re.search(r"^define[^\n]*@commonprofile_frag\([\s\S]*?^}",ir,re.M)
            if not fragment or not all(token in fragment.group() for token in ["clothReferenceIntegral","clothLTCIntegral","temporalFieldDiffuse"]):
                raise ValueError("Cloth shading is not live in the final captured fragment")
        reports.append({"arm":label,"sourceSHA":hashlib.sha256(source.encode()).hexdigest(),"command":command})
    a,b = [(evidence/(label+".ll")).read_bytes() for label in ("A","B")]
    result = {"identicalOptimizedIR":a==b,"A_SHA":hashlib.sha256(a).hexdigest(),"B_SHA":hashlib.sha256(b).hexdigest(),"inputs":reports,
        "scope":("Captured complete SceneKit Metal source; same compiler options and path" if "--captured" in sys.argv else
                 "Complete current surface in a compute wrapper, including all runtime branches; not a SceneKit hardware register-count measurement")}
    (evidence/"ir-comparison.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
