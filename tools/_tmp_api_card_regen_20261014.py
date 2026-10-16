# -*- coding: utf-8 -*-
"""卡图 API 重生成批（2026-10-14）：网页点名的 10 单位，t2i 语义重出（不锁现役结构）。

用户口径：有些现役卡图正是对结构不满意才重出 → 走 t2i（不用现役图做 i2i 参考），
风格一致性靠冻结骨架 + 单变量 {SUBJECT}（docs/API精灵图生成工作流_v1.md §2/§3 支柱2/3）。
底色=品红 #FF00FF（本批军绿主体多，品红零撞色；键控对齐 tools/flow_sprite_pipeline/
magenta_cut_key_ref.py 现役口径：r>140 & b>140 & g<0.75*min(r,b)-10 + 二次键控 +
紫边去饱和 + 2px 邻域去色 + 1px 羽化）。

产物只落暂存目录（过目检才部署，部署铁律见工作流 §5）：
  docs/卡图API重生成_20261014/
    raw/<编号>_<id>.png   1024 品红底原图
    cut/<编号>_<id>.png   键控后 512 透明底（bbox 居中留 ~8% 边距）
    ledger.json           台账：prompt/URL/耗时/md5
    review.html           审查页（tools/_tmp_build_card_regen_page.py 生成）

用法：python tools/_tmp_api_card_regen_20261014.py gen|cut|all
"""
import base64
import hashlib
import io
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "卡图API重生成_20261014")
RAW = os.path.join(OUT, "raw")
CUT = os.path.join(OUT, "cut")
LEDGER = os.path.join(OUT, "ledger.json")

IMG = "https://apihub.agnes-ai.com/v1/images/generations"
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

# ── 冻结骨架（工作流 §3 模板；KEY_COLOR=品红，本批军绿/蓝色系主体零撞色）──
SKELETON = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, flat orthographic game sprite, single subject only centered, "
    "{SUBJECT} "
    "matte painting style, detailed weathering and surface texture, "
    "complex dramatic lighting with rim light from top-left, "
    "solid flat magenta #FF00FF background ONLY, the background is one perfectly uniform "
    "flat color with no gradients and no lighting falloff, "
    "centered composition, full body fitting in frame with generous empty margin, "
    "NO text, NO watermark, NO ground, NO shadow, NO scene background"
)

