# -*- coding: utf-8 -*-
# 卡图解析链探针：验证 override 接线在真实解析链中生效（10-01 深夜换卡批）
# 用法：godot --headless --script tools/probe_card_wiring.gd --path .
extends SceneTree


# (card_id, 期望路径子串, 说明)
const CASES := [
	# 9 张新接线 → player/<key>.png 专属文件
	["mod_stinger", "player/mod_stinger.png", "新7-1"],
	["mod_stryker_m2", "player/mod_stryker_m2.png", "新7-2"],
	["platform_modern_stealth", "player/platform_modern_stealth.png", "新7-3"],
	["ww1_105mm", "player/ww1_105mm.png", "新7-4"],
	["ww1_a7v", "player/ww1_a7v.png", "新7-5"],
	["ww1_mark4", "player/ww1_mark4.png", "新7-6"],
	["ww1_lanchest", "player/ww1_lanchest.png", "新7-7"],
	["mod_sup_m4_carbine", "player/mod_sup_m4_carbine.png", "补漏A"],
	["ww2_air_dive_bomber", "player/ww2_air_dive_bomber.png", "补漏B"],
	# 共享方保持原图不动（零波及）
	["ww1_saint", "player/vis_player_042.png", "留-圣沙蒙"],
	["cold_sam7", "player/vis_player_090.png", "留-sam7"],
	["mod_stryker_mgs", "player/vis_player_059.png", "留-MGS"],
	["platform_ww1_fort", "player/vis_player_003.png", "留-fort"],
	["fut_scout_drone", "player/vis_player_022.png", "留-scout"],
	["hound", "player/vis_player_001.png", "留-hound"],
	["platform_ww1_medium", "player/vis_player_001.png", "留-medium"],
]


func _initialize() -> void:
	var fails := 0
	for case in CASES:
		var card: CardResource = CardResource.new()
		card.card_id = case[0]
		card.card_type = 0  # COMBAT_UNIT
		var full: String = UiAssetLoader.card_icon_path_for(card)
		var thumb: String = UiAssetLoader.card_icon_path_for_list(card)
		var ok_full: bool = full.ends_with(case[1])
		var ok_thumb: bool = thumb.is_empty() or thumb.contains("_thumb384/")
		var ok := ok_full and ok_thumb
		if not ok:
			fails += 1
		print("%s [%s] %s -> full=%s thumb=%s" % ["PASS" if ok else "FAIL", case[2], case[0], full, thumb])
	print("RESULT %d/%d pass" % [CASES.size() - fails, CASES.size()])
	quit(1 if fails > 0 else 0)
