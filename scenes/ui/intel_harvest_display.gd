extends PanelContainer
class_name IntelHarvestDisplay
## v6.7: 战斗结算中的情报收获展示组件（单维度化）
## 每个被击败敌人显示 1 条情报进度条 + 第N次击败 +X% + 揭示标签
##
## 使用方式：
##   var ui = IntelHarvestDisplay.new()
##   ui.set_data(harvest_data)
##   parent.add_child(ui)
##
## v26 UI：视觉层收口 IntelUIKit（签名竖条标题 + 统一行卡 + token 化配色），
## 替代旧 12+ 处手写 Color 字面量与硬编码 13px 字号——数据/性能逻辑不变。

const DT = preload("res://resources/design_tokens.gd")
# 批次三 B10：字号 token 引入（10px 白名单/中文升 12）
const IntelDimensions = preload("res://data/intel_dimensions.gd")
const IntelUIKit = preload("res://scenes/ui/components/intel_ui_kit.gd")

## v7.x 性能：情报条目渲染上限。超过此数量的敌人不再各自建节点（每条节点是
## PanelContainer+StyleBox+VBox+HBox+多Label+ProgressBar，50敌人≈300+节点），
## 末尾追加一行"…另 +N 种敌人"折叠。前 N 条通常覆盖主要敌人类型，完整列表在情报手册查看。
const MAX_VISIBLE_ENTRIES: int = 15

var _card_entries: Array[Dictionary] = []
var _reveal_events: Array[Dictionary] = []
var _intel_item_drops: Array = []
var _im: Node = null  ## IntelManual引用
## v7.x 性能：显示名缓存。同卡种敌人只查一次 EnemyArchetypes/DefaultCards 表（133卡）。
var _display_name_cache: Dictionary = {}

func _ready() -> void:
	_im = get_node_or_null("/root/IntelManual")
	_build_initial_ui()

func _build_initial_ui() -> void:
	# v26 UI：容器卡统一情报家族语言（深卡底 + 紫签名描边 + 圆角4）
	add_theme_stylebox_override("panel",
		IntelUIKit.list_row_style(DT.COLOR_VIOLET, false))

## 设置情报收获数据（由战斗结算调用）
## data格式: {"harvests": [...], "reveal_events": [...], "intel_item_drops": [...]}
func set_data(data: Dictionary) -> void:
	_card_entries.clear()
	for d in data.get("harvests", []):
		_card_entries.append(d)
	_reveal_events.clear()
	for d in data.get("reveal_events", []):
		_reveal_events.append(d)
	_intel_item_drops.clear()
	for d in data.get("intel_item_drops", []):
		_intel_item_drops.append(d)
	_refresh_ui()

func _refresh_ui() -> void:
	## 清除旧内容
	for child in get_children():
		if child.name != "_style_placeholder":
			child.queue_free()

	if _card_entries.is_empty() and _reveal_events.is_empty() and _intel_item_drops.is_empty():
		return

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	outer.name = "HarvestContent"

	## 标题（签名竖条 + 计数右对齐，与情报中心同语言）
	var count_text := "%d 种敌人" % _card_entries.size() if not _card_entries.is_empty() else ""
	outer.add_child(IntelUIKit.section_header("情报收获", DT.COLOR_VIOLET, count_text))

	## 按敌人分组显示（限流：超过 MAX_VISIBLE_ENTRIES 后折叠，避免高波次关卡节点爆炸）
	var shown_count: int = 0
	for entry in _card_entries:
		if not entry is Dictionary:
			continue
		if shown_count >= MAX_VISIBLE_ENTRIES:
			break
		var card_box := _create_card_entry(entry)
		outer.add_child(card_box)
		shown_count += 1
	## 折叠提示：超出上限的敌人种类
	var hidden_count: int = _card_entries.size() - shown_count
	if hidden_count > 0:
		outer.add_child(IntelUIKit.label(
			"…另 +%d 种敌人（详见 情报舱·敌方情报）" % hidden_count,
			DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM))

	## 情报道具掉落展示
	if not _intel_item_drops.is_empty():
		outer.add_child(IntelUIKit.section_header("情报道具", DT.COLOR_RES_RESEARCH))
		for item in _intel_item_drops:
			if not item is Dictionary:
				continue
			var item_row := HBoxContainer.new()
			item_row.add_theme_constant_override("separation", 8)
			item_row.add_child(IntelUIKit.label(String(item.get("name", "未知道具")),
				DT.FONT_SIZE_SMALL, DT.COLOR_RES_RESEARCH, 120.0))
			var desc_lbl := IntelUIKit.label(String(item.get("desc", "")),
				DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM)
			desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			item_row.add_child(desc_lbl)
			outer.add_child(item_row)

	add_child(outer)

