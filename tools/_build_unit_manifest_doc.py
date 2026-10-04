# -*- coding: utf-8 -*-
## 单位统一清单（敌我全量·含黑门）文档生成器
## 前置: Godot headless 已跑 tools/_tmp_unit_manifest_dump.gd → _anim_review/unit_manifest_full.json
## 用法: python tools/_build_unit_manifest_doc.py
## 输出: docs/单位统一清单_敌我全量_含黑门.md
## 原则：一切数据来自游戏真解析链（manifest/统一表/UiAssetLoader/UnitFrameAnim），
##       文件存在性在本机 assets/ 实查，不在文档里手写任何一条可核对项。
import json, os, io, sys, collections

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUMP = os.path.join(ROOT, "_anim_review", "unit_manifest_full.json")
OUT = os.path.join(ROOT, "docs", "单位统一清单_敌我全量_含黑门.md")

ERA_NAMES = {-1: "—", -2: "相位师", 0: "一战", 1: "二战", 2: "冷战", 3: "现代", 4: "近未来", 5: "星冥"}
KIND_NAMES = {-1: "—", 0: "轻装", 1: "装甲", 2: "支援", 3: "空中", 4: "堡垒"}
CTYPE_NAMES = {-1: "—", 0: "战斗单位", 1: "能源", 2: "法则", 3: "平台", 4: "武器", 5: "合成"}
SEG_NAMES = {
    "A": "A 段 · 原平台线（敌方ID = `foe_<统一ID>`，掉落卡 = `captured_foe_<统一ID>`）",
    "B": "B 段 · 原精英平台（敌方ID = `foe_<统一ID>`，掉落卡 = `captured_foe_<统一ID>`）",
    "C": "C 段 · 固定敌人原型（敌方ID / 掉落卡前缀均用统一ID）",
    "D": "D 段 · 补充敌人池（敌方ID / 掉落卡前缀均用统一ID；含 v26 飞机 8 + v30.5 喷气试点 2）",
    "E": "E 段 · 堡垒阵地（敌方ID / 掉落卡前缀均用统一ID；掉率 12%）",
    "F": "F 段 · 星冥族（黑门无限模式，era=5；含黑门本体，本体击碎必掉）",
}
ROLE_NAMES = {"basic": "基础", "elite": "精英", "ace": "王牌", "boss": "首领", "core": "黑门本体"}


def res2rel(p):
    return os.path.join(ROOT, p[len("res://"):].replace("/", os.sep)) if p and p.startswith("res://") else ""


def fexists(p):
    r = res2rel(p)
    return bool(r) and os.path.isfile(r)


def rel_disp(p):
    if not p:
        return "—"
    p = p[len("res://assets/card_icons/"):] if p.startswith("res://assets/card_icons/") else p[len("res://"):]
    return p[:-4] if p.endswith(".png") else p


def fam_key(aid):
    return aid[len("foe_"):] if aid.startswith("foe_") else aid


def anim_disp(r):
    a = r.get("anim")
    parts = []
    if a and (a["idle"] >= 2 or a["attack"] > 0):
        parts.append("`%s` %d+%d帧" % (r["anim_key"], a["idle"], a["attack"]))
    if r.get("boss_frames"):
        parts.append("boss%d帧" % r["boss_frames"])
    if r.get("pose_frames"):
        parts.append("姿态%d" % r["pose_frames"])
    return " ".join(parts) if parts else "—"


def unit_anim_missing(rec):
    a = rec.get("anim")
    return not ((a and (a["idle"] >= 2 or a["attack"] > 0)) or rec.get("boss_frames") or rec.get("pose_frames"))


