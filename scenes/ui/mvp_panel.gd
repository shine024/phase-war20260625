extends Control
## v7.x 整合结算面板（MVP 战绩 + 奖励明细合并）
##
## 战斗结束瞬间一次性弹出，展示完整结算：
##   上半区：战绩横幅（胜利/失败 + 时长 + 星级 + 核心数据 + 击杀分布）
##   下半区：奖励明细（本关获得 / 相位场经验 / 战斗掉落 / 相位仪掉落 / 情报揭示）
##
## 合并自原 mvp_panel + battle_result_dialog，消除"两次弹窗 + 切换动画"割裂感。
##
## 内容（团队 MVP，不做 per-unit——普通单位伤害走 CombatFeedback 直调不经过 SignalBus，无法准确采集）：
##   - 战绩横幅（胜利/失败 + 时长）
##   - 核心数据（击毁 X · 损失 Y · 伤害 Z）
##   - 击杀类型（前 3 类敌人，来自 BattleManager._defeated_enemies）
##   - 星级评定（★1~3，基于击杀比/损失比/时长）
##   - 奖励摘要（能量块/纳米材料/卡牌副本）
##   - 相位场经验结算
##   - 战斗掉落列表（DropManager 待领取）
##   - 相位仪掉落（独立展示）
##   - 情报揭示（IntelHarvestDisplay + IntelRevealPopup）
##   - 关闭按钮 → 领取全部 + 返回准备界面
##
## 数据来源：BattleInfoDisplay.get_battle_stats() + BattleManager._defeated_enemies + GameManager.last_battle_reward_summary

const DT = preload("res://resources/design_tokens.gd")
const GC = preload("res://resources/game_constants.gd")   # v23.6.1 稀有度色单一源
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")   # v23.6.1 按钮工厂
const DefaultCards = preload("res://data/default_cards.gd")
const FormatUtil = preload("res://scripts/ui/format_util.gd")
const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")   # v22.4 要塞反馈行

signal result_confirmed(player_won: bool)

## v22.4（P0-2）：从基地出击时，结算面板提供"返回基地"直达按钮
var _bunker_return_available := false


static func create(parent: Node, player_won: bool, blueprints: Array, \
		phase_field_xp_before: int, phase_field_level_before: int, \
		reward_summary: Dictionary, is_afk: bool = false) -> Control:
	var panel: Control = load("res://scenes/ui/mvp_panel.tscn").instantiate()
	panel.player_won = player_won
	panel._blueprints = blueprints
	panel._xp_before = phase_field_xp_before
	panel._level_before = phase_field_level_before
	panel._reward_summary = reward_summary
	panel._is_afk = is_afk
	parent.add_child(panel)
	panel._build()
	return panel


var player_won: bool = true
var _blueprints: Array = []
var _xp_before: int = 0
var _level_before: int = 0
var _reward_summary: Dictionary = {}
var _is_afk: bool = false
# 星级 Label 引用，供逐个亮起动画使用
var _star_lbl: Label = null


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP


func _build() -> void:
	# 关键：自带 CanvasLayer（layer=200），渲染层级高于 HudLayer(40)/InfoPanelLayer(90)/PopupLayer(100)。
	# 否则面板加到 main（layer=0）会被相位仪底栏（HudLayer 40）盖住底部按钮。
	# 面板节点仍加到 main（保持 _on_continue_pressed → parent._on_result_confirmed 调用链），
	# 但视觉上通过这个 CanvasLayer 提升到最顶层。
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "MvpPanelOverlay"
	overlay_layer.layer = 200
	add_child(overlay_layer)
	# 背景遮罩（放在 overlay_layer 内，确保遮罩也在最顶层）
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(backdrop)
	# 主面板：用普通 Panel（非 Container），纯 anchors 固定到屏幕中央留边区域。
	# 关键：不能用 PanelContainer/VBoxContainer——Container 会按子节点 minimum_size
	# 自动撑大自己，ScrollContainer 的内容高度会传上来把面板顶出屏幕。
	# Panel 不参与 minimum_size 传播，offset 锚定的边界就是面板的真实边界，绝不会被撑开。
	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	# 居中面板：宽 920（左右各 460），高 600（上下各 300），1280×720 屏幕内留足边距
	panel.offset_left = -460
	panel.offset_right = 460
	panel.offset_top = -300
	panel.offset_bottom = 300
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(panel)
	# 面板样式
	var style := StyleBoxFlat.new()
	if player_won:
		style.bg_color = Color(0.04, 0.12, 0.10, 0.98)
		style.border_color = Color(0.0, 0.9, 0.7, 0.8)
		style.shadow_color = Color(0.0, 0.9, 0.7, 0.3)
	else:
		style.bg_color = Color(0.14, 0.04, 0.04, 0.98)
		style.border_color = Color(0.9, 0.2, 0.2, 0.8)
		style.shadow_color = Color(0.9, 0.2, 0.2, 0.3)
	style.corner_radius_top_left = DT.CORNER_RADIUS
	style.corner_radius_top_right = DT.CORNER_RADIUS
	style.corner_radius_bottom_right = DT.CORNER_RADIUS
	style.corner_radius_bottom_left = DT.CORNER_RADIUS
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)

	# ═══ 可滚动内容区：anchors 钉在面板上半部（留出底部 60px 给按钮） ═══
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 20.0        # 左内边距
	scroll.offset_right = -20.0      # 右内边距
	scroll.offset_top = 16.0         # 上内边距
	scroll.offset_bottom = -70.0     # 底部留 70px 给按钮区（按钮高44 + 分隔 + margin）
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# 关键：设为 0，防止 ScrollContainer 用内容高度作为自身 min_size 顶开按钮
	scroll.custom_minimum_size = Vector2(0, 0)
	panel.add_child(scroll)
	# 内容列（所有可滚动内容放这里）
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ═══ 战绩区域（挂机模式跳过） ═══
	if not _is_afk:
		_render_victory_banner(vbox)
		_render_battle_stats(vbox)
		# v27: 败因分析——失败要产出知识（残存敌军构成 + 克制建议 + 情报提示）
		if not player_won:
			_render_defeat_analysis(vbox)

	# ═══ 奖励明细区域 ═══
	_render_phase_field_xp(vbox)
	if player_won:
		_render_reward_summary(vbox)
	_render_intel_harvest(vbox)
	if player_won:
		_render_drops(vbox)
		_render_phase_instrument_drop(vbox)
		# v7.x 胜利面板漏显修复：本局缴获与战利品（战中击杀卡/符文/相位师全部奖励）
		_render_collected_rewards(vbox)
	# v22.4（P0-2）：要塞反馈行——修复进度/精神/回基地入口（未进过基地的玩家不显示）
	_render_bunker_status(vbox)

	# ═══ 二周目入口（v26.6 断链补链：start_ng_plus 此前零入口） ═══
	_render_ng_plus_entry(vbox)

	# ═══ 关闭按钮：anchors 钉在面板底部，永远可见 ═══
	_render_close_button_anchored(panel)

	# 整体淡入（panel 是 Control，有 modulate；CanvasLayer 没有 modulate 属性）
	# C7: 时长走 DT.MOTION_FADE_IN + SINE（原 0.3 裸 linear，与全项目弹窗节奏不一致）
	panel.modulate.a = 0.0
	if not DT.is_motion_reduce():
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "modulate:a", 1.0, DT.MOTION_FADE_IN)

	# 星级逐个亮起动画（胜利时）
	if not _is_afk and player_won and _star_lbl != null:
		_animate_stars()


