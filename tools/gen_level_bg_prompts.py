# -*- coding: utf-8 -*-
"""Generate docs/level_background_ai_prompts_1-100.md from game level data."""
from __future__ import annotations

import os

WEATHER_CN = ["晴朗", "雨天", "风暴", "浓雾"]
TERRAIN_CN = ["平原", "山地", "城市", "森林", "沙漠"]
ENERGY_CN = ["常规能量场", "强能量场", "虚空裂隙", "纳米雾场"]
TOD_CN = ["黎明", "白昼", "黄昏", "夜晚"]

WEATHER_EN = {
    "晴朗": "clear sky with soft layered clouds",
    "雨天": "overcast rainy sky, cool gray-blue atmosphere, light rain haze",
    "风暴": "stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image)",
    "浓雾": "foggy sky, low visibility mist, diffused light",
}
TERRAIN_EN = {
    "平原": "open plains horizon, distant low ridges",
    "山地": "layered mountain ranges fading into atmospheric perspective",
    "城市": "distant city skyline silhouettes, industrial roofs and chimneys",
    "森林": "dense forest canopy line, broken treelines",
    "沙漠": "dune silhouettes, heat shimmer suggestion (subtle, still image)",
}
TOD_EN = {
    "黎明": "dawn light, warm-cool gradient, soft morning glow",
    "白昼": "daylight, balanced exposure, clear readability",
    "黄昏": "golden hour, long shadows, amber rim light",
    "夜晚": "night scene, cool moonlight or distant searchlights (no figures operating them)",
}
ENERGY_EN = {
    "常规能量场": "subtle normal battlefield atmosphere, no flashy magic",
    "强能量场": "faint cyan electric haze along horizon, tasteful sci-fi undertone",
    "虚空裂隙": "thin purple-void aurora streaks in sky, subtle dimensional shimmer",
    "纳米雾场": "soft silver nano-fog band above midground, tech-mist readability",
}

def faction_cn_for(level: int) -> str:
    if 1 <= level <= 20:
        return "钢壁防务（Iron Wall Corp）"
    if 21 <= level <= 40:
        return "新星兵工（Nova Arms）"
    if 41 <= level <= 60:
        return "以太动力（Aether Dynamics）"
    if 61 <= level <= 80:
        return "量子后勤（Quantum Logistics）"
    if 81 <= level <= 90:
        return "螺旋侦察（Helix Recon）"
    if 91 <= level <= 100:
        return "虚空相位（Void Research）"
    return ""

