# -*- coding: utf-8 -*-
## 卡图+待机/攻击动画 总审网页生成器 v2（家族制·统一ID）
## 前置: Godot headless 已跑 tools/_tmp_unit_manifest_dump.gd → _anim_review/unit_manifest_full.json
##       （与《docs/单位统一清单_敌我全量_含黑门.md》共用同一份数据源，口径永不分叉）
## 用法: python tools/_build_card_anim_review.py
## 输出: tools/card_anim_review.html（双击打开；资产走 ../assets 相对路径，勿移动文件）
## 结构: 镜像家族(=统一ID,140) / 独立我方卡(33) / 特色掉落卡(12) / 相位师平台(24)
## 口径: 敌我共用朝左 sheet；页面动画默认按"我方视角"镜像显示（实机 flip_h），家族卡可一键切敌方视角。
import json, os, io, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _card_anim_asset_probe as probe

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUMP = os.path.join(ROOT, "_anim_review", "unit_manifest_full.json")
OUT = os.path.join(ROOT, "tools", "card_anim_review.html")
MARKS_FILE = os.path.join(ROOT, "tools", "card_anim_review_marks (要修改的).json")

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ERA_NAMES = {0: "一战", 1: "二战", 2: "冷战", 3: "现代", 4: "近未来", 5: "星冥", -1: "未知", -2: "相位师"}
KIND_NAMES = {0: "轻装", 1: "装甲", 2: "支援", 3: "空中", 4: "堡垒"}
SEG_NAMES = {"A": "A·平台线", "B": "B·精英", "C": "C·固定", "D": "D·补充池", "E": "E·堡垒", "F": "F·星冥"}
ROLE_NAMES = {"basic": "基础", "elite": "精英", "ace": "王牌", "boss": "首领", "core": "黑门本体"}


def res_to_rel(p):
    return ("../" + p[len("res://"):]) if p and p.startswith("res://") else ""


def rel_exists(rel):
    return bool(rel) and os.path.isfile(os.path.join(ROOT, rel.lstrip("./")))


def fam_key(aid):
    return aid[len("foe_"):] if aid.startswith("foe_") else aid


def anim_part(r, flip):
    """dump 行 → 页面 anim 规格（含 sheet 相对路径与镜像标志）"""
    a = r.get("anim")
    if not a:
        return None
    a = dict(a)
    a["sheet_idle"] = res_to_rel(a.get("sheet_idle", ""))
    a["sheet_attack"] = res_to_rel(a.get("sheet_attack", ""))
    a["_flip"] = flip
    return a


def frames_part(r, key_frames, key_dir):
    """boss/pose 逐帧组 → {n, dir, paths}"""
    n = r.get(key_frames) or 0
    if not n:
        return None
    d = r.get(key_dir) or r["id"]
    pat = "idle_f%d.png" if key_frames == "boss_frames" else "attack_f%d.png"
    return {"n": n, "dir": d,
            "paths": ["../assets/effects/unit_anims/%s/%s" % (d, pat % i) for i in range(n)]}


def alt_anims_part(row, winner_key):
    """解析链上被遮蔽的候选动画目录（游戏内不生效），供网页「选哪套动画」对比/拍板"""
    out = []
    for c in row.get("anim_cands") or []:
        k = c.get("key", "")
        if not k or k == winner_key:
            continue
        a = {x: c[x] for x in ("fps", "fs", "idle", "attack")}
        a["sheet_idle"] = res_to_rel(c.get("sheet_idle", ""))
        a["sheet_attack"] = res_to_rel(c.get("sheet_attack", ""))
        out.append({"key": k, "anim": a})
    return out


def base_flags(rec_icon_rels, anim, boss, pose, need_anim=True):
    flags = []
    for tag, rel in rec_icon_rels:
        if not rel:
            flags.append("no_icon_" + tag)
        elif not rel_exists(rel):
            flags.append("icon_missing_" + tag)
    has_idle = (anim and anim.get("idle", 0) >= 2) or boss
    if need_anim and not has_idle:
        flags.append("no_anim")
    if anim and anim.get("idle", 0) == 1:
        flags.append("idle_lt2")
    has_atk = (anim and anim.get("attack", 0) > 0) or pose
    if need_anim and has_idle and not has_atk:
        flags.append("no_attack")
    return flags


SUS_ORDER = ["face", "size", "bg", "clip"]


