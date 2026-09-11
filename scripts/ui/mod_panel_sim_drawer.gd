class_name ModPanelSimDrawer
extends RefCounted
## v27.15（改造审查报告 5.9 首拆）：效果模拟抽屉控制器
## 自 modification_panel.gd 平移（v1.5 建制 / v26.16 三栏对比 / v27.15 展开动画），逻辑零改动——
## 仅宿主成员访问改经 panel.*。面板侧在 _ready 首段 new(self)，调用面 toggle()/open()/close()。
## 后续拆分（名册视图/改造库视图/详情视图）照此范式逐块平移。

const DT = preload("res://resources/design_tokens.gd")

var panel: Node  # 宿主 modification_panel（duck 访问其成员）

func _init(host: Node) -> void:
	panel = host

## v1.5：效果模拟抽屉切换按钮回调
func toggle() -> void:
	if panel.sim_drawer == null:
		return
	var will_open: bool = not panel.sim_drawer.visible
	if will_open:
		open()
	else:
		close()

## v1.5：打开效果模拟抽屉——完整 effect 列表 + 逐属性前后对比（v26.16 新增）+ 战力预估
func open() -> void:
	if panel.sim_drawer == null or panel.selected_mod_id.is_empty():
		return
	var mod_data: Dictionary = ModificationRegistry.get_data(panel.selected_mod_id) if ModificationRegistry != null else {}
	if mod_data.is_empty():
		return
	# v26.16：已安装改造的"预估"会把第二份的重复收益算进去，抽屉改为明示不适用
	var already_installed: bool = panel._is_mod_installed(panel.selected_mod_id)
	# 清空旧内容
	for child in panel.sim_drawer.get_children():
		panel.sim_drawer.remove_child(child)
		child.free()
	# 抽屉底色 + 内边距
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.12, 0.6)
	sb.border_width_top = 1
	sb.border_color = Color(0.024, 0.714, 0.831, 0.25)
	sb.content_margin_left = 12
	sb.content_margin_top = 8
	sb.content_margin_right = 12
	sb.content_margin_bottom = 8
	panel.sim_drawer.add_theme_stylebox_override("panel", sb)
	# 三栏内容
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 栏1：完整效果列表（复用 _format_effects_for_display：兼容 effects/level_effects/grant_slot，
	# 修复吸血等 level_effects 机制改造原显示"（无效果数据）"的 bug）
	var col1 := VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.add_theme_constant_override("separation", 2)
	col1.add_child(_make_sim_section_label("◆ 完整效果"))
	var effect_lines: PackedStringArray = panel._format_effects_for_display(mod_data)
	if effect_lines.is_empty():
		col1.add_child(_make_sim_kv("（无效果数据）", "", Color(0.5, 0.55, 0.65, 0.6)))
	else:
		for line in effect_lines:
			# 段头（"—— Lv.3（满级）——"）/ 布尔解锁（"✓ xxx"）走标题样式；数值行拆"标签 值"
			if line.begins_with("——") or line.begins_with("✓"):
				col1.add_child(_make_sim_section_label(line))
			else:
				var sp: int = line.find(" ")
				if sp > 0:
					col1.add_child(_make_sim_kv(line.substr(0, sp), line.substr(sp + 1), DT.COLOR_GREEN_UP))
				else:
					col1.add_child(_make_sim_kv(line, "", Color(0.9, 0.92, 0.96, 1)))
	hbox.add_child(col1)
	# 栏2：逐属性前后对比（v26.16 视觉批次：与战力预估同源，走真实 build_stats 路径；
	# 只显示有变化的行，机制类改造零变化时给明确文案而非空列）
	var col2 := VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.add_theme_constant_override("separation", 2)
	col2.add_child(_make_sim_section_label("◆ 属性对比"))
	var can_preview: bool = panel.selected_card != null and BlueprintManager != null
	var before_stats: UnitStats = EvolutionHelpers.build_unit_stats_for_power_preview(panel.selected_card, BlueprintManager) if can_preview else null
	var after_stats: UnitStats = EvolutionHelpers.estimate_stats_with_extra_mod(panel.selected_card, panel.selected_mod_id, BlueprintManager) if can_preview else null
	if already_installed:
		col2.add_child(_make_sim_kv("该改造已安装", "无需预估", Color(0.5, 0.55, 0.65, 0.6)))
	elif before_stats != null and after_stats != null:
		var stat_rows := [
			["耐久", before_stats.max_hp, after_stats.max_hp],
			["攻轻", before_stats.attack_light, after_stats.attack_light],
			["攻甲", before_stats.attack_armor, after_stats.attack_armor],
			["攻空", before_stats.attack_air, after_stats.attack_air],
			["防轻", before_stats.defense_light, after_stats.defense_light],
			["防甲", before_stats.defense_armor, after_stats.defense_armor],
			["防空", before_stats.defense_air, after_stats.defense_air],
		]
		var changed_count := 0
		for r in stat_rows:
			var d: float = float(r[2]) - float(r[1])
			if absf(d) < 0.5:
				continue
			changed_count += 1
			col2.add_child(_make_sim_kv(String(r[0]), "%d → %d (%s%d)" % [
				int(r[1]), int(r[2]), "+" if d > 0.0 else "", int(round(d))],
				DT.COLOR_GREEN_UP if d > 0.0 else DT.COLOR_RED_DOWN))
		if changed_count == 0:
			col2.add_child(_make_sim_kv("无直接数值变化", "机制类", Color(0.5, 0.55, 0.65, 0.6)))
	else:
		col2.add_child(_make_sim_kv("属性预览不可用", "—", Color(0.5, 0.55, 0.65, 0.6)))
	hbox.add_child(col2)
	# 栏3：战力预估（当前已装该冲突组的模块数 + 战力前后）
	var col3 := VBoxContainer.new()
	col3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col3.add_theme_constant_override("separation", 2)
	col3.add_child(_make_sim_section_label("◆ 战力预估"))
	var before_power: float = panel._cached_card_power
	# v1.5 修复：原 after = before × power_mult 严重虚高（power_mult 是稀有度/成本权重，非战力增益倍率，
	# 1.35 会对 3000 战力卡显示 +1050）。改为克隆实例卡 + 追加候选改造，走与真实安装完全相同的
	# build_stats→combat_power 路径，预览值与右栏/intel 面板实际安装后显示的战力一致。
	# 槽位占用
	var mod_count: int = panel.selected_card.mods.size() if (panel.selected_card and "mods" in panel.selected_card) else 0
	if already_installed:
		col3.add_child(_make_sim_kv("槽位", "%d/9" % mod_count, DT.COLOR_CYAN_TECH_SOFT))
	else:
		var after_power: float = EvolutionHelpers.estimate_power_with_extra_mod(panel.selected_card, panel.selected_mod_id, BlueprintManager) if (panel.selected_card != null and BlueprintManager != null) else before_power
		col3.add_child(_make_sim_kv("当前战力", str(int(before_power)) if before_power > 0 else "—", Color(0.55, 0.6, 0.7, 0.8)))
		col3.add_child(_make_sim_kv("装上后", str(int(after_power)), DT.COLOR_GREEN_UP))
		var delta: int = int(after_power - before_power)
		col3.add_child(_make_sim_kv("变化", ("+" if delta >= 0 else "") + str(delta), DT.COLOR_GREEN_UP if delta >= 0 else DT.COLOR_RED_DOWN))
		col3.add_child(_make_sim_kv("槽位", "%d/9 → %d/9" % [mod_count, mod_count + 1], DT.COLOR_CYAN_TECH_SOFT))
	hbox.add_child(col3)
	panel.sim_drawer.add_child(hbox)
	panel.sim_drawer.visible = true
	if panel.deck_sim_button:
		panel.deck_sim_button.text = "效果模拟 ↑"
		panel.deck_sim_button.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT)
	# v27.15（改造审查报告 5.7）：展开动画——高度 0 → 自然高度 150ms；完成后释放约束交还内容自适应
	_animate_open()

