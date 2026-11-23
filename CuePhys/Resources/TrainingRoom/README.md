# Training room assets

Current room trial (2026-10-02): all three styles use an **8 × 6 m** inner floor
and **3.6 m** wall height. Wall anchors, furniture, posters and camera clearance
follow the new shell; furniture/table sizes are retained. Six geometry exports
and six lightmaps were rebuilt from the current measured Swift lighting rig
(83.618076 W per Blender panel), with world strength 2.2 and 12 W wall washes.
Runtime yarn and repeating carpet motifs retain their physical scale; the eastern
border follows the new floor. Rebuild defaults are now 8 × 6; override with
`--room-length` / `--room-width`. Metal baking is optional via `--use-metal`.
Evidence, current Blender files and original backups:
`output/room-size-study-20261002/integration/`; task record:
`tasks/ROOM-SIZE-STUDY-20261002.md`. The dated sections below describe prior revisions.

S428/S430, 2026-09-12. Original project-owned Blender geometry and procedural materials;
no third-party models/textures used in the new room atlases. Existing TrainingCarpet
is retained as the low-contrast yarn detail texture from the prior room work.

Styles: tournament = ④极简赛事 (default), walnut = ②温润木质 (legacy preference
raw value preserved), eastern = ⑥当代东方. Only selected style loaded.

`Room_<style>_perimeter.usdz` and `_floor.usdz` are real Blender USD exports,
with geometry/UVs only. Corresponding `<style>_<part>.png` contains Cycles diffuse
color + direct + indirect light, baked with original room materials. Table-body
occlusion is baked into the room; moving ball lighting/shadows are not. No lights/cameras exported.

Perimeter atlas: 2048²; floor illumination: 1024². Runtime `.constant` applies
baked RGB without a second light pass. Floor gets a separate material UV transform
(0.9m yarn tile on the 10×8m planar UV, anisotropy 16). S438 bakes actual table
visibility into the floor; the old ellipse overlay is disabled for this room. The old floor plane
has no geometry to avoid coplanar duplicates. The USD Y-up conversion is retained
as authored on the imported root; no extra 90° rotation.

Rebuild an isolated asset candidate:

```
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 \
  --python scripts/blender/build_training_rooms.py -- \
  --style tournament --output output/render-quality-v62/room-rebuild \
  --table-shadow-obj output/render-quality-v62/S437-shadow-mesh/table-shadow.obj
```

Repeat with walnut/eastern. Inspect and validate exports in the App before
replacing bundled assets. Current source `.blend`, baking logs, clean-reimport
audit and images: `output/render-quality-v62/S438-room-grounding/` (prior S430 retained).

S458 lighting update: geometry remains S438, six diffuse PNGs now use measured
reference table panels (44.566746W each in Blender4.5.6), world strength4 and
unchanged32W wall washes. Run `scripts/blender/calibrate_reference_panels.py`
in Blender with `--output <calibration-directory>` first, then add
`--panel-calibration <calibration-directory>/calibration.json --world-strength 4`
to the rebuild above. Calibration checks the Swift source hash before baking.
Current source bakes/audit: `output/render-quality-v62/S458-balanced-room/`.
Prior PNGs: `output/render-quality-v62/S453-light-calibration/baseline/`.
Direct diffuse matching does not imply that runtime ball indirect/specular
lighting has been derived from the room; that remains a separate approximation.

Since ADR-P5-01 (2026-09-14) the room is installed by `AngleTrainingScene.setupScene`
whenever `MobileTableRendering.isEnabled` (Release: always; Debug escape hatch
`-v62.legacyRendering`), and the Settings "球房风格" entry ships in Release. Runtime memory budget:
2 diffuse atlases ≈26.7MiB RGBA including mipmaps, plus shared yarn texture and
geometry; one selected-style prototype cache shares decoded images with cloned instances.
Geometry/materials are copied per instance to isolate exposure and view state; no cache retains all three styles. These are resource estimates,
not measured phone FPS/energy acceptance.

