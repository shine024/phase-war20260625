extends Node
## R5 内容结构批 boot 冒烟（全 autoload 环境）：
##  ① 制造配方扩容 API 实测（era0/1 直接入池：规模/白名单成员/缴获剔除/era2+ 口径不变）
##  ② 布局 60 关 spot check（get_for_level 深拷贝/字段读取）
## 跑法：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_r5_content_boot.tscn

var _fails: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_manufacture_checks()
	_layout_checks()
	_air_trial_checks()
	_icon_checks()
	if _fails.is_empty():
		print("[R5Content] ALL PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			printerr("[R5Content] FAIL: " + f)
		get_tree().quit(1)

func _chk(cond: bool, label: String) -> void:
	if cond:
		print("[R5Content] PASS: " + label)
	else:
		_fails.append(label)

func _manufacture_checks() -> void:
	ManagerLazyLoader.ensure_loaded("manufacture")
	var mm: Node = get_tree().root.get_node_or_null("ManufactureManager")
	_chk(mm != null, "ManufactureManager 未挂载")
	if mm == null:
		return
	var ids: Array = mm.get_recipe_ids()
	_chk(ids.size() >= 60, "配方目录规模 < 60（实际 %d）" % ids.size())
	_chk(ids.size() <= 90, "配方目录规模超出预期上限（实际 %d）" % ids.size())
	# era0/1 无原型代表卡入池（ww1_sup_ford_ambulance/ww2_air_bomber 为
	# enemy_only 敌方形态卡，不在玩家池，不入池才是正确行为——勿当断言样本）
	for pid in ["ww1_vickers", "ww1_a7v",
			"ww2_t34_85", "ww2_kingtiger", "ww2_is2"]:
		_chk(ids.has(pid), "era0/1 直入卡未入池：%s" % pid)
	# enemy_only 敌方形态卡不入池（同名卡非玩家可制造）
	for pid in ["ww1_sup_ford_ambulance", "ww2_air_bomber"]:
		_chk(not ids.has(pid), "enemy_only 卡混入配方目录：%s" % pid)
	# 缴获卡不入池
	for pid in ids:
		if String(pid).begins_with("captured_"):
			_chk(false, "缴获卡混入配方目录：%s" % pid)
			break
	# era2+ 无原型卡不入池（口径不变抽查；cold_mig21 有 cold_boss_mig 等 4 个原型
	# 映射属旧口径入池，cold_chieftain/cold_f4 才是真·无原型玩家卡）
	_chk(not ids.has("cold_chieftain"), "era2 无原型卡不应入池（cold_chieftain）")
	_chk(not ids.has("cold_f4"), "era2 无原型卡不应入池（cold_f4）")
	# 无原型卡情报恒 0 → tier1（白板池语义）
	var tier: int = int(mm.get_pool_tier("ww2_t34_85"))
	_chk(tier == 1, "无原型卡品质档非 1（实际 %d）" % tier)
	# 有原型卡口径不变（tier 随情报可 >1 的接口仍在）
	_chk(mm.has_method("get_effective_pool"), "有效概率池接口缺失")
	# is_manufacturable 与目录一致
	_chk(bool(mm.is_manufacturable("ww2_t34_85")), "is_manufacturable 与目录不一致（ww2_t34_85）")

func _layout_checks() -> void:
	var LBL = load("res://data/level_battle_layouts.gd")
	var count: int = 0
	for lv in range(1, 101):
		if LBL.has_custom_layout(lv):
			count += 1
			var e: Dictionary = LBL.get_for_level(lv)
			e["note"] = "mutated"   # 深拷贝验证：改副本不污染表
	_chk(count == 60, "布局覆盖非 60（实际 %d）" % count)
	_chk(String(LBL.get_note(10)) != "mutated", "get_for_level 非深拷贝（表被污染）")
	_chk(String(LBL.get_note(29)).contains("滩头"), "L29 note 缺失")
	_chk(String(LBL.get_note(100)).contains("终局"), "L100 note 缺失")

## ③ 二战尾部飞行试点（v30.5 R5）：min_level 门 + L39 空中压制真题面 + 槽位活性
func _air_trial_checks() -> void:
	var EA = load("res://data/enemy_archetypes.gd")
	# min_level 门：L36-40 关卡域池含两架实验机
	for lv in [36, 37, 38, 39, 40]:
		var pool: Array = EA.get_ids_for_era_at_level(1, lv)
		_chk(pool.has("ww2_air_me262"), "L%d 池缺 Me-262" % lv)
		_chk(pool.has("ww2_air_meteor_e"), "L%d 池缺流星" % lv)
	# era1 其余关不越门；era0 池不混入
	for lv in [21, 25, 30, 35]:
		var pool2: Array = EA.get_ids_for_era_at_level(1, lv)
		_chk(not pool2.has("ww2_air_me262"), "L%d 池不应有 Me-262" % lv)
	_chk(not EA.get_ids_for_era_at_level(0, 10).has("ww2_air_me262"), "era0 池混入 Me-262")
	# 时代全量口径（图鉴）不受 min_level 影响
	_chk(EA.get_ids_for_era(1).has("ww2_air_me262"), "era1 全量池缺 Me-262")
	# L39 题面 = 空中压制（手工覆盖）；相邻关不被波及
	var TT = load("res://data/level_tactical_themes.gd")
	_chk(String(TT.get_theme_id_for_level(39)) == "air_supremacy", "L39 题面非空中压制")
	for lv in [38, 40]:
		_chk(String(TT.get_theme_id_for_level(lv)) != "air_supremacy", "L%d 不应抽到空中压制" % lv)
	# 波型槽活性：L39 空中压制能 roll 出 aircraft 偏好
	var rng := RandomNumberGenerator.new()
	rng.seed = 39
	var hit_air := false
	for i in range(60):
		var tags: Array = TT.roll_wave_bias("air_supremacy", rng, 1, 39)
		if tags.has("aircraft"):
			hit_air = true
			break
	_chk(hit_air, "L39 空中压制 roll 不出 aircraft 偏好")
	# era0（一战）池零飞行单位：混合绞杀 aircraft 槽被剔除（v23.4 诚实化口径仍成立；
	# era1 全档有 v26 轰炸机属既有行为，实验机 L36-40 界外不入池已由上面池断言覆盖）
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 10
	var leaked := false
	for i in range(80):
		var tags2: Array = TT.roll_wave_bias("mixed_grind", rng2, 0, 10)
		if tags2.has("aircraft"):
			leaked = true
			break
	_chk(not leaked, "L10（era0）混合绞杀 roll 出 aircraft 偏好（应剔除）")
	# 试点区间内混合绞杀 aircraft 槽活
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 37
	var hit37 := false
	for i in range(80):
		var tags3: Array = TT.roll_wave_bias("mixed_grind", rng3, 1, 37)
		if tags3.has("aircraft"):
			hit37 = true
			break
	_chk(hit37, "L37 混合绞杀 roll 不出 aircraft（试点关应活）")
	# L39 波次序列：aircraft 偏好波占多数（真题面）
	var seq: Array = LevelSpawnSequences.get_sequence_for_level(39)
	var air_waves := 0
	var total_waves := 0
	for spec in seq:
		if spec.has("archetype_bias_tags"):
			total_waves += 1
			if (spec["archetype_bias_tags"] as Array).has("aircraft"):
				air_waves += 1
	_chk(total_waves > 0 and air_waves >= maxi(1, int(total_waves * 0.4)),
		"L39 空中波占比不足（%d/%d）" % [air_waves, total_waves])
	# L21-35 关卡序列无 aircraft 偏好泄漏
	for lv in [21, 25, 30, 35]:
		var seq2: Array = LevelSpawnSequences.get_sequence_for_level(lv)
		var leaked2 := false
		for spec2 in seq2:
			if (spec2.get("archetype_bias_tags", []) as Array).has("aircraft"):
				leaked2 = true
				break
		_chk(not leaked2, "L%d 序列泄漏 aircraft 偏好" % lv)

## ④ 试验机卡图（v30.5 R5 生图批）：运行时解析到新部署的 PNG（非占位/模板回退）
func _icon_checks() -> void:
	var EA = load("res://data/enemy_archetypes.gd")
	for pid in ["ww2_air_me262", "ww2_air_meteor_e"]:
		var p: String = String(EA.resolve_card_icon_texture_path(pid, EA.get_config(pid)))
		_chk(p.contains("/%s.png" % pid), "%s 未解析到专属卡图（实际 %s）" % [pid, p])
		if p.contains("/%s.png" % pid):
			_chk(ResourceLoader.exists(p), "%s 卡图未入资源系统（%s，需 --import）" % [pid, p])
	# v26 八机（RELEASE_GAP 遗留项终验：图已在盘，运行时解析应非占位）
	for pid in ["ww2_air_bomber", "ww2_air_dive_bomber", "cold_air_strike_fighter",
			"cold_air_bomber", "mod_air_multirole", "mod_air_bomber",
			"fut_air_stealth_multirole", "fut_air_stealth_bomber"]:
		var p2: String = String(EA.resolve_card_icon_texture_path(pid, EA.get_config(pid)))
		_chk(p2.contains("/%s.png" % pid), "v26 机 %s 未解析到专属卡图（实际 %s）" % [pid, p2])
	# 脚部锚点已生成（飞机类为高位档；具体值随图轮廓比例浮动，只断存在+合理区间）
	var CFA = load("res://data/card_foot_anchors.gd")
	for pid in ["ww2_air_me262", "ww2_air_meteor_e"]:
		var ff: float = float(CFA.FOOT_FRAC.get(pid, -1.0))
		_chk(ff >= 0.15 and ff <= 0.60, "%s 脚部锚点缺失/异常（%s）" % [pid, str(ff)])
