# -*- coding: utf-8 -*-
"""§4.4 world_map.gd 手术：领地图退役 + 历史色标 + 驻防段重写（势力批1，一次性脚本）"""
import io

p = 'scenes/world_map.gd'
s = io.open(p, encoding='utf-8').read()
fails = []


def rep(old, new, tag):
    global s
    if old not in s:
        fails.append(tag)
        return
    s = s.replace(old, new, 1)


# 1. preload 删
rep('const FactionConquestBuffs = preload("res://data/faction_conquest_buffs.gd")  # v6.9: 占领势力加成描述\n', '', 'preload')

# 2. 领地图按钮块删（保留 vbox_r 供燃料 chip 用）
rep('''	# v22: 势力领地图入口改挂标题栏（旧实现位于滚动内容里，随网格布局退役）
	var vbox_r := get_node_or_null("Margin/VBox")
	if vbox_r != null and vbox_r.get_node_or_null("TerritoryMapButton") == null:
		var territory_btn := Button.new()
		territory_btn.name = "TerritoryMapButton"
		territory_btn.text = "◆ 势力领地图"
		territory_btn.tooltip_text = "查看100关当前占领状态（势力领地分布）"
		territory_btn.custom_minimum_size = Vector2(0, 30)
		var tbs := StyleBoxFlat.new()
		tbs.bg_color = Color(0.06, 0.1, 0.17, 0.9)
		tbs.border_width_left = 1; tbs.border_width_top = 1
		tbs.border_width_right = 1; tbs.border_width_bottom = 1
		tbs.border_color = Color(0.0, 0.75, 0.85, 0.6)
		tbs.corner_radius_top_left = 5; tbs.corner_radius_top_right = 5
		tbs.corner_radius_bottom_right = 5; tbs.corner_radius_bottom_left = 5
		territory_btn.add_theme_stylebox_override("normal", tbs)
		_apply_map_btn_states(territory_btn, tbs)
		territory_btn.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)
		territory_btn.add_theme_font_size_override("font_size", 13)
		territory_btn.pressed.connect(_on_territory_map_button)
		vbox_r.add_child(territory_btn)
		vbox_r.move_child(territory_btn, 1)  # 标题之后、地图画布之前
''',
    '''	# v6.22: 势力领地图入口已随占领状态机退役删除（领地概念不再存在）
	var vbox_r := get_node_or_null("Margin/VBox")
''', 'territory_btn')

# 3. occupation_changed 连接删
rep('''	if SignalBus and SignalBus.has_signal("occupation_changed"):
		SignalBus.occupation_changed.connect(_on_occupation_changed_refresh)
''', '', 'occ_connect')

# 4. 头部 _occupation_dirty 变量与注释
rep('''# v9 perf：隐藏期间的占领变化置脏，重新打开时补刷（见 _on_occupation_changed_refresh）
var _occupation_dirty: bool = false
''', '', 'dirty_var')

# 5. _on_visibility_changed 里补刷块
rep('''	# v27.12: 隐藏期间占领变化过 → 变可见时补一次全量重建（覆盖不经过 refresh_for_open
	# 的显隐路径；refresh_for_open 已先行清脏标记，不会在这里二次重建）
	if _runtime_active and _occupation_dirty:
		_occupation_dirty = false
		refresh_levels()
	if _runtime_active:
''', '''	if _runtime_active:
''', 'dirty_visblock')

# 6. _on_occupation_changed_refresh 函数删
rep('''## v6.10: 占领变化时刷新地图（让关卡按钮的占领色标实时更新）
## v9 perf：地图隐藏时置脏跳过——world_map 随 WorldMapPanel 常驻主场景但默认不可见，
## 每次过关都触发 100 按钮全量重建是纯浪费；重新打开时 refresh_for_open 补刷
func _on_occupation_changed_refresh(_level: int, _old_f: String, _new_f: String) -> void:
	if not is_visible_in_tree():
		_occupation_dirty = true
		return
	refresh_levels()

''', '', 'occ_refresh_fn')