# =========================================================================
#  战绩区域
# =========================================================================

func _render_victory_banner(vbox: VBoxContainer) -> void:
	# 战绩横幅（大标题）
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_ls := LabelSettings.new()
	if player_won:
		title.text = "✓ 胜  利"
		title_ls.font_color = DT.COLOR_GOLD
		title_ls.font_size = DT.FONT_SIZE_HUGE
	else:
		title.text = "✗ 失  败"
		title_ls.font_color = Color(1, 0.3, 0.3, 1)
		title_ls.font_size = DT.FONT_SIZE_TITLE
	title_ls.outline_color = Color(0, 0, 0, 0.85)
	title_ls.outline_size = 4
	title.label_settings = title_ls
	vbox.add_child(title)
	# 副标题描述
	var desc := Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.text = "任务完成！前进到下一战区。" if player_won else "阵地失守…重新整备后再战。"
	desc.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	desc.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	vbox.add_child(desc)


func _render_battle_stats(vbox: VBoxContainer) -> void:
	var stats: Dictionary = _collect_stats()
	# 战斗时长 + 星级（同一行）
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 32)
	vbox.add_child(top_row)
	# 时长
	var time_lbl := Label.new()
	time_lbl.text = "战斗时长  %s" % _format_time(stats.get("battle_time", 0.0))
	time_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	time_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	time_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(time_lbl)
	# 星级
	var stars: int = _compute_stars(stats)
	_star_lbl = Label.new()
	_star_lbl.text = _star_text(stars)
	_star_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE)
	_star_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD if stars >= 2 else DT.COLOR_TEXT_DIM)
	_star_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(_star_lbl)

	# 核心数据网格
	vbox.add_child(_make_separator())
	var data_grid := GridContainer.new()
	data_grid.columns = 2
	data_grid.add_theme_constant_override("h_separation", 32)
	data_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(data_grid)
	_add_data_row(data_grid, "击毁敌方", str(stats.get("enemy_kills", 0)), DT.COLOR_GREEN_BRIGHT)
	_add_data_row(data_grid, "我方损失", str(stats.get("player_kills", 0)), DT.COLOR_DANGER)
	_add_data_row(data_grid, "造成伤害", FormatUtil.format_thousands(int(stats.get("damage_dealt", 0))), DT.COLOR_ACCENT_CYAN)
	_add_data_row(data_grid, "承受伤害", FormatUtil.format_thousands(int(stats.get("damage_taken", 0))), DT.COLOR_ENERGY)

	# 击杀类型分布
	var kill_breakdown := _kill_type_breakdown()
	if not kill_breakdown.is_empty():
		var kb_lbl := Label.new()
		kb_lbl.text = "击破分布"
		kb_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		kb_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		kb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(kb_lbl)
		var kb_val := Label.new()
		kb_val.text = ", ".join(kill_breakdown)
		kb_val.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		kb_val.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		kb_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(kb_val)


# =========================================================================
#  奖励明细区域
# =========================================================================

func _render_phase_field_xp(vbox: VBoxContainer) -> void:
	var pim: Node = Engine.get_main_loop().root.get_node_or_null("PhaseInstrumentManager")
	if pim == null or not pim.has_method("get_phase_field_xp_progress"):
		return
	var phase_prog: Dictionary = pim.get_phase_field_xp_progress()
	var phase_xp_after: int = int(phase_prog.get("xp", 0))
	var phase_level_after: int = int(phase_prog.get("level", 1))
	var phase_xp_gain: int = max(0, phase_xp_after - _xp_before)
	var phase_info := Label.new()
	phase_info.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	phase_info.add_theme_color_override("font_color", Color(DT.COLOR_CYAN_TECH.r, DT.COLOR_CYAN_TECH.g, DT.COLOR_CYAN_TECH.b, 0.95))
	if player_won:
		var lv_up_text: String = ""
		if phase_level_after > _level_before:
			lv_up_text = "  (Lv.%d → Lv.%d)" % [_level_before, phase_level_after]
		phase_info.text = "相位场经验 +%d%s" % [phase_xp_gain, lv_up_text]
	else:
		phase_info.text = "相位场经验 +0"
	vbox.add_child(phase_info)


