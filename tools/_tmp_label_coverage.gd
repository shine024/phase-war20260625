extends SceneTree
## 临时验证（用后即删）：改造效果键中文翻译覆盖率 + 背包瓷砖文案抽样。

func _initialize() -> void:
	pass  # autoload 首帧才挂载，工作挪到 _process

func _process(_delta: float) -> bool:
	_run()
	return true

func _run() -> void:
	var reg: Node = root.get_node_or_null("/root/ModificationRegistry")
	if reg == null:
		print("[LBL] FAIL: ModificationRegistry 未就绪")
		quit(1)
		return
	var ModEffectLabels = load("res://scripts/ui/mod_effect_labels.gd")
	# 收集全部改造的全部效果键（effects + level_effects 内层）
	var keys := {}
	var mod_count := 0
	for t in range(9):
		for mid in (reg.call("get_for_unit_type", t) as Array):
			var data: Dictionary = reg.call("get_data", String(mid))
			if data.is_empty():
				continue
			mod_count += 1
			for src in [data.get("effects", {}), data.get("level_effects", {})]:
				if src is Dictionary:
					for k in (src as Dictionary).keys():
						var vv = (src as Dictionary)[k]
						if vv is Dictionary:  # level_effects 档位壳
							for kk in (vv as Dictionary).keys():
								keys[String(kk)] = true
						else:
							keys[String(k)] = true
	print("[LBL] 改造 ", mod_count, " 个，效果键 ", keys.size(), " 个")
	# 断言全部可翻译（translate 未命中会原样返回 → 含下划线即漏）
	var missing: Array = []
	for k in keys.keys():
		var t: String = ModEffectLabels.translate(String(k))
		if t == String(k) and String(k).contains("_"):
			missing.append(String(k))
	if not missing.is_empty():
		print("[LBL] FAIL 漏译键: ", missing)
	else:
		print("[LBL] 覆盖率 100%（无裸显英文键名）")
	# 背包瓷砖文案抽样（用户截图里裸显的两个键 + 常见键）
	var bp = load("res://scenes/ui/backpack_panel.gd").new()
	var samples := [["accuracy_bonus", 0.5], ["death_heal", 0.2], ["attack_light", 8], ["max_hp", 40], ["crit_chance", 0.12], ["phase_shift_counter", 1], ["hijack_aura_cd", 18.0], ["salvage_repair", 0.08]]
	for s in samples:
		print("[LBL] 瓷砖行: ", bp._format_mod_effect_short(String(s[0]), s[1]))
	bp.free()
	print("[LBL] ", "PASS" if missing.is_empty() else "FAIL")
	quit(0 if missing.is_empty() else 1)
