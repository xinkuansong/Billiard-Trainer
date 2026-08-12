#!/usr/bin/env python3
"""
verify_sync_schema_alignment.py — 用户数据同步「Swift DTO ↔ Mongoose schema」双端对齐门禁
（问题集合 v36 Q5 / D-v36-3=A；契约 .kiro/steering/content-data-contract.md §4.1 / §8.13）

## 为什么需要这个门禁

Mongoose schema 默认 `strict: true`：**未在 schema 里登记的字段会被静默丢弃**，
写入不报错、响应里也没有它。因此「Swift DTO 有、后端 schema 没有」这一个方向
就是一次数据静默丢失事故，而且客户端完全无感。本仓库已经踩过两次，两次都靠人肉走查
才发现：
  - v29 W5：`AngleTestDTO` 的 `quizType` / `errorMM` / `sessionId` 未登记；
  - v36 W1：`TrainingSessionDTO` 的 9 个成绩字段未登记（`unitLabel` 丢失还会让恢复
    出来的数据**语义错误**——「局/次」被当成「球」）。
本脚本把这条纪律变成机器检查，供 `make verify-gate`（pre-push）调用。

## 对齐口径（裁定，v36 W4）

| 检查 | 内容 | 级别 | 依据 |
|------|------|------|------|
| D0 | 两侧字段集能否被解析出来（结构找不到 / node 不可用 / 字段集为空） | **FAIL** | 解析不了就等于门禁不存在；⛔ 绝不静默 PASS |
| D1 | **Swift DTO 有、后端 schema 未登记** 的字段 | **FAIL** | `strict:true` 静默丢数据 = 本轮真实事故形态 |
| D2 | 后端 schema 有、Swift DTO 没有的字段（排除服务端专属白名单） | WARN | 不丢数据，但通常是死字段或客户端漏读；需人判断，不阻塞 |
| D3 | 同名字段的标量类型口径（Int/Double↔Number、String↔String…） | WARN | mongoose 会做 cast，多数不致命；但 `[XDTO]` ↔ 子 schema 的**结构**不一致按 D1 FAIL |

嵌套是自动递归的：Swift 侧字段类型形如 `[XxxDTO]` 且后端同名 path 是带子 schema 的
数组时，就下钻比对 `XxxDTO` ↔ 该子 schema（本仓当前覆盖
`TrainingSessionDTO → DrillEntryDTO → DrillSetDTO` ↔ `drillEntrySchema` / `drillSetSchema`）。
新增嵌套 DTO 无需改本脚本。

### 白名单（唯一一处，逐条理由；⛔ 禁止为「凑绿」往里加业务字段）

`SERVER_OWNED_PATHS` 只用于**豁免 D2 WARN**（后端有而 Swift 无），
⛔ 不豁免 D1 —— 也就是说它无论如何不能掩盖「Swift 有而后端没登记」的事故。
子 schema 声明了 `_id: false`，故子文档里本来就没有 `_id`/`__v`，无需额外处理。

## 解析方式与可靠性依据

- **后端侧 = `node -e` require 真模型，打印 `schema.paths`。** 这是 mongoose 自己算出的
  最终 path 表，与线上 `strict` 过滤用的是同一份数据结构，属**真源**而非近似；
  能自动覆盖 `timestamps: true` 注入的 `createdAt`/`updatedAt`、`_id`、`__v`，以及
  子 schema 的 `_id: false`。正则解析 JS 只能是猜。代价是依赖 `backend/node_modules`
  （已 gitignore），缺失时本脚本 **FAIL 并给出 `cd backend && npm install`**，
  ⛔ 不降级为跳过。
- **Swift 侧 = 文本解析 `struct` 体内的存储属性。** 这些 DTO 没有自定义 `CodingKeys`，
  Codable 合成的 wire key 就是存储属性名，因此「存储属性集 == JSON 字段集」；
  若将来手写了 `enum CodingKeys`，本脚本会改用它（含 `case a = "wire"` 重命名）。
  解析前剥掉注释，只认结构体体内**顶层深度**的 `let/var name: Type` 行，跳过
  `static` 与以 `{` 结尾的计算属性。任何一步解析不出字段就 D0 FAIL。
  （不用 SwiftSyntax：本仓无 Swift 侧脚本工具链，引一整套解析器不符合最小改动；
  这些 DTO 是手写小结构体，形态稳定，且解析失败会 FAIL 而不是错放。）

## 用法

  python3 scripts/verify_sync_schema_alignment.py            # 全部检查
  python3 scripts/verify_sync_schema_alignment.py --gate      # 门禁模式（pre-push；阻塞集相同）
  python3 scripts/verify_sync_schema_alignment.py --root <fixture>   # 指向影子副本（构造性用例用）
  python3 scripts/verify_sync_schema_alignment.py --selftest  # 构造性自测：注入未登记字段，断言真会 FAIL

退出码：任一 FAIL 则为 1，否则 0。WARN 不影响退出码。
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

SWIFT_REL = Path("QiuJi/Data/Services/BackendSyncService.swift")
BACKEND_MODELS_REL = Path("backend/src/models")

# (标签, Swift DTO 结构体名, 后端模型文件名)
PAIRS = [
    ("TrainingSessionDTO ↔ trainingSessionSchema", "TrainingSessionDTO", "TrainingSession.js"),
    ("AngleTestDTO ↔ angleTestSchema", "AngleTestDTO", "AngleTest.js"),
]

# 服务端专属 path → 客户端 DTO 不该有它的理由。仅豁免 D2（后端有而 Swift 无）。
SERVER_OWNED_PATHS = {
    "_id": "mongoose 主键，客户端不持有（同步一律按 clientId 寻址，v36 D-v36-2）",
    "__v": "mongoose 版本键，纯服务端簿记",
    "userId": "服务端由 JWT 注入，客户端上传它等于允许越权写别人的数据",
    "createdAt": "timestamps:true 自动维护的服务端时间",
    "updatedAt": "timestamps:true 自动维护；下行增量锚点走 SyncedRecord 信封而非业务 DTO（v36 W3）",
}

# Swift 标量 → mongoose SchemaType.instance
TYPE_MAP = {
    "String": {"String"},
    "Int": {"Number"},
    "Double": {"Number"},
    "Float": {"Number"},
    "Bool": {"Boolean"},
    "Date": {"Date"},
}


class ParseError(Exception):
    """两侧字段集解析失败 —— 一律按 D0 FAIL 上报，不得静默放过。"""


# ── Swift 侧 ──────────────────────────────────────────────────────────────

def strip_swift_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return "\n".join(re.sub(r"//.*$", "", line) for line in text.splitlines())


def struct_body(text: str, name: str) -> str:
    """取 `struct <name> … { … }` 的体（含嵌套内容），大括号配平失败即 ParseError。"""
    match = re.search(rf"(?m)^[ \t]*struct[ \t]+{re.escape(name)}\b[^{{\n]*\{{", text)
    if not match:
        raise ParseError(f"在 Swift 源里找不到 `struct {name}`（改名/挪文件了？同步更新本脚本 PAIRS）")
    depth, start = 0, match.end()
    for i in range(match.end() - 1, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start:i]
    raise ParseError(f"`struct {name}` 的大括号未配平，无法确定结构体范围")


PROP_RE = re.compile(
    r"^\s*(?:public|private|internal|fileprivate|package)?\s*(?:let|var)\s+"
    r"([A-Za-z_]\w*)\s*:\s*([^=]+?)\s*(?:=.*)?$"
)
CASE_RE = re.compile(r"^\s*case\s+(.+)$")


def top_level_lines(body: str):
    """产出结构体体内**顶层深度**的行（跳过嵌套 struct / enum / init / 闭包内部）。"""
    depth = 0
    for line in body.splitlines():
        if depth == 0:
            yield line
        depth += line.count("{") - line.count("}")


def coding_keys(body: str) -> list[str] | None:
    """若手写了 `enum CodingKeys`，返回其 wire key 列表；否则 None（用合成 key）。"""
    match = re.search(r"(?m)^[ \t]*(?:private\s+)?enum[ \t]+CodingKeys\b[^{\n]*\{", body)
    if not match:
        return None
    inner = struct_body_from(body, match)
    keys: list[str] = []
    for line in inner.splitlines():
        hit = CASE_RE.match(line)
        if not hit:
            continue
        for item in hit.group(1).split(","):
            item = item.strip()
            if not item:
                continue
            if "=" in item:
                name, raw = item.split("=", 1)
                keys.append(raw.strip().strip('"'))
            else:
                keys.append(item.strip())
    if not keys:
        raise ParseError("`enum CodingKeys` 存在但解析不出任何 case")
    return keys


def struct_body_from(text: str, match: re.Match) -> str:
    depth, start = 0, match.end()
    for i in range(match.end() - 1, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start:i]
    raise ParseError("大括号未配平")


def swift_fields(text: str, struct_name: str) -> dict[str, str]:
    """返回 {wire key: Swift 类型（去掉可选 `?`）}。"""
    body = struct_body(text, struct_name)
    props: dict[str, str] = {}
    for line in top_level_lines(body):
        code = line.strip()
        if not code or "static" in code.split(":")[0] or code.endswith("{"):
            continue
        hit = PROP_RE.match(code)
        if not hit:
            continue
        props[hit.group(1)] = hit.group(2).strip().rstrip("?").strip()
    if not props:
        raise ParseError(f"`struct {struct_name}` 里解析不出任何存储属性（解析器与源码形态脱节）")
    declared = coding_keys(body)
    if declared is None:
        return props
    unknown = [k for k in declared if k not in props]
    if unknown:
        # CodingKeys 里的 case 名与属性名不一致（重命名）时无法回推类型，
        # 用 "?" 占位：字段集比对照旧成立，只是 D3/递归对该字段不下判断。
        for key in unknown:
            props.setdefault(key, "?")
    return {k: props[k] for k in declared}


# ── 后端侧 ────────────────────────────────────────────────────────────────

NODE_DUMP = r"""
const path = process.argv[1];
function dump(schema) {
  const out = {};
  for (const [key, type] of Object.entries(schema.paths)) {
    out[key] = { instance: type.instance || null,
                 sub: type.schema ? dump(type.schema) : null };
  }
  return out;
}
const model = require(path);
const schema = model && model.schema ? model.schema : model;
if (!schema || !schema.paths) throw new Error("模块导出里找不到 mongoose schema：" + path);
process.stdout.write(JSON.stringify(dump(schema)));
"""


def backend_paths(model_file: Path) -> dict:
    if shutil.which("node") is None:
        raise ParseError("找不到 `node`，无法读取 mongoose schema 真源 → 装 Node.js 后重跑")
    if not model_file.is_file():
        raise ParseError(f"后端模型文件不存在：{model_file}")
    proc = subprocess.run(
        ["node", "-e", NODE_DUMP, str(model_file)],
        capture_output=True, text=True, cwd=str(model_file.parent),
    )
    if proc.returncode != 0:
        stderr = proc.stderr.strip()
        lines = stderr.splitlines()
        # node 把版本号打在 stderr 末尾，取首个含 Error 的行才定位得到真因。
        reason = next((ln.strip() for ln in lines if "Error" in ln), lines[0] if lines else "无输出")
        hint = ""
        if "Cannot find module 'mongoose'" in stderr:
            hint = "\n      → 依赖缺失（backend/node_modules 已 gitignore）：cd backend && npm install"
        raise ParseError(f"node require 后端模型失败：{reason}{hint}")
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise ParseError(f"node 输出不是合法 JSON：{exc}") from exc
    if not data:
        raise ParseError(f"{model_file.name} 的 schema.paths 为空（解析口径失效）")
    return data


# ── 比对 ──────────────────────────────────────────────────────────────────

class Report:
    def __init__(self) -> None:
        self.fails: list[str] = []
        self.warns: list[str] = []

    def fail(self, check: str, msg: str) -> None:
        self.fails.append(f"{check} {msg}")
        print(f"  ✗ [{check}] {msg}")

    def warn(self, check: str, msg: str) -> None:
        self.warns.append(f"{check} {msg}")
        print(f"  ⚠ [{check}] {msg}")

    def ok(self, msg: str) -> None:
        print(f"  ✓ {msg}")


def compare(report: Report, scope: str, swift: dict[str, str], backend: dict,
            swift_text: str) -> None:
    missing = [k for k in swift if k not in backend]
    if missing:
        report.fail("D1", f"{scope}: Swift DTO 有、后端 schema 未登记 → {', '.join(missing)}"
                          "（mongoose strict:true 会静默丢弃，服务器副本有损）")
    extra = [k for k in backend if k not in swift and k not in SERVER_OWNED_PATHS]
    if extra:
        report.warn("D2", f"{scope}: 后端 schema 有、Swift DTO 未消费 → {', '.join(extra)}"
                          "（死字段？或客户端漏读服务端产出）")

    for key, swift_type in swift.items():
        node = backend.get(key)
        if node is None:
            continue
        element = re.fullmatch(r"\[(\w+)\]", swift_type)
        if element:
            if node["sub"] is None:
                report.fail("D1", f"{scope}.{key}: Swift 是数组 `{swift_type}`，"
                                  f"后端却是 `{node['instance']}` 无子 schema（嵌套字段全部会被丢）")
                continue
            compare(report, f"{scope}.{key}", swift_fields(swift_text, element.group(1)),
                    node["sub"], swift_text)
            continue
        if node["sub"] is not None:
            report.warn("D3", f"{scope}.{key}: 后端是子 schema，Swift 侧类型 `{swift_type}` 不是数组")
            continue
        expected = TYPE_MAP.get(swift_type)
        if expected and node["instance"] not in expected:
            report.warn("D3", f"{scope}.{key}: Swift `{swift_type}` ↔ 后端 `{node['instance']}` 口径不同")

    aligned = [k for k in swift if k in backend]
    report.ok(f"{scope}: {len(aligned)} 个字段两端都在册"
              f"（Swift {len(swift)} / 后端 {len(backend)}）")


def run(root: Path, gate: bool = False) -> int:
    swift_path = root / SWIFT_REL
    print(f"→ 双端对齐门禁（Swift DTO ↔ Mongoose schema）  root={root}")
    if gate:
        # 门禁模式与默认模式阻塞集相同（无豁免项），打印出来避免读日志时误以为放宽了。
        print("  门禁模式：阻塞 D0（解析失败）/ D1（Swift 有、后端未登记）；D2/D3 为 WARN")
    report = Report()
    try:
        swift_text = strip_swift_comments(swift_path.read_text(encoding="utf-8"))
    except OSError as exc:
        print(f"  ✗ [D0] 读不到 Swift 源 {swift_path}：{exc}")
        print("\n⛔ 双端对齐门禁未通过：FAIL 1 / WARN 0")
        return 1

    for label, struct_name, model_name in PAIRS:
        print(f"\n[{label}]")
        try:
            swift = swift_fields(swift_text, struct_name)
            backend = backend_paths(root / BACKEND_MODELS_REL / model_name)
        except ParseError as exc:
            report.fail("D0", f"{label}: {exc}")
            continue
        compare(report, struct_name, swift, backend, swift_text)

    print()
    if report.fails:
        print(f"⛔ 双端对齐门禁未通过：FAIL {len(report.fails)} / WARN {len(report.warns)}")
        print("处置：把 Swift DTO 新增字段登记进对应 mongoose schema"
              "（给 default、不加 required，与 §4.1 惯例一致）；"
              "⛔ 不得靠删 DTO 字段或加白名单凑绿。")
        return 1
    print(f"✅ 双端对齐门禁通过：FAIL 0 / WARN {len(report.warns)}")
    return 0


# ── 构造性自测（不碰真源文件） ─────────────────────────────────────────────

INJECTED_FIELD = "    let selftestUnregisteredField: String\n"


def build_fixture(dest: Path, inject: bool) -> None:
    """把 Swift 源与后端模型复制进影子目录；node_modules 用符号链接（勿复制 100MB+）。"""
    (dest / SWIFT_REL).parent.mkdir(parents=True, exist_ok=True)
    text = (REPO_ROOT / SWIFT_REL).read_text(encoding="utf-8")
    if inject:
        anchor = "struct AngleTestDTO: Codable {\n"
        if anchor not in text:
            raise SystemExit("自测注入锚点失效：找不到 `struct AngleTestDTO: Codable {`")
        text = text.replace(anchor, anchor + INJECTED_FIELD, 1)
    (dest / SWIFT_REL).write_text(text, encoding="utf-8")
    shutil.copytree(REPO_ROOT / BACKEND_MODELS_REL, dest / BACKEND_MODELS_REL)
    (dest / "backend" / "node_modules").symlink_to(REPO_ROOT / "backend" / "node_modules")


def selftest() -> int:
    cases = [
        ("inject_unregistered_field", True, 1, "selftestUnregisteredField"),
        ("baseline_clean", False, 0, "FAIL 0"),
    ]
    bad = []
    for name, inject, want_code, want_text in cases:
        with tempfile.TemporaryDirectory(prefix=f"align-selftest-{name}-") as tmp:
            root = Path(tmp) / "root"
            build_fixture(root, inject)
            proc = subprocess.run(
                [sys.executable, str(Path(__file__).resolve()), "--root", str(root)],
                capture_output=True, text=True,
            )
        output = proc.stdout + proc.stderr
        passed = proc.returncode == want_code and want_text in output
        print("=" * 72)
        print(f"用例 {name}：{'在影子副本的 AngleTestDTO 注入后端未登记字段' if inject else '未改动的影子副本（对照组）'}")
        print(output.rstrip())
        print(f"期望：退出码 {want_code} 且输出含 {want_text!r}；实测退出码 {proc.returncode}")
        print(f"结果：{'PASS —— 检查行为符合预期' if passed else 'FAIL —— 检查行为不符预期'}")
        if not passed:
            bad.append(name)
    print("=" * 72)
    print(f"构造性用例：{len(cases) - len(bad)}/{len(cases)} 符合预期")
    for name in bad:
        print(f"  ✗ {name}")
    return 1 if bad else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--gate", action="store_true", help="门禁模式（pre-push 入口；阻塞集与默认相同）")
    parser.add_argument("--root", default=str(REPO_ROOT), help="仓库根（构造性用例可指向影子副本）")
    parser.add_argument("--selftest", action="store_true",
                        help="构造性自测：在影子副本注入未登记字段，断言门禁真会 FAIL")
    args = parser.parse_args()
    if args.selftest:
        return selftest()
    return run(Path(args.root).resolve(), gate=args.gate)


if __name__ == "__main__":
    sys.exit(main())
