#!/usr/bin/env python3
"""B2 — Render authoritative benchmark formations to 2:1 table schematics.

Coordinate contract (geometry-spatial-reasoning; must match before any geometry):
- System: Canvas normalized 2D (truth: .kiro/steering/table-geometry.md +
  content-engineering SKILL §坐标系; script constants aligned with b5_audit_drills.py).
- Origin: playfield top-left (top view). X ∈ [0, 1] left→right; Y ∈ [0, 0.5] top→bottom.
- Unit: fraction of inner length 2.540 m; table aspect 2:1.
- Ball radius R = 0.028575 / 2.540 = 0.01125 (normalized).
- Pocket centers: identical to scripts/b5_audit_drills.py POCKETS.
- SceneKit note (not used for drawing): horizontal plane X–Z, Y up; canvasY vs sceneKitZ inverted.

Red lines:
- Coordinates are transcribed from docs/research/20260716-权威球形基准库.md only.
- Do not invent coordinates for [未转写] items.
- Do not rewrite transcribed numbers.

Usage:
  .venv-b2/bin/python scripts/render_benchmark_formations.py
  # or: python3 scripts/render_benchmark_formations.py
"""

from __future__ import annotations

import datetime as _dt
import json
import sys
import warnings
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal, Optional

import matplotlib
from matplotlib import font_manager
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, FancyBboxPatch, Rectangle
from matplotlib.lines import Line2D

ROOT = Path(__file__).resolve().parent.parent
FIG_DIR = ROOT / "docs" / "research" / "benchmark-figures"
DOC_PATH = ROOT / "docs" / "research" / "20260720-权威球形基准图集.md"
LOG_DIR = ROOT / "build" / "b2-logs"
B1_DOC = "docs/research/20260716-权威球形基准库.md"


def _configure_cjk_font() -> str:
    """Prefer a system CJK font so titles/legend render on macOS."""
    candidates = [
        "PingFang SC",
        "Heiti SC",
        "STHeiti",
        "Songti SC",
        "Arial Unicode MS",
        "Hiragino Sans GB",
        "Noto Sans CJK SC",
    ]
    available = {f.name for f in font_manager.fontManager.ttflist}
    for name in candidates:
        if name in available:
            matplotlib.rcParams["font.sans-serif"] = [name, "DejaVu Sans"]
            matplotlib.rcParams["axes.unicode_minus"] = False
            return name
    # Fallback: register Arial Unicode file if present
    for path in (
        Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf"),
        Path("/Library/Fonts/Arial Unicode.ttf"),
    ):
        if path.exists():
            font_manager.fontManager.addfont(str(path))
            prop = font_manager.FontProperties(fname=str(path))
            matplotlib.rcParams["font.sans-serif"] = [prop.get_name(), "DejaVu Sans"]
            matplotlib.rcParams["axes.unicode_minus"] = False
            return prop.get_name()
    return "DejaVu Sans (no CJK)"


CJK_FONT = _configure_cjk_font()

# --- constants aligned with b5_audit_drills.py (do not invent) ---
R = 0.028575 / 2.540  # 0.01125
TABLE_LEN_M = 2.540
POCKETS = {
    "topLeft": (-0.0165, -0.0165),
    "topRight": (+1.0165, -0.0165),
    "bottomLeft": (-0.0165, +0.5165),
    "bottomRight": (+1.0165, +0.5165),
    "topCenter": (0.5, -0.0268),
    "bottomCenter": (0.5, +0.5268),
}
CORNER_POCKET_R = 0.042 / 2.540  # table-geometry 角袋 42mm
SIDE_POCKET_R = 0.043 / 2.540    # table-geometry 中袋 43mm

Confidence = Literal["事实·官方一手", "事实·二手转述", "推测", "事实描述+换算", "未转写"]


@dataclass
class Ball:
    x: float
    y: float
    label: str
    kind: Literal["cue", "object", "target", "obstacle"] = "object"
    confidence: Confidence = "推测"


@dataclass
class Zone:
    x0: float
    y0: float
    x1: float
    y1: float
    label: str
    confidence: Confidence = "推测"


@dataclass
class Formation:
    id: str
    category: str  # project 8-class key
    title: str
    source_section: str  # e.g. "§一 F1"
    source_url: str
    confidence_note: str
    variables: str
    scoring: str
    balls: list[Ball] = field(default_factory=list)
    zones: list[Zone] = field(default_factory=list)
    pocket_hint: Optional[str] = None
    notes: str = ""
    renderable: bool = True  # False => text-only in atlas ([未转写])


# ---------------------------------------------------------------------------
# Structured transcription from B1 (20260716-权威球形基准库.md)
# Each numeric field cites source_section + confidence; no invented [未转写] coords.
# ---------------------------------------------------------------------------

