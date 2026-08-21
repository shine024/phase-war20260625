extends SceneTree
## 无人机系列卡图重生成后的链路 smoke 验证（--script 模式，秒级）
## 1) ui_asset_loader.gd 可解析 + override 指向新专属图
## 2) 12 个产物文件存在（10 新增 + 2 覆盖 vis_065）
## 3) manifest 敌方路径仍指向 vis_enemy_065（战场精灵）
## 4) card_icon_path_for 对 5 张卡返回非空路径

const UiAssetLoaderScript := preload("res://scripts/ui_asset_loader.gd")
const ManifestScript := preload("res://data/enemy_unit_manifest.gd")
const CardResourceScript := preload("res://resources/card_resource.gd")
const GC := preload("res://resources/game_constants.gd")

func _init() -> void:
	var fails: Array = []
	var o: Dictionary = UiAssetLoaderScript.PLAYER_ICON_OVERRIDE

	# 1) override 指向新专属图（card_id 自身 = player/{card_id}.png）
	var expect_self := {
		"fut_swarm": "fut_swarm",
		"fut_attack_drone": "fut_attack_drone",
		"fut_nano_drone": "fut_nano_drone",
		"fe_aether_swarm_queen": "fe_aether_swarm_queen",
	}
	for cid in expect_self:
		var got: String = String(o.get(cid, ""))
		if got != cid:
			fails.append("override %s = '%s'（期望 '%s'）" % [cid, got, cid])

	# 2) 产物文件存在（FileAccess 不依赖 import）
	for sub in ["enemy", "player"]:
		for name in ["fut_air_drone", "fe_aether_swarm_queen", "fut_swarm",
				"fut_attack_drone", "fut_nano_drone"]:
			var p: String = "res://assets/card_icons/%s/%s.png" % [sub, name]
			if not FileAccess.file_exists(p):
				fails.append("缺文件 %s" % p)
	for pair in [["enemy", "vis_enemy_065"], ["player", "vis_player_065"]]:
		var p2: String = "res://assets/card_icons/%s/%s.png" % [pair[0], pair[1]]
		if not FileAccess.file_exists(p2):
			fails.append("缺文件 %s" % p2)

	# 3) manifest 敌方路径 → vis_enemy_065
	var enemy_p: String = ManifestScript.get_unit_icon_path_for_archetype("fut_air_drone", false)
	if enemy_p != "res://assets/card_icons/enemy/vis_enemy_065.png":
		fails.append("manifest 敌方路径 = '%s'（期望 vis_enemy_065）" % enemy_p)

	# 4) card_icon_path_for 非空（dedicated/override/manifest 任一路径命中）
	var loader = UiAssetLoaderScript
	for cid in ["fut_air_drone", "fe_aether_swarm_queen", "fut_swarm",
			"fut_attack_drone", "fut_nano_drone", "fut_space_fighter"]:
		var c = CardResourceScript.new()
		c.card_id = cid
		c.card_type = GC.CardType.COMBAT_UNIT
		var icon: String = loader.card_icon_path_for(c)
		if icon.is_empty():
			fails.append("card_icon_path_for(%s) 为空" % cid)
		else:
			print("  %s -> %s" % [cid, icon])
		c.free()

	# 5) 锚点表已含新卡
	var anchors := preload("res://data/card_foot_anchors.gd")
	for cid in ["fut_air_drone", "fut_swarm", "fut_attack_drone", "fut_nano_drone"]:
		if cid != String(anchors.FOOT_FRAC.get(cid, "")) and not anchors.FOOT_FRAC.has(cid):
			fails.append("FOOT_FRAC 缺 %s" % cid)

	if fails.is_empty():
		print("[PASS] 无人机系列卡图链路 5/5 组全部通过")
	else:
		for f in fails:
			push_error("[FAIL] " + f)
		print("[FAIL] %d 项未通过" % fails.size())
	quit(0)
