# -*- coding: utf-8 -*-
"""generate_bunker_caps_upg.py —— 基地房间"时代升级态"胶囊批量生成（agnes-image-2.1-flash）

对 15 个房间，以《这是我的战争》手绘风 + 正交侧视为基准，生成"高科技升级版"内景：
构图语义与现有胶囊对应（同一房间、同一视角），观感从一战废土升级为跨时代改造。
输出：docs/基地重设计/generated5/cap_<rid>_upg.jpeg（白底，烘焙脚本自动抠图优先采用）

用法：
  python tools/generate_bunker_caps_upg.py                # 全部 15 张
  python tools/generate_bunker_caps_upg.py war_room depot # 指定房间
  python tools/generate_bunker_caps_upg.py --list         # 只列房间
"""
import json, os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
OUT_DIR = os.path.join(ROOT, "docs", "基地重设计", "generated5")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"
SIZE = "1152x768"   # ≈3:2，接近胶囊原生比例；烘焙 aspect-fill 兜底裁切

# 升级版前缀 v3：地面用"光滑金属地板"的正面意象锁死（v26.2 用户反馈：负面词垃圾列表
# 无效且反激活——轻量模型对 Avoid 词敏感度差，提 trash 概念反而画 trash）。
# 色板词 "dusty olive" 也改为 "olive green"，杜绝尘土暗示。
P_ROOM_UPG = (
    "2D game asset, hand-painted stylized game art, "
    "muted palette of dark grey-brown and olive green with cold cyan glow accents, "
    "strictly side view, flat orthographic room interior vignette, "
    "furniture group arranged on a single floor line at the bottom edge, "
    "the floor is one smooth continuous surface of polished metal planks, "
    "completely empty and spotless from wall to wall, minimal wall decorations "
    "(plain shelves and tool boards only), "
    "NO ceiling, NO side walls, NO room border, pure solid white background, "
    "no text, no watermark, crisp edges, high detail density. "
)
P_UPG = (
    "UPGRADED far-future refit of this room: the old scrap equipment is replaced by sleek "
    "retro-future tech of a far-future era, cold cyan-white (#00e5ff) glow accents instead "
    "of warm bulbs, control surfaces and screens showing ONLY simple abstract glowing "
    "patterns, plain color readouts and flat graphic symbols (never detailed pictures or "
    "scenes), the interior is as clean and orderly as a starship cabin — every surface "
    "wiped and polished, nothing lying on the floor anywhere, keep the same hand-painted "
    "stylized look, side view camera and floor line as a base-game room vignette. "
)
P_NEGA = (
    "text, watermark, signature, frame, border, extra background scenery, perspective view, "
    "ceiling, side walls, anime, 3d render, plastic look, "
    "wall posters, framed paintings, wall art, screens showing detailed images or scenery or faces"
)

