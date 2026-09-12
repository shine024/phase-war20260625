extends PanelContainer
class_name IntelligenceHubPanel

## 情报中心：V1 世界观情报 · V3 单位进化总图 + 详情 · v6.2 符文图鉴

signal closed
signal open_progression_requested(card_id: String)

const RuneDefs = preload("res://data/runes.gd")
const RunewordDefs = preload("res://data/runewords.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const UnifiedCardTable = preload("res://data/unified_card_table.gd")  # v20.13c: 敌卡获得后的每卡部署次数预览
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")  # v21.0: 改造情报子行的 mod 名/稀有度
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")
const IntelUIKit = preload("res://scenes/ui/components/intel_ui_kit.gd")

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
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame_textured(accent))
	var chrome = PanelChrome.attach_to($Margin/VBox, "情报舱", accent, "情报中枢")
	chrome.closed.connect(_on_close)
	# v9.x 性能：同步路径只保留样式/标题/骨架。atlas 条目与 lore 卡全部入队分帧
	# （首开同步冻结 1.2~3s 的热点即 _setup_evolution_tab 全量构建 + _refresh_lore 整表重建）。
	_setup_evolution_tab()
	_refresh_lore()
	_lore_dirty = false
	_refresh_runes_tab()
	# P2-12: 敌方情报手册 Tab（纯代码构建）——intel_harvest_display 承诺"详见情报手册"，
	# 此前全 UI 无任何面板读取 IntelManual 条目做浏览，情报进度对玩家不可见
	_setup_intel_tab()
	if _tab_container:
		_tab_container.set_tab_title(0, "世界观情报")
		_tab_container.set_tab_title(1, "单位谱系图谱")
		_tab_container.set_tab_title(2, "符文图鉴")
		_tab_container.set_tab_title(3, "敌方情报")
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
	if _tab_container and _tab_container.current_tab == 3:
		_refresh_intel_tab()


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
	if tab == 3:
		_refresh_intel_tab()


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
		_refresh_lore_header(0)
		_add_lore_placeholder("情报系统未初始化")
		return

	var unlocked: Array = lm.get_unlocked_lore()
	_refresh_lore_header(unlocked.size())
	if unlocked.is_empty():
		_add_lore_placeholder("暂无已解锁世界观情报\n（战斗掉落情报页后显示于此）")
		return

	# v9.x 性能：lore 卡入队分帧出队（复用符文页签的分帧 timer）
	_lore_load_queue = unlocked.duplicate()
	_process_lore_batch(LORE_PER_FRAME_FIRST)
	if not _lore_load_queue.is_empty():
		_start_rune_load_timer()


## v26 UI：页签区块标题（签名竖条 + 已解锁计数），挂在 LoreTab 顶部（按名字防重建重复）
func _refresh_lore_header(unlocked_count: int) -> void:
	var tab := _lore_grid.get_parent().get_parent() as VBoxContainer  # LoreScroll 的父级 LoreTab
	if tab == null:
		return
	var old := tab.get_node_or_null("LoreHeader")
	if old != null:
		old.queue_free()
	var header := IntelUIKit.section_header("世界观情报", DT.COLOR_VIOLET,
		"已解锁 %d 份" % unlocked_count)
	header.name = "LoreHeader"
	tab.add_child(header)
	tab.move_child(header, 0)


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
	# 修复：GridContainer 里 autowrap 无最小宽度会把标签压成 1 字宽（逐字竖排塌缩）
	lbl.custom_minimum_size = Vector2(520, 80)
	_lore_grid.add_child(lbl)


