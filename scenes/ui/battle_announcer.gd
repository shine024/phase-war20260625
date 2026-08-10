extends PanelContainer
## v7.x 战斗事件播报条（BattleAnnouncer）
##
## 监听战斗关键信号，以滑入/淡出面板形式播报事件，让法则/波次/符文/BOSS 等系统
## 有"存在感"——不再静默发生。克制风格：短停留（1.5~2s），不遮挡战场核心区域。
##
## 3 档优先级：
##   HIGH（BOSS/胜负/法则）—— 大字 20px，立即插队显示
##   NORMAL（波次/符文）—— 中字 16px，排队
##   LOW（势力/部署提示）—— 小字 12px，排队，超限优先丢弃
##
## 挂载：HudLayer/TopCenterAnnouncer（main.tscn），offset_top 50~130 居中
## 队列：最多积压 3 条，超出丢弃最旧的（LOW 优先丢）

const DT = preload("res://resources/design_tokens.gd")
const RunewordDefinitions = preload("res://data/runewords.gd")

enum Priority { LOW = 0, NORMAL = 1, HIGH = 2 }

const _MAX_QUEUE: int = 3
const _HIGH_DURATION: float = 2.0
const _NORMAL_DURATION: float = 1.8
const _LOW_DURATION: float = 1.5
const _SLIDE_IN_TIME: float = 0.18
const _FADE_OUT_TIME: float = 0.3

var _label: Label = null
var _queue: Array[Dictionary] = []   # 待播报队列 {text, color, size, duration}
var _showing: bool = false
var _active_tween: Tween = null


func _ready() -> void:
	# 构建极简面板：半透明深色 + 青色边框
	var style := StyleBoxFlat.new()
	style.bg_color = Color(DT.COLOR_BG.r, DT.COLOR_BG.g, DT.COLOR_BG.b, 0.85)
	style.corner_radius_top_left = DT.CORNER_RADIUS
	style.corner_radius_top_right = DT.CORNER_RADIUS
	style.corner_radius_bottom_right = DT.CORNER_RADIUS
	style.corner_radius_bottom_left = DT.CORNER_RADIUS
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = DT.COLOR_ACCENT_CYAN
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 中央标签
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	modulate.a = 0.0
	visible = false
	# 监听信号
	if SignalBus:
		SignalBus.wave_spawned.connect(_on_wave_spawned)
		SignalBus.boss_wave_started.connect(_on_boss_wave_started)
		SignalBus.phase_master_appeared.connect(_on_phase_master_appeared)
		SignalBus.phase_law_cast.connect(_on_phase_law_cast)
		SignalBus.battle_started.connect(_on_battle_started)
		# v9.5: 符文之语激活播报（phase_instrument_manager 增量 emit）
		SignalBus.runeword_triggered.connect(_on_runeword_triggered)


# =========================================================================
#  信号处理
# =========================================================================

func _on_battle_started() -> void:
	# 战斗开始清空残留队列（避免上一场遗留事件）
	_queue.clear()
	_kill_active()
	_showing = false


func _on_wave_spawned(wave_index: int) -> void:
	# 波次总数从 BattleManager 读取（若可读）
	var total: int = 0
	var bm: Node = get_node_or_null("/root/BattleManager")
	if bm != null and bm.has_method("get_enemy_wave_total"):
		total = bm.get_enemy_wave_total()
	var text: String = "第 %d 波" % wave_index
	if total > 0:
		text += " / %d" % total
	_enqueue(text, DT.COLOR_TEXT_BRIGHT, DT.FONT_SIZE_MEDIUM, _NORMAL_DURATION, Priority.NORMAL)


func _on_boss_wave_started(boss_archetype_ids: Array) -> void:
	if boss_archetype_ids.is_empty():
		return
	_enqueue("⚠ 精英波次来袭", DT.COLOR_DANGER, DT.FONT_SIZE_LARGE, _HIGH_DURATION, Priority.HIGH)


func _on_phase_master_appeared(master_config: Dictionary) -> void:
	var display_name: String = master_config.get("display_name", master_config.get("name", "相位师"))
	_enqueue("⚔ 相位师 · %s" % display_name, DT.COLOR_DANGER, DT.FONT_SIZE_LARGE, _HIGH_DURATION, Priority.HIGH)


func _on_phase_law_cast(law_id: String, _position: Vector2, family: String) -> void:
	var color: Color = _family_color(family)
	_enqueue("⚡ %s" % _law_display_name(law_id), color, DT.FONT_SIZE_LARGE, _HIGH_DURATION, Priority.HIGH)


func _on_runeword_triggered(rw_id: String, _unit: Node) -> void:
	# v9.5: 符文之语激活——NORMAL 优先级（注释里明确"波次/符文"档），金色（稀有成就感）
	var display_name: String = String(RunewordDefinitions.RUNEWORD_NAMES.get(rw_id, rw_id))
	_enqueue("✦ 符文之语 · %s" % display_name, DT.COLOR_GOLD, DT.FONT_SIZE_MEDIUM, _NORMAL_DURATION, Priority.NORMAL)


# =========================================================================
#  队列与显示
# =========================================================================

## 入队：HIGH 立即插队（清空当前显示），NORMAL/LOW 排队
func _enqueue(text: String, color: Color, font_size: int, duration: float, prio: int) -> void:
	var entry := {"text": text, "color": color, "size": font_size, "duration": duration, "prio": prio}
	if prio == Priority.HIGH:
		# 高优先级：打断当前显示，立即播报
		_kill_active()
		_queue.clear()
		_show_entry(entry)
		return
	# 中低优先级排队，超限丢弃最旧（LOW 优先丢）
	_queue.append(entry)
	if _queue.size() > _MAX_QUEUE:
		_queue.pop_front()
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	_show_entry(_queue.pop_front())


func _show_entry(entry: Dictionary) -> void:
	var ls := LabelSettings.new()
	ls.font_color = entry["color"]
	ls.font_size = DT.current_font_size(int(entry["size"]))
	ls.outline_color = Color(0, 0, 0, 0.85)
	ls.outline_size = 3
	_label.text = entry["text"]
	_label.label_settings = ls
	visible = true
	modulate.a = 0.0
	# 滑入
	_active_tween = create_tween()
	_active_tween.tween_property(self, "modulate:a", 1.0, _SLIDE_IN_TIME)
	_active_tween.tween_interval(float(entry["duration"]))
	_active_tween.tween_property(self, "modulate:a", 0.0, _FADE_OUT_TIME)
	_active_tween.tween_callback(_on_entry_done)


func _on_entry_done() -> void:
	visible = false
	_show_next()


func _kill_active() -> void:
	# 杀掉正在播放的 tween（若有），立即进入下一则
	if _active_tween and is_instance_valid(_active_tween):
		_active_tween.kill()
		_active_tween = null
	modulate.a = 0.0
	visible = false


# =========================================================================
#  辅助
# =========================================================================

func _family_color(family: String) -> Color:
	match family.to_upper():
		"STEEL":
			return DT.COLOR_ACCENT_CYAN
		"FLAME":
			return DT.COLOR_ENERGY
		"THUNDER":
			return DT.COLOR_ACCENT_PURPLE
		"VOID":
			return Color(1.0, 0.42, 0.62, 1.0)
		_:
			return DT.COLOR_ACCENT_CYAN


func _law_display_name(law_id: String) -> String:
	if law_id.is_empty():
		return "相位法则"
	if law_id.find("·") >= 0:
		return law_id
	var cleaned: String = law_id.replace("law_", "").replace("_", " ")
	return cleaned.capitalize()
