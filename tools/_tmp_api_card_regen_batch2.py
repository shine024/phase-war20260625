# -*- coding: utf-8 -*-
"""卡图 API 重生成 批2（2026-10-14）：用户点名 26 编号（041~149），t2i 语义生成。

口径与批1一致（docs/API精灵图生成工作流_v1.md）：冻结骨架 + 单变量 {SUBJECT}，
品红底 #FF00FF，朝左（敌方约定），色彩锚前置防剪影，键控对齐 magenta_cut_key_ref。
模型 = agnes-image-2.5-flash（用户拍板 2026-10-14）。
146/149（split 分家单位）无现役卡图，纯语义从零生成。

产物：docs/卡图API重生成_20261014/{raw,cut}/编号·名称.png + ledger_batch2.json
用法：python tools/_tmp_api_card_regen_batch2.py gen|cut|all
"""
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from threading import Thread

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _tmp_api_card_regen_20261014 import KEYS, SKELETON, key_magenta  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "卡图API重生成_20261014")
RAW = os.path.join(OUT, "raw")
CUT = os.path.join(OUT, "cut")
LEDGER = os.path.join(OUT, "ledger_batch2.json")
IMG = "https://api.agnes-ai.cn/v1/images/generations"
MODEL = "agnes-image-2.5-flash"
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
BLOCKED = []  # 403 风控熔断旗（线程内置位，gen_all 主线程检查后退出码 3）

