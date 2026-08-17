extends PanelContainer
class_name IntelligenceHubPanel

## 情报中心：V1 世界观情报 · V3 单位进化总图 + 详情 · v6.2 符文图鉴

signal closed
signal open_progression_requested(card_id: String)

const RuneDefs = preload("res://data/runes.gd")
const RunewordDefs = preload("res://data/runewords.gd")
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

@onready var _tab_container: TabContainer = $Margin/VBox/TabContainer
@onready var _lore_grid: GridContainer = $Margin/VBox/TabContainer/LoreTab/LoreScroll/LoreGrid
@onready var _evolution_host: Control = $Margin/VBox/TabContainer/EvolutionTab/EvolutionHost
@onready var _rune_content: VBoxContainer = $Margin/VBox/TabContainer/RuneTab/RuneScroll/RuneContent

var _atlas: EvolutionAtlasView
var _detail: UnitProgressionDetailView


func _ready() -> void:
	# v7.x 面板统一：MEDIUM 档 + 紫色签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	custom_minimum_size = DT.PANEL_SIZE_MEDIUM
	var accent := DT.get_panel_accent("intelligence")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(accent))
	var chrome = PanelChrome.attach_to($Margin/VBox, "情报中心", accent, "INTEL HUB")
	chrome.closed.connect(_on_close)
	# v9.x 性能：同步路径只保留样式/标题/骨架。atlas 条目与 lore 卡全部入队分帧
	# （首开同步冻结 1.2~3s 的热点即 _setup_evolution_tab 全量构建 + _refresh_lore 整表重建）。
	_setup_evolution_tab()
	_refresh_lore()
	_lore_dirty = false
	_refresh_runes_tab()
	if _tab_container:
		_tab_container.set_tab_title(0, "世界观情报")
		_tab_container.set_tab_title(1, "单位进化图谱")
		_tab_container.set_tab_title(2, "符文图鉴")
		_tab_container.tab_changed.connect(_on_tab_changed)
	# v9.x 性能：监听 lore 解锁置脏，refresh() 未脏时跳过 lore 整表重建
	var lm: Node = get_node_or_null("/root/LoreManager")
	if lm and lm.has_signal("lore_unlocked") and not lm.lore_unlocked.is_connected(_on_lore_unlocked):
		lm.lore_unlocked.connect(_on_lore_unlocked)


func _exit_tree() -> void:
	var lm: Node = get_node_or_null("/root/LoreManager")
	if lm and lm.has_signal("lore_unlocked") and lm.lore_unlocked.is_connected(_on_lore_unlocked):
		lm.lore_unlocked.disconnect(_on_lore_unlocked)


func refresh() -> void:
	if _lore_dirty:
		_refresh_lore()
		_lore_dirty = false
	_refresh_runes_tab()
	if _atlas:
		_atlas.refresh()
	if _detail and _detail.visible and not _detail.get_card_id().is_empty():
		_detail.show_card(_detail.get_card_id())


func _setup_evolution_tab() -> void:
	if _evolution_host == null:
		return
	for child in _evolution_host.get_children():
		child.queue_free()

	_atlas = EvolutionAtlasView.new()
	_atlas.name = "EvolutionAtlas"
	_atlas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_atlas.card_selected.connect(_on_atlas_card_selected)
	_evolution_host.add_child(_atlas)

	_detail = UnitProgressionDetailView.new()
	_detail.name = "UnitDetail"
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail.back_pressed.connect(_on_detail_back)
	_detail.open_progression_requested.connect(_on_detail_open_progression)
	_evolution_host.add_child(_detail)
	_detail.hide_detail()


func _on_tab_changed(tab: int) -> void:
	if tab == 1 and _atlas:
		_atlas.refresh()
	if tab == 2:
		_refresh_runes_tab()


## v9.x 性能：lore 分帧加载状态（整表销毁重建曾是首开冻结热点之一）
var _lore_load_queue: Array = []
var _lore_dirty := true
const LORE_PER_FRAME_FIRST := 8   # 首帧加载量（立即可见）
const LORE_PER_FRAME := 8         # 后续每帧加载量


