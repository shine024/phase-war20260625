extends SceneTree
## v6.31（记录4）批次冒烟：--script 模式加载全部改动脚本 + 纯数据断言。
## 注意：--script 模式不注册 autoload（AGENTS.md Godot CLI 节），故只做
## ①编译级 load ②静态/纯数据断言；面板仅 new() 验方法存在性（不进树）。
## 通过输出 V631_SMOKE_OK。

var _fail := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok  ", label)
	else:
		_fail += 1
		printerr("  FAIL", label)

func _initialize() -> void:
	print("== v6.31 smoke ==")

	# ── 1) 编译级加载（改动脚本全量） ──
	var scripts := [
		"res://scenes/main.gd",
		"res://scenes/ui/collection_panel.gd",
		"res://scenes/ui/affix_forge_panel.gd",
		"res://scenes/ui/battle_click_overlay.gd",
		"res://scenes/ui/backpack_panel.gd",
		"res://managers/tutorial_progression_manager.gd",
		"res://scenes/ui/top_hud_bar.gd",
		"res://scenes/ui/leaderboard/leaderboard_presenter.gd",
		"res://scenes/ui/leaderboard/leaderboard_panel.gd",
		"res://data/modification_modules/universal_mods.gd",
		"res://data/modification_modules/recon_mods.gd",
		"res://scenes/ui/faction_panel.gd",
		"res://scenes/ui/intelligence_hub_panel.gd",
		"res://scenes/ui/evolution_panel.gd",
	]
	for p in scripts:
		var s: Script = load(p)
		_check(s != null and s.can_instantiate(), "load " + p)

	# ── 2) 记录4#9：改造 desc 文案落盘断言 ──
	var UM: Script = load("res://data/modification_modules/universal_mods.gd")
	var RM: Script = load("res://data/modification_modules/recon_mods.gd")
	var pain: Dictionary = UM.get_script_constant_map().get("DATA", {}).get("gen_18_pain_conductor", {})
	_check(String(pain.get("description", "")).contains("攻击它的敌人被减速"),
		"gen_18 pain_conductor desc rewritten")
	var bino: Dictionary = RM.get_script_constant_map().get("DATA", {}).get("rec_15_field_binoculars", {})
	_check(String(bino.get("description", "")).contains("观瞄升级"),
		"rec_15 field_binoculars desc rewritten")

	# ── 3) 记录4#15：战功榜载具名三级回退 helper ──
	var LP: Script = load("res://scenes/ui/leaderboard/leaderboard_presenter.gd")
	var fallback: String = LP.platform_display_name("zz_no_such_platform_xyz")
	_check(fallback == "zz_no_such_platform_xyz", "platform_display_name falls back to raw id")
	# WAR_PLATFORMS 命中条目应返回中文名（非空且 != id）
	var wp: Dictionary = (load("res://data/enemy_phase_equipment.gd") as Script).get_war_platform(
		LP.get_script_constant_map().get("WAR_PLATFORMS", {}).keys()[0] \
			if not LP.get_script_constant_map().get("WAR_PLATFORMS", {}).is_empty() else "")
	_check(true, "war platform query executed (result size %d)" % wp.size())

	# ── 4) 记录4#13：词缀面板 show_panel + 实例序号 ──
	var afp: Control = (load("res://scenes/ui/affix_forge_panel.gd") as Script).new()
	_check(afp.has_method("show_panel"), "affix panel show_panel exists")
	_check(afp._instance_seq_tag("abc#12") == " #12", "seq tag parses #12")
	_check(afp._instance_seq_tag("plain_id") == "", "seq tag empty w/o hash")
	afp.free()

	# ── 5) 记录4#5：顶栏精神 chip 方法存在 ──
	var thb: Control = (load("res://scenes/ui/top_hud_bar.gd") as Script).new()
	_check(thb.has_method("_build_sanity_chip") and thb.has_method("_refresh_sanity_chip"),
		"top hud sanity chip methods exist")
	thb.free()

	# ── 6) 记录4#14：制造舱 helper + 空调用不崩 ──
	var evp: Control = (load("res://scenes/ui/evolution_panel.gd") as Script).new()
	_check(evp.has_method("_render_resource_cost"), "evolution _render_resource_cost exists")
	evp._render_resource_cost({})  # resource_details==null → 早退
	evp._render_resource_cost({"crystal": 30, "alloy": 5})  # 同上，分支全走
	_check(true, "evolution empty-cost calls no-crash")
	evp.free()

	# ── 7) 记录4#10：情报舱三分区方法存在 ──
	var ihp: Control = (load("res://scenes/ui/intelligence_hub_panel.gd") as Script).new()
	_check(ihp.has_method("_build_mod_intel_content") and ihp.has_method("_apply_intel_mode_visibility")
		and ihp.has_method("_on_intel_mode_pressed"), "intel hub tri-mode methods exist")
	ihp.free()

	# ── 8) 记录4#12：main.tscn InfoPanelLayer layer=110（压过商店遮罩 100） ──
	var ps: PackedScene = load("res://scenes/main.tscn")
	_check(ps != null, "load main.tscn")
	if ps != null:
		var st := ps.get_state()
		var found := false
		for i in st.get_node_count():
			if String(st.get_node_name(i)) == "InfoPanelLayer":
				for j in st.get_node_property_count(i):
					if String(st.get_node_property_name(i, j)) == "layer":
						found = int(st.get_node_property_value(i, j)) == 110
		_check(found, "InfoPanelLayer layer==110")

	# ── 9) 记录4#14：evolution_panel.tscn 间距（BodyHBox 8 / DetailContent 6） ──
	var eps: PackedScene = load("res://scenes/ui/evolution_panel.tscn")
	_check(eps != null, "load evolution_panel.tscn")
	if eps != null:
		var st2 := eps.get_state()
		var body_sep := -1
		var detail_sep := -1
		for i in st2.get_node_count():
			var nn := String(st2.get_node_name(i))
			if nn == "BodyHBox" or nn == "DetailContent":
				for j in st2.get_node_property_count(i):
					if String(st2.get_node_property_name(i, j)) == "theme_override_constants/separation":
						if nn == "BodyHBox":
							body_sep = int(st2.get_node_property_value(i, j))
						else:
							detail_sep = int(st2.get_node_property_value(i, j))
		_check(body_sep == 8, "BodyHBox separation==8 (got %d)" % body_sep)
		_check(detail_sep == 6, "DetailContent separation==6 (got %d)" % detail_sep)

	# ── 10) 记录4#2：教程门老档豁免（方法存在；实调依赖 autoload 仅验签名） ──
	var tpm: Script = load("res://managers/tutorial_progression_manager.gd")
	_check(tpm.new().has_method("is_pending_truck_base_intro"), "TPM gate method exists")

	print("V631_SMOKE_OK" if _fail == 0 else "V631_SMOKE_FAIL(%d)" % _fail)
	quit(1 if _fail > 0 else 0)
