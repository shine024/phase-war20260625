extends Control
## v6.71 动态补给网 · 补给中枢面板（truck_base 工位嵌入，纯脚本面板——
## hero_archive/memorial 同款加载路径，_ensure_panel_wrapper 双路径）。
##
## 三区（计划 M3.3）：
##   补给网总览——十区域威胁条形（陷落/降级/在守计数）+ 评分总览
##   遗物架——收集度阶梯 + 开遗物箱（能量支付，pity 文案单一源）
##   迷失名册——黑门内怪物化的相位师档案（roam/garrison 来路 + 迷失日）
##
## C3：数值全读常量与 SNM API；文案全走 describe_*；无「必出」字样。
## tooltip 走 Control.tooltip_text（truck_base 工位牌内嵌场景，HoverTip 两步接
## 入仅适用 world_map 节点——此处面板内悬停一律原生 tooltip，计划口径修正记录）。

signal closed

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const SupplyThreat = preload("res://data/supply_threat.gd")
const SupplyExchange = preload("res://data/supply_exchange.gd")
const RelicRegistry = preload("res://data/relic_registry.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")

const ACCENT := Color(0.55, 0.9, 0.85)
const COL_THREAT_LOW := Color(0.45, 0.85, 0.5)
const COL_THREAT_MID := Color(0.95, 0.75, 0.3)
const COL_THREAT_HIGH := Color(0.95, 0.4, 0.35)
const COL_FALLEN := Color(0.62, 0.35, 0.85)

var _scroll: ScrollContainer
var _content: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## truck_base._open_panel 兜底刷新口（wrapper 复用时 refresh()）
func refresh() -> void:
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
		_content = null
	_build()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 620)
	var sb := PanelStyles.make_panel_frame(ACCENT)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	# ── 标题行 ──
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	root.add_child(head)
	var title := Label.new()
	title.text = "补给中枢 · 动态补给网"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(func() -> void: closed.emit())
	head.add_child(close_btn)

	# ── 滚动内容 ──
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	_build_overview_section(_content)
	_build_relic_section(_content)
	_build_lost_section(_content)


func _snm() -> Node:
	return get_node_or_null("/root/SupplyNetworkManager")


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	return l


