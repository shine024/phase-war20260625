extends SceneTree
## 2026-08-22 UI 整体优化批次二（A+B+C）验证脚本（--script 模式）
## 用法：godot --headless --rendering-driver opengl3 --path . --script tests/ui_batch2_validation.gd
##
## 覆盖：本批次改动文件编译加载 + 关键改动的源码/运行时断言。
## 注：引用 autoload 的文件在 --script 模式必然编译失败（环境限制非错误），源码扫描兜底。

const FILES: Array[String] = [
	# Phase A
	"res://scenes/ui/mvp_panel.gd",
	"res://scenes/ui/backpack_card_item_drag.gd",
	"res://scenes/ui/instrument_bar_drag.gd",
	"res://scenes/ui/afk_panel.gd",
	"res://scenes/ui/afk_level_selector.gd",
	"res://scenes/ui/afk_settlement_dialog.gd",
	"res://scenes/ui/feature_unlock_popup.gd",
	"res://scenes/ui/card_info_panel.gd",
	"res://scenes/ui/phase_instrument_selector.gd",
	"res://scenes/ui/growth_panel.gd",
	"res://scenes/ui/offline_reward_dialog.gd",
	"res://scenes/main.gd",
	# Phase B
	"res://scenes/ui/bottom_instrument_bar.gd",
	"res://scenes/ui/resource_slot_item.gd",
	"res://scenes/ui/evolution_atlas_view.gd",
	"res://scenes/ui/backpack/backpack_presenter.gd",
	"res://scenes/ui/phase_master_skill_panel.gd",
	"res://scenes/ui/backpack_panel.gd",
	# Phase C
	"res://resources/design_tokens.gd",
	"res://scenes/ui/resource_bar.gd",
	"res://scenes/ui/resource_info_panel.gd",
	"res://scenes/ui/buff_fold_card.gd",
	"res://scenes/ui/battle_hud.gd",
	"res://scenes/ui/bottom_function_bar.gd",
	"res://scenes/ui/top_hud_bar.gd",
	"res://scenes/ui/leaderboard/faction_row.gd",
	"res://scenes/ui/leaderboard/enemy_row.gd",
	"res://scenes/ui/leaderboard/player_row.gd",
	"res://scenes/ui/evolution_panel.gd",
	"res://scenes/ui/intel_reveal_popup.gd",
	"res://scenes/ui/help_panel.gd",
	"res://scenes/ui/backpack_card_item.gd",
	"res://scenes/ui/modification_panel.gd",
	"res://scenes/effects/damage_number_display.gd",
	"res://scenes/ui/achievement_panel.gd",
	"res://scenes/ui/intel_harvest_display.gd",
	"res://resources/default_theme.tres",
	# Phase D
	"res://scenes/ui/leaderboard/leaderboard_panel.gd",
	"res://scenes/ui/leaderboard/leaderboard_presenter.gd",
	"res://scenes/ui/leaderboard/leaderboard_detail_builders.gd",
	"res://scenes/ui/leaderboard/faction_row.gd",
]

const AUTOLOAD_NAMES: Array[String] = [
	"SignalBus", "BattleManager", "GameManager", "PhaseInstrumentManager", "EnergyManager",
	"ManagerLazyLoader", "SaveManager", "AudioManager", "InstanceRegistry", "PhaseMasterSkillManager",
	"BattleInputState", "BasicResourceManager",
]

var _fails: Array[String] = []
var _skipped: Array[String] = []


func _init() -> void:
	_check_compile_all()
	_check_a_assertions()
	_check_c_assertions()
	_check_d_assertions()
	_report()
	quit(0 if _fails.is_empty() else 1)


func _src(path: String) -> String:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		_fails.append("无法读取: %s" % path)
		return ""
	var t := fa.get_as_text()
	fa.close()
	return t


func _check_compile_all() -> void:
	for sp in FILES:
		var s: Resource = load(sp)
		if s != null:
			continue
		var source := _src(sp)
		if source.is_empty():
			continue
		var refs := false
		for name in AUTOLOAD_NAMES:
			if source.contains(name):
				refs = true
				break
		if refs:
			_skipped.append(sp)
		else:
			_fails.append("编译失败: %s" % sp)


