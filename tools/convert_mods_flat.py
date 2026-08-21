# -*- coding: utf-8 -*-
"""v18.b 玩家改造固定值分层转换器

策略（用户批准的分层方案）：
- uncommon + rare 的 7 键属性条（attack_light/armor/air, defense_light/armor/air, max_hp）
  float 百分比 → int 固定值（引擎按 value 类型分流：float=乘区 / int=加值）
- 补 level_effects 三档（×1 / ×1.75 / ×2.5）线性成长
- epic/legendary 保留百分比（终局层）；负值（惩罚型 tradeoff）跳过保持百分比
- 兼容单行与多行两种 effects 块格式

换算基准（一战/二战卡池中位混合）：攻击 55 / 生命 290 / 防御 100
用法：python tools/convert_mods_flat.py [--apply]
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
MODULES = ["infantry", "armor", "artillery", "anti_air", "air", "recon", "engineer", "fort", "universal"]
STAT_KEYS = {"attack_light": "attack", "attack_armor": "attack", "attack_air": "attack",
             "defense_light": "defense", "defense_armor": "defense", "defense_air": "defense",
             "max_hp": "hp"}
BASE_REF = {"attack": 55.0, "defense": 100.0, "hp": 290.0}
LEVEL_MULT = [1.0, 1.75, 2.5]
TARGET_RARITY = {"uncommon", "rare"}


def fmt_num(v: float, dim: str) -> int:
    if dim == "hp":
        return max(1, int(round(v / 5.0) * 5))
    return max(1, int(round(v)))


ENTRY_RE = re.compile(r"^([a-z_]+) = (-?\d+(?:\.\d+)?)(,?)\s*(#.*)?$")


def convert_block(body_lines, mod_id, log):
    """body_lines: effects 块内的条目行（已 strip）。逐行转换，返回 (新行列表, level_effects 体 or None)"""
    new_lines = []
    stat_flats = {}
    other_entries = []
    for raw in body_lines:
        s = raw.strip()
        m = ENTRY_RE.match(s)
        if m:
            key, val_s, comma = m.group(1), m.group(2), m.group(3)
            if key in STAT_KEYS and "." in val_s:
                val = float(val_s)
                if val > 0.0:
                    dim = STAT_KEYS[key]
                    stat_flats[key] = [fmt_num(val * BASE_REF[dim] * lm, dim) for lm in LEVEL_MULT]
                    # 沿用原行缩进，保持与兄弟条目一致
                    lead = raw[:len(raw) - len(raw.lstrip("\t"))]
                    new_lines.append("%s%s = %d%s" % (lead, key, stat_flats[key][0], comma))
                    continue
                # 负值保持百分比
            # level_effects 里不能带行内注释（# 会吞掉行尾导致大括号不闭合）——剥掉
            clean = s.split("#")[0].strip().rstrip(",")
            if clean:
                other_entries.append(clean)
        new_lines.append(raw)
    if not stat_flats:
        return None, None
    lv_parts = []
    for li in range(3):
        inner = ["%s = %d" % (k, v[li]) for k, v in stat_flats.items()]
        inner.extend(other_entries)
        lv_parts.append("%d: {%s}" % (li + 1, ", ".join(inner)))
    log.append((mod_id, stat_flats))
    return new_lines, ", ".join(lv_parts)


def main():
    apply = "--apply" in sys.argv
    log = []
    for name in MODULES:
        path = None
        for suffix in ["_mods.gd", ".gd"]:
            cand = os.path.join(ROOT, "data", "modification_modules", name + suffix)
            if os.path.exists(cand):
                path = cand
                break
        if path is None:
            print("!! 找不到模块:", name)
            continue
        lines = open(path, encoding="utf-8").read().split("\n")
        out = []
        cur_id = ""
        cur_rarity = ""
        i = 0
        changed = 0
        while i < len(lines):
            line = lines[i]
            m = re.match(r'\t"([\w]+)" = \{', line)
            if m:
                cur_id = m.group(1)
                cur_rarity = ""
            rm = re.search(r'rarity = "(\w+)"', line)
            if rm:
                cur_rarity = rm.group(1)

            # 单行 effects = {...}
            em = re.match(r"^(\s*)effects = \{(.*)\}(,?)\s*(#.*)?$", line)
            if em and cur_rarity in TARGET_RARITY:
                indent, body, comma = em.group(1), em.group(2), em.group(3)
                parts = [p.strip() for p in body.split(",") if p.strip()]
                new_lines, lv_body = convert_block(["\t\t\t" + p for p in parts], cur_id, log)
                if new_lines is not None:
                    inner = ", ".join(x.strip() for x in new_lines)
                    out.append("%seffects = {%s}%s" % (indent, inner, comma))
                    if lv_body:
                        out.append("%slevel_effects = {%s}," % (indent, lv_body))
                    changed += 1
                    i += 1
                    continue

            # 多行 effects = { 起始
            ms = re.match(r"^(\s*)effects = \{\s*$", line)
            if ms and cur_rarity in TARGET_RARITY:
                indent = ms.group(1)
                j = i + 1
                body_lines = []
                close_idx = -1
                close_line = "},"
                while j < len(lines):
                    s = lines[j].strip()
                    if s in ("}", "},"):
                        close_idx = j
                        close_line = s
                        break
                    body_lines.append(lines[j])
                    j += 1
                if close_idx > 0:
                    new_lines, lv_body = convert_block(body_lines, cur_id, log)
                    if new_lines is not None:
                        out.append(line)
                        out.extend(new_lines)
                        out.append(lines[close_idx])  # 闭括号行原样保留（缩进不变）
                        if lv_body:
                            out.append("%slevel_effects = {%s}," % (indent, lv_body))
                        changed += 1
                        i = close_idx + 1
                        continue

            out.append(line)
            i += 1
        if changed and apply:
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write("\n".join(out))
        print("%-10s %s: %d 条转换" % (name, "已写入" if apply else "预览", changed))
    print("\n明细:")
    for mid, flats in log:
        pretty = "; ".join("%s L1/2/3=%s" % (k, v) for k, v in flats.items())
        print("  %-24s %s" % (mid, pretty))


if __name__ == "__main__":
    main()
