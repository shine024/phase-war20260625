extends VBoxContainer
## v7.x 左侧三段折叠卡（对齐设计稿 ui_redesign_battle_hud_v7.html ③ 左侧 BUFF 折叠卡）
## 结构：VBoxContainer > [FoldCard(BUFF), FoldCard(我的面板), FoldCard(资源)]
## 数据源：
##   - BUFF 段：PhaseLawManager.equipped_passive_laws + PhaseLaws.get_by_id()
##   - 我的面板段：BlueprintManager（已解锁蓝图数）+ InstanceRegistry（实例数）+ BattleManager（场上兵力）
##   - 资源段：BasicResourceManager（能量块/纳米材料/研究点/合金/晶体）
## 折叠态：每段独立 toggle，默认 BUFF 展开、其余两段折叠

const PhaseLaws = preload("res://data/phase_laws.gd")

var _refresh_accum: float = 0.0
const _REFRESH_SEC: float = 1.0

# 三段折叠卡的内建节点引用
var _buff_card: Dictionary = {}
var _panel_card: Dictionary = {}
var _res_card: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 6)
	# 三段折叠卡（BUFF 默认展开；我的面板/资源 默认折叠）
	_buff_card = _build_fold_card("☰ BUFF", true, Color(0.13, 0.83, 0.93, 0.08))
	_panel_card = _build_fold_card("🎖 我的面板", false, Color(0.65, 0.55, 1.0, 0.07))
	_res_card = _build_fold_card("◆ 资源", false, Color(0.98, 0.75, 0.15, 0.07))
	_refresh()
	# 法则/资源变更时刷新
	var plm := get_node_or_null("/root/PhaseLawManager")
	if plm:
		if plm.has_signal("passive_laws_changed"):
			plm.passive_laws_changed.connect(_refresh)
		if plm.has_signal("law_env_changed"):
			plm.law_env_changed.connect(_refresh)
	var brm := get_node_or_null("/root/BasicResourceManager")
	if brm and brm.has_signal("resources_changed"):
		brm.resources_changed.connect(_refresh)


## 构建一段折叠卡，返回 {root: PanelContainer, content: VBoxContainer, toggle: Button}
func _build_fold_card(title: String, expanded: bool, head_bg: Color) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(172, 0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.07, 0.11, 0.88)
	st.border_color = Color(0.2, 0.3, 0.45, 0.25)
	st.border_width_bottom = 1
	st.corner_radius_top_left = 6
	st.corner_radius_top_right = 6
	st.corner_radius_bottom_right = 6
	st.corner_radius_bottom_left = 6
	card.add_theme_stylebox_override("panel", st)
	add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)
	# 标题按钮（点击折叠/展开）
	var toggle := Button.new()
	toggle.text = "%s %s" % [title, "▼" if expanded else "▶"]
	toggle.add_theme_font_size_override("font_size", 12)
	toggle.add_theme_color_override("font_color", Color(0.91, 0.94, 0.96, 1))
	toggle.add_theme_color_override("font_hover_color", Color(0.13, 0.83, 0.93, 1))
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.flat = true
	var title_st := StyleBoxFlat.new()
	title_st.bg_color = head_bg
	title_st.set_content_margin_all(4)
	toggle.add_theme_stylebox_override("normal", title_st)
	vbox.add_child(toggle)
	# 内容容器
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	content.visible = expanded
	vbox.add_child(content)
	var info := {root = card, content = content, toggle = toggle, expanded = expanded}
	toggle.pressed.connect(func(): _toggle(info))
	return info


func _toggle(info: Dictionary) -> void:
	info["expanded"] = not bool(info["expanded"])
	var exp: bool = info["expanded"]
	(info["content"] as VBoxContainer).visible = exp
	# 标题箭头切换（保留原标题前缀，只换末尾箭头）
	var btn: Button = info["toggle"]
	var t: String = btn.text.rstrip("▼▶ ").strip_edges()
	btn.text = "%s %s" % [t, "▼" if exp else "▶"]


func _process(delta: float) -> void:
	# P2 性能优化：卡片隐藏时不做任何刷新
	if not visible:
		return
	_refresh_accum += delta
	if _refresh_accum >= _REFRESH_SEC:
		_refresh_accum = 0.0
		_refresh()


func _refresh() -> void:
	_refresh_buff()
	_refresh_panel()
	_refresh_resource()


# ========== 段1：BUFF（被动法则）==========
func _refresh_buff() -> void:
	var content: VBoxContainer = _buff_card.content
	if content == null:
		return
	for c in content.get_children():
		c.queue_free()
	var plm := get_node_or_null("/root/PhaseLawManager")
	if plm == null:
		content.add_child(_make_row("（法则系统未加载）", Color(0.5, 0.55, 0.6)))
		return
	var passives: Array = plm.get("equipped_passive_laws") if "equipped_passive_laws" in plm else []
	if passives.is_empty():
		content.add_child(_make_row("（未装备被动法则）", Color(0.5, 0.55, 0.6)))
		return
	for law_id in passives:
		var law := PhaseLaws.get_by_id(String(law_id))
		if law.is_empty():
			continue
		var name: String = String(law.get("display_name", law_id))
		var rt: Dictionary = law.get("runtime_tags", {})
		var val_str := ""
		if rt.has("value"):
			val_str = " +" + _fmt_val(float(rt["value"]))
		elif rt.has("desc"):
			val_str = " " + String(rt["desc"])
		content.add_child(_make_row(name + val_str, Color(0.52, 0.83, 0.6, 1)))