# 7. refresh_for_open 置脏块删
rep('''	# v9 perf：隐藏期间占领变化过 → 补一次全量重建（占领色标已变）
	if _occupation_dirty:
		_occupation_dirty = false
		refresh_levels()
	_on_visibility_changed()
''', '''	_on_visibility_changed()
''', 'dirty_open')

# 8. _refresh_static_state 注释 + 数据源换历史辖区
rep('''## 每次构建/刷新时重读动态状态：占领色环集合 + 巨环三态
func _refresh_static_state(current_level: int) -> void:
	_s_occ_colors.clear()
	for lv in range(1, LEVEL_COUNT + 1):
		var fid := _get_level_occupation_safe(lv)
''',
    '''## 每次构建/刷新时重读：历史辖区色环集合（v6.22 定案5：纯风味，数据源=静态表）+ 巨环三态
func _refresh_static_state(current_level: int) -> void:
	_s_occ_colors.clear()
	for lv in range(1, LEVEL_COUNT + 1):
		var fid := _get_level_faction_safe(lv)
''', 'refresh_static')

# 9. tooltip 改「曾属于」
rep('''	# v6.10: 占领 tooltip（色环由 overlay 绘制，节点不再染膜）
	var occupation_fid: String = _get_level_occupation_safe(level_index)
	if not occupation_fid.is_empty():
		var occ_name: String = occupation_fid
		var fsm = get_node_or_null("/root/FactionSystemManager")
		if fsm and fsm.has_method("get_faction_info"):
			occ_name = String(fsm.get_faction_info(occupation_fid).get("name", occupation_fid))
		if btn.tooltip_text.is_empty():
			btn.tooltip_text = "占领：%s" % occ_name
		else:
			btn.tooltip_text += "\\n占领：%s" % occ_name
''',
    '''	# v6.22: 历史辖区 tooltip（色环语义=曾属于，定案5 纯风味）
	var occupation_fid: String = _get_level_faction_safe(level_index)
	if not occupation_fid.is_empty():
		var occ_name: String = occupation_fid
		var fsm = get_node_or_null("/root/FactionSystemManager")
		if fsm and fsm.has_method("get_faction_info"):
			occ_name = String(fsm.get_faction_info(occupation_fid).get("name", occupation_fid))
		if btn.tooltip_text.is_empty():
			btn.tooltip_text = "曾属于：%s" % occ_name
		else:
			btn.tooltip_text += "\\n曾属于：%s" % occ_name
''', 'tooltip')

# 10. _get_level_occupation_safe 重写为静态表直读并改名
rep('''func _get_level_occupation_safe(level: int) -> String:
	var fsm = get_node_or_null("/root/FactionSystemManager")
	if fsm and fsm.has_method("get_level_occupation"):
		return String(fsm.get_level_occupation(level))
	# 回退静态（v7.x 性能：用全局单例）
	var li = LevelInformation.get_shared()
	return li.get_level_faction(level)
''',
    '''## v6.22: 动态占领查询已退役——关卡势力归属=纯风味静态表（定案5）
func _get_level_faction_safe(level: int) -> String:
	var li = LevelInformation.get_shared()
	return String(li.get_level_faction(level))
''', 'fn_rename')

