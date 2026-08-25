# Godot 验证：冷战/现代坦克+IFV 史实口径修正后表完整性
extends SceneTree

func _init() -> void:
	var table = load("res://data/unified_card_table.gd")
	if table == null:
		print("FAIL: 无法加载 unified_card_table.gd")
		quit(1)
		return
	var ok := true
	var expects := {
		# IFV
		"cold_inf_btr60": {"weapon_label": "14.5mm KPVT重机枪", "w_armor": "14.5mm穿甲弹链"},
		"cold_sup_m113": {"w_light": "12.7mm M2重机枪", "w_armor": "12.7mm穿甲弹链"},
		"cold_inf_bmp1": {"weapon_label": "73mm低压滑膛炮", "w_armor": "9M14反坦克导弹"},
		"cold_bradley": {"weapon_label": "25mm M242链炮", "w_armor": "TOW反坦克导弹", "w_air": "7.62mm同轴机枪"},
		# 冷战坦克
		"cold_arm_t55": {"w_armor": "100mm线膛炮", "weapon_label": "100mm主炮"},
		"cold_t62": {"weapon_label": "115mm滑膛炮", "w_armor": "115mm滑膛炮"},
		"cold_t72": {"weapon_label": "125mm滑膛炮"},
		"cold_m60t": {"weapon_label": "105mm线膛炮", "w_armor": "105mm线膛炮"},
		"cold_chieftain": {"weapon_label": "120mm线膛炮"},
		# 现代坦克
		"mod_arm_m1a1": {"weapon_label": "120mm滑膛炮", "w_armor": "120mm滑膛炮"},
		"mod_m1a2": {"weapon_label": "120mm滑膛炮"},
		"mod_arm_m1a2sep": {"w_armor": "120mm滑膛炮"},
		"mod_t90": {"weapon_label": "125mm滑膛炮"},
		"mod_leo2a6": {"weapon_label": "120mm L55滑膛炮"},
		"mod_challenger2": {"weapon_label": "120mm线膛炮"},
		"mod_stryker_mgs": {"weapon_label": "105mm线膛炮", "w_armor": "105mm线膛炮"},
		# 变体
		"cold_arm_btr_e": {"w_armor": "14.5mm穿甲弹链"},
		"cold_sup_bmp1_x": {"w_armor": "9M14反坦克导弹"},
		"mod_arm_abrams_e": {"w_armor": "120mm滑膛炮"},
		# 数值未动的抽查（确认没误伤）
		"cold_inf_btr60_a": {},
	}
	expects.erase("cold_inf_btr60_a")
	var count: int = 0
	for uid in expects:
		var entry: Dictionary = table.get_entry(uid)
		if entry.is_empty():
			print("FAIL: %s 不存在" % uid)
			ok = false
			continue
		for k in expects[uid]:
			count += 1
			var got = entry.get(k)
			if got != expects[uid][k]:
				print("FAIL: %s.%s = %s (期望 %s)" % [uid, k, str(got), str(expects[uid][k])])
				ok = false
	# 数值未动抽查
	for pair in [["cold_t72", "atk_a"], ["mod_m1a2", "atk_a"], ["cold_inf_btr60", "atk_a"], ["cold_bradley", "atk_a"]]:
		var entry: Dictionary = table.get_entry(pair[0])
		count += 1
		if int(entry.get(pair[1], -1)) <= 0:
			print("FAIL: %s.%s 数值异常 %s" % [pair[0], pair[1], str(entry.get(pair[1]))])
			ok = false
	print("断言总数: %d" % (count))
	var all: Array = table.get_all_card_ids()
	print("总卡数: %d (期望 223)" % all.size())
	if all.size() != 223:
		ok = false
	for uid in ["cold_bradley", "mod_leo2a6", "cold_inf_bmp1"]:
		var card = table.build_card_resource(uid)
		if card == null:
			print("FAIL: build_card_resource(%s) = null" % uid)
			ok = false
		else:
			print("PASS smoke: %s -> %s" % [uid, card.display_name])
	if ok:
		print("=== ALL PASS ===")
	else:
		print("=== HAS FAILURES ===")
	quit(0 if ok else 1)
