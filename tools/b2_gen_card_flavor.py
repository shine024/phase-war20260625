#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次②卡面叙述生成器（骨架）——data/card_flavor_texts.gd 草案产出。

计划出处：docs/统一化/plans/2026-09-08-批次2-文案收编计划.md §2.4 / Task 1 Step 2。
基调锚　：docs/统一化/批次2-样例审批.md 样例 1/2/3 的 flavor（军语克制／一句原型＋至多
          一句战术特征／去庆祝腔），宪法 docs/统一化/LANGUAGE_BIBLE.md 约束下生成：
          - 条目名只读不写（v2.4 终局裁决）——本工具零写 UCT，flavor 只新增不改名；
          - 数值内核——flavor 不含数值子串（机制与数值由 MECHANISM_DESC/动态模板承载）；
          - 中英混排（语气规则 6）——兵器实名照留（MP18/毛瑟G98），拉丁/数字与中文间
            补半角空格（存量卡名黏排不处理，新生成文案排版合规）。
          - 星冥缴获语境式（样例 3）:「黑门内缴获。星冥构装，无从考据其原型。」

用法：
  python tools/b2_gen_card_flavor.py                # --dry-run（默认）：统计＋样例
  python tools/b2_gen_card_flavor.py --sample 12    # 多打几条样例抽查
  python tools/b2_gen_card_flavor.py --out <PATH>   # 写 .gd 草案到任意路径
  python tools/b2_gen_card_flavor.py --write        # 落盘 data/card_flavor_texts.gd（Task 8 才用）

模板矩阵：时代(6)×兵种(5) 战术短句 ＋ 档位(7) 句式分层（普通/老练一句式、精英/头目/Boss/
终极双句式、堡垒工事式、星冥缴获语境式）。生成稿＝草案，人工抽查＋MANUAL 字典手工覆写
（运行时 MANUAL 优先于生成稿——重生成不冲掉人工修订）。

解析套路：沿用已删 tools/b2_propose_term_names.py（git 2c17aa0）／tools/gen_term_mapping_draft.py
已验证的 UCT `_TABLE` 定界正则（行扫描字典字面量），拷贝不 import。

