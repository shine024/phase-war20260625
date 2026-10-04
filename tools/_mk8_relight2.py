# -*- coding: utf-8 -*-
"""MK8 relight 回收（2026-10-05）：_mk8_anchor2 两枚锚定帧暗场废品（body_mean~45，
lit_frac<=0.09 —— 源卡图本就深色，img2img 继承暗度）→ relight_prompt() 双图回收：
Image1=结构正确的暗锚定，Image2=现役成品 idle f0 品红底（正确配色标准）。只修光照配色。
relit 过 lit_gate 后覆写 <key>_anchor_raw.png；attack 掷须重跑（旧掷继承暗锚定）。
用法: python tools/_mk8_relight2.py [rel|attack|both]   缺省 both
"""
import io
import json
import os
import subprocess
import sys
import types
import base64

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
os.makedirs(OUT, exist_ok=True)


def load(name, path):
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines()
             if not ln.strip().startswith("sys.stdout = io.TextIOWrapper")]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


ag = load("mk8_ag", os.path.join(ROOT, "tools", "img25_anchor_gen.py"))
agk = load("mk8_agk", os.path.join(ROOT, "tools", "img25_attack_gen.py"))
# 沿用 anchor2 的朝右 patch 与 cells 定义
a2 = load("mk8_a2", os.path.join(ROOT, "tools", "_mk8_anchor2.py"))

from PIL import Image  # noqa: E402

UNITS = ["fe_void_dimensional_soldier", "fe_iron_wall_juggernaut"]


def _data_uri(im):
    b = io.BytesIO()
    im.save(b, "PNG")
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


def color_standard(unit):
    """现役成品 idle f0 → 512 品红底（正确配色标准）。"""
    sh = Image.open(os.path.join(UA, unit, "sheet_idle.png")).convert("RGBA")
    f0 = sh.crop((0, 0, 256, 256)).resize((512, 512), Image.LANCZOS)
    bg = Image.new("RGB", (512, 512), (255, 0, 255))
    bg.paste(f0, (0, 0), f0)
    return bg


def relight(unit):
    raw_p = os.path.join(OUT, unit + "_anchor_raw.png")
    bak_p = os.path.join(OUT, unit + "_anchor_raw_dark.png")
    if not os.path.exists(bak_p):
        os.replace(raw_p, bak_p)          # 暗锚定留档（Image1 源）
    payload = {"model": "agnes-image-2.5-flash",
               "prompt": ag.relight_prompt(),
               "size": "1K", "ratio": "1:1",
               "extra_body": {"image": [_data_uri(Image.open(bak_p).convert("RGB")),
                                        _data_uri(color_standard(unit))],
                              "response_format": "b64_json"}}
    pp = os.path.join(OUT, "_relight_payload.json")
    with open(pp, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False)
    print("[relight:%s] 生成中…（Image1=暗锚定 Image2=现役 f0）" % unit, flush=True)
    raw = ag.gen_image(pp)
    if raw is None:
        print("[relight:%s] 3 掷皆废" % unit, flush=True)
        return False
    ok, info = ag.lit_gate(Image.open(io.BytesIO(raw)))
    print("[relight:%s] 亮度门: %s" % (unit, json.dumps(info, ensure_ascii=False)), flush=True)
    with open(raw_p, "wb") as f:
        f.write(raw)
    if not ok:
        print("[relight:%s] 仍暗 → 保留 raw 供目验/再回收" % unit, flush=True)
        return False
    return True


def rebuild(unit):
    """relit raw → keyed/fullbody → idle 重 build → attack 重掷 2 版。"""
    raw = Image.open(os.path.join(OUT, unit + "_anchor_raw.png")).convert("RGB")
    keyed = ag.chroma_key(raw)
    keyed = agk.depink(keyed)
    keyed = agk.keep_main_bodies(keyed, 0.35)
    ok, info = a2.fullbody_check(keyed)
    print("  [%s] 全身校验: ok=%s %s" % (unit, ok, info), flush=True)
    if not ok:
        print("  [%s] relit 后非全身，中止（暗锚定留档 _anchor_raw_dark.png）" % unit, flush=True)
        return False
    keyed.save(os.path.join(OUT, unit + "_anchor_keyed.png"))
    a2.build_idle(unit)
    subject, cells = a2.UNITS[unit]
    cj = os.path.join(OUT, "_mk8_cells_%s.json" % unit)
    with open(cj, "w", encoding="utf-8") as f:
        json.dump(dict(cells, extra=a2.EXTRA_RIGHT), f, ensure_ascii=False)
    rc = subprocess.call([sys.executable, os.path.join(ROOT, "tools", "img25_attack_gen.py"),
                          unit, "--subject", subject, "--rolls", "2", "--cells-json", cj],
                         cwd=ROOT)
    print("[%s] attack 重掷 rc=%d" % (unit, rc), flush=True)
    return rc == 0


def main():
    which = (sys.argv[1] if len(sys.argv) > 1 else "both").lower()
    for unit in UNITS:
        print("== %s ==" % unit, flush=True)
        if "rel" in which:
            if not relight(unit):
                continue
        if "attack" in which or "both" in which:
            rebuild(unit)
    print("MK8 relight 批结束", flush=True)


if __name__ == "__main__":
    main()