DESCS: list[str] = []
# WW1
DESCS.extend(
    [
        "晨曦中的索姆河，第一阶段突破作战",
        "泥泞的堡垒区，持续的炮火覆盖",
        "被摧毁的村庄，废墟中的阵地防守",
        "铁丝网阵地，手对手的肉搏战",
        "山丘阵地，视野开阔的攻防战",
        "林地密林，丛林中的游击战",
        "河道要塞，水上运输线的争夺",
        "工业区废墟，工厂遗骸中的激战",
        "平原冲锋，大规模骑兵冲锋战",
        "山谷陷阱，敌方伏击的突围战",
        "补给站争夺，后勤线的防守战",
        "机关枪阵地，死神镰刀的扫射",
        "堑壕防线，步步为营的攻坚",
        "炮火覆盖区，地狱之火的轰炸",
        "城市街道，巷战中的血战",
        "沙地要塞，沙漠中的防御",
        "森林伏击，林间突袭战",
        "鼓动全线，最后的总攻",
        "指挥中枢，敌方司令部争夺战",
        "胜利时刻，一战结束前夜的最后一战",
    ]
)
# WW2
DESCS.extend(
    [
        "不列颠空战，欧洲战场开启",
        "北非沙漠，隆美尔的雄狮之师",
        "苏联前线，莫斯科保卫战",
        "太平洋岛屿，日军防线",
        "诺曼底滩头，D日登陆作战",
        "莱茵河防线，德军最后堡垒",
        "太平洋反攻，岛屿争夺战",
        "柏林前夜，欧洲战场最后冲刺",
        "硫黄岛，血肉磨坊的战场",
        "荷兰冻土，冬季防线突破",
        "法国解放，巴黎光复在即",
        "德国心脏，柏林之战",
        "中国战场，日军在亚洲的最后据点",
        "东南亚，丛林中的绞肉机",
        "缅甸阵地，丛林战的极端",
        "日本本土，最终决战前的岛屿战",
        "冲绳血战，太平洋战争最后的岛屿",
        "原子弹之影，核武的威胁",
        "战争机器，二战巅峰之作",
        "世界重生，新时代的开端",
    ]
)
# Cold War
DESCS.extend(
    [
        "铁幕降临，两极对峙开始",
        "朝鲜半岛，意识形态的冲突",
        "古巴导弹危机，核战争边缘",
        "越南丛林，非传统战争",
        "中东危机，石油与权力的争夺",
        "柏林危机，东西方的对峙",
        "中苏边界，社会主义阵营的裂隙",
        "中东战争，反复的冲突",
        "南美战火，冷战在美洲",
        "阿富汗苏联，帝国的陷阱",
        "东欧剧变，铁幕背后的咆哮",
        "印支战争，美苏代理人",
        "中越战争，同志的兵戈相见",
        "马岛争端，岛屿的血泪",
        "伊朗变革，伊斯兰的觉醒",
        "苏联衰落，帝国的黄昏",
        "古巴导弹，危险的边缘游走",
        "冷战峰值，对立的最高点",
        "苏联解体，帝国的终结",
        "新世界秩序，冷战的落幕",
    ]
)
# Modern
DESCS.extend(
    [
        "海湾战争，精准制导的革命",
        "科威特收复，沙漠风暴来临",
        "巴尔干战争，欧洲的创伤",
        "科索沃空袭，网络战争的开端",
        "阿富汗反恐，新型战争",
        "伊拉克战争，大规模杀伤武器之谎",
        "中东乱局，恐怖主义与反恐",
        "格鲁吉亚冲突，大国博弈",
        "南海争端，21世纪的新战场",
        "叙利亚内战，国际介入的复杂",
        "恐怖活动，看不见的敌人",
        "网络战争，虚拟空间的较量",
        "无人机时代，天空中的死神",
        "精准打击，高科技战争",
        "联合作战，多国部队协同",
        "中东重塑，大国游戏的棋盘",
        "核武危机，威慑的平衡",
        "现代战争，终极的高科技对抗",
        "多线作战，全球化的冲突",
        "和平的曙光，战争的可能性",
    ]
)
# Near future
DESCS.extend(
    [
        "人工智能觉醒，机器的反抗",
        "相位折叠，空间战争的开端",
        "量子纠缠战，微观层面的对决",
        "反重力坦克，重力的解放",
        "虚空之门，异界的入侵",
        "电磁脉冲风暴，技术的崩溃",
        "时空扭曲，时间的战争",
        "纳米虫群，微观世界的杀戮",
        "幽灵协议，谍报战的极限",
        "机械生命，生与非生的界限",
        "虚拟现实战争，两个世界的碰撞",
        "相位跳跃，维度的切割",
        "能量场对撞，物理法则的突破",
        "思想控制，精神层面的战争",
        "集群智能，群体的力量",
        "终极武器，构装纪元的巅峰",
        "多维战场，高维世界的战斗",
        "相位临界，构装纪元的终章",
        "永恒战争，循环的宿命",
        "新纪元黎明，超越一切的存在",
    ]
)

assert len(DESCS) == 100