func _on_lore_unlocked(_lore_id: String, _lore_name: String) -> void:
	_lore_dirty = true


func _refresh_lore() -> void:
	if _lore_grid == null:
		return
	for child in _lore_grid.get_children():
		child.queue_free()
	_lore_load_queue.clear()

	var lm: Node = get_node_or_null("/root/LoreManager")
	if lm == null or not lm.has_method("get_unlocked_lore"):
		_add_lore_placeholder("情报系统未初始化")
		return

	var unlocked: Array = lm.get_unlocked_lore()
	if unlocked.is_empty():
		_add_lore_placeholder("暂无已解锁世界观情报\n（战斗掉落情报页后显示于此）")
		return

	# v9.x 性能：lore 卡入队分帧出队（复用符文页签的分帧 timer）
	_lore_load_queue = unlocked.duplicate()
	_process_lore_batch(LORE_PER_FRAME_FIRST)
	if not _lore_load_queue.is_empty():
		_start_rune_load_timer()


func _process_lore_batch(batch_count: int) -> void:
	var n := 0
	while n < batch_count and not _lore_load_queue.is_empty():
		_add_lore_card(_lore_load_queue.pop_front())
		n += 1


func _add_lore_placeholder(message: String) -> void:
	var lbl := Label.new()
	lbl.text = message
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	_lore_grid.add_child(lbl)


func _add_lore_card(lore_data: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 100)
	panel.add_theme_stylebox_override("panel",
		PanelStyles.make_card_style(Color(DT.COLOR_CARD.r, DT.COLOR_CARD.g, DT.COLOR_CARD.b, 0.9), DT.COLOR_BORDER_DIM, 1, 4, 8))
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = lore_data.get("name", "情报资料")
	name_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD)
	name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	vbox.add_child(name_lbl)

	var desc := Label.new()
	desc.text = lore_data.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(200, 0)
	desc.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
	desc.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	vbox.add_child(desc)

	_lore_grid.add_child(panel)


func _on_atlas_card_selected(card_id: String) -> void:
	if _detail == null or _atlas == null:
		return
	_detail.show_card(card_id)
	_atlas.visible = false


func _on_detail_back() -> void:
	var focus_id: String = _detail.get_card_id() if _detail else ""
	if _detail:
		_detail.hide_detail()
	if _atlas:
		_atlas.visible = true
		if not focus_id.is_empty():
			_atlas.focus_card(focus_id)


func _on_detail_open_progression(card_id: String) -> void:
	open_progression_requested.emit(card_id)


# ═══════════════════════════════════════════════════════════════════
# v6.2: 符文图鉴标签页 — 显示全部符文和符文之语说明
# ═══════════════════════════════════════════════════════════════════

func _refresh_runes_tab() -> void:
	if _rune_content == null:
		return
	for child in _rune_content.get_children():
		child.queue_free()
	# 获取玩家拥有的符文（用于标记"已获得"）
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var owned_runes: Array = []
	var equipped_runes: Array = []
	if pim and pim.has_method("get_owned_runes"):
		owned_runes = pim.get_owned_runes()
	if pim and pim.has_method("get_rune_slots"):
		equipped_runes = pim.get_rune_slots()
	# ── 第一部分：符文列表 ──
	_add_rune_section_header("◈ 符文列表（%d/%d 已获得）" % [owned_runes.size(), RuneDefs.ALL_RUNES.size()])
	# v9.4: 分帧加载符文卡——56 张符文图标（995×995 RGBA ~4MB/张）一次性加载会触发内存峰值，
	# 改为每帧加载若干个，避免 _ready 阶段集中分配导致 OOM（首次崩溃即发生在此）。
	# 符文之语列表（无图标）紧跟首帧后同步加载，开销小。
	_rune_load_queue = RuneDefs.ALL_RUNES.duplicate()
	_rune_load_owned = owned_runes
	_rune_load_equipped = equipped_runes
	# 首帧先加载一批，让用户立即看到内容
	_process_rune_load_batch(RUNE_PER_FRAME_FIRST)
	# 符文之语列表（无图标，纯文本，内存开销小，直接同步加载）
	_add_rune_section_header("✦ 符文之语列表（共%d种）" % RunewordDefs.ALL_RUNEWORDS.size())
	for rw in RunewordDefs.ALL_RUNEWORDS:
		_add_runeword_card(rw, owned_runes)
	# 若还有剩余符文未加载，启动分帧定时器
	if not _rune_load_queue.is_empty():
		_start_rune_load_timer()


