#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""2026-09-02 改造图标错配修复轮。

视觉审查（86 图标全量拼贴 + AI 读图）结论分三类，本脚本处理前两类：
1. 重生成 9 张画面与用途错配/缺失的图标（agnes API，管线与 regen_all_mod_icons.py 一致）
2. 部署 docs/待生成改造图标_v26/ 的 12 张专属图标（同管线白转透明 512）
3. （数据层 icon 字段指派修正不在本脚本，见同日 CHANGELOG）

用法：python tools/fix_mod_icons_mismatch_2026-09-02.py            # 全部
      python tools/fix_mod_icons_mismatch_2026-09-02.py mod_ecm     # 单张重试
      python tools/fix_mod_icons_mismatch_2026-09-02.py --deploy-v26
"""
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "assets", "ui", "icons", "mod_icons")
V26 = os.path.join(ROOT, "docs", "待生成改造图标_v26")
RAW = os.path.join(D, "_fixregen_raw")
os.makedirs(RAW, exist_ok=True)

API_KEY = open(os.path.join(ROOT, "tools", "_api_key.txt"), encoding="utf-8").read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
BASE_URL_FALLBACK = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"

# 与 regen_all_mod_icons.py 完全同款前缀/负向（风格一致性）
P = "单个军事科技部件图标，扁平矢量插画，粗轮廓剪影，深色调主体配霓虹青蓝高光与少量橙色点缀，居中占画面60%，纯白背景，无文字无水印，"
N = "不要文字，不要边框，不要多对象，不要透视，不要照片写实，不要背景色块，背景必须是纯白色。"

# 9 张重生成：修正后的主体描述（旧主体错在哪见 CHANGELOG 2026-09-02）
SUBJECT = {
    # 旧图=热成像仪，实际用途=航空云爆温压弹（air_thermolite_bomb 温压弹）
    "mod_thermolite": "航空云爆温压炸弹弹体，粗短圆润弹身与双层燃料空气扩散环尾翼",
    # 旧图=装甲板+圆形舱口，实际用途=火炮温压弹（art_11_thermobaric，TOS-1）
    "mod_ammo_thermobaric": "火箭温压弹战斗部，火箭弹体与炽热橙红弹头核心",
    # 旧图=整支冲锋枪，实际用途=火炮膛线强化（art_01_rifling）
    "mod_barrel": "加长火炮身管特写，炮口朝上斜置，膛线刻纹与炮口制退器清晰",
    # 旧图=普通坦克，实际用途=坦克架桥车（eng_04_bridge）
    "mod_bridge": "坦克架桥车展开的剪刀式金属桥臂与桥板",
    # 旧图=整架直升机，实际用途=电子对抗吊舱（air_08_ecm）
    "mod_ecm": "机载电子对抗干扰吊舱，圆柱吊舱与散热格栅天线阵面",
    # 旧图=三发炮弹（与弹药箱撞语义），实际用途=烟幕/干扰弹发射器
    "mod_countermeasure": "烟幕干扰弹发射器阵列，多管发射巢与弹出的干扰弹体",
    # 旧图=传感器板，实际用途=假目标诱饵（rec_11_decoy 充气坦克）
    "mod_deception": "充气假坦克诱饵，半透明充气坦克轮廓与支撑骨架",
    # 旧图=罗盘+扳手（扳手是污染元素），实际用途=军用GPS（rec_07_gps）
    "mod_navigation": "军用GPS接收终端，加固手持机与屏幕卫星定位波束",
    # 文件缺失（gen_unified_splash 统一装药引用了不存在的图标）
    "mod_explosion": "标准化高爆装药，黄色装药块与弹丸装药段",
}

# 12 张 v26 专属图标：按 mod_id 命名部署（数据层 icon 字段同步接线）
V26_DEPLOY = [
    "air_17_bombsight", "air_18_heavy_rack", "air_19_cluster_dispenser",
    "air_20_standoff_missile", "air_21_terrain_radar", "air_22_countermeasure",
    "arm_17_spacer_armor", "arm_18_gun_mantlet", "aa_14_searchlight",
    "aa_15_flak_burst", "for_14_bomb_shelter", "gen_stealth_coating",
]


def generate(prompt, output_path):
    for base in (BASE_URL, BASE_URL_FALLBACK):
        payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
        tmp = output_path + ".payload.json"
        open(tmp, "w", encoding="utf-8").write(payload)
        cmd = ["curl", "--http1.1", "-s", "-X", "POST", base + "/images/generations",
               "-H", "Authorization: Bearer " + API_KEY, "-H", "Content-Type: application/json",
               "--data-binary", "@" + tmp, "-o", output_path + ".resp.json", "--max-time", "180"]
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=200)
        except subprocess.TimeoutExpired:
            continue
        finally:
            try:
                os.unlink(tmp)
            except OSError:
                pass
        if r.returncode != 0:
            continue
        try:
            content = open(output_path + ".resp.json", encoding="utf-8").read()
            data = json.loads(content)
            url = (data.get("data") or [{}])[0].get("url", "")
        except Exception:
            continue
        finally:
            try:
                os.unlink(output_path + ".resp.json")
            except OSError:
                pass
        if not url:
            continue
        # -k：产物 CDN platform-outputs.agnes-ai.space 证书链不被本机 Windows schannel
        # 信任（_netfix.py 同因），System32 curl.exe 必须跳过验证才能下载
        subprocess.run(["curl", "--http1.1", "-s", "-k", "-L", "-o", output_path, url, "--max-time", "180"],
                       capture_output=True, timeout=200)
        if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
            return True
    return False


def deploy(raw_path, out_path):
    from PIL import Image
    import numpy as np
    arr = np.array(Image.open(raw_path).convert("RGB"), dtype=np.int16)
    brightness = arr.sum(axis=2) / 3.0
    alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([arr[:, :, 0].astype(np.uint8), arr[:, :, 1].astype(np.uint8),
                                     arr[:, :, 2].astype(np.uint8), alpha]), "RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    scale = min(512 / w, 512 / h) * 0.84
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.paste(img, ((512 - nw) // 2, (512 - nh) // 2), img)
    canvas.save(out_path)


def main():
    only = None
    deploy_v26_only = "--deploy-v26" in sys.argv
    for a in sys.argv[1:]:
        if not a.startswith("--"):
            only = a
    ok = fail = 0
    failed = []

    if not deploy_v26_only:
        for f in sorted(SUBJECT):
            if only and f != only:
                continue
            out = os.path.join(D, f + ".png")
            # 已有当日产物则跳过 API（单张重试时用 --force 重跑）
            if os.path.exists(out) and "--force" not in sys.argv and f != "mod_explosion":
                # mod_explosion 从缺失态生成；其余默认覆盖（本次即修复轮）
                pass
            raw = os.path.join(RAW, f + ".png")
            print(f"[gen] {f} ...", flush=True)
            good = False
            for attempt in range(3):
                if generate(P + SUBJECT[f] + N, raw):
                    good = True
                    break
                print(f"  retry {attempt + 1}/3", flush=True)
                time.sleep(3)
            if not good:
                print("  GEN FAIL:", f, flush=True)
                fail += 1
                failed.append(f)
                continue
            try:
                deploy(raw, out)
                print("  deployed", flush=True)
                ok += 1
            except Exception as e:
                print("  DEPLOY FAIL:", f, e, flush=True)
                fail += 1
                failed.append(f)

    for name in V26_DEPLOY:
        if only and only != name:
            continue
        src = os.path.join(V26, name + ".png")
        out = os.path.join(D, name + ".png")
        if not os.path.exists(src):
            print("[v26] missing source:", name, flush=True)
            fail += 1
            failed.append(name)
            continue
        if os.path.exists(out) and "--force" not in sys.argv:
            print(f"[v26] {name} already deployed, skip", flush=True)
            continue
        try:
            deploy(src, out)
            print(f"[v26] deployed {name}", flush=True)
            ok += 1
        except Exception as e:
            print(f"[v26] DEPLOY FAIL {name}: {e}", flush=True)
            fail += 1
            failed.append(name)

    print(f"\nDone: {ok} ok, {fail} fail")
    if failed:
        print("FAILED:", " ".join(failed))


if __name__ == "__main__":
    main()