# English midground props / silhouette themes (one per level, matches DESCS order)
MID_EN: list[str] = [
    # 1-20 WW1
    "WW1 Somme morning: shattered woods, river mist, distant craters, ruined farmhouse silhouettes, barbed wire lines, sandbag berms, low bunkers, trench traces",
    "mud fortress berms, splintered stakes, shell-scarred rises, broken trench lines, wooden posts",
    "ruined village rooftops, collapsed walls, courtyard rubble piles, defensive tooth lines",
    "dense barbed wire entanglements, stake rows, shallow fighting pits silhouettes",
    "open hill crest lines, observation posts, zigzag trench cuts on slopes",
    "forest edge with splintered trunks, mossy stumps, hidden trench mouths",
    "riverbank piers, broken bridge spans, mooring posts, water glint (background only)",
    "factory skeleton frames, rusted gantries, broken chimneys, industrial rubble",
    "wide plain horizon, distant fence lines, low earthworks, hoof-rutted ground suggestion (empty)",
    "valley mouth choke point, steep ridge silhouettes, fallen logs as barriers",
    "supply dump crates stacks (no people), tarp covers, wheel ruts, barrel clusters",
    "MG nest concrete lips, sandbag walls, embrasure shapes, spent brass piles (static props)",
    "deep zigzag trenches, duckboards suggestion, parapet sandbags, communication trenches",
    "charred tree spikes, smoke-stained ground, crater lips, scattered shell casings",
    "narrow street ruins, barricade debris, shattered windows, cobble patches",
    "desert redoubt silhouettes, stone sangars, wind fences, distant watchtower",
    "forest ambush corridor: ferns, fallen timber, low earth berms",
    "multiple parallel trench lines, flagless poles, distant signal masts",
    "command bunker bulkhead shapes, antenna masts, sandbag revetments, map table NOT visible (no interior story)",
    "WW1 armistice dawn: quiet battlefield, lowered barriers, distant crosses silhouette-free of figures",
    # 21-40 WW2
    "Battle of Britain mood: distant airfield strips, radar tower lattice, empty radar bunkers, reinforced perimeter fences",
    "North Africa: rolling dunes, escarpment lines, oasis palms sparse, vehicle track patterns",
    "Eastern Front winter: snow fields, birch trunks, ruined brick blocks, ice river crack",
    "Pacific atoll: palm clusters, coral rock, bunker pours, beach obstacles",
    "Normandy beach: sea wall blocks, hedgehog obstacles, shattered bunkers, tidal flats",
    "Rhine riverbank: pontoon remnants, bunker teeth, vineyard terraces",
    "Pacific island ridgeline: coconut logs, coconut bunker, rope nets",
    "Berlin suburb ruins: apartment shells, tram wires hanging, rubble mountains",
    "Iwo Jima ash slopes: sharp volcanic grit, cave mouths dark, cable reels",
    "Netherlands winter: frozen canals, windmill silhouette, dike roads",
    "Paris liberation mood: barricade furniture piles, tricolor faded on wall (no text), cafe awning ruins",
    "Berlin center: shattered colonnade, statue plinth empty, tram wreck",
    "Chinese river town ruins: tile roofs collapsed, stone bridge arch",
    "SE Asia jungle: bamboo thickets, laterite red soil berms, river glint",
    "Burma trail: rope bridge silhouette, monsoon mud shine, elephant grass (no animals)",
    "Japanese home island coast: sheer cliffs, tunnel mouths, shore batteries",
    "Okinawa ridge: tombs stone walls, mud slides, cave vents",
    "atomic dread sky: tall cumulus, subtle lens flare, silent city silhouette",
    "factory assembly hall skeleton, crane rails, tank hull shapes covered (no crew)",
    "VE-day dawn: confetti-like paper on ground, quiet street, bunting shapes without letters",
    # 41-60 Cold War
    "iron curtain fence double lines, watchtower cones, snow patrol road",
    "Korean ridge war: rice paddies terraces, snow caps, bunker huts",
    "Caribbean missile launch pad silhouettes, palm ridges, blockhouse",
    "Vietnam triple canopy line, bamboo thickets, punji stake fields (props only)",
    "Middle East oil derricks, pipeline on sand ridge, flare stack",
    "Berlin Wall concrete segments, death strip gravel, tower lights",
    "Sino-Soviet border posts, birch forest, snow drifts",
    "Golan-like ridges: terraced fields, bunker teeth, dust",
    "South American jungle favela silhouettes on hill, river brown",
    "Afghan mountain pass switchbacks, cave mouths, stone sangars",
    "Eastern Europe square: toppled statue pedestal, cobble churned",
    "Indochina river delta: mangrove fingers, sampan wrecks, dike roads",
    "Karst hills China-Vietnam: sharp peaks, rice wet mirrors",
    "Falklands rocky grass, stone walls, peat trenches",
    "Iranian city minaret silhouettes, burning oil drum props (no people)",
    "Soviet industrial taiga: radar domes, missile train garage mouths",
    "Caribbean bay: radar dome, pier fences, storm sky",
    "nuclear test observation towers distant, desert flats, caution tapes",
    "Moscow winter skyline faint, red stars removed, generic spires",
    "UN-blue mood open plaza: modern glass, peace dove statue without text",
    # 61-80 Modern
    "Desert Storm highway of death mood WITHOUT vehicles with crews: abandoned hull silhouettes far, oil smoke, desert heat",
    "Kuwait oil fires distant orange glow, sand berms, highway cut",
    "Balkan ruined brutalist atrium, sniper pockmarks, snow slush",
    "Kosovo command center exterior: satellite dishes, sandbag wall modern",
    "Afghan mountain firebase: HESCO walls, comms poles, gravel",
    "Iraq palm boulevard ruins: checkpoint concrete, rust barrels",
    "Middle East souk alley ruined, hanging wires, tarp roofs",
    "Caucasus mountain road blast cuts, concrete dragon teeth",
    "South China Sea island runway: reef ring, radar dome, sea cyan",
    "Syria aleppo-like rubble canyon, bent rebar, dust",
    "urban terror scene props: abandoned bus, caution tape abstract, no victims",
    "cyberwar server stacks outdoor camouflage, fiber trunks, LED hum",
    "drone ground control shelter: antenna farm, gravel, distant runway",
    "JDAM scorch marks on hangar, precision holes, foam panels",
    "joint ops camp: multinational tent colors abstract, helipad H mark minimal",
    "desert FOB expansion: container stacks, T-wall lines, dust devils",
    "nuclear silo hatch landscape: fence coils, warning stripes no text",
    "stealth hangar black wedge, heat tiles, rain",
    "global map room exterior generic: glass HQ, flagpoles without flags",
    "peace memorial plaza: water pool, dove sculpture abstract, sunrise",
    # 81-100 Near Future
    "awakened AI server citadel: glowing server cliffs, red eye LEDs in architecture (not faces)",
    "folded space: duplicated cliff slices, parallax glitch, mirrored peaks",
    "quantum lab battleground: interference fringes in air, lattice glow",
    "anti-grav test track: floating rocks, blue glow under hull shapes (empty)",
    "void gate arch: black ellipse, purple rim, alien desert",
    "EMP storm city: dark towers, lightning crawls on metal",
    "time warp battlefield: clock melt on tower, split sky colors",
    "nano swarm haze: metallic mist band, eaten metal edges",
    "ghost protocol plaza: holo statues blank-faced (no faces), glass shards",
    "bio-mechanical ridge: cable vines, rib arches, no creatures",
    "VR glitch forest: pixel leaves, neon seams, real mud mix",
    "phase jump cliffs: sliced terrain cubes floating slightly",
    "colliding energy domes: two color fields meeting, ground crack",
    "mind control tower: obelisk with halo rings, empty streets",
    "swarm drone dock: hex pads, charging lights, no drones flying",
    "ultimate weapon silo: massive circular door, warning bands no text",
    "hypercube shadow on ground: 4D hint, impossible geometry far",
    "phase critical sky: aurora cracks, ground glassified",
    "eternal war loop: same trench copied in circle, subtle",
    "new dawn obelisk light beam: clean desert, old rust tanks tiny far",
]

