#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""术语映射草稿生成器（统一化手术批次① Task 3）。

扫描两大数据源，产出 docs/统一化/term_mapping_draft.csv 审校工作台：

  1. 卡牌：data/unified_card_table.gd（UCT v8.0 单一真值源）
     - 实测结构：const _TABLE: Array = [ ... ]，条目以 {"card_id":"..."} 起；
       键名为 card_id / display_name（JSON 风格冒号语法）。
     - 解析严格限定在 _TABLE 数组跨度内（起：const _TABLE 行，止：行首 "]"）。
       现状说明：文件后部辅助函数的 3 处 display_name 均为 entry.get(...) 形态，
       冒号正则本就不匹配——定界属前瞻防御：若未来辅助代码在表后构造含
       "card_id"/"display_name" 键的字面量字典，不定界会被条目分块正则误抓。
       勿以「现状无实效」为由删除定界。
  2. 改造：data/modification_modules/*_mods.gd 共 10 文件
     - 实测结构：const DATA: Dictionary = { ... }，条目以行首 "xxx_id" = { 起；
       条目内 name = "中文名"（name_en 为英文名不收，\b 词界排除）。
     - 不设 DATA 结束定界：实测条目收口缩进不一致（infantry_mods.gd:63 首条
       目收口 "}," 在列 0，"engineer 用单行紧凑风格），行首 "}" 判界会误切；
       而「条目起始正则」与「name = " 计数」全文件实测均恰等于条目数
       （顶部 const 声明键名不带引号、尾部 static func 无 name 赋值，天然
       不误配），故自 const DATA 起扫到文件尾是安全的。
     - 存量 quirk 如实录入：engineer eng_01_mine_sweeper 的数据显示名即
       「反应装甲」（id 与名不同源，phase-war 数据现状，非解析错位）。

CSV 规格（详见 LANGUAGE_BIBLE 第四章）：
  列：id / 旧名 / 来源 / 类型 / 提案新名 / 词汇依据 / 状态
  编码 UTF-8-sig（带 BOM，Excel 兼容），逗号分隔，LF 行尾。
  提案新名列一律留空（命名规则需逐条人工审，见第四章「提案新名留空策略」；
  历史实名卡已裁决：R4 乙案军语化（2026-09-08），实名不入卡名，存活于
  描述原型句与改造名；R 标记保留供批次②审阅）；状态全「待审」。

重跑保护：默认对既有 CSV 中状态非「待审」的行（人工已裁决，保护键＝
「类型|id」复合键）保留其提案新名/词汇依据/状态三列，仅刷新事实列
（id/旧名/来源/类型）——防止误重跑冲毁审校成果；--force 可强制全量覆盖。

用法：
  python tools/gen_term_mapping_draft.py --sample   # 校准模式：每源打印前 3 对 id/名
  python tools/gen_term_mapping_draft.py            # 全量生成（默认合并保护）
  python tools/gen_term_mapping_draft.py --force    # 全量生成（覆盖人工裁决，慎用）

预期行数（2026-09-08 实测基准）：卡 231±3 / 改造 202±3；超出容差时
打印警告提示查正则或查数据源变更。
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UCT_PATH = ROOT / "data" / "unified_card_table.gd"
MODS_DIR = ROOT / "data" / "modification_modules"
OUT_PATH = ROOT / "docs" / "统一化" / "term_mapping_draft.csv"

# 10 改造文件 → 兵种中文名（第一章「兵种类名」口径；universal/enhancement 为
# 跨兵种通用位，非 13 类平台成员，类型列如实标注「通用」「全局强化」）。
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

# ── UCT 字段值 → 中文标签（出处：unified_card_table.gd 头部字段说明 41-59 行）──
ERA_NAMES = {0: "一战", 1: "二战", 2: "冷战", 3: "现代", 4: "近未来", 5: "星冥"}
KIND_NAMES = {0: "轻装", 1: "装甲", 2: "支援", 3: "空中", 4: "堡垒"}
TIER_NAMES = {
    "GRUNT": "普通",
    "VETERAN": "老练",
    "ELITE": "精英",
    "CHAMPION": "精英头目",
    "BOSS": "Boss",
    "ULTIMATE": "终极",
    "FORT": "堡垒",
}

EXPECTED_CARDS = 231
EXPECTED_MODS = 202
TOLERANCE = 3

CSV_HEADER = ["id", "旧名", "来源", "类型", "提案新名", "词汇依据", "状态"]


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:  # 容错：历史文件偶有 BOM/换行差异
        return path.read_text(encoding="utf-8-sig")


# ────────────────────────────── 卡牌（UCT） ──────────────────────────────

RE_TABLE_START = re.compile(r"^const _TABLE\s*:\s*Array\s*=\s*\[", re.M)
RE_TABLE_END = re.compile(r"^\]", re.M)
RE_CARD_ENTRY = re.compile(r'\{"card_id"\s*:\s*"([^"]+)"')
RE_CARD_NAME = re.compile(r'"display_name"\s*:\s*"([^"]*)"')
RE_CARD_ERA = re.compile(r'"era"\s*:\s*(\d+)')
RE_CARD_KIND = re.compile(r'"combat_kind"\s*:\s*(\d+)')
RE_CARD_TIER = re.compile(r"Tier\.([A-Z]+)")
RE_CARD_ENEMY = re.compile(r'"enemy_only"\s*:\s*true')


def parse_cards() -> list[dict]:
    """解析 UCT _TABLE 数组，返回 [{id, name, source, type, basis}, ...]。"""
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
        name = nm.group(1)

        tags: list[str] = []
        era = RE_CARD_ERA.search(chunk)
        kind = RE_CARD_KIND.search(chunk)
        tier = RE_CARD_TIER.search(chunk)
        tags.append(KIND_NAMES.get(int(kind.group(1)), f"定位{kind.group(1)}") if kind else "定位?")
        tags.append(ERA_NAMES.get(int(era.group(1)), f"时代{era.group(1)}") if era else "时代?")
        tags.append(TIER_NAMES.get(tier.group(1), tier.group(1)) if tier else "档次?")
        if RE_CARD_ENEMY.search(chunk):
            tags.append("敌专属")
        # 含拉丁字母/数字 = 历史实名候选（第四章 R4 裁决范围标记，机械判定）
        if re.search(r"[A-Za-z0-9]", name):
            tags.append("含实名(R4)")
        rows.append({
            "id": s.group(1),
            "name": name,
            "source": "data/unified_card_table.gd",
            "type": "卡",
            "basis": "·".join(tags) + "｜规则:第四章R1-R5",
        })
    return rows


# ────────────────────────────── 改造（mods） ──────────────────────────────

RE_DATA_START = re.compile(r"^const DATA\s*:\s*Dictionary\s*=\s*\{", re.M)
RE_MOD_ENTRY = re.compile(r'^[ \t]*"([^"]+)"[ \t]*=[ \t]*\{', re.M)
RE_MOD_NAME = re.compile(r'\bname\b[ \t]*=[ \t]*"([^"]*)"')  # \b 排除 name_en
RE_MOD_SLOT = re.compile(r'\bslot_type\b[ \t]*=[ \t]*"([^"]*)"')
RE_MOD_RARITY = re.compile(r'\brarity\b[ \t]*=[ \t]*"([^"]*)"')
RE_MOD_PROTO = re.compile(r'\bprototype\b[ \t]*=[ \t]*"([^"]*)"')


def parse_mods() -> list[dict]:
    """解析 10 个 *_mods.gd 的 DATA 字典，返回 [{id, name, source, type, basis}, ...]。"""
    rows: list[dict] = []
    for fname, label in MOD_FILES:
        path = MODS_DIR / fname
        text = _read(path)
        m = RE_DATA_START.search(text)
        if not m:
            raise SystemExit(f"[FATAL] 未找到 const DATA 起始：{path}")
        span = text[m.end():]  # 扫到文件尾（依据见文件头注释：实测无尾部误配）

        starts = list(RE_MOD_ENTRY.finditer(span))
        for i, s in enumerate(starts):
            chunk = span[s.start(): starts[i + 1].start() if i + 1 < len(starts) else len(span)]
            nm = RE_MOD_NAME.search(chunk)
            if not nm:
                print(f"[WARN] 改造条目 {s.group(1)}（{fname}）缺 name，跳过", file=sys.stderr)
                continue
            tags: list[str] = []
            slot = RE_MOD_SLOT.search(chunk)
            rarity = RE_MOD_RARITY.search(chunk)
            proto = RE_MOD_PROTO.search(chunk)
            if slot:
                tags.append(slot.group(1))
            if rarity:
                tags.append(rarity.group(1))
            if proto:
                tags.append(f"原型{proto.group(1)}")
            basis = "·".join(tags) + "｜规则:第四章R-改1-R-改4" if tags else "规则:第四章R-改1-R-改4"
            rows.append({
                "id": s.group(1),
                "name": nm.group(1),
                "source": f"data/modification_modules/{fname}",
                "type": f"改造·{label}",
                "basis": basis,
            })
    return rows


# ────────────────────────────── 合并与写出 ──────────────────────────────

def load_preserved() -> dict[str, dict]:
    """读取既有 CSV，返回 {"类型|id": row}——仅状态非「待审」的行视为人工已裁决需保护。

    保护键用「类型+id」复合键：卡与改造分属两数据源、id 各自独立编名，
    现状虽无撞名，复合键防未来两源出现同名 id 时保护错行（前瞻防御）。
    """
    preserved: dict[str, dict] = {}
    if not OUT_PATH.exists():
        return preserved
    with open(OUT_PATH, "r", encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            if row.get("id") and row.get("状态", "待审") != "待审":
                preserved[f'{row.get("类型", "")}|{row["id"]}'] = row
    return preserved


def write_csv(rows: list[dict], force: bool) -> None:
    preserved = {} if force else load_preserved()
    merged = 0
    out_rows: list[list[str]] = []
    for r in rows:
        proposal, basis, status = "", r["basis"], "待审"
        old = preserved.get(f'{r["type"]}|{r["id"]}')
        if old is not None:
            proposal = old.get("提案新名", "") or ""
            basis = old.get("词汇依据", "") or basis
            status = old.get("状态", "待审") or "待审"
            merged += 1
        out_rows.append([r["id"], r["name"], r["source"], r["type"], proposal, basis, status])

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(CSV_HEADER)
        w.writerows(out_rows)

    print(f"[OK] 写出 {OUT_PATH.relative_to(ROOT)}（as_posix: {OUT_PATH.as_posix()}）")
    print(f"     数据行 {len(out_rows)}；保留人工裁决行 {merged}（--force 可覆盖）")


def check_counts(cards: int, mods: int) -> None:
    for label, got, want in (("卡", cards, EXPECTED_CARDS), ("改造", mods, EXPECTED_MODS)):
        if abs(got - want) > TOLERANCE:
            print(f"[WARN] {label} {got} 条，超出预期 {want}±{TOLERANCE}——查正则或查数据源变更",
                  file=sys.stderr)


def main() -> None:
    ap = argparse.ArgumentParser(description="生成术语映射 CSV 草稿（详见 LANGUAGE_BIBLE 第四章）")
    ap.add_argument("--sample", action="store_true", help="校准模式：每源打印前 3 对 id/名")
    ap.add_argument("--force", action="store_true", help="覆盖人工已裁决行（默认保留保护）")
    args = ap.parse_args()

    try:  # Windows 控制台中文输出容错
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

    cards = parse_cards()
    mods = parse_mods()

    if args.sample:
        print("== 卡牌 data/unified_card_table.gd 前 3 对 ==")
        for r in cards[:3]:
            print(f"  {r['id']}  ->  {r['name']}")
        for fname, _ in MOD_FILES:
            sub = [r for r in mods if r["source"] == f"data/modification_modules/{fname}"]
            print(f"== 改造 data/modification_modules/{fname} 前 3 对（共 {len(sub)}）==")
            for r in sub[:3]:
                print(f"  {r['id']}  ->  {r['name']}")
        print(f"合计：卡 {len(cards)} / 改造 {len(mods)}")
        return

    check_counts(len(cards), len(mods))
    write_csv(cards + mods, args.force)
    print(f"     合计：卡 {len(cards)} / 改造 {len(mods)} / 总 {len(cards) + len(mods)}")


if __name__ == "__main__":
    main()