## v26 UI：lore 卡统一走 IntelUIKit 行卡语言（紫签名条 + 亮名 + 中灰正文 + 就地 tooltip）
func _add_lore_card(lore_data: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	panel.add_theme_stylebox_override("panel", IntelUIKit.list_row_style(DT.COLOR_VIOLET, false))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var name_text: String = lore_data.get("name", "情报资料")
	var name_lbl := IntelUIKit.label(name_text, DT.FONT_SIZE_SMALL, DT.COLOR_VIOLET_SOFT)
	vbox.add_child(name_lbl)

	var desc_text: String = lore_data.get("description", "")
	var desc := Label.new()
	desc.text = desc_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(200, 0)
	desc.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	desc.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	vbox.add_child(desc)

	# 就地解释：卡片内容被裁切时悬停可读全文
	panel.tooltip_text = "%s\n%s" % [name_text, desc_text]

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
	_add_rune_section_header("符文列表", "已获得 %d/%d" % [owned_runes.size(), RuneDefs.ALL_RUNES.size()])
	# v9.4: 分帧加载符文卡——56 张符文图标（995×995 RGBA ~4MB/张）一次性加载会触发内存峰值，
	# 改为每帧加载若干个，避免 _ready 阶段集中分配导致 OOM（首次崩溃即发生在此）。
	# 符文之语列表（无图标）紧跟首帧后同步加载，开销小。
	_rune_load_queue = RuneDefs.ALL_RUNES.duplicate()
	_rune_load_owned = owned_runes
	_rune_load_equipped = equipped_runes
	# 首帧先加载一批，让用户立即看到内容
	_process_rune_load_batch(RUNE_PER_FRAME_FIRST)
	# 符文之语列表（无图标，纯文本，内存开销小，直接同步加载）
	_add_rune_section_header("符文之语", "共 %d 种" % RunewordDefs.ALL_RUNEWORDS.size())
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


## v26 UI：区块标题统一走 IntelUIKit（签名竖条 + 计数右对齐，替代 ◈/✦ 纯文本标题）
func _add_rune_section_header(title_text: String, count_text := "") -> void:
	_rune_content.add_child(IntelUIKit.section_header(title_text, DT.COLOR_VIOLET, count_text))


## v26 UI：符文行统一 IntelUIKit 行卡语言——
## 状态三档描边（已装备=金高亮 / 已获得=稀有度色 / 未获得=中性灰），
## 名称+类别·稀有度双行列对齐，状态 chip 替代「[已获得]」方括号文本。
func _add_rune_card(rune_def: Dictionary, is_owned: bool, is_equipped: bool) -> void:
	var rune_id: String = rune_def.get("id", "")
	var rune_name: String = RuneDefs.RUNE_NAMES.get(rune_id, rune_id)
	var rarity: String = str(rune_def.get("rarity", "common"))
	var rarity_color: Color = RuneDefs.RARITY_COLORS.get(rarity, Color(0.5, 0.5, 0.5))
	var rarity_name: String = RuneDefs.RARITY_NAMES.get(rarity, "未知") as String
	var category_name: String = _rune_category_name(rune_def.get("category", ""))

	var panel := PanelContainer.new()
	var stripe: Color = DT.COLOR_GOLD if is_equipped else (rarity_color if is_owned else DT.COLOR_TEXT_FAINT)
	panel.add_theme_stylebox_override("panel", IntelUIKit.list_row_style(stripe, is_equipped))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# 符文专属图标缩略图（未获得的半透明，与文字状态色一致）
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = UiAssetLoader.rune_icon(rune_id)
	icon_rect.modulate = rarity_color if is_owned else Color(DT.COLOR_TEXT_FAINT.r, DT.COLOR_TEXT_FAINT.g, DT.COLOR_TEXT_FAINT.b, 0.5)
	icon_rect.tooltip_text = "%s · %s（%s）" % [rune_name, category_name, rarity_name]
	hbox.add_child(icon_rect)

	# 名称块：名字 + 类别·稀有度副行（定宽 230，与效果列成对齐网格）
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 1)
	name_box.custom_minimum_size = Vector2(230, 0)
	name_box.add_child(IntelUIKit.label(rune_name, DT.FONT_SIZE_BODY,
		DT.COLOR_TEXT_BRIGHT if is_owned else DT.COLOR_TEXT_FAINT))
	name_box.add_child(IntelUIKit.label("%s · %s" % [category_name, rarity_name],
		DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM if is_owned else DT.COLOR_TEXT_FAINT))
	hbox.add_child(name_box)

	# 效果说明
	var primary: String = str(rune_def.get("desc_primary", ""))
	var secondary: String = str(rune_def.get("desc_secondary", ""))
	var effect_text: String = primary
	if not secondary.is_empty():
		effect_text += " / " + secondary
	var effect_lbl := IntelUIKit.label(effect_text, DT.FONT_SIZE_SMALL,
		DT.COLOR_TEXT_MID if is_owned else Color(DT.COLOR_TEXT_FAINT.r, DT.COLOR_TEXT_FAINT.g, DT.COLOR_TEXT_FAINT.b, 0.85))
	effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(effect_lbl)

	# 状态 chip（替代「[已装备]/[已获得]/[未获得]」方括号文本）
	var chip_text := "已装备" if is_equipped else ("已获得" if is_owned else "未获得")
	var chip_color := DT.COLOR_GOLD if is_equipped else DT.COLOR_GREEN_UP
	hbox.add_child(IntelUIKit.status_chip(chip_text, chip_color, not is_owned))

	_rune_content.add_child(panel)