UNITS2 = [
    dict(no="041", uid="ww1_boss_av7", name="圣沙蒙坦克",         subject="fully colored military illustration in riveted grey-blue steel with mud-splattered tracks and rust streaks: a World War I French Saint-Chamond heavy tank facing left, one long overhanging hull with a sloped front glacis, a short 75mm gun in the front plate pointing left, a small top cupola, exposed coil springs and tracks"),
    dict(no="053", uid="cold_inf_spetsnaz_e", name="特种部队",
         subject="fully colored military illustration in dark digital-camo fatigues with black tactical webbing, cloth folds and gear straps clearly painted: a modern special forces operator aiming an AK-105 carbine with both hands, the muzzle level and pointing toward the left edge"),
    dict(no="056", uid="mod_inf_marine", name="海军陆战队",
         subject="fully colored military illustration in woodland MARPAT digital camo with tan tactical gear, cloth folds and pouch details clearly painted: a modern marine in a combat helmet holding an M16A4 rifle at the ready, the muzzle level and pointing toward the left edge"),
    dict(no="057", uid="mod_air_technical_e", name="皮卡武装",
         subject="fully colored military illustration in olive-green truck paint with dusty tan weathering and worn bed rails: an armed technical pickup truck facing left, one heavy machine gun ring-mounted in the open cargo bed pointing left, spare tyres standing in the bed"),
    dict(no="059", uid="mod_arty_mlrs_e", name="火箭炮车",
         subject="fully colored military illustration in olive-green and gunmetal with worn paint edges: a tracked self-propelled multiple rocket launcher facing left, one raised pod cluster of rocket tubes on the rear bed angled up-left, boxy armored cab at the front"),
    dict(no="060", uid="mod_inf_delta_e", name="三角洲部队",
         subject="fully colored military illustration in tan combat gear with black balaclava and pouches, cloth folds and strap buckles clearly painted: a Delta Force operator aiming an M4 carbine fitted with an optic, the muzzle level and pointing toward the left edge"),
    dict(no="064", uid="fut_air_drone", name="无人机群",
         subject="fully colored military illustration in dark-grey composite with glowing cyan sensor strips: a swarm of four small futuristic combat drones flying in a loose staggered formation heading left, sleek delta stealth shapes with glowing cyan sensor eyes, each drone complete"),
    dict(no="066", uid="fut_arm_mech_e", name="机甲步兵",
         subject="fully colored military illustration in pale blue-white armor plates with dark servo joints and cyan accent lights: a future mech infantry trooper inside a light powered exoskeleton standing braced facing left, the bullpup rifle raised and shouldered, aiming toward the left edge, about to fire, exposed hydraulic pistons on the limbs"),
    dict(no="068", uid="fut_inf_spectre_e", name="幽灵特工",
         subject="fully colored military illustration in dark teal nano-weave suit with glowing seam lines and a half-face visor: a futuristic stealth operative holding a compact energy submachine gun level and pointing toward the left edge, cloak edges shimmering faintly"),
    dict(no="069", uid="fut_arm_colossus_e", name="巨神机甲",
         subject="fully colored military illustration in heavy pale-green slab armor with dark gunmetal joints and a glowing cyan power core embedded in the chest: a colossal bipedal siege war mech facing left with exactly ONE weapon, its right arm ending in a single massive rotary gatling cannon pointed left, the left arm a simple armored manipulator fist with no weapon, no shoulder cannon, thick armored greaves and layered slab pauldrons, exposed hydraulic pistons at the knees"),
    dict(no="070", uid="fut_boss_nexus", name="风暴核心",
         subject="fully colored military illustration in obsidian-black and gunmetal with blue-white energy veins, a BOSS-scale tracked mobile fortress filling the frame: a very wide super-heavy multi-track chassis along the bottom like a rolling land fortress with layered angled armor plates and small gun turrets, and on top of the chassis ONE ENORMOUS faceted storm crystal towering high, the giant crystal is the dominant part of the machine at twice the height of the fortress body, blazing with lightning arcs, blue-white energy conduits running from the crystal down into the hull, amber trim lines"),
    dict(no="149", uid="ww2_mg42", name="MG42机枪组",
         subject="fully colored military illustration in blued gun steel and dark olive-green metal with brass ammunition, rivets and worn paint clearly painted: an unmanned automatic machine gun emplacement facing left, one belt-fed general-purpose machine gun with a long ventilated barrel sleeve on a reinforced tripod, a clockwork auto-traverse mechanism and a large ammunition drum box beside it, its barrel pointing toward the left edge, absolutely no people"),
    dict(no="073", uid="ww1_sup_vickers", name="维克斯 .303 机枪阵地",
         subject="fully colored military illustration in sun-bleached sandbag tan and olive-green gun metal, burlap weave and blued steel clearly painted: a World War I Vickers machine gun emplacement facing left, one water-cooled Vickers gun on a tripod behind a low curved sandbag screen, its barrel pointing toward the left edge, ammunition boxes beside"),
    dict(no="074", uid="ww1_sup_ford_ambulance", name="福特 T 型战地救护车",
         subject="fully colored military illustration in olive-drab truck paint with white red-cross markings and canvas texture: a World War I Ford Model T field ambulance facing left, canvas-topped light truck with a thin radiator grille at the front, spoked wheels"),
    dict(no="075", uid="ww1_inf_mp18_x", name="MP18 突击队",
         subject="fully colored military illustration in field-grey uniform cloth with brown leather gear, cloth folds and steel helmet sheen clearly painted: a World War I German stormtrooper standing braced facing left, the MP18 submachine gun raised and shouldered, aiming toward the left edge, about to fire, stahlhelm helmet, gas mask canister on the belt"),
    dict(no="078", uid="ww2_arty_pak40", name="PaK 40 反坦克炮组",
         subject="fully colored military illustration in dark-yellow dunkelgelb paint with worn edges and rivets: a World War II German PaK 40 anti-tank gun facing left, one long-barreled gun on a two-wheel split-trail carriage, the barrel pointing toward the left edge, gun shield plate and trail legs spread"),
    dict(no="086", uid="mod_sup_m4_carbine", name="M4 卡宾特遣班",
         subject="fully colored military illustration in tan multicam gear with a fast helmet and knee pads, cloth folds and pouch buckles clearly painted: a modern task-force rifleman aiming an M4 carbine fitted with an optic and foregrip, the muzzle level and pointing toward the left edge"),
    dict(no="087", uid="mod_inf_patriot", name="爱国者 PAC-3 发射车",
         subject="fully colored military illustration in tan missile-tube paint with black stencil marks and trailer frame steel: a Patriot PAC-3 surface-to-air launcher facing left, one rectangular trailer-mounted launcher with four missile tubes angled up-left, a support mast folded at the rear"),
    dict(no="093", uid="fut_arty_hel30", name="HEL-30 激光炮阵列",
         subject="fully colored military illustration in dark gunmetal with amber warning stripes and a glowing blue lens core: a futuristic HEL-30 laser cannon array facing left, one large multi-lens emitter cannon on an autonomous tracked carriage, the emitter pointing toward the left edge, cooling fins along the barrel"),
    dict(no="094", uid="fut_sup_nrepair", name="N-Repair 纳米工程车",
         subject="fully colored military illustration in blue-grey truck armor with glowing cyan nano-fluid lines: a futuristic nano-repair engineering vehicle facing left, one six-wheel chassis with a multi-joint robotic service arm folded at the rear and one glowing translucent nano-fluid tank"),
    dict(no="095", uid="fut_inf_x9", name="X-9 猎杀者渗透组",
         subject="fully colored military illustration in matte-black stealth exosuit plating with violet seam glows and a full-face visor: a futuristic X-9 infiltration hunter standing braced facing left, the compact rail carbine raised and shouldered, aiming toward the left edge, about to fire, armored cloak panels over the shoulders"),
    dict(no="110", uid="ww1_fort_pillbox", name="混凝土机枪碉堡",
         subject="fully colored military illustration in weathered grey concrete with rain stains and moss patches: a low hexagonal machine-gun pillbox bunker, one dark embrasure slit facing the left edge, sandbags piled at the base, a dented shallow dome roof"),
    dict(no="113", uid="ww2_fort_flak", name="88mm防空塔",
         subject="fully colored military illustration in dark-grey flak steel with red-white turret rings and worn paint: a World War II 88mm anti-aircraft gun emplacement, one long-barreled 88 on a cross-shaped platform mount, the barrel elevated toward the upper left, splinter shield around the breech"),
    dict(no="116", uid="mod_fort_citadel", name="要塞核心",
         subject="fully colored military illustration in gunmetal bastion plates with glowing cyan energy seams: a futuristic fortress core, one squat armored dome with layered angled armor plates and one glowing hexagonal energy gate on the front face pointing left, sensor masts on top"),
    dict(no="128", uid="xeno_tripod", name="三足行者",
         subject="fully colored military illustration in green-black alien carapace with bioluminescent green glow veins: an alien war tripod facing left, three tall articulated insect legs, one bulbous hood-shaped body with hanging tentacle cables and a single glowing heat-ray emitter eye pointing toward the left edge"),
    dict(no="146", uid="ww1_saint", name="圣沙蒙坦克",
         subject="fully colored military illustration in riveted grey steel with mud-caked tracks and paint chipping: a World War I French Saint-Chamond tank facing left, one long overhanging hull with a sloped front glacis, a 75mm gun in the front plate pointing left, exposed suspension and a low driver cupola"),
]


