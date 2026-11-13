# Real SceneKit cloth visual study

This isolated macOS SceneKit harness renders the real current USDZ `TaiNi` mesh and material through the production cloth surface shader. It is a visual and input-domain experiment, **not a whole-App acceptance test or a performance benchmark**. No production source is edited.

## Reproduction

Run from repository root:

```sh
python3 scripts/research/cloth_lowdim_20261113/visual_prepare.py --reference output/render-lowdim-20261113/native-reference --out output/render-lowdim-20261113/visual-r2
output/render-lowdim-20261113/visual-r2/render "$PWD" output/render-lowdim-20261113/visual-r2
output/render-lowdim-20261113/visual-r2/render "$PWD" output/render-lowdim-20261113/visual-r2 --diagnostics-only
tools/shot_reconstruction/.venv/bin/python scripts/research/cloth_lowdim_20261113/visual_analyze.py output/render-lowdim-20261113/visual-r2
```

Serialize the renderer with other GPU timing jobs. Preparation/analysis are CPU work. The `native-reference/generator.swift` dependency is the sibling research export of production `MobileReferenceLighting` Swift generation; its SHA is recorded.

## Production boundary

- Current `ModelTrial20261010_TaiQiuZhuo.usdz`, production model root transform, ball/cue removal, uniform scale and rail-derived placement.
- Production `MobileClothAlignment.swift` plus the actual `PocketLeatherMesh.decode` function. Only the `SCNVector3` CGFloat-to-Float bridge changes for macOS. Preserve `.geometry` while replacing `.surface`/`.fragment`. Source determines the measured imported bed Y (~0.794738), then lifts bed and White markings to physical Y=0.8.
- Actual cloth normal/roughness texture bindings retained, UV scale 2 and repeat from `MobileTableRendering`; normal intensity **0.65** and plain multiply sRGB **(.54,.73,.54)** from `MaterialFactory.enhanceClothMaterials(preservesClothResponse:true)`; diffuse exact sRGB `(48,155,32)/255`, metalness=0 before the production shader.
- Actual generated batched `MobileContactOcclusion` prefix, inverse `.85` packing decode used by reflection profile, `MobileRailOcclusion.png`, cloth fiber modulation, analytic helpers, complete production cloth emission and native PBR residual, original 64-near/8-far path, rectangle lights, source RGBE environment, exposure -0.1, HDR with adaptation off, SSAO off, highlight headroom.
- Other table finishes are imported materials rather than every final App override; balls are diagnostic spheres with the exact shadow packed positions; room geometry, ball reflection probes, App lifecycle and UI are absent. The overall scene is therefore not a full-App visual baseline. macOS does not prove identical iOS compiler/color behavior.

## Candidates

K means groups **per lamp**: K2=2x1, K4=2x2, K8=4x2. Generate the same 64 visibility samples per near fragment, accumulate scalar directional moments within fixed groups, and evaluate 4/8/16 total BRDFs. Keep original diffuse E/unoccludedE sums. Use the corner hemisphere guard and original far/invalid-guard branch. This isolates specular representation error with real native texture/tangent sampling; it is not an interpolation/cache experiment and does not measure a final optimization's speed.

Guard uses production emitter center/U/V functions, not rounded dimension literals. Candidate fallback is source-equivalent, not promised bit-identical after shader compilation: r2 has 1 or 2 fallback pixels differing by one PNG code value in the two single-ball cameras, identically for all K, while remaining fallback cameras are equal. R-repeat and R-restored are exactly equal in all cameras.

## Evidence

`analysis.json` has per-K whole frame, cloth, candidate and fallback RGB errors, and actual final normal/roughness statistics. PNG metrics are final **8-bit code values**, not linear radiance. All r2 K2/K4/K8 maxima are one code value in these five fixed cameras; this does not establish an arbitrary-view, temporal or perceptual tolerance.