## v26 UI：符文之语行统一 IntelUIKit 行卡语言——
## 描边按层级色（可激活=全亮高亮 / 符文不足=中性灰），层级/状态改 chip，名称列与符文行对齐。
func _add_runeword_card(rw_def: Dictionary, owned_runes: Array) -> void:
	var rw_id: String = rw_def.get("id", "")
	var rw_name: String = RunewordDefs.RUNEWORD_NAMES.get(rw_id, rw_id) as String
	var tier: int = int(rw_def.get("tier", 2))
	var tier_color: Color = RunewordDefs.TIER_COLORS.get(tier, Color(0.6, 0.6, 0.6))
	var tier_name: String = RunewordDefs.TIER_NAMES.get(tier, "未知") as String
	# 检查玩家是否拥有全部所需符文
	var required: Array = rw_def.get("required_runes", [])
	var has_all: bool = true
	for rid in required:
		if not owned_runes.has(str(rid)):
			has_all = false
			break

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		IntelUIKit.list_row_style(tier_color if has_all else DT.COLOR_TEXT_FAINT, has_all))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	# 名称行：名字 + 层级 chip + 状态 chip（替代「★」前缀与「[可激活]」方括号文本）
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.add_child(IntelUIKit.label(rw_name, DT.FONT_SIZE_BODY,
		DT.COLOR_TEXT_BRIGHT if has_all else DT.COLOR_TEXT_FAINT))
	name_row.add_child(IntelUIKit.status_chip("%s · %d符文" % [tier_name, required.size()], tier_color))
	name_row.add_child(IntelUIKit.status_chip("可激活" if has_all else "符文不足",
		DT.COLOR_GOLD, not has_all))
	vbox.add_child(name_row)

	# 细节行：所需符文（定宽 230 与符文名列对齐）+ 效果
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 12)
	var runes_str: String = ""
	for rid in required:
		if not runes_str.is_empty():
			runes_str += " + "
		runes_str += RuneDefs.RUNE_NAMES.get(str(rid), str(rid))
	detail_row.add_child(IntelUIKit.label("所需符文：%s" % runes_str,
		DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM, 230.0))
	var effect_lbl := IntelUIKit.label(RunewordDefs.get_effects_description(rw_id),
		DT.FONT_SIZE_SMALL,
		DT.COLOR_TEXT_MID if has_all else Color(DT.COLOR_TEXT_FAINT.r, DT.COLOR_TEXT_FAINT.g, DT.COLOR_TEXT_FAINT.b, 0.85))
	effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_row.add_child(effect_lbl)
	vbox.add_child(detail_row)

	_rune_content.add_child(panel)