assert len(MID_EN) == 100

NEGATIVE_EN = (
    "characters, people, soldiers, infantry, human silhouettes, enemies, monsters, "
    "weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, "
    "aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, "
    "skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, "
    "text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, "
    "blocked lane, top-down view, isometric, strong perspective distortion, fisheye, "
    "photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, "
    "low resolution, messy composition, duplicate lanes"
)

ERAS = [
    (0, "World War I", "Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy"),
    (1, "World War II", "Nova Arms style: olive drab + rust orange + steel gray, industrial war economy"),
    (2, "Cold War", "Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension"),
    (3, "Modern", "Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB"),
    (4, "Near Future", "Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints"),
]


def env_for(level: int) -> tuple[str, str, str, str]:
    era = (level - 1) // 20
    i = (level - 1) % 20 + 1
    w = WEATHER_CN[(era * 5 + i) % 4]
    t = TERRAIN_CN[(era + i) % 5]
    e = ENERGY_CN[(era * 3 + i) % 4]
    d = TOD_CN[i % 4]
    return w, t, e, d


def scene_cn(level: int, w: str, t: str, e: str, d: str) -> str:
    return f"{w}、{t}、{d}、{e}；{faction_cn_for(level)}战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。"


def build_prompt(level: int) -> str:
    w, t, e, d = env_for(level)
    era_idx = (level - 1) // 20
    _, era_name, palette = ERAS[era_idx]
    desc = DESCS[level - 1]
    mid = MID_EN[level - 1]
    boss = level in (20, 40, 60, 80, 100)

    # Stage 1: match approved reference (Somme dawn + post-rain) while keeping data-driven hints.
    if level == 1:
        sky = (
            "Top 65%: dawn sky with layered blue-cyan distant mountains, soft clouds, morning light; "
            "light post-rain cool gray-blue haze and wet atmosphere; "
            f"{TERRAIN_EN[t]}; "
            f"{ENERGY_EN[e]} integrated subtly into sky and horizon readability."
        )
    else:
        sky = (
            f"Top 65%: {TOD_EN[d]}, {WEATHER_EN[w]}; {TERRAIN_EN[t]}; "
            f"{ENERGY_EN[e]} integrated subtly into sky and horizon readability."
        )
    middle = f"Middle 20%: transition zone — {mid}. Era: {era_name}. {palette}."
    lane = (
        "Bottom 15%: one single main battle lane running straight from left to right across the entire frame; "
        "lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). "
        "Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; "
        "lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. "
        "near side-view perspective, sharp edges, unbroken, not curved, not occluded. "
        "Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. "
        "Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. "
        "Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, "
        "short communication trench openings — must NOT intrude into the lane silhouette."
    )
    mp18_note = (
        ' Thematically aligned with roster theme "Stage 1 — Infantry Squad · MP18" (no soldiers, no weapons depicted).'
        if level == 1
        else ""
    )
    theme = (
        f'Theme must match Phase War Stage {level} background — narrative cue: "{desc}" '
        f"(no text in image).{mp18_note}"
        f'{" BOSS STAGE finale mood — extra epic sky, still no characters." if boss else ""}'
    )
    style = (
        "Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, "
        "readable composition, no characters, no combat VFX, no text, 16:9 horizontal."
    )
    header = (
        "16:9 horizontal 2D mobile game scene with fixed 3-layer composition "
        "(top 65% sky / middle 20% midground transition / bottom 15% single battle lane)."
    )
    return "\n".join([header, sky, middle, lane, theme, style, "", f"Negative prompt: {NEGATIVE_EN}"])