## Phase A 断言
func _check_a_assertions() -> void:
	# A1: mvp uncommon 键
	var mvp := _src("res://scenes/ui/mvp_panel.gd")
	if not mvp.contains('"uncommon": return DT.COLOR_RARITY_UNCOMMON'):
		_fails.append("A1: mvp_panel uncommon 色键缺失")
	if not mvp.contains('"uncommon": return "优秀"'):
		_fails.append("A1: mvp_panel uncommon 名字键缺失")
	# A2: 公共校验函数 + 红绿反馈
	var ibd := _src("res://scenes/ui/instrument_bar_drag.gd")
	if not ibd.contains("static func card_matches_slot_color"):
		_fails.append("A2: card_matches_slot_color 未抽出")
	var bcd := _src("res://scenes/ui/backpack_card_item_drag.gd")
	if not bcd.contains("card_matches_slot_color"):
		_fails.append("A2: 背包拖拽未接入公共校验")
	if not bcd.contains("can_place: bool"):
		_fails.append("A2: 悬停校验变量缺失")
	# A2 语义：纯逻辑函数运行时验证（仅当脚本在本模式可实例化——无 autoload 依赖）
	var drag: GDScript = load("res://scenes/ui/instrument_bar_drag.gd")
	if drag != null and drag.can_instantiate():
		var GC = load("res://resources/game_constants.gd")
		var inst = drag.new()
		var card := CardResource.new()
		card.card_type = GC.CardType.COMBAT_UNIT
		if not inst.card_matches_slot_color(card, "green"):
			_fails.append("A2: 战斗卡应可放绿槽")
		if inst.card_matches_slot_color(card, "red"):
			_fails.append("A2: 战斗卡不应可放红槽")
		if inst.card_matches_slot_color(card, "rune"):
			_fails.append("A2: 卡牌不应可放符文槽")
	# A3: ESC consume 与新增处理
	for pair in [
		["res://scenes/ui/afk_panel.gd", "set_input_as_handled"],
		["res://scenes/ui/afk_level_selector.gd", "set_input_as_handled"],
		["res://scenes/ui/afk_settlement_dialog.gd", "set_input_as_handled"],
		["res://scenes/ui/feature_unlock_popup.gd", "func _input("],
		["res://scenes/ui/card_info_panel.gd", "func _input("],
		["res://scenes/ui/phase_instrument_selector.gd", "func _input("],
		["res://scenes/ui/growth_panel.gd", "func _input("],
		["res://scenes/ui/offline_reward_dialog.gd", "func _input("],
		["res://scenes/main.gd", "_retreat_confirm.queue_free()"],
	]:
		var src := _src(pair[0])
		if not src.contains(pair[1]):
			_fails.append("A3: %s 缺少 %s" % [pair[0], pair[1]])
	# A4: 装备失败反馈
	var pis := _src("res://scenes/ui/phase_instrument_selector.gd")
	if not pis.contains("装备失败：该相位仪当前无法装备"):
		_fails.append("A4: 相位仪装备失败 toast 缺失")