# 11. 战前摘要驻防段重写
rep('''	# v6.9/v6.10: 查询关卡驻防势力（动态占领优先，回退静态）
	# v6.10: 玩家攻克易主后，驻防显示跟随动态占领状态
	var garrison_faction_id: String = _get_level_occupation_safe(level_index)
	var garrison_text: String = "无主之地（无占领势力，无敌方加成）"
	var garrison_buff_text: String = ""
	var garrison_color: Color = Color(0.7, 0.75, 0.8, 0.9)
	if not garrison_faction_id.is_empty():
		var fsm = get_node_or_null("/root/FactionSystemManager")
		if fsm and fsm.has_method("get_faction_info"):
			var finfo: Dictionary = fsm.get_faction_info(garrison_faction_id)
			var fname: String = String(finfo.get("name", garrison_faction_id))
			var flevel: int = int(finfo.get("level", 1))
			garrison_text = "%s（Lv.%d）" % [fname, flevel]
			# 显示该势力对该关敌人的加成（来自 faction_conquest_buffs.gd）
			if FactionConquestBuffs != null:
				garrison_buff_text = FactionConquestBuffs.describe_buff(garrison_faction_id, flevel)
				garrison_color = Color(1.0, 0.7, 0.4, 1.0)  # 橙红：占领势力，威胁提示
''',
    '''	# v6.22: 驻防信息=历史辖区（纯风味）——占领/敌方加成链已退役，buff 恒空
	var garrison_faction_id: String = _get_level_faction_safe(level_index)
	var garrison_text: String = "无主之地"
	var garrison_buff_text: String = ""
	var garrison_color: Color = Color(0.7, 0.75, 0.8, 0.9)
	if not garrison_faction_id.is_empty():
		var fsm = get_node_or_null("/root/FactionSystemManager")
		if fsm and fsm.has_method("get_faction_info"):
			var finfo: Dictionary = fsm.get_faction_info(garrison_faction_id)
			var fname: String = String(finfo.get("name", garrison_faction_id))
			garrison_text = "%s（曾属）" % fname
			garrison_color = CompanyDefs.get_faction_color(garrison_faction_id)
''', 'garrison')

# 12. 领地图打开函数 + 本地 overlay 懒建整块删
rep('''## v6.10: 打开势力领地图面板
func _on_territory_map_button() -> void:
	# OccupationPanel 已静态实例化于 main.tscn（PopupLayer/OccupationOverlay/CenterContainer），
	# 旧的 UILazyLoader.ensure_loaded("occupation") 守卫恒真（UILazyLoader 无此方法），导致按钮永远早退——已删。
	var overlay = get_node_or_null("/root/Main/PopupLayer/OccupationOverlay")
	var main = get_node_or_null("/root/Main")
	# v6.21 K 条：独立/内嵌模式（从移动基地进图）main.tscn 不在场 → 本场景自持懒实例化，
	# 与 main.tscn 的 overlay 同构（Backdrop+CenterContainer+OccupationPanel）。
	if overlay == null:
		overlay = _ensure_local_occupation_overlay()
		if overlay == null:
			return
		overlay.visible = true
	elif main != null and main.has_method("_open_overlay"):
		# v6.14: 走 main 统一开关（开面板淡入动效，与其它 16 入口同路径）；
		# 直接 visible=true 时 ESC/关闭链仍正常（close_top 按 visible 找），仅无动效。
		main._open_overlay(overlay, "occupation")
	else:
		overlay.visible = true
	var panel = overlay.get_node_or_null("CenterContainer/OccupationPanel")
	if panel and panel.has_method("_refresh_all"):
		panel._refresh_all()

var _local_occupation_overlay: Control = null

## v6.21 K 条：懒建势力领面板弹层（仅 main 不在场时使用）。panel 的 closed 信号自己收层。
func _ensure_local_occupation_overlay() -> Control:
	if _local_occupation_overlay != null and is_instance_valid(_local_occupation_overlay):
		return _local_occupation_overlay
	var panel_scene: PackedScene = load("res://scenes/ui/occupation_panel.tscn")
	if panel_scene == null:
		return null
	var overlay := Control.new()
	overlay.name = "OccupationOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel: Control = panel_scene.instantiate()
	panel.name = "OccupationPanel"
	center.add_child(panel)
	if panel.has_signal("closed"):
		panel.closed.connect(func(): overlay.visible = false)
	add_child(overlay)
	_local_occupation_overlay = overlay
	return overlay

''', '## v6.22: 原 _on_territory_map_button/_ensure_local_occupation_overlay 已随领地图面板退役删除。\n\n', 'overlay_fns')

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print("FAILS:", fails if fails else "none - all 12 blocks applied")
