# -*- coding: utf-8 -*-
"""ww2_inf_bazooka 身份病修复·出新卡（2026-10-05）：B4 同款 agnes 文生图暂存批。

背景：ww2_inf_bazooka（巴祖卡组）无专属卡图，icon 解析回退 vis_009（tan 装甲车），
卡图/锚定/攻击动画/游戏部署 idle 全是车——出巴祖卡火箭筒手专属卡，过 lit_gate，
暂存 .godot/unit_review/bazooka_card_staging/ 绝不写 assets/（§十 铁律），用户拍板后部署。

用法: python tools/_bazooka_card_gen.py        # 3 候选全生成
      python tools/_bazooka_card_gen.py cand_b # 只生成指定案
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
KEYS = re.findall(r"sk-[A-Za-z0-9]{20,}",
                  open(os.path.join(ROOT, "tools", "_agnes_image_api.md"), encoding="utf-8").read())
API = "https://apihub.agnes-ai.com/v1/images/generations"  # 2026-10-05 cn 域 TLS 全死，图像走 com 实测 200
STAGE = os.path.join(ROOT, ".godot", "unit_review", "bazooka_card_staging")
os.makedirs(STAGE, exist_ok=True)
MODEL = "agnes-image-2.5-flash"

SUBJECT = ("二战美军巴祖卡火箭筒手（M1 bazooka gunner），单名士兵：M1钢盔、人字纹野战服与"
           "帆布装具，低饱和橄榄绿偏冷灰化涂装；M1巴祖卡火箭筒长筒右肩上肩托，双手持筒"
           "（前手握筒身、后手握握把），筒口朝画面正右方，筒身带 small 方形瞄准具与尾缘排气罩，"
           "背后斜挎一支加兰德M1步枪（背带可见）；肩上的火箭筒是绝对主视觉，"
           "标准制式装备，干净利落的量产感")

# 四件套（docs/单位分帧动画生成管线.md orthographic 硬锁句式）
AXIS = ("视点在主体正侧方：只见单侧脸颊与单侧肩膀，远侧手臂被躯干遮挡，"
        "火箭筒筒口与鼻尖同指画面正右方；无任何透视缩短；")
POSE = ("双手持火箭筒举至肩，筒托肩上、贴腮瞄准，做射击准备姿；")

BASE_TAIL = ("完整全身居中入镜，四周留约百分之十白色边距，主体任何部分不得触碰画布四边，脚部完整落在画面内。"
             "低饱和冷灰化军绿钢色调（muted desaturated olive drab and cold grey），主体受光充足、照明均匀，"
             "高光与暗部层次分明，材质细节清晰可读，绝不允许画成黑色剪影或单色深色轮廓块；"
             "厚涂插画风格（thick painterly illustration），形体由色块与明暗交界塑造，"
             "笔触平滑融合（smooth blended painterly brushwork, rendered color masses）；"
             "干净棚拍纯白背景，无地面无场景无杂物无投影；"
             "【单一主体·硬性】画面中只允许出现这一名士兵本身，严禁出现第二名士兵、背景战友、"
             "背景车辆、背景坦克或任何背景道具；背景是摄影棚白底，不是战场；"
             "画面中没有文字、水印、边框、旗帜徽标字母；"
             "严禁大面积高饱和绿、大面积正红、粉、品红、俯视、斜视角、3/4视角、画面裁切、透视缩短。"
             "text, perspective view, frame, ground, ceiling, foreshortening")

CANDS = {
    "cand_a": "游戏卡图立绘：%s。严格2D正侧视，正交投影，面朝画面正右方，绝不朝左；%s%s站姿。%s"
              % (SUBJECT, AXIS, POSE, BASE_TAIL),
    "cand_b": "游戏卡图立绘：%s。严格2D正侧视，正交投影，面朝画面正右方，绝不朝左；%s%s"
              "单膝跪地右膝跪姿（kneeling firing pose），左腿前屈踩地，跪姿肩射。%s"
              % (SUBJECT, AXIS, POSE, BASE_TAIL),
    "cand_c": "游戏卡图立绘：%s。严格2D正侧视，正交投影，面朝画面正右方，绝不朝左；%s%s站姿，"
              "筒尾排气罩与背带细节更清晰，装具上多一枚火箭弹背袋。%s"
              % (SUBJECT, AXIS, POSE, BASE_TAIL),
}
LIT_RESCUE = "。主体必须完全受光、亮度充足，绝不允许暗色剪影。"


def gen(payload, tag):
    pp = os.path.join(STAGE, "_payload.json")
    with open(pp, "w", encoding="utf-8") as f:
        f.write(json.dumps(payload))
    for i in range(3):
        r = subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", API,
                            "-H", "Authorization: Bearer " + KEYS[i % len(KEYS)],
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
    """白底卡图亮度门：底要白、本体要受光不剪影、本体量要足（B4 同款）。"""
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


def run_case(cid, prompt):
    out = os.path.join(STAGE, "%s_raw.png" % cid)
    if os.path.isfile(out) and os.path.getsize(out) > 10000:
        print("[skip] %s 已有" % cid, flush=True)
        return
    payload = {"model": MODEL, "prompt": prompt, "size": "1024x1024",
               "extra_body": {"response_format": "b64_json"}}
    t0 = time.time()
    raw = gen(payload, cid)
    if not raw:
        print("[FAIL] %s 三次无果" % cid, flush=True)
        return
    im = Image.open(io.BytesIO(raw)).convert("RGB")
    ok, info = lit_gate_white(im)
    if not ok and info.get("verdict") == "dark":
        raw2 = gen(dict(payload, prompt=prompt + LIT_RESCUE), cid + "-r")
        if raw2:
            im2 = Image.open(io.BytesIO(raw2)).convert("RGB")
            ok2, info2 = lit_gate_white(im2)
            if ok2:
                im, ok, info = im2, ok2, info2
    im.save(out)
    print("[%s] %s %.0fs %s" % ("OK" if ok else "DARK", cid, time.time() - t0,
                                json.dumps(info, ensure_ascii=False)), flush=True)


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    for cid, prompt in CANDS.items():
        if only and only not in cid:
            continue
        run_case(cid, prompt)
    print("bazooka 出卡完成 → %s" % STAGE, flush=True)


if __name__ == "__main__":
    main()