## Phase C 断言
func _check_c_assertions() -> void:
	# C2: DT 新 token
	var dt: GDScript = load("res://resources/design_tokens.gd")
	if dt == null:
		_fails.append("C2: design_tokens 编译失败")
	else:
		var dt_src := _src("res://resources/design_tokens.gd")
		for tok in ["COLOR_RES_ENERGY", "COLOR_RES_NANO", "COLOR_RES_RESEARCH", "COLOR_RES_ALLOY",
				"COLOR_RES_CRYSTAL", "MOTION_FADE_IN", "MOTION_FADE_OUT", "MOTION_POP",
				'"help"', '"player_master"', '"phase_master_skill"', '"mvp"', '"backpack"']:
			if not dt_src.contains(tok):
				_fails.append("C2: DT 缺少 %s" % tok)
	# C2 运行时：token 值可取
	if dt != null:
		if absf(dt.MOTION_FADE_IN - 0.2) > 0.001 or absf(dt.MOTION_POP - 0.25) > 0.001:
			_fails.append("C2: MOTION_* 值异常")
	# C1: 稀有度本地副本已删
	for pair in [
		["res://scenes/ui/growth_panel.gd", "return GC.get_rarity_color(rarity)"],
		["res://scenes/ui/resource_slot_item.gd", "return GC.get_rarity_color(rarity)"],
		["res://scenes/ui/backpack_card_item.gd", "return GC.get_rarity_color(rarity)"],
	]:
		var src := _src(pair[0])
		if not src.contains(pair[1]):
			_fails.append("C1: %s 未透传 GC.get_rarity_color" % pair[0])
		if src.contains("Color(0.420, 0.463, 0.569"):
			_fails.append("C1: %s 仍有稀有度手抄色值" % pair[0])
	# C4: 高饱和已收敛
	if _src("res://scenes/ui/battle_hud.gd").contains("Color(0, 1, 1"):
		_fails.append("C4: battle_hud 仍有纯青")
	for f in ["res://scenes/ui/leaderboard/faction_row.gd", "res://scenes/ui/leaderboard/enemy_row.gd",
			"res://scenes/ui/leaderboard/player_row.gd"]:
		if _src(f).contains("0.843, 0.0"):
			_fails.append("C4: %s 仍有 #FFD700 纯金" % f)
	# C3: 字号扫描（11px 归零），纯 GDScript 计数（bash 输出在 Windows 有编码问题）
	var scan_targets: Array[String] = []
	for dir in ["res://scenes/ui/", "res://scenes/", "res://scripts/"]:
		var dir_access := DirAccess.open(dir)
		if dir_access == null:
			continue
		dir_access.list_dir_begin()
		var fname := dir_access.get_next()
		while not fname.is_empty():
			if fname.ends_with(".gd") or fname.ends_with(".tscn"):
				scan_targets.append(dir + fname)
			fname = dir_access.get_next()
		dir_access.list_dir_end()
	# ui 子目录递归（单层即可覆盖 scenes/ui）
	var ui_dir := DirAccess.open("res://scenes/ui/")
	if ui_dir != null:
		ui_dir.list_dir_begin()
		var sub := ui_dir.get_next()
		while not sub.is_empty():
			if ui_dir.current_is_dir() and not sub.begins_with("."):
				var sub_access := DirAccess.open("res://scenes/ui/" + sub + "/")
				if sub_access != null:
					sub_access.list_dir_begin()
					var f2 := sub_access.get_next()
					while not f2.is_empty():
						if f2.ends_with(".gd") or f2.ends_with(".tscn"):
							scan_targets.append("res://scenes/ui/" + sub + "/" + f2)
						f2 = sub_access.get_next()
					sub_access.list_dir_end()
			sub = ui_dir.get_next()
		ui_dir.list_dir_end()
	var residue: Array[String] = []
	for sp in scan_targets:
		var content := _src(sp)
		if content.is_empty():
			continue
		if content.count('add_theme_font_size_override("font_size", 11)') > 0 \
				or content.count('add_theme_font_size_override("normal_font_size", 11)') > 0 \
				or content.count("theme_override_font_sizes/font_size = 11\n") > 0:
			residue.append(sp)
	if not residue.is_empty():
		_fails.append("C3: 仍有 11px 字号残留: " + ", ".join(residue))
	# C3: 中文 10px 三个重灾区归零（其余处纯数字 10px 允许）
	for f in ["res://scenes/ui/backpack_panel.gd", "res://scenes/ui/phase_instrument_selector.gd",
			"res://scenes/ui/leaderboard/leaderboard_panel.gd"]:
		var n10: int = _src(f).count('add_theme_font_size_override("font_size", 10)')
		if n10 > 0:
			_fails.append("C3: 中文10px未清零: %s x%d" % [f, n10])
	# 死 preload 清理
	for f in ["res://scenes/ui/backpack_card_item.gd", "res://scenes/ui/backpack/backpack_presenter.gd",
			"res://scenes/ui/modification_panel.gd"]:
		if _src(f).contains("blueprint_star_config"):
			_fails.append("清理: %s 仍 preload 已删除的 blueprint_star_config" % f)


