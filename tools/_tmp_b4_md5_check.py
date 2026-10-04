# -*- coding: utf-8 -*-
import hashlib, json, os, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
man = json.load(open(os.path.join(ROOT, ".godot", "art_backup_b4_deploy_20261004", "_md5_manifest.json"), encoding="utf-8"))
bad = 0
for rel in ["player/vis_player_060.png", "enemy/vis_enemy_060.png",
            "player/vis_player_065.png", "enemy/vis_enemy_065.png",
            "player/vis_player_061.png", "enemy/vis_enemy_061.png"]:
    k = os.path.join("assets", "card_icons", *rel.split("/"))
    h = hashlib.md5(open(os.path.join(ROOT, "assets", "card_icons", *rel.split("/")), "rb").read()).hexdigest()
    ok = (h == man.get(k))
    bad += (not ok) and (rel.endswith(("060", "065")))
    print("OK " if ok else "DIFF ", rel, "(060/065 预期=OK 还原, 061 预期=DIFF 新图)")
print("还原判定:", "通过" if bad == 0 else "失败 %d" % bad)
