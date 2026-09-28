extends PanelContainer
## v7.x 战斗日志底栏（BattleLog）
##
## 让战斗感觉"活起来"——玩家看到"我方 XX 击毁 敌方 YY"、"精英波次来袭！"、
## "基地 -350 HP"，沉浸感显著提升。克制风格：默认折叠（仅最新 1 行 + ▼ 展开），
## 战斗中常驻显示，战斗结束保留 2s 后淡出。
## v25.6：BU-8 peek 滑入滑出模式退役——新消息 3s 闪现收回的节奏在交战密集期
## 反复进出屏幕，读感割裂；宽度收半（锚点 0→0.5）后常驻遮挡已可控。
##
## 性能：仿 battle_info_display 的 _stats_dirty 模式——事件先入队列，
## _process 每 0.3s 合并刷新一次 Label，避免高频事件每帧重建文本。
##
## 挂载：HudLayer/BattleLogBar（BattleBottomBar 兄弟节点）。
## 保留最近 30 条，FIFO。
## v26.16 收窄贴边：不再占左半屏浮在底部栏上方，改为左下窄列——右缘动态紧挨
## 大招条按钮簇左缘（订阅 ult_cluster_geometry_changed，簇宽随可见按钮变化重排）、
## 底缘紧贴相位仪栏顶边、折叠态与大招条带同高成行。展开态（96px）会向上探进
## 功能抽屉展开区——仅该态在抽屉开（bottom_drawer_toggled）时淡出让位，收起复原；
## 战斗结束后收抽屉不复活。

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")

const _MAX_ENTRIES: int = 30           # 保留条目上限
const _REFRESH_SEC: float = 0.3        # 合并刷新间隔
const _COLLAPSED_LINES: int = 1        # 折叠时显示行数
const _EXPANDED_LINES: int = 5         # 展开时显示行数
const _HEIGHT_COLLAPSED: float = 50.0  # 折叠态高度：与大招条带同高成行，底缘贴相位仪栏顶
const _HEIGHT_EXPANDED: float = 96.0   # 展开态高度（5 行），向上加高
const _BAND_HUG_GAP: float = 12.0      # 右缘与大招按钮簇的间隙（底板左外扩 10px + 2px 呼吸）

var _entries: Array[Dictionary] = []   # {text, color}
var _dirty: bool = false
var _refresh_acc: float = 0.0
var _expanded: bool = false
var _log_label: RichTextLabel = null
var _toggle_btn: Button = null
var _battle_active: bool = false       # 战斗进行中（让位复原的门卫：战后收抽屉不复活）
var _drawer_open: bool = false         # 底部功能抽屉当前开合（bottom_drawer_toggled 维护）
var _alpha_tween: Tween = null         # 本面板唯一的 alpha 补间（让位/复原/战后淡出共用，互斥）