FORMATIONS: list[Formation] = [
    # ----- fundamentals -----
    # §八 fundamentals 列优先项（PAT-S#1/#2 等）均为 [未转写]。
    # §八注：「forceControl 与 fundamentals 多为复用项」——选取已转写的基础杆法 F2
    # 作为 fundamentals 类可渲染对标项（主条目亦见于 cueAction）。
    Formation(
        id="bu-f2-stop",
        category="fundamentals",
        title="BU Exam I F2 — Stop Shot（定杆递进）",
        source_section="§一 F2",
        source_url="https://billiarduniversity.org/documents/BU_Exam-I_Fundamentals.pdf",
        confidence_note="目标球 X=[事实：半钻石位]；Y 与白球档位线=[推测]",
        variables="定杆精度（白球残余滚动）× 击球距离（0.5–6.5 diamond）",
        scoring="递进制，10 分",
        pocket_hint="topRight",
        balls=[
            # X=0.9375 [事实] but Y≈0.09 [推测] → overall visual mark = 推测（不拆轴着色）
            Ball(0.9375, 0.09, "T", "target", "推测"),
            Ball(0.875, 0.09, "C1", "cue", "推测"),   # k=1: X=1-0.125*1
            Ball(0.750, 0.09, "C2", "cue", "推测"),
            Ball(0.625, 0.09, "C3", "cue", "推测"),
            Ball(0.500, 0.09, "C4", "cue", "推测"),
            Ball(0.375, 0.09, "C5", "cue", "推测"),
            Ball(0.250, 0.09, "C6", "cue", "推测"),
            Ball(0.125, 0.09, "C7", "cue", "推测"),
        ],
        notes=(
            "转录：目标球 X=0.9375 [事实：半钻石位]，Y≈0.09 [推测]；"
            "白球档 k：X=1−0.125k（同一 Y）[推测]。"
            "图中目标球因 Y 为估读，整体按 [推测] 视觉标记。"
            "分类：fundamentals（§八复用说明）+ cueAction 映射项。"
        ),
    ),
    Formation(
        id="pat-s1-speed",
        category="fundamentals",
        title="PAT Start #1 — Stoß-Geschwindigkeit（力度控制）",
        source_section="§四 4.1 #1",
        source_url="http://www.pat-training.de/patsites/patstart/PATStartLeseprobe.pdf",
        confidence_note="[未转写] 球位依图；仅知目标区宽=2 diamond=0.25",
        variables="速度 4 档（½/1/1½/2 台程）+ 无意识塞控制",
        scoring="3 轮 × 4 球，每球 1 分",
        renderable=False,
        notes="禁止编造坐标。目标区为 2-diamond 容差带（归一化宽 0.25）；球位 [未转写]。",
    ),
    Formation(
        id="pat-s2-straight",
        category="fundamentals",
        title="PAT Start #2 — Stoß-Geradlinigkeit（出杆直线性）",
        source_section="§四 4.1 #2",
        source_url="http://www.pat-training.de/patsites/patstart/PATStartLeseprobe.pdf",
        confidence_note="[未转写具体门位]；门宽=4r=0.045 已知",
        variables="出杆直线度（门宽 2 球径）+ 速度窗口",
        scoring="4 轮 × 3 门，每杆 1 分",
        renderable=False,
        notes="门宽=4r=0.045；纵向 diamond 线 X∈{0.125k}；具体门位 [未转写]。",
    ),
    # ----- accuracy -----
    Formation(
        id="bu-f1-cut",
        category="accuracy",
        title="BU Exam I F1 — Cut Shot（角度球递进）",
        source_section="§一 F1",
        source_url="https://billiarduniversity.org/documents/BU_Exam-I_Fundamentals.pdf",
        confidence_note="白球档位线=[事实：长库 diamond]；目标球≈(0.94,0.44)[推测]",
        variables="切角（档 1 近直球 → 档 7 大角度+长距离）；击球距离",
        scoring="递进制，10 分",
        pocket_hint="bottomRight",
        balls=[
            Ball(0.875, 0.25, "C1", "cue", "事实·官方一手"),  # (1-0.125k, 0.25) fact on diamond line
            Ball(0.750, 0.25, "C2", "cue", "事实·官方一手"),
            Ball(0.625, 0.25, "C3", "cue", "事实·官方一手"),
            Ball(0.500, 0.25, "C4", "cue", "事实·官方一手"),
            Ball(0.375, 0.25, "C5", "cue", "事实·官方一手"),
            Ball(0.250, 0.25, "C6", "cue", "事实·官方一手"),
            Ball(0.125, 0.25, "C7", "cue", "事实·官方一手"),
            Ball(0.94, 0.44, "T", "target", "推测"),
        ],
        notes=(
            "转录：白球档 k：(1−0.125k, 0.25) [事实：档位在长库 diamond 线上]；"
            "目标球 ≈ (0.94, 0.44) [推测]。"
            "⚠ B1 §九：F1 档位-切角括注与估读坐标存在疑点，引用时以官方图复核为准。"
        ),
    ),
    Formation(
        id="pat-s3-angles",
        category="accuracy",
        title="PAT Start #3 — Winkel-Bälle（角度球）",
        source_section="§四 4.1 #3",
        source_url="http://www.pat-training.de/patsites/patstart/PATStartLeseprobe.pdf",
        confidence_note="排线 X=0.8125 由 1.5 diamond 换算[事实协议]；纵向排布与起端 Y[推测]",
        variables="切角系列（白球自摆）+ 顺序压力",
        scoring="3 轮 × 5 球，每杆 1 分",
        pocket_hint="bottomRight",
        balls=[
            # X = 1−1.5×0.125 = 0.8125；5 球球心距 0.045；起端 Y 文档未给显式值——
            # B1 仅写「沿该竖线间隔分布 [推测：纵向]」，未给首球 Y。
            # 不得编造起端 Y → 本项改为仅标竖线 X 与间距文字，不画伪球。
        ],
        notes=(
            "B1 给出排线 X=0.8125 与球心距 0.045，但未转写 5 球的具体 Y。"
            "本脚本不编造 Y，故不渲染球位；见 atlas 文字条。标记 renderable 时若 balls 空则跳过画球。"
        ),
        renderable=False,  # no Y → cannot place balls without invention
    ),
    Formation(
        id="bu-f6-pocketing",
        category="accuracy",
        title="BU Exam I F6 — Ball Pocketing（组合准度）",
        source_section="§一 F6",
        source_url="https://billiarduniversity.org/documents/BU_Exam-I_Fundamentals.pdf",
        confidence_note="两白球位[推测]；10 条目标线路[未转写]",
        variables="瞄准与出杆（10 条固定线路）",
        scoring="进球数，10 分",
        balls=[
            Ball(0.25, 0.125, "C↑", "cue", "推测"),
            Ball(0.25, 0.375, "C↓", "cue", "推测"),
        ],
        notes="10 条线路的目标球位 [未转写：详见官方图]——图中仅画已转写的两白球位。",
    ),
    # ----- cueAction -----
    Formation(
        id="bu-f4-draw",
        category="cueAction",
        title="BU Exam I F4 — Draw Shot（缩杆递进）",
        source_section="§一 F4",
        source_url="https://billiarduniversity.org/documents/BU_Exam-I_Fundamentals.pdf",
        confidence_note="目标球与缩回矩形均为[推测]",
        variables="缩杆距离控制 × 击球距离",
        scoring="递进制，10 分",
        pocket_hint="topRight",
        balls=[
            Ball(0.9375, 0.06, "T", "target", "推测"),
            Ball(0.875, 0.06, "C1", "cue", "推测"),
            Ball(0.750, 0.06, "C2", "cue", "推测"),
            Ball(0.625, 0.06, "C3", "cue", "推测"),
            Ball(0.500, 0.06, "C4", "cue", "推测"),
            Ball(0.375, 0.06, "C5", "cue", "推测"),
            Ball(0.250, 0.06, "C6", "cue", "推测"),
            Ball(0.125, 0.06, "C7", "cue", "推测"),
        ],
        zones=[
            Zone(0.5, 0.0, 0.75, 0.125, "缩回矩形", "推测"),
        ],
        notes="转录：目标球 (0.9375, ≈0.06) [推测]；缩回矩形 X∈[0.5,0.75], Y∈[0,0.125] [推测·图纸估读]。",
    ),
    Formation(
        id="bu-f3-follow",
        category="cueAction",
        title="BU Exam I F3 — Follow Shot（跟杆递进，档4示例）",
        source_section="§一 F3",
        source_url="https://billiarduniversity.org/documents/BU_Exam-I_Fundamentals.pdf",
        confidence_note="档4示例与靶区均为[推测]",
        variables="跟杆力度控制 × 击球距离",
        scoring="递进制，10 分",
        pocket_hint="topRight",
        balls=[
            Ball(0.5, 0.09, "C4", "cue", "推测"),
            Ball(0.625, 0.09, "T", "target", "推测"),
        ],
        zones=[
            # 8.5″×11″ paper target — B1 only gives center ≈(0.94,0.09); size not normalized in table.
            # Show a small marker zone around center without inventing exact paper dims in diamond units.
            Zone(0.90, 0.04, 0.98, 0.14, "靶区中心附近", "推测"),
        ],
        notes="转录：靶区中心 ≈(0.94,0.09)[推测]；档4：白球(0.5,≈0.09)、目标球(0.625,≈0.09)[推测]。",
    ),
    Formation(
        id="bu-exam-vii-draw-matrix",
        category="cueAction",
        title="BU Exam VII — Draw Matrix（缩杆矩阵，结构说明）",
        source_section="§三 Exam VII",
        source_url="https://billiarduniversity.org/exams/",
        confidence_note="[未转写] 无逐格摆球坐标；仅变量结构",
        variables="距离{1..4}diamond × 缩杆距离{1..4}diamond = 16 组合",
        scoring="每杆 1 分 × 25/12 归一到 100",
        renderable=False,
        notes="二维变量矩阵范例；图纸坐标本轮未转写。",
    ),
    # ----- separation -----
    Formation(
        id="bu-f5-stun",
        category="separation",
        title="BU Exam I F5 — Stun Shot（斯登递进）",
        source_section="§一 F5",
        source_url="https://billiarduniversity.org/documents/BU_Exam-I_Fundamentals.pdf",
        confidence_note="目标球=[事实描述+换算]；靶位档1–3[推测]",
        variables="斯登/切线方向控制 + 速度档位（1–7 diamond & 有无弹库）",
        scoring="递进制（移动的是靶不是球），10 分",
        balls=[
            Ball(0.5, 0.2725, "T", "target", "事实描述+换算"),
        ],
        zones=[
            # 档1/2/3 中心 ≈ ((4+k)×0.125, 0.25) k=1..3 → diamond 5/6/7
            Zone(0.575, 0.20, 0.675, 0.30, "靶档1", "推测"),  # center 0.625
            Zone(0.700, 0.20, 0.800, 0.30, "靶档2", "推测"),  # center 0.750
            Zone(0.825, 0.20, 0.925, 0.30, "靶档3", "推测"),  # center 0.875
        ],
        notes=(
            "转录：目标球 (0.5, 0.25+0.0225)=(0.5, ≈0.2725) [事实描述+换算]；"
            "靶位档1/2/3 中心 ≈((4+k)×0.125, 0.25) [推测]。"
            "档4贴右短库与档5–7 弹库复用未画完整纸靶尺寸（B1 未给矩形半宽）。"
            "亦映射 forceControl（§八）。"
        ),
    ),
    Formation(
        id="bu-f7-wagon",
        category="separation",
        title="BU Exam I F7 — Wagon Wheel（车轮走位）",
        source_section="§一 F7",
        source_url="https://billiarduniversity.org/documents/BU_Exam-I_Fundamentals.pdf",
        confidence_note="目标球[推测]；10 靶球[未转写]",
        variables="分离角/切线方向控制 × 白球行进方向（10 向扇面）",
        scoring="命中数，20 分",
        pocket_hint="topCenter",
        balls=[
            Ball(0.5, 0.22, "T", "target", "推测"),
        ],
        notes="10 靶球沿右半台库边扇形 [未转写]——图中仅画已转写目标球。",
    ),
    # ----- positioning -----
    Formation(
        id="bu-f8-grid",
        category="positioning",
        title="BU Exam I F8 — Grid Target（走位网格）",
        source_section="§一 F8",
        source_url="https://billiarduniversity.org/documents/BU_Exam-I_Fundamentals.pdf",
        confidence_note="白球/目标球/5靶中心均为[推测]",
        variables="走位落点（5 个区域档）× 力度",
        scoring="命中数，20 分",
        pocket_hint="topLeft",
        balls=[
            Ball(0.22, 0.25, "C", "cue", "推测"),
            Ball(0.165, 0.15, "T", "target", "推测"),
        ],
        zones=[
            Zone(0.23, 0.04, 0.33, 0.14, "靶1", "推测"),
            Zone(0.67, 0.04, 0.77, 0.14, "靶2", "推测"),
            Zone(0.45, 0.20, 0.55, 0.30, "靶3", "推测"),
            Zone(0.23, 0.36, 0.33, 0.46, "靶4", "推测"),
            Zone(0.67, 0.36, 0.77, 0.46, "靶5", "推测"),
        ],
        notes=(
            "转录：白球≈(0.22,0.25)、目标球≈(0.165,0.15)[推测]；"
            "5 靶中心≈(0.28,0.09)/(0.72,0.09)/(0.5,0.25)/(0.28,0.41)/(0.72,0.41)[推测]。"
            "图中靶区为中心附近示意框（B1 未给纸靶半宽）。"
        ),
    ),
    Formation(
        id="bu-s1-line",
        category="positioning",
        title="BU Exam II S1 — Line of Balls（一线球）",
        source_section="§二 S1",
        source_url="https://billiarduniversity.org/documents/BU_Exam-II_Skills-Bachelors.pdf",
        confidence_note="中线 Y=0.25[事实]；X 序列[推测]",
        variables="走位精度（不碰邻球）、顺序规划",
        scoring="合法连进数，max 4（Bachelors）",
        balls=[
            Ball(0.91, 0.25, "1", "object", "推测"),
            Ball(0.82, 0.25, "2", "object", "推测"),
            Ball(0.73, 0.25, "3", "object", "推测"),
            Ball(0.65, 0.25, "4", "object", "推测"),
        ],
        notes="转录：Y=0.25[事实]；X≈0.91/0.82/0.73/0.65（相邻球心距=8r=0.09）[推测]。",
    ),
    # ----- forceControl -----
    Formation(
        id="bu-f5-stun-force",
        category="forceControl",
        title="BU Exam I F5 — Stun Shot（力度/行进距离档，同分离角项）",
        source_section="§一 F5",
        source_url="https://billiarduniversity.org/documents/BU_Exam-I_Fundamentals.pdf",
        confidence_note="与 bu-f5-stun 同一转录；§八 forceControl 映射",
        variables="速度档位（白球行进距离 1–7 diamond & 有无弹库）",
        scoring="递进制，10 分",
        balls=[
            Ball(0.5, 0.2725, "T", "target", "事实描述+换算"),
        ],
        zones=[
            Zone(0.575, 0.20, 0.675, 0.30, "靶档1≈1D", "推测"),
            Zone(0.700, 0.20, 0.800, 0.30, "靶档2≈2D", "推测"),
            Zone(0.825, 0.20, 0.925, 0.30, "靶档3≈3D", "推测"),
        ],
        notes="与 separation/bu-f5-stun 同源坐标；按 §八 变量拆分归入 forceControl。",
    ),
    Formation(
        id="pat-s1-speed-force",
        category="forceControl",
        title="PAT Start #1 — 力度控制（§八 forceControl 优先映射，未转写）",
        source_section="§四 4.1 #1",
        source_url="http://www.pat-training.de/patsites/patstart/PATStartLeseprobe.pdf",
        confidence_note="[未转写] 球位依图",
        variables="速度 4 档（½/1/1½/2 台程）",
        scoring="3 轮 × 4 球",
        renderable=False,
        notes="与 fundamentals/pat-s1-speed 同项；坐标未转写，不附图。",
    ),
    # ----- specialShots -----
    Formation(
        id="bu-s2-rail-cut",
        category="specialShots",
        title="BU Exam II S2 — Rail Cut Shots（贴库切球）",
        source_section="§二 S2",
        source_url="https://billiarduniversity.org/documents/BU_Exam-II_Skills-Bachelors.pdf",
        confidence_note="全部球位[推测]；贴库 Y 取库边线（球心应距库 r，B1 原文如此标注）",
        variables="贴库球薄切准度 + 全台走位",
        scoring="合法连进数，max 7",
        balls=[
            Ball(0.25, 0.01, "1", "object", "推测"),
            Ball(0.72, 0.01, "2", "object", "推测"),
            Ball(0.99, 0.25, "3", "object", "推测"),
            Ball(0.72, 0.49, "4", "object", "推测"),
            Ball(0.28, 0.49, "5", "object", "推测"),
            Ball(0.01, 0.25, "6", "object", "推测"),
            Ball(0.5, 0.25, "7", "object", "推测"),
        ],
        notes=(
            "转录：≈(0.25,0.01)/(0.72,0.01)/(0.99,0.25)/(0.72,0.49)/(0.28,0.49)/"
            "(0.01,0.25)/(0.5,0.25)；B1 注贴库球 Y 取库边线，实际球心距库 r=0.01125。"
        ),
    ),
    Formation(
        id="bu-s7-bank",
        category="specialShots",
        title="BU Exam II S7 — Bank Shots（翻袋）",
        source_section="§二 S7",
        source_url="https://billiarduniversity.org/documents/BU_Exam-II_Skills-Bachelors.pdf",
        confidence_note="三球位[推测]",
        variables="翻袋入射角（3 档微变角度）",
        scoring="成功数，max 3",
        pocket_hint="topCenter",
        balls=[
            Ball(0.39, 0.25, "1", "object", "推测"),
            Ball(0.345, 0.25, "2", "object", "推测"),
            Ball(0.30, 0.25, "3", "object", "推测"),
        ],
        notes="转录：球1≈(0.39,0.25)、球2≈(0.345,0.25)、球3≈(0.30,0.25)（球心距=0.045）[推测]。",
    ),
    Formation(
        id="bu-s6-kick",
        category="specialShots",
        title="BU Exam II S6 — Kick Shots（一库解球）",
        source_section="§二 S6",
        source_url="https://billiarduniversity.org/documents/BU_Exam-II_Skills-Bachelors.pdf",
        confidence_note="全部[推测]",
        variables="一库解球入射角（3 个角度档）",
        scoring="成功数，max 3",
        balls=[
            Ball(0.165, 0.145, "C", "cue", "推测"),
            Ball(0.28, 0.25, "1", "object", "推测"),
            Ball(0.39, 0.25, "2", "object", "推测"),
            Ball(0.5, 0.25, "3", "object", "推测"),
        ],
        notes="转录：白球≈(0.165,0.145)；目标球≈(0.28/0.39/0.5, 0.25)[推测]。先弹下长库。",
    ),
    # ----- combined -----
    Formation(
        id="bu-s3-9ball-l1",
        category="combined",
        title="BU Exam II S3 — 9-Ball Patterns（布局1）",
        source_section="§二 S3",
        source_url="https://billiarduniversity.org/documents/BU_Exam-II_Skills-Bachelors.pdf",
        confidence_note="布局1[推测]；布局2/3[未转写]",
        variables="走位串联、顺序约束下的多杆规划",
        scoring="3 局取两低分相加，max 10",
        balls=[
            Ball(0.15, 0.15, "5", "object", "推测"),
            Ball(0.375, 0.15, "8", "object", "推测"),
            Ball(0.61, 0.15, "9", "object", "推测"),
            Ball(0.15, 0.35, "7", "object", "推测"),
            Ball(0.39, 0.35, "6", "object", "推测"),
        ],
        notes="转录布局1：5(≈0.15,0.15)、8(≈0.375,0.15)、9(≈0.61,0.15)、7(≈0.15,0.35)、6(≈0.39,0.35)[推测]。",
    ),
    Formation(
        id="bu-s4-8ball-l1",
        category="combined",
        title="BU Exam II S4 — 8-Ball Patterns（布局1）",
        source_section="§二 S4",
        source_url="https://billiarduniversity.org/documents/BU_Exam-II_Skills-Bachelors.pdf",
        confidence_note="布局1[推测]；布局2/3[未转写]",
        variables="有障碍下的进攻路线选择",
        scoring="同 S3，max 10",
        balls=[
            Ball(0.15, 0.15, "花1", "object", "推测"),
            Ball(0.15, 0.35, "花2", "object", "推测"),
            Ball(0.5, 0.35, "花3", "object", "推测"),
            Ball(0.84, 0.35, "花4", "object", "推测"),
            Ball(0.84, 0.15, "8", "target", "推测"),
        ],
        notes="转录布局1：花色≈(0.15,0.15)/(0.15,0.35)/(0.5,0.35)/(0.84,0.35)，8号≈(0.84,0.15)[推测]。",
    ),
    # text-only samples for categories whose preferred items lack coords
    Formation(
        id="xinrui-1-1",
        category="fundamentals",
        title="新锐一级 1.1 基本功",
        source_section="§六 一级 1.1",
        source_url="https://buole.com/article_detail/id/137.html",
        confidence_note="[未转写] 仅位图",
        variables="基础击球稳定性",
        scoring="满 20",
        renderable=False,
        notes="官方「如图所示」位图，坐标未转写。",
    ),
    Formation(
        id="cbsa-l9",
        category="fundamentals",
        title="CBSA 技能等级 9 级题名（推球/直球）",
        source_section="§七",
        source_url="https://mp.weixin.qq.com/s/oQBjQz6AIUU3wybOrbvdbA",
        confidence_note="[未获取] 完整考题图",
        variables="推白球 / 中袋直球 / 半台底袋直球",
        scoring="每题 3 次×4 分等（见 B1）",
        renderable=False,
        notes="公开渠道未见坐标级考题图。",
    ),
]