## v9.4: 分帧加载状态
var _rune_load_queue: Array = []
var _rune_load_owned: Array = []
var _rune_load_equipped: Array = []
const RUNE_PER_FRAME_FIRST := 12   # 首帧加载量（立即可见）
const RUNE_PER_FRAME := 10         # 后续每帧加载量
var _rune_load_timer: Timer = null


## v9.4: 从队列里取出 batch_count 个符文，创建卡片。
func _process_rune_load_batch(batch_count: int) -> void:
	var n := 0
	while n < batch_count and not _rune_load_queue.is_empty():
		var rune: Dictionary = _rune_load_queue.pop_front()
		var rune_id: String = rune.get("id", "")
		var is_owned: bool = _rune_load_owned.has(rune_id)
		var is_equipped: bool = _rune_load_equipped.has(rune_id)
		_add_rune_card(rune, is_owned, is_equipped)
		n += 1


## v9.4: 启动分帧加载定时器，每帧处理 RUNE_PER_FRAME 个直到队列清空。
func _start_rune_load_timer() -> void:
	if _rune_load_timer == null:
		_rune_load_timer = Timer.new()
		_rune_load_timer.wait_time = 0.016  # 约一帧
		_rune_load_timer.one_shot = false
		_rune_load_timer.timeout.connect(_on_rune_load_timer_timeout)
		add_child(_rune_load_timer)
	_rune_load_timer.start()


func _on_rune_load_timer_timeout() -> void:
	# v9.x 性能：统一分帧 tick——lore 与 rune 两个队列都空时才停表
	var did_work := false
	if not _rune_load_queue.is_empty():
		_process_rune_load_batch(RUNE_PER_FRAME)
		did_work = true
	if not _lore_load_queue.is_empty():
		_process_lore_batch(LORE_PER_FRAME)
		did_work = true
	if not did_work:
		if _rune_load_timer:
			_rune_load_timer.stop()
		return


func _add_rune_section_header(title_text: String) -> void:
	var header := Label.new()
	header.text = title_text
	header.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	header.add_theme_color_override("font_color", DT.COLOR_VIOLET)
	_rune_content.add_child(header)


