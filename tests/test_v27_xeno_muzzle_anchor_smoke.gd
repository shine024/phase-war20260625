extends SceneTree
## v27 星冥弹道锚点覆盖冒烟：图源回退（get_anchor 第④级）命中统计 + 经典回退不回归
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/test_v27_xeno_muzzle_anchor_smoke.gd

func _initialize() -> void:
	const XenoUnits = preload("res://data/xeno_units.gd")
	const MuzzleAnchors = preload("res://data/muzzle_anchors.gd")
	const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")

	var errors: PackedStringArray = []
	var hit_direct: Array = []
	var hit_visual: Array = []
	var fallback: Array = []

	for xid in XenoUnits.ID_ORDER:
		var anchor: Dictionary = MuzzleAnchors.get_anchor(String(xid))
		if not anchor.is_empty():
			var vis: String = EnemyUnitManifest.visual_id_for_archetype(String(xid))
			if MuzzleAnchors.MUZZLE.has(String(xid)):
				hit_direct.append(String(xid))
			else:
				hit_visual.append("%s→%s" % [String(xid), vis])
		else:
			fallback.append(String(xid))

	print("[v27] 直命中(", hit_direct.size(), "): ", hit_direct)
	print("[v27] 图源回退命中(", hit_visual.size(), "): ", hit_visual)
	print("[v27] 胸口兜底(", fallback.size(), "): ", fallback)

	# 断言：占位图本身有敌方标注（fut_*/mod_ 卡图 id 在 MUZZLE 表内）的单位必须图源命中
	# 注：fut_air_stealth_multirole/bomber（六代机/B-21）为 v26 八飞机，敌我标注表均未标——
	# 属既有数据缺口（换 vis_xeno_* 专属图时随锚点流程补），占位期走胸口兜底为正确行为。
	for xid in XenoUnits.ID_ORDER:
		var vis_m: String = EnemyUnitManifest.visual_id_for_archetype(String(xid))
		if MuzzleAnchors.MUZZLE.has(vis_m) and MuzzleAnchors.get_anchor(String(xid)).is_empty():
			errors.append("应图源命中但 miss: %s (vis=%s)" % [xid, vis_m])
	# 断言：兜底单位必须属于"无标注图"（vis_player_* 占位 或 未标注的新飞机卡）
	for xid in fallback:
		var vis: String = EnemyUnitManifest.visual_id_for_archetype(String(xid))
		if not vis.begins_with("vis_player_") and MuzzleAnchors.MUZZLE.has(vis):
			errors.append("有标注卡图却兜底: %s (vis=%s)" % [xid, vis])
	# 断言：经典单位回退行为不回归（抽查 foe_ 前缀 + 平台映射 + 直查三类）
	if MuzzleAnchors.get_anchor("ww1_inf_mp18").is_empty():
		errors.append("经典直查回归: ww1_inf_mp18")
	if MuzzleAnchors.get_anchor("fut_sup_bulwark").is_empty():
		errors.append("经典直查回归: fut_sup_bulwark")
	if MuzzleAnchors.get_anchor("ww1_fort_pillbox").is_empty():
		errors.append("堡垒直查回归: ww1_fort_pillbox")

	if errors.is_empty():
		print("[v27] MUZZLE-ANCHOR-SMOKE PASS（命中 ", hit_direct.size() + hit_visual.size(), "/20）")
		quit(0)
	else:
		for e in errors:
			printerr("[v27] FAIL: ", e)
		quit(1)