func _ready() -> void:
	# v25 HUD 家族：半透明深底 + 6 圆角；保留左侧 3px 青色签名条
	var style := PanelStyles.make_hud_panel(0.25)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.border_width_left = 3
	style.border_color = Color(DT.COLOR_ACCENT_CYAN.r, DT.COLOR_ACCENT_CYAN.g, DT.COLOR_ACCENT_CYAN.b, 0.8)
	style.content_margin_left = 10.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 主容器
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)
	# 日志文本（RichTextLabel 支持多色多行）
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.fit_content = true
	_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_label.scroll_active = false
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override("normal_font_size", DT.FONT_SIZE_SMALL)
	hbox.add_child(_log_label)
	# 展开/折叠按钮
	_toggle_btn = Button.new()
	_toggle_btn.text = "▼"
	_toggle_btn.custom_minimum_size = Vector2(28, 0)
	_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	# 按钮样式（克制：小而暗）
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.15, 0.25, 0.8)
	btn_style.corner_radius_top_left = 3
	btn_style.corner_radius_top_right = 3
	btn_style.corner_radius_bottom_right = 3
	btn_style.corner_radius_bottom_left = 3
	_toggle_btn.add_theme_stylebox_override("normal", btn_style)
	# ui-review·易用性：hover/pressed 反馈（原单态悬停无响应）
	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = btn_style.bg_color.lightened(0.18)
	_toggle_btn.add_theme_stylebox_override("hover", btn_hover)
	_toggle_btn.add_theme_stylebox_override("pressed", btn_style.duplicate())
	_toggle_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	_toggle_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	hbox.add_child(_toggle_btn)
	modulate.a = 0.0
	visible = false
	set_process(false)
	# 监听战斗事件
	if SignalBus:
		SignalBus.unit_killed.connect(_on_unit_killed)
		SignalBus.boss_wave_started.connect(_on_boss_wave_started)
		SignalBus.phase_master_appeared.connect(_on_phase_master_appeared)
		SignalBus.battle_started.connect(_on_battle_started)
		SignalBus.battle_ended.connect(_on_battle_ended)
		SignalBus.unit_damaged.connect(_on_unit_damaged)
		SignalBus.bottom_drawer_toggled.connect(_on_bottom_drawer_toggled)
		SignalBus.ult_cluster_geometry_changed.connect(_reflow)
	get_viewport().size_changed.connect(func() -> void: _reflow.call_deferred())

# =========================================================================
#  信号处理
# =========================================================================

func _on_battle_started() -> void:
	_kill_alpha_tween()
	_entries.clear()
	_dirty = true
	set_process(true)
	_expanded = false
	_battle_active = true
	if _toggle_btn != null:
		_toggle_btn.text = "▼"
	modulate.a = 1.0
	visible = true
	_reflow.call_deferred()
	# 抽屉残留展开时开战：立即让位（开场序列的强制收抽屉晚到也不闪日志）
	if _drawer_open:
		_yield_for_drawer()

func _on_battle_ended(_player_won: bool) -> void:
	# 战斗结束停止采集，但保留最后日志 2s 供查看，然后淡出
	set_process(false)
	_battle_active = false
	_kill_alpha_tween()
	if not visible or modulate.a <= 0.01 or (_drawer_open and _expanded):
		# 让位态（alpha 已 0/让位中）或本就隐藏：直接收摊，防"战后收抽屉复活"
		_entries.clear()
		modulate.a = 0.0
		visible = false
		return
	_alpha_tween = create_tween()
	_alpha_tween.tween_interval(2.0)
	_alpha_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	_alpha_tween.tween_callback(func():
		visible = false
		_entries.clear()
	)

func _on_unit_killed(victim: Node, killer: Node, is_player_victim: bool) -> void:
	if is_player_victim:
		# 我方损失
		_add_entry("损失 %s" % _unit_name(victim), DT.COLOR_DANGER)
	else:
		# 我方击杀敌方。v26.15d: 击杀者为 dot/灼烧类伤害时节点常已释放，
		# 旧文案读作"未知单位"（玩家不可知语义），回退"我方单位"。
		var killer_name: String = _unit_name(killer) if killer != null and is_instance_valid(killer) else "我方单位"
		_add_entry("我方 %s 击毁 %s" % [killer_name, _unit_name(victim)], DT.COLOR_GREEN_BRIGHT)

func _on_boss_wave_started(wave_kind: String, _ids: Array) -> void:
	match wave_kind:
		"core":
			_add_entry("黑门本体现身！", DT.COLOR_DANGER)
		"boss":
			_add_entry("首领波次来袭！", DT.COLOR_ENERGY)
		"elite":
			_add_entry("精英波次来袭！", DT.COLOR_ENERGY)

func _on_phase_master_appeared(master_config: Dictionary) -> void:
	var name: String = master_config.get("display_name", master_config.get("name", "相位师"))
	_add_entry("相位师 · %s" % name, DT.COLOR_DANGER)

