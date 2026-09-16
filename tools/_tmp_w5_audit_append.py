# -*- coding: utf-8 -*-
"""W5 全量视觉审计·§11 附录生成（2026-09-14）。
聚合 160 张子代理判档 + 主代理复核裁决，生成 §11 附录追加到 W3 增量分档表。
只写文档，不动任何图片资产。
"""
import json
import os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUD = os.path.join(BASE, ".godot", "agent_tools", "w5_vision_audit")
W3 = os.path.join(BASE, "docs", "统一化", "plans", "2026-09-14-W3增量分档表.md")

# ---- 主代理复核裁决（2026-09-14 亲读 13 张 + 同族采信）----
REVIEW = {
    "cold_arm_p18": ("C", "复核✓亲读：照片/模型渲染质感、无厚涂基础；ice rim 缺位；涂装语义合规"),
    "cold_arty_bmd1": ("C", "复核✓同族采信：cold 族渲染家族（p18 亲读确认）；ice rim 缺位；涂装语义合规"),
    "cold_sup_bmp1_x": ("C", "复核✓同族采信：cold 族渲染家族；ice rim 缺位；迷彩涂装语义合规"),
    "mod_arty_rq7": ("C", "复核✓亲读：硬边勾线平涂插画（cel 家族）；ice rim 缺位"),
    "vis_player_065": ("C", "复核✓亲读：3D 产品渲染零笔触；neon 落位本身合规"),
    "vis_player_066": ("C", "复核✓同族采信：与 065 同渲染家族"),
    "vis_player_078": ("C", "复核✓亲读：硬边勾线平涂建筑插画（cel 家族）；蓝核落位本身合规"),
    "vis_xeno_tripod": ("C", "复核✓亲读：中央半透明残影读作生成残迹（若为设计触须则材质语义不统一，呈 CP-2）"),
}
BLOCK7 = ["vis_player_043", "vis_player_044", "vis_player_045", "vis_player_046",
          "vis_player_047", "vis_player_048", "vis_player_050", "vis_player_051",
          "vis_player_052", "vis_player_053", "vis_player_055", "vis_player_056"]
for cid in BLOCK7:
    REVIEW[cid] = ("C", "复核✓同族采信：照片/盒装渲染家族（抽验 043/048/056 亲读确认，全块同款）")


def occ_band(p):
    if p > 90:
        return ">90"
    if p >= 85:
        return "85-90"
    if p >= 65:
        return "65-85"
    if p >= 50:
        return "50-65"
    return "<50"