工程约束：Python 标准库 only；Windows 显式 UTF-8。
"""

from __future__ import annotations

import argparse
import datetime as _dt
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
UCT_PATH = ROOT / "data" / "unified_card_table.gd"
DEFAULT_OUT = ROOT / "data" / "card_flavor_texts.gd"

# ── UCT 字段值 → 中文标签（出处：unified_card_table.gd 头部字段说明）──
ERA_NAMES = {0: "一战", 1: "二战", 2: "冷战", 3: "现代", 4: "近未来", 5: "星冥"}
KIND_NAMES = {0: "轻装", 1: "装甲", 2: "支援", 3: "空中", 4: "堡垒"}
TIER_NAMES = {
    "GRUNT": "普通", "VETERAN": "老练", "ELITE": "精英", "CHAMPION": "精英头目",
    "BOSS": "Boss", "ULTIMATE": "终极", "FORT": "堡垒",
}

# ── 解析正则（拷贝自 gen_term_mapping_draft.py 已验证套路，定界防表后辅助函数误配）──
RE_TABLE_START = re.compile(r"^const _TABLE\s*:\s*Array\s*=\s*\[", re.M)
RE_TABLE_END = re.compile(r"^\]", re.M)
RE_CARD_ENTRY = re.compile(r'\{"card_id"\s*:\s*"([^"]+)"')
RE_CARD_NAME = re.compile(r'"display_name"\s*:\s*"([^"]*)"')
RE_CARD_SHORT = re.compile(r'"short_name"\s*:\s*"([^"]*)"')
RE_CARD_WLABEL = re.compile(r'"weapon_label"\s*:\s*"([^"]*)"')
RE_CARD_WLIGHT = re.compile(r'"w_light"\s*:\s*"([^"]*)"')
RE_CARD_WARMOR = re.compile(r'"w_armor"\s*:\s*"([^"]*)"')
RE_CARD_WAIR = re.compile(r'"w_air"\s*:\s*"([^"]*)"')
RE_CARD_ERA = re.compile(r'"era"\s*:\s*(\d+)')
RE_CARD_KIND = re.compile(r'"combat_kind"\s*:\s*(\d+)')
RE_CARD_TIER = re.compile(r"Tier\.([A-Z]+)")
RE_CARD_ENEMY = re.compile(r'"enemy_only"\s*:\s*true')

# ── 模板矩阵：时代 × 兵种 → 战术短句（军语克制体；基调锚＝样例 1「堑壕近战中泼洒弹幕」）──
TACTIC_MATRIX: dict[int, dict[int, str]] = {
    0: {  # 一战
        0: "堑壕近战中泼洒弹幕",
        1: "突破铁丝网与堑壕",
        2: "交叉火力封锁阵地",
        3: "低空掠袭与校射",
        4: "固守要点抗击冲击",
    },
    1: {  # 二战
        0: "诸兵种协同突击",
        1: "装甲集群正面突破",
        2: "炮火准备覆盖敌前沿",
        3: "夺取局部制空权",
        4: "纵深配置层层阻击",
    },
    2: {  # 冷战
        0: "乘车机动下车战斗",
        1: "复合装甲远程对射",
        2: "快速转移炮火支援",
        3: "高空拦截与低空突击",
        4: "预设阵地待机反击",
    },
    3: {  # 现代
        0: "数字化班组精确交战",
        1: "猎歼一体远程开火",
        2: "全天候火力召唤",
        3: "体系协同空中打击",
        4: "机动防御节点抗击",
    },
    4: {  # 近未来
        0: "外骨骼增幅近距突击",
        1: "无人僚车协同突击",
        2: "定向能持续压制",
        3: "隐身突防精确拔点",
        4: "能量护幕固守待援",
    },
    5: {  # 星冥（现行 UCT 无 era=5 带——预留，落地时启用）
        0: "构装阵列近距突击",
        1: "构装装甲碾压战线",
        2: "全域火力覆盖",
        3: "轨道机动突袭",
        4: "相位护幕固守",
    },
}

# 兵种自称（样例 1「本班原型为…」句式）
KIND_NOUN = {0: "班", 1: "车", 2: "组", 3: "机", 4: "阵地"}

# 星冥缴获语境式（样例 3 逐字锚）
XENO_FLAVOR = "黑门内缴获。星冥构装，无从考据其原型。"

# 数值内核断言：flavor 禁数值子串（%／×／＋／每 N／N 秒 级/张/格…；
# 兵器实名内的数字（MP18/81mm/T-34）合法——检查前先剥去拉丁连续段）
RE_LATIN_RUN = re.compile(r"[A-Za-z0-9][A-Za-z0-9./\-]*")
RE_NUM_CORE = re.compile(r"[％%×✕＋+*]|每\s*[0-9]|[0-9]+\s*(?:秒|次|张|点|级|格|关|人)")
# 中英混排：拉丁/数字与中文之间补半角空格（语气规则 6）；CJK 区间 U+4E00–U+9FFF
_CJK = r"一-鿿"


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8-sig")


def parse_uct() -> list[dict]:
    """解析 UCT _TABLE（定界），返回卡事实行。"""
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

        def _g(rx: re.Pattern, default=None):
            mm = rx.search(chunk)
            return mm.group(1) if mm else default

        rows.append({
            "id": s.group(1),
            "name": nm.group(1),
            "short": _g(RE_CARD_SHORT, "") or "",
            "wlabel": _g(RE_CARD_WLABEL, "") or "",
            "w_light": _g(RE_CARD_WLIGHT, "") or "",
            "w_armor": _g(RE_CARD_WARMOR, "") or "",
            "w_air": _g(RE_CARD_WAIR, "") or "",
            "era": int(_g(RE_CARD_ERA, -1)),
            "kind": int(_g(RE_CARD_KIND, -1)),
            "tier": _g(RE_CARD_TIER, ""),
            "enemy": bool(RE_CARD_ENEMY.search(chunk)),
        })
    return rows


def _space_latin(text: str) -> str:
    """中英混排合规：拉丁/数字与汉字之间补半角空格（只处理边界，不动既有空格；
    纯符号段（如泛型名「冲锋枪/步枪」的斜杠）不触发加空格）。"""
    text = re.sub(rf"([A-Za-z0-9][A-Za-z0-9./\-]*)(?=[{_CJK}])", r"\1 ", text)
    text = re.sub(rf"([{_CJK}])(?=[A-Za-z0-9])", r"\1 ", text)
    return text


# 纯中译实名词根（拷自已删 b2_propose_term_names.py 的 CN_REALNAME_ROOTS——宪法 R4
# 「标记盲区」子条：不含拉丁/数字，机械实名标记不中，命中即视同含实名）
CN_REALNAME_ROOTS = (
    "毛瑟", "李恩菲尔德", "维克斯", "圣沙蒙", "加兰德", "波波沙", "勃朗宁",
    "铁拳", "巴祖卡", "虎式", "四号", "马克", "汤普森", "罗尔斯", "兰彻斯特",
    "暴风突击队", "谢尔曼",
)

# 建制后缀（display_name 兜底作原型词时剥去，避免「原型为汤普森班」式拗口）
RE_UNIT_SUFFIX = re.compile(r"(班|组|巢|排|连|营|队|车|机|群|阵地|要塞级)$")


def _strip_unit_suffix(name: str) -> str:
    return RE_UNIT_SUFFIX.sub("", name.strip())


def _display_proto(name: str) -> str:
    """display_name 兜底作原型词：剥建制后缀；敌卡「步兵班·MP18」式复合名取
    含实名（拉丁/数字或中译词根）的「·」段——两段皆无实名则保留全名交人工判。"""
    s = name.strip()
    if "·" in s:
        segs = [RE_UNIT_SUFFIX.sub("", seg.strip()) for seg in s.split("·")]
        for seg in segs[1:]:  # 首段多为兵种/建制前缀，从第二段起找实名
            if seg and (re.search(r"[A-Za-z0-9]", seg) or any(r in seg for r in CN_REALNAME_ROOTS)):
                return seg
    return RE_UNIT_SUFFIX.sub("", s)


def _weapon_of(card: dict) -> str:
    """实名载体（§2.4）：weapon_label/w_light 优先，display_name（剥建制后缀）兜底；
    含拉丁/数字实名者 > 中译实名（词根表）> 第一个非空候选（泛型武器名）。"""
    label = _space_latin(card["wlabel"].strip())
    light = _space_latin(card["w_light"].strip())
    dname = _space_latin(_display_proto(card["name"]))
    for w in (label, light, dname):
        if w and re.search(r"[A-Za-z0-9]", w):
            return w
    if dname and any(root in dname for root in CN_REALNAME_ROOTS):
        return dname
    for w in (label, light, dname):
        if w:
            return w
    return ""


def _tactic(card: dict) -> str:
    return TACTIC_MATRIX.get(card["era"], TACTIC_MATRIX[0]).get(card["kind"], "列阵接战")


def _glue(prefix: str, token: str) -> str:
    """前缀以汉字结尾且 token 以拉丁/数字开头时补一个半角空格（语气规则 6）。"""
    if token and re.match(r"[A-Za-z0-9]", token) and prefix and re.search(rf"[{_CJK}]$", prefix):
        return prefix + " " + token
    return prefix + token


def make_flavor(card: dict) -> str:
    """单卡 flavor 草案——档位分层句式（§2.4 三档模板＋堡垒/星冥特化）。"""
    era, kind, tier = card["era"], card["kind"], card["tier"]
    era_w = ERA_NAMES.get(era, "未知时代")
    noun = KIND_NOUN.get(kind, "队")
    weapon = _weapon_of(card)
    tactic = _tactic(card)

    # 星冥缴获语境式（样例 3）：星冥带 / xeno 系卡专用
    if era == 5 or "xeno" in card["id"]:
        return XENO_FLAVOR

    if tier == "FORT":
        s = _glue("驻防工事以", weapon) + "为主器。"
        return s + tactic + "，寸土不让。"
    if tier in ("GRUNT", "VETERAN"):
        s = _glue(f"本{noun}原型为", weapon) + "，" + tactic
        return s + "。" if tier == "GRUNT" else s + "，久经战阵。"
    if tier == "ELITE":
        return f"{era_w}战线拣选的老兵骨干。" + _glue("原型为", weapon) + f"，{tactic}。"
    if tier == "CHAMPION":
        return (f"{era_w}战线拣选的先锋{noun}。" + _glue("原型为", weapon)
                + f"，{tactic}，火力与耐久同步强化。")
    if tier == "BOSS":
        return f"驻守{era_w}战线的重装力量。" + _glue("原型为", weapon) + f"，{tactic}，足以左右一场战斗。"
    if tier == "ULTIMATE":
        return (f"「{card['name']}」是{era_w}战线的终战力量。" + _glue("原型为", weapon)
                + f"，{tactic}。")
    return _glue(f"本{noun}原型为", weapon) + f"，{tactic}。"


def _dedupe(flavors: dict[str, str], cards: list[dict]) -> int:
    """同文草案消歧：武器/空械副句变体 → 时代驻扎句 → 仍撞则告警（人工覆写兜底）。"""
    seen: dict[str, str] = {}
    n_fix = 0
    for c in cards:
        base = flavors[c["id"]]
        if base not in seen:
            seen[base] = c["id"]
            continue
        variants = []
        if c["w_armor"].strip():
            variants.append(base + _glue("对装甲目标换用", _space_latin(c["w_armor"].strip())) + "。")
        if c["w_air"].strip():
            variants.append(base + _glue("对空警戒依托", _space_latin(c["w_air"].strip())) + "。")
        variants.append(base + f"驻{ERA_NAMES.get(c['era'], '未知时代')}战线待命。")
        variants.append(base + f"沿革记录为「{c['name']}」。")  # 样例 2「沿革」式——卡名几乎必唯一
        fixed = next((v for v in variants if v not in seen), None)
        if fixed:
            flavors[c["id"]] = fixed
            seen[fixed] = c["id"]
            n_fix += 1
        else:
            print(f"[WARN] flavor 草案同文未能消歧：{c['id']}（人工覆写兜底）", file=sys.stderr)
    return n_fix


def check_numeric_core(flavors: dict[str, str]) -> list[str]:
    """数值内核断言：flavor 剥去拉丁连续段后不得含数值子串。返回违规项。"""
    bad = []
    for cid, text in flavors.items():
        stripped = RE_LATIN_RUN.sub("", text)
        if RE_NUM_CORE.search(stripped):
            bad.append(f"{cid}: {text}")
    return bad


def render_gd(flavors: dict[str, str]) -> str:
    lines = [
        "extends RefCounted",
        "class_name CardFlavorTexts",
        "## ══════════════════════════════════════════════════════════════════",
        f"## 批次②生成——卡面原型叙述表（生成于 {_dt.date.today().isoformat()}，草案）。",
        "## 生成器：tools/b2_gen_card_flavor.py（模板矩阵：时代×兵种×档位）。",
        "## 基调锚：docs/统一化/批次2-样例审批.md 样例 1/2/3（军语克制／一句原型＋至多",
        "## 一句战术特征／去庆祝腔）；宪法 docs/统一化/LANGUAGE_BIBLE.md 约束：",
        "## · 条目名只读不写（v2.4 终局裁决）——本表只新增 flavor，不改任何卡名；",
        "## · 数值内核——flavor 不含数值（机制与数值由 MECHANISM_DESC/动态模板承载）；",
        "## · 手工可覆写——改下方 MANUAL 字典（键=card_id，运行时优先于生成稿），",
        "##   勿直改 FLAVOR（重新生成会覆盖）；消费由 Task 8 落地（default_cards/card_info_panel）。",
        f"## 对账：FLAVOR 键集 == UCT card_id 集（{len(flavors)}/{len(flavors)}，生成时断言）。",
        "## ══════════════════════════════════════════════════════════════════",
        "",
        "const FLAVOR: Dictionary = {",
    ]
    for cid, text in flavors.items():
        escaped = text.replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'\t"{cid}": "{escaped}",')
    lines += [
        "}",
        "",
        "## 手工覆写区（card_id → 覆写文案；留空即全用生成稿）",
        "const MANUAL: Dictionary = {",
        "}",
        "",
        "static func get_flavor(card_id: String) -> String:",
        "\treturn MANUAL.get(card_id, FLAVOR.get(card_id, \"\"))",
        "",
    ]
    return "\n".join(lines)


def pick_samples(cards: list[dict], flavors: dict[str, str], n: int) -> list[dict]:
    """抽样：按时代×档位分层取样（每层先到先得），供人工抽查基调。"""
    picked, layers = [], {}
    for c in cards:
        key = (c["era"], c["tier"] if c["tier"] in ("GRUNT", "VETERAN") else "HIGH")
        layers.setdefault(key, c)
    # 分层打散后截前 N（保证跨时代/档位）
    for key in sorted(layers, key=lambda k: (k[0], str(k[1]))):
        picked.append(layers[key])
    if len(picked) > n:
        step = len(picked) / n
        picked = [picked[int(i * step)] for i in range(n)]
    return picked


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="批次②卡面叙述生成器（骨架——草案不落地，落地在 Task 8）")
    ap.add_argument("--sample", type=int, default=6, help="dry-run 打印样例条数（默认 6）")
    ap.add_argument("--out", metavar="PATH", type=Path, help="写 .gd 草案到指定路径")
    ap.add_argument("--write", action="store_true",
                    help="落盘 data/card_flavor_texts.gd（Task 8 落地时才用）")
    args = ap.parse_args(argv)

    cards = parse_uct()
    if not cards:
        raise SystemExit("[FATAL] UCT 解析结果为空")
    flavors = {c["id"]: make_flavor(c) for c in cards}

    # 对账断言：FLAVOR 键集 == UCT card_id 集（§2.4）
    assert set(flavors) == {c["id"] for c in cards}, "FLAVOR 键集与 UCT card_id 集不符"
    n_dupe = _dedupe(flavors, cards)
    bad_nums = check_numeric_core(flavors)

    n = len(cards)
    by_era = {}
    for c in cards:
        by_era[c["era"]] = by_era.get(c["era"], 0) + 1
    enemy_n = sum(1 for c in cards if c["enemy"])
    print("== b2_gen_card_flavor.py（骨架 dry-run）==")
    print(f"UCT 解析：{n} 卡（敌专属 {enemy_n}／玩家可购 {n - enemy_n}）"
          f"；对账断言 {len(flavors)}/{n} 通过")
    print("时代分布：" + "／".join(f"{ERA_NAMES.get(k, k)} {v}" for k, v in sorted(by_era.items())))
    print(f"同文消歧：{n_dupe} 条｜数值内核断言：{'通过（0 违规）' if not bad_nums else f'违规 {len(bad_nums)} 条'}")
    for b in bad_nums[:5]:
        print(f"  [NUM] {b}")

    print(f"—— 草案样例（分层抽样 {min(args.sample, n)} 条）——")
    for c in pick_samples(cards, flavors, max(3, args.sample)):
        tag = f"{ERA_NAMES.get(c['era'], '?')}·{KIND_NAMES.get(c['kind'], '?')}·{TIER_NAMES.get(c['tier'], '?')}"
        en = "敌专属 " if c["enemy"] else ""
        print(f"  {c['id']}（{en}{tag}｜{c['name']}）")
        print(f"    → {flavors[c['id']]}")

    if args.write and not args.out:
        args.out = DEFAULT_OUT
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(render_gd(flavors), encoding="utf-8", newline="\n")
        print(f"[OK] 草案已写出：{args.out.as_posix()}（{len(flavors)} 条；Task 8 前不落 data/）")
    else:
        print("（dry-run 未落盘——落地用 --out/--write，Task 8 消费）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