func _rune_category_name(category: String) -> String:
	match category:
		"attack": return "攻击"
		"defense": return "防御"
		"energy": return "能量"
		"mobility": return "机动"
		"special": return "特殊"
	return "未知"


# ═══════════════════════════════════════════════════════════════════
# P2-12: 敌方情报手册标签页 — 浏览 IntelManual 全部条目（进度/揭示档位/击败数）
# ═══════════════════════════════════════════════════════════════════

var _intel_content: VBoxContainer = null

func _setup_intel_tab() -> void:
	if _tab_container == null:
		return
	var tab := VBoxContainer.new()
	tab.name = "IntelManualTab"
	_tab_container.add_child(tab)
	# v26 UI：顶部 4 行机制文字墙 → 「进度阶梯」可视化里程碑 + 一行脚注
	#（包容性：机制读一次图形就懂，不必啃文字墙）
	var ladder := VBoxContainer.new()
	ladder.add_theme_constant_override("separation", 4)
	ladder.add_child(IntelUIKit.section_header("情报进度阶梯", DT.COLOR_VIOLET,
		"击败/部署同一形态累积 · 缴获实物卡直接过半"))
	ladder.add_child(_build_intel_milestone_strip())
	ladder.add_child(IntelUIKit.label(
		"部署 +4% 固定不衰减；击败/部署附带改造情报点数，点数达标解锁该形态专属改造",
		DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM))
	tab.add_child(ladder)
	var scroll := ScrollContainer.new()
	scroll.name = "IntelScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)
	_intel_content = VBoxContainer.new()
	_intel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intel_content.add_theme_constant_override("separation", 4)
	scroll.add_child(_intel_content)


## v26 UI：4 档里程碑横条（25/50/75/100），色阶 中灰→青→紫→金 与行档位色同源
func _build_intel_milestone_strip() -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 6)
	var milestones := [
		["25%", "配方解锁", DT.COLOR_TEXT_MID],
		["50%", "品质池扩充", DT.COLOR_ACCENT_CYAN],
		["75%", "史诗/传说入池", DT.COLOR_VIOLET],
		["100%", "满池 + 全改造", DT.COLOR_GOLD],
	]
	for i in milestones.size():
		var m: Array = milestones[i]
		if i > 0:
			var arrow := IntelUIKit.label("→", DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_FAINT)
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			strip.add_child(arrow)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var pct := IntelUIKit.label(m[0], DT.FONT_SIZE_BODY, m[2])
		pct.add_theme_font_override("font", DT.get_title_font_bold())
		cell.add_child(pct)
		cell.add_child(IntelUIKit.label(m[1], DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM))
		strip.add_child(cell)
	return strip

func _refresh_intel_tab() -> void:
	if _intel_content == null:
		return
	for child in _intel_content.get_children():
		child.queue_free()
	var im: Node = get_node_or_null("/root/IntelManual")
	if im == null or not im.has_method("get_all_entries"):
		var lbl := Label.new()
		lbl.text = "情报手册未初始化"
		lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		_intel_content.add_child(lbl)
		return
	var entries: Dictionary = im.get_all_entries()
	if entries.is_empty():
		var ph := Label.new()
		ph.text = "尚无敌方情报记录\n（在战斗中遭遇并击败敌人后，这里会累积情报进度）"
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		_intel_content.add_child(ph)
		return
	# 头部区块标题（替代「◆ 已记录…」纯文本）
	var total_completed: int = 0
	for card_id in entries:
		if bool((entries[card_id] as Dictionary).get("is_unlocked", false)):
			total_completed += 1
	var header := IntelUIKit.section_header("敌方档案", DT.COLOR_VIOLET,
		"已记录 %d 种 · 完整解锁 %d 种" % [entries.size(), total_completed])
	_intel_content.add_child(header)
	# 条目按进度降序（v21.0: 主轴改 base_progress，旧档回退 intel_progress）
	var sorted_ids: Array = entries.keys()
	sorted_ids.sort_custom(func(a, b) -> bool:
		return float((entries[a] as Dictionary).get("base_progress", (entries[a] as Dictionary).get("intel_progress", 0.0))) \
			> float((entries[b] as Dictionary).get("base_progress", (entries[b] as Dictionary).get("intel_progress", 0.0))))
	for card_id in sorted_ids:
		var e: Dictionary = entries[card_id]
		_add_intel_row(String(card_id), e, im)