def _post(key, body, timeout=300):
    req = urllib.request.Request(IMG, data=json.dumps(body).encode(),
                                 headers={"Authorization": "Bearer " + key,
                                          "Content-Type": "application/json"})
    r = urllib.request.urlopen(req, timeout=timeout, context=CTX)
    return json.loads(r.read().decode())


def gen_one(u, key_idx, tries=12):
    prompt = SKELETON.replace("{SUBJECT}", u["subject"])
    body = {"model": MODEL, "prompt": prompt, "image_size": "1024x1024"}
    t0 = time.time()
    last = None
    for a in range(tries):
        try:
            d = _post(KEYS[key_idx % len(KEYS)], body)
            url = (d.get("data") or [{}])[0].get("url", "")
            if not url:
                raise RuntimeError("no url: %s" % json.dumps(d)[:160])
            png = urllib.request.urlopen(
                urllib.request.Request(url), timeout=120, context=CTX).read()
            path = os.path.join(RAW, "%s·%s.png" % (u["no"], u["name"]))
            open(path, "wb").write(png)
            print("  OK %s %s %.0fs (key%d try%d)" % (
                u["no"], u["name"], time.time() - t0, key_idx % len(KEYS), a + 1),
                flush=True)
            return dict(no=u["no"], uid=u["uid"], name=u["name"],
                        prompt=prompt, url=url,
                        secs=round(time.time() - t0, 1),
                        raw=os.path.relpath(path, ROOT).replace("\\", "/"),
                        cut=None, key=key_idx % len(KEYS), attempt=a + 1)
        except urllib.error.HTTPError as e:
            last = "HTTP %d %s" % (e.code, e.read().decode()[:120])
            print("  retry %s: %s" % (u["no"], last), flush=True)
            if e.code == 403:  # 账号风控：置位熔断旗（线程内 SystemExit 传不出去）
                BLOCKED.append(True)
                return dict(no=u["no"], uid=u["uid"], name=u["name"],
                            prompt=prompt, error="BLOCKED403", raw=None, cut=None)
            if e.code == 503:
                time.sleep(30 + a * 8)
                continue
        except Exception as e:
            last = repr(e)
            print("  retry %s: %r" % (u["no"], e), flush=True)
        key_idx += 1
        time.sleep(6)
    return dict(no=u["no"], uid=u["uid"], name=u["name"], prompt=prompt,
                error=str(last), raw=None, cut=None)