# ── 批次清单：编号=审查网页「NNN·」编号；icon_e=网页数据给出的现役图实际路径 ──
UNITS = [
    dict(no="011", uid="ww2_arty_m81", name="81mm迫击炮", era="二战",
         icon="assets/card_icons/enemy/vis_enemy_011.png",
         subject="fully colored military illustration in rich olive-green and rust-brown palette with visible brushed-metal texture and paint chipping: an unmanned World War II automatic 81mm mortar facing left, the muzzle angled up toward the left edge of the image, on a stabilized base with ammunition drum and mechanical auto-loader arm"),
    dict(no="012", uid="ww1_arty_m81", name="81mm迫击炮组", era="一战",
         icon="assets/card_icons/enemy/vis_enemy_012.png",
         subject="fully colored military illustration in multi-tone field-grey and weathered brass palette with rivets and gear details clearly painted: an unmanned World War I automatic trench mortar facing left, the muzzle angled up toward the left edge of the image, chain-fed ammunition belt and brass gear auto-loader on a riveted steel mount"),
    dict(no="017", uid="cold_sup_zsu23", name="ZSU-23-4自行高炮", era="冷战",
         icon="assets/card_icons/enemy/vis_enemy_017.png",
         subject="a Soviet ZSU-23-4 Shilka self-propelled anti-aircraft gun: quad 23mm autocannon barrels clustered and pointing up-left atop a boxy turret with a raised dish radar, tracked chassis with five road wheels, dark olive green with worn edges"),
    dict(no="019", uid="mod_arm_m1a1", name="M1A1主战坦克", era="现代",
         icon="assets/card_icons/enemy/vis_enemy_019.png",
         subject="fully colored military illustration in NATO green with dusty desert-tan streaks, worn track metal and painted hull panels: an M1A1 Abrams main battle tank facing left, the long 120mm gun barrel pointing straight toward the left edge of the image, low angular turret, side skirts and seven-spoke road wheels"),
    dict(no="026", uid="fut_arm_prism", name="光棱坦克", era="未来",
         icon="assets/card_icons/enemy/vis_enemy_026.png",
         subject="a futuristic prism tank: sleek low-hover chassis in white ceramic composite armor, a tall crystalline focusing prism tower on the turret splitting into refractor nodes, glowing cyan-blue energy conduits along the hull"),
    dict(no="030", uid="fut_arm_titan_mk2", name="泰坦Mk.II", era="未来",
         icon="assets/card_icons/enemy/vis_enemy_031.png",
         subject="the Titan Mk.II, a colossal armored war-walker platform on four heavy articulated legs, a bristling central hull mounting twin long-barreled rail cannons pointing left, layered gunmetal blue-grey plates with amber warning stripes"),
    dict(no="032", uid="fut_air_heavy_carrier", name="重装母舰", era="未来",
         icon="assets/card_icons/enemy/vis_enemy_033.png",
         subject="fully colored military illustration in dark blue-grey armor panels with glowing cyan trim lights, engine exhaust glow and deck markings: a massive futuristic heavy airborne carrier facing left in full side view, broad flying-wing hull with rows of engine pods and an open launch bay deck lined with small drones"),
    dict(no="037", uid="ww1_sup_mg_nest", name="机枪巢", era="一战",
         icon="assets/card_icons/enemy/vis_enemy_038.png",
         subject="fully colored military illustration in sun-bleached sandbag tan and olive-green metal, burlap weave texture, rivets and brass gears clearly painted: an unmanned automatic machine gun nest facing left, an auto-firing heavy machine gun on a mechanical stabilized mount with a belt-fed ammunition box and a clockwork auto-traverse mechanism, its water-cooled barrel pointing toward the left edge of the image, set inside a curved wall of stacked weathered sandbags"),
    dict(no="038", uid="ww1_arty_mortar", name="迫击炮组", era="一战",
         icon="assets/card_icons/enemy/vis_enemy_039.png",
         subject="fully colored military illustration in blued-steel and mud-brown palette with scratches and rust streaks clearly painted: an unmanned compact light automatic trench mortar facing left, the muzzle angled up toward the left edge of the image, drum-magazine auto-feeder on a tripod base"),
    dict(no="039", uid="ww1_inf_storm_e", name="暴风突击队", era="架空",
         icon="assets/card_icons/enemy/vis_enemy_040.png",
         subject="fully colored military illustration in muted grey-green combat fatigues with dark tactical gear, cloth folds and metal sheen clearly painted: a single elite assault trooper facing left, striding forward toward the left edge of the frame with his service rifle raised and carried at the ready, the muzzle pointing ahead-left, wearing a smooth rounded combat helmet and a chest rig with pouches"),
]

KEYS = [l.strip() for l in open(os.path.join(ROOT, "tools", "_api_key.txt"),
                                encoding="utf-8").read().splitlines() if l.strip()]


def _post(key, body, timeout=300):
    req = urllib.request.Request(IMG, data=json.dumps(body).encode(),
                                 headers={"Authorization": "Bearer " + key,
                                          "Content-Type": "application/json"})
    r = urllib.request.urlopen(req, timeout=timeout, context=CTX)
    return json.loads(r.read().decode())


