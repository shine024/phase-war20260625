extends SceneTree
## R5 内容结构批（设计审查 F-11，v30.5）验证脚本——布局表纯数据实测 + 扩容源码断言。
## 运行：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_r5_content_check.gd
## LevelBattleLayouts 为纯静态数据类（无 autoload 依赖），--script 直调安全；
## manufacture_manager 是 lazy manager（引用 IntelManual 等 autoload 全局名），
## 其扩容规模的 API 实测在 boot 场景（_tmp_r5_content_boot.tscn）跑，此处只做源码断言。

var _fails: Array = []
var _passes: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails.append(label)

func _src(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _init() -> void:
	print("=== R5 content check ===")
	var LBL = load("res://data/level_battle_layouts.gd")

	# ── 1. 布局覆盖 24→60 ──
	var layouts: Dictionary = {}
	for lv in range(1, 101):
		if LBL.has_custom_layout(lv):
			layouts[lv] = true
	_check(layouts.size() == 60, "布局覆盖非 60 关（实际 %d）" % layouts.size())
	_check(not layouts.has(1), "L1 教程关不应有布局")

	# ── 2. 字段约束（rows 仅 2/3；cols 2-4；excluded 编号在界内）──
	for lv in range(1, 101):
		if not LBL.has_custom_layout(lv):
			continue
		var e: Dictionary = LBL.get_for_level(lv)
		var rows: int = int(e.get("rows", 3))
		_check(rows == 2 or rows == 3, "L%d rows 非法（%d）" % [lv, rows])
		var pc: int = int(e.get("player_cols", 3))
		var ec: int = int(e.get("enemy_cols", 3))
		_check(pc >= 2 and pc <= 4, "L%d player_cols 越界（%d）" % [lv, pc])
		_check(ec >= 2 and ec <= 4, "L%d enemy_cols 越界（%d）" % [lv, ec])
		for slot in e.get("player_excluded", []):
			_check(int(slot) >= 0 and int(slot) < rows * pc, "L%d player_excluded 槽号越界（%d）" % [lv, int(slot)])
		for slot in e.get("enemy_excluded", []):
			_check(int(slot) >= 0 and int(slot) < rows * ec, "L%d enemy_excluded 槽号越界（%d）" % [lv, int(slot)])
		_check(not String(LBL.get_note(lv)).is_empty(), "L%d 缺 note 题面" % lv)

	# ── 3. 五 Boss 关有棋面（20/40/60/80/100）──
	for lv in [20, 40, 60, 80, 100]:
		_check(LBL.has_custom_layout(lv), "Boss 关 L%d 缺棋面" % lv)

	# ── 4. 有规则的关尽量有布局（special_rules 41 关中未覆盖者仅豁免清单内）──
	# 豁免：规则关但有意不配布局的（题面不冲突）
	var rule_levels := [3, 5, 8, 10, 12, 15, 17, 19, 20, 23, 25, 27, 30, 32, 35, 38, 40,
		42, 45, 47, 50, 52, 55, 57, 60, 62, 65, 67, 70, 72, 75, 80, 82, 85, 87, 88, 90, 92, 95, 100]
	var no_layout_rules := []
	for lv in rule_levels:
		if not LBL.has_custom_layout(lv):
			no_layout_rules.append(lv)
	_check(no_layout_rules.is_empty(), "规则关缺布局：%s" % str(no_layout_rules))

	# ── 5. 制造扩容（源码断言；规模实测在 boot）──
	var mm := _src("res://managers/manufacture_manager.gd")
	_check(mm.contains("era0/1 直接入池"), "制造扩容注释缺失")
	_check(mm.contains("cres.era <= 1 and cres.card_type == GC.CardType.COMBAT_UNIT"), "era0/1 入池过滤缺失")
	_check(mm.contains('pid2.begins_with("captured_")'), "扩容未剔除缴获卡")
	# 帮助面板数字已去硬编码
	var hp := _src("res://scenes/ui/help_panel.gd")
	_check(not hp.contains("38 张"), "帮助面板配方数仍硬编码 38")

	# ── 6. 二战尾部飞行试点（源码断言；API 实测在 boot）──
	# 数据真身三件套：统一卡表（数值）+ manifest D 段（池籍/等级门）+ TAG_PATCH（fast/elite）
	var uct := _src("res://data/unified_card_table.gd")
	_check(uct.contains("\"card_id\":\"ww2_air_me262\""), "Me-262 统一表条目缺失")
	_check(uct.contains("\"card_id\":\"ww2_air_meteor_e\""), "流星统一表条目缺失")
	var eum := _src("res://data/enemy_unit_manifest.gd")
	_check(eum.contains("\"ww2_air_me262\", \"ww2_air_meteor_e\""), "D 段池籍缺失")
	_check(eum.contains("\"ww2_air_me262\": 36"), "Me-262 min_level 门缺失")
	_check(eum.contains("\"ww2_air_meteor_e\": 36"), "流星 min_level 门缺失")
	_check(eum.contains("\"min_level\": int(POOL_MIN_LEVEL.get(aid, 0))"), "D 段行未落 min_level")
	var eag := _src("res://data/enemy_archetypes.gd")
	_check(eag.contains("\"ww2_air_me262\": [\"fast\"]"), "Me-262 fast 补丁缺失")
	_check(eag.contains("\"ww2_air_meteor_e\": [\"elite\", \"fast\"]"), "流星 elite/fast 补丁缺失")
	var ltt := _src("res://data/level_tactical_themes.gd")
	_check(ltt.contains("39: AIR_SUPREMACY"), "L39 空中压制覆盖缺失")
	for ln in ltt.split("\n"):
		var s := ln.strip_edges()
		if s.begins_with("0: [") or s.begins_with("1: ["):
			_check(not s.contains("AIR_SUPREMACY"), "era0/1 候选表混入 AIR_SUPREMACY：%s" % s)
	# 出怪/兜底/情报三处池取数走关卡域（min_level 门生效前提）
	for f in ["res://managers/battle/battle_spawn_system.gd",
			"res://scenes/units/enemy_phase_field_driver.gd",
			"res://scenes/world_map.gd"]:
		_check(_src(f).contains("get_ids_for_era_at_level"), "%s 池未走关卡域" % f)

	if _fails.is_empty():
		print("ALL PASS (%d checks)" % _passes)
		quit(0)
	else:
		for f in _fails:
			push_error("[R5-CHECK] " + f)
		print("FAILED: %d / passed %d" % [_fails.size(), _passes])
		quit(1)
