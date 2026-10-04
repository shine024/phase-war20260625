# -*- coding: utf-8 -*-
"""img25 锚定帧重做批（2026-10-01 用户令：动画组成必须与卡图一致，减少与原图差异）。

背景: 特别批 10 单位中 6 个与卡图差异超限——
    fut_sup_ps9        线圈塔被画成帆（结构性走样，且该锚定帧未经用户目验）
    fut_stealth_bomber 轮廓走样 + 霓虹描线暗淡
    cold_mig21 / cold_rpg / mod_air_bomber  整体压暗成黑涂装（卡图为银灰/沙色）
    cold_ak47          大衣棕→绿、平端枪变低姿枪（进而诱发抬枪违规）
用户新标准: 组成与卡图一一对应（杜绝"刺刀兵背后多无人机"式自由发挥），配色不压暗。
做法: 复用 img25_anchor_gen（build_prompt 已加严：组成·硬性/配色·硬性/姿态随卡图），
    subject 逐单位按单读卡图重写；产出 卡图|旧锚定|新锚定 三栏对比图落本目录供目验。
铁律: img25_approved/ 里用户冻结的旧锚定绝不覆盖绝不删除（二进制资产不入 git，删=永久）；
    新锚定先落 staging 根，用户目验通过后再替换（旧的改名 _old 留档）。

用法:
    python tools/img25_anchor_redo.py                # 全量 6 单位重生成+对比图
    python tools/img25_anchor_redo.py --keys fut_sup_ps9
    python tools/img25_anchor_redo.py --panel-only   # 只重画对比图（含 hummer 待目验栏）
"""
import argparse
import base64
import json
import os
import shutil
import sys
import time

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import img25_anchor_gen as G  # noqa: E402

ROOT = G.ROOT
WORK = os.path.join(ROOT, ".godot", "unit_review")
STAGING = os.path.join(WORK, "img25_staging")
APPROVED = os.path.join(WORK, "img25_approved")
REDO = os.path.join(STAGING, "_special10", "_anchor_redo")

# key -> (卡图相对路径, subject)；subject 全部来自 2026-10-01 逐张单读卡图
SUBJECTS = {
    "cold_ak47": (
        "assets/card_icons/player/vis_player_050.png",
        "一名苏式步枪兵：橄榄绿钢盔、灰棕色长款大衣、胸前棕色弹药盒、背后绿色背包与卷毯、黑色长靴，"
        "双手水平端持一支带木质护木、木质枪托和弧形弹匣的突击步枪，枪口水平指向画面左方。"
        "人物、装具、步枪的部件组成和配色与卡图完全一致（大衣保持卡图的灰棕色，严禁改成绿色军装）"),
    "cold_mig21": (
        "assets/card_icons/player/vis_player_056.png",
        "一架轻型喷气战斗机：浅银灰色机身带橄榄绿迷彩斑块、机背双垂尾、气泡形座舱盖、灰色雷达罩，机头朝左。"
        "不外挂导弹炸弹。配色严格保持卡图的浅银灰+绿斑（严禁整体压暗、严禁改成黑色或深绿涂装）"),
    "cold_rpg": (
        "assets/card_icons/player/vis_player_046.png",
        "一挺架设状态的沙色反坦克火箭炮（无后坐力炮）：沙色长发射管、管口插着一枚绿色火箭弹（弹头朝左）、"
        "炮身中部一块多边形沙色盾板、管下方一个绿色弹药箱、沙色开脚大架与驻锄。全组只有这一套武器系统，无人物。"
        "配色保持卡图的沙色+绿色（严禁整体改成黑色）"),
    "fut_stealth_bomber": (
        "assets/card_icons/player/vis_player_094.png",
        "一架深炭灰色隐形战斗机：菱形融合机身、外倾双垂尾、翼身融合边条，机头朝左。"
        "机身棱线有明亮的青蓝色霓虹发光描线、座舱盖有蓝色光边——霓虹亮度与卡图一致（清晰醒目，不许暗淡消失），"
        "机身保持卡图炭灰色不许更黑。只有这一架飞机，无僚机无无人机"),
    "fut_sup_ps9": (
        "assets/card_icons/player/fut_sup_ps9.png",
        "一辆履带式特种车辆：橄榄灰绿装甲车体（车首朝左、每侧约八个负重轮），"
        "车体中央矗立一座特斯拉线圈塔（中段线圈柱、顶部圆盘法兰盖，发蓝光），"
        "线圈塔前后各立一根带圆盘绝缘裙的细桅杆，三根塔杆顶端之间有蓝色电弧相连——电弧是设备本体特征必须保留；"
        "车体后部放一台灰色发动机机组。所有部件与卡图一一对应原位保留"
        "（严禁把线圈塔画成帆、帆布或风帆，严禁删掉桅杆、发动机、线圈塔任何一个）"),
    "mod_air_bomber": (
        "assets/card_icons/player/mod_air_bomber.png",
        "一架大型喷气战略轰炸机：细长圆柱机身、后掠上单翼（纯侧视可见翼下四个发动机短舱）、"
        "高耸单垂尾、浅灰色涂装，机头朝左，无外挂无开火。配色严格保持卡图的浅灰色"
        "（严禁整体压暗成黑色或深灰色）"),
}

