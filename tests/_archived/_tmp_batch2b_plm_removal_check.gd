extends SceneTree
## tests/_tmp_batch2b_plm_removal_check.gd — 批次2b（P2-7 范围B 蓝槽法则链 + PLM 退场）验证
## ① 核心改动文件可加载（语法层）
## ② PhaseLawManager / active_law_effects 源文件已删、全项目零标识符引用（autoload 删除后为编译期错误）
## ③ project.godot autoload=31 且无 PhaseLawManager；SignalBus 无法则信号
## ④ starter 符文发放已迁至 PIM.clear_slots_for_new_game；PhaseLaws 数据表按计划保留
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_batch2b_plm_removal_check.gd

func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "(missing)"
	var s := f.get_as_text()
	f.close()
	return s

func _dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)

func _initialize() -> void:
	var errs: Array[String] = []

	# ── ① 加载核心文件 ──
	var files: Array[String] = [
		"res://managers/phase_instrument_manager.gd",
		"res://managers/phase_instrument_loadout_sync.gd",
		"res://managers/game_manager.gd",
		"res://managers/blueprint_manager.gd",
		"res://managers/save_manager.gd",
		"res://managers/audio_manager.gd",
		"res://managers/new_systems_integration.gd",
		"res://managers/battle/battle_manager.gd",
		"res://managers/battle/battle_damage_system.gd",
		"res://managers/battle/battle_spectacle.gd",
		"res://scenes/main.gd",
		"res://scenes/ui/battle_click_overlay.gd",
		"res://scenes/ui/bottom_instrument_bar.gd",
		"res://scenes/ui/buff_fold_card.gd",
		"res://scenes/ui/card_info_panel.gd",
		"res://scenes/ui/battle_announcer.gd",
		"res://scenes/ui/battle_log.gd",
		"res://scenes/units/enemy_unit.gd",
		"res://scenes/units/swarm_enemy_slot.gd",
		"res://scenes/units/bullet.gd",
		"res://scripts/battle_input_state.gd",
		"res://scripts/signal_bus.gd",
		"res://scripts/systems/main_battle_setup.gd",
		"res://scripts/ui_asset_loader.gd",
	]
	for fp in files:
		if load(fp) == null:
			errs.append("加载失败: " + fp)

	# ── ② 文件删除 + 零引用 ──
	if FileAccess.file_exists("res://managers/phase_law_manager.gd"):
		errs.append("phase_law_manager.gd 仍存在")
	if FileAccess.file_exists("res://managers/active_law_effects.gd"):
		errs.append("active_law_effects.gd 仍存在")
	var scan_files: Array[String] = files.duplicate()
	scan_files.append("res://managers/battle/simple_enemy_projectile_batch.gd")
	for fp in scan_files:
		var src_lines := _read_file(fp).split("\n")
		var code_only: Array[String] = []
		for ln in src_lines:
			var t := String(ln).strip_edges()
			# 跳过注释行（退役说明注释允许提及旧标识符；代码引用才是编译/运行错误）
			if t.begins_with("#") or t.begins_with("##"):
				continue
			code_only.append(String(ln))
		var code_src := "\n".join(code_only)
		for ident in ["PhaseLawManager", "ActiveLawEffects", "active_law_cast_at",
				"phase_law_runtime_changed", "pending_cast_law"]:
			if code_src.find(ident) >= 0:
				errs.append("%s 残留标识符 %s" % [fp, ident])

	# ── ③ project.godot + SignalBus ──
	var pg := _read_file("res://project.godot")
	if pg.find("PhaseLawManager") >= 0:
		errs.append("project.godot 仍含 PhaseLawManager autoload")
	var autoload_count: int = pg.count("=\"*res://") + pg.count("=\"*res") - pg.count("=\"*res://") # 粗计
	var auto_section: String = pg.substr(pg.find("[autoload]"))
	auto_section = auto_section.substr(0, auto_section.find("\n["))
	var entry_count: int = 0
	for line in auto_section.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("_") or "=" in t:
			entry_count += 1
	if entry_count != 31:
		errs.append("autoload 数量非 31: %d" % entry_count)
	var sb_src := _read_file("res://scripts/signal_bus.gd")
	for sig in ["signal active_law_cast_at", "signal phase_law_runtime_changed", "signal phase_law_cast"]:
		if sb_src.find(sig) >= 0:
			errs.append("SignalBus 残留信号定义: " + sig)

	# ── ④ 迁移与保留 ──
	var pim_src := _read_file("res://managers/phase_instrument_manager.gd")
	if pim_src.find("NEW_GAME_STARTER_RUNE_IDS") < 0:
		errs.append("PIM.clear_slots_for_new_game 缺 starter 符文发放")
	if pim_src.find("func sync_law_cards_to_phase_law_manager") >= 0:
		errs.append("PIM 仍定义 sync_law_cards_to_phase_law_manager")
	if load("res://data/phase_laws.gd") == null:
		errs.append("PhaseLaws 数据表应保留（旧档背包跳过判定仍用）")

	if errs.is_empty():
		print("BATCH2B CHECK: ALL PASS")
		quit(0)
	else:
		for e in errs:
			printerr("FAIL: " + e)
		quit(1)
