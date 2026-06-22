extends Control
## 战斗结果对话框：显示胜负、奖励、蓝图解锁等
## 从 main.gd 拆分出来，减少主脚本体积

const DefaultCards = preload("res://data/default_cards.gd")
const DialogScene = preload("res://scenes/ui/battle_result_dialog.tscn")

signal result_confirmed(player_won: bool)


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


func _ready() -> void:
	layout_mode = 1
	anchors_preset = 8
	mouse_filter = Control.MOUSE_FILTER_STOP

## 创建并显示战斗结果对话框
static func create(parent: Node, player_won: bool, blueprints: Array, \
		phase_field_xp_before: int, phase_field_level_before: int, \
		reward_summary: Dictionary) -> Control:

	var BlueprintMgr: Node = Engine.get_main_loop().root.get_node_or_null("BlueprintManager")

	var dialog: Control = DialogScene.instantiate()
	dialog.layout_mode = 1
	dialog.anchors_preset = 8
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP

	# 获取静态布局节点
	var panel: PanelContainer = dialog.get_node("Panel")
	var dim: ColorRect = dialog.get_node("DimRect")
	var content_box: VBoxContainer = dialog.get_node("Panel/Margin/VBox/ContentScroll/ContentBox")
	var header: VBoxContainer = dialog.get_node("Panel/Margin/VBox/ContentScroll/ContentBox/Header")
	var icon_lbl: Label = dialog.get_node("Panel/Margin/VBox/ContentScroll/ContentBox/Header/IconLabel")
	var desc_lbl: Label = dialog.get_node("Panel/Margin/VBox/ContentScroll/ContentBox/Header/DescLabel")
	var ok_btn: Button = dialog.get_node("Panel/Margin/VBox/BtnHBox/OkBtn")

	# 动态样式
	var bg_style := StyleBoxFlat.new()
	if player_won:
		bg_style.bg_color = Color(0.04, 0.12, 0.10, 0.98)
		bg_style.border_color = Color(0.0, 0.9, 0.7, 0.8)
		bg_style.shadow_color = Color(0.0, 0.9, 0.7, 0.3)
		icon_lbl.text = "✓ 胜利！"
		icon_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.7, 1))
		desc_lbl.text = "任务完成！前进到下一战区。"
		ok_btn.text = "继续"
		ok_btn.add_theme_color_override("font_color", Color(0.0, 0.94, 1, 1))
	else:
		bg_style.bg_color = Color(0.14, 0.04, 0.04, 0.98)
		bg_style.border_color = Color(0.9, 0.2, 0.2, 0.8)
		bg_style.shadow_color = Color(0.9, 0.2, 0.2, 0.3)
		icon_lbl.text = "✗ 失败…"
		icon_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		desc_lbl.text = "阵地失守…重新整备后再战。"
		ok_btn.text = "重试"
		ok_btn.add_theme_color_override("font_color", Color(1, 0.7, 0.2, 1))
	bg_style.border_width_left = 2; bg_style.border_width_top = 2
	bg_style.border_width_right = 2; bg_style.border_width_bottom = 2
	bg_style.corner_radius_top_left = 10; bg_style.corner_radius_top_right = 10
	bg_style.corner_radius_bottom_right = 10; bg_style.corner_radius_bottom_left = 10
	bg_style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", bg_style)

	# 相位场经验结算
	var pim: Node = Engine.get_main_loop().root.get_node_or_null("PhaseInstrumentManager")
	if pim and pim.has_method("get_phase_field_xp_progress"):
		var phase_prog: Dictionary = pim.get_phase_field_xp_progress()
		var phase_xp_after: int = int(phase_prog.get("xp", 0))
		var phase_level_after: int = int(phase_prog.get("level", 1))
		var phase_xp_gain: int = max(0, phase_xp_after - phase_field_xp_before)
		var phase_info := Label.new()
		phase_info.add_theme_font_size_override("font_size", 12)
		phase_info.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0, 0.95))
		if player_won:
			var lv_up_text: String = ""
			if phase_level_after > phase_field_level_before:
				lv_up_text = "  (Lv.%d → Lv.%d)" % [phase_field_level_before, phase_level_after]
			phase_info.text = "相位场经验 +%d%s" % [phase_xp_gain, lv_up_text]
		else:
			phase_info.text = "相位场经验 +0"
		content_box.add_child(phase_info)

	# 奖励摘要
	if player_won and not reward_summary.is_empty():
		var reward_sep := HSeparator.new()
		reward_sep.add_theme_color_override("color", Color(0, 0.9, 0.7, 0.25))
		content_box.add_child(reward_sep)
		var reward_title := Label.new()
		reward_title.text = "◆ 本关获得"
		reward_title.add_theme_font_size_override("font_size", 13)
		reward_title.add_theme_color_override("font_color", Color(0.35, 0.95, 0.75, 1))
		content_box.add_child(reward_title)
		var reward_list := VBoxContainer.new()
		reward_list.add_theme_constant_override("separation", 3)
		# 扫描 pending drops 中已汇总的 MATERIAL 资源，合并到顶部显示（避免与掉落列表重复）
		var _dm_for_summary: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
		var _pending_mats: Dictionary = _summarize_pending_materials(_dm_for_summary)
		var energy_gain: int = int(reward_summary.get("energy_block_gain", 0)) + int(_pending_mats.get("energy_block", 0))
		# 纳米材料统一显示一行（固定关卡奖励 + 随机掉落，合并总量）
		var basic_nano_gain: int = int(reward_summary.get("basic_nano_gain", 0)) + int(_pending_mats.get("nano_materials", 0))
		var fragment_gain_total: int = int(reward_summary.get("fragment_gain_total", 0))
		var recon_bonus_percent: int = int(reward_summary.get("recon_fragment_bonus_percent", 0))
		# v6.2 法则系统废弃，战斗不再产出法则知识（battle_damage_system 已禁用 _roll_law_knowledge_drops），
		# 原"法则知识值 +N"行永远为 0，已移除避免误导
		var reward_lines: Array[String] = [
			"  ▸ 能量块 +%d" % energy_gain,
			"  ▸ 纳米材料 +%d" % basic_nano_gain,
			"  ▸ 卡牌副本 +%d（侦查加成 %+d%%）" % [fragment_gain_total, recon_bonus_percent],
			]
		for line_text in reward_lines:
			var reward_lbl := Label.new()
			reward_lbl.text = line_text
			reward_lbl.add_theme_font_size_override("font_size", 12)
			reward_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1, 0.95))
			reward_list.add_child(reward_lbl)
		content_box.add_child(reward_list)

	# ═══ v6.0: 情报收获展示（含 intel_item_drops，由 IntelHarvestDisplay 统一渲染） ═══
	var intel_harvest: Dictionary = reward_summary.get("intel_harvest", {})
	if not intel_harvest.is_empty():
		var intel_sep := HSeparator.new()
		intel_sep.add_theme_color_override("color", Color(0.5, 0.3, 0.9, 0.25))
		content_box.add_child(intel_sep)
		var IHD = preload("res://scenes/ui/intel_harvest_display.gd")
		var harvest_ui = IHD.new()
		harvest_ui.set_data(intel_harvest)
		content_box.add_child(harvest_ui)
		# v6.6: 有新揭示事件时，延迟弹出 IntelRevealPopup 精致展示
		var reveal_events: Array = intel_harvest.get("reveal_events", [])
		if not reveal_events.is_empty():
			dialog.call_deferred("_show_intel_reveal_popup", reveal_events)

	# 掉落列表（来自 DropManager 待领取）
	var dm: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
	if player_won and dm != null and dm.has_method("get_pending_drops"):
		var drops: Array = dm.get_pending_drops()
		if not drops.is_empty():
			var drop_sep := HSeparator.new()
			drop_sep.add_theme_color_override("color", Color(0.0, 0.8, 1.0, 0.25))
			content_box.add_child(drop_sep)
			var drop_title := Label.new()
			drop_title.text = "◆ 战斗掉落（点击继续自动领取）"
			drop_title.add_theme_font_size_override("font_size", 13)
			drop_title.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0, 1.0))
			content_box.add_child(drop_title)
			var primary_drops: Array = []
			var secondary_drops: Array = []
			for dr in drops:
				if not (dr is DropTables.DropResult):
					continue
				# 过滤已在"本关获得"区汇总的 MATERIAL 资源（nano_materials/energy_block），
				# 避免同一资源在面板上重复显示
				if _is_summarized_material(dr):
					continue
				var info0: Dictionary = dm.get_drop_info(dr) if dm.has_method("get_drop_info") else {}
				var t0: int = int(info0.get("type", -1))
				if _drop_type_is_card_lane(t0):
					primary_drops.append(dr)
				else:
					secondary_drops.append(dr)
			var _sort_by_name := func(a, b) -> bool:
				var ia: Dictionary = dm.get_drop_info(a)
				var ib: Dictionary = dm.get_drop_info(b)
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
				sh.add_theme_font_size_override("font_size", 11)
				sh.add_theme_color_override("font_color", Color(0.5, 0.82, 0.98, 0.92))
				drop_list.add_child(sh)
				for dr in rows:
					var line_text: String = "  ▸ 未知掉落"
					if dm.has_method("get_drop_info"):
						var info: Dictionary = dm.get_drop_info(dr)
						var n: String = String(info.get("name", "未知"))
						var c: int = int(info.get("count", 1))
						var s: String = String(info.get("source", "battle"))
						line_text = "  ▸ %s ×%d（%s）" % [n, c, s]
					var dl := Label.new()
					dl.text = line_text
					dl.add_theme_font_size_override("font_size", 12)
					dl.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0, 0.95))
					drop_list.add_child(dl)
			_append_drop_rows.call(primary_drops, "  ▸ 缴获 / 研发类")
			_append_drop_rows.call(secondary_drops, "  ▸ 物资 / 情报类")
			content_box.add_child(drop_list)

	# 相位仪掉落（独立展示）
	var pi_drop: Dictionary = reward_summary.get("phase_instrument_drop", {})
	if player_won and pi_drop is Dictionary and not pi_drop.is_empty():
		var pi_sep := HSeparator.new()
		pi_sep.add_theme_color_override("color", Color(0.55, 0.9, 1.0, 0.25))
		content_box.add_child(pi_sep)
		var pi_title := Label.new()
		pi_title.text = "◆ 相位仪掉落"
		pi_title.add_theme_font_size_override("font_size", 13)
		pi_title.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0, 1.0))
		content_box.add_child(pi_title)
		var pi_name: String = String(pi_drop.get("name", "未知相位仪"))
		var pi_star: int = int(pi_drop.get("star", 1))
		var pi_line := Label.new()
		pi_line.text = "  ▸ %s ★%d（已加入相位仪库）" % [pi_name, pi_star]
		pi_line.add_theme_font_size_override("font_size", 12)
		pi_line.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 0.95))
		content_box.add_child(pi_line)
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
				p_line.add_theme_font_size_override("font_size", 11)
				p_line.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0, 0.92))
				content_box.add_child(p_line)
			if pi_props.size() > show_n:
				var more_line := Label.new()
				more_line.text = "    · 还有 %d 条属性…" % (pi_props.size() - show_n)
				more_line.add_theme_font_size_override("font_size", 11)
				more_line.add_theme_color_override("font_color", Color(0.60, 0.78, 0.95, 0.88))
				content_box.add_child(more_line)

	# v3 后直接掉落成品卡到背包，不再展示蓝图解锁信息
	# 蓝图制造系统已废弃，以下蓝图列表展示代码已移除（2026-05-29）
	# 原 230-256 行的蓝图展示逻辑已删除，避免误导玩家

	# 按钮信号
	ok_btn.pressed.connect(func():
		var dm_claim: Node = Engine.get_main_loop().root.get_node_or_null("DropManager")
		if dm_claim != null and dm_claim.has_method("claim_drops"):
			dm_claim.claim_drops()
		if parent != null and parent.has_method("_on_result_confirmed"):
			parent._on_result_confirmed()
		dialog.queue_free()
	)

	panel.modulate.a = 0
	var t = dialog.create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)

	parent.add_child(dialog)
	return dialog


## 获取蓝图显示名称（支持法则蓝图和能量卡蓝图）
static func _get_blueprint_display_name(card_id: String) -> String:
	# 法则蓝图（law:xxx 前缀）
	if card_id.begins_with("law:"):
		var law_id: String = card_id.substr(4)
		var PL = preload("res://data/phase_laws.gd")
		var law = PL.get_by_id(law_id)
		if not law.is_empty():
			return str(law.get("name", card_id))
		return card_id

	# 能量卡
	if card_id.begins_with("energy_"):
		match card_id:
			"energy_basic": return "基础能量卡"
			"energy_advanced": return "高级能量卡"
			"energy_quantum": return "量子能量卡"
			_:
				return DefaultCards.get_safe_display_name(card_id)
	# 敌人蓝图（bp_ww1_001 等）及其他未命中的卡牌
	return DefaultCards.get_safe_display_name(card_id)


## v6.6: 战斗结算后展示情报揭示事件弹窗（实例方法，由 dialog.call_deferred 调用）
## reveal_events: [{"title","desc","icon","rewards",...}, ...]
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