func _add_intel_row(card_id: String, entry: Dictionary, im: Node) -> void:
	# v21.0: 主进度轴改 base_progress（= max(intel 峰值, 获取下限)，旧档无此键时回退 intel）
	var progress: float = clampf(float(entry.get("base_progress", entry.get("intel_progress", 0.0))), 0.0, 1.0)
	var defeat_count: int = int(entry.get("defeat_count", 0))
	var deploy_count: int = int(entry.get("deploy_count", 0))
	var is_complete: bool = bool(entry.get("is_unlocked", false))
	# v26 UI：档位色唯一语义（与进度条/行描边同源）——满档金 / 过半青 / 低档中性灰
	var is_full: bool = is_complete or progress >= 1.0
	var tier_color: Color = DT.COLOR_GOLD if is_full \
		else (DT.COLOR_ACCENT_CYAN if progress >= 0.5 else DT.COLOR_BORDER)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", IntelUIKit.list_row_style(tier_color, is_full))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# 名称列（定宽 170 全表对齐；完整解锁由行色/进度达意，去掉 ✓ 字符）
	var display_name: String = DefaultCards.get_safe_display_name(card_id)
	var name_lbl := IntelUIKit.label(
		display_name if not display_name.is_empty() else card_id,
		DT.FONT_SIZE_BODY,
		DT.COLOR_TEXT_BRIGHT if progress > 0.0 else DT.COLOR_TEXT_FAINT, 170.0)
	name_lbl.tooltip_text = display_name if not display_name.is_empty() else card_id
	hbox.add_child(name_lbl)

	# 进度列：细进度条 + 「N% · 档位描述」副行（替代纯文字「情报 N%」）
	var prog_box := VBoxContainer.new()
	prog_box.add_theme_constant_override("separation", 3)
	prog_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog_box.add_child(IntelUIKit.thin_progress(progress, tier_color))
	var tier_text: String = String(im.get_tier_description(card_id)) if im.has_method("get_tier_description") else ""
	prog_box.add_child(IntelUIKit.label("情报 %d%% · %s" % [int(round(progress * 100.0)), tier_text],
		DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM))
	hbox.add_child(prog_box)

	# 计数列（定宽右对齐，恒显示，保证全表同网格——旧行「上阵」列时有时无导致错位）
	hbox.add_child(IntelUIKit.label("击败 ×%d" % defeat_count, DT.FONT_SIZE_SMALL,
		DT.COLOR_TEXT_MID, 62.0, HORIZONTAL_ALIGNMENT_RIGHT))
	hbox.add_child(IntelUIKit.label("上阵 ×%d" % deploy_count, DT.FONT_SIZE_SMALL,
		DT.COLOR_TEXT_MID if deploy_count > 0 else DT.COLOR_TEXT_FAINT, 62.0, HORIZONTAL_ALIGNMENT_RIGHT))

	# 尾部状态 chips（互斥档位 + 部署上限预览）
	if is_full:
		hbox.add_child(IntelUIKit.status_chip("完全掌握", DT.COLOR_GOLD))
	elif progress >= 0.5 and EnemyCardModMap.can_low_evolve(card_id):
		var low_chip := IntelUIKit.status_chip("配方已解锁", DT.COLOR_GOLD)
		low_chip.tooltip_text = "该形态情报过半——可在「制造舱」直接制造对应我方卡"
		hbox.add_child(low_chip)

	# v20.13c: 该敌卡掉落获得后作为我方卡的每场可部署次数（UCT 口径预览）
	var du_card: CardResource = DefaultCards.get_card_by_id(card_id)
	if du_card != null and du_card.card_type == GameConstants.CardType.COMBAT_UNIT:
		var du_entry := UnifiedCardTable.get_entry(card_id)
		if not du_entry.is_empty():
			var du_uses := UnifiedCardTable.get_deploy_uses(du_entry, du_card)
			if du_uses < 99:
				var du_chip := IntelUIKit.status_chip("部署×%d/场" % du_uses, DT.COLOR_ICE_TEXT)
				du_chip.tooltip_text = "获得该卡后，每场战斗最多可部署次数"
				hbox.add_child(du_chip)

	_intel_content.add_child(panel)

	# v21.0: 改造情报小节——该形态 mod_pool 各模块的点数/阈值（已解锁金色高亮）
	if EnemyCardModMap.has_entry(card_id) and im.has_method("get_mod_intel_points"):
		_add_mod_intel_rows(card_id, im)

