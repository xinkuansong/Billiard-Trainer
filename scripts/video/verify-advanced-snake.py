#!/usr/bin/env python3
"""Verify the encoded snake video, its phase ledger and the continuous board copy."""
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

out = Path(sys.argv[1]).resolve()
r3 = (out / "advanced-snake-15ball-2k60.mp4").exists()
r2 = r3 or (out / "advanced-snake-15ball-2k120.mp4").exists()
video = out / ("advanced-snake-15ball-2k60.mp4" if r3 else ("advanced-snake-15ball-2k120.mp4" if r2 else "advanced-snake-15ball-1080p60.mp4"))
fps = 120 if r2 and not r3 else 60
size = (1440,2560) if r2 else (1080,1920)
timeline = json.loads((out / "timeline.json").read_text())
sequence = json.loads((out / "continuous-sequence.json").read_text())
probe = json.loads(subprocess.check_output([
    "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(video)
]))
stream, = [s for s in probe["streams"] if s["codec_type"] == "video"]
assert (stream["width"], stream["height"]) == size
assert stream["codec_name"] == "h264" and stream["avg_frame_rate"] == f"{fps}/1"
assert int(stream["nb_frames"]) == timeline["frames"]
assert abs(float(stream["duration"]) - timeline["frames"]/fps) < 0.02
assert not [s for s in probe["streams"] if s["codec_type"] == "audio"]
assert len(sequence["steps"]) == 15
for i, step in enumerate(sequence["steps"]):
    assert step["shot"]["targetKey"] == f"_{i+1}"
    assert len(step["before"]["onTable"]) == 16-i
    assert len(step["after"]["onTable"]) == 15-i
    assert (step["shot"]["spinX"]**2 + step["shot"]["spinY"]**2)**0.5 <= 0.500000001
    if i:
        assert step["before"] == sequence["steps"][i-1]["after"]
assert set(sequence["steps"][-1]["after"]["onTable"]) == {"cueBall"}
phases = timeline["phases"]
for i in range(1, 16):
    shot_phases = [p for p in phases if p["shot"] == i]
    expected = ["observe", "to-aim", "aim", "from-aim", "setup", "stroke", "motion", "settled"] if r2 else ["observe", "aim", "setup", "stroke", "motion", "settled"]
    if r3:
        expected = ["to-observe", "observe", "to-aim", "aim", "setup", "stroke", "motion-aim", "from-aim", "motion", "settled"]
        # A short shot may settle before the camera finishes returning; its
        # moving-ball phase then ends in from-aim, followed directly by settled.
        if not any(p["phase"] == "motion" for p in shot_phases):
            expected.remove("motion")
    elif r2 and i > 1:
        expected.insert(0,"to-observe")
    assert [p["phase"] for p in shot_phases] == expected
    aim_index = next(j for j,p in enumerate(shot_phases) if p["phase"] == "aim")
    assert shot_phases[aim_index+1]["frame"]-shot_phases[aim_index]["frame"] == 2*fps
if r2:
    camera = json.loads((out / "camera-frames.json").read_text())
    assert len(camera["frames"]) == timeline["frames"]
    assert camera["maxPositionDelta"] < 0.10 and camera["maxAngleDelta"] < 0.06
    manifest_path = out / "capture-manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    observation_fov = manifest.get("observation", {}).get("verticalFov", 58)
    minimum_fov = min(52, manifest.get("opening", {}).get("verticalFov", 52))
    assert min(p["fov"] for p in camera["frames"]) >= minimum_fov
    # Quintic interpolation uses Float32: allow four ULPs at the configured FOV.
    fov_roundoff = 4 * 2 ** (math.floor(math.log2(observation_fov)) - 23)
    assert max(p["fov"] for p in camera["frames"]) <= observation_fov + fov_roundoff
    import math
    def yaw_at(frame):
        x,y,z,w = camera["frames"][frame]["orientation"]
        return math.atan2(-(1-2*(x*x+y*y)), -2*(x*z+y*w))
    for shot in range(1,16):
        observations = next(p for p in phases if p["shot"] == shot and p["phase"] == "observe")
        aiming = next(p for p in phases if p["shot"] == shot and p["phase"] == "aim")
        setup = next(p for p in phases if p["shot"] == shot and p["phase"] == "setup")
        for other in [observations,setup]:
            delta = yaw_at(aiming["frame"])-yaw_at(other["frame"])
            assert abs(math.atan2(math.sin(delta),math.cos(delta))) < 0.0001


motion_hash_count = None
if r2:
    # Decode consecutive native frames during a moving shot, not a planned static hold.
    motion_start = next(p["time"] for p in phases if p["shot"] == 1 and p["phase"] == ("motion-aim" if r3 else "motion"))
    hashes = subprocess.check_output(["ffmpeg","-v","error","-ss",str(motion_start+0.05),"-i",str(video),
        "-frames:v","60","-an","-f","framemd5","-"],text=True)
    rows = [line for line in hashes.splitlines() if line and not line.startswith("#")]
    motion_hash_count = len(set(line.split(",")[-1].strip() for line in rows))
    assert len(rows) == 60 and motion_hash_count > 50, (len(rows),motion_hash_count)

review = out / "encoded-review"
review.mkdir(exist_ok=True)
extracted_count = 0
for index, phase in enumerate(phases):
    if phase["phase"] not in ("aim", "motion", "motion-aim", "settled", "to-aim", "from-aim", "to-observe"):
        continue
    extracted_count += 1
    end = phases[index+1]["frame"] if index+1 < len(phases) else timeline["frames"]
    frame = (phase["frame"]+end-1)//2
    dest = review / f'{phase["phase"]}-{phase["shot"]:02d}.png'
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{frame/fps:.8f}",
                    "-i", str(video), "-frames:v", "1", str(dest)], check=True)
for phase in (("aim", "motion", "settled", "to-aim", "from-aim", "motion-aim", "to-observe") if r3 else ("aim", "motion", "settled", "to-aim", "from-aim") if r2 else ("aim", "motion", "settled")):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "image2", "-pattern_type", "glob", "-i",
                    str(review / f"{phase}-[0-9][0-9].png"), "-vf", "scale=270:480,tile=5x3",
                    "-frames:v", "1", str(review / f"{phase}-review.png")], check=True)
result = {
    "passed": True, "video": video.name, "size": list(size), "fps": fps,
    "frames": timeline["frames"], "seconds": float(stream["duration"]),
    "aimSegments": 15, "aimSecondsEach": 2, "continuousShots": 15,
    "finalOnTable": ["cueBall"], "audio": "none",
    "sha256": hashlib.sha256(video.read_bytes()).hexdigest(),
    "extractedReviewFrames": extracted_count,
    "consecutiveMotionFrames": 60 if r2 else None, "distinctMotionFrames": motion_hash_count,
    "note": "Encoding and ledger checks. Review PNGs separately for visual acceptance."
}
(out / "verification.json").write_text(json.dumps(result, indent=2, ensure_ascii=False))
print(json.dumps(result, indent=2, ensure_ascii=False))
