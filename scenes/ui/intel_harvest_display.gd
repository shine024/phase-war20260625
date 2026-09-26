extends PanelContainer
class_name IntelHarvestDisplay
## v6.7: 战斗结算中的情报收获展示组件（单维度化）
##
## v6.14 重构（2026-09-14 实测反馈"结算面板太复杂"）：事件化摘要——
##   只把"有事件"的敌人列成单行（首次遭遇 / 新揭示 / 跨过情报档 25·50·75·100%），
##   其余常规击败折成一行汇总；逐行进度条与卡片底移除（绝对进度是"翻阅型"信息，
##   归 情报舱·敌方情报）。新揭示/改造解锁的精致弹窗（mvp_panel 侧）保持不变。
##
## 使用方式：
##   var ui = IntelHarvestDisplay.new()
##   ui.set_data(harvest_data)
##   parent.add_child(ui)

const DT = preload("res://resources/design_tokens.gd")
const IntelUIKit = preload("res://scenes/ui/components/intel_ui_kit.gd")

## 情报档位（与 ManufacturePools 制造门/品质档同口径：25 配方门 / 50 / 75 / 100 满档）
const TIER_MARKS: Array[float] = [0.25, 0.50, 0.75, 1.0]
## 事件行渲染上限（首遇潮关卡兜底；超出折叠计数）
const MAX_EVENT_ROWS: int = 12

var _card_entries: Array[Dictionary] = []
var _reveal_events: Array[Dictionary] = []
var _intel_item_drops: Array = []
var _im: Node = null  ## IntelManual 引用
## v7.x 性能：显示名缓存。同卡种敌人只查一次 EnemyArchetypes/DefaultCards 表。
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

	# 汇总统计（总数 / 增量 / 改造情报点）
	var total_delta := 0.0
	var total_points := 0
	for entry in _card_entries:
		if not entry is Dictionary:
			continue
		total_delta += _entry_delta(entry)
		total_points += int(entry.get("mod_points", 0))

	## 标题（签名竖条 + 计数右对齐）
	var count_text := ""
	if not _card_entries.is_empty():
		count_text = "%d 种敌人 · 共 +%d%%" % [_card_entries.size(), roundi(total_delta * 100.0)]
	outer.add_child(IntelUIKit.section_header("情报收获", DT.COLOR_VIOLET, count_text))

	# 事件分类：首次遭遇 / 新揭示 / 跨档 → 单行列出；其余进常规汇总
	var event_rows: Array = []   # [{"entry":.., "crossed": float(-1=无)}]
	var regular_count := 0
	var regular_delta := 0.0
	for entry in _card_entries:
		if not entry is Dictionary:
			continue
		var crossed := _crossed_tier_mark(entry)
		var is_event: bool = bool(entry.get("first_encounter", false)) \
				or _has_reveal(entry) or crossed >= 0.0
		if is_event:
			event_rows.append({"entry": entry, "crossed": crossed})
		else:
			regular_count += 1
			regular_delta += _entry_delta(entry)

	var shown := 0
	for row_info in event_rows:
		if shown >= MAX_EVENT_ROWS:
			break
		outer.add_child(_create_event_row(row_info["entry"], float(row_info["crossed"])))
		shown += 1
	if event_rows.size() > shown:
		outer.add_child(IntelUIKit.label("…另有 %d 条事件" % (event_rows.size() - shown),
			DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM))

	# 常规汇总行（含明细指引；全事件仗也给指引）
	if regular_count > 0:
		outer.add_child(IntelUIKit.label(
			"常规击败 %d 种 · 情报 +%d%%（明细见 情报舱·敌方情报）"
				% [regular_count, roundi(regular_delta * 100.0)],
			DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM))
	elif not _card_entries.is_empty():
		outer.add_child(IntelUIKit.label("明细见 情报舱·敌方情报",
			DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM))

	# 改造情报聚合（原逐行"改造情报 +N 点"收拢为一行）
	if total_points > 0:
		var mp_lbl := IntelUIKit.label("改造情报共 +%d 点" % total_points,
			DT.FONT_SIZE_SMALL, DT.COLOR_GREEN_UP)
		mp_lbl.tooltip_text = "点数随机落入各敌形专属改造池，攒满阈值即解锁（详见情报手册）"
		outer.add_child(mp_lbl)

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

## ── 事件判定 / 数值助手 ──────────────────────────────────