def main():
    d = json.load(open(DUMP, encoding="utf-8"))
    enemies, players, captured, platforms = d["enemies"], d["players"], d["captured"], d["platforms"]

    # ── 家族分组：敌方原型为锚；我方卡按「解析出的卡图路径 == 敌方我方镜像路径」挂接 ──
    fam_players = collections.defaultdict(list)
    matched_player_ids = set()
    icon_player_to_fam = {}
    for e in enemies:
        ip = e.get("icon_player") or ""
        if ip:
            icon_player_to_fam.setdefault(ip, e["id"])  # setdefault：共用立绘记首个家族
    for p in players:
        ip = p.get("icon") or ""
        if ip in icon_player_to_fam:
            fam_players[icon_player_to_fam[ip]].append("`" + p["id"] + "`")
            matched_player_ids.add(p["id"])
    independent = [p for p in players if p["id"] not in matched_player_ids]

    # ── 缴获三口径 ──
    # ① 运行时掉落卡 captured_<敌方ID>（CapturedUnitCards 动态注册，140 张，数值=统一表同名卡）
    # ② UCT enemy_only（116）：家族同名卡 / 旧平台卡 / 特色掉落卡
    captured_ids = {c["id"] for c in captured}
    uct_in_fam = [c for c in captured_ids if c in {fam_key(e["id"]) for e in enemies}]
    uct_platform = sorted(c for c in captured_ids if c.startswith("platform_"))
    uct_drop = sorted(c for c in captured_ids if c.startswith("drop_"))
    uct_other = sorted(c for c in captured_ids
                       if c not in uct_in_fam and c not in uct_platform and c not in uct_drop)

    # ── 共用立绘检测（同 basename 挂多个家族）──
    icon_use = collections.defaultdict(list)
    for e in enemies:
        if e.get("icon"):
            icon_use[rel_disp(e["icon"])].append(e["id"])
    shared_icons = {k: v for k, v in icon_use.items() if len(v) > 1}

    # ── 孤儿立绘 ──
    referenced = set()
    for e in enemies:
        for k in ("icon", "icon_player"):
            if e.get(k):
                referenced.add(os.path.normpath(res2rel(e[k])).lower())
    for arr in (players, captured, platforms):
        for r in arr:
            if r.get("icon"):
                referenced.add(os.path.normpath(res2rel(r["icon"])).lower())
    orphans = {"enemy": [], "player": []}
    for sub in ("enemy", "player"):
        pdir = os.path.join(ROOT, "assets", "card_icons", sub)
        if not os.path.isdir(pdir):
            continue
        for fn in sorted(os.listdir(pdir)):
            if not fn.lower().endswith(".png"):
                continue
            if os.path.normpath(os.path.join(pdir, fn)).lower() not in referenced:
                orphans[sub].append(fn[:-4])

    # ── 特色掉落卡 → 绑定家族（从数据反查，非注释）──
    drop_binding = collections.defaultdict(list)
    for e in enemies:
        for did in e.get("special_drops", []):
            drop_binding[did].append(fam_key(e["id"]))
    drop_card_recs = {c["id"]: c for c in captured}

    L = []
    w = L.append
    w("# 单位统一清单（敌我全量 · 含黑门）")
    w("")
    w("**版本** v3.0 全量重制 | **生成** %s（生成器 `tools/_build_unit_manifest_doc.py` + `tools/_tmp_unit_manifest_dump.gd`，机器生成勿手改）" % d["generated"])
    w("")
    w("**数据源**（全部走游戏真解析链，非人工抄录）：")
    w("")
    w("- 敌方 = `EnemyUnitManifest.get_entries()`（A/B/C/D/E 段 + F 段星冥·黑门本体，%d 条）" % len(enemies))
    w("- 我方 = `DefaultCards.create_all()`（统一表非 enemy_only + 势力专属，%d 张）" % len(players))
    w("- 缴获 = 运行时 `captured_*`（CapturedUnitCards 动态注册 %d 张）+ `UnifiedCardTable.get_enemy_only_entries()`（%d 张）" % (len(enemies), len(captured)))
    w("- 战争平台 = `data/json/enemy_phase_platforms.json`（%d 个）" % len(platforms))
    w("- 卡图 = `UiAssetLoader.card_icon_path_for` / `manifest.get_unit_icon_path_for_archetype`；动画 = `UnitFrameAnim._resolve_key` + Boss/姿态帧实查")
    w("")
    w("---")
    w("")
    w("## 0. 统一 ID 方案")
    w("")
    w("**统一ID = 单位家族键** = 敌方原型的无前缀 id（A/B 段去 `foe_`，其余段原样）。同一单位的四种体系 id 由此派生：")
    w("")
    w("| 段 | 统一ID 示例 | 敌方战场ID | 击杀掉落卡 | 我方卡来源 |")
    w("|----|------------|-----------|-----------|-----------|")
    w("| A 原平台线 | `ww1_arm_rolls` | `foe_ww1_arm_rolls` | `captured_foe_ww1_arm_rolls` | 统一表同名卡（玩家原生） |")
    w("| B 原精英平台 | `fut_sup_bulwark` | `foe_fut_sup_bulwark` | `captured_foe_fut_sup_bulwark` | 统一表同名卡 |")
    w("| C/D/E | `ww1_inf_mp18` | `ww1_inf_mp18`（同统一ID） | `captured_ww1_inf_mp18` | 统一表同名卡 / 缴获入库 |")
    w("| F 星冥 | `xeno_zealot` | `xeno_zealot`（同统一ID） | `captured_xeno_zealot` | 缴获卡部署（captured_* 动态注册） |")
    w("")
    w("> 掉落卡数值规则：`captured_*` 保留前缀（向后兼容存档），数值 = 统一表同名卡（`captured_unit_cards.gd` v8.0）。")
    w("")
    w("**立绘（卡图）命名规则** —— 我方图 = 敌方原图水平翻转（`tools/generate_mirrored_player_icons.py` 生成）：")
    w("")
    w("- 旧编号层：`assets/card_icons/enemy/vis_enemy_NNN.png`（敌方原图）↔ `assets/card_icons/player/vis_player_NNN.png`（我方镜像），编号一一对应。")
    w("  - 001~028 = A 段；030~035 = B 段；036~071 = C 段；072~081 = E 段堡垒。")
    w("- 新一代层（D 段及以后）：敌我同名文件 `enemy/<统一ID>.png` / `player/<统一ID>.png`（如 `cold_inf_metis`）。")
    w("- 星冥层：`vis_xeno_<name>`（敌我双侧各一张）。")
    w("- 运行时取图由 `get_unit_icon_path_for_archetype(aid, for_player)` 分流；本清单立绘列即其返回值（文件存在性已实查）。")
    w("")
    w("**动画目录**：`assets/effects/unit_anims/<anim_key>/`，key 由 `UnitFrameAnim._resolve_key` 解析（卡id → 去 foe_ → 缴获映射 → 视觉id → ANIM_ALIAS）。")
    w("")
    w("---")
    w("")
    w("## 1. 总览对账（全机械校验）")
    w("")
    seg_n = collections.Counter(e["seg"] for e in enemies)
    miss_icon = [fam_key(e["id"]) for e in enemies if not fexists(e.get("icon", ""))]
    miss_mirror = [fam_key(e["id"]) for e in enemies if not fexists(e.get("icon_player", ""))]
    no_anim = [fam_key(e["id"]) for e in enemies if unit_anim_missing(e)]
    no_atk = []
    for e in enemies:
        a = e.get("anim")
        if a and a["idle"] >= 2 and a["attack"] == 0 and not e.get("pose_frames"):
            no_atk.append(fam_key(e["id"]))
    w("| 项目 | 数量 |")
    w("|------|------|")
    w("| 敌方原型合计 | **%d**（A %d / B %d / C %d / D %d / E %d / F %d 含黑门本体）|" % (
        len(enemies), seg_n["A"], seg_n["B"], seg_n["C"], seg_n["D"], seg_n["E"], seg_n["F"]))
    w("| 我方卡合计 | **%d**（挂接镜像家族 %d + 独立卡 %d，见 §4）|" % (len(players), len(matched_player_ids), len(independent)))
    w("| 缴获·运行时 `captured_*` | **%d**（每敌方一张，动态注册）|" % len(enemies))
    w("| 缴获·统一表 enemy_only | **%d**（家族同名 %d + 旧平台卡 %d + 特色掉落 %d + 其他 %d）|" % (
        len(captured), len(uct_in_fam), len(uct_platform), len(uct_drop), len(uct_other)))
    w("| 战争平台 | **%d**（`*_basic` 8 个有出战配置；advanced/expert 16 个为未接线数据变体）|" % len(platforms))

    def stat_row(label, ids):
        if ids:
            sample = "`, `".join(ids[:6]) + ("…" if len(ids) > 6 else "")
            w("| %s | %d（`%s`）|" % (label, len(ids), sample))
        else:
            w("| %s | 0 ✅ |" % label)
    stat_row("敌方缺敌方原图", miss_icon)
    stat_row("敌方缺我方镜像图", miss_mirror)
    stat_row("敌方无任何动画", no_anim)
    stat_row("敌方无攻击表现（仅idle）", no_atk)
    w("| 共用立绘的家族 | %d %s |" % (len(shared_icons), ("（" + "；".join("%s←%s" % (k, ",".join(v)) for k, v in sorted(shared_icons.items())) + "）") if shared_icons else ""))
    w("| 孤儿立绘（enemy/ 未挂接） | %d |" % len(orphans["enemy"]))
    w("| 孤儿立绘（player/ 未挂接） | %d |" % len(orphans["player"]))
    w("")
    w("---")
    w("")
    w("## 2. 敌方单位（按段，%d）" % len(enemies))
    w("")
    w("「我方挂接卡」= 解析出的卡图与该家族我方镜像图相同的玩家原生卡（即『我方 = 敌方水平转置』的落地关系）。")
    w("")
    idx = 0
    for seg in ["A", "B", "C", "D", "E", "F"]:
        rows = [e for e in enemies if e["seg"] == seg]
        w("### %s（%d）" % (SEG_NAMES[seg], len(rows)))
        w("")
        w("| # | 统一ID | 名称 | 时代 | 兵种 | 掉落卡（掉率） | 我方挂接卡 | 敌方立绘 | 我方立绘 | 动画 | 缺 |")
        w("|---|--------|------|------|------|----------------|------------|----------|----------|------|----|")
        for e in rows:
            idx += 1
            cap = e.get("drop_card_id", "")
            capcell = ("`%s`（%.0f%%）" % (cap, e["drop"] * 100)) if cap else "—（%.0f%%）" % (e["drop"] * 100)
            flags = []
            if not fexists(e.get("icon", "")):
                flags.append("缺敌立绘")
            if not fexists(e.get("icon_player", "")):
                flags.append("缺我方镜像")
            if unit_anim_missing(e):
                flags.append("无动画")
            elif e.get("anim") and e["anim"]["idle"] >= 2 and e["anim"]["attack"] == 0 and not e.get("pose_frames"):
                flags.append("无攻击")
            remark = ""
            if e["seg"] == "F":
                bits = []
                if e.get("role"):
                    bits.append(ROLE_NAMES.get(e["role"], e["role"]))
                if e.get("power"):
                    bits.append("power %d" % e["power"])
                remark = "（" + "；".join(bits) + "）" if bits else ""
            sp = e.get("special_drops")
            if sp:
                remark += ("；" if remark else "（") + "特色掉落 " + "、".join("`%s`" % s for s in sp)
            if remark and not remark.endswith("）"):
                remark += "）"
            mycards = "、".join(fam_players.get(e["id"], [])) or "—"
            w("| %d | `%s` | %s%s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                idx, fam_key(e["id"]), e["name"], remark, ERA_NAMES.get(e["era"], e["era"]),
                KIND_NAMES.get(e["kind"], e["kind"]), capcell, mycards,
                rel_disp(e.get("icon", "")), rel_disp(e.get("icon_player", "")),
                anim_disp(e), "、".join(flags) if flags else "✅"))
        w("")

    w("---")
    w("")
    w("## 3. 特色掉落卡（精英/Boss 专属，%d 张）" % len(drop_binding))
    w("")
    w("绑定关系从敌方 JSON `drops` 配置反查（非注释手抄）。这些卡 enemy_only，不入常规卡池，仅击败绑定敌人掉落。")
    w("")
    w("| # | 卡ID | 名称 | 时代 | 兵种 | 绑定敌人 | 卡图 | 动画 |")
    w("|---|------|------|------|------|----------|------|------|")
    for i, did in enumerate(sorted(drop_binding), 1):
        c = drop_card_recs.get(did, {})
        w("| %d | `%s` | %s | %s | %s | %s | %s | %s |" % (
            i, did, c.get("name", "—"), ERA_NAMES.get(c.get("era", -1), c.get("era", -1)),
            KIND_NAMES.get(c.get("kind", -1), c.get("kind", -1)),
            "、".join("`%s`" % b for b in drop_binding[did]),
            rel_disp(c.get("icon", "")) or "—", anim_disp(c) if c else "—"))
    w("")

    w("---")
    w("")
    w("## 4. 我方独立卡（未挂接镜像家族，%d 张）" % len(independent))
    w("")
    w("以下卡的卡图不走「敌方原图镜像」管线（专属立绘 / 策略卡 / 势力专属等）。")
    w("")
    w("| # | 卡ID | 名称 | 类型 | 时代 | 兵种 | 卡图 | 动画 | 缺 |")
    w("|---|------|------|------|------|------|------|------|----|")
    for i, p in enumerate(independent, 1):
        flags = []
        if not p.get("icon") or not fexists(p["icon"]):
            flags.append("缺卡图")
        if p.get("ctype") == 0 and unit_anim_missing(p):
            flags.append("无动画")
        w("| %d | `%s` | %s | %s | %s | %s | %s | %s | %s |" % (
            i, p["id"], p["name"] or "—", CTYPE_NAMES.get(p.get("ctype", -1), p.get("ctype")),
            ERA_NAMES.get(p["era"], p["era"]), KIND_NAMES.get(p["kind"], p["kind"]),
            rel_disp(p.get("icon", "")), anim_disp(p), "、".join(flags) if flags else "✅"))
    w("")

    w("---")
    w("")
    w("## 5. 统一表 enemy_only 补充（%d 张）" % (len(uct_platform) + len(uct_other)))
    w("")
    w("### 旧平台卡（%d 张，enemy_only：现役为 A 段直接 ID 卡，旧 platform_* 保留在缴获/兼容层）" % len(uct_platform))
    w("")
    w(", ".join("`%s`" % c for c in uct_platform))
    w("")
    if uct_other:
        w("### 其他（%d 张）" % len(uct_other))
        w("")
        w(", ".join("`%s`" % c for c in uct_other))
        w("")

    w("---")
    w("")
    w("## 6. 相位师战争平台（%d 个）" % len(platforms))
    w("")
    w("敌相位师 `spawn_sequence` 与我方相位仪 loadout 均可直接部署；动画仅 `ANIM_ALIAS` 覆盖 `*_basic`。无独立卡图（战场直接以动画呈现）。")
    w("")
    w("| # | 平台ID | 势力 | 层级 | 动画 |")
    w("|---|--------|------|------|------|")
    for i, p in enumerate(platforms, 1):
        tier = "基础" if p["id"].endswith("_basic") else ("进阶" if p["id"].endswith("_advanced") else "专家")
        wired = "" if p["id"].endswith("_basic") else "（未接线数据变体）"
        w("| %d | `%s` | %s | %s%s | %s |" % (
            i, p["id"], p.get("faction", "—"), tier, wired, anim_disp(p)))
    w("")

    w("---")
    w("")
    w("## 7. 孤儿立绘（文件在库、无任何数据引用）")
    w("")
    if not orphans["enemy"] and not orphans["player"]:
        w("无 ✅")
    else:
        for sub in ("enemy", "player"):
            if orphans[sub]:
                w("**%s/**（%d）：%s" % (sub, len(orphans[sub]), ", ".join("`%s`" % o for o in orphans[sub])))
                w("")
    w("---")
    w("")
    w("## 8. 相对旧版《card_icon_manifest_100_zh（100敌人设定）.md》v1.2（2026-05-20）的主要变化")
    w("")
    w("- A 段 29 → **28**（v3 重构：foe 卡直接定义属性，不再克隆旧平台卡；旧 `platform_*` 28 张退到统一表 enemy_only 兼容层，见 §5）。")
    w("- C 段 id 全部换代：旧 `enemy_ww1_infantry_basic` 类程序名 → 新一代语义 id（如 `ww1_inf_mp18`），36 条不变。")
    w("- D 段 29 → **39**（+v26 飞机 8：ww2/cold/mod/fut 各轰炸+多用途；+v30.5 喷气试点 2：`ww2_air_me262`、`ww2_air_meteor_e`，L36-40 等级门）。")
    w("- 新增 **E 段堡垒 10**（vis_player_072~081，掉率 12%，ww1 碉堡/要塞炮 L4 等级门）。")
    w("- 新增 **F 段星冥 20 + 黑门本体**（v27 黑门无限模式，era=5；本体 role=core 击碎必掉，立绘共用 `vis_xeno_mothership`）。")
    w("- visual_id 旧「001~100 一套编号」→ 现行三层（旧编号 001~081 + D 段新一代直名 + `vis_xeno_*`），详 §0。")
    w("- 缴获体系明示双层：运行时 `captured_*` 140 张（数值=统一表同名卡）+ 统一表 enemy_only 116 张，详 §0/§5。")
    w("- 战争平台（相位师）体系、势力专属卡（fe_*，14 张无动画）为本清单 §4/§6 新覆盖内容，旧版无。")
    w("")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(L))
    print("DOC_OK -> docs/单位统一清单_敌我全量_含黑门.md (%.1f KB, %d lines)" % (os.path.getsize(OUT) / 1024, len(L)))
    print("matched=%d independent=%d orphanE=%d orphanP=%d uct_in_fam=%d plat=%d drop=%d other=%d shared=%d" % (
        len(matched_player_ids), len(independent), len(orphans["enemy"]), len(orphans["player"]),
        len(uct_in_fam), len(uct_platform), len(uct_drop), len(uct_other), len(shared_icons)))


if __name__ == "__main__":
    main()