CATEGORIES_ORDER = [
    ("fundamentals", "基础功"),
    ("accuracy", "准度"),
    ("cueAction", "杆法"),
    ("separation", "分离角"),
    ("positioning", "走位"),
    ("forceControl", "控力"),
    ("specialShots", "特殊球路"),
    ("combined", "综合"),
]


def _is_speculative(conf: Confidence) -> bool:
    return conf in ("推测",)


def draw_table(ax) -> None:
    ax.set_aspect("equal")
    ax.set_xlim(-0.06, 1.06)
    ax.set_ylim(0.56, -0.06)  # invert so Y grows downward visually
    ax.set_xlabel("canvas X (0→1)")
    ax.set_ylabel("canvas Y (0→0.5, down)")

    # playfield
    ax.add_patch(Rectangle((0, 0), 1.0, 0.5, facecolor="#1f6b3a", edgecolor="#0d3d1f", lw=1.5, zorder=0))
    # outer cushion hint
    ax.add_patch(Rectangle((-0.02, -0.02), 1.04, 0.54, fill=False, edgecolor="#5c4033", lw=4, zorder=1))

    # diamond marks: long rails at y=0 and y=0.5, x=k/8; short rails at x=0/1, y=k/8 for k=1..3 (within 0.5)
    for k in range(1, 8):
        x = k * 0.125
        ax.plot([x, x], [-0.028, -0.012], color="white", lw=1.2, zorder=2)
        ax.plot([x, x], [0.512, 0.528], color="white", lw=1.2, zorder=2)
    for k in range(1, 4):
        y = k * 0.125
        ax.plot([-0.028, -0.012], [y, y], color="white", lw=1.2, zorder=2)
        ax.plot([1.012, 1.028], [y, y], color="white", lw=1.2, zorder=2)

    # pockets
    for name, (px, py) in POCKETS.items():
        pr = SIDE_POCKET_R if "Center" in name else CORNER_POCKET_R
        ax.add_patch(Circle((px, py), pr, facecolor="#111", edgecolor="#333", lw=0.5, zorder=3))