## 创建单个敌人的情报条目（单维度：1条进度条）
func _create_card_entry(entry: Dictionary) -> PanelContainer:
	var box := PanelContainer.new()
	# v26 UI：行卡统一——首次遭遇青色描边（新数据语义），重复遭遇中性灰
	var is_first: bool = entry.get("first_encounter", false)
	box.add_theme_stylebox_override("panel",
		IntelUIKit.list_row_style(DT.COLOR_ACCENT_CYAN if is_first else DT.COLOR_BORDER, false))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)

	## 敌人名称行
	var card_id: String = entry.get("card_id", "")
	var enemy_type: String = entry.get("enemy_type", "")

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)

	var name_lbl := IntelUIKit.label(_get_enemy_display_name(card_id, enemy_type),
		DT.FONT_SIZE_BODY, DT.COLOR_TEXT_BRIGHT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	## 首次遭遇 chip（替代旧「◆」图标 + 「[首次遭遇]」行内文本）
	if is_first:
		name_row.add_child(IntelUIKit.status_chip("首次遭遇", DT.COLOR_ACCENT_CYAN))

	## 击败次数（若有）
	if _im and card_id != "":
		var defeat_count: int = _im.get_defeat_count(card_id) if _im.has_method("get_defeat_count") else 0
		if defeat_count > 0:
			name_row.add_child(IntelUIKit.label("第%d次击败" % defeat_count,
				DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM))
	vbox.add_child(name_row)

	## 单维度进度条
	var dims: Dictionary = entry.get("dimensions", {})
	var delta: float = 0.0
	if dims.has("intel"):
		## 合并后结构：{"intel": {"old_val":..,"new_val":..,"delta":..}}
		var dim_val: Variant = dims["intel"]
		if dim_val is Dictionary:
			delta = float(dim_val.get("delta", 0.0))
		elif dim_val is float or dim_val is int:
			delta = float(dim_val)
	elif dims.size() > 0:
		## 兜底：旧格式可能残留多 key，取总和
		for k in dims:
			var v: Variant = dims[k]
			if v is Dictionary:
				delta += float(v.get("delta", 0.0))
			else:
				delta += float(v)

	if delta >= 0.001:
		var progress_row := _create_progress_row(card_id, enemy_type, delta)
		vbox.add_child(progress_row)

	## v21.0: 本次击败获得的改造情报点数（intel_discovery_manager 写入的 "mod_points" 键）
	var mod_points: int = int(entry.get("mod_points", 0))
	if mod_points > 0:
		var mp_lbl := IntelUIKit.label("改造情报 +%d 点" % mod_points,
			DT.FONT_SIZE_SMALL, DT.COLOR_GREEN_UP)
		mp_lbl.tooltip_text = "点数随机落入该敌方形态的专属改造池，攒满阈值即解锁（详见情报手册）"
		vbox.add_child(mp_lbl)

	return box

## 创建单维度进度条行
func _create_progress_row(card_id: String, enemy_type: String, delta: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	## 进度条（v26 UI：统一细进度条，宽度弹性填充）
	var progress: ProgressBar = IntelUIKit.thin_progress(0.0, IntelDimensions.DIM_COLORS[IntelDimensions.DIM_INTEL])
	progress.custom_minimum_size = Vector2(180, 8)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	## 获取当前情报值
	var current_pct: float = 0.0
	if _im and _im.has_method("get_intel_progress"):
		current_pct = _im.get_intel_progress(card_id) * 100.0
	progress.value = current_pct / 100.0
	row.add_child(progress)

	## 百分比文本（定宽对齐）
	row.add_child(IntelUIKit.label("%.0f%%" % current_pct,
		DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_MID, 36.0, HORIZONTAL_ALIGNMENT_RIGHT))

	## 增长量（提升绿 token）
	row.add_child(IntelUIKit.label("+%.0f%%" % (delta * 100.0),
		DT.FONT_SIZE_SMALL, DT.COLOR_GREEN_UP, 40.0))

	## 揭示检查：该敌人本次是否有新揭示（chip 替代旧「✦新揭示!」文本）
	var has_reveal: bool = false
	for rev in _reveal_events:
		var rev_card: String = rev.get("card_id", "")
		if rev_card == card_id:
			has_reveal = true
			break
	if has_reveal:
		row.add_child(IntelUIKit.status_chip("新揭示", DT.COLOR_GOLD))

	return row

## 获取敌人显示名称
func _get_enemy_display_name(card_id: String, enemy_type: String) -> String:
	## v7.x 性能：缓存命中优先。结算面板按敌人列表逐条取显示名，同卡种敌人会重复
	## 查 EnemyArchetypes(36单位) + DefaultCards(133卡) 两张表，缓存后只查一次。
	if not card_id.is_empty() and _display_name_cache.has(card_id):
		return String(_display_name_cache[card_id])
	## 优先从EnemyArchetypes获取名称
	if not card_id.is_empty():
		var config: Dictionary = EnemyArchetypes.get_config(card_id)
		if not config.is_empty():
			var dn: String = config.get("display_name", "")
			_display_name_cache[card_id] = dn
			return dn
	## 尝试DefaultCards.get_safe_display_name（依次查DefaultCards→EnemyArchetypes）
	if not card_id.is_empty():
		var safe: String = _get_default_cards().get_safe_display_name(card_id)
		if not safe.is_empty() and safe != card_id:
			_display_name_cache[card_id] = safe
			return safe
	## 兜底（不缓存：enemy_type 推导结果，与 card_id 非一一对应）
	match enemy_type:
		"infantry": return "步兵部队"
		"flame": return "火焰兵"
		"heavy_armor": return "重装甲"
		"artillery": return "火炮单位"
		"stealth": return "隐匿单位"
		"air": return "空中单位"
		"boss_nano": return "纳米核心"
		"boss_phase": return "相位师"
		_: return card_id if not card_id.is_empty() else "未知敌人"

## 获取DefaultCards脚本引用
func _get_default_cards() -> GDScript:
	return preload("res://data/default_cards.gd")
