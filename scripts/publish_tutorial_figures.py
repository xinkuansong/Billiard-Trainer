#!/usr/bin/env python3
"""
publish_tutorial_figures.py — 精讲配图发布：PNG 母版 → HEIC 打包目录（v25 W4 / D-v25-2 / D-v25-10）

目录分工（folder reference 是整目录打包，母版与发布图必须分家，否则孤儿帧必然进包）：
  母版  QiuJi/Resources/DrillTutorials/   全量 PNG（含孤儿帧），gitignore，**不打包**
        ← `import-engine-export-to-app.py` 回填目标；C2 回填一致性仍按字节比对这里
  发布  QiuJi/Resources/TutorialFigures/  仅被精讲引用者，HEIC，**进 git、folder ref 打包**
        ← 本脚本产物；Bundle 子目录名 = TutorialFigures（`DrillTutorialImageStore`）

清单 content/tutorial-figures-manifest.json 记录每张产物的源 md5，用途有二：
  ① 增量发布（源没变就不重压）；
  ② 门禁 --check 的新鲜度判据——母版改了但没重发布会被拦下。
    ⛔ 转 HEIC 后源与产物不可能字节相等，`verify_tutorial_sync.py` 的 C2 字节比对
    对发布目录天然失效，本清单是它在发布链路上的等价物，不是降级放行。

用法：
  python3 scripts/publish_tutorial_figures.py              # 增量发布
  python3 scripts/publish_tutorial_figures.py --check      # 只校验（verify-gate 入口），不写盘
  python3 scripts/publish_tutorial_figures.py --force      # 全量重压
  python3 scripts/publish_tutorial_figures.py --quality 75

退出码：发布模式失败（缺母版 / sips 报错）或 --check 不通过为 1，否则 0。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_tutorial_images import collect_image_refs  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[1]
DRILLS_DIR = REPO_ROOT / "QiuJi" / "Resources" / "Drills"
MASTERS_DIR = REPO_ROOT / "QiuJi" / "Resources" / "DrillTutorials"
PUBLISH_DIR = REPO_ROOT / "QiuJi" / "Resources" / "TutorialFigures"
MANIFEST_PATH = REPO_ROOT / "content" / "tutorial-figures-manifest.json"

# q70：v25 W4 拍板值。实测 1440×2720 渲染图 PNG 3.7 MB → q45 64 KB / q60 115 KB /
# q75 198 KB，HEIC 回转 PNG 与母版比对 PSNR 41.7–43.4 dB（q45 已目视无差）。
# 取 q70 留足余量，仍远低于 W4 DoD 的 150 MB 上限。
DEFAULT_QUALITY = 70
PUBLISHED_IMAGE_SUFFIX = ".heic"
# 动态演示片段（`clip` 字段）已是 H.264/HEVC，原样搬运不做二次编码。
CLIP_SUFFIX = ".mp4"


def md5(path: Path) -> str:
    h = hashlib.md5()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def collect_clip_refs(drills_dir: Path | None = None) -> set[str]:
    """精讲 `clip` 字段引用的片段名（不含扩展名），与 image 同一遍历口径。"""
    clips: set[str] = set()
    for path in sorted((drills_dir or DRILLS_DIR).rglob("*.json")):
        if path.name == "index.json":
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        tutorial = data.get("tutorial")
        if not isinstance(tutorial, dict):
            continue
        buckets = [tutorial.get("sections")]
        for form in tutorial.get("formations") or []:
            if isinstance(form, dict):
                buckets.append(form.get("sections"))
        for sections in buckets:
            if not isinstance(sections, list):
                continue
            for section in sections:
                if not isinstance(section, dict):
                    continue
                clip = section.get("clip")
                if isinstance(clip, str) and clip.strip():
                    clips.add(clip.strip())
    return clips


def load_manifest() -> dict[str, dict]:
    if not MANIFEST_PATH.is_file():
        return {}
    try:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        # ⛔ FL-029：清单坏了要能定位，不静默当空清单（那会伪装成"全量重压"）
        print(f"❌ 清单解析失败 {MANIFEST_PATH}: {exc}", file=sys.stderr)
        raise SystemExit(1)
    entries = data.get("figures")
    return entries if isinstance(entries, dict) else {}


def write_manifest(entries: dict[str, dict], quality: int) -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "_note": "publish_tutorial_figures.py 产物清单；src_md5 = 母版 PNG 的 md5，供增量与门禁新鲜度判据",
        "quality": quality,
        "count": len(entries),
        "total_bytes": sum(e.get("bytes", 0) for e in entries.values()),
        "figures": dict(sorted(entries.items())),
    }
    MANIFEST_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def encode_heic(src: Path, dst: Path, quality: int) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        ["sips", "-s", "format", "heic", "-s", "formatOptions", str(quality),
         str(src), "--out", str(dst)],
        capture_output=True, text=True,
    )
    if proc.returncode != 0 or not dst.is_file():
        raise RuntimeError(f"sips 转码失败 {src.name}: {proc.stderr.strip() or proc.stdout.strip()}")


def resolve_master(stem: str) -> Path | None:
    candidate = MASTERS_DIR / f"{stem}.png"
    return candidate if candidate.is_file() else None


def build_plan() -> tuple[dict[str, Path], dict[str, Path], list[str]]:
    """返回 (图片发布集, 片段发布集, 缺母版清单)，键为产物文件名。"""
    image_stems = sorted({stem for _, stem, _ in collect_image_refs()})
    clip_stems = sorted(collect_clip_refs())

    images: dict[str, Path] = {}
    clips: dict[str, Path] = {}
    missing: list[str] = []

    for stem in image_stems:
        master = resolve_master(stem)
        if master is None:
            missing.append(f"{stem}.png")
            continue
        images[f"{stem}{PUBLISHED_IMAGE_SUFFIX}"] = master

    for stem in clip_stems:
        master = MASTERS_DIR / f"{stem}{CLIP_SUFFIX}"
        if not master.is_file():
            missing.append(f"{stem}{CLIP_SUFFIX}")
            continue
        clips[f"{stem}{CLIP_SUFFIX}"] = master

    return images, clips, missing


def existing_products() -> set[str]:
    if not PUBLISH_DIR.is_dir():
        return set()
    return {p.name for p in PUBLISH_DIR.iterdir() if p.is_file() and not p.name.startswith(".")}


def run_check(images: dict[str, Path], clips: dict[str, Path], missing: list[str]) -> int:
    manifest = load_manifest()
    expected = {**images, **clips}
    on_disk = existing_products()

    absent = sorted(set(expected) - on_disk)
    # D-v25-10：孤儿帧不进包——发布目录出现引用集之外的文件即视为违规
    extra = sorted(on_disk - set(expected))
    stale: list[str] = []
    unrecorded: list[str] = []
    for name, master in sorted(expected.items()):
        if name in absent:
            continue
        entry = manifest.get(name)
        if entry is None:
            unrecorded.append(name)
            continue
        if entry.get("src_md5") != md5(master):
            stale.append(name)

    total = sum((PUBLISH_DIR / n).stat().st_size for n in on_disk & set(expected))
    print(f"[发布图] 应发布 {len(expected)}  已发布 {len(on_disk & set(expected))}  "
          f"合计 {total / 1048576:.1f} MB")
    print(f"  缺母版 {len(missing)}  未发布 {len(absent)}  过期 {len(stale)}  "
          f"未登记清单 {len(unrecorded)}  多余产物 {len(extra)}")
    for label, items in (("缺母版", missing), ("未发布", absent), ("过期(母版已变)", stale),
                         ("未登记清单", unrecorded), ("多余产物(孤儿入包)", extra)):
        for item in items[:20]:
            print(f"    · {label}: {item}")
        if len(items) > 20:
            print(f"    · {label}: …… 另有 {len(items) - 20} 项")

    fails = len(missing) + len(absent) + len(stale) + len(unrecorded) + len(extra)
    print(f"总计 FAIL: {fails}" + ("" if fails else " —— 发布链路同步"))
    return 1 if fails else 0


def run_publish(images: dict[str, Path], clips: dict[str, Path], missing: list[str],
                quality: int, force: bool, dry_run: bool) -> int:
    if missing:
        for name in missing:
            print(f"❌ 缺母版: {name}", file=sys.stderr)
        print(f"❌ {len(missing)} 个被引用配图在母版目录找不到，先修引用或重跑回填", file=sys.stderr)
        return 1

    manifest = load_manifest()
    expected = {**images, **clips}
    new_manifest: dict[str, dict] = {}
    converted = skipped = copied = 0

    for name, master in sorted(expected.items()):
        src_md5 = md5(master)
        dst = PUBLISH_DIR / name
        prior = manifest.get(name)
        fresh = (
            not force
            and dst.is_file()
            and prior is not None
            and prior.get("src_md5") == src_md5
            and prior.get("quality") == (quality if name.endswith(PUBLISHED_IMAGE_SUFFIX) else None)
        )
        if fresh:
            skipped += 1
            new_manifest[name] = {**prior, "bytes": dst.stat().st_size}
            continue
        if dry_run:
            print(f"  PUBLISH {master.name} → {name}")
            new_manifest[name] = {"src": master.name, "src_md5": src_md5,
                                  "quality": quality if name.endswith(PUBLISHED_IMAGE_SUFFIX) else None,
                                  "bytes": prior.get("bytes", 0) if prior else 0}
            continue
        if name.endswith(PUBLISHED_IMAGE_SUFFIX):
            encode_heic(master, dst, quality)
            converted += 1
            entry_quality = quality
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(master.read_bytes())
            copied += 1
            entry_quality = None
        new_manifest[name] = {"src": master.name, "src_md5": src_md5,
                              "quality": entry_quality, "bytes": dst.stat().st_size}

    # 清掉不再被引用的旧产物（D-v25-10：发布目录只许存在被引用者）
    pruned = 0
    for name in sorted(existing_products() - set(expected)):
        print(f"  PRUNE {name}")
        if not dry_run:
            (PUBLISH_DIR / name).unlink()
        pruned += 1

    if not dry_run:
        write_manifest(new_manifest, quality)

    total = sum(e.get("bytes", 0) for e in new_manifest.values())
    print(f"✅ 发布 {len(new_manifest)} 项（新压 {converted} / 搬运 {copied} / 复用 {skipped} / "
          f"清理 {pruned}）  合计 {total / 1048576:.1f} MB  质量 q{quality}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="只校验发布集与新鲜度，不写盘（verify-gate 入口）")
    ap.add_argument("--force", action="store_true", help="忽略清单，全量重压")
    ap.add_argument("--dry-run", action="store_true", help="打印将发布的项，不写盘")
    ap.add_argument("--quality", type=int, default=DEFAULT_QUALITY, help=f"HEIC 质量（默认 {DEFAULT_QUALITY}）")
    args = ap.parse_args()

    if not MASTERS_DIR.is_dir():
        print(f"❌ 母版目录不存在: {MASTERS_DIR}", file=sys.stderr)
        return 1

    images, clips, missing = build_plan()
    if args.check:
        return run_check(images, clips, missing)
    return run_publish(images, clips, missing, args.quality, args.force, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