func _render_reward_summary(vbox: VBoxContainer) -> void:
	if _reward_summary.is_empty():
		return
	var reward_sep := HSeparator.new()
	reward_sep.add_theme_color_override("color", Color(0, 0.9, 0.7, 0.25))
	vbox.add_child(reward_sep)
	var reward_title := Label.new()
	reward_title.text = "◆ 本关获得"
	reward_title.add_theme_font_size_override("font_size", 13)
	reward_title.add_theme_color_override("font_color", DT.COLOR_GREEN_BRIGHT)
	vbox.add_child(reward_title)
	var reward_list := VBoxContainer.new()
	reward_list.add_theme_constant_override("separation", 3)
	# 扫描 pending drops 中已汇总的 MATERIAL 资源，合并到顶部显示（避免与掉落列表重复）
	ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
	var dm_for_summary: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
	var pending_mats: Dictionary = _summarize_pending_materials(dm_for_summary)
	var energy_gain: int = int(_reward_summary.get("energy_block_gain", 0)) + int(pending_mats.get("energy_block", 0))
	# 纳米材料统一显示一行（固定关卡奖励 + 随机掉落，合并总量）
	var basic_nano_gain: int = int(_reward_summary.get("basic_nano_gain", 0)) + int(pending_mats.get("nano_materials", 0))
	var fragment_gain_total: int = int(_reward_summary.get("fragment_gain_total", 0))
	var recon_bonus_percent: int = int(_reward_summary.get("recon_fragment_bonus_percent", 0))
	var reward_lines: Array[String] = [
		"  ▸ 能量块 +%d" % energy_gain,
		"  ▸ 纳米材料 +%d" % basic_nano_gain,
		"  ▸ 卡牌副本 +%d（侦查加成 %+d%%）" % [fragment_gain_total, recon_bonus_percent],
		]
	for line_text in reward_lines:
		var reward_lbl := Label.new()
		reward_lbl.text = line_text
		reward_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		reward_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		reward_list.add_child(reward_lbl)
	vbox.add_child(reward_list)


func _render_intel_harvest(vbox: VBoxContainer) -> void:
	var intel_harvest: Dictionary = _reward_summary.get("intel_harvest", {})
	if intel_harvest.is_empty():
		return
	var intel_sep := HSeparator.new()
	intel_sep.add_theme_color_override("color", Color(DT.COLOR_VIOLET.r, DT.COLOR_VIOLET.g, DT.COLOR_VIOLET.b, 0.25))
	vbox.add_child(intel_sep)
	var IHD = preload("res://scenes/ui/intel_harvest_display.gd")
	var harvest_ui = IHD.new()
	harvest_ui.set_data(intel_harvest)
	vbox.add_child(harvest_ui)
	# 有新揭示事件时，延迟弹出 IntelRevealPopup 精致展示
	var reveal_events: Array = intel_harvest.get("reveal_events", [])
	if not reveal_events.is_empty():
		call_deferred("_show_intel_reveal_popup", reveal_events)
	# 改造解锁：结算时批量展示（避免战斗中多次弹窗）
	var mod_unlocks: Array = intel_harvest.get("mod_unlock_events", [])
	if not mod_unlocks.is_empty():
		var lines: Array[String] = []
		for entry in mod_unlocks:
			if entry is Dictionary:
				var card: String = String(entry.get("card_name", ""))
				var mod: String = String(entry.get("mod_name", ""))
				lines.append("「%s」→ %s" % [card, mod])
		var title := "改造情报解锁"
		var desc := "本关共解锁 %d 项改造模块：\n%s" % [lines.size(), "\n".join(lines)]
		call_deferred("_show_mod_unlock_popup", title, desc)


func _render_drops(vbox: VBoxContainer) -> void:
	ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
	var dm: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
	if dm == null or not dm.has_method("get_pending_drops"):
		return
	var drops: Array = dm.get_pending_drops()
	if drops.is_empty():
		return
	var drop_sep := HSeparator.new()
	drop_sep.add_theme_color_override("color", Color(DT.COLOR_CYAN_TECH.r, DT.COLOR_CYAN_TECH.g, DT.COLOR_CYAN_TECH.b, 0.25))
	vbox.add_child(drop_sep)
	var drop_title := Label.new()
	drop_title.text = "◆ 战斗掉落（点击继续自动领取）"
	drop_title.add_theme_font_size_override("font_size", 13)
	drop_title.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH)
	vbox.add_child(drop_title)
	# 性能优化：get_drop_info 内部会查 DefaultCards(133卡表)/PhaseLaws，
	# 每次 sort 比较重复调用是 O(n²) 量级。一次性预建每个 drop 的 info 缓存。
	var primary_drops: Array = []
	var secondary_drops: Array = []
	var info_cache: Dictionary = {}  # instance_id -> info Dictionary
	var has_get_info: bool = dm != null and dm.has_method("get_drop_info")
	for dr in drops:
		if not (dr is DropTables.DropResult):
			continue
		# 过滤已在"本关获得"区汇总的 MATERIAL 资源（nano_materials/energy_block）
		if _is_summarized_material(dr):
			continue
		var info0: Dictionary = dm.get_drop_info(dr) if has_get_info else {}
		info_cache[dr.get_instance_id()] = info0
		var t0: int = int(info0.get("type", -1))
		if _drop_type_is_card_lane(t0):
			primary_drops.append(dr)
		else:
			secondary_drops.append(dr)
	# 排序比较器只查缓存
	var _sort_by_name := func(a, b) -> bool:
		var ia: Dictionary = info_cache.get(a.get_instance_id(), {})
		var ib: Dictionary = info_cache.get(b.get_instance_id(), {})
		return String(ia.get("name", "")) < String(ib.get("name", ""))
	primary_drops.sort_custom(_sort_by_name)
	secondary_drops.sort_custom(_sort_by_name)
	var drop_list := VBoxContainer.new()
	drop_list.add_theme_constant_override("separation", 3)
	var _append_drop_rows := func(rows: Array, subhdr: String) -> void:
		if rows.is_empty():
			return
		var sh := Label.new()
		sh.text = subhdr
		sh.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		sh.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_MID.r, DT.COLOR_TEXT_MID.g, DT.COLOR_TEXT_MID.b, 0.95))
		drop_list.add_child(sh)
		for dr in rows:
			var line_text: String = "  ▸ 未知掉落"
			var info: Dictionary = info_cache.get(dr.get_instance_id(), {})
			var n: String = String(info.get("name", "未知"))
			var c: int = int(info.get("count", 1))
			var s: String = String(info.get("source", "battle"))
			# v9.x（P2-7）：能量类掉落随科研点退役，claim 时静默跳过（drop_manager 无效果臂）；
			# 旧档 pending 若仍出现，如实标注跳过（原"研究点 ×N"文案随科研点退役失实，v26.4 清理）。
			var t_int: int = int(info.get("type", -1))
			if t_int == DropTables.DropType.ENERGY_CARD or t_int == DropTables.DropType.ENERGY_DATA or t_int == DropTables.DropType.ENERGY_BLUEPRINT:
				line_text = "  ▸ 旧版本掉落（已自动跳过）"
			else:
				line_text = "  ▸ %s ×%d（%s）" % [n, c, s]
			var dl := Label.new()
			dl.text = line_text
			dl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			dl.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
			drop_list.add_child(dl)
	_append_drop_rows.call(primary_drops, "  ▸ 缴获 / 研发类")
	_append_drop_rows.call(secondary_drops, "  ▸ 物资 / 情报类")
	vbox.add_child(drop_list)


