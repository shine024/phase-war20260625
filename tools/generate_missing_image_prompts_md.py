# -*- coding: utf-8 -*-
"""Generate docs/missing_image_paths_agent_prompts.md from missing_image_paths.txt."""
from __future__ import annotations

import os
import re

REPO = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
MISSING_TXT = os.path.join(REPO, "docs", "missing_image_paths.txt")
OUT_MD = os.path.join(REPO, "docs", "missing_image_paths_agent_prompts.md")
UI_PROMPTS = os.path.join(REPO, "docs", "prompts", "ui_icon_prompts_74.md")

NEG = (
    "Negative prompt: text, watermark, logo, 3D render, photorealistic, "
    "gradient background, cluttered, multiple items"
)
NEG_ZH = "文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品"

TECH_UI = (
    "flat 2D game UI icon, centered composition, clean vector or semi-flat style, "
    "512x512, transparent or dark grey-blue background"
)

# Cross-ref: ui_icon_prompts_74.md section titles -> filename stem
FACTION_REF: dict[str, str] = {
    "iron_wall_corp": "faction_iron_wall_corp（铁壁公司）",
    "nova_arms": "faction_nova_arms（诺瓦军武）",
    "aether_dynamics": "faction_aether_dynamics（以太动力）",
    "quantum_logistics": "faction_quantum_logistics（量子物流）",
    "helix_recon": "faction_helix_recon（螺旋侦察）",
    "void_research": "faction_void_research（虚空研究所）",
    "frontier_union": "faction_frontier_union（边境联盟）",
}

STAR_REF: dict[int, str] = {
    1: "star_1（1星·铜——相位感知初现）",
    2: "star_2（2星·铜——相位感知强化）",
    3: "star_3（3星·银——相位感知成熟）",
    4: "star_4（4星·金——意志具象化）",
    5: "star_5（5星·金——意志共振）",
    6: "star_6（6星·白金——现实改写者）",
    7: "star_7（7星·钻石——超空间主宰）",
}

# Phase instrument model variants (shop/faction equipment icons)
INSTRUMENT_VISUAL: dict[str, tuple[str, str]] = {
    "pi_generic_01": ("巡航I型", "compact entry phase instrument dial, bronze trim, one slow star point on deep space blue face, rookie pilot starter kit aesthetic"),
    "pi_generic_02": ("巡航II型", "slightly larger dial with dual faint star orbits and soft cyan recovery glow ring suggesting energy recycle"),
    "pi_generic_03": ("巡航III型", "dial with expanded outer deployment range tick marks and three star points, agile scout styling"),
    "pi_generic_04": ("锋线III型", "dial with forward-pointing phase blade motif on bezel, warm amber accent for attack tuning"),
    "pi_generic_05": ("锋线IV型", "dual-layer dial rings, crossed phase strike glyphs, balanced assault module look"),
    "pi_generic_06": ("壁垒IV型", "heavy shield-shaped bezel around dial, reinforced rivet frame, defensive steel gray accents"),
    "pi_generic_07": ("壁垒V型", "fortified dial with thick armored collar and steady gold stability glow"),
    "pi_generic_08": ("脉冲V型", "dial surrounded by pulsing lightning arcs, high energy output capacitor nodes"),
    "pi_generic_09": ("脉冲VI型", "overcharged dial with red overload sector and crackling phase sparks at rim"),
    "pi_generic_10": ("星链VI型", "constellation-linked dial with six tiny node stars chained by light threads, resource focus"),
    "pi_generic_11": ("星链VII型", "seven-node star chain halo, balanced multi-stat enhancement look, silver-gold trim"),
    "pi_generic_12": ("天穹VII型", "celestial crown bezel above dial, radiant sky-gold aura, ultimate generic flagship instrument"),
    "pi_aegis_01": ("神盾-前哨", "dial on small shield outpost mount, aether dynamics silver-blue, sentry turret silhouette on bezel"),
    "pi_aegis_02": ("神盾-方阵", "square phalanx shield array framing dial, formation grid lines, defensive corporation emblem hint"),
    "pi_aegis_03": ("神盾-穹顶", "domed shield canopy over dial, layered energy panels, fortress dome silhouette"),
    "pi_aegis_04": ("神盾-壁垒核", "massive citadel core shield with radiant barrier nodes, ultimate aether dynamics fortress instrument"),
    "pi_helix_01": ("螺旋-猎线", "helix recon green spiral spine across dial, hunter sight reticle, recon line motif"),
    "pi_helix_02": ("螺旋-织网", "interwoven helix mesh net around dial, data web nodes, scout network aesthetic"),
    "pi_helix_03": ("螺旋-神经束", "dense neural helix bundle core, bright synapse flashes, advanced recon instrument"),
    "pi_nova_01": ("新星-回路", "nova arms orange circuit loop around dial, weapon circuit board traces"),
    "pi_nova_02": ("新星-灼流", "flame-wreathed dial bezel, heat distortion waves, assault firepower styling"),
    "pi_nova_03": ("新星-超弦", "hyperstring vibration lines and intense flame crown, legendary nova arms superweapon dial"),
    "pi_nova_04": ("新星-裂变庭", "fission chamber ring with particle burst spokes, kill-energy feedback glow"),
    "pi_iron_01": ("铁幕-重锚", "iron wall corp anchor bolt frame, heavy steel chains, anchored tanker dial"),
    "pi_iron_02": ("铁幕-铸链", "forged chain links encircling dial, molten steel seam highlights"),
    "pi_iron_03": ("铁幕-王座", "throne-backplate iron fortress mount, regal gunmetal and gold rivets, ultimate iron wall instrument"),
    "pi_umbra_01": ("影幕-薄刃", "void research violet thin blade slash across dial, stealth edge highlight"),
    "pi_umbra_02": ("影幕-折光", "refracted light prism shards, crit eye slit motif, shadow recon styling"),
    "pi_umbra_03": ("影幕-寂静域", "silent void dome suppressing light, dark purple haze, assassination field instrument"),
    "pi_atlas_01": ("擎天-工蜂", "quantum logistics cargo drone silhouette, worker bee logistics glyph, teal supply lines"),
    "pi_atlas_02": ("擎天-梁柱", "structural support beam frame, bridge pillar icons, logistics backbone dial"),
    "pi_atlas_03": ("擎天-桥核", "bridge core hub with radiating supply routes, heavy teal energy trunk lines"),
    "pi_eon_01": ("永纪-秒针", "frontier union gold clock hand second needle, minimal time dial ticks"),
    "pi_eon_02": ("永纪-时阶", "layered time-step rings, olive and gold chronometer stages"),
    "pi_eon_03": ("永纪-终式", "ultimate chronology crown, multi-hand temporal dial, frontier union flagship time instrument"),
    "pi_r_free_deploy": ("零成本部署", "nano-printed unit materializing from hyperspace blueprint ghost, large zero cost symbol, golden legendary aura"),
}

