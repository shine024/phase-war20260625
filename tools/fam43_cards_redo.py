# -*- coding: utf-8 -*-
"""fam43 v2 修复批·6 张卡重生成（2026-10-06 用户判定 JSON）。

病卡（fam43_fix_audit/_cards_*.png 目检）：
  ww2_air_dive_bomber  3/4 俯视角非正侧（Ju 87 斯图卡）
  fut_arm_prism        3/4 视角 + 敌方卡朝右违契约（白灰棱镜坦克）
  ww1_inf_mp18_x       卡图自带粗黑描边 + 半身构图（MP18 冲锋枪手）
  ww2_arm_garand_para  卡图自带粗黑描边（加兰德伞兵）
  mod_sup_m4_carbine   alpha 缺洞=前小腿被白底吃了（M4 卡宾枪手）
  mod_air_multirole    卡面白斑颜料病（多功能战斗机）

一律朝右生成（宪法口径）→ 目检 → 镜像朝左部署敌方卡（拍板后另行执行）。
只落 staging .godot/unit_review/fam43_cards_redo/，绝不写 assets/。
用法: python tools/fam43_cards_redo.py [key ...]
"""
import base64
import io
import json
import os
import re
import subprocess
import sys
import time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS_API = re.findall(r"sk-[A-Za-z0-9]{20,}",
                      open(os.path.join(ROOT, "tools", "_agnes_image_api.md"), encoding="utf-8").read())
API = "https://apihub.agnes-ai.com/v1/images/generations"
STAGE = os.path.join(ROOT, ".godot", "unit_review", "fam43_cards_redo")
os.makedirs(STAGE, exist_ok=True)
MODEL = "agnes-image-2.5-flash"

# ---- 三类正交硬锁（STYLE_BIBLE §四 + §6.1.3 几何段）----
AXIS_INF = ("视点在主体正侧方：只见单侧脸颊与单侧肩膀，远侧手臂被躯干遮挡，"
            "鼻尖与武器枪口同指画面正右方；无任何透视缩短；")
AXIS_TANK = ("视点在车体正侧方：车体主轴水平横贯画面，两侧负重轮与履带侧视重叠成单列，"
             "只见车体单侧面，不见车头正面与车尾正面；无任何透视缩短；")
AXIS_AIR = ("视点在机身正侧方：机首与机尾在同一水平线上，两侧机翼因侧视重叠成单一线条"
            "（edge-on wings），只见机身单侧面，不见机头正面与机尾正面；无任何透视缩短；")

BASE_TAIL = ("完整全身居中入镜，四周留约百分之十白色边距，主体任何部分不得触碰画布四边，脚部/起落架完整落在画面内。"
             "低饱和冷灰化军械色调，主体受光充足、照明均匀，高光与暗部层次分明，材质细节清晰可读，"
             "绝不允许画成黑色剪影或单色深色轮廓块；轮廓边缘干净利落，不要粗黑描边，"
             "不要外发光光晕，不要深色轮廓线包边；"
             "厚涂插画风格（thick painterly illustration），形体由色块与明暗交界塑造，"
             "笔触平滑融合（smooth blended painterly brushwork, rendered color masses）；"
             "干净棚拍纯白背景，无地面无场景无杂物无投影；"
             "【单一主体·硬性】画面中只允许出现这一个主体本身，严禁出现第二个人物、背景人物、"
             "背景车辆或任何背景道具；背景是摄影棚白底，不是战场；"
             "画面中没有文字、水印、边框、旗帜徽标字母；"
             "严禁大面积高饱和绿、大面积正红、粉、品红、俯视、斜视角、3/4视角、画面裁切、透视缩短。"
             "text, perspective view, frame, ground, ceiling, foreshortening")

UNITS = {
    "ww2_air_dive_bomber": dict(
        axis=AXIS_AIR,
        subject=("二战德军 Ju 87 斯图卡俯冲轰炸机（Junkers Ju 87 Stuka）：倒鸥形机翼（inverted gull wings）、"
                 "固定式起落架带流线型轮罩（fixed spatted landing gear）、纵长全玻璃座舱盖（long fully "
                 "glazed canopy）、单具三叶螺旋桨在机首，机身方正骨架感，德军灰绿迷彩单体机"),
        pose="水平直线平飞姿态，机首朝画面正右方，起落架放下状态。"),
    "fut_arm_prism": dict(
        axis=AXIS_TANK,
        subject=("近未来轻型棱镜坦克（prism light tank）：流线浅灰白色多棱角装甲车体，"
                 "低矮三棱柱形炮塔顶置，塔前伸出一根细长晶体棱镜炮管（long thin crystalline prism cannon），"
                 "车体侧面的能量导管泛极淡青色，履带行走机构完整"),
        pose="静驻姿态，炮管水平指向前方，无炮口焰。"),
    "ww1_inf_mp18_x": dict(
        axis=AXIS_INF,
        subject=("一战德军暴风突击队 MP18 冲锋枪手（German stormtrooper）：M1916 圆顶钢盔（Stahlhelm）、"
                 "原野灰野战服与皮质装具、腰间弹药 pouches、长筒行军靴，双手持伯格曼 MP18 冲锋枪"
                 "（左侧蜗牛鼓弹鼓清晰可见），完整全身从钢盔到靴底全部入镜"),
        pose="持枪行进间准备姿态，枪口朝画面正右方。"),
    "ww2_arm_garand_para": dict(
        axis=AXIS_INF,
        subject=("二战美军空降兵（US Army paratrooper）：M1C 伞兵钢盔带下巴带、M1942 跳伞夹克与"
                 "伞兵装具、伞兵系带长靴，双手持 M1 加兰德步枪（M1 Garand），完整全身入镜"),
        pose="持枪行进间准备姿态，枪口朝画面正右方。"),
    "mod_sup_m4_carbine": dict(
        axis=AXIS_INF,
        subject=("现代步兵支援枪手（modern infantry rifleman）：战术头盔带导轨、防弹插板战术背心、"
                 "棕褐色系作战服，双手持 M4 卡宾枪（M4 carbine）配瞄准镜与护木，腿侧副包，"
                 "完整全身从盔顶到靴底全部入镜，两腿完整"),
        pose="持枪行进间准备姿态，枪口朝画面正右方。"),
    "mod_air_multirole": dict(
        axis=AXIS_AIR,
        subject=("现代单发多用途战斗机（modern single-engine multirole fighter jet）：气泡式座舱盖"
                 "（bubble canopy）、机腹进气道、三角翼与全动平尾、灰色现役涂装、"
                 "翼下挂格斗弹两枚，机首雷达罩清晰"),
        pose="水平直线平飞姿态，机首朝画面正右方，起落架收起状态。"),
}
LIT_RESCUE = "。主体必须完全受光、亮度充足，绝不允许暗色剪影。"