func _render_phase_instrument_drop(vbox: VBoxContainer) -> void:
	var pi_drop: Dictionary = _reward_summary.get("phase_instrument_drop", {})
	if not (pi_drop is Dictionary) or pi_drop.is_empty():
		return
	var pi_sep := HSeparator.new()
	pi_sep.add_theme_color_override("color", Color(DT.COLOR_CYAN_TECH.r, DT.COLOR_CYAN_TECH.g, DT.COLOR_CYAN_TECH.b, 0.25))
	vbox.add_child(pi_sep)
	var pi_title := Label.new()
	pi_title.text = "◆ 相位仪掉落"
	pi_title.add_theme_font_size_override("font_size", 13)
	pi_title.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH)
	vbox.add_child(pi_title)
	var pi_name: String = String(pi_drop.get("name", "未知相位仪"))
	var pi_star: int = int(pi_drop.get("star", 1))
	var pi_line := Label.new()
	pi_line.text = "  ▸ %s ★%d（已加入相位仪库）" % [pi_name, pi_star]
	pi_line.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	pi_line.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	vbox.add_child(pi_line)
	var pi_props: Array = pi_drop.get("properties", [])
	if pi_props is Array and not pi_props.is_empty():
		var show_n: int = mini(5, pi_props.size())
		for i in range(show_n):
			var p: Variant = pi_props[i]
			if not (p is Dictionary):
				continue
			var p_display: String = String((p as Dictionary).get("display", ""))
			if p_display.is_empty():
				continue
			var p_line := Label.new()
			p_line.text = "    · %s" % p_display
			p_line.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			p_line.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_MID.r, DT.COLOR_TEXT_MID.g, DT.COLOR_TEXT_MID.b, 0.95))
			vbox.add_child(p_line)
		if pi_props.size() > show_n:
			var more_line := Label.new()
			more_line.text = "    · 还有 %d 条属性…" % (pi_props.size() - show_n)
			more_line.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			more_line.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_DIM.r, DT.COLOR_TEXT_DIM.g, DT.COLOR_TEXT_DIM.b, 0.95))
			vbox.add_child(more_line)


# =========================================================================
#  v7.x 胜利面板漏显修复：本局缴获与战利品
#  渲染绕过 DropManager.pending_drops 直接入背包/库存的奖励：
#  战中击杀卡 / 战中符文 / 相位师 Boss掉落卡 / 缴获平台卡 / 相位师符文 /
#  相位师改造蓝图 / 特殊相位仪 / 相位师额外材料
# =========================================================================

func _render_collected_rewards(vbox: VBoxContainer) -> void:
	var collected: Array = _reward_summary.get("collected_rewards", [])
	if collected.is_empty():
		return
	# 按 category 分组（保留首次出现顺序）
	var grouped: Dictionary = {}  # category -> Array[entry]
	var order: Array[String] = []
	for entry in collected:
		if not (entry is Dictionary):
			continue
		var cat: String = String(entry.get("category", ""))
		if cat.is_empty():
			continue
		if not grouped.has(cat):
			grouped[cat] = []
			order.append(cat)
		grouped[cat].append(entry)
	if grouped.is_empty():
		return
	var col_sep := HSeparator.new()
	col_sep.add_theme_color_override("color", Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.3))
	vbox.add_child(col_sep)
	var col_title := Label.new()
	col_title.text = "◆ 本局缴获与战利品"
	col_title.add_theme_font_size_override("font_size", 13)
	col_title.add_theme_color_override("font_color", DT.COLOR_GOLD)
	vbox.add_child(col_title)
	var col_list := VBoxContainer.new()
	col_list.add_theme_constant_override("separation", 3)
	# 按固定顺序渲染各分组（缺失则跳过）
	var section_order: Array[String] = ["card", "rune", "mod_blueprint", "instrument", "resource"]
	for cat in section_order:
		if not grouped.has(cat):
			continue
		_render_collected_section(col_list, cat, grouped[cat])
	vbox.add_child(col_list)


## 渲染单个分类区块（卡牌/符文/改造蓝图/特殊相位仪/资源）
func _render_collected_section(parent_vbox: VBoxContainer, cat: String, entries: Array) -> void:
	var section_title: String = _collected_section_title(cat)
	var sh := Label.new()
	sh.text = "  ▸ %s（共%d）" % [section_title, entries.size()]
	sh.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	sh.add_theme_color_override("font_color", Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.95))
	parent_vbox.add_child(sh)
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var line_text: String = _collected_entry_line(cat, entry)
		var line_lbl := Label.new()
		line_lbl.text = "      · " + line_text
		line_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		line_lbl.add_theme_color_override("font_color", _collected_entry_color(cat, entry))
		parent_vbox.add_child(line_lbl)


## 分类中文标题
static func _collected_section_title(cat: String) -> String:
	match cat:
		"card": return "缴获卡牌"
		"rune": return "符文"
		"mod_blueprint": return "改造蓝图"
		"instrument": return "特殊相位仪"
		"resource": return "相位师额外战利品"
		_: return cat