func _desc(text: String, col: Color = DT.COLOR_TEXT_DIM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# ─────────────────────────────────────────────────────────────
#  区一：补给网总览（十区域威胁条形 + 计数）
# ─────────────────────────────────────────────────────────────

func _build_overview_section(root: VBoxContainer) -> void:
	var snm := _snm()
	root.add_child(_section_title("补给网总览"))
	if snm == null:
		root.add_child(_desc("补给网数据不可用（离线降级）"))
		return
	var fallen_n: int = 0
	var degraded_n: int = 0
	var total_n: int = SupplyThreat.REGION_COUNT * SupplyThreat.REGION_SIZE
	for lv in range(1, total_n + 1):
		match String(snm.call("get_level_state", lv)):
			"fallen":
				fallen_n += 1
			"recovered_degraded":
				degraded_n += 1
	var stat := Label.new()
	stat.text = "在守 %d · 降级 %d · 陷落 %d（共 %d 补给点）" % [
		total_n - fallen_n - degraded_n, degraded_n, fallen_n, total_n]
	stat.add_theme_font_size_override("font_size", 13)
	stat.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	root.add_child(stat)

	# 十区域威胁条（每区一行：区名/威胁值/条形/状态摘要）
	for region in range(1, SupplyThreat.REGION_COUNT + 1):
		var threat: int = int(snm.call("get_region_threat", region))
		var range_v: Vector2i = SupplyThreat.level_range_for_region(region)
		var col := COL_THREAT_LOW
		var tag := "平稳"
		if threat >= SupplyThreat.FALL_THRESHOLD - 20:
			col = COL_THREAT_HIGH
			tag = "告急"
		elif threat >= 40:
			col = COL_THREAT_MID
			tag = "紧张"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_l := Label.new()
		name_l.text = "区域 %d（%d-%d关）" % [region, range_v.x, range_v.y]
		name_l.custom_minimum_size = Vector2(150, 0)
		name_l.add_theme_font_size_override("font_size", 12)
		name_l.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		row.add_child(name_l)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = SupplyThreat.FALL_THRESHOLD
		bar.value = threat
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(320, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bar_sb := StyleBoxFlat.new()
		bar_sb.set_corner_radius_all(4)
		bar_sb.bg_color = Color(0.12, 0.13, 0.16)
		bar.add_theme_stylebox_override("background", bar_sb)
		var fill_sb := StyleBoxFlat.new()
		fill_sb.set_corner_radius_all(4)
		fill_sb.bg_color = col
		bar.add_theme_stylebox_override("fill", fill_sb)
		row.add_child(bar)
		var val_l := Label.new()
		val_l.text = "%d/%d · %s" % [threat, SupplyThreat.FALL_THRESHOLD, tag]
		val_l.custom_minimum_size = Vector2(110, 0)
		val_l.add_theme_font_size_override("font_size", 12)
		val_l.add_theme_color_override("font_color", col)
		row.add_child(val_l)
		root.add_child(row)
	root.add_child(_desc("威胁每日自然增长（时代越深增速越快）；清除渗透 −%d、收复陷落 −%d、日常巡逻 −%d。到达 %d 即有补给点陷落（防御最低者先失守）。" % [
		SupplyThreat.CLEAR_INCURSION_RELIEF, SupplyThreat.RECONQUEST_RELIEF,
		SupplyThreat.NO_INCURSION_DECAY, SupplyThreat.FALL_THRESHOLD]))


# ─────────────────────────────────────────────────────────────
#  区二：遗物架（收集阶梯 + 开遗物箱）
# ─────────────────────────────────────────────────────────────

func _build_relic_section(root: VBoxContainer) -> void:
	var snm := _snm()
	root.add_child(_section_title("遗物架"))
	if snm == null:
		root.add_child(_desc("遗物数据不可用"))
		return
	var owned: Array = snm.call("get_owned_relic_ids")
	var total_count: int = RelicRegistry.RELICS.size()
	var milestones: Dictionary = RelicRegistry.COLLECTION_MILESTONES
	var sum_l := Label.new()
	sum_l.text = "收集度 %d / %d — 阶梯：5 件=兑换折扣+%d%% · 10 件=异族战资源+%d%% · %d 件=燃料效率+%d%% · %d 件=威胁日增−%d" % [
		owned.size(), total_count,
		int(milestones.get(5, {}).get("exchange_discount", 0)),
		int(milestones.get(10, {}).get("xeno_bonus", 0)),
		18, int(milestones.get(18, {}).get("fuel_efficiency", 0)),
		24, int(milestones.get(24, {}).get("threat_slow", 0))]
	sum_l.add_theme_font_size_override("font_size", 12)
	sum_l.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	sum_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(sum_l)

	# 遗物格阵（拥有=亮格 tooltip 效果；未拥有=暗格 tooltip 线索）
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	root.add_child(grid)
	for relic in RelicRegistry.RELICS:
		var rid: String = String(relic.get("id", ""))
		var has: bool = rid in owned
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(140, 40)
		var csb := StyleBoxFlat.new()
		csb.set_corner_radius_all(8)
		csb.bg_color = Color(0.16, 0.22, 0.22, 1.0) if has else Color(0.10, 0.10, 0.12, 1.0)
		csb.border_color = ACCENT if has else Color(0.25, 0.25, 0.28)
		csb.set_border_width_all(2 if has else 1)
		cell.add_theme_stylebox_override("panel", csb)
		var tag := Label.new()
		tag.text = String(relic.get("name", "？"))
		tag.set_anchors_preset(Control.PRESET_FULL_RECT)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", ACCENT if has else Color(0.35, 0.35, 0.38))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(tag)
		if has:
			cell.tooltip_text = "%s · %s" % [String(relic.get("desc", "")), RelicRegistry.describe_effect(relic)]
		else:
			cell.tooltip_text = "未获得 · %s系遗物（收复陷落与考评兑换可得）" % String(relic.get("era", ""))
		grid.add_child(cell)

	# 遗物效果总览（遗物箱不是库存——roll 到即开，入口在关卡兑换与考评货架）
	root.add_child(_desc("遗物箱从关卡兑换与考评货架获得；连续 %d 次未出时概率提升（软保底，%s）。" % [
		SupplyExchange.PITY_THRESHOLD, SupplyExchange.describe_box_pity(int(snm.get("exchange_pity")))]))
	var eff := Label.new()
	eff.text = "当前效果合计：兑换折扣+%d%% · 异族战资源+%d%% · 燃料效率+%d%% · 威胁日增−%d" % [
		snm.call("get_relic_effect_sum", "exchange_discount"),
		snm.call("get_relic_effect_sum", "salvage_rate"),
		snm.call("get_relic_effect_sum", "fuel_efficiency"),
		snm.call("get_relic_effect_sum", "threat_slow")]
	eff.add_theme_font_size_override("font_size", 12)
	eff.add_theme_color_override("font_color", Color(0.75, 0.95, 0.9))
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(eff)


# ─────────────────────────────────────────────────────────────
#  区三：迷失名册（黑门怪物化的相位师档案）
# ─────────────────────────────────────────────────────────────

func _build_lost_section(root: VBoxContainer) -> void:
	var snm := _snm()
	root.add_child(_section_title("迷失名册"))
	if snm == null:
		root.add_child(_desc("名册数据不可用"))
		return
	var lost: Array = snm.call("get_lost_overview")
	if lost.is_empty():
		root.add_child(_desc("尚无相位师迷失。固守失守的战友与走进黑门的游猎者，都会在门中留下怪物般的轮廓……"))
		return
	root.add_child(_desc("他们没能回来。名字留在册上，身影只在黑门深处出现——（迷失的相位师会成为黑门变体 boss，每 %d 波现身一次）" % 40,
		Color(0.75, 0.6, 0.85)))
	for entry in lost:
		var mid: String = String(entry.get("master_id", ""))
		var origin: String = String(entry.get("origin", ""))
		var day: int = int(entry.get("lost_day", 0))
		# 池内双形态：游猎者存 NPC 名，驻守者存 enemy master_id——后者反查显示名
		var display: String = mid
		var master: Dictionary = EnemyPhaseMasters.get_master_by_id(mid)
		if not master.is_empty():
			display = String(master.get("name", mid))
		var row := Label.new()
		row.text = "☠ %s —— %s%s" % [
			display,
			"游猎途中步入黑门" if origin == "roam" else "驻守补给点失守后被吞没",
			"（第 %d 日）" % day if day > 0 else ""]
		row.add_theme_font_size_override("font_size", 12)
		row.add_theme_color_override("font_color", Color(0.8, 0.65, 0.9))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(row)