def main() -> None:
    root = os.path.join(os.path.dirname(__file__), "..")
    out_path = os.path.join(root, "docs", "level_background_ai_prompts_1-100.md")
    lines: list[str] = [
        "# Phase War — 关卡 1–100 场景图 AI 提示词",
        "",
        "本文档由 `tools/gen_level_bg_prompts.py` 生成；与 `data/level_information.gd` 关卡文案及 `_get_environment_for_era_level` 环境循环对齐。",
        "每张图：**无角色、无怪物、无 UI、无文字**；**16:9 横版**；**固定三层构图**（上 65% 天空/远景、中 20% 过渡带、下 15% 唯一主战斗车道）。",
        "**第 1 关**英文 Top 65% 在数据环境之上强化了「索姆河黎明 + 青蓝远山 + 雨后微湿」，以贴合已验证的 Stage 1 参考图；中文「场景说明」仍为数据表字段。",
        "",
        "---",
        "",
    ]
    for level in range(1, 101):
        w, t, e, d = env_for(level)
        desc = DESCS[level - 1]
        cn_scene = scene_cn(level, w, t, e, d)
        era_idx = (level - 1) // 20
        _, era_name, _ = ERAS[era_idx]
        lines.append(f"## 第 {level} 关（{era_name}）")
        lines.append("")
        lines.append(f"**关卡介绍：** {desc}")
        lines.append("")
        lines.append(f"**场景说明：** {cn_scene}")
        lines.append("")
        lines.append("### English prompt（复制到生图工具）")
        lines.append("")
        lines.append("```text")
        lines.append(build_prompt(level))
        lines.append("```")
        lines.append("")
        lines.append("### 负面提示词（中文备忘，与 English 中 Negative 一致）")
        lines.append("")
        lines.append(
            "角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、"
            "血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、"
            "S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、"
            "模糊、低分辨率、构图杂乱、重复多条车道。"
        )
        lines.append("")
        lines.append("---")
        lines.append("")

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("Wrote", out_path)


if __name__ == "__main__":
    main()