## 单项行文本
static func _collected_entry_line(cat: String, entry: Dictionary) -> String:
	var name: String = String(entry.get("name", entry.get("id", "?")))
	var source: String = String(entry.get("source", ""))
	var src_suffix: String = "（%s）" % source if not source.is_empty() else ""
	match cat:
		"card":
			var count: int = int(entry.get("count", 1))
			if count > 1:
				return "%s ×%d%s" % [name, count, src_suffix]
			return "%s%s" % [name, src_suffix]
		"rune":
			var rarity: String = _collected_rarity_name(String(entry.get("rarity", "")))
			return "%s%s%s" % [name, ("（" + rarity + "）") if not rarity.is_empty() else "", src_suffix]
		"mod_blueprint":
			var rarity: String = _collected_rarity_name(String(entry.get("rarity", "")))
			return "%s%s%s" % [name, ("（" + rarity + "）") if not rarity.is_empty() else "", src_suffix]
		"instrument":
			var star: int = int(entry.get("star", 1))
			return "%s ★%d%s" % [name, star, src_suffix]
		"resource":
			var res_name: String = _collected_resource_name(String(entry.get("id", "")))
			var amount: int = int(entry.get("amount", 0))
			return "%s +%d%s" % [res_name, amount, src_suffix]
		_:
			return name + src_suffix


## 单项颜色（按 category / 稀有度区分）
static func _collected_entry_color(cat: String, entry: Dictionary) -> Color:
	match cat:
		"card": return DT.COLOR_TEXT_BRIGHT
		"instrument": return DT.COLOR_GOLD
		"resource": return DT.COLOR_GREEN_BRIGHT
		"rune", "mod_blueprint":
			return _collected_rarity_color(String(entry.get("rarity", "")))
		_: return DT.COLOR_TEXT_BRIGHT


## 稀有度中文名（符文/改造蓝图用）
static func _collected_rarity_name(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"uncommon": return "优秀"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
		"mythic": return "神话"
		_: return rarity


## 稀有度配色（v23.6.1：收口到 GC.get_rarity_color 单一源，删除本地平行表）
static func _collected_rarity_color(rarity: String) -> Color:
	return GC.get_rarity_color(rarity)


## 资源 id → 中文名
static func _collected_resource_name(res_id: String) -> String:
	match res_id:
		"nano_materials": return "纳米材料"
		"energy_block": return "能量块"
		"alloy": return "合金"
		"crystal": return "晶体"
		_: return res_id


## 关闭按钮：用 anchors 钉在面板底部，独立于 ScrollContainer，内容再多也永远可见
## v26.6: 断链补链——二周目入口。战役最终关（LevelInformation.LEVEL_COUNT）胜利后
## 显示"进入二周目"按钮，接通 SaveManager.start_ng_plus（符文/相位仪保留、进度重置、敌方 ×1.2）。
## 此前该函数全链活（enemy_unit ×1.2、ng_plus 存档键、DayClock.reset_for_new_loop）但零调用方。
func _render_ng_plus_entry(vbox: VBoxContainer) -> void:
	if not player_won or _is_afk:
		return
	if GameManager.ng_plus_active:
		return  # 已在二周目，不重复提供入口
	if GameManager.current_level < LevelInformation.LEVEL_COUNT:
		return  # 未通关最终关
	vbox.add_child(_make_separator())
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	vbox.add_child(wrap)
	var head := Label.new()
	head.text = "∞ 战役已通关——二周目已解锁"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE)
	head.add_theme_color_override("font_color", DT.COLOR_GOLD)
	wrap.add_child(head)
	var hint := Label.new()
	hint.text = "符文与相位仪将保留，战役进度与资源重置，敌方全员强化（×1.2）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	wrap.add_child(hint)
	var btn := Button.new()
	btn.text = "进入二周目"
	btn.custom_minimum_size = Vector2(220, 42)
	var styles := PanelStyles.make_button_styles(DT.COLOR_GOLD, "solid")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, styles[state])
	btn.pressed.connect(_show_ng_plus_confirm)
	var center := CenterContainer.new()
	center.add_child(btn)
	wrap.add_child(center)