func _on_unit_damaged(unit: Node, is_player: bool, amount: float, _pos: Vector2) -> void:
	# 仅记录"我方基地驱动器"受击（普通单位受伤太频繁，不记）
	# 基地驱动器走 phase_field_driver.gd emit unit_damaged，普通单位不走 SignalBus
	if not is_player:
		return
	if unit == null or not is_instance_valid(unit):
		return
	# 基地驱动器的类名判断：检查是否为 phase_field_driver
	var cls = unit.get_class()
	if unit.has_method("get") and unit.get("max_hp") != null:
		# 粗略识别：基地驱动器是 Node2D 且不在 player_units/enemy_units 组
		if not unit.is_in_group("player_units") and not unit.is_in_group("enemy_units"):
			var amt := int(amount)
			if amt > 0:
				_add_entry("基地 -%d HP" % amt, DT.COLOR_DANGER)

# =========================================================================
#  抽屉让位（v26.16：战斗中开功能抽屉时，日志面板不再盖住抽屉上半截）
# =========================================================================

func _on_bottom_drawer_toggled(open: bool) -> void:
	_drawer_open = open
	if open:
		_yield_for_drawer()
	else:
		_restore_from_drawer()

## 抽屉展开 → 日志淡出让位（抽屉关闭注意力在菜单上，日志暂隐代价最小）。
## v26.16 收窄贴边后：折叠态（带内左侧）与抽屉展开区天然不重叠，无需让位；
## 仅展开态（96px 上探进抽屉区）让位。
func _yield_for_drawer() -> void:
	if not _expanded:
		return
	if not visible:
		return
	_kill_alpha_tween()
	if not _battle_active:
		# 战后 2s 保留窗内开抽屉：让位即收摊，跳过保留期
		modulate.a = 0.0
		visible = false
		_entries.clear()
		return
	if DT.is_motion_reduce():
		modulate.a = 0.0
		return
	_alpha_tween = create_tween()
	_alpha_tween.tween_property(self, "modulate:a", 0.0, DT.MOTION_FADE_OUT)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _restore_from_drawer() -> void:
	# 仅展开态有让位可复原；战斗已结束（战后淡出链管终态）/ 本就隐藏 / 竞态：不复原
	if not _expanded:
		return
	if not _battle_active or not visible or _drawer_open:
		return
	_kill_alpha_tween()
	if DT.is_motion_reduce():
		modulate.a = 1.0
		return
	_alpha_tween = create_tween()
	_alpha_tween.tween_property(self, "modulate:a", 1.0, DT.MOTION_FADE_IN)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _kill_alpha_tween() -> void:
	if _alpha_tween != null and _alpha_tween.is_valid():
		_alpha_tween.kill()
	_alpha_tween = null

## v26.16 收窄贴边重排：右缘动态紧挨大招条按钮簇左缘（簇宽随可见按钮变化，
## 由 ult_cluster_geometry_changed 驱动），底缘紧贴相位仪栏顶边，左缘对齐底部栏
## 边距；折叠态与大招条带同高（50px）成行，展开态向上加高到 96px。
func _reflow() -> void:
	if not is_inside_tree():
		return
	var ult: Control = get_node_or_null("../BattleBottomBar/UltimateCastBar") as Control
	var inst: Control = get_node_or_null("../BattleBottomBar/BottomInstrumentBar") as Control
	if ult == null or inst == null:
		return
	var vp_h: float = get_viewport_rect().size.y
	var cluster_left: float = ult.get_global_rect().get_center().x
	if ult.has_method("get_cluster_left_x"):
		cluster_left = float(ult.call("get_cluster_left_x"))
	var bar_top: float = inst.get_global_rect().position.y
	# 折叠态高度跟随大招条带实际高度（呼吸垫等会使带宽 50→53px 浮动），保证两行齐平
	var h: float = _HEIGHT_EXPANDED if _expanded else maxf(_HEIGHT_COLLAPSED, ult.get_global_rect().size.y)
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 16.0
	offset_right = cluster_left - _BAND_HUG_GAP
	offset_bottom = bar_top - vp_h
	offset_top = offset_bottom - h

