extends SceneTree
## v28 T4 稀有度辉光断言（临时）：rarity_panel_style 必须带稀有度色外辉光递进。
## 用法：godot --headless --path . --script tests/_tmp_t4_rarity_glow_check.gd

func _initialize() -> void:
	var CFU = load("res://scripts/card_frame_ui.gd")
	var GC = load("res://resources/game_constants.gd")
	var fails: Array[String] = []
	var expect := {
		"common": [0, 0.0], "uncommon": [3, 0.22], "rare": [3, 0.28],
		"epic": [4, 0.36], "legendary": [5, 0.45], "mythic": [6, 0.55],
	}
	for r in expect.keys():
		var sb: StyleBoxFlat = CFU.rarity_panel_style(r)
		var want_size: int = expect[r][0]
		var want_a: float = expect[r][1]
		if sb == null:
			fails.append(r + ": stylebox null")
			continue
		if sb.shadow_size != want_size:
			fails.append("%s: shadow_size=%d want %d" % [r, sb.shadow_size, want_size])
		if want_size > 0:
			var rc: Color = GC.get_rarity_color(r)
			if absf(sb.shadow_color.a - want_a) > 0.01:
				fails.append("%s: glow alpha=%.2f want %.2f" % [r, sb.shadow_color.a, want_a])
			if absf(sb.shadow_color.r - rc.r) > 0.01:
				fails.append("%s: glow 不带稀有度色相" % r)
	if fails.is_empty():
		print("[T4-CHECK] ALL PASS (6 rarities glow ladder)")
	else:
		for f in fails:
			print("[T4-CHECK] FAIL: ", f)
	quit(1 if not fails.is_empty() else 0)