## v26.6: 二周目确认框——自绘全屏遮罩（AcceptDialog 在 CanvasLayer 下不可显示，
## 同 main.gd 撤退确认框模式），挂独立 CanvasLayer(layer=210) 压过结算面板(200)。
var _ng_confirm_layer: CanvasLayer = null
func _show_ng_plus_confirm() -> void:
	if _ng_confirm_layer != null and is_instance_valid(_ng_confirm_layer):
		return
	var layer := CanvasLayer.new()
	layer.layer = 210
	add_child(layer)
	_ng_confirm_layer = layer
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = DT.COLOR_BACKDROP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var sb := PanelStyles.make_panel_frame_textured(DT.COLOR_GOLD)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "进入二周目"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", DT.COLOR_GOLD)
	vbox.add_child(title)
	var body := Label.new()
	body.text = "战役进度与资源将重置，符文与相位仪保留，敌方全员强化（×1.2）。\n确定开启新周目吗？"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.88, 0.9, 0.94, 1.0))
	vbox.add_child(body)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)
	var confirm_btn := Button.new()
	confirm_btn.text = "确认开启"
	confirm_btn.custom_minimum_size = Vector2(120, 38)
	var c_styles := PanelStyles.make_button_styles(DT.COLOR_GOLD, "solid")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		confirm_btn.add_theme_stylebox_override(state, c_styles[state])
	btn_row.add_child(confirm_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(120, 38)
	var n_styles := PanelStyles.make_button_styles(DT.COLOR_TEXT_MID)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		cancel_btn.add_theme_stylebox_override(state, n_styles[state])
	btn_row.add_child(cancel_btn)
	# 关闭确认框
	var close := func() -> void:
		if _ng_confirm_layer != null and is_instance_valid(_ng_confirm_layer):
			_ng_confirm_layer.queue_free()
		_ng_confirm_layer = null
	confirm_btn.pressed.connect(func():
		close.call()
		# 重置进度并保存（符文/相位仪保留、ng_plus 激活），回标题屏以新周目重新开始
		SaveManager.start_ng_plus()
		SceneTransition.change(get_tree(), "res://scenes/title_screen.tscn")
	)
	cancel_btn.pressed.connect(close)


func _render_close_button_anchored(panel: Control) -> void:
	var btn := Button.new()
	if _is_afk:
		btn.text = "自动继续 →"
	elif player_won:
		btn.text = "继  续"
	else:
		btn.text = "返回整备"
	# anchors：钉在面板底部，距左右边各留 100px 居中，距底 16px
	btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	btn.anchor_left = 0.0
	btn.anchor_right = 1.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = 100.0
	btn.offset_right = -100.0
	btn.offset_top = -60.0   # 按钮 top 距面板底 60px（按钮高 44 + 16px 底边距）
	btn.offset_bottom = -16.0
	# v22.4（P0-2）：从基地出击时，左下角加"返回基地"直达按钮，主按钮让位右移
	if _bunker_return_available:
		btn.offset_left = 260.0
		var home_btn := Button.new()
		home_btn.text = "← 返回基地"
		home_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		home_btn.anchor_top = 1.0
		home_btn.anchor_bottom = 1.0
		home_btn.offset_left = 24.0
		home_btn.offset_right = 224.0
		home_btn.offset_top = -60.0
		home_btn.offset_bottom = -16.0
		home_btn.custom_minimum_size = Vector2(0, 44)
		# v23.6.1：走 PanelStyles 工厂四态（替换手写单态，圆角归按钮档 6）
		var home_styles: Dictionary = PanelStyles.make_button_styles(Color(1.0, 0.72, 0.32), "solid")
		for key in ["normal", "hover", "pressed", "disabled", "focus"]:
			home_btn.add_theme_stylebox_override(key, home_styles[key])
		home_btn.add_theme_color_override("font_color", Color(0.09, 0.07, 0.04))
		home_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
		home_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		home_btn.pressed.connect(_on_return_bunker_pressed)
		panel.add_child(home_btn)
	btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn.custom_minimum_size = Vector2(0, 44)
	# v23.6.1：走 PanelStyles 工厂四态（原仅 normal 有样式，无 hover/按下反馈）
	var btn_accent: Color = DT.COLOR_GOLD if player_won else DT.COLOR_BORDER
	var btn_styles: Dictionary = PanelStyles.make_button_styles(btn_accent, "solid")
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(key, btn_styles[key])
	btn.add_theme_color_override("font_color", DT.COLOR_VOID)
	btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	btn.pressed.connect(_on_continue_pressed)
	panel.add_child(btn)


# =========================================================================
#  v22.4 要塞反馈区（P0-2：战斗→基地循环闭合）
# =========================================================================

## 打完仗的基地一览：修复进度推进/今日完工/精神状态（低精神折损提示）。
## 从基地出击（launch_from_bunker）且非挂机时，底部追加"返回基地"直达按钮。
## 从未进过基地的玩家（/root/BunkerManager 不存在）整区不显示，零干扰。
func _render_bunker_status(vbox: VBoxContainer) -> void:
	var bunker: Node = Engine.get_main_loop().root.get_node_or_null("BunkerManager") \
		if Engine.get_main_loop() != null else null
	if bunker == null or not bunker.has_method("get_day"):
		return
	_bunker_return_available = Engine.has_meta("launch_from_bunker") and not _is_afk

	var title := Label.new()
	var mult: float = bunker.get_drop_reward_multiplier() \
		if bunker.has_method("get_drop_reward_multiplier") else 1.0
	var sanity_txt: String = "精神 %d" % int(round(bunker.get_sanity()))
	if mult < 1.0:
		sanity_txt += "（低精神：奖励 ×%.2f）" % mult
	title.text = "◆ 余烬要塞 · 第 %d 天 · %s · 英雄档案 %d/30" % [
		bunker.get_day(), sanity_txt, bunker.get_hero_fragment_count()]
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.32))
	vbox.add_child(title)

	# 低精神本战折损（game_manager 已实际扣除，这里只展示）
	var pen: Dictionary = _reward_summary.get("sanity_penalty", {})
	if not pen.is_empty():
		var pen_l := Label.new()
		pen_l.text = "  ⚠ 低精神折损：纳米 -%d · 能量块 -%d（医疗室/睡觉可恢复）" % [
			int(pen.get("nano", 0)), int(pen.get("energy", 0))]
		pen_l.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		pen_l.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
		vbox.add_child(pen_l)

	# 施工中的房间（进度已含本场推进）+ 今日完工
	var detail := Label.new()
	var parts: Array[String] = []
	for def in BunkerRoomDefs.get_all_rooms():
		var rid: String = def.get("id", "")
		if bunker.get_room_state(rid) == BunkerRoomDefs.STATE_REPAIRING:
			var pct: int = int(round(bunker.get_room_progress(rid) * 100.0))
			var frozen_txt: String = "（冻结·需反应堆）" if bunker.is_repair_frozen(rid) else ""
			parts.append("%s +%d%%%s" % [str(def.get("name", rid)), pct, frozen_txt])
	var done_names: Array[String] = []
	for entry in bunker.get_completed_today():
		done_names.append(BunkerRoomDefs.completed_entry_label(str(entry)))
	if not done_names.is_empty():
		parts.append("✔ 完工：" + "、".join(done_names))
	detail.text = "  " + ("；".join(parts) if not parts.is_empty() else "暂无施工中的房间——回基地可开工新修复")
	detail.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	detail.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(detail)

# =========================================================================
#  按钮回调（统一领取 + 返回准备界面）
# =========================================================================

func _on_continue_pressed() -> void:
	result_confirmed.emit(player_won)
	# 领取全部掉落
	ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
	var dm_claim: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
	if dm_claim != null and dm_claim.has_method("claim_drops"):
		dm_claim.claim_drops()
	# 淡出后返回准备界面。注意：CanvasLayer 没有 modulate 属性（见 _build 注释），
	# 因此淡出必须作用于面板内的 Control（Panel），不能作用于 overlay_layer。
	var panel: Control = get_node_or_null("MvpPanelOverlay/Panel")
	var tw := create_tween()
	if panel != null:
		if DT.is_motion_reduce():
			panel.modulate.a = 0.0
		else:
			# C7: 淡出统一 DT.MOTION_FADE_OUT + SINE
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(panel, "modulate:a", 0.0, DT.MOTION_FADE_OUT)
	tw.tween_callback(func():
		var parent: Node = get_parent()
		if parent != null and parent.has_method("_on_result_confirmed"):
			parent._on_result_confirmed()
		queue_free()
	)