S429 initial App images were rejected: floor multi-index UV reconstruction produced
a dark floor, and low-sample baking was noisy. S430 uses a plain floor with authored
planar UV, 192 Cycles samples and Blender compositor denoising. These issues must
not be counted as visually accepted just because the initial tests passed.

S481 quiet-room/rack revision (2026-09-13): use `--world-strength 2.2
--wall-wash-watts 12` with the same panel calibration. Current rack has four
segmented tapered cues per furnished wall, felt seats and open retaining clips;
wood/eastern dado caps terminate at uprights. Rack UV islands receive higher
relative texel density and are packed isotropically in the existing2048² atlas.
No extra texture or material batch. Rejected strip-packed/early-triangulated
experiments caused upholstery artifacts; preserve the one-join normal pipeline.
Final source and clean-import audit: `output/render-quality-v62/S481-isotropic-uv/`.
Prior complete assets: `output/render-quality-v62/S464-rack-baseline/`.

### S488 loop-pile detail
TrainingCarpet.jpg now uses the user-selected charcoal loop-pile concept (built-in image_gen; source and prompt in output/render-quality-v62/S487-loop-carpet). 1024² JPEG, 30cm mirrored repeat; baked floor lighting remains unchanged. Runtime local yarn modulation is recentered around the swatch gray. S488 three-style render and S489 selection/culling checks passed; phone motion/thermal validation pending.

### 2026-09-28 per-room carpet atlases (r4)
The r2 unified-chevron interpretation was rejected. Each room retains its selected
concept: tournament broad charcoal chevrons, walnut warm taupe basket weave,
eastern warm stone-gray ground with a squared key border. Accepted references
are preserved in `output/carpet-styles-20260928/accepted-reference/`.

`Carpet_{style}.png` are independent 1402 × 1122 base-color atlases generated
with image_gen from the selected references. Prompts/provenance are under
`output/carpet-styles-20260928/r3/source/` and `r4/source/`. After the user rejected r3 as oversized/coarse, tournament uses a mirrored
2 × 2 repeat and walnut 4 × 4 over the 10 × 8 m floor (half their r3 motif size).
Eastern covers the floor once with a revised finer border and single corner keys. The shader divides sampled linear albedo by the original uniform
bake albedo (from `build_training_rooms.py`) to retain baked light and shadows.
The original 30 cm yarn detail remains separate at 15% modulation; atlas sampling
uses +2 mip bias for the repeating weaves and +1 for the smoother eastern atlas,
retaining border clarity while suppressing oversized generated fiber grain. No USDZ, lightmap or light changes.

Only the selected room atlas is loaded: one additional texture sample, about
8 MiB RGBA with mipmaps. This is an estimate, not a measured device cost.
Comparison shader stripping retains original yarn/lighting for same-run baseline.
Actual render evidence and device validation status: `tasks/ui-reviews/UR-20260928-carpet-styles.md`.


r4 was rejected as lacking textile character. r5 is currently a tournament-only
material trial: clean macro atlas (new image_gen source under `r5/source/`),
no added mip bias, and the original yarn at 20 cm repeat/full modulation.
Walnut/eastern retain r4 until this material direction is visually accepted.
The 10 cm/+4 bias experiment was discarded as too soft; no device quality
claim should cite that intermediate image. `texture-trial.html` compares r4/r5
on-device static outputs. All three styles remain visually unaccepted.


r6: user accepted the r5 tournament material. Its atlas, shader parameters and
viewed device images are frozen in `accepted-reference/r5-tournament/`.
All rooms now use the accepted 20 cm yarn repeat at full modulation. Walnut
uses a cleaned basket-weave macro atlas with +1 mip bias; eastern retains its
fine key-border atlas with +1 mip bias. Tournament still uses its exact r5
atlas and zero added mip bias. Patterns/palettes remain distinct. This extends
the material treatment, not the user's visual acceptance of the other rooms.