def gen(payload, tag):
    pp = os.path.join(STAGE, "_payload.json")
    with open(pp, "w", encoding="utf-8") as f:
        f.write(json.dumps(payload))
    for i in range(3):
        r = subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", API,
                            "-H", "Authorization: Bearer " + KEYS_API[i % len(KEYS_API)],
                            "-H", "Content-Type: application/json",
                            "--data-binary", "@" + pp, "--max-time", "360"],
                           capture_output=True, text=True, timeout=380)
        try:
            d = json.loads(r.stdout)
        except Exception:
            print("  [%s] 响应非 JSON: %s" % (tag, r.stdout[:100]), flush=True)
            time.sleep(12)
            continue
        if d.get("error") or d.get("code"):
            print("  [%s] API错: %s" % (tag, json.dumps(d, ensure_ascii=False)[:160]), flush=True)
            time.sleep(12)
            continue
        item = (d.get("data") or [{}])[0]
        if item.get("b64_json"):
            return base64.b64decode(item["b64_json"])
        if item.get("url"):
            dl = subprocess.run(["curl", "--http1.1", "-s", "-L", item["url"], "--max-time", "120"],
                                capture_output=True, timeout=140)
            try:
                Image.open(io.BytesIO(dl.stdout)).load()
                return dl.stdout
            except Exception:
                pass
    return None


def lit_gate_white(im):
    import numpy as np
    a = np.asarray(im.convert("RGB")).astype(int)
    border = np.concatenate([a[:3].reshape(-1, 3), a[-3:].reshape(-1, 3),
                             a[:, :3].reshape(-1, 3), a[:, -3:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    bg_ok = bool(bg.min() >= 225)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    body = dist > 100
    n = int(body.sum())
    if n < 4000:
        return False, {"bg": [round(float(v)) for v in bg], "body_px": n, "verdict": "empty"}
    rgb = a[body]
    mean = float(rgb.mean())
    lit = float((rgb.max(axis=1) > 100).mean())
    ok = bg_ok and mean >= 80 and lit >= 0.35
    return ok, {"bg": [round(float(v)) for v in bg], "body_px": n,
                "mean": round(mean, 1), "lit": round(lit, 2),
                "verdict": "pass" if ok else "dark"}


def run_case(key):
    u = UNITS[key]
    out = os.path.join(STAGE, "%s_raw.png" % key)
    if os.path.isfile(out) and os.path.getsize(out) > 10000:
        print("[skip] %s 已有" % key, flush=True)
        return
    prompt = ("游戏卡图立绘：%s。严格2D正侧视，正交投影，面朝画面正右方，绝不朝左；%s%s%s"
              % (u["subject"], u["axis"], u["pose"], BASE_TAIL))
    payload = {"model": MODEL, "prompt": prompt, "size": "1024x1024",
               "extra_body": {"response_format": "b64_json"}}
    t0 = time.time()
    raw = gen(payload, key)
    if not raw:
        print("[FAIL] %s 三次无果" % key, flush=True)
        return
    im = Image.open(io.BytesIO(raw)).convert("RGB")
    ok, info = lit_gate_white(im)
    if not ok and info.get("verdict") == "dark":
        raw2 = gen(dict(payload, prompt=prompt + LIT_RESCUE), key + "-r")
        if raw2:
            im2 = Image.open(io.BytesIO(raw2)).convert("RGB")
            ok2, info2 = lit_gate_white(im2)
            if ok2:
                im, ok, info = im2, ok2, info2
    im.save(out)
    print("[%s] %s %.0fs %s" % ("OK" if ok else "DARK", key, time.time() - t0,
                                json.dumps(info, ensure_ascii=False)), flush=True)


def main():
    keys = sys.argv[1:] or list(UNITS)
    for k in keys:
        run_case(k)
    print("fam43 卡重生成批完成 → %s" % STAGE, flush=True)


if __name__ == "__main__":
    main()