# =========================================================================
#  日志条目管理
# =========================================================================

func _add_entry(text: String, color: Color) -> void:
	_entries.append({"text": text, "color": color})
	# FIFO 裁剪
	while _entries.size() > _MAX_ENTRIES:
		_entries.pop_front()
	_dirty = true

func _process(delta: float) -> void:
	_refresh_acc += delta
	if _refresh_acc < _REFRESH_SEC:
		return
	_refresh_acc = 0.0
	if _dirty:
		_refresh_display()
		_dirty = false

func _refresh_display() -> void:
	if _entries.is_empty():
		_log_label.text = ""
		return
	var lines: int = _EXPANDED_LINES if _expanded else _COLLAPSED_LINES
	var start: int = maxi(0, _entries.size() - lines)
	var bb := ""
	for i in range(start, _entries.size()):
		var e: Dictionary = _entries[i]
		var c: Color = e["color"]
		var color_hex := "#%02x%02x%02x" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]
		var prefix := "" if i == _entries.size() - 1 else "  "  # 最新一条前缀空格少（视觉强调）
		bb += "%s[color=%s]%s[/color]\n" % [prefix, color_hex, str(e["text"])]
	_log_label.text = bb

func _on_toggle_pressed() -> void:
	_expanded = not _expanded
	_toggle_btn.text = "▲" if _expanded else "▼"
	_dirty = true
	_reflow()
	# 抽屉开着时展开会上探进抽屉展开区：立即让位
	if _expanded and _drawer_open:
		_yield_for_drawer()

# =========================================================================
#  辅助
# =========================================================================

## 单位显示名（优先用卡牌名，回退 archetype_id，再回退节点名）
func _unit_name(unit: Node) -> String:
	if unit == null or not is_instance_valid(unit):
		return "未知单位"
	# 优先 stats.platform_card_id（我方/卡格战）
	if "stats" in unit:
		var s = unit.get("stats")
		if s != null and "platform_card_id" in s:
			var cid: String = str(s.platform_card_id)
			if not cid.is_empty():
				return _card_id_to_name(cid)
	# 敌方 archetype_id
	if "archetype_id" in unit:
		var aid: String = str(unit.archetype_id)
		if not aid.is_empty():
			return _archetype_to_name(aid)
	return unit.name

func _card_id_to_name(card_id: String) -> String:
	# v26.15d: 优先查 UCT 真实中文卡名（玩家/敌方条目同表带 display_name）——
	# 旧实现只做 id 美化（"ww1_inf_mp18"→"Ww 1 Inf Mp 18"），战报可读性差。
	var entry: Dictionary = load("res://data/unified_card_table.gd").get_entry(card_id)
	if not entry.is_empty():
		var dn: String = str(entry.get("display_name", ""))
		if not dn.is_empty():
			return dn
	# 简单美化：去掉前缀，按 _ 拆分
	if card_id.is_empty():
		return "单位"
	var cleaned := card_id.replace("ww1_", "").replace("ww2_", "").replace("cold_", "").replace("modern_", "").replace("future_", "")
	cleaned = cleaned.replace("_", " ")
	return cleaned.capitalize()

func _archetype_to_name(archetype_id: String) -> String:
	if archetype_id.is_empty():
		return "敌方单位"
	# v26.15d: archetype_id 同样先查 UCT 中文名
	var entry: Dictionary = load("res://data/unified_card_table.gd").get_entry(archetype_id)
	if not entry.is_empty():
		var dn: String = str(entry.get("display_name", ""))
		if not dn.is_empty():
			return dn
	var cleaned := archetype_id.replace("elite_", "").replace("basic_", "").replace("boss_", "")
	cleaned = cleaned.replace("_", " ")
	return cleaned.capitalize()
