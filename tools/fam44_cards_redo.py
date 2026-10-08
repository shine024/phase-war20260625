# -*- coding: utf-8 -*-
"""fam44 重做批·卡图生图（2026-10-06 深夜，用户「现在能做的都做」令）。

7 案（源=总审备注 + muzzle 页备注）：
  fe_quantum_mobile_base      卡图和待机攻击都重做（移动堡垒基地）
  fe_quantum_repair_drone     同上（纳米修复蜂群）
  fe_void_dimensional_soldier 同上（次元行者）
  fe_frontier_veteran         要先变攻击姿势（边境老兵）
  fe_iron_wall_juggernaut     要生成抬枪动作图（重装先驱）
  mod_arm_stryker_e           要重新生图，正侧视的（斯特赖克）
  mod_arm_m1a2sep             要正侧视的图（备选路线；img25_approved 锚定另有本地推导）

一律朝右生成（宪法口径）→ staging 目检 → 拍板后镜像/部署另行执行。
只落 .godot/unit_review/fam44_cards_redo/，绝不写 assets/。
用法: python tools/fam44_cards_redo.py [key ...]
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
API = "https://apihub.agnes-ai.cn/v1/images/generations"  # 图像域=cn，须 --ssl-no-revoke
STAGE = os.path.join(ROOT, ".godot", "unit_review", "fam44_cards_redo")
os.makedirs(STAGE, exist_ok=True)
MODEL = "agnes-image-2.5-flash"

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
    "fe_quantum_mobile_base": dict(
        axis=AXIS_TANK,
        subject=("近未来巨型移动堡垒基地车（quantum mobile fortress base）：重型八轮轮式底盘，"
                 "宽厚浅灰蓝装甲车体，车体上方中央一座指挥塔桥楼（command tower superstructure）"
                 "带观察窗与碟形天线（dish antenna），车侧淡青色能量导管，白色补给舱段，"
                 "整体是单一辆巨型车辆"),
        pose="静驻姿态，车轴水平，无炮口焰。"),
    "fe_quantum_repair_drone": dict(
        axis=AXIS_AIR,
        subject=("近未来纳米修复无人机群（nano repair drone swarm）视作单一单位主体："
                 "三四架小型四旋翼无人机紧贴成簇紧凑编队同高并排悬浮，浅灰白机身，"
                 "腹下挂机械维修臂与工具吊舱，机臂尖端极淡青色指示灯——"
                 "这群无人机就是本单位唯一主体本身，不是背景道具"),
        pose="并排同高悬停姿态，无地面。"),
    "fe_void_dimensional_soldier": dict(
        axis=AXIS_INF,
        subject=("科幻次元行者士兵（dimensional walker）：哑光深黑装甲服，装甲缝隙泛紫罗兰色"
                 "能量纹路（violet energy seams），全罩头盔面罩上一条发光紫色目镜缝，"
                 "肩甲与胸甲层叠，双手持一把造型简洁的能量步枪（energy rifle），"
                 "完整全身从盔顶到靴底全部入镜"),
        pose="持枪行进间准备姿态，枪口朝画面正右方。"),
    "fe_frontier_veteran": dict(
        axis=AXIS_INF,
        subject=("现代边境老兵（frontier veteran）：灰白短须络腮胡，皱纹深嵌的面庞，"
                 "棕褐色磨旧作战服与战术背心，腿侧弹匣包，旧式复合头盔，"
                 "双手持自动步枪（battle rifle）带光学瞄具，"
                 "完整全身从盔顶到靴底全部入镜"),
        pose="据枪攻击姿态：枪托抵肩贴腮，上身前倾，双手上抬据枪瞄准，枪口朝画面正右方。"),
    "fe_iron_wall_juggernaut": dict(
        axis=AXIS_INF,
        subject=("近未来重装先驱（heavy juggernaut vanguard）：高大厚重外骨骼装甲士兵，"
                 "橄榄灰绿色重型装甲板，宽大肩甲与层叠胸甲，液压关节与背部动力骨架，"
                 "双手持一挺重型加特林机枪（heavy gatling gun）带弹链箱，"
                 "完整全身从盔顶到靴底全部入镜"),
        pose="抬枪攻击姿态：加特林机枪整体抬至肩侧据枪，枪口明显上抬指向画面右上方，枪身轴线清晰可读。"),
    "mod_arm_stryker_e": dict(
        axis=AXIS_TANK,
        subject=("现代美军斯特赖克八轮装甲车（Stryker 8x8 armored personnel carrier）："
                 "楔形钝首车体，车顶遥控武器站（remote weapon station）带一挺机枪，"
                 "车侧八个大直径防弹轮毂侧视排成单列，沙黄色涂装，车尾跳板门，"
                 "车体侧面储物栏与天线"),
        pose="静驻姿态，车轴水平，无炮口焰。"),
    "mod_arm_m1a2sep": dict(
        axis=AXIS_TANK,
        subject=("现代美军 M1A2 SEP 艾布拉姆斯坦克（M1A2 SEP Abrams）：楔形复合装甲炮塔，"
                 "炮塔正面与侧裙挂贫铀装甲块，120 毫米滑膛炮带热护套与炮口校准镜，"
                 "车长周视镜与车体前部驾驶舱盖，七对负重轮与侧裙板，整体沙褐色涂装"),
        pose="静驻姿态，炮管水平指向前方，无炮口焰。"),
}
LIT_RESCUE = "。主体必须完全受光、亮度充足，绝不允许暗色剪影。"


def gen(payload, tag):
    pp = os.path.join(STAGE, "_payload.json")
    with open(pp, "w", encoding="utf-8") as f:
        f.write(json.dumps(payload))
    for i in range(3):
        r = subprocess.run(["curl", "--http1.1", "--ssl-no-revoke", "-s", "-X", "POST", API,
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
            dl = subprocess.run(["curl", "--http1.1", "--ssl-no-revoke", "-s", "-L", item["url"], "--max-time", "120"],
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
    print("fam44 卡重生成批完成 → %s" % STAGE, flush=True)


if __name__ == "__main__":
    main()