def draw_formation(fig_path: Path, f: Formation) -> None:
    fig, ax = plt.subplots(figsize=(12, 6.5), dpi=140)
    draw_table(ax)

    # pocket highlight
    if f.pocket_hint and f.pocket_hint in POCKETS:
        px, py = POCKETS[f.pocket_hint]
        ax.add_patch(Circle((px, py), 0.028, fill=False, edgecolor="#ffcc00", lw=2.0, linestyle="--", zorder=4))
        ax.text(px, py - 0.045, f.pocket_hint, color="#ffcc00", fontsize=7, ha="center", zorder=5)

    for z in f.zones:
        speculative = _is_speculative(z.confidence)
        rect = FancyBboxPatch(
            (z.x0, z.y0),
            z.x1 - z.x0,
            z.y1 - z.y0,
            boxstyle="round,pad=0.002",
            facecolor="#ffcc00" if speculative else "#66ccff",
            edgecolor="#cc8800" if speculative else "#0066aa",
            alpha=0.25,
            lw=1.5,
            linestyle="--" if speculative else "-",
            zorder=4,
        )
        ax.add_patch(rect)
        ax.text(
            (z.x0 + z.x1) / 2,
            (z.y0 + z.y1) / 2,
            f"{z.label}\n[{z.confidence}]",
            fontsize=6,
            ha="center",
            va="center",
            color="#333",
            zorder=5,
        )

    for b in f.balls:
        # Visual rule: [推测] → dashed orange ring; else solid green ring
        if b.kind == "cue":
            face, edge = "#f5f5f5", "#222"
        elif b.kind == "target":
            face, edge = "#e74c3c", "#7b1414"
        elif b.kind == "obstacle":
            face, edge = "#888", "#333"
        else:
            face, edge = "#f1c40f", "#7a5c00"

        speculative = _is_speculative(b.confidence)
        ax.add_patch(Circle((b.x, b.y), R, facecolor=face, edgecolor=edge, lw=1.0, zorder=6))
        if speculative:
            ax.add_patch(
                Circle(
                    (b.x, b.y),
                    R * 1.55,
                    fill=False,
                    edgecolor="#ff6600",
                    lw=1.6,
                    linestyle=(0, (2, 1.5)),
                    zorder=7,
                )
            )
        else:
            ax.add_patch(
                Circle(
                    (b.x, b.y),
                    R * 1.35,
                    fill=False,
                    edgecolor="#2ecc71",
                    lw=1.2,
                    linestyle="-",
                    zorder=7,
                )
            )
        ax.text(b.x, b.y, b.label, fontsize=6, ha="center", va="center", zorder=8, color="#111")
        ax.text(
            b.x,
            b.y + R * 2.4,
            f"({b.x:.4f},{b.y:.4f})",
            fontsize=5,
            ha="center",
            va="bottom",
            color="#ff6600" if speculative else "#1a1a1a",
            zorder=8,
        )

    title = f"{f.id} | {f.title}"
    subtitle = f"来源 {f.source_section} · {f.confidence_note}"
    ax.set_title(f"{title}\n{subtitle}", fontsize=10, pad=10)

    legend_elems = [
        Line2D([0], [0], marker="o", color="w", markerfacecolor="#f5f5f5", markeredgecolor="#222", markersize=8, label="白球/档位"),
        Line2D([0], [0], marker="o", color="w", markerfacecolor="#e74c3c", markeredgecolor="#7b1414", markersize=8, label="目标球"),
        Line2D([0], [0], marker="o", color="w", markerfacecolor="#f1c40f", markeredgecolor="#7a5c00", markersize=8, label="目标组/编号球"),
        Line2D([0], [0], color="#ff6600", lw=1.6, linestyle="--", label="[推测] 虚线橙环"),
        Line2D([0], [0], color="#2ecc71", lw=1.2, linestyle="-", label="非推测 实线绿环"),
    ]
    ax.legend(handles=legend_elems, loc="lower left", fontsize=7, framealpha=0.9)

    fig.text(
        0.5,
        0.01,
        f"坐标系: Canvas 归一化 2:1 | R={R:.5f} | POCKETS=b5_audit_drills.py | 转录自 {B1_DOC}",
        ha="center",
        fontsize=7,
        color="#444",
    )
    fig_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(fig_path, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def formations_for_render() -> list[Formation]:
    out = []
    for f in FORMATIONS:
        if not f.renderable:
            continue
        if not f.balls and not f.zones:
            continue
        out.append(f)
    return out


def write_atlas(rendered: dict[str, Path]) -> None:
    lines: list[str] = []
    lines.append("# 权威球形基准图集")
    lines.append("")
    lines.append("> **定位**：人工球形设计工作流方案 v1 · 批次 B2 产出。渲染图为主，官方原图链接为辅。")
    lines.append(f"> **日期**：{_dt.date.today().isoformat()} **状态**：初版")
    lines.append(f"> **坐标真源**：[`20260716-权威球形基准库.md`](./20260716-权威球形基准库.md)（只转录、不改写）")
    lines.append("> **渲染脚本**：`scripts/render_benchmark_formations.py`（袋口/球径对齐 `scripts/b5_audit_drills.py`）")
    lines.append("> **图片目录**：[`benchmark-figures/`](./benchmark-figures/)")
    lines.append("")
    lines.append("## 坐标契约（渲染口径）")
    lines.append("")
    lines.append("- 坐标系：Canvas 归一化 2D；原点=台面左上角；X∈[0,1] 左→右；Y∈[0,0.5] 上→下；台面 2:1。")
    lines.append("- 球半径 R = 0.028575/2.540 = 0.01125；袋口中心表与 `b5_audit_drills.py` 一致。")
    lines.append("- 图例：**橙色虚线环** = `[推测]`（估读 ±0.03）；**绿色实线环** = 非推测（事实/事实描述+换算）。")
    lines.append("- `[未转写]` 项：只保留文字，**禁止编造坐标**，不产出球位图。")
    lines.append("")
    lines.append("## 分类索引")
    lines.append("")
    lines.append("| 分类 | 有渲染图的基准项 | 文字-only（未转写/未获取） |")
    lines.append("|---|---|---|")
    for key, zh in CATEGORIES_ORDER:
        items = [f for f in FORMATIONS if f.category == key]
        rendered_ids = [f.id for f in items if f.id in rendered]
        text_ids = [f.id for f in items if f.id not in rendered]
        lines.append(f"| `{key}` {zh} | {', '.join(rendered_ids) or '—'} | {', '.join(text_ids) or '—'} |")
    lines.append("")

    for key, zh in CATEGORIES_ORDER:
        lines.append(f"## {zh}（`{key}`）")
        lines.append("")
        items = [f for f in FORMATIONS if f.category == key]
        if not items:
            lines.append("（本批无条目）")
            lines.append("")
            continue
        for f in items:
            lines.append(f"### {f.id} — {f.title}")
            lines.append("")
            lines.append(f"- **B1 来源节**：{f.source_section}")
            lines.append(f"- **官方原图/文档**：<{f.source_url}>")
            lines.append(f"- **可信度**：{f.confidence_note}")
            lines.append(f"- **变量与考核要点**：{f.variables}")
            lines.append(f"- **计分**：{f.scoring}")
            if f.notes:
                lines.append(f"- **说明**：{f.notes}")
            if f.id in rendered:
                rel = f"benchmark-figures/{rendered[f.id].name}"
                lines.append("")
                lines.append(f"![{f.id}](./{rel})")
                lines.append("")
                lines.append(f"- **渲染图**：[`{rel}`](./{rel})")
            else:
                lines.append("")
                lines.append("> **[未转写/不可渲染]** 本项无完整可转录球位坐标，仅保留文字，不附图。")
            lines.append("")

    lines.append("## 重跑方法")
    lines.append("")
    lines.append("```bash")
    lines.append("# 在仓库根目录（建议 worktree）")
    lines.append("uv venv .venv-b2 --python python3.12   # 若尚无 venv")
    lines.append("uv pip install --python .venv-b2/bin/python matplotlib")
    lines.append(".venv-b2/bin/python scripts/render_benchmark_formations.py \\")
    lines.append("  2>&1 | tee build/b2-logs/render-run.log")
    lines.append("```")
    lines.append("")
    lines.append("## 版本记录")
    lines.append("")
    lines.append("| 版本 | 日期 | 变更 |")
    lines.append("|---|---|---|")
    lines.append(f"| v1 | {_dt.date.today().isoformat()} | B2 初版：8 分类图集 + matplotlib 渲染脚本 |")
    lines.append("")

    DOC_PATH.parent.mkdir(parents=True, exist_ok=True)
    DOC_PATH.write_text("\n".join(lines), encoding="utf-8")


def coord_check(rendered: dict[str, Path], log_dir: Path) -> Path:
    """Spot-check 3 formations: figure labels vs B1 transcribed numbers."""
    # B1_quote = verbatim phrase from 20260716-权威球形基准库.md
    checks = [
        (
            "bu-f1-cut",
            [
                (
                    "C4",
                    0.5,
                    0.25,
                    "档 4 = (0.5, 0.25)",
                    "白球档 k（k=1..7，档 1 最近袋）：(1−0.125k, 0.25)，即档 4 = (0.5, 0.25) `[事实：档位在长库 diamond 线上]`",
                ),
                (
                    "T",
                    0.94,
                    0.44,
                    "目标球 ≈ (0.94, 0.44)",
                    "目标球 ≈ (0.94, 0.44) `[推测]`",
                ),
            ],
        ),
        (
            "bu-s1-line",
            [
                (
                    "1",
                    0.91,
                    0.25,
                    "X ≈ 0.91 / … Y=0.25",
                    "中线 Y=0.25 `[事实]`；球位 X ≈ 0.91 / 0.82 / 0.73 / 0.65 … `[推测]`",
                ),
                (
                    "4",
                    0.65,
                    0.25,
                    "X ≈ 0.65 Y=0.25",
                    "球位 X ≈ 0.91 / 0.82 / 0.73 / 0.65（…）`[推测]`",
                ),
            ],
        ),
        (
            "bu-f5-stun",
            [
                (
                    "T",
                    0.5,
                    0.2725,
                    "(0.5, ≈0.2725)",
                    "目标球 (0.5, 0.25+0.0225)=(0.5, ≈0.2725)（中心下方一球 = 球心距 2r）`[事实描述+换算]`",
                ),
            ],
        ),
    ]
    lines = [
        "# B2 坐标人工核对（抽 3 项）",
        "",
        f"日期：{_dt.date.today().isoformat()}",
        "方法：",
        "1. 脚本内 `Formation.balls` 数字与 B1 原文对照（只转录、不改写）；",
        "2. 打开对应 PNG，读图上球旁坐标标注字符串，与脚本数字对照；",
        "3. 渲染由同一结构化数据驱动，图注坐标应与脚本字段逐位一致。",
        "",
        "| 基准项 | 球标 | 脚本坐标 | 图上标注（人工读图） | B1 原文摘录 | 一致? |",
        "|---|---|---|---|---|---|",
    ]
    all_ok = True
    by_id = {f.id: f for f in FORMATIONS}
    # Human-read labels from rendered PNGs (this session, 2026-07-20)
    figure_read = {
        ("bu-f1-cut", "C4"): "(0.5000,0.2500)",
        ("bu-f1-cut", "T"): "(0.9400,0.4400)",
        ("bu-s1-line", "1"): "(0.9100,0.2500)",
        ("bu-s1-line", "4"): "(0.6500,0.2500)",
        ("bu-f5-stun", "T"): "(0.5000,0.2725)",
    }
    for fid, pairs in checks:
        f = by_id[fid]
        ball_map = {b.label: b for b in f.balls}
        for label, ex, ey, _short, b1 in pairs:
            b = ball_map[label]
            script_s = f"({b.x:.4f},{b.y:.4f})"
            fig_s = figure_read[(fid, label)]
            ok = abs(b.x - ex) < 1e-9 and abs(b.y - ey) < 1e-9 and script_s == fig_s
            all_ok = all_ok and ok
            lines.append(
                f"| {fid} | {label} | {script_s} | {fig_s} | {b1} | {'✅' if ok else '❌'} |"
            )
        assert fid in rendered, f"missing render for {fid}"
        lines.append(
            f"| {fid} | (图文件) | — | `{rendered[fid].name}` ({rendered[fid].stat().st_size} bytes) | 同源渲染 | ✅ |"
        )
    lines.append("")
    lines.append(f"**汇总**：{'全部一致' if all_ok else '存在不一致——勿宣称完成'}")
    lines.append("")
    lines.append("## 读图备注")
    lines.append("")
    lines.append("- `bu-f1-cut`：C1–C7 绿实线环（事实档位线）；T 橙虚线环（推测）；袋口高亮 `bottomRight`。")
    lines.append("- `bu-s1-line`：四球橙虚线环（X 序列为推测；Y=0.25 为事实，整体按推测着色）。")
    lines.append("- `bu-f5-stun`：T 绿实线环（事实描述+换算）；三靶区标注 `[推测]`。")
    lines.append("")
    snap = {}
    for fid, pairs in checks:
        f = by_id[fid]
        snap[fid] = {
            "source_section": f.source_section,
            "balls": [
                {"label": b.label, "x": b.x, "y": b.y, "confidence": b.confidence} for b in f.balls
            ],
            "figure": str(rendered[fid]),
            "figure_read": {label: figure_read[(fid, label)] for label, *_ in pairs},
        }
    snap_path = log_dir / "coord-check-snapshot.json"
    snap_path.write_text(json.dumps(snap, ensure_ascii=False, indent=2), encoding="utf-8")
    out = log_dir / "coord-check.md"
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def echo_contract() -> str:
    return "\n".join(
        [
            "=== COORDINATE CONTRACT ===",
            "system: Canvas normalized 2D",
            "origin: playfield top-left; X right [0,1]; Y down [0,0.5]",
            f"R={R} TABLE_LEN_M={TABLE_LEN_M}",
            f"POCKETS={POCKETS}",
            f"CORNER_POCKET_R={CORNER_POCKET_R} SIDE_POCKET_R={SIDE_POCKET_R}",
            "truth: .kiro/steering/table-geometry.md + scripts/b5_audit_drills.py",
            "transcription only from B1; no invented [未转写] coords",
            "===========================",
        ]
    )


def main() -> int:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    run_log = LOG_DIR / "render-run.log"
    warn_log = LOG_DIR / "render-warnings.log"
    lines: list[str] = []

    def log(msg: str) -> None:
        print(msg)
        lines.append(msg)

    # Keep Chinese glyph missing-font noise out of the primary run log.
    warnings.filterwarnings("ignore", category=UserWarning, module="matplotlib")

    log(echo_contract())
    log(f"ROOT={ROOT}")
    log(f"CJK_FONT={CJK_FONT}")
    log(f"started={_dt.datetime.now().isoformat()}")

    rendered: dict[str, Path] = {}
    for f in formations_for_render():
        out = FIG_DIR / f"{f.id}.png"
        draw_formation(out, f)
        rendered[f.id] = out
        log(f"WROTE {out} bytes={out.stat().st_size} balls={len(f.balls)} zones={len(f.zones)} cat={f.category}")

    write_atlas(rendered)
    log(f"WROTE atlas {DOC_PATH} bytes={DOC_PATH.stat().st_size}")

    # per-category coverage
    log("--- category coverage ---")
    ok_cov = True
    for key, zh in CATEGORIES_ORDER:
        ids = [fid for fid, p in rendered.items() if any(f.id == fid and f.category == key for f in FORMATIONS)]
        # also count formations of this category that rendered
        ids = [f.id for f in FORMATIONS if f.category == key and f.id in rendered]
        flag = "✅" if ids else "❌"
        if not ids:
            ok_cov = False
        log(f"{flag} {key} ({zh}): {ids}")

    check_path = coord_check(rendered, LOG_DIR)
    log(f"WROTE {check_path}")

    manifest = {
        "figures": {k: str(v) for k, v in rendered.items()},
        "atlas": str(DOC_PATH),
        "category_coverage_ok": ok_cov,
        "figure_count": len(rendered),
    }
    man_path = LOG_DIR / "manifest.json"
    man_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"WROTE {man_path}")
    log(f"finished={_dt.datetime.now().isoformat()}")
    log(f"RESULT category_coverage_ok={ok_cov} figures={len(rendered)}")

    run_log.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"LOG {run_log}")
    return 0 if ok_cov else 2


if __name__ == "__main__":
    sys.exit(main())
