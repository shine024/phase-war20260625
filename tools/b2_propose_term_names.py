#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次②提案填充辅助（Task 0 最小实现——仅 --sample 模式）。

设计出处：docs/统一化/plans/2026-09-08-批次2-文案收编计划.md §2.1；
命名规则宪法：docs/统一化/LANGUAGE_BIBLE.md 第四章（卡 R1–R5／改造 R-改1–R-改4）。

当前范围（Task 0 样例审批门）：
  --sample：卡（UCT）与改造（mods 十文件）两源各打印前 3 对「原名→提案」到 stdout，
  不写 CSV——供用户审批军语化基调。全量模式（CSV 填充＋合并保护＋报告统计）留 Task 1。

卡名规则引擎（§2.1；R4 已裁决乙案军语化）：
  1. 解析事实标签（定位/时代/档位/敌专属/实名标记）；
  2. 兵种词根＝R1 十三类映射；支援细分（旧名含 炮/迫击→炮兵，含 高射/防空→防空）；
  3. 平台特征词＝关键词表抽取：旧名含拉丁/数字实名 → weapon_label 优先（R4 乙案：
     实名不再入卡名、武器名即描述原型句载体），否则旧名优先、weapon_label 兜底；
     两处都抽不到 → 定位词兜底；
  4. 建制后缀＝R3 档位映射：普通/老练→班（支援系→组）、精英→排、精英头目→连、
     Boss→营、堡垒→要塞级、终极→独立称谓保留原名；装甲/空中系按 R2 不用建制后缀；
  5. 合成模板 {兵种}·{平台词}{建制}（ww1_mp18 → 步兵·冲锋枪班）；
  6. 碰撞检测（硬要求，全表视野计算）：同名提案先追加档位字、再追加时代字；
     仍撞 → 提案留空并标记「需人工」；
  7. 已合规名（终极独立称谓／守护者系／无实名且模板输出=旧名）→ 提案＝原名。

改造名规则引擎（R-改1–R-改3 最小实现）：
  1. 「改装」禁令（R-改2）：现名含「改装」→ 替换为「改造」；
  2. 游戏黑话字根（本能/收割/狂暴/嗜血）→ 自动提案留空标「需人工」
     （如 enh_shield_kill「收割本能」——prototype「战意觉醒」同为非军语词根，
     军语化候选由人工定名，见 docs/统一化/批次2-样例审批.md 样例 6）；
  3. 其余视为已合规（军语名词性短语、无禁用词）→ 提案＝原名。
     （全量禁用词扫描由 b2_scan_banned_words.py 承担，Task 1 落地。）

工程约束：零第三方依赖（标准库 only）；Windows 控制台强制 UTF-8 输出；
解析套路拷贝自 tools/gen_term_mapping_draft.py（已验证），不 import——彼脚本无模块化出口。
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UCT_PATH = ROOT / "data" / "unified_card_table.gd"
MODS_DIR = ROOT / "data" / "modification_modules"

# 改造源文件扫描顺序（沿用 gen_term_mapping_draft.py 已验证顺序；标签为兵种归属）
MOD_FILES: list[tuple[str, str]] = [
    ("infantry_mods.gd", "步兵"),
    ("armor_mods.gd", "装甲"),
    ("artillery_mods.gd", "炮兵"),
    ("anti_air_mods.gd", "防空"),
    ("air_mods.gd", "空军"),
    ("recon_mods.gd", "侦察"),
    ("engineer_mods.gd", "工兵"),
    ("fort_mods.gd", "堡垒"),
    ("universal_mods.gd", "通用"),
    ("enhancement_mods.gd", "全局强化"),
]

# ── UCT 字段值 → 中文标签（出处：unified_card_table.gd 头部字段说明）──
ERA_NAMES = {0: "一战", 1: "二战", 2: "冷战", 3: "现代", 4: "近未来", 5: "星冥"}
KIND_NAMES = {0: "轻装", 1: "装甲", 2: "支援", 3: "空中", 4: "堡垒"}
TIER_NAMES = {
    "GRUNT": "普通", "VETERAN": "老练", "ELITE": "精英", "CHAMPION": "精英头目",
    "BOSS": "Boss", "ULTIMATE": "终极", "FORT": "堡垒",
}

# ── 卡名引擎词表 ──
BRANCH_BY_KIND = {0: "步兵", 1: "装甲", 3: "空军", 4: "堡垒"}  # kind 2 支援细分见 branch_word()
SUPPORT_GUN_HINTS = ("炮", "迫击")   # 旧名含 → 炮兵
SUPPORT_AA_HINTS = ("高射", "防空")  # 旧名含 → 防空