# 15 房间：id → (中文, 升级态主体描述)
ROOMS = {
    "entry_hall":      ("入口大厅", "a fortified blast-door vestibule upgraded with a scanning gate frame, glowing status strips along the doorframe, modern airlock controls beside the old bulkhead"),
    "dormitory":       ("宿舍", "a rest quarters upgraded with stacked capsule sleeping pods with soft cyan reading lights, a modern heating unit, clean bedding, personal lockers"),
    "mess_hall":       ("食堂", "a mess hall upgraded with an automated serving line, heated display counters, modern food lockers, clean steel tables with the same benches"),
    "medical":         ("医疗室", "a field med bay upgraded with a modern medical pod bed with vital-sign monitor screens, sterile instrument arms, supply cabinets with glowing labels"),
    "war_room":        ("兵棋室", "a war planning room upgraded into a holographic command post: a sand table with a glowing cyan holographic terrain map projected above it, modern digital consoles and wall displays around the old planning table"),
    "workshop":        ("维修工坊", "a two-station workshop upgraded with a precision robotic arm over one workbench, powered tool racks, a parts printer, glowing tool outlines on the board"),
    "archive":         ("档案室", "an archive room upgraded with glowing data-codex shelves, a retrieval terminal screen, card walls in illuminated frames, reading desk with a modern lamp"),
    "comms":           ("通讯室", "a communications room upgraded with a modern signal array console, multiple glowing waveform screens, antenna feed panels replacing the old radios"),
    "depot":           ("仓库", "a card-wall depot upgraded with automated vertical rack shelves, glowing item tags on every card slot, a cargo lift platform, inventory scanner frame"),
    "honor_hall":      ("荣誉陈列室", "a honor hall upgraded with illuminated memorial display cases, a glowing wall of honor with framed medals, a holographic remembrance plinth"),
    "reactor":         ("反应堆核心", "a reactor core chamber upgraded with a contained arc-fusion core, reinforced magnetic ring, glowing coolant channels, modern control pedestal"),
    "phase_lab":       ("相位实验室", "a phase laboratory upgraded with a sealed experiment pod, floating sample container with cyan glow, modern measurement consoles, cable conduits"),
    "weather_station": ("气象站", "a weather station room upgraded with a modern meteorological sensor array readout, wall of climate data screens, radar feed terminal"),
    "observatory":     ("观星台", "an observatory upgraded with a modern computerized telescope on a mount, a curved star-chart projection screen, dim blue starlight accents"),
    "monument":        ("纪念碑墙", "a memorial wall upgraded with engraved metal name plaques softly backlit, eternal flame lamp, wreath stands on the same wall"),
}


def load_keys():
    src = open(KEY_MD, "r", encoding="utf-8").read()
    keys = re.findall(r"sk-[A-Za-z0-9]{20,}", src)
    if not keys:
        raise SystemExit("tools/_agnes_image_api.md 里找不到 key")
    return keys


def call_api(prompt, key, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1})
    tmp, resp = out + ".payload.json", out + ".resp.json"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
    subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
                    "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
                    "--data-binary", "@" + tmp, "-o", resp, "--max-time", "180"],
                   capture_output=True, text=True, timeout=200)
    try:
        os.unlink(tmp)
    except OSError:
        pass
    content = open(resp, "r", encoding="utf-8", errors="replace").read()
    try:
        os.unlink(resp)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        print("  非法响应: " + content[:160])
        return False
    url = (data.get("data") or [{}])[0].get("url", "")
    if url:
        subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out, url, "--max-time", "180"],
                       capture_output=True, text=True, timeout=200)
        return os.path.exists(out) and os.path.getsize(out) > 5000
    b64 = (data.get("data") or [{}])[0].get("b64_json", "")
    if b64:
        import base64
        with open(out, "wb") as f:
            f.write(base64.b64decode(b64))
        return os.path.getsize(out) > 5000
    print("  无图像数据: " + content[:160])
    return False


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if "--list" in sys.argv:
        for rid, (zh, _) in ROOMS.items():
            print("%s  %s" % (rid, zh))
        return
    targets = args or list(ROOMS.keys())
    bad = [t for t in targets if t not in ROOMS]
    if bad:
        raise SystemExit("未知房间: %s（--list 查看全部）" % ", ".join(bad))
    keys = load_keys()
    os.makedirs(OUT_DIR, exist_ok=True)
    ok_n = 0
    for i, rid in enumerate(targets):
        zh, desc = ROOMS[rid]
        out = os.path.join(OUT_DIR, "cap_%s_upg.jpeg" % rid)
        if os.path.exists(out) and os.path.getsize(out) > 5000 and not args:
            print("[%d/%d] %s（%s）已存在，跳过" % (i + 1, len(targets), rid, zh))
            ok_n += 1
            continue
        prompt = P_ROOM_UPG + "Scene: " + desc + ". " + P_UPG + "Avoid: " + P_NEGA
        key = keys[i % len(keys)]
        print("[%d/%d] %s（%s）..." % (i + 1, len(targets), rid, zh), end=" ", flush=True)
        ok = call_api(prompt, key, out)
        print("OK %dKB" % (os.path.getsize(out) // 1024) if ok else "FAIL")
        ok_n += 1 if ok else 0
        if i < len(targets) - 1:
            time.sleep(3)
    print("完成 %d/%d" % (ok_n, len(targets)))


if __name__ == "__main__":
    main()