def union_sus(sus_e, sus_p, met_e, met_p):
    """敌/我两侧探测并集；face 只看我方侧（敌方本向必然同向）"""
    sus, sides = [], {}
    for tag, arr in (("敌", sus_e), ("我", sus_p)):
        for s in arr:
            if s == "face" and tag == "敌":
                continue
            if s in ("probe_err", "diff"):
                continue
            if s not in sides:
                sides[s] = []
                sus.append(s)
            if tag not in sides[s]:
                sides[s].append(tag)
    met = {}
    if met_p.get("jh"):
        met["jh"] = met_p["jh"]
    if met_p.get("sz"):
        met["sz"] = met_p["sz"]
    if met_p.get("sim") is not None:
        met["sim"] = met_p["sim"]
    ce, cp = met_e.get("clip") or 0, met_p.get("clip") or 0
    if max(ce, cp):
        met["clip"] = max(ce, cp)
    if met_e.get("err") or met_p.get("err"):
        sus.append("probe_err")
        met["err"] = (met_e.get("err") or met_p.get("err") or "")[:60]
    return sus, sides, met


def probe_side(icon_rel, anim, boss):
    try:
        return probe.analyze_card(icon_rel or None, anim, boss, None)
    except Exception as e:  # 单卡资产异常不炸整页
        return (["probe_err"], {"err": str(e)[:60]})


