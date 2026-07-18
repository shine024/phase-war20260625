extends RefCounted
class_name GeoShapes
## v7.x UI 重设计几何控件集合。
##
## 容器是纯 RefCounted（被 const preload 作命名空间），内部两个 inner class
## 各自继承 Control，供面板 `GeoShapes.HexagonSlot.new()` / `GeoShapes.TierLadder.new()`
## 实例化后挂到节点树。配色统一走 DesignTokens（DT），档位名/色走 PowerTiers。
##
## 消费方（调用点签名以 card_enhancement_panel.gd / modification_panel.gd 为准）：
##   - HexagonSlot.new() → .accent_color = DT.COLOR_AMBER → .set_data(state, name, level, lock_label="")
##   - TierLadder.new() → .set_data(current_tier, required_tier, card_power)

const DT = preload("res://resources/design_tokens.gd")
const PowerTiers = preload("res://data/power_tiers.gd")


# ============================================================
# HexagonSlot —— 蜂巢词条槽（强化面板 5 格）
# ============================================================
# 用法：const GeoShapes = preload(...)
#       var hex = GeoShapes.HexagonSlot.new()
#       hex.accent_color = DT.COLOR_AMBER
#       hex.set_data(GeoShapes.HexagonSlot.State.FILLED, "词条名", 2)
class HexagonSlot extends Control:
	enum State { LOCKED, EMPTY, FILLED }

	# accent 由消费方在 set_data 前赋值（强化面板用 COLOR_AMBER）
	var accent_color: Color = Color(0.961, 0.620, 0.043, 1)

	var _state: int = State.LOCKED
	var _label: String = ""
	var _level: int = 0
	var _lock_label: String = ""

	func _init() -> void:
		# 蜂巢六边形的最小包围盒：宽 56 / 高 64 留出文字空间
		custom_minimum_size = Vector2(56, 64)

	## 统一数据入口（3 参/4 参兼容，lock_label 缺省空串）。
	## LOCKED   显示锁标 + lock_label（如 "LV.4"）
	## EMPTY    显示提示（_label，如 "即将解锁"）
	## FILLED   显示词条名 + Lv.x
	func set_data(state: int, label: String, level: int, lock_label: String = "") -> void:
		_state = clampi(state, State.LOCKED, State.FILLED)
		_label = label
		_level = int(level)
		_lock_label = lock_label
		queue_redraw()

	func _draw() -> void:
		var size_v: Vector2 = get_size()
		if size_v.x < 2.0 or size_v.y < 2.0:
			return
		# 六边形中心、半径（取宽高较小者的 0.42 倍，留出文字区）
		var center: Vector2 = Vector2(size_v.x * 0.5, size_v.y * 0.42)
		var r: float = minf(size_v.x, size_v.y * 0.8) * 0.42
		var pts := _hex_points(center, r)

		# 按 state 配色
		var fill: Color
		var edge: Color
		var text_color: Color
		match _state:
			State.LOCKED:
				fill = DT.COLOR_SLOT_LOCKED
				edge = DT.COLOR_BORDER_DIM
				text_color = DT.COLOR_TEXT_FAINT
			State.EMPTY:
				fill = DT.COLOR_CARD
				edge = Color(accent_color.r, accent_color.g, accent_color.b, 0.55)
				text_color = DT.COLOR_TEXT_DIM
			State.FILLED:
				fill = Color(accent_color.r, accent_color.g, accent_color.b, 0.85)
				edge = accent_color
				text_color = Color(0.05, 0.06, 0.10, 1)
			_:
				fill = DT.COLOR_SLOT_LOCKED
				edge = DT.COLOR_BORDER_DIM
				text_color = DT.COLOR_TEXT_FAINT

		# 六边形主体
		draw_colored_polygon(pts, fill)
		# 描边（line_strip 需首尾闭合）
		var edge_pts := pts.duplicate()
		edge_pts.append(pts[0])
		for i in range(edge_pts.size() - 1):
			draw_line(edge_pts[i], edge_pts[i + 1], edge, 1.5)

		# 中心圆点（FILLED 状态外环强调，其余淡化）
		var dot_r: float = 3.0
		draw_circle(center, dot_r, text_color if _state == State.FILLED else edge)

		# 文字区（六边形下方 0.5y~1.0y）
		var text_area_center: Vector2 = Vector2(size_v.x * 0.5, size_v.y * 0.78)
		var main_text: String = ""
		var sub_text: String = ""
		match _state:
			State.LOCKED:
				# 不用 emoji（emoji 在 Rajdhani 字体下易渲染为豆腐块），统一用文字
				main_text = _lock_label if not _lock_label.is_empty() else "锁"
			State.EMPTY:
				main_text = _label if not _label.is_empty() else "+"
			State.FILLED:
				main_text = _label
				if _level > 0:
					sub_text = "Lv.%d" % _level

		if not main_text.is_empty():
			draw_string(_font_for_state(), text_area_center - Vector2(0, 6), main_text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 11, text_color)
		if not sub_text.is_empty():
			draw_string(_font_for_state(), text_area_center + Vector2(0, 12), sub_text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 9, text_color)

	# 平顶六边形顶点（顶部水平边，尖角朝左右）
	static func _hex_points(center: Vector2, r: float) -> PackedVector2Array:
		var arr := PackedVector2Array()
		# 平顶六边形角度：0, 60, 120, 180, 240, 300 度
		for i in range(6):
			var ang: float = deg_to_rad(60.0 * i)
			arr.append(Vector2(center.x + r * cos(ang), center.y + r * sin(ang)))
		return arr

	func _font_for_state() -> Font:
		# 用 DesignTokens 的正文字体（Rajdhani Regular），失败回退系统
		return DT.get_body_font()