# 平台特征词表（§2.1 规则 3；长词优先，命中即取）
PLATFORM_KEYWORDS = [
    "突击步枪", "自行火炮", "重机枪", "冲锋枪", "迫击炮", "野战炮", "榴弹炮",
    "装甲车", "战斗机", "轰炸机", "无人机", "步枪", "机枪", "火炮", "坦克",
    "雷达", "医疗", "工兵", "突击", "装甲",
]
PLATFORM_KEYWORDS.sort(key=len, reverse=True)

# 纯中译实名盲区词根（宪法第四章 R4「标记盲区」子条——不含拉丁/数字、机械标记不中，
# 命中即视同含实名）。样例级词根表，Task 1 全量模式再扩。
CN_REALNAME_ROOTS = [
    "毛瑟", "李恩菲尔德", "维克斯", "圣沙蒙", "加兰德", "波波沙", "勃朗宁",
    "铁拳", "巴祖卡", "虎式", "四号", "马克", "汤普森", "罗尔斯", "兰彻斯特",
    "暴风突击队", "谢尔曼",
]

# R3 档位→建制后缀：(地面系, 支援系)；None＝独立称谓（保留原名骨架）
TIER_SUFFIX = {
    "GRUNT": ("班", "组"),
    "VETERAN": ("班", "组"),
    "ELITE": ("排", "排"),
    "CHAMPION": ("连", "连"),
    "BOSS": ("营", "营"),
    "FORT": ("要塞级", "要塞级"),
    "ULTIMATE": None,
}

# 碰撞消歧追加字（§2.1 规则 6：先档位字、再时代字；档位字取军语短词）
TIER_DISAMBIG = {
    "GRUNT": "普通", "VETERAN": "老练", "ELITE": "精锐", "CHAMPION": "头目",
    "BOSS": "首领", "ULTIMATE": "终极", "FORT": "要塞",
}

# ── 改造名引擎词表 ──
MOD_JARGON_ROOTS = ("本能", "收割", "狂暴", "嗜血")  # 游戏黑话字根 → 需人工军语化


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:  # 容错：历史文件偶有 BOM/换行差异
        return path.read_text(encoding="utf-8-sig")


# ────────────── 解析正则（拷贝自 gen_term_mapping_draft.py，已验证） ──────────────

RE_TABLE_START = re.compile(r"^const _TABLE\s*:\s*Array\s*=\s*\[", re.M)
RE_TABLE_END = re.compile(r"^\]", re.M)
RE_CARD_ENTRY = re.compile(r'\{"card_id"\s*:\s*"([^"]+)"')
RE_CARD_NAME = re.compile(r'"display_name"\s*:\s*"([^"]*)"')
RE_CARD_WLABEL = re.compile(r'"weapon_label"\s*:\s*"([^"]*)"')
RE_CARD_ERA = re.compile(r'"era"\s*:\s*(\d+)')
RE_CARD_KIND = re.compile(r'"combat_kind"\s*:\s*(\d+)')
RE_CARD_TIER = re.compile(r"Tier\.([A-Z]+)")
RE_CARD_ENEMY = re.compile(r'"enemy_only"\s*:\s*true')

RE_DATA_START = re.compile(r"^const DATA\s*:\s*Dictionary\s*=\s*\{", re.M)
RE_MOD_ENTRY = re.compile(r'^[ \t]*"([^"]+)"[ \t]*=[ \t]*\{', re.M)
RE_MOD_NAME = re.compile(r'\bname\b[ \t]*=[ \t]*"([^"]*)"')  # \b 排除 name_en
RE_MOD_PROTO = re.compile(r'\bprototype\b[ \t]*=[ \t]*"([^"]*)"')


def parse_cards() -> list[dict]:
    """解析 UCT _TABLE 数组（定界防表后辅助函数误配），返回事实标签行。"""
    text = _read(UCT_PATH)
    m = RE_TABLE_START.search(text)
    if not m:
        raise SystemExit(f"[FATAL] 未找到 const _TABLE 起始：{UCT_PATH}")
    e = RE_TABLE_END.search(text, m.end())
    if not e:
        raise SystemExit(f"[FATAL] 未找到 _TABLE 收口 ]：{UCT_PATH}")
    span = text[m.end(): e.start()]

    starts = list(RE_CARD_ENTRY.finditer(span))
    rows: list[dict] = []
    for i, s in enumerate(starts):
        chunk = span[s.start(): starts[i + 1].start() if i + 1 < len(starts) else len(span)]
        nm = RE_CARD_NAME.search(chunk)
        if not nm:
            print(f"[WARN] 卡条目 {s.group(1)} 缺 display_name，跳过", file=sys.stderr)
            continue
        wl = RE_CARD_WLABEL.search(chunk)
        era = RE_CARD_ERA.search(chunk)
        kind = RE_CARD_KIND.search(chunk)
        tier = RE_CARD_TIER.search(chunk)
        rows.append({
            "id": s.group(1),
            "name": nm.group(1),
            "wlabel": wl.group(1) if wl else "",
            "era": int(era.group(1)) if era else -1,
            "era_label": ERA_NAMES.get(int(era.group(1)), f"时代{era.group(1)}") if era else "时代?",
            "kind": int(kind.group(1)) if kind else -1,
            "tier": tier.group(1) if tier else "",
            "enemy": bool(RE_CARD_ENEMY.search(chunk)),
        })
    return rows