def main():
    global OUT  # redo 分支会重定向输出页
    d = json.load(open(DUMP, encoding="utf-8"))
    enemies, players, captured, platforms = d["enemies"], d["players"], d["captured"], d["platforms"]

    # ── 家族挂接：我方卡卡图 == 家族我方镜像图 ──
    icon_player_to_fam = {}
    for e in enemies:
        ip = e.get("icon_player") or ""
        if ip and ip not in icon_player_to_fam:
            icon_player_to_fam[ip] = fam_key(e["id"])
    fam_players = {}
    matched = set()
    for p in players:
        f = icon_player_to_fam.get(p.get("icon") or "")
        if f:
            fam_players.setdefault(f, []).append(p)
            matched.add(p["id"])
    independent = [p for p in players if p["id"] not in matched]

    captured_ids = {c["id"] for c in captured}
    captured_recs = {c["id"]: c for c in captured}
    drop_binding = {}
    for e in enemies:
        for did in e.get("special_drops", []):
            drop_binding.setdefault(did, []).append(fam_key(e["id"]))

    sections, mig = [], {}
    total = 0
    issues = {}

    def add_flag(f, key):
        issues.setdefault(f, []).append(key)

    def finish(rec, sec):
        nonlocal total
        total += 1
        for f in rec["flags"]:
            add_flag(f, sec + "|" + rec["id"])
        sections[-1]["rows"].append(rec)

    # ── §1 镜像家族（统一ID）──
    sec_fam = {"key": "fam", "title": "镜像家族（统一ID）",
               "srcnote": "敌方原型 140 个=统一ID。我方卡图=敌方图水平镜像；同图多卡归并为一张家族卡（挂接卡列出）。缴获双层：运行时 captured_<敌方ID> 140 张 + 统一表 enemy_only（家族同名/旧平台/特色掉落 116 张），标注落在家族即可。",
               "rows": []}
    sections.append(sec_fam)
    fam_rows = {}                            # fid -> fam 行（供 §1.5 挂接卡引用宿主）
    for e in enemies:
        fid = fam_key(e["id"])
        anim = anim_part(e, flip=True)          # 页面默认我方视角
        boss = frames_part(e, "boss_frames", "boss_dir")
        pose = frames_part(e, "pose_frames", "pose_dir")
        icon_e, icon_p = res_to_rel(e.get("icon", "")), res_to_rel(e.get("icon_player", ""))
        flags = base_flags([("enemy", icon_e), ("player", icon_p)], anim, boss, pose)
        pcards = fam_players.get(fid, [])
        pkeys = sorted({p.get("anim_key", "") for p in pcards if p.get("anim_key")})
        ekey = e.get("anim_key", "")
        extra_anims = []
        for k in pkeys:
            if k == ekey:
                continue
            for p in pcards:
                if p.get("anim_key") == k:
                    extra_anims.append({"key": k, "anim": anim_part(p, flip=True)})
                    break
        if extra_anims:
            flags.append("anim_split")
        alt_anims = alt_anims_part(e, ekey)
        if alt_anims:
            flags.append("anim_alt")
        sus_e, met_e = probe_side(icon_e, anim_part(e, flip=False), boss)
        sus_p, met_p = probe_side(icon_p, anim, boss)
        sus, sides, met = union_sus(sus_e, sus_p, met_e, met_p)
        rec = {
            "id": fid, "fid": fid, "name": e.get("name", ""), "era": e.get("era", -1),
            "kind": e.get("kind", -1), "seg": e.get("seg", "?"),
            "role": e.get("role", ""), "power": e.get("power", 0),
            "drop": e.get("drop", 0.0), "drop_card_id": e.get("drop_card_id", ""),
            "uct": fid in captured_ids,
            "specials": e.get("special_drops", []),
            "joined": [p["id"] for p in pcards],
            "joined_names": [p.get("name", "") for p in pcards],
            "icon_e": icon_e, "icon_p": icon_p,
            "anim": anim, "anim_key": ekey,
            "boss": boss, "pose": pose,
            "flags": flags, "flip": True, "sec": "fam",
            "sus": sus, "sus_sides": sides,
        }
        if met:
            rec["met"] = met
        if extra_anims:
            rec["extra_anims"] = extra_anims
        if alt_anims:
            rec["alt_anims"] = alt_anims
        finish(rec, "fam")
        fam_rows[fid] = rec
        mig["enemies|" + e["id"]] = "fam|" + fid
    for p in players:
        f = icon_player_to_fam.get(p.get("icon") or "")
        if f:
            mig.setdefault("players|" + p["id"], "fam|" + f)
            mig.setdefault("captured|" + p["id"], "fam|" + f)

    # ── §1.5 动画独立挂接卡（游戏内一卡一行：游戏名+卡图+自己动画）──
    # 同图多卡归并进家族行后，动画与家族宿主不同的卡在这里单独立行，
    # 按「游戏中的名」逐卡审——避免被家族行的宿主动画遮蔽。
    sec_split = {"key": "split", "title": "动画独立挂接卡（游戏内一卡一行）",
                 "srcnote": "与家族卡同图但动画目录不同的游戏内独立卡。行名=游戏内 display_name，卡图=该卡实机图，动画=该卡实机 sheet（与运行时 UnitFrameAnim 解析结果一致）。家族行本身只代表宿主动画。",
                 "rows": []}
    sections.append(sec_split)
    for fid, pcards in fam_players.items():
        host = fam_rows.get(fid)
        if not host:
            continue
        ekey = host["anim_key"]
        for p in pcards:
            pk = p.get("anim_key", "")
            if not pk or pk == ekey:
                continue  # 与宿主同动画：家族行预览即它，不重复出行
            anim = anim_part(p, flip=True)
            boss = frames_part(p, "boss_frames", "boss_dir")
            pose = frames_part(p, "pose_frames", "pose_dir")
            icon = res_to_rel(p.get("icon", ""))
            need = p.get("ctype", -1) == 0
            flags = base_flags([("player", icon)], anim, boss, pose, need_anim=need)
            sus, met = probe_side(icon, anim, boss)
            sus = [s for s in sus if s not in ("probe_err", "diff")]
            alt_anims = alt_anims_part(p, pk)
            if alt_anims:
                flags.append("anim_alt")
            rec = {
                "id": p["id"], "name": p.get("name", ""), "era": p.get("era", -1),
                "kind": p.get("kind", -1), "ctype": p.get("ctype", -1),
                "icon": icon, "anim": anim, "anim_key": pk,
                "boss": boss, "pose": pose,
                "flags": flags, "flip": True, "sec": "split",
                "sus": sus, "sus_sides": {s: ["我"] for s in sus},
                "note": "挂接家族: " + host["name"] + "（同图不同动画）",
            }
            if met:
                rec["met"] = met
            if alt_anims:
                rec["alt_anims"] = alt_anims
            finish(rec, "split")
            mig["players|" + p["id"]] = "split|" + p["id"]

    # ── §2 独立我方卡 ──
    sections.append({"key": "ind", "title": "独立我方卡（不走镜像管线）",
                     "srcnote": "卡图不经敌方镜像的玩家原生卡：专属立绘/策略卡/势力专属（fe_*）。非战斗卡（能源/法则）本就不需要动画。",
                     "rows": []})
    for p in independent:
        anim = anim_part(p, flip=True)
        boss = frames_part(p, "boss_frames", "boss_dir")
        pose = frames_part(p, "pose_frames", "pose_dir")
        icon = res_to_rel(p.get("icon", ""))
        need = p.get("ctype", -1) == 0  # 只有战斗单位要求动画
        flags = base_flags([("player", icon)], anim, boss, pose, need_anim=need)
        sus, met = probe_side(icon, anim, boss)
        sus = [s for s in sus if s not in ("probe_err", "diff")]
        alt_anims = alt_anims_part(p, p.get("anim_key", ""))
        if alt_anims:
            flags.append("anim_alt")
        rec = {
            "id": p["id"], "name": p.get("name", ""), "era": p.get("era", -1),
            "kind": p.get("kind", -1), "ctype": p.get("ctype", -1),
            "icon": icon, "anim": anim, "anim_key": p.get("anim_key", ""),
            "boss": boss, "pose": pose,
            "flags": flags, "flip": True, "sec": "ind",
            "sus": sus, "sus_sides": {s: ["我"] for s in sus},
        }
        if met:
            rec["met"] = met
        if alt_anims:
            rec["alt_anims"] = alt_anims
        finish(rec, "ind")
        mig.setdefault("players|" + p["id"], "ind|" + p["id"])

    # ── §3 特色掉落卡 ──
    sections.append({"key": "drop", "title": "特色掉落卡（精英/Boss 专属）",
                     "srcnote": "enemy_only、不入常规卡池；绑定关系从敌方 JSON drops 配置反查（7 张 drop_* + 5 张跨段精英卡）。",
                     "rows": []})
    for did in sorted(drop_binding):
        c = captured_recs.get(did)
        if not c:
            continue
        anim = anim_part(c, flip=True)
        boss = frames_part(c, "boss_frames", "boss_dir")
        pose = frames_part(c, "pose_frames", "pose_dir")
        icon = res_to_rel(c.get("icon", ""))
        flags = base_flags([("player", icon)], anim, boss, pose)
        sus, met = probe_side(icon, anim, boss)
        sus = [s for s in sus if s not in ("probe_err", "diff")]
        alt_anims = alt_anims_part(c, c.get("anim_key", ""))
        if alt_anims:
            flags.append("anim_alt")
        rec = {
            "id": did, "name": c.get("name", ""), "era": c.get("era", -1),
            "kind": c.get("kind", -1),
            "bound": drop_binding[did],
            "icon": icon, "anim": anim, "anim_key": c.get("anim_key", ""),
            "boss": boss, "pose": pose,
            "flags": flags, "flip": True, "sec": "drop",
            "sus": sus, "sus_sides": {s: ["我"] for s in sus},
        }
        if met:
            rec["met"] = met
        if alt_anims:
            rec["alt_anims"] = alt_anims
        finish(rec, "drop")
        mig.setdefault("captured|" + did, "drop|" + did)

    # ── §4 相位师平台 ──
    sections.append({"key": "plat", "title": "相位师战争平台",
                     "srcnote": "敌我两侧均可部署（敌 spawn_sequence / 我方相位仪 loadout），卡图 assets/card_icons/<id>.png（2026-10-04 批生成）；advanced/expert 16 个为未接线数据变体（ANIM_ALIAS 仅覆盖 *_basic）。",
                     "rows": []})
    for p in platforms:
        anim = anim_part(p, flip=False)
        boss = frames_part(p, "boss_frames", "boss_dir")
        pose = frames_part(p, "pose_frames", "pose_dir")
        icon = res_to_rel(p.get("icon", ""))
        flags = base_flags([("platform", icon)], anim, boss, pose)
        sus, met = probe_side(icon, anim, boss)
        sus = [s for s in sus if s not in ("probe_err", "diff")]
        alt_anims = alt_anims_part(p, p.get("anim_key", ""))
        if alt_anims:
            flags.append("anim_alt")
        tier = "basic" if p["id"].endswith("_basic") else ("advanced" if p["id"].endswith("_advanced") else "expert")
        rec = {
            "id": p["id"], "name": p.get("name", ""), "era": -2, "kind": -1,
            "faction": p.get("faction", ""), "tier": {"basic": "基础", "advanced": "进阶", "expert": "专家"}[tier],
            "icon": icon, "anim": anim, "anim_key": p.get("anim_key", ""),
            "boss": boss, "pose": pose,
            "flags": flags, "flip": False, "sec": "plat",
            "sus": sus, "sus_sides": {s: ["敌"] for s in sus},
        }
        if tier != "basic":
            rec["note"] = "数据变体：无出战配置"
        if met:
            rec["met"] = met
        if alt_anims:
            rec["alt_anims"] = alt_anims
        finish(rec, "plat")
        mig.setdefault("platforms|" + p["id"], "plat|" + p["id"])

    # ── 兼容层附录（不生成卡片）──
    compat = sorted(c for c in captured_ids if c.startswith("platform_"))
    uct_drop = sorted(c for c in captured_ids if c.startswith("drop_"))
    uct_fam = sorted(c for c in captured_ids if c not in compat and c not in uct_drop)

    # ── 全局序号：全部行 NNN·名（跨段连续，批次任务可按号指名）──
    # 放在标注过滤前：redo 页/过滤页的行保留总审页同号，便于跨页引用。
    _no = 0
    for s in sections:
        for r in s["rows"]:
            _no += 1
            if r.get("name"):
                r["name"] = "%03d·%s" % (_no, r["name"])

    # ── 标注过滤：默认只留「有备注 或 选定重做」的行（用户规则：无备注且未选重做=接受）；
    #    --full 出全量页。种子标注并入页面：本机 localStorage 已有则不覆盖。
    marks_seed = {}
    # --redo-page [json路径]: 出「问题工作台」页——只含有内容的标注行，输出 card_anim_redo.html
    redo_mode = "--redo-page" in sys.argv
    if redo_mode:
        i = sys.argv.index("--redo-page")
        mf = sys.argv[i + 1] if i + 1 < len(sys.argv) and not sys.argv[i + 1].startswith("--") else MARKS_FILE
        OUT = os.path.join(ROOT, "tools", "card_anim_redo.html")
        try:
            marks_seed = json.load(open(mf, encoding="utf-8")).get("marks", {})
        except Exception as e:
            print("redo marks 载入失败:", e)
            return
    elif os.path.isfile(MARKS_FILE):
        try:
            marks_seed = json.load(open(MARKS_FILE, encoding="utf-8")).get("marks", {})
        except Exception as e:
            print("marks 载入失败（跳过过滤）:", e)
    only_marked = redo_mode or ("--marked" in sys.argv)  # 默认全量；redo 页/ --marked 才过滤
    missing = []
    if only_marked and marks_seed:
        want = {k for k, m in marks_seed.items()
                if (m.get("n") or "").strip() or m.get("r") == "yes" or m.get("p")}
        missing = []
        for sec in sections:
            keep = []
            for r in sec["rows"]:
                k = sec["key"] + "|" + r["id"]
                if k in want:
                    keep.append(r)
                    want.discard(k)
            sec["rows"] = keep
        sections = [s for s in sections if s["rows"]]
        missing = sorted(want)
        total = sum(len(s["rows"]) for s in sections)
    elif only_marked:
        print("标注文件缺失或为空，出全量页")

    data = {
        "generated": d.get("generated", ""),
        "sections": sections,
        "era_names": ERA_NAMES, "kind_names": KIND_NAMES, "seg_names": SEG_NAMES,
        "role_names": ROLE_NAMES,
        "total": total,
        "issues": issues,
        "mig": mig,
        "compat": compat,
        "marks_seed": marks_seed,
        "only_marked": only_marked,
        "uct_stats": {"family": len(uct_fam), "platform": len(compat), "drop": len(uct_drop),
                      "runtime": len(enemies)},
    }
    tpl = open(os.path.join(ROOT, "tools", "_card_anim_review_template.html"), encoding="utf-8").read()
    payload = json.dumps(data, ensure_ascii=True, separators=(",", ":")).replace("</", "<\\/")
    html = tpl.replace("__DATA__", payload)
    if redo_mode:
        # redo 页页首横幅（body 后注入，不依赖模板结构）
        banner = ('<div style="position:sticky;top:0;z-index:99;background:#7a1f1f;color:#fff;'
                  'padding:6px 14px;font:600 14px/1.4 system-ui">问题工作台 — 标注导出回执：'
                  '只列有标注的行（%d 张）。备注原文在卡上；改完一批后用总审页核对。</div>' % total)
        html = html.replace("<body>", "<body>" + banner, 1)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    print("BUILD_OK total=%d (fam=%d split=%d ind=%d drop=%d plat=%d) -> %s (%.1f KB)" % (
        total, sum(len(s["rows"]) for s in sections if s["key"] == "fam"),
        sum(len(s["rows"]) for s in sections if s["key"] == "split"),
        sum(len(s["rows"]) for s in sections if s["key"] == "ind"),
        sum(len(s["rows"]) for s in sections if s["key"] == "drop"),
        sum(len(s["rows"]) for s in sections if s["key"] == "plat"),
        os.path.relpath(OUT, ROOT), os.path.getsize(OUT) / 1024))
    if only_marked:
        print("  标注过滤开：只显示「有备注或选重做」的行；--full 出全量")
    if missing:
        print("  标注键无对应行 %d 个: %s" % (len(missing), ";".join(missing[:10]) + ("..." if len(missing) > 10 else "")))
    for k, v in issues.items():
        if v:
            print("  issue[%s] n=%d: %s" % (k, len(v), ";".join(v[:8]) + ("..." if len(v) > 8 else "")))


if __name__ == "__main__":
    main()
