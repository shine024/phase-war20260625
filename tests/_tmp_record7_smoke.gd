extends SceneTree
## 记录7（v6.24）修复批冒烟：改动脚本可编译 + 关键新符号存在。
## 跑法：godot --headless --script tests/_tmp_record7_smoke.gd（成功尾行 RECORD7_SMOKE_OK）

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail += 1
		push_error("[SMOKE FAIL] " + msg)
	else:
		print("  ok - ", msg)

func _initialize() -> void:
	print("== 记录7 冒烟 ==")
	# ── 可编译性（加载即编译）──
	var files := [
		"res://scenes/ui/bottom_instrument_bar.gd",
		"res://scenes/bunker/truck_base.gd",
		"res://scripts/node_finder.gd",
		"res://scenes/ui/unit_hover_info.gd",
		"res://scenes/ui/battle_click_overlay.gd",
		"res://scenes/ui/card_info_panel.gd",
		"res://managers/toast_manager.gd",
		"res://scenes/ui/resource_slot_item.gd",
		"res://scenes/ui/backpack_panel.gd",
		"res://scenes/ui/backpack/backpack_presenter.gd",
		"res://scenes/ui/afk_panel.gd",
		"res://scenes/world_map.gd",
		"res://managers/battle/simple_enemy_projectile_batch.gd",
		"res://managers/battle/simple_player_projectile_batch.gd",
		"res://scenes/units/bullet.gd",
		"res://scenes/ui/auto_deploy_controller.gd",
		"res://managers/battle/phase_instrument_abilities.gd",
		"res://managers/affix_manager.gd",
		"res://managers/phase_instrument_manager.gd",
		"res://managers/card_ability_manager.gd",
		"res://resources/unit_stats_table.gd",
		"res://scenes/units/construct_unit.gd",
		"res://managers/battle/battle_spawn_system.gd",
		"res://scripts/card_grid_unit_visuals.gd",
		"res://scripts/battle/fort_shield_aura.gd",
	]
	for f in files:
		var s: Script = load(f)
		_check(s != null, "可编译: " + f)

	# ── 关键符号 ──
	var nf: Script = load("res://scripts/node_finder.gd")
	_check(nf.get_script_method_list().any(func(m): return String(m["name"]) == "get_card_info_panel"),
		"NodeFinder.get_card_info_panel 存在")
	var toast: Script = load("res://managers/toast_manager.gd")
	_check(toast.get_script_method_list().any(func(m): return String(m["name"]) == "_apply_toast_anchor"),
		"ToastManager 战斗锚点切换存在")
	var pres: Script = load("res://scenes/ui/backpack/backpack_presenter.gd")
	_check(pres.get_script_method_list().any(func(m): return String(m["name"]) == "_compute_grid_signature"),
		"presenter 网格签名存在")
	# world_map 已揭示集（static var 无法直接反射，脚本级常量/源码断言兜底）
	var wm_src := FileAccess.get_file_as_string("res://scenes/world_map.gd")
	_check(wm_src.contains("_s_revealed_levels"), "world_map 已揭示集存在")
	_check(wm_src.contains("_refresh_enter_btn_label"), "world_map 出击键文案刷新存在")
	var bib_src := FileAccess.get_file_as_string("res://scenes/ui/bottom_instrument_bar.gd")
	_check(bib_src.contains("remove_meta(\"deploy_tooltip_base\")"), "deploy_tooltip_base 缓存失效存在")
	_check(bib_src.contains("_fit_count >= 2"), "格子揭示门第二次 fit 判据存在")
	var pia_src := FileAccess.get_file_as_string("res://managers/battle/phase_instrument_abilities.gd")
	_check(pia_src.contains("\"vertical\""), "核武轰炸 vertical 天降弹道")
	_check(not pia_src.contains("\"high_arc\""), "核武轰炸旧 high_arc 已移除")
	# 减伤帽统一
	var ust_src := FileAccess.get_file_as_string("res://resources/unit_stats_table.gd")
	_check(ust_src.contains("minf(0.60, stats.damage_reduction"), "unit_stats_table 减伤帽 0.60")
	var cu_src := FileAccess.get_file_as_string("res://scenes/units/construct_unit.gd")
	_check(cu_src.contains("clampf(stats.damage_reduction + bonus, 0.0, 0.6)"), "construct_unit 减伤帽 0.60")
	# 资产朝向翻正备份存在
	_check(FileAccess.file_exists("res://.godot/art_backup_facing_fix_20260924/cold_inf_spetsnaz_e/attack_f0.png"),
		"attack_f0 翻正备份落盘")
	_check(FileAccess.file_exists("res://.godot/art_backup_whitebg_20260924/enemy_master_010.png"),
		"相位师白底备份落盘")

	if _fail == 0:
		print("RECORD7_SMOKE_OK")
	else:
		print("RECORD7_SMOKE_FAIL fails=", _fail)
	quit(1 if _fail > 0 else 0)