var _tween: Tween = null

## v27.15：抽屉展开高度动画。等一帧让内容先算出自然高度，再从 0 缓动到该值；
## 若面板/抽屉中途被关（close() kill），动画安全中止。
func _animate_open() -> void:
	var drawer: Control = panel.sim_drawer
	if drawer == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	drawer.custom_minimum_size.y = 0.0
	await panel.get_tree().process_frame
	if drawer == null or not drawer.visible or not is_instance_valid(drawer):
		return  # 等帧期间被关闭/释放
	var target_h: float = maxf(drawer.size.y, 40.0)
	_tween = panel.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(drawer, "custom_minimum_size:y", target_h, 0.15)
	_tween.finished.connect(func():
		if is_instance_valid(drawer):
			drawer.custom_minimum_size.y = 0.0  # 交还给内容驱动的最小高度
	)

## v1.5：关闭效果模拟抽屉
func close() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_tween = null
	if panel.sim_drawer != null:
		panel.sim_drawer.visible = false
		panel.sim_drawer.custom_minimum_size.y = 0.0
	if panel.deck_sim_button:
		panel.deck_sim_button.text = "效果模拟 ↓"
		panel.deck_sim_button.add_theme_color_override("font_color", DT.COLOR_SLATE_A80)

## v1.5：抽屉小区块标题
func _make_sim_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT)
	return lbl

## v1.5：抽屉键值行
func _make_sim_kv(key: String, val: String, val_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var kl := Label.new()
	kl.text = key
	kl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	kl.add_theme_color_override("font_color", DT.COLOR_SLATE_DIM_A85)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(kl)
	var vl := Label.new()
	vl.text = val
	vl.add_theme_font_override("font", DT.get_title_font_bold())
	vl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	vl.add_theme_color_override("font_color", val_color)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(vl)
	return row