def parse_mods() -> list[dict]:
    """解析 10 个 *_mods.gd 的 DATA 字典（扫到文件尾——依据见 gen 脚本头注释）。"""
    rows: list[dict] = []
    for fname, label in MOD_FILES:
        path = MODS_DIR / fname
        text = _read(path)
        m = RE_DATA_START.search(text)
        if not m:
            raise SystemExit(f"[FATAL] 未找到 const DATA 起始：{path}")
        span = text[m.end():]

        starts = list(RE_MOD_ENTRY.finditer(span))
        for i, s in enumerate(starts):
            chunk = span[s.start(): starts[i + 1].start() if i + 1 < len(starts) else len(span)]
            nm = RE_MOD_NAME.search(chunk)
            if not nm:
                print(f"[WARN] 改造条目 {s.group(1)}（{fname}）缺 name，跳过", file=sys.stderr)
                continue
            proto = RE_MOD_PROTO.search(chunk)
            rows.append({
                "id": s.group(1),
                "name": nm.group(1),
                "prototype": proto.group(1) if proto else "",
                "file": fname,
                "branch": label,
            })
    return rows


# ────────────────────────── 卡名规则引擎（R1–R5） ──────────────────────────

def has_realname(name: str) -> bool:
    """实名标记：拉丁字母/数字（机械判定）＋ 纯中译实名盲区词根（宪法 R4 子条）。"""
    if re.search(r"[A-Za-z0-9]", name):
        return True
    return any(root in name for root in CN_REALNAME_ROOTS)


def branch_word(card: dict) -> str:
    """R1 兵种词根；支援系（kind 2）按旧名关键词细分（§2.1 规则 2）。"""
    kind = card["kind"]
    if kind == 2:
        if any(h in card["name"] for h in SUPPORT_GUN_HINTS):
            return "炮兵"
        if any(h in card["name"] for h in SUPPORT_AA_HINTS):
            return "防空"
        return "支援"
    return BRANCH_BY_KIND.get(kind, "支援")


def platform_word(card: dict) -> str | None:
    """平台特征词（§2.1 规则 3）：拉丁/数字实名卡 weapon_label 优先（武器名=原型句
    载体），纯中译/无名卡旧名优先；另一池兜底；均无 → None（调用方定位词兜底）。"""
    if re.search(r"[A-Za-z0-9]", card["name"]):
        pools = (card["wlabel"], card["name"])
    else:
        pools = (card["name"], card["wlabel"])
    for pool in pools:
        for kw in PLATFORM_KEYWORDS:
            if kw in pool:
                return kw
    return None


def tier_suffix(card: dict, branch: str) -> str | None:
    """R3 档位→建制后缀；支援系（支援/炮兵/防空）低档用「组」。None＝独立称谓。"""
    pair = TIER_SUFFIX.get(card["tier"])
    if pair is None:
        return None
    return pair[1] if branch in ("支援", "炮兵", "防空") else pair[0]


def propose_card(card: dict) -> tuple[str, str]:
    """单卡提案：返回 (提案名, 规则依据说明)。"""
    name, tier = card["name"], card["tier"]
    # 规则 7：终极独立称谓（「铁壁守护者·一战」式保留骨架）／守护者系（R3/R5）
    if tier == "ULTIMATE" or "守护者" in name or card["id"].startswith("guardian_"):
        return name, "已合规：独立称谓/守护者系（R3/R5）→保留"
    branch = branch_word(card)
    plat = platform_word(card) or KIND_NAMES.get(card["kind"], "单位")
    suffix = tier_suffix(card, branch)
    if suffix is None:
        return name, "独立称谓档（R3）→保留原名"
    if card["kind"] in (1, 3):
        proposal = f"{branch}·{plat}"  # R2：装甲/空中系不用建制后缀
        tmpl = "R2 装甲/空中系：{兵种}·{平台}"
    else:
        proposal = f"{branch}·{plat}{suffix}"
        tmpl = "R4 乙案军语化：{兵种}·{平台}{建制}"
    # 规则 7：无实名且结构已合 → 原名，减少无谓改动
    if not has_realname(name) and proposal == name:
        return name, "已合规：结构已合 R2 且无实名→保留"
    return proposal, tmpl