def gen_one(u, key_idx, tries=4):
    """单张 t2i：429/网络错退避换 key 重试；台账记录 prompt/URL/耗时。"""
    prompt = SKELETON.replace("{SUBJECT}", u["subject"])
    body = {"model": "agnes-image-2.1-flash", "prompt": prompt,
            "image_size": "1024x1024"}
    t0 = time.time()
    last = None
    for a in range(tries):
        try:
            d = _post(KEYS[key_idx % len(KEYS)], body)
            url = (d.get("data") or [{}])[0].get("url", "")
            if not url:
                raise RuntimeError("no url in response: %s" % json.dumps(d)[:200])
            req = urllib.request.Request(url)
            png = urllib.request.urlopen(req, timeout=120, context=CTX).read()
            path = os.path.join(RAW, "%s·%s.png" % (u["no"], u["name"]))
            open(path, "wb").write(png)
            rec = dict(no=u["no"], uid=u["uid"], name=u["name"], era=u["era"],
                       prompt=prompt, url=url, secs=round(time.time() - t0, 1),
                       md5=hashlib.md5(png).hexdigest(),
                       raw=os.path.relpath(path, ROOT).replace("\\", "/"),
                       cut=None, key=key_idx % len(KEYS), attempt=a + 1)
            print("  OK %s %s %.0fs (key%d try%d) %dKB" % (
                u["no"], u["uid"], rec["secs"], rec["key"], a + 1, len(png) // 1024))
            return rec
        except urllib.error.HTTPError as e:
            last = "HTTP %d %s" % (e.code, e.read().decode()[:160])
        except Exception as e:
            last = repr(e)
        print("  retry %s %s (attempt %d): %s" % (u["no"], u["uid"], a + 1, last))
        key_idx += 1  # 429/网络错 → 换下一把 key
        time.sleep(6 if "429" in str(last) else 3)
    return dict(no=u["no"], uid=u["uid"], name=u["name"], era=u["era"],
                prompt=prompt, error=str(last), raw=None, cut=None)


def gen_all(nos=None):
    units = [u for u in UNITS if nos is None or u["no"] in nos]
    os.makedirs(RAW, exist_ok=True)
    ledger = []
    # 键数不足3也安全：分片器永不指向 units 本体（2026-10-14 批2 实踩：2 键时
    # shards=[units] → 迭代中自我 append → MemoryError 死循环）
    n = max(1, min(len(KEYS), 3))
    from threading import Thread
    shards = [[] for _ in range(n)]
    for i, u in enumerate(units):
        shards[i % n].append(u)
    lock_results = []

    def run_shard(shard, kidx):
        for u in shard:
            rec = gen_one(u, kidx)
            with open(os.path.join(OUT, "_lock"), "a") as lf:
                pass
            lock_results.append(rec)
            time.sleep(3)  # 批间隔

    threads = [Thread(target=run_shard, args=(s, i)) for i, s in enumerate(shards)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    lock_results.sort(key=lambda r: r["no"])
    json.dump(lock_results, open(LEDGER, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    ok = [r for r in lock_results if r.get("raw")]
    print("gen done: %d/%d ok -> %s" % (len(ok), len(lock_results), RAW))


def rebuild_ledger():
    """不调 API 重建台账：raw 文件已在盘上时（如 v1 汇总 bug 后）按 UNITS + 文件重扫。"""
    ledger = []
    for u in UNITS:
        path = os.path.join(RAW, "%s·%s.png" % (u["no"], u["name"]))
        rec = dict(no=u["no"], uid=u["uid"], name=u["name"], era=u["era"],
                   prompt=SKELETON.replace("{SUBJECT}", u["subject"]),
                   url=None, secs=None, cut=None, rebuilt=True)
        if os.path.exists(path):
            rec["md5"] = hashlib.md5(open(path, "rb").read()).hexdigest()
            rec["raw"] = os.path.relpath(path, ROOT).replace("\\", "/")
        else:
            rec["raw"] = None
        ledger.append(rec)
    json.dump(ledger, open(LEDGER, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("rebuild: %d/%d raw on disk -> %s" % (
        len([r for r in ledger if r["raw"]]), len(ledger), LEDGER))


# ── 品红键控（口径基线=magenta_cut_key_ref.py；判据按本批实测底色带放宽──
# 模型出品红底实测为深玫红 R176-188/G14-44/B108-132（B<140 原判据咬不住→011/019/039 残留）。
# 主体色核对：军绿/沙色 G≥R、蓝灰 B 高 G 高、琥珀条 B 低——g<0.6r ∧ b>95 与主体零交集。──
def _is_key(r, g, b):
    return (r > 150) & (b > 95) & (g < 0.6 * r)


def key_magenta(im):
    cell = np.asarray(im.convert("RGB")).astype(int)
    r, g, b = cell[:, :, 0], cell[:, :, 1], cell[:, :, 2]
    mag = _is_key(r, g, b)
    alpha = np.where(mag, 0, 255).astype(np.uint8)

    violet = (~mag) & (r > 120) & (b > 120) & (g < 0.8 * np.minimum(r, b))
    despill = cell.copy()
    new_rb = ((r + b) // 2)
    for ch in (0, 2):
        despill[:, :, ch] = np.where(violet, (new_rb * 0.5 + despill[:, :, ch] * 0.5),
                                     despill[:, :, ch])

    r2, g2, b2 = (despill[:, :, 0].astype(int), despill[:, :, 1].astype(int),
                  despill[:, :, 2].astype(int))
    mag2 = _is_key(r2, g2, b2)
    alpha[mag2] = 0

    dil = mag2.copy()
    for _ in range(2):
        dil = dil | np.roll(dil, 1, 0) | np.roll(dil, -1, 0) \
                  | np.roll(dil, 1, 1) | np.roll(dil, -1, 1)
    purple = dil & (~mag2) & (r2 > g2 + 18) & (b2 > g2 + 8) & (alpha > 0)
    if purple.any():
        gray = ((r2 + g2 * 2 + b2) // 4).astype(np.uint8)
        for ch in range(3):
            despill[:, :, ch] = np.where(purple, gray, despill[:, :, ch])

    opaque = alpha == 255
    neigh = np.zeros_like(opaque)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        neigh |= ~np.roll(np.roll(opaque, dy, 0), dx, 1)
    alpha[opaque & neigh] = 140
    return np.dstack([despill.astype(np.uint8), alpha])


def cut_all(margin_frac=0.08, canvas=512):
    """键控 → alpha 并集 bbox → 等比缩放置 512 画布居中（~8% 边距，对齐卡图惯例）。"""
    os.makedirs(CUT, exist_ok=True)
    ledger = json.load(open(LEDGER, encoding="utf-8"))
    for rec in ledger:
        rawp = rec.get("raw")
        if not rawp:
            continue
        arr = key_magenta(Image.open(os.path.join(ROOT, rawp)))
        a = arr[:, :, 3]
        ys, xs = np.nonzero(a > 0)
        if len(xs) == 0:
            rec["cut_note"] = "EMPTY_AFTER_KEY"
            continue
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        x0, y0 = max(0, x0 - 2), max(0, y0 - 2)
        crop = arr[y0:y1 + 2, x0:x1 + 2]
        im = Image.fromarray(crop, "RGBA")
        side = int(canvas * (1.0 - margin_frac * 2))
        im.thumbnail((side, side), Image.LANCZOS)
        out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        out.paste(im, ((canvas - im.width) // 2, (canvas - im.height) // 2), im)
        path = os.path.join(CUT, "%s·%s.png" % (rec["no"], rec["name"]))
        out.save(path)
        rec["cut"] = os.path.relpath(path, ROOT).replace("\\", "/")
        rec["content_frac"] = round(im.width / canvas, 3)
        print("  cut %s %s content=%.2f" % (rec["no"], rec["uid"], rec["content_frac"]))
    json.dump(ledger, open(LEDGER, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("cut done -> %s" % CUT)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    os.makedirs(OUT, exist_ok=True)
    if mode == "rebuild":
        rebuild_ledger()
    elif mode == "gen":
        gen_all(set(sys.argv[2].split(",")) if len(sys.argv) > 2 else None)
        rebuild_ledger()  # 子集跑完按盘上文件重建全量台账（已删剪影的记缺失）
    if mode in ("cut", "all"):
        cut_all()
