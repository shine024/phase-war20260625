# -*- coding: utf-8 -*-
"""B5 WaveB 生图批（2026-10-04）：§十 锚定帧先行路线，13 案。
每案：阶段0 锚定帧（身份唯一真身，缺才生成）→ [want_idle] 锚定帧直出微呼吸 idle 主版（512 基）
    → [want_attack] 阶段1 3×2 攻击表多掷（--cells-json 想像力脚本 + R2 轴描述/框景英文条款）。
断点续跑：锚定帧看 <key>_anchor_raw.png；攻击看 <key>.b5att 标记（全部掷次落盘才写）。
产物只落 .godot/unit_review/img25_staging/，绝不写 assets/（§十 铁律）。
用法: python tools/_b5_gen_batch.py [--only key1,key2]
"""
import io
import json
import os
import subprocess
import sys
import types
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")

AXIS_EN = ("Strictly flat side profile facing left: the camera is exactly at the subject's own side, "
           "level with its midline; the subject's long axis stretches horizontally across the whole image, "
           "its upright parts stay vertical, no perspective foreshortening. "
           "Zoomed-out wide framing: the whole subject fully inside each cell with generous empty space "
           "on all four sides, far from the cell edges.")

JOBS = [
    dict(key="cold_inf_m60", card="enemy/vis_enemy_051.png", rolls=0, idle=1, att=0,
         subject="冷战时期美军M60通用机枪手，橄榄绿作战服与M1钢盔，单人持M60机枪（两脚架收拢），放松站立，枪身垂持于腰侧枪口斜向下"),
    dict(key="fut_arm_mech_e", card="enemy/vis_enemy_067.png", rolls=0, idle=1, att=0,
         subject="未来派敌方重型双足战斗机甲，深蓝灰厚装甲板与肩部火箭舱，头部单条视觉窗，厚重液压双腿站立"),
    dict(key="ww1_sup_mg_nest", card="enemy/vis_enemy_038.png", rolls=0, idle=1, att=0,
         subject="第一次世界大战重机枪掩体，沙袋堆环形工事中一挺水冷式重机枪，枪管带散热套筒指向画面左侧"),
    dict(key="ww2_sup_mg42", card="enemy/vis_enemy_045.png", rolls=2, idle=1, att=1,
         subject="第二次世界大战德军MG42通用机枪手，原野灰作战服与钢盔，腰挂弹药盒，双手持MG42机枪枪口斜向下待机",
         cells=dict(seq="机枪扫射", cells={"1": "枪托抵肩微微上抬，枪口泛起点点微光",
                                          "2": "枪口爆出锐长橙红色火光，弹壳向右抛出",
                                          "3": "火光衰减，枪口青烟拉出一缕",
                                          "4": "枪管微微发红冒热气，身体被后坐轻推",
                                          "5": "回到待机持枪"}, fx="只要枪口火光与硝烟弹壳，无弹道无曳光")),
    dict(key="ww2_boss_kingtiger", card="enemy/vis_enemy_049.png", rolls=3, idle=1, att=1,
         subject="第二次世界大战德国虎王重型坦克，亨舍尔炮塔，长身管88毫米炮指向画面左侧，德国灰涂装，履带裙板",
         cells=dict(seq="主炮齐射", cells={"1": "炮管微微后缩蓄力，炮口泛起微光",
                                          "2": "炮口爆出巨大橙白色火光，整车明显后坐",
                                          "3": "火光衰减，大团硝烟从炮口散开",
                                          "4": "后坐复位，炮口余烟缭绕",
                                          "5": "回到待机"}, fx="只有炮口火光与硝烟，无弹道无曳光")),
    dict(key="ww2_air_bomber", card="enemy/ww2_air_bomber.png", rolls=3, idle=0, att=1,
         subject="第二次世界大战四发重型螺旋桨轰炸机，深绿涂装白机徽，机背炮塔与机鼻玻璃投弹舱，四台螺旋桨发动机，纯侧面朝左平飞",
         cells=dict(seq="投弹", cells={"1": "机腹弹舱门缓缓开启",
                                       "2": "一串炸弹脱离机腹向下坠落",
                                       "3": "炸弹坠离画面，舱门全开",
                                       "4": "弹舱门收拢复位",
                                       "5": "回到待机平飞"}, fx="机身保持水平飞行姿态绝不掉头，无爆炸无火光")),
    dict(key="ww1_arty_mortar", card="enemy/vis_enemy_039.png", rolls=2, idle=0, att=1,
         subject="第一次世界大战堑壕迫击炮，短粗炮管斜指左上方约六十度，圆形钢制底座与两根支撑架",
         cells=dict(seq="曲射", cells={"1": "炮身微微下沉蓄力",
                                       "2": "炮口喷出球形橙红膛口焰，一发电球离开炮口向上",
                                       "3": "膛口焰散成烟环，炮身回弹",
                                       "4": "炮口余烟上飘，底座尘土微扬",
                                       "5": "回到待机仰角"}, fx="炮口朝天开火，无弹道无落点爆炸")),
    dict(key="ww1_a7v", card="player/ww1_a7v.png", rolls=2, idle=0, att=1,
         subject="第一次世界大战德国A7V突击坦克，高大火箱形铆接车体，灰绿色钢板，车体侧面机枪射孔",
         cells=dict(seq="侧射", cells={"1": "侧面机枪射口泛起微光",
                                       "2": "射口喷出短促橙红火光",
                                       "3": "火光衰减，青烟贴着车体散开",
                                       "4": "射口余烟",
                                       "5": "回到待机"}, fx="车体长轴水平横贯画面，只有射口火光与硝烟")),
    dict(key="ww1_lanchest", card="player/ww1_lanchest.png", rolls=2, idle=0, att=1,
         subject="第一次世界大战英国兰彻斯特装甲车，直立式驾驶楼与后置圆炮塔，深绿橄榄涂装，辐条车轮",
         cells=dict(seq="炮塔机枪射击", cells={"1": "炮塔机枪微微上抬泛光",
                                               "2": "枪口喷出短促橙红火光，弹壳抛出",
                                               "3": "火光衰减，青烟一缕",
                                               "4": "枪口余烟缭绕",
                                               "5": "回到待机"}, fx="只有枪口火光与硝烟，无弹道")),
    dict(key="ww1_mark4", card="player/ww1_mark4.png", rolls=3, idle=1, att=1,
         subject="第一次世界大战英国Mark IV菱形坦克，菱形车体环绕履带，侧面艏炮炮管伸出，土黄迷彩涂装",
         cells=dict(seq="艏炮开火", cells={"1": "艏炮微微后缩蓄力泛光",
                                          "2": "艏炮喷出橙白色火光，车体微震",
                                          "3": "火光衰减硝烟涌出",
                                          "4": "炮管复位余烟缭绕",
                                          "5": "回到待机"}, fx="只有炮口火光与硝烟，无弹道无曳光")),
    dict(key="mod_arm_m1a2sep", card="player/vis_player_023.png", rolls=3, idle=1, att=1,
         subject="现代美军M1A2 SEP艾布拉姆斯主战坦克，沙黄色涂装，侧裙板，120毫米滑膛炮指向画面左侧，指挥塔观瞄",
         cells=dict(seq="主炮开火", cells={"1": "炮管微微后缩蓄力，炮口泛起微光",
                                          "2": "炮口爆出巨大橙白色火光，整车明显后坐",
                                          "3": "火光衰减，大团硝烟散开",
                                          "4": "后坐复位，炮口余烟缭绕",
                                          "5": "回到待机"}, fx="只有炮口火光与硝烟，无弹道无曳光")),
    dict(key="mod_air_technical_e", card="enemy/vis_enemy_058.png", rolls=2, idle=0, att=1,
         subject="现代武装皮卡战车，白色双排座皮卡后斗上架设一挺重机枪，枪身与枪口朝向画面左侧，车斗前撑支架",
         cells=dict(seq="机枪扫射", cells={"1": "机枪微微上抬，枪口泛起微光",
                                          "2": "枪口喷出锐长橙红火光，弹壳向右抛出",
                                          "3": "火光衰减，枪口青烟一缕",
                                          "4": "枪身随连发轻颤",
                                          "5": "回到待机"}, fx="枪口必须朝画面左侧绝不能朝向镜头前方，无弹道无曳光")),
    dict(key="ww1_arty_77mm", card="player/vis_player_003.png", rolls=3, idle=1, att=1,
         subject="第一次世界大战德国77毫米克虏伯野战炮，细长炮管水平指向画面左侧，双轮炮架与防盾，灰绿色涂装，木质辐条轮",
         cells=dict(seq="野炮齐射", cells={"1": "炮身沿炮架后滑蓄力泛光",
                                          "2": "炮口爆出橙白色火光，整车后坐",
                                          "3": "火光衰减大团硝烟散开",
                                          "4": "炮架回弹复位余烟缭绕",
                                          "5": "回到待机"}, fx="只有炮口火光与硝烟，无弹道无曳光")),
]