## 本次情报增量（兼容 dict 形 {"old_val","new_val","delta"} 与旧纯 float 形）
func _entry_delta(entry: Dictionary) -> float:
	var dims: Dictionary = entry.get("dimensions", {})
	if not dims is Dictionary or dims.is_empty():
		return 0.0
	var dim_val: Variant = dims.get("intel", null)
	if dim_val is Dictionary:
		return float(dim_val.get("delta", 0.0))
	elif dim_val is float or dim_val is int:
		return float(dim_val)
	## 兜底：旧格式可能残留多 key，取总和
	var sum := 0.0
	for k in dims:
		var v: Variant = dims[k]
		if v is Dictionary:
			sum += float(v.get("delta", 0.0))
		else:
			sum += float(v)
	return sum

## 战后该敌形情报新值（百分数）。优先用 harvest 自带的 new_val（结算时点已定格），
## 无 dict 形时回退查 IntelManual 实时值；两路都不可得返回 -1（未知）。
func _new_pct(entry: Dictionary) -> float:
	var dims: Dictionary = entry.get("dimensions", {})
	if dims is Dictionary:
		var dim_val: Variant = dims.get("intel", null)
		if dim_val is Dictionary and dim_val.has("new_val"):
			return clampf(float(dim_val["new_val"]), 0.0, 1.0) * 100.0
	var card_id := String(entry.get("card_id", ""))
	if _im != null and not card_id.is_empty() and _im.has_method("get_base_progress"):
		return clampf(float(_im.get_base_progress(card_id)), 0.0, 1.0) * 100.0
	return -1.0

## 本次跨过的最高情报档位（0-1；无跨档返回 -1）。
## 档位与 ManufacturePools 制造门/品质池同口径——跨档=制造供给发生变化，值得玩家知道。
func _crossed_tier_mark(entry: Dictionary) -> float:
	var delta := _entry_delta(entry)
	if delta <= 0.0001:
		return -1.0
	var new_pct := _new_pct(entry)
	if new_pct < 0.0:
		return -1.0
	var old_pct := new_pct - delta * 100.0
	var best := -1.0
	for m in TIER_MARKS:
		var t: float = m * 100.0
		if old_pct < t and new_pct >= t:
			best = maxf(best, m)
	return best


## 记录3#13：本次是否跨过制造配方门（25% 档）——跨过即该敌形战斗卡"新卡可制造"。
## 与 _crossed_tier_mark 的"最高跨档"不同：从 10% 直跨到 60% 也算跨过配方门。
func _crossed_recipe_gate(entry: Dictionary) -> bool:
	var delta := _entry_delta(entry)
	if delta <= 0.0001:
		return false
	var new_pct := _new_pct(entry)
	if new_pct < 0.0:
		return false
	var old_pct := new_pct - delta * 100.0
	return old_pct < 25.0 and new_pct >= 25.0

func _has_reveal(entry: Dictionary) -> bool:
	var card_id := String(entry.get("card_id", ""))
	for rev in _reveal_events:
		if String(rev.get("card_id", "")) == card_id:
			return true
	return false

## 单行事件行：名字 [首次遭遇][新揭示][跨N%档] …… +X% → Y%
func _create_event_row(entry: Dictionary, crossed: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var card_id := String(entry.get("card_id", ""))
	var name_lbl := IntelUIKit.label(
		_get_enemy_display_name(card_id, String(entry.get("enemy_type", ""))),
		DT.FONT_SIZE_BODY, DT.COLOR_TEXT_BRIGHT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)

	# 事件 chip（首遇=新数据语义青、揭示=金、跨档=供给扩展绿）
	if bool(entry.get("first_encounter", false)):
		row.add_child(IntelUIKit.status_chip("首次遭遇", DT.COLOR_ACCENT_CYAN))
	if _has_reveal(entry):
		row.add_child(IntelUIKit.status_chip("新揭示", DT.COLOR_GOLD))
	if crossed >= 0.0:
		row.add_child(IntelUIKit.status_chip("跨 %d%% 档" % roundi(crossed * 100.0),
			DT.COLOR_GREEN_UP))
	# 记录3#13：跨配方门（25%）= 该敌形的战斗卡进入制造目录——原只显"跨 25% 档"
	# 玩家读不懂，用户拍板加明示 chip（原揭示弹窗已并入本行显示）
	if _crossed_recipe_gate(entry):
		row.add_child(IntelUIKit.status_chip("★ 新卡可制造", DT.COLOR_GOLD))

	# 增量（绿）+ 战后新值（右对齐定宽；旧值不可得时省略箭头段）
	row.add_child(IntelUIKit.label("+%d%%" % roundi(_entry_delta(entry) * 100.0),
		DT.FONT_SIZE_SMALL, DT.COLOR_GREEN_UP, 44.0, HORIZONTAL_ALIGNMENT_RIGHT))
	var new_pct := _new_pct(entry)
	if new_pct >= 0.0:
		row.add_child(IntelUIKit.label("→ %d%%" % roundi(new_pct),
			DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_MID, 60.0, HORIZONTAL_ALIGNMENT_RIGHT))
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
