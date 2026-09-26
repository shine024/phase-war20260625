extends SceneTree
## v6.30（记录3）批次冒烟：--script 模式加载全部改动脚本 + 纯数据断言。
## 注意：--script 模式不注册 autoload（AGENTS.md Godot CLI 节），故只做
## ①编译级 load ②静态/纯数据可调函数断言；依赖管理器的函数仅验证存在性。
## 通过输出 V630_SMOKE_OK。

var _fail := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok  ", label)
	else:
		_fail += 1
		printerr("  FAIL", label)

func _initialize() -> void:
	print("== v6.30 smoke ==")

	# ── 1) 编译级加载（改动脚本全量） ──
	var scripts := [
		"res://scenes/main.gd",
		"res://scenes/ui/backpack_panel.gd",
		"res://scenes/ui/backpack/backpack_presenter.gd",
		"res://scenes/ui/mvp_panel.gd",
		"res://scenes/ui/store_panel.gd",
		"res://scenes/ui/modification_panel.gd",
		"res://scenes/ui/top_hud_bar.gd",
		"res://scenes/ui/intel_harvest_display.gd",
		"res://scenes/ui/phase_master_skill_panel.gd",
		"res://scripts/systems/afk_mode_manager.gd",
		"res://scripts/battle/fort_shield_aura.gd",
		"res://scripts/battle/vfx_impact_factory.gd",
		"res://managers/battle/battle_manager.gd",
		"res://managers/battle/battle_spawn_system.gd",
		"res://managers/battle/battle_spectacle.gd",
		"res://managers/battle/phase_instrument_abilities.gd",
		"res://data/phase_master_skill_tree.gd",
		"res://data/phase_master_skill_tree_v8_extension.gd",
		"res://data/unlock_labels.gd",
	]
	for p in scripts:
		var s: Script = load(p)
		_check(s != null and s.can_instantiate(), "load " + p)

	# ── 2) 背包整行制（纯 RefCounted 逻辑，实例化脚本级验证） ──
	var bp: Script = load("res://scenes/ui/backpack_panel.gd")
	var panel: Control = bp.new()
	var grid := GridContainer.new()
	grid.columns = 7
	panel.add_child(grid)
	for i in 8:
		grid.add_child(Control.new())  # 8 张假卡
	panel._ensure_min_card_slots(grid)
	# 8 卡 7 列 → 2 整行 + 1 整行 = 21（3×7），残行不可能
	_check(grid.get_child_count() == 21, "backpack full-row target 8cards/7cols=21 (got %d)" % grid.get_child_count())
	for i in 8:
		grid.get_child(0).free()
	# 0 卡 → 1 整行 = 7
	panel._ensure_min_card_slots(grid)
	_check(grid.get_child_count() == 7, "backpack full-row target 0cards=7 (got %d)" % grid.get_child_count())
	panel.free()

	# ── 3) 技能树数据：power_cap 翻译分支 + 英文代号清零 ──
	var UL: Script = load("res://data/unlock_labels.gd")
	var Tree8: Script = load("res://data/phase_master_skill_tree_v8_extension.gd")
	var TreeMain: Script = load("res://data/phase_master_skill_tree.gd")
	var nodes: Array = []
	var main_tree: Dictionary = TreeMain.get_script_constant_map().get("SKILL_TREE", {})
	var ext_tree: Dictionary = Tree8.get_script_constant_map().get("EXTENSION_NODES", {})
	for branch in ["command", "firepower", "intelligence"]:
		nodes.append_array(main_tree.get(branch, []))
		nodes.append_array(ext_tree.get(branch, []))
	_check(nodes.size() > 50, "skill nodes collected (%d)" % nodes.size())
	var pc_found := false
	var bad_en := []
	for n in nodes:
		for u in n.get("unlocks", []):
			if u is Dictionary and String(u.get("type", "")) == "power_cap":
				pc_found = true
		# 面向用户文本禁英文代号（AGENTS.md v6.30 纪律）——desc/name 抽查
		var txt: String = String(n.get("desc", "")) + String(n.get("name", ""))
		for code in ["ARMOR", "FORT", "FAST", "SNIPER", "ECM", "STEEL", "THUNDER",
				"VOID", "STALKER", "FLAME", "ARTILLERY", "ENGINEER"]:
			if txt.contains(code):
				bad_en.append("%s:%s" % [n.get("id"), code])
	_check(pc_found, "power_cap unlock nodes exist")
	_check(bad_en.is_empty(), "no EN codons in skill names/desc" + (str(bad_en) if not bad_en.is_empty() else ""))
	# power_cap 总览摘要条目（v6.30 前被静默跳过）
	var fake_nodes := []
	for n in nodes:
		for u in n.get("unlocks", []):
			if u is Dictionary and String(u.get("type", "")) == "power_cap":
				fake_nodes.append(String(n.get("id", "")))
	var summary: Array = UL.get_unlocked_summary(fake_nodes)
	_check(summary.size() == fake_nodes.size() and fake_nodes.size() > 0,
		"get_unlocked_summary covers power_cap (%d/%d)" % [summary.size(), fake_nodes.size()])

	# ── 4) 战法/技能 desc 作用域抽查（记录3#15：与 stat_bonus 实际作用面一致） ──
	for n in nodes:
		if String(n.get("id", "")) == "pms_fp_1a":
			_check(not String(n.get("desc", "")).contains("装甲单位"), "pms_fp_1a desc scope fixed")
		if String(n.get("id", "")) == "pms_fp_1b":
			_check(not String(n.get("desc", "")).contains("步兵单位"), "pms_fp_1b desc scope fixed")

	# ── 5) AFK 管理器：unit_died 补位函数存在（连接在 init 里，仅验证编译+签名） ──
	var afk: Script = load("res://scripts/systems/afk_mode_manager.gd")
	_check(afk.new() != null, "AFKModeManager instantiable")
	_check(afk.new().has_method("_on_unit_died_from_bus"), "AFK unit_died handler exists")

	# ── 6) spawn 系统查询口存在（依赖 autoload 不实调） ──
	var bss: Script = load("res://managers/battle/battle_spawn_system.gd")
	_check(bss.new().has_method("get_player_deployable_summary"), "deploy summary API exists")

	# ── 7) 77mm 动画资产：逐帧实心零触边（记录3#4 入库校验） ──
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/effects/unit_anims/ww1_arty_77mm/sheet_attack.png"))
	_check(img != null and img.get_width() == 3072, "77mm attack sheet 3072 wide")
	if img != null:
		var solid_touch := false
		for f in range(12):
			for x in [0, 255]:
				for y in range(img.get_height()):
					if img.get_pixel(f * 256 + x, y).a >= 0.5:
						solid_touch = true
			for y in [0, img.get_height() - 1]:
				for x in range(f * 256, f * 256 + 256):
					if img.get_pixel(x, y).a >= 0.5:
						solid_touch = true
		_check(not solid_touch, "77mm frames: no solid (a>=128) edge touch")

	print("V630_SMOKE_OK" if _fail == 0 else "V630_SMOKE_FAIL(%d)" % _fail)
	quit(1 if _fail > 0 else 0)