## v21.0: 某敌方形态的改造情报子行（mod 名 + 点数/阈值 + 图纸持有状态）
## v25.3 口径澄清："研究完成"只是情报侧进度，安装改造的真实门槛是图纸（蓝图掉落）——
## 行内并列展示两者，消灭"情报中心说解锁了、工坊却装不了"的两套解锁混淆。
## v26 UI：整组缩进 MarginContainer（替代旧 6 空格前缀），研究进度改细进度条，图纸状态改 chip。
func _add_mod_intel_rows(card_id: String, im: Node) -> void:
	var pool: Array[String] = EnemyCardModMap.get_unlockable_mods(card_id)
	if pool.is_empty():
		return
	var points_map: Dictionary = im.get_all_mod_intel_points(card_id) if im.has_method("get_all_mod_intel_points") else {}
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 26)
	indent.add_theme_constant_override("margin_right", 4)
	_intel_content.add_child(indent)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	indent.add_child(rows)
	for mid in pool:
		var mod_data: Dictionary = ModRegistry.get_data(String(mid))
		var mod_name: String = String(mod_data.get("name", String(mid)))
		var rarity: String = String(mod_data.get("rarity", "common"))
		var threshold: int = IntelModThresholds.get_threshold(rarity)
		var pts: int = int(points_map.get(String(mid), 0))
		var unlocked: bool = im.is_mod_unlocked(card_id, String(mid)) if im.has_method("is_mod_unlocked") else false
		var has_bp: bool = IntelItemBag != null and IntelItemBag.has_item("blueprint_" + String(mid))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl := IntelUIKit.label("▸ %s" % mod_name, DT.FONT_SIZE_SMALL,
			DT.COLOR_GOLD if has_bp else DT.COLOR_TEXT_MID, 150.0)
		lbl.tooltip_text = "研究进度：击败/部署该敌方形态随机获得点数，攒满 %d 点研究完成（base 情报满 100%% 时全部完成）。注意：研究完成≠可安装——安装该改造需要在工坊获得对应图纸（战后掉落）。当前图纸：%s" % [
			threshold, "已持有 ✓" if has_bp else "未获得 ✗"]
		row.add_child(lbl)
		var prog := IntelUIKit.thin_progress(float(pts) / float(maxi(threshold, 1)),
			DT.COLOR_GOLD if unlocked else DT.COLOR_ACCENT_CYAN)
		prog.custom_minimum_size = Vector2(90, 8)
		row.add_child(prog)
		var prog_lbl := IntelUIKit.label("研究完成" if unlocked else "%d/%d" % [pts, threshold],
			DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM, 64.0, HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(prog_lbl)
		var bp_chip := IntelUIKit.status_chip("图纸 ✓" if has_bp else "图纸 ✗",
			DT.COLOR_GOLD, not has_bp)
		bp_chip.tooltip_text = "安装改造需要图纸（战后掉落的消耗品）；研究进度不替代图纸"
		row.add_child(bp_chip)
		rows.add_child(row)


func _on_close() -> void:
	_on_detail_back()
	closed.emit()