# ========== 段2：我的面板（养成/兵力概览）==========
func _refresh_panel() -> void:
	var content: VBoxContainer = _panel_card.content
	if content == null:
		return
	for c in content.get_children():
		c.queue_free()
	# 总卡数：InstanceRegistry 实例总数
	var total_cards := 0
	var ir := get_node_or_null("/root/InstanceRegistry")
	if ir and ir.has_method("get_all_instance_ids"):
		total_cards = ir.get_all_instance_ids().size()
	# 进化阶：取蓝图最高星（粗略反映养成深度）
	var max_star := 0
	var bm := get_node_or_null("/root/BlueprintManager")
	if bm and bm.has_method("get_unlocked_blueprint_ids"):
		for cid in bm.get_unlocked_blueprint_ids():
			if bm.has_method("get_blueprint_star"):
				var s := int(bm.get_blueprint_star(String(cid)))
				if s > max_star:
					max_star = s
	# 场上兵力：我方在场单位 / unit_limit
	var on_field := 0
	var unit_limit := 0
	var battle_mgr := get_node_or_null("/root/BattleManager")
	if battle_mgr:
		if battle_mgr.has_method("get_player_unit_count"):
			on_field = int(battle_mgr.get_player_unit_count())
		if "max_player_units" in battle_mgr:
			unit_limit = int(battle_mgr.max_player_units)
	content.add_child(_make_kv_row("卡牌总数", "%d" % total_cards, Color(0.13, 0.83, 0.93, 1)))
	content.add_child(_make_kv_row("最高进化", "★%d" % max_star if max_star > 0 else "—", Color(0.98, 0.75, 0.15, 1)))
	var field_str := "%d / %d" % [on_field, unit_limit] if unit_limit > 0 else "%d" % on_field
	content.add_child(_make_kv_row("场上兵力", field_str, Color(0.2, 0.85, 0.4, 1)))


# ========== 段3：资源（能量/纳米/研究点/合金/晶体）==========
func _refresh_resource() -> void:
	var content: VBoxContainer = _res_card.content
	if content == null:
		return
	for c in content.get_children():
		c.queue_free()
	var brm := get_node_or_null("/root/BasicResourceManager")
	if brm == null:
		content.add_child(_make_row("（资源系统未加载）", Color(0.5, 0.55, 0.6)))
		return
	# BasicResourceManager 字段为强类型 var，Node.get() 不支持默认值参数，改用 _get_int 守卫取值
	content.add_child(_make_kv_row("⚡ 能量块", _fmt_num(_get_int(brm, "total_energy_block")), Color(0.98, 0.75, 0.15, 1)))
	content.add_child(_make_kv_row("📦 纳米材料", _fmt_num(_get_int(brm, "total_nano_materials")), Color(0.3, 0.8, 1.0, 1)))
	content.add_child(_make_kv_row("🔬 研究点", _fmt_num(_get_int(brm, "total_research_points")), Color(0.75, 0.55, 1.0, 1)))
	content.add_child(_make_kv_row("🔶 合金", _fmt_num(_get_int(brm, "total_alloy")), Color(1.0, 0.6, 0.2, 1)))
	content.add_child(_make_kv_row("💎 晶体", _fmt_num(_get_int(brm, "total_crystal")), Color(0.6, 0.3, 1.0, 1)))


# ========== 辅助：行构建 ==========
func _make_row(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## key-value 行：左 label(灰) + 右 label(彩色数值)
func _make_kv_row(key: String, val: String, val_color: Color) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kl := Label.new()
	kl.text = key
	kl.add_theme_font_size_override("font_size", 11)
	kl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72, 1))
	kl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	kl.add_theme_constant_override("outline_size", 2)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(kl)
	var vl := Label.new()
	vl.text = val
	vl.add_theme_font_size_override("font_size", 11)
	vl.add_theme_color_override("font_color", val_color)
	vl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	vl.add_theme_constant_override("outline_size", 2)
	vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vl)
	return hbox


func _fmt_val(v: float) -> String:
	# 百分比类（<1）显示为 %，数值类直接显示
	if v < 1.0 and v > 0:
		return "%d%%" % int(v * 100)
	return "%d" % int(v)


## 从 Node 安全取 int 属性：属性不存在或非数值返回 0（Node.get 不支持默认值参数）
func _get_int(node: Node, prop: String) -> int:
	if node == null or not (prop in node):
		return 0
	return int(node.get(prop))


func _fmt_num(n: int) -> String:
	if n >= 100000:
		return "%.1f万" % (n / 10000.0)
	if n >= 10000:
		return "%.1fK" % (n / 1000.0)
	return "%d" % n
