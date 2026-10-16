# -*- coding: utf-8 -*-
"""灵耀 API 单拍重掷试跑(2026-10-16):agnes 风控断供备份线。

协议:POST https://api.lingyaoai.com/v1/images/edits,multipart(model/prompt/image),
model=gpt-image-2(nano-banana-2.1 渠道坏,实测)。prompt 组装与 agnes 管线
(_tmp_api_firegrid_v2_20261015.py)完全同源:SKELETON+desc+pose+MARGIN+INV(+flash)。

暂存审阅制:输出落 .godot/unit_review/lingyao/,目验通过才进 poses+拼卷。
注意:灵耀输出尺寸不遵请求值(512 请求出 1254²),入 poses 前统一 resize 1024²。

用法:python -I -u -X utf8 tools/_tmp_lingyao_regen_20261016.py 053 TL
"""
import base64
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import _tmp_api_firegrid_v2_20261015 as V2  # noqa: E402  (ALL_CFG/V1/MARGIN/…)

API = "https://api.lingyaoai.com/v1/images/edits"
KEY = "sk-pMAcVaOGkhoAhu7CoEZ69QbpQAInG1qPb3xFOVUjaHGApMtt"
MODEL = "gpt-image-2"
RAW = V2.RAW
OUT = os.path.join(ROOT, ".godot", "unit_review", "lingyao")
TMP = os.path.join(ROOT, ".godot", "_ly_prompt.txt")

# 顺参考句覆写(039 教训:本尊跨步姿,prompt 逆参考必翻;2026-10-16 三本尊核对)
OVERRIDE = {
    "075:TL": "ready: the stormtrooper in the same advancing stride as the reference, "
              "the one MP18 raised and shouldered exactly as in the reference, aiming level left",
    "086:TL": "ready: the trooper in the same advancing stride as the reference, "
              "the M4 carbine raised and shouldered exactly as in the reference, aiming level left",
    "086:BL": "recoil: frozen mid-frame like a paused photograph in exactly the reference stance, "
              "the advancing stride unchanged, the M4 carbine still raised and shouldered, "
              "aiming level left, only his torso leaning back just a hair, "
              "both boots flat on the ground, no flash",
    "056:BL": "recoil: frozen mid-frame like a paused photograph in exactly the reference stance, "
              "the advancing stride unchanged, the M16A4 still raised and shouldered, "
              "aiming level left, only his torso leaning back just a hair, "
              "both boots flat on the ground, no flash",
}


def build_prompt(no, beat):
    """照抄 gen_unit 拼装,beat 序 TL/TR/BL/BR → poses[0..3]。"""
    beats = ["TL", "TR", "BL", "BR"]
    i = beats.index(beat)
    cfg = V2.merged_cfg(no)
    pose = OVERRIDE.get("%s:%s" % (no, beat), cfg["poses"][i])
    if no in V2.NO_WEAPON_NOS:
        prompt = (V2.V1.SKELETON.replace("{DESC}", cfg["desc"])
                  + "Now show THE SAME subject in this exact action beat: %s. " % pose
                  + V2.NO_WEAPON_MARGIN + V2.NO_WEAPON_INV
                  + " Identical scale and colors as the reference image.")
    else:
        prompt = (V2.V1.SKELETON.replace("{DESC}", cfg["desc"])
                  + "Now show THE SAME subject in this exact action beat: %s. " % pose
                  + V2.MARGIN + V2.V1.INV
                  + " Identical scale and colors as the reference image.")
    if beat == "TR" and cfg.get("flash"):
        prompt = prompt + " " + cfg["flash"]
    if beat != "TR":
        # 灵耀对 MARGIN "muzzle effects" 敏感,非开火拍必补禁焰(2026-10-16 批 4 拍焰泛滥教训)
        prompt = prompt + " No muzzle flash, no flame, no glow at the muzzle in this beat."
    return prompt


def gen_beat(no, beat):
    import _tmp_api_card_regen_batch2 as B2
    all_units = {u["no"]: u for u in V2.UNITS}
    for u in B2.UNITS2:
        all_units.setdefault(u["no"], u)
    u = all_units.get(no)
    if not u:
        print("[%s] 无单位" % no)
        return False
    card = os.path.join(RAW, "%s·%s.png" % (u["no"], u["name"]))
    if not os.path.exists(card):
        print("[%s] 卡图缺 %s" % (no, card))
        return False
    os.makedirs(OUT, exist_ok=True)
    prompt = build_prompt(no, beat)
    with open(TMP, "w", encoding="utf-8") as f:
        f.write(prompt)
    out_json = os.path.join(OUT, "_resp.json")
    cmd = ["curl", "-sS", "-m", "300", "-X", "POST", API,
           "-H", "Authorization: Bearer " + KEY,
           "-F", "model=" + MODEL,
           "-F", "prompt=<" + TMP,
           "-F", "image=@{}".format(card).replace("\\", "/"),
           "-F", "size=1024x1024",
           "-o", out_json,
           "-w", "%{http_code}"]
    t0 = __import__("time").time()
    code = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT).stdout.strip()
    dt = __import__("time").time() - t0
    if code != "200":
        print("[%s %s] HTTP %s %.0fs" % (no, beat, code, dt))
        try:
            print(open(out_json, encoding="utf-8", errors="replace").read()[:300])
        except OSError:
            pass
        return False
    d = json.load(open(out_json, encoding="utf-8"))
    if "data" not in d or not d["data"] or "b64_json" not in d["data"][0]:
        print("[%s %s] 应答无图: %s" % (no, beat, json.dumps(d, ensure_ascii=False)[:300]))
        return False
    raw = base64.b64decode(d["data"][0]["b64_json"])
    out_png = os.path.join(OUT, "%s·%s_%s.png" % (no, u["name"], beat))
    with open(out_png, "wb") as f:
        f.write(raw)
    from PIL import Image
    import io
    im = Image.open(io.BytesIO(raw))
    print("[%s·%s %s] OK %s %.0fs -> %s" % (no, u["name"], beat, im.size, dt,
                                            os.path.basename(out_png)))
    return True


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    import time
    fails = []
    for spec in sys.argv[1].split(","):
        no, beat = spec.split(":")
        if not gen_beat(no, beat.upper()):
            fails.append(spec)
        time.sleep(3)
    print("FAILS:", fails if fails else "none")
    sys.exit(0)
