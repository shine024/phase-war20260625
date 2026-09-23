extends SceneTree
## v26.x 批次一临时验证：short_name 数据链 + 名牌解析 + 变体后缀剥离（纯逻辑，不碰 autoload 依赖）

func _init() -> void:
	var fails: Array[String] = []
	var UCT = load("res://data/unified_card_table.gd")
	var Strip = load("res://scripts/card_grid_name_strip.gd")
	var with_short := 0
	var checked_short := 0
	var checked_suffix := 0
	for id in UCT.get_all_card_ids():
		var c = UCT.build_card_resource(id)
		if c == null:
			fails.append("build null: " + str(id))
			continue
		if not c.short_name.is_empty():
			with_short += 1
			if not Strip.text_fits(c.short_name, 64.0, 11):
				fails.append("short too wide: %s -> %s" % [id, c.short_name])
			# 短名卡：解析结果必须等于 short_name
			if Strip.battlefield_display_name(c) != c.short_name:
				fails.append("short resolve: %s -> %s" % [c.display_name, Strip.battlefield_display_name(c)])
			checked_short += 1
		if c.display_name.ends_with("·精锐") or c.display_name.ends_with("·敌方") \
				or c.display_name.ends_with("·Boss") or c.display_name.ends_with("·改"):
			# 无短名的变体卡：解析结果必须剥掉后缀
			if not c.short_name.is_empty():
				continue  # 短名直接生效，不走剥后缀
			var resolved: String = Strip.battlefield_display_name(c)
			if resolved.ends_with("·精锐") or resolved.ends_with("·敌方") \
					or resolved.ends_with("·Boss") or resolved.ends_with("·改"):
				fails.append("suffix strip failed: %s -> %s" % [c.display_name, resolved])
			checked_suffix += 1
	if with_short != 76:  # v26.x 短名总数（第二轮校准后；2026-09-02 修死文案——判定值一直是对的，报错文案旧值 58 未同步）
		fails.append("short_name count=%d expect 76" % with_short)
	if Strip.battlefield_display_name(null) != "":
		fails.append("null card should resolve empty")
	print("cards with short_name: %d (checked %d), suffix variants checked: %d" % [with_short, checked_short, checked_suffix])
	if fails.is_empty():
		print("BATCH1 CHECK: ALL PASS")
	else:
		for f in fails: print("FAIL: ", f)
	quit(0 if fails.is_empty() else 1)