- `*-variants.png`: R/K2/K4/K8 side by side.
- `*-comparison.png`: R/K8, candidate coverage and amplified difference.
- `*-red-control.png`: obvious replacement control; shader changes actually execute.
- `*-reference/repeat/restored.png`: deterministic and restoration controls.
- `*-coverage.png`: green candidate, red fallback, native other materials unaffected.
- `*-normal-roughness.rgba32f`, geometry-normal, world-position, tangent and bitangent: 600x400 float render targets, no MSAA. Two constant captures calibrate the output: (.25,.5,.75,1) is recovered exactly and world-normal length error is below 2e-7. These diagnostics bypass PNG/ICC assumptions.
- `*-actual-inputs.npy`: **all visible TaiNi pixels**, row-major, Nx10 float32 `[px,py,pz,nx,ny,nz,vx,vy,vz,roughness]`, normalized world view vector. `*-pixel-indices.npy` maps rows to `y*600+x`; `*-bed-mask.npy` tags the horizontal physical bed. No near/candidate selection is applied.
- `pixel-fixtures.json`: camera and exact 16 packed balls for each file.
- `scenekit-actual-inputs.npy`: 1920-row fast probe, 384 deterministic raster-spaced bed pixels per view across the entire visible bed. `scenekit-paired.npy` is the matching Nx4 normal/roughness subset.

Real visible bed tangents are approximately +X, bitangents -Z, geometry normals +Y; the handedness dot(cross(T,B),N) is +1. This corrects the early raw-texture helper's default +Z bitangent assumption. More importantly, actual sampled normals are much flatter after normal intensity and native filtering/mips than original full-resolution PNG texels. The actual input export preserves native sampling and needs no guessed tangent basis.

White dots and a long line visible in the table are actual source `Plane_001` White geometry, not leftover balls or a candidate artifact. Faces 606 and 607–610 encode a ~9.7mm spot at x≈-0.635,z≈0 and a ~1.3mm-wide line at x≈+0.635 across the width. These source markings can show coplanar raster fragmentation; do not interpret the entire isolated image as production visual acceptance.

## Invalid earlier evidence

`visual-r1` omitted the production bed geometry lift, so its rail-AO condition did not run on the bed. It is retained as a failed intermediate, not the final production-cloth comparison. Its first float attempt also omitted SCNTransaction.flush and is explicitly preserved under `invalid-unflushed-float-attempt`. r2 fixes both, calibrates float output and verifies final physical bed Y.

## Height-safe support-mask follow-up

`visual-height-safe-r3` reuses the same corrected renderer, replaces only the unconditional below-bed mask OR term with `support_height_safe.metal`, and captures the original five cameras plus twelve fixed-camera ball-position frames. The original inSupport OR, shadowPossible, near/far quadrature, filtering, BRDF, material and geometry remain.

```sh
python3 scripts/research/cloth_lowdim_20261113/visual_prepare.py --reference output/render-lowdim-20261113/native-reference --out output/render-lowdim-20261113/visual-height-safe-r3 --support-mask scripts/research/cloth_lowdim_20261113/support_height_safe.metal
output/render-lowdim-20261113/visual-height-safe-r3/render "$PWD" output/render-lowdim-20261113/visual-height-safe-r3 --support-only
tools/shot_reconstruction/.venv/bin/python scripts/research/cloth_lowdim_20261113/visual_analyze_support.py output/render-lowdim-20261113/visual-height-safe-r3
```

`support-analysis.json` reports all17 R/candidate frames exactly equal in RGB, all repeat/restore controls equal, and all11 consecutive motion-frame delta comparisons equal. Coverage proves pruning executed (for example26,971 near visible scatter pixels remove mask entries). This is a frozen-position sequence, not complete App motion/lifecycle evidence. The helper SHA is recorded: r3 predates any subsequent negative-subnormal/FTZ domain-guard revision, so do not silently attribute its capture to a changed helper version.

The independent mathematical and CPU audit is under `output/render-lowdim-20261113/support-height-audit/PROOF.md`, with constants, exact Float32 counterexample and reusable helper. `support-height-bounded/results.json` checks1.8million generated states and592,557 actually excluded receiver/ball pairs against all64 source grid samples: zero false negatives from both Float64 cross-product and Float32 source-formula evaluators within the declared rig domain. The original unrestricted height-generalization is falsified, even though it matched all exported current pixels; keep that rejected candidate separate from the proven filtered-cone bound.