## v22.4（P0-2）：直接回基地——领取掉落 + 存档 + 清 meta + 切场景。
## 不走 main 的 _on_result_confirmed（那是"返回整备"路径），场景切换自然拆除战斗态。
func _on_return_bunker_pressed() -> void:
	ManagerLazyLoader.ensure_loaded("drop")
	var dm: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
	if dm != null and dm.has_method("claim_drops"):
		dm.claim_drops()
	if SaveManager and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	if Engine.has_meta("launch_from_bunker"):
		Engine.remove_meta("launch_from_bunker")
	var panel: Control = get_node_or_null("MvpPanelOverlay/Panel")
	var tw := create_tween()
	if panel != null:
		if DT.is_motion_reduce():
			panel.modulate.a = 0.0
		else:
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(panel, "modulate:a", 0.0, DT.MOTION_FADE_OUT)
	tw.tween_callback(func():
		SceneTransition.change(get_tree(), "res://scenes/bunker/bunker_main.tscn"))


# =========================================================================
#  战绩数据采集
# =========================================================================

func _collect_stats() -> Dictionary:
	# 优先从 BattleInfoDisplay.get_battle_stats() 取（实时统计）
	var bid: Node = get_node_or_null("/root/Main/HudLayer/BattleTopStatusBar/BattleInfoDisplay")
	if bid == null:
		# fallback：尝试全局查找
		var tree := get_tree()
		if tree != null:
			bid = _find_node_by_name(tree.root, "BattleInfoDisplay")
	if bid != null and bid.has_method("get_battle_stats"):
		return bid.get_battle_stats()
	return {}


func _find_node_by_name(root: Node, name: String) -> Node:
	if root.name == name:
		return root
	for c in root.get_children():
		var found := _find_node_by_name(c, name)
		if found != null:
			return found
	return null


## 击杀类型分布（前 3 类），来自 BattleManager._defeated_enemies
func _kill_type_breakdown() -> Array:
	var bm: Node = get_node_or_null("/root/BattleManager")
	if bm == null:
		return []
	var defeated: Array = []
	if "_defeated_enemies" in bm:
		defeated = bm.get("_defeated_enemies")
	if defeated.is_empty():
		return []
	# 按 enemy_type 聚合
	var counts: Dictionary = {}
	for e in defeated:
		var et: String = e.get("enemy_type", "infantry") if e is Dictionary else "infantry"
		counts[et] = int(counts.get(et, 0)) + 1
	# 排序取前 3
	var sorted: Array = counts.keys()
	sorted.sort_custom(func(a, b): return counts[a] > counts[b])
	var out: Array = []
	for i in range(mini(3, sorted.size())):
		out.append("%s ×%d" % [_type_display_name(sorted[i]), counts[sorted[i]]])
	return out


func _type_display_name(t: String) -> String:
	match t:
		"infantry": return "步兵"
		"armor", "tank": return "装甲"
		"artillery": return "火炮"
		"anti_air": return "防空"
		"air": return "空军"
		"recon": return "侦察"
		"engineer": return "工兵"
		"fort": return "堡垒"
		_: return t


# =========================================================================
#  败因分析（v27：失败产出知识——productive failure）
# =========================================================================

## 残存敌军构成：结算面板存活期（战场在确认后才清理）扫描 EnemyUnits。
## 敌方兵种判定复用 BattleManager._guess_enemy_type_from_archetype（同 _defeated_enemies 口径）。
func _alive_enemy_breakdown() -> Dictionary:
	var main := get_parent()
	if main == null or not is_instance_valid(main) or not main.has_method("_get_battlefield"):
		return {}
	var bf: Node2D = main._get_battlefield()
	if bf == null:
		return {}
	var eu: Node = bf.get_node_or_null("EnemyUnits")
	if eu == null:
		return {}
	var bm: Node = get_node_or_null("/root/BattleManager")
	var counts: Dictionary = {}
	for c in eu.get_children():
		if c == null or not is_instance_valid(c):
			continue
		var hp_val = c.get("hp")
		if hp_val != null and float(hp_val) <= 0.0:
			continue
		var aid = c.get("archetype_id")
		if aid == null or str(aid).is_empty():
			continue
		var et: String = "infantry"
		if bm != null and bm.has_method("_guess_enemy_type_from_archetype"):
			et = str(bm.call("_guess_enemy_type_from_archetype", str(aid), []))
		counts[et] = int(counts.get(et, 0)) + 1
	return counts

## 克制建议（按残存敌军构成给最多 3 条；口径与战斗克制链一致：对空封锁/装甲碾压/曲射压制）
const _COUNTER_ADVICE: Dictionary = {
	"armor": "装甲单位多——上火炮/反坦克单位，或给主力安装穿甲类改造",
	"air": "空中单位多——需要防空单位（对空特化 +25%），其余地面单位打不到飞机",
	"infantry": "轻步兵海——机枪/范围伤害类单位清杂效率最高",
	"fort": "堡垒/重装单位——用曲射单位（迫击炮/火炮）在对方射程外压制",
	"artillery": "敌方火炮威胁大——高机动单位快速突进斩首，避免战线僵持对轰",
	"anti_air": "敌方防空压制我方空军——先地面单位拔点，再放飞行卡",
	"recon": "侦察渗透骚扰后排——补前排防线单位堵住缺口",
	"engineer": "工兵近身爆破——提升前排硬度（堡垒/装甲）优先",
}

func _render_defeat_analysis(vbox: VBoxContainer) -> void:
	var sec_title := Label.new()
	sec_title.text = "▍败因分析"
	sec_title.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	sec_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35, 1.0))
	vbox.add_child(sec_title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	body.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)

	var lines: Array = []
	var alive: Dictionary = _alive_enemy_breakdown()
	if alive.is_empty():
		lines.append("· 敌军构成：未能记录（战场已清场）")
	else:
		var keys: Array = alive.keys()
		keys.sort_custom(func(a, b): return alive[a] > alive[b])
		var parts: Array = []
		for i in range(mini(4, keys.size())):
			parts.append("%s×%d" % [_type_display_name(str(keys[i])), int(alive[keys[i]])])
		lines.append("· 残存敌军：" + "　".join(parts))
		# 克制建议：按残存数量取构成前 3 的兵种
		var advised: int = 0
		for k in keys:
			var tip: String = str(_COUNTER_ADVICE.get(str(k), ""))
			if not tip.is_empty():
				lines.append("· 建议：" + tip)
				advised += 1
				if advised >= 3:
					break
	var killed: Array = _kill_type_breakdown()
	lines.append("· 本场击杀：" + ("、".join(killed) if not killed.is_empty() else "无"))
	lines.append("· 情报：在情报中心把对应敌种情报推到 75%+ 可解锁弱点/抗性提示")
	lines.append("· 整备：提升卡牌等级/改造/制造高品质卡后再战，或稍后用大招手动模式攒爆发打 Boss 波")
	body.text = "\n".join(lines)
	vbox.add_child(body)