def resolve_collisions(rows: list[dict]) -> None:
    """碰撞检测（§2.1 规则 6，硬要求）：全表顺序消歧——先档位字、再时代字、
    仍撞留空标「需人工」。就地更新 rows（proposal/note 字段）。"""
    taken: set[str] = set()
    for r in rows:
        p = r["proposal"]
        if not p:
            continue
        if p not in taken:
            taken.add(p)
            continue
        tier_w = TIER_DISAMBIG.get(r["tier"], TIER_NAMES.get(r["tier"], r["tier"] or "?"))
        c1 = f"{p}·{tier_w}"
        if c1 not in taken:
            r["proposal"], r["note"] = c1, "碰撞消歧：+档位字"
            taken.add(c1)
            continue
        c2 = f"{c1}·{r['era_label']}"
        if c2 not in taken:
            r["proposal"], r["note"] = c2, "碰撞消歧：+档位字+时代字"
            taken.add(c2)
            continue
        r["proposal"], r["note"] = "", "同名未消歧→需人工"


# ───────────────────────── 改造名规则引擎（R-改1–R-改3） ─────────────────────────

def propose_mod(mod: dict) -> tuple[str, str]:
    """单条改造提案：返回 (提案名, 规则依据说明)。"""
    name = mod["name"]
    if "改装" in name:  # R-改2「改装」禁令
        return name.replace("改装", "改造"), "R-改2：「改装」→「改造」"
    if any(root in name for root in MOD_JARGON_ROOTS):
        # R-改3：军事术语优先于游戏黑话——黑话字根且 prototype 非军语词根，机械不可靠
        return "", f"游戏黑话字根；prototype「{mod['prototype']}」非军语词根→需人工"
    return name, "已合规：军语名词性短语→保留"


# ───────────────────────────────── sample 模式 ─────────────────────────────────

def run_sample() -> None:
    cards = parse_cards()
    mods = parse_mods()

    # 卡：全表计算（碰撞检测需全量视野），仅打印前 3
    card_rows = []
    for c in cards:
        p, reason = propose_card(c)
        card_rows.append({**c, "proposal": p, "reason": reason, "note": ""})
    resolve_collisions(card_rows)

    # 改造：全表计算（统计口径），仅打印前 3
    mod_rows = []
    for m in mods:
        p, reason = propose_mod(m)
        mod_rows.append({**m, "proposal": p, "reason": reason})

    print("== 卡牌源 data/unified_card_table.gd（前 3 / 全表 %d 已过碰撞检测）==" % len(card_rows))
    for r in card_rows[:3]:
        note = f"；{r['note']}" if r["note"] else ""
        line = f"  [卡] {r['id']} | {r['name']} → {r['proposal'] or '（留空·需人工）'} | {r['reason']}{note}"
        print(line)

    print("== 改造源 data/modification_modules/（前 3 / 全表 %d）==" % len(mod_rows))
    for r in mod_rows[:3]:
        print(f"  [改] {r['id']} | {r['name']} → {r['proposal'] or '（留空·需人工）'} | {r['reason']}")

    # 全表统计（碰撞消歧/留空规模即风险#3 的量化呈现）
    c_prop = sum(1 for r in card_rows if r["proposal"])
    c_disambig = sum(1 for r in card_rows if r["note"].startswith("碰撞消歧"))
    c_human = sum(1 for r in card_rows if not r["proposal"])
    c_keep = sum(1 for r in card_rows if r["proposal"] == r["name"])
    m_prop = sum(1 for r in mod_rows if r["proposal"])
    m_human = sum(1 for r in mod_rows if not r["proposal"])
    print("—— 全表统计 ——")
    print(f"  卡：提案非空 {c_prop}/{len(card_rows)}（其中保留原名 {c_keep}、消歧 {c_disambig}）；留空需人工 {c_human}")
    print(f"  改造：提案非空 {m_prop}/{len(mod_rows)}；留空需人工 {m_human}")
    print("（--sample 仅打印；CSV 填充/合并保护留 Task 1 全量模式）")


def main() -> None:
    ap = argparse.ArgumentParser(
        description="批次②提案填充辅助（Task 0 仅 --sample；规则见 LANGUAGE_BIBLE 第四章）")
    ap.add_argument("--sample", action="store_true",
                    help="样例模式：卡/改造两源各打印前 3 对提案（Task 0 审批门）")
    args = ap.parse_args()

    try:  # Windows 控制台 GBK 防 mojibake
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

    if not args.sample:
        print("Task 0 仅实现 --sample（全量 --write 模式留 Task 1 落地）。")
        print("用法：python tools/b2_propose_term_names.py --sample")
        return
    run_sample()


if __name__ == "__main__":
    main()