def load_mod(name, path):
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines() if "sys.stdout = io.TextIOWrapper" not in ln]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


ag = load_mod("b5_ag", os.path.join(ROOT, "tools", "img25_attack_gen.py"))

import numpy as np  # noqa: E402


def build_idle(key):
    """锚定帧 → 键控/depink/主体保留/bbox → 512 基fit（底缘锚定）→ 8 帧微呼吸环。"""
    raw = Image.open(os.path.join(OUT, key + "_anchor_raw.png")).convert("RGB")
    bg = ag.detect_bg_color(raw)
    rgba = ag.chroma_key(raw, bg, tol=85)
    rgba = ag.depink(rgba)
    rgba = ag.keep_main_bodies(rgba, 0.35)
    box = ag.alpha_bbox(rgba)
    if box is None:
        print("[idle:%s] 键控后空图！" % key)
        return False
    body = rgba.crop(box)
    FS2 = 512
    w, h = body.size
    sc = min((FS2 - 40) / w, (FS2 - 40) / h, 1.6)
    body = body.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
    base = Image.new("RGBA", (FS2, FS2), (0, 0, 0, 0))
    base.paste(body, ((FS2 - body.width) // 2, FS2 - 16 - body.height), body)
    a0 = np.asarray(base)
    up = np.roll(a0, -2, axis=0)
    up[-2:, :] = 0
    loop = [a0, a0, up, up, a0, a0, a0, a0]
    sheet = Image.new("RGBA", (8 * FS2, FS2), (0, 0, 0, 0))
    for i, f in enumerate(loop):
        sheet.paste(Image.fromarray(f), (i * FS2, 0))
    sheet.save(os.path.join(OUT, "%s_idle_sheet_512.png" % key))
    # 预览网格
    g = Image.new("RGBA", (4 * 256, 2 * 256), (40, 44, 52, 255))
    for i, f in enumerate(loop):
        fr = Image.fromarray(f).resize((256, 256), Image.LANCZOS)
        g.paste(fr, (i % 4 * 256, i // 4 * 256), fr)
    g.convert("RGB").save(os.path.join(OUT, "%s_idle_grid_preview.png" % key))
    print("[idle:%s] OK" % key, flush=True)
    return True


from PIL import Image  # noqa: E402


def run(cmd):
    print("  $", " ".join(cmd[2:]), flush=True)
    return subprocess.call(cmd, cwd=ROOT)


def main():
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    for job in JOBS:
        if only and job["key"] not in only:
            continue
        key = job["key"]
        card = os.path.join(ROOT, "assets", "card_icons", job["card"])
        anchor = os.path.join(OUT, key + "_anchor_raw.png")
        print("== %s ==" % key, flush=True)
        if not os.path.isfile(anchor):
            if run([sys.executable, os.path.join(ROOT, "tools", "img25_anchor_gen.py"),
                    key, card, "--chroma-out"]) != 0 or not os.path.isfile(anchor):
                print("[FAIL] 锚定帧 %s" % key, flush=True)
                continue
        else:
            print("  锚定帧已有，跳过", flush=True)
        if job["idle"] and not os.path.isfile(os.path.join(OUT, "%s_idle_sheet_512.png" % key)):
            build_idle(key)
        if job["att"]:
            marker = os.path.join(OUT, "%s.b5att" % key)
            if os.path.isfile(marker):
                print("  攻击表已有标记，跳过", flush=True)
            else:
                cj = os.path.join(OUT, "_b5_cells_%s.json" % key)
                with open(cj, "w", encoding="utf-8") as f:
                    json.dump(dict(job["cells"], extra=AXIS_EN), f, ensure_ascii=False)
                rc = run([sys.executable, os.path.join(ROOT, "tools", "img25_attack_gen.py"),
                          key, "--subject", job["subject"], "--rolls", str(job["rolls"]),
                          "--card", card, "--cells-json", cj])
                got = [f for f in os.listdir(OUT)
                       if f.startswith(key + "_R") and f.endswith("_attack_sheet_832.png")]
                if rc == 0 and got:
                    with open(marker, "w") as f:
                        f.write("%d rolls" % job["rolls"])
                else:
                    print("[FAIL] 攻击表 %s" % key, flush=True)
    print("B5 WaveB 批结束", flush=True)


if __name__ == "__main__":
    main()