# ============================================================
# TierLadder —— 战力档位阶梯条（改造面板 5 档）
# ============================================================
# 用法：var ladder = GeoShapes.TierLadder.new()
#       ladder.set_data(current_tier, required_tier, card_power)
# 5 档 GRUNT/VETERAN/ELITE/CHAMPION/OVERLORD，当前档高亮、要求档金边描边。
class TierLadder extends Control:
	var _current: int = 0
	var _required: int = 0
	var _power: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 42)

	func set_data(current_tier: int, required_tier: int, card_power: int) -> void:
		_current = clampi(current_tier, 0, 4)
		_required = clampi(required_tier, 0, 4)
		_power = maxi(0, card_power)
		queue_redraw()

	func _draw() -> void:
		var size_v: Vector2 = get_size()
		if size_v.x < 4.0 or size_v.y < 4.0:
			return
		# 5 段水平排列，段间 3px 间隔
		var gap: float = 3.0
		var seg_w: float = maxf(8.0, (size_v.x - gap * 4.0) / 5.0)
		var bar_h: float = 14.0
		var top_margin: float = 4.0
		var x: float = 0.0
		for tier in range(5):
			var rect := Rect2(x, top_margin, seg_w, bar_h)
			var base_color: Color = PowerTiers.get_tier_color(tier)
			var fill: Color
			var border: Color
			var border_w: float = 1.0
			if tier < _current:
				# 已达成档：满色
				fill = base_color
				border = base_color.darkened(0.2)
			elif tier == _current:
				# 当前档：accent 高亮 + 加粗描边
				fill = base_color.lightened(0.1)
				border = DT.COLOR_AMBER_SOFT
				border_w = 2.0
			else:
				# 未达档：灰化
				fill = Color(base_color.r * 0.3, base_color.g * 0.3, base_color.b * 0.3, 0.5)
				border = DT.COLOR_BORDER_DIM
			draw_rect(rect, fill, true)
			draw_rect(rect, border, false, border_w)

			# 要求档：金色虚线描边提示（用加粗金边，draw_rect 不支持虚线，用双层表达）
			if tier == _required and _required != _current:
				var gold_rect := rect.grow(2.0)
				draw_rect(gold_rect, DT.COLOR_GOLD, false, 1.5)

			# 档位中文名（缩写，避免窄段溢出）
			var name_str: String = String(PowerTiers.TIER_NAMES.get(tier, "?"))
			var short_name: String = name_str.substr(0, 1) if name_str.length() > 0 else "?"
			draw_string(_font(), rect.position + Vector2(rect.size.x * 0.5, bar_h + 14), short_name,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 9,
				DT.COLOR_AMBER_SOFT if tier == _current else DT.COLOR_TEXT_FAINT)

			x += seg_w + gap

		# 战力数值（右上角）
		var power_text: String = "战力 %d" % _power
		draw_string(_font(), Vector2(size_v.x, 2.0), power_text,
			HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, DT.COLOR_TEXT_FAINT)

	func _font() -> Font:
		return DT.get_body_font()