## Phase D 断言
func _check_d_assertions() -> void:
	# D1: 四面板根框架走工厂
	for pair in [
		["res://scenes/ui/growth_panel.gd", "make_panel_frame(DT.get_system_color(\"growth\"))"],
		["res://scenes/ui/evolution_panel.gd", "make_panel_frame(DT.COLOR_VIOLET)"],
		["res://scenes/ui/modification_panel.gd", "make_panel_frame(DT.get_system_color(\"modify\"))"],
		["res://scenes/ui/backpack_panel.gd", "make_panel_frame(DesignTokens.get_panel_accent(\"backpack\"))"],
	]:
		if not _src(pair[0]).contains(pair[1]):
			_fails.append("D1: %s 根框架未走工厂" % pair[0])
	# D2: 排行榜构建器委托
	var lb_panel := _src("res://scenes/ui/leaderboard/leaderboard_panel.gd")
	var lb_pres := _src("res://scenes/ui/leaderboard/leaderboard_presenter.gd")
	for f in [lb_panel, lb_pres]:
		if not f.contains("return LeaderboardDetailBuilders.make_stat_label"):
			_fails.append("D2: 排行榜未委托共享构建器")
	if not lb_panel.contains("LeaderboardDetailBuilders.translate_special_tag"):
		_fails.append("D2: panel 装备标签未汉化")
	var builders: GDScript = load("res://scenes/ui/leaderboard/leaderboard_detail_builders.gd")
	if builders == null:
		_fails.append("D2: leaderboard_detail_builders 编译失败")
	# D3: 成就/帮助入口 + 死 overlay 删除
	var main_src := _src("res://scenes/main.gd")
	for needle in ["btn_achievement_pressed.connect(_on_achievement_pressed)",
			"btn_help_pressed.connect(_on_help_pressed)",
			'"achievement": return achievement_overlay',
			'{"overlay": achievement_overlay, "key": "achievement"}',
			'{"overlay": help_overlay, "key": "help"}']:
		if not main_src.contains(needle):
			_fails.append("D3: main.gd 缺少 %s" % needle)
	# D3: enhancement_overlay 活代码残留（注释中的历史说明不算）
	if main_src.contains("var enhancement_overlay") or main_src.contains("(enhancement_overlay") \
			or main_src.contains("enhancement_overlay,"):
		_fails.append("D3: enhancement_overlay 残留")
	var bar_src := _src("res://scenes/ui/bottom_function_bar.gd")
	if not bar_src.contains('["achievement",  "成就"') and not bar_src.contains('["achievement", "成就"'):
		_fails.append("D3: 功能栏无成就按钮")
	if not bar_src.contains('"帮助"'):
		_fails.append("D3: 功能栏无帮助按钮")
	var tscn_src := _src("res://scenes/main.tscn")
	if tscn_src.contains("EnhancementOverlay") or tscn_src.contains("DropsInventoryOverlay"):
		_fails.append("D3: main.tscn 死 overlay 残留")
	# D3: 原生 DnD 死链删除
	var drag_src := _src("res://scenes/ui/instrument_bar_drag.gd")
	if drag_src.contains("func can_drop_data") or drag_src.contains("func drop_data"):
		_fails.append("D3: instrument_bar_drag 死 DnD 残留")
	if not _src("res://scenes/ui/bottom_instrument_bar.gd").contains("_slot_to_flat_index"):
		_fails.append("D3: 误删活代码 _slot_to_flat_index")


func _report() -> void:
	if _fails.is_empty():
		print("[UI-BATCH2-VALIDATION] ALL PASS — %d files compiled/loaded, %d skipped(autoload-dep)" % [
			FILES.size() - _skipped.size(), _skipped.size()])
		for sp in _skipped:
			print("  ↷ skip: %s" % sp)
	else:
		print("[UI-BATCH2-VALIDATION] FAILED x%d:" % _fails.size())
		for f in _fails:
			print("  ✗ %s" % f)
		for sp in _skipped:
			print("  ↷ skip: %s" % sp)