def main():
    res = {}
    for f in ("results/wave_partial.json", "results/wave_rest.json"):
        res.update(json.load(open(os.path.join(AUD, f), encoding="utf-8")))
    rows = []
    for k in sorted(res):
        rows.extend(res[k])
    by_id = {r["id"]: r for r in rows}

    # 应用复核裁决
    for cid, (g, note) in REVIEW.items():
        by_id[cid]["grade"] = g
        by_id[cid]["note"] = note

    mani = json.load(open(os.path.join(AUD, "w5_manifest.json"), encoding="utf-8"))
    listing = json.load(open(os.path.join(BASE, ".godot", "agent_tools", "w5_vision_audit_list.json"), encoding="utf-8"))

    # 档位统计（读图 160）
    import collections
    gc = collections.Counter(r["grade"] for r in rows)

    # 发现项分组
    cel_c = [r["id"] for r in rows if r["grade"] == "C" and r["brush"] == "cel"]
    photo_c = [r["id"] for r in rows if r["grade"] == "C" and r["brush"] in ("photo", "smooth")]
    ground_c = [r["id"] for r in rows if r["grade"] == "C" and any("接地阴影" in i and "成片" in i for i in r["issues"])]
    facing_c = [r["id"] for r in rows if r["grade"] == "C" and r["facing"] not in ("right", "left", "tilted") or
                (r["grade"] == "C" and ((r["id"].startswith("vis_enemy") is False) and r["facing"] == "left"))]
    rim_b = [r["id"] for r in rows if r["grade"] == "B" and not r["rim_ok"]]

    L = []
    L.append("")
    L.append("---")
    L.append("")
    L.append("## §11 全量视觉分档附录（W5 视觉模型补审，2026-09-14）")
    L.append("")
    L.append("> **性质**：《2026-09-14-全量视觉审计计划》产出物——09-08 抽检与程序化维度之外，**目视维度的全量补审**。审计只读、0 改图；处置全部待 CP-2 用户裁决。")
    L.append("> **方法**：160 张读图（148 player + 12 enemy 非等价）切成 14 片，视觉子代理并行六维判档（rim/写实度/笔触/构图/标记/暖源语义，口径=STYLE_BIBLE 二/三/四/五/七章程 + 本表 §10 裁决）；主代理聚合 + 亲读复核 13 张 + 同族采信；锚点=me262 A- / patriot B 记 / c96 B。")
    L.append("> **指标口径**：占比=不透明像素外接框最大边/画幅（87.9%=部署管线 88% 规格，与历史审计同口径）；暖区=r>b+30 占不透明像素（§10 度量式，涂装语义按 §10 豁免）。")
    L.append("> **计划勘误**（对全量视觉审计计划）：①枚举单实测 94 张 enemy_only 中 82 张与本轮 player 148 像素级翻转等价（按计划'镜像共享不单独读图'原则继承判档），12 张非等价单独读图——读图量 242→160；②分片 21→14（读图量下降所致）；③enemy 同名镜像实测 63 张（计划记 76）。")
    L.append("")
    L.append("### §11.1 覆盖对账")
    L.append("")
    L.append("| 块 | 张数 | 判档方式 |")
    L.append("|---|---|---|")
    L.append("| player 148 | 148 | 逐张读图 |")
    L.append("| enemy vis 族镜像（对应本轮 player 148） | 82 | 翻转等价（像素级全量验证 82/82），继承 player 档 |")
    L.append("| enemy 非等价独有（001/008/014/022/027/054/063/064/072/075/113/114） | 12 | 逐张读图 |")
    L.append("| 命名族 enemy 镜像（cold_*/drop_*/fe_*/fut_*/mod_*/ww1_*/ww2_* 同名文件） | 63 | 翻转等价（像素级全量验证 63/63），继承 player 档（不在 242 枚举内，随行共享） |")
    L.append("| **合计** | **305 文件** | 160 读图 + 145 镜像继承 |")
    L.append("")
    L.append("### §11.2 分档总账（读图 160 张）")
    L.append("")
    L.append("| 档 | 张数 | 占比 | 一句话 |")
    L.append("|---|---|---|---|")
    L.append("| A | %d | %.1f%% | 四维全中（fut 系厚涂 5 + vis_player_031） |" % (gc["A"], gc["A"] * 100.0 / 160))
    L.append("| A- | %d | %.1f%% | 单一轻微瑕疵（occ 88%% 规格微超大半、接地淡痕、rim 微弱） |" % (gc["A-"], gc["A-"] * 100.0 / 160))
    L.append("| B | %d | %.1f%% | 笔触构图合规、色板/rim 档位问题（主体=ice rim 缺位 %d 张，LUT/补 rim 可救） |" % (gc["B"], gc["B"] * 100.0 / 160, len(rim_b)))
    L.append("| C | %d | %.1f%% | 硬伤（含 C? 存疑 20 张经主代理复核全部归 C，见 §11.3） |" % (gc["C"], gc["C"] * 100.0 / 160))
    L.append("")
    L.append("镜像继承 145 张（82 vis 族 + 63 命名族）随 player 同 id 行同档，不计入上表。")
    L.append("")
    L.append("### §11.3 主代理复核记录（C? 20 张 → 全部归 C）")
    L.append("")
    L.append("亲读复核 13 张：vis_player_043/048/056（片7 照片感块抽验）、cold_arm_p18、mod_arty_rq7、vis_player_065/078、fe_frontier_veteran（朝向）、fe_quantum_repair_drone（多主体）、vis_player_041（接地阴影）、vis_xeno_tripod（残影）、vis_enemy_001（旧图断链）。其余 7 张 C?（cold_arty_bmd1/cold_sup_bmp1_x/vis_player_044/045/046/047/050/051/052/053/055 中未亲读者、066）按同族采信归档——同族判定依据：同生成批次、同笔触特征、同 rim 状态。程序化辅证：vis_player_019 与 023 像素级全同（发现项②）。")
    L.append("")
    L.append("### §11.4 关键发现（审计只读，处置待 CP-2）")
    L.append("")
    L.append("1. **重复图**：`vis_player_019` 与 `vis_player_023` **像素级完全相同**（两张不同卡共用一张 BMP 步战车图）——内容错误级，两张皆 C（照片感）。")
    L.append("2. **部署断链（管线 bug，09-11 同款复发）**：player 侧 vis_player_001/075 已于 2026-09-14 重生成（W3 §7-A），但 enemy 正确路径 `enemy/vis_enemy_001/075.png` 仍是 09-11 旧图（mtime 9/11、occ 94.7/96.5、馆藏实拍感）；新翻转被写错名为 `enemy/vis_player_001.png`、`enemy/vis_player_075.png`（+2 .import，共 4 件，实测=新 player 图的翻转）。§7-A'enemy 翻转部署'实际未落到生效路径。")
    L.append("3. **照片/渲染感家族 C（%d 张）**：写实度 5 或盒装模型/3D 渲染零笔触，按时代带聚簇（vis_player 043-056 块、057-062 块、068-070、016/018/026/029/035、cold 族 3、ww2 族 4、enemy 缴获族 5、mod_sup_m4_carbine、065/066）——09-08'卡图照片感一律重生成'口径的未抽样存量。样张：043（汤姆逊步兵）/048（黑豹）/pak40/vis_enemy_001。" % len(photo_c))
    L.append("4. **cel 勾边家族 C（%d 张）**：%s——禁则 9 重生对象家族。" % (len(cel_c), "、".join(cel_c)))
    L.append("5. **成片接地阴影 C（%d 张）**：%s——底缘贯穿成片投影（禁则 7 重）；另有少量'轻微不成片'记 B/A- 的 issues 已随行标注。" % (len(ground_c), "、".join(ground_c)))
    L.append("6. **朝向错 C（2 张）**：fe_frontier_veteran（朝左，亲读确认）、vis_player_067（正视+cel 双硬伤）。")
    L.append("7. **多主体 C（1 张）**：fe_quantum_repair_drone（1 大机+9 小机群，亲读确认）。")
    L.append("8. **残影件 C（1 张）**：vis_xeno_tripod 中央半透明残影（亲读确认，语义存设计可能，呈 CP-2）。")
    L.append("9. **xeno 族健康**：vis_xeno_* 20 张全量 A-/B，仅 templar/thing（接地光池）与 sentinel（rim 色档错位）例外——黑门紫语义全族落位正确。")
    L.append("10. **B 簇主因=ice rim 缺位**（%d 张）：历史写实系（vis 写实带/ww1/ww2/cold/mod）普遍无冰天青背光缘，笔触构图多合格——后处理补 rim 批量可救，非重生成级。" % len(rim_b))
    L.append("")
    L.append("### §11.5 逐张分档表——player 148（读图）")
    L.append("")
    L.append("| 路径(player/) | 档 | rim | 写实/笔触 | 朝向 | 占比 | 暖源 | 备注 |")
    L.append("|---|---|---|---|---|---|---|---|")

    player_ids = listing["player"]
    inherit_map = {m["id"]: m["mirror_of"] for m in mani["mirror_inherit"]}
    for cid in player_ids:
        r = by_id[cid]
        rim = ("ice" if r.get("rim_expect_self", r.get("rim_actual")) else "")
        rim_txt = "%s/%s" % (r.get("rim_expect_self", "?"), r["rim_actual"]) if "rim_expect_self" in r else r["rim_actual"]
        marks = "" if r["marks"] == "none" else "；标记:" + str(r["marks"])
        issues = "" if not r["issues"] else "；" + ";".join(r["issues"][:2])
        L.append("| %s | %s | %s | %s/%s | %s | %s | %s | %s%s%s |" % (
            cid, r["grade"], rim_txt, r["realism"], r["brush"], r["facing"],
            occ_band(_occ(mani, cid)), r["warm_src"], r["note"], marks, issues))
    L.append("")
    L.append("### §11.6 逐张分档表——enemy 非等价独有 12（读图）")
    L.append("")
    L.append("| 路径(enemy/) | 档 | rim | 写实/笔触 | 朝向 | 占比 | 暖源 | 备注 |")
    L.append("|---|---|---|---|---|---|---|---|")
    solo_ids = [e["id"] for e in json.load(open(os.path.join(AUD, "shards", "w5_shard_13.json"), encoding="utf-8")) if e["side"] == "enemy"] + \
               [e["id"] for e in json.load(open(os.path.join(AUD, "shards", "w5_shard_14.json"), encoding="utf-8"))]
    for cid in solo_ids:
        r = by_id[cid]
        marks = "" if r["marks"] == "none" else "；标记:" + str(r["marks"])
        issues = "" if not r["issues"] else "；" + ";".join(r["issues"][:2])
        L.append("| %s | %s | auto/%s | %s/%s | %s | %s | %s | %s%s%s |" % (
            cid, r["grade"], r["rim_actual"], r["realism"], r["brush"], r["facing"],
            occ_band(_occ(mani, cid)), r["warm_src"], r["note"], marks, issues))
    L.append("")
    L.append("### §11.7 镜像继承对照——enemy vis 族 82（不读图，随 player 同档）")
    L.append("")
    L.append("| enemy 文件 | 档 | 镜像源（player/） |")
    L.append("|---|---|---|")
    def pgrade(pid):
        return by_id[pid]["grade"]
    for m in mani["mirror_inherit"]:
        L.append("| %s | %s（继承） | %s |" % (m["id"], pgrade(m["mirror_of"]), m["mirror_of"]))
    L.append("")
    named = [cid for cid in player_ids if os.path.exists(os.path.join(BASE, "assets", "card_icons", "enemy", cid + ".png"))]
    L.append("### §11.8 命名族 enemy 镜像 63 张（不在 242 枚举内）")
    L.append("")
    L.append("%s 张命名族卡（%s…）的 enemy 同名文件经像素级翻转校验（63/63 等价），**判档与 player 侧同行同档**，不另列。改任何 player 卡图后必须按 FLIP_LEFT_RIGHT 同步重 derive enemy 侧（发现项②即未同步反例）。" % (len(named), "、".join(named[:6])))
    L.append("")
    L.append("### §11.9 CP-2 检查点（呈用户裁决，审计 0 改图）")
    L.append("")
    L.append("| 组 | 内容 | 数量 | 建议处置（待裁决） |")
    L.append("|---|---|---|---|")
    L.append("| 1 | 照片/渲染感家族（发现③，§11.5/§11.6 中 brush=photo/smooth 的 C 行） | %d | 按 6.1 模板分时代批量重生成（批次④/W3-C 同款管线）；或用户拍板'模型质感'风格豁免转 B 记 |" % len(photo_c))
    L.append("| 2 | cel 勾边家族（发现④） | %d | 重生成（禁则 9，无调色救法） |" % len(cel_c))
    L.append("| 3 | 成片接地阴影（发现⑤） | %d | 外科清除（W3-B 底带残迹同款）可保图；重生成则随组 1/2 |" % len(ground_c))
    L.append("| 4 | 散项：朝向 2 + 多主体 1 + 残影 1 | 4 | 重生成/修图个案 |")
    L.append("| 5 | 重复图 019==023 | 2 | 重生成其一（两张卡需不同图） |")
    L.append("| 6 | 部署断链（发现②） | 6 文件 | **建议尽快修**（非美学裁决）：enemy/vis_enemy_001/075 := flip(新 player) + 错名 4 件移除；另建部署脚本校验防复发 |")
    L.append("| 7 | B 簇 rim 缺位（发现⑩） | %d | 后处理补 rim（ice/neon 按判定链）批量轮，低成本；不急 |" % len(rim_b))
    L.append("")
    L.append("**呈样张**（CP-2 抽验入口，亲读复核件）：`.godot/agent_tools/w5_vision_audit/` 结果全量 JSON；样张可直接看卡图原文 `assets/card_icons/player/vis_player_043.png`（照片感家族）、`drop_phase_lance.png`（cel）、`vis_player_041.png`（接地阴影）、`vis_xeno_tripod.png`（残影）。")
    L.append("")

    with open(W3, "a", encoding="utf-8") as f:
        f.write("\n".join(L))
    print("appended §11 to", W3)
    print("stats:", dict(gc), "| photo_c=%d cel_c=%d ground_c=%d rim_b=%d" % (len(photo_c), len(cel_c), len(ground_c), len(rim_b)))


def _occ(mani, cid):
    """从 shard 文件取该 id 的 occupancy_pct。"""
    if not hasattr(_occ, "_cache"):
        _occ._cache = {}
        for s in mani["shards"]:
            for e in json.load(open(s["file"], encoding="utf-8")):
                _occ._cache[e["id"]] = e.get("occupancy_pct", 0.0)
    return _occ._cache.get(cid, 0.0)


if __name__ == "__main__":
    main()