NEUTRAL_FACTION_PROMPT = """flat 2D faction logo icon, a balanced neutral compass rose combined with three interlocking hollow circles representing no single faction allegiance, soft silver-white and muted grey-blue palette, faint hyperspace void backdrop with dim flowing light streaks, symmetrical emblem for generic unaligned phase operators, flat clean vector style, centered on dark background, game UI faction icon, 512x512"""

STAR_8_PROMPT = """flat 2D eight-star rating icon, eight classic five-pointed stars in a gentle arc or double-row layout, brilliant platinum-silver fill with subtle prismatic edge highlights suggesting beyond-seven-star extension tier, faint hyperspace light band behind the row, centered on dark grey-blue background, game UI rarity rating icon, 512x512"""


def parse_missing_paths() -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    if not os.path.isfile(MISSING_TXT):
        return rows
    for line in open(MISSING_TXT, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"(res://\S+\.png)\s*(?:#\s*(.+))?", line)
        if m:
            rows.append((m.group(1), (m.group(2) or "").strip()))
    return rows


def instrument_prompt(pid: str, cn: str, visual: str) -> str:
    star_hint = ""
    if "VII" in cn or "7" in cn or "终式" in cn or "超弦" in cn or "王座" in cn or "壁垒核" in cn:
        star_hint = "legendary tier gold-purple rim glow, "
    elif "VI" in cn or "6" in cn or "寂静" in cn or "桥核" in cn:
        star_hint = "epic tier purple-blue rim glow, "
    elif "IV" in cn or "V" in cn or "灼流" in cn or "时阶" in cn:
        star_hint = "rare tier blue rim glow, "
    return (
        f"flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, "
        f"{visual}, {star_hint}soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, "
        f"centered on dark grey-blue background, 512x512"
    )


