#!/usr/bin/env python3
"""
patch-pbxproj-folder-refs.py — 在 xcodegen 生成的 project.pbxproj 中注入 folder refs

背景
----
xcodegen 不会为 project.yml 中 `type: folder` 的 resources 生成 Xcode folder
reference（蓝色文件夹）。当前 QiuJi 工程的 Resources/Drills、Resources/Plans、
Resources/Videos 都需要作为 folder reference 打包（这样 `Bundle.main.url(
forResource:withExtension:subdirectory:)` 才能解析子目录路径）。

之前的做法是手工编辑 pbxproj。任何一次 `xcodegen generate` 都会清掉手工修改。
本脚本在 `xcodegen generate` 之后立即跑一遍即可补回去（幂等）。

约定
----
- folder 引用 id：`F1A5B07100000000000000<X>0`（X = A 0..9 / A..F）
- build file id：`F1A5B07100000000000000<X>1`
- 必须运行在仓库根目录（或本脚本所在的 scripts/ 目录）

用法
----
  python3 scripts/patch-pbxproj-folder-refs.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
PBXPROJ = REPO_ROOT / "QiuJi.xcodeproj" / "project.pbxproj"

# (name, path, id_suffix)
# path 相对 Resources 组（QiuJi/Resources/...）
FOLDERS = [
    ("Drills", "Drills", "A"),
    ("Plans", "Plans", "B"),
    ("Videos", "Videos", "C"),
]

ID_PREFIX = "F1A5B07100000000000000"


def patch(pbxproj_text: str) -> str:
    text = pbxproj_text

    for name, path, suffix in FOLDERS:
        ref_id = f"{ID_PREFIX}{suffix}0"
        build_id = f"{ID_PREFIX}{suffix}1"

        already_has_ref = ref_id in text
        already_has_build = build_id in text

        # 1) PBXBuildFile section
        if not already_has_build:
            build_line = (
                f"\t\t{build_id} /* {name} in Resources */ = "
                f"{{isa = PBXBuildFile; fileRef = {ref_id} /* {name} */; }};\n"
            )
            text = re.sub(
                r"(/\* Begin PBXBuildFile section \*/\n)",
                r"\1" + build_line,
                text,
                count=1,
            )

        # 2) PBXFileReference section
        if not already_has_ref:
            ref_line = (
                f"\t\t{ref_id} /* {name} */ = "
                f"{{isa = PBXFileReference; lastKnownFileType = folder; "
                f"path = {path}; sourceTree = \"<group>\"; }};\n"
            )
            text = re.sub(
                r"(/\* Begin PBXFileReference section \*/\n)",
                r"\1" + ref_line,
                text,
                count=1,
            )

        # 3) Resources 组 children（PBXGroup）
        #    匹配形如：
        #    XXX /* Resources */ = {
        #        isa = PBXGroup;
        #        children = (
        #            ...
        #        );
        #        path = Resources;
        if f"{ref_id} /* {name} */," not in text:
            group_re = re.compile(
                r"(\s+[A-Z0-9]{24} /\* Resources \*/ = \{\s*"
                r"isa = PBXGroup;\s*"
                r"children = \(\s*)([\s\S]*?)(\s*\);\s*"
                r"path = Resources;)",
            )
            m = group_re.search(text)
            if m is None:
                print(f"⚠️  未找到 Resources PBXGroup，{name} 跳过 children 注入", file=sys.stderr)
            else:
                injection = f"\t\t\t\t{ref_id} /* {name} */,\n"
                new_children = m.group(2).rstrip("\n") + "\n" + injection.rstrip("\n")
                text = text[: m.start()] + m.group(1) + new_children + m.group(3) + text[m.end():]

        # 4) Resources build phase 的 files（PBXResourcesBuildPhase）
        #    工程里有 QiuJi 主 target 与 QiuJiLiveActivity 扩展两个 Resources 阶段。
        #    必须注入到主 app 那一个 —— 用 TaiQiuZhuo.usdz 作为锚点定位。
        if f"{build_id} /* {name} in Resources */," not in text:
            main_app_phase_re = re.compile(
                r"(isa = PBXResourcesBuildPhase;[\s\S]*?"
                r"files = \(\s*)([\s\S]*?TaiQiuZhuo\.usdz in Resources[\s\S]*?)(\s*\);\s*"
                r"runOnlyForDeploymentPostprocessing)",
            )
            m = main_app_phase_re.search(text)
            if m is None:
                print(f"⚠️  未找到包含 TaiQiuZhuo.usdz 的主 app Resources 阶段，{name} 跳过", file=sys.stderr)
            else:
                injection = f"\t\t\t\t{build_id} /* {name} in Resources */,\n"
                new_files = m.group(2).rstrip("\n") + "\n" + injection.rstrip("\n")
                text = text[: m.start()] + m.group(1) + new_files + m.group(3) + text[m.end():]

    return text


def main() -> int:
    if not PBXPROJ.is_file():
        print(f"❌ 找不到 pbxproj: {PBXPROJ}", file=sys.stderr)
        return 1
    original = PBXPROJ.read_text()
    patched = patch(original)
    if patched == original:
        print("ℹ️  无需修改（folder refs 已就位）")
        return 0
    PBXPROJ.write_text(patched)
    refs = ", ".join(name for name, _, _ in FOLDERS)
    print(f"✅ 已注入 folder refs：{refs}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