func _add_rune_card(rune_def: Dictionary, is_owned: bool, is_equipped: bool) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 0)
	var style := StyleBoxFlat.new()
	var rarity: String = str(rune_def.get("rarity", "common"))
	var border_color: Color = RuneDefs.RARITY_COLORS.get(rarity, Color(0.5, 0.5, 0.5))
	style.bg_color = Color(DT.COLOR_CARD.r, DT.COLOR_CARD.g, DT.COLOR_CARD.b, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border_color if is_owned else Color(DT.COLOR_BORDER_DIM.r, DT.COLOR_BORDER_DIM.g, DT.COLOR_BORDER_DIM.b, 0.5)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# 符文名 + 状态标记
	var rune_id: String = rune_def.get("id", "")
	var rune_name: String = RuneDefs.RUNE_NAMES.get(rune_id, rune_id)
	var rarity_name: String = RuneDefs.RARITY_NAMES.get(rarity, "未知") as String
	var category_name: String = _rune_category_name(rune_def.get("category", ""))
	var status: String = ""
	if is_equipped:
		status = " [已装备]"
	elif is_owned:
		status = " [已获得]"
	else:
		status = " [未获得]"

	# v6.2: 符文专属图标缩略图（未获得的半透明，与文字状态色一致）
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = UiAssetLoader.rune_icon(rune_id)
	icon_rect.modulate = border_color if is_owned else Color(DT.COLOR_TEXT_FAINT.r, DT.COLOR_TEXT_FAINT.g, DT.COLOR_TEXT_FAINT.b, 0.5)
	hbox.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.text = "%s  (%s·%s)%s" % [rune_name, category_name, rarity_name, status]
	name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	name_lbl.add_theme_color_override("font_color", border_color if is_owned else DT.COLOR_TEXT_FAINT)
	name_lbl.custom_minimum_size = Vector2(300, 0)
	hbox.add_child(name_lbl)

	# 效果说明
	var effect_lbl := Label.new()
	var primary: String = str(rune_def.get("desc_primary", ""))
	var secondary: String = str(rune_def.get("desc_secondary", ""))
	var effect_text: String = primary
	if not secondary.is_empty():
		effect_text += " / " + secondary
	effect_lbl.text = effect_text
	effect_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
	effect_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_MID if is_owned else Color(DT.COLOR_TEXT_FAINT.r, DT.COLOR_TEXT_FAINT.g, DT.COLOR_TEXT_FAINT.b, 0.85))
	effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(effect_lbl)

	_rune_content.add_child(panel)


func _add_runeword_card(rw_def: Dictionary, owned_runes: Array) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var tier: int = int(rw_def.get("tier", 2))
	var tier_color: Color = RunewordDefs.TIER_COLORS.get(tier, Color(0.6, 0.6, 0.6))
	# 检查玩家是否拥有全部所需符文
	var required: Array = rw_def.get("required_runes", [])
	var has_all: bool = true
	for rid in required:
		if not owned_runes.has(str(rid)):
			has_all = false
			break
	style.bg_color = Color(DT.COLOR_VIOLET.r, DT.COLOR_VIOLET.g, DT.COLOR_VIOLET.b, 0.08)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = tier_color if has_all else Color(DT.COLOR_BORDER_DIM.r, DT.COLOR_BORDER_DIM.g, DT.COLOR_BORDER_DIM.b, 0.5)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# 名称行
	var rw_id: String = rw_def.get("id", "")
	var rw_name: String = RunewordDefs.RUNEWORD_NAMES.get(rw_id, rw_id) as String
	var tier_name: String = RunewordDefs.TIER_NAMES.get(tier, "未知") as String
	var status_str: String = " [可激活]" if has_all else " [符文不足]"
	var name_lbl := Label.new()
	name_lbl.text = "★ %s  (%s·%d符文)%s" % [rw_name, tier_name, required.size(), status_str]
	name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	name_lbl.add_theme_color_override("font_color", tier_color if has_all else DT.COLOR_TEXT_FAINT)
	vbox.add_child(name_lbl)

	# 所需符文行
	var runes_str: String = ""
	for rid in required:
		if not runes_str.is_empty():
			runes_str += " + "
		runes_str += RuneDefs.RUNE_NAMES.get(str(rid), str(rid))
	var req_lbl := Label.new()
	req_lbl.text = "所需符文：%s" % runes_str
	req_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
	req_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	vbox.add_child(req_lbl)

	# 效果行
	var effect_lbl := Label.new()
	effect_lbl.text = RunewordDefs.get_effects_description(rw_id)
	effect_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
	effect_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_MID if has_all else Color(DT.COLOR_TEXT_FAINT.r, DT.COLOR_TEXT_FAINT.g, DT.COLOR_TEXT_FAINT.b, 0.85))
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(effect_lbl)

	_rune_content.add_child(panel)


func _rune_category_name(category: String) -> String:
	match category:
		"attack": return "攻击"
		"defense": return "防御"
		"energy": return "能量"
		"mobility": return "机动"
		"special": return "特殊"
	return "未知"


func _on_close() -> void:
	_on_detail_back()
	closed.emit()