def section_for_path(path: str, cn: str) -> str:
    name = path.split("/")[-1]
    lines: list[str] = []

    if "/ui/factions/" in path:
        fid = name.replace("_128.png", "").replace("_32.png", "")
        size = "128" if "_128" in name else "32"
        if fid == "neutral":
            prompt = NEUTRAL_FACTION_PROMPT
            note = "中立势力；512 生成后导出 128 与 32 两版"
        else:
            ref = FACTION_REF.get(fid, fid)
            prompt = None
            note = f"完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **{ref}**；512 生成后缩放为 {size}×{size}"
        lines.append(f"### {name}（{cn}）")
        lines.append(f"**输出：** `{path}`")
        lines.append(f"**说明：** {note}")
        if prompt:
            lines.append("#### English prompt")
            lines.append("```text")
            lines.append(prompt.strip())
            lines.append("")
            lines.append(NEG)
            lines.append("```")
            lines.append(f"#### 负面提示词（中文备忘）\n{NEG_ZH}")
        else:
            lines.append(f"#### 引用\n`docs/prompts/ui_icon_prompts_74.md` 中 **{ref}** 一节。")
        return "\n\n".join(lines) + "\n"

    if "/ui/stars/" in path:
        n = int(name.replace("star_", "").replace(".png", ""))
        if n == 8:
            prompt = STAR_8_PROMPT
            note = "8 星扩展；7 星样式见 ui_icon_prompts §star_7"
        else:
            ref = STAR_REF.get(n, f"star_{n}")
            prompt = None
            note = f"见 `docs/prompts/ui_icon_prompts_74.md` → **{ref}**"
        lines.append(f"### {name}（{cn}）")
        lines.append(f"**输出：** `{path}`")
        lines.append(f"**说明：** {note}")
        if prompt:
            lines.append("#### English prompt")
            lines.append("```text")
            lines.append(prompt.strip())
            lines.append("")
            lines.append(NEG)
            lines.append("```")
            lines.append(f"#### 负面提示词（中文备忘）\n{NEG_ZH}")
        else:
            lines.append(f"#### 引用\n`docs/prompts/ui_icon_prompts_74.md` → **{ref}**。")
        return "\n\n".join(lines) + "\n"

    if "/ui/instruments/" in path:
        pid = name.replace(".png", "")
        cn2, visual = INSTRUMENT_VISUAL.get(pid, (cn, "unique phase instrument variant"))
        if pid == "pi_r_free_deploy":
            lines.append(f"### {name}（{cn}）")
            lines.append(f"**输出：** `{path}`")
            lines.append("**说明：** 稀有属性图标；完整 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **pi_r_free_deploy（自由部署）**。")
            lines.append("#### 引用\n同上（属性图标构图，非表盘型号）。")
            return "\n\n".join(lines) + "\n"
        body = instrument_prompt(pid, cn2, visual)
        lines.append(f"### {name}（{cn2}）")
        lines.append(f"**输出：** `{path}`")
        lines.append(f"**型号 ID：** `{pid}` | **势力/系列：** 见 `data/phase_instruments.gd`")
        lines.append("#### English prompt")
        lines.append("```text")
        lines.append(body)
        lines.append("")
        lines.append(NEG)
        lines.append("```")
        lines.append(f"#### 负面提示词（中文备忘）\n{NEG_ZH}")
        return "\n\n".join(lines) + "\n"

    return ""


def main() -> None:
    items = parse_missing_paths()
    parts = [
        "# 缺失图片 Agent 生图提示词（对齐 missing_image_paths.txt）",
        "",
        "**版本：** 2026-05-22",
        "**对齐：** `docs/missing_image_paths.txt`（当前仍缺项）",
        "**主文档（势力 7 + 星 1–7 + 属性 26）：** `docs/prompts/ui_icon_prompts_74.md`",
        "",
        "## 使用方式",
        "",
        "1. 势力 Logo：用 §一 或下文 **neutral**；**512×512** 生成后缩放为 `*_128.png`、`*_32.png`。",
        "2. 星级：用 `ui_icon_prompts_74.md` §二 或下文 **star_8**；保存为 `star_N.png`（非仅 128）。",
        "3. 相位仪**型号**（`pi_generic_*` / `pi_aegis_*` 等）：用本文 §三；512 生成，文件名与路径一致。",
        "4. 透明底：UI 图标可用深灰蓝底直接 PNG，或 `#00FF00` 绿幕抠图（见 `docs/ART_EXPORT_CHECKLIST_GREENSCREEN.md` §七–九）。",
        "",
        "## 统一负面提示词",
        "",
        "```text",
        NEG,
        "```",
        "",
        f"共 **{len(items)}** 条缺失项。",
        "",
        "---",
        "",
        "## 一、势力 Logo（16 文件 · 8 势力 × 2 尺寸）",
        "",
        "> 7 势力英文 prompt 在 `ui_icon_prompts_74.md` §一；此处仅补 **neutral** 与路径对照。",
        "",
    ]

    for path, cn in items:
        if "/ui/factions/" not in path:
            continue
        parts.append(section_for_path(path, cn))

    parts.extend(["", "---", "", "## 二、星级图标（8）", ""])
    for path, cn in items:
        if "/ui/stars/" not in path:
            continue
        parts.append(section_for_path(path, cn))

    parts.extend(["", "---", "", "## 三、相位仪型号图标（36）", ""])
    for path, cn in items:
        if "/ui/instruments/" not in path:
            continue
        parts.append(section_for_path(path, cn))

    open(OUT_MD, "w", encoding="utf-8").write("\n".join(parts))
    print(f"Wrote {OUT_MD} ({len(items)} items)")


if __name__ == "__main__":
    main()