def gen_all(nos=None):
    units = [u for u in UNITS2 if nos is None or u["no"] in nos]
    os.makedirs(RAW, exist_ok=True)
    n = max(1, min(len(KEYS), 3))  # 键数不足3也安全：分片器永不指向 units 本体
    shards = [[] for _ in range(n)]
    for i, u in enumerate(units):
        shards[i % n].append(u)
    results = []

    def run_shard(shard, kidx):
        for u in shard:
            results.append(gen_one(u, kidx))
            time.sleep(3)

    threads = [Thread(target=run_shard, args=(s, i)) for i, s in enumerate(shards)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    if BLOCKED:
        print("=== API BLOCKED (403) ===", flush=True)
        sys.exit(3)
    results.sort(key=lambda r: r["no"])
    json.dump(results, open(LEDGER, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("gen done: %d/%d ok" % (
        len([r for r in results if r.get("raw")]), len(results)), flush=True)


def cut_all(margin_frac=0.08, canvas=512):
    os.makedirs(CUT, exist_ok=True)
    ledger = json.load(open(LEDGER, encoding="utf-8"))
    import numpy as np

    def key_adaptive(im):
        arr = key_magenta(im)
        if (arr[:, :, 3] > 0).mean() >= 0.05:
            return arr
        a = np.asarray(im.convert("RGB")).astype(int)  # 暗品红底回退：角点色距键控
        cc = np.vstack([a[:40, :40].reshape(-1, 3), a[:40, -40:].reshape(-1, 3),
                        a[-40:, :40].reshape(-1, 3), a[-40:, -40:].reshape(-1, 3)])
        bg = np.median(cc, 0)
        dist = np.sqrt(((a - bg) ** 2).sum(2))
        alpha = np.where(dist < 70, 0, 255).astype(np.uint8)
        return np.dstack([a.astype(np.uint8), alpha])

    for rec in ledger:
        if not rec.get("raw"):
            continue
        arr = key_adaptive(Image.open(os.path.join(ROOT, rec["raw"])))
        a = arr[:, :, 3]
        ys, xs = np.nonzero(a > 0)
        if len(xs) == 0:
            rec["cut_note"] = "EMPTY_AFTER_KEY"
            continue
        x0, x1, y0, y1 = max(0, xs.min() - 2), xs.max() + 3, max(0, ys.min() - 2), ys.max() + 3
        im = Image.fromarray(arr[y0:y1, x0:x1], "RGBA")
        side = int(canvas * (1.0 - margin_frac * 2))
        im.thumbnail((side, side), Image.LANCZOS)
        outim = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        outim.paste(im, ((canvas - im.width) // 2, (canvas - im.height) // 2), im)
        path = os.path.join(CUT, "%s·%s.png" % (rec["no"], rec["name"]))
        outim.save(path)
        rec["cut"] = os.path.relpath(path, ROOT).replace("\\", "/")
        rec["content_frac"] = round(im.width / canvas, 3)
        print("  cut %s %s content=%.2f" % (rec["no"], rec["name"], rec["content_frac"]),
              flush=True)
    json.dump(ledger, open(LEDGER, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


def rebuild_ledger():
    """按 UNITS2 + 盘上文件重建全量台账（子集补跑后调用，防台账被子集覆盖丢失）。"""
    ledger = []
    for u in UNITS2:
        raw = os.path.join(RAW, "%s·%s.png" % (u["no"], u["name"]))
        cut = os.path.join(CUT, "%s·%s.png" % (u["no"], u["name"]))
        rec = dict(no=u["no"], uid=u["uid"], name=u["name"], rebuilt=True,
                   prompt=SKELETON.replace("{SUBJECT}", u["subject"]),
                   raw=os.path.relpath(raw, ROOT).replace("\\", "/") if os.path.exists(raw) else None,
                   cut=os.path.relpath(cut, ROOT).replace("\\", "/") if os.path.exists(cut) else None)
        ledger.append(rec)
    json.dump(ledger, open(LEDGER, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("rebuild: %d/%d raw on disk" % (
        len([r for r in ledger if r["raw"]]), len(ledger)), flush=True)


from PIL import Image  # noqa: E402  (cut_all 用)

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode == "gen":
        gen_all(set(sys.argv[2].split(",")) if len(sys.argv) > 2 else None)
        rebuild_ledger()
    elif mode == "cut":
        cut_all()
    elif mode == "rebuild":
        rebuild_ledger()
    else:
        gen_all()
        cut_all()
