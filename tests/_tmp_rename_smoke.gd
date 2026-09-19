extends SceneTree
## v6.15 相位师改名冒烟：JSON/LEGACY 兜底/叙事文本/档案文案 四链一致性。

func _init() -> void:
	var fails: Array = []

	var EPM = load("res://data/enemy_phase_masters.gd")
	var all: Array = EPM.ENEMY_MASTERS
	if all.size() != 30:
		fails.append("ENEMY_MASTERS 数量 %d != 30" % all.size())
	var m30: Dictionary = EPM.get_master_by_id("enemy_master_030")
	if m30.get("name") != "贺同舟" or m30.get("title") != "第三十一个":
		fails.append("030 JSON 链名字错误: %s / %s" % [m30.get("name"), m30.get("title")])
	var m1: Dictionary = EPM.get_master_by_id("enemy_master_001")
	if m1.get("name") != "沈铸城" or m1.get("title") != "十七天的防线":
		fails.append("001 名字错误: %s / %s" % [m1.get("name"), m1.get("title")])

	# LEGACY 兜底链（分时代 gd 文件）与 JSON 同步
	var legacy: Array = EPM.LEGACY_ENEMY_MASTERS
	if legacy.size() != 30:
		fails.append("LEGACY 数量 %d != 30" % legacy.size())
	for i in range(30):
		if String(legacy[i].get("name", "")) != String(all[i].get("name", "")):
			fails.append("LEGACY/JSON 名字不同步 @%d: %s vs %s" % [i, legacy[i].get("name"), all[i].get("name")])
			break

	# 叙事：L10 副句 + 驻守台词仍可解析
	var CN = load("res://data/campaign_narrative.gd")
	if not String(CN.LEVEL_ECHO.get(10, "")).contains("霍北望守在这里"):
		fails.append("LEVEL_ECHO[10] 未同步: %s" % CN.LEVEL_ECHO.get(10, ""))
	if String(CN.get_post_battle_master_name(20)) != "秦引路":
		fails.append("L20 署名错误: %s" % CN.get_post_battle_master_name(20))
	var pre10: Array = CN.get_pre_battle_lines(10)
	if pre10.is_empty():
		fails.append("L10 战前台词缺失")

	# 同伴档案：027 deed 微调后可读
	var HAT = load("res://data/hero_archive_texts.gd")
	var d27: Dictionary = HAT.BESPOKE.get("enemy_master_027", {})
	if not String(d27.get("deed", "")).begins_with("她的火收放自如"):
		fails.append("027 deed 未同步: %s" % d27.get("deed", ""))

	# 混融系别名不受影响
	if HAT.faction_display("void_flame") != "虚空混融系":
		fails.append("混融系显示名受影响: %s" % HAT.faction_display("void_flame"))

	if fails.is_empty():
		print("RENAME_SMOKE_OK")
	else:
		for f in fails:
			print("FAIL: ", f)
		print("RENAME_SMOKE_FAILED")
		push_error("rename smoke failed")
	quit(0)