# 只出对比图不出图（锚定帧本身待用户目验）
PANEL_ONLY = {
    "mod_hummer_m2": "assets/card_icons/player/vis_player_058.png",
}


def gen_one(key, card_rel, subject):
    card_img = Image.open(os.path.join(ROOT, card_rel)).convert("RGB").resize((512, 512), Image.LANCZOS)
    uri = "data:image/png;base64," + base64.b64encode(G._png_bytes(card_img)).decode()
    payload = os.path.join(STAGING, "_anchor_payload.json")
    with open(payload, "w", encoding="utf-8") as f:
        f.write(json.dumps({"model": "agnes-image-2.5-flash",
                            "prompt": G.build_prompt(subject),
                            "size": "1K", "ratio": "1:1",
                            "extra_body": {"image": [uri], "response_format": "b64_json"}},
                           ensure_ascii=False))
    t0 = time.time()
    raw = G.gen_image(payload)
    if raw is None:
        print("[%s] 生成失败（3 掷皆废）" % key, flush=True)
        return False
    out = os.path.join(STAGING, key + "_anchor_raw.png")
    with open(out, "wb") as f:
        f.write(raw)
    print("[%s] 新锚定帧 OK (%.0fs)" % (key, time.time() - t0), flush=True)
    return True


def panel(key, card_rel, new_label="新锚定帧"):
    """卡图 | 旧锚定(如有) | 新锚定 三栏对比图 -> REDO/<key>_cmp_anchor.png"""
    H = 380
    parts = [("卡图", os.path.join(ROOT, card_rel))]
    old = os.path.join(APPROVED, key + "_anchor_raw.png")
    if not os.path.exists(old):
        old = os.path.join(STAGING, key + "_anchor_old.png")
    if os.path.exists(old):
        parts.append(("旧锚定帧", old))
    new = os.path.join(STAGING, key + "_anchor_raw.png")
    if not os.path.exists(new):
        print("[%s] 缺新锚定帧，跳过对比图" % key)
        return
    parts.append((new_label, new))
    scaled = []
    for lab, p in parts:
        im = Image.open(p).convert("RGBA")
        w = max(1, int(im.width * H / im.height))
        scaled.append((lab, im.resize((w, H), Image.LANCZOS)))
    W = sum(p.width for _, p in scaled) + 8 * (len(scaled) + 1) + 130 * len(scaled)
    sheet = Image.new("RGB", (W, H + 44), (70, 70, 70))
    d = ImageDraw.Draw(sheet)
    x = 8
    for lab, p in scaled:
        sheet.paste(p, (x, 8), p)
        d.text((x + 2, H + 16), lab, fill=(255, 255, 80))
        x += p.width + 138
    sheet.save(os.path.join(REDO, key + "_cmp_anchor.png"))
    print("[%s] 对比图 OK" % key, flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keys", default=",".join(SUBJECTS))
    ap.add_argument("--panel-only", action="store_true", help="不调 API，只重画对比图")
    args = ap.parse_args()
    sub = set(args.keys.split(","))
    os.makedirs(REDO, exist_ok=True)

    if not args.panel_only:
        ok = []
        for key, (card_rel, subject) in SUBJECTS.items():
            if key not in sub:
                continue
            stale = os.path.join(STAGING, key + "_anchor_raw.png")
            if os.path.exists(stale):  # staging 残留旧稿挪走，避免新旧混淆
                shutil.move(stale, os.path.join(STAGING, key + "_anchor_old.png"))
            if gen_one(key, card_rel, subject):
                panel(key, card_rel)
                ok.append(key)
        print("重做完成 %d: %s" % (len(ok), sorted(ok)), flush=True)

    for key, card_rel in PANEL_ONLY.items():  # hummer 待目验栏（不重生成）
        panel(key, card_rel, new_label="锚定帧(待目验)")
    print("对比图目录:", REDO)


if __name__ == "__main__":
    main()
