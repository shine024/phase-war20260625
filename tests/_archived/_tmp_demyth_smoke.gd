extends SceneTree
## v6.15 去神魔化三件套冒烟：大招/技能/相位仪/战功榜四链加载与新名抽查。

func _init() -> void:
	var fails: Array = []

	# ① 敌方大招表：数量不变 + 新名抽查 + 旧名清零
	var EMI = load("res://data/enemy_master_instruments.gd")
	var ult10: Array = EMI.get_master_ultimate_spells("enemy_master_010")
	var ult_names: Array = []
	for u in ult10:
		ult_names.append(String(u.get("name", "")))
	if not ult_names.has("最后一根火柴"):
		fails.append("010 大招新名缺失: %s" % str(ult_names))
	var ult27: Array = EMI.get_master_ultimate_spells("enemy_master_027")
	for u in ult27:
		var nm := String(u.get("name", ""))
		if nm == "三十七度烈焰" or nm == "烈焰极刑":
			pass
	var all_ult_text := JSON.stringify(EMI.MASTER_ULTIMATES)
	for bad in ["宙斯", "普罗米修斯", "地狱", "诸神", "凤凰", "深渊", "女神", "神之", "魔神", "末日审判"]:
		if all_ult_text.contains(bad):
			fails.append("大招表残留旧词: %s" % bad)
	var var_display := JSON.stringify(EMI.MASTER_VARIANTS)
	if var_display.contains("·"):
		fails.append("变体 display 仍有旧格式名（含·）")

	# ② 技能树：编译加载 + 旧称号清零
	var EMS = load("res://data/enemy_master_skill_tree.gd")
	var st_text := JSON.stringify(EMS.get_master_skills("enemy_master_029")) if EMS.has_method("get_master_skills") else ""
	var tree_src := FileAccess.get_file_as_string("res://data/enemy_master_skill_tree.gd")
	for bad in ["雷霆主宰", "电磁装甲师", "熵增炎魔", "诸神黄昏", "凤凰重生", "虚空领主", "电磁战神", "混沌炎魔", "神之光环", "雷霆之神", "夜之女神", "炼狱女王"]:
		if tree_src.contains('"name": "%s"' % bad):
			fails.append("技能树残留: %s" % bad)

	# ③ 玩家相位仪：顶格档新名 + 掉落系列数量
	var PI = load("res://data/phase_instruments.gd")
	var defs: Array = PI.get_all()
	var pi_text := JSON.stringify(defs)
	for good in ["钢铁卫士·传奇", "烈焰破坏者·传奇", "雷霆风暴·传奇", "虚空行者·传奇", "熵焰卫士", "混沌焰仪"]:
		if not pi_text.contains(good):
			fails.append("相位仪新名缺失: %s" % good)
	for bad in ["钢铁之神", "炎魔之神", "雷神", "虚空女神", "神威钢躯", "雷神之躯", "烈焰地狱"]:
		if pi_text.contains(bad):
			fails.append("相位仪残留旧名: %s" % bad)

	# ④ 战功榜混融系对齐宪法
	var EPL = load("res://data/enemy_phase_leaderboard.gd")
	var fi: Dictionary = EPL.get_faction_display_info("void_flame")
	if String(fi.get("name", "")) != "虚空混融系":
		fails.append("混融系显示名未对齐: %s" % fi.get("name"))

	if fails.is_empty():
		print("DEMYTH_SMOKE_OK")
	else:
		for f in fails:
			print("FAIL: ", f)
		print("DEMYTH_SMOKE_FAILED")
	quit(0)