## 星级评定：基于击杀比/损失比/时长（1~3 星）
func _compute_stars(stats: Dictionary) -> int:
	if not player_won:
		return 1
	var kills: int = int(stats.get("enemy_kills", 0))
	var losses: int = int(stats.get("player_kills", 0))
	var time_s: float = float(stats.get("battle_time", 0.0))
	var stars: int = 1
	# 击杀数门槛
	if kills >= 8:
		stars += 1
	if kills >= 20:
		stars += 1
	# 损失扣星
	if losses > kills * 0.8 and kills > 0:
		stars = max(1, stars - 1)
	# 时长奖励（速胜）
	if time_s > 0 and time_s < 60 and kills >= 5:
		stars = min(3, stars + 1)
	return clampi(stars, 1, 3)


func _star_text(stars: int) -> String:
	var s := ""
	for i in range(3):
		s += "★" if i < stars else "☆"
	return s


## 星级逐个亮起动画（胜利时增强仪式感）
func _animate_stars() -> void:
	if _star_lbl == null:
		return
	# 解析星数（"★" 个数）
	var lit_count: int = 0
	for ch in _star_lbl.text:
		if ch == "★":
			lit_count += 1
	# 预构建每个亮起阶段的状态字符串，避免闭包捕获循环变量
	var states: Array[String] = []
	for i in range(lit_count + 1):
		var s := ""
		for j in range(3):
			s += "★" if j < i else "☆"
		states.append(s)
	# 初始全暗
	_star_lbl.text = states[0]
	_star_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	# 逐个亮起（每阶段用循环内局部变量捕获，确保各自独立）
	var tw := create_tween()
	for i in range(1, lit_count + 1):
		var target_text: String = states[i]
		tw.tween_callback(func():
			_star_lbl.text = target_text
		)
		tw.tween_interval(0.12)
	# 全部亮起后恢复金色
	tw.tween_callback(func():
		_star_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD)
	)


# =========================================================================
#  掉落辅助方法（从 battle_result_dialog.gd 移植）
# =========================================================================

static func _drop_type_is_card_lane(t: int) -> bool:
	return (
		t == DropTables.DropType.CARD_DATA
		or t == DropTables.DropType.DROPPED_CARD
		or t == DropTables.DropType.CARD_REWARD
		or t == DropTables.DropType.ENERGY_CARD
		or t == DropTables.DropType.STAT_BOOST
		or t == DropTables.DropType.LAW_CARD
		or t == DropTables.DropType.LAW_DATA
		or t == DropTables.DropType.LAW_BLUEPRINT
		or t == DropTables.DropType.ENERGY_DATA
		or t == DropTables.DropType.ENERGY_BLUEPRINT
		or t == DropTables.DropType.BLUEPRINT_FRAGMENT
	)


## 扫描 DropManager 待领取掉落，统计已在"本关获得"区汇总的 MATERIAL 资源总量。
## 这些资源（nano_materials / energy_block）会合并到顶部汇总行显示，
## 故需从"战斗掉落"列表中过滤掉，避免同一资源在面板上重复出现。
## 返回 {"nano_materials": int, "energy_block": int}
static func _summarize_pending_materials(dm: Node) -> Dictionary:
	var totals: Dictionary = {"nano_materials": 0, "energy_block": 0}
	if dm == null or not dm.has_method("get_pending_drops"):
		return totals
	for dr in dm.get_pending_drops():
		if not (dr is DropTables.DropResult):
			continue
		if dr.drop.type != DropTables.DropType.MATERIAL:
			continue
		var item_id: String = String(dr.drop.item_id)
		# basic_nano 是旧 ID，映射到 nano_materials（与 drop_manager._add_material 一致）
		if item_id == "basic_nano":
			item_id = "nano_materials"
		if totals.has(item_id):
			totals[item_id] = int(totals[item_id]) + int(dr.count)
	return totals


## 判断某掉落是否属于"已在顶部汇总的 MATERIAL 资源"（需从掉落列表过滤掉）
static func _is_summarized_material(dr) -> bool:
	if not (dr is DropTables.DropResult):
		return false
	if dr.drop.type != DropTables.DropType.MATERIAL:
		return false
	var item_id: String = String(dr.drop.item_id)
	return item_id == "nano_materials" or item_id == "energy_block" or item_id == "basic_nano"


# =========================================================================
#  情报揭示弹窗（从 battle_result_dialog.gd 移植）
# =========================================================================

func _show_intel_reveal_popup(reveal_events: Array) -> void:
	if reveal_events.is_empty():
		return
	# 找到 PopupLayer 挂载点
	var tree := get_tree()
	if tree == null:
		return
	var main_scene := tree.current_scene
	var popup_layer: Node = null
	if main_scene:
		popup_layer = main_scene.get_node_or_null("PopupLayer")
	if popup_layer == null:
		popup_layer = tree.root  # 兜底
	# 创建并展示揭示弹窗
	var IntelRevealPopupClass = load("res://scenes/ui/intel_reveal_popup.gd")
	if IntelRevealPopupClass == null:
		return
	var popup = IntelRevealPopupClass.create(popup_layer)
	popup.show_reveals(reveal_events)


## 改造解锁批量弹窗（结算时调用，与 _show_intel_reveal_popup 同模式）
func _show_mod_unlock_popup(title: String, description: String) -> void:
	FeatureUnlockPopup.show_now(title, description)


# =========================================================================
#  辅助 UI
# =========================================================================

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	return sep


func _add_data_row(grid: GridContainer, label: String, value: String, color: Color) -> void:
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	l.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	grid.add_child(l)
	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	v.add_theme_color_override("font_color", color)
	grid.add_child(v)


func _format_time(sec: float) -> String:
	var m: int = int(sec) / 60
	var s: int = int(sec) % 60
	return "%d:%02d" % [m, s]
