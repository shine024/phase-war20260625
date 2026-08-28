extends Control
## ═══════════════════════════════════════════════════════════
##  相位师技能树 · 电路板主板渲染（v22 方案3 重设计）
##
##  单板三轨：指挥(蓝)/智能化(绿)/火力(橙红)三条竖轨并排，
##  tier 0-15 自上而下递进，跨系前置走线全部可见。
##  「奇点解算」门关在智能轨 t3，三系 t2 走线汇聚——星型拓扑。
##
##  结构（自底向上）：
##    SubstrateLayer  基板（深空底 + 过孔点阵 + tier 标尺，静态画一次）
##    TraceLayer      走线层（一条 requires 边 = 一条走线，状态变化重绘）
##    ChipWidget×74   芯片（封装/边框/管芯/引脚/名称/成本，三态换装）
##    SparkDot        解锁瞬间的沿线光点（临时，最顶层）
##
##  走线规则：
##    - 触及奇点节点的边 = 紫色奇点走线；其余 = 子节点分支色
##    - 通电判定 = 源节点已解锁（目标未解锁时电止于引脚："电到门口没进芯"）
##    - 同轨上下层：45° 肘折线；同层并列：水平直连；
##      跨轨：经轨间通道（±6px 子通道错开），曼哈顿 + 8px 45° 倒角
##
##  布局纯计算生成（branch/tier/槽位 → 坐标），无手调坐标表；
##  数据表加节点自动排入。芯片构建一次，状态刷新只换装不重建。
## ═══════════════════════════════════════════════════════════

const DT = preload("res://resources/design_tokens.gd")
const SkillTree = preload("res://data/phase_master_skill_tree.gd")

signal chip_clicked(node_id: String)

enum ChipState { LOCKED, STANDBY, POWERED }

## 器件封装风格 = 解锁内容类型（差异化轴）：
##   QFN 方片=数值强化 · MODULE 八角=兵种机制/能力 · DIP 双列=战法 ·
##   CAN 圆罐=卡片技能 · QFP 双框=进化形态 · 奇点=管芯紫色菱形◈（叠加于任意封装）
enum ChipStyle { QFN, MODULE, DIP, CAN, QFP }

# ── 几何常量（面板据此对齐轨道标题行）──
const CHIP := 66                 # 芯片边长
const SLOT_PITCH := 72           # 槽间距 = 66 + 6
const LANE_SLOTS := 4            # 每轨槽位（智能 t9 / 火力 t7 各 4 芯片为最宽行）
const LANE_W := LANE_SLOTS * CHIP + (LANE_SLOTS - 1) * (SLOT_PITCH - CHIP)  # 282
const LANE_GAP := 14             # 轨间通道宽
const RULER_W := 20              # 左侧 tier 标尺列
const MARGIN_L := 6
const MARGIN_R := 6
const ROW_H := 104               # 66 芯片 + 16 名称带 + 22 走线空间
const HEADER_H := 40
const TIERS := 16
const BOARD_W := MARGIN_L + RULER_W + LANE_W * 3 + LANE_GAP * 2 + MARGIN_R
const BOARD_H := HEADER_H + ROW_H * TIERS + 14

## 轨道顺序：智能居中（奇点解算门关所在），指挥左 / 火力右
const LANE_ORDER: Array = [
	SkillTree.BRANCH_COMMAND,
	SkillTree.BRANCH_INTELLIGENCE,
	SkillTree.BRANCH_FIREPOWER,
]

const PIN_OFFSETS: Array = [-14, 0, 14]   # 每侧 3 引脚的偏移
const CHAMFER := 8.0                       # 45° 倒角边长

# ── 电路结构件配色（结构中性色；语义色一律走 DesignTokens / 分支色 / 奇点紫）──
const PIN_METAL := Color(0.32, 0.40, 0.52, 1)     # 引脚金属（亮铁灰）
const DIE_DARK := Color(0.14, 0.19, 0.29, 1)      # 断路管芯
const TRACE_DEAD := Color(0.19, 0.24, 0.36, 1)    # 断路走线
const GRID_LINE := Color(1.0, 1.0, 1.0, 0.05)     # 层分隔线

# id -> {lane, slot, tier, x, y, chip, node}
var _node_geo: Dictionary = {}
# 边列表 [{from, to, a_pin, b_pin, ch_off, a_side, b_side}]
var _edges: Array = []
var _trace_layer: TraceLayer = null
var _selected_id: String = ""


func _init() -> void:
	custom_minimum_size = Vector2(BOARD_W, BOARD_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()


# ─────────────────────────────────────────────
#  构建（一次）
# ─────────────────────────────────────────────

func _build() -> void:
	var substrate := SubstrateLayer.new()
	substrate.size = Vector2(BOARD_W, BOARD_H)
	add_child(substrate)

	_trace_layer = TraceLayer.new()
	_trace_layer.size = Vector2(BOARD_W, BOARD_H)
	add_child(_trace_layer)

	# 节点摆位：每轨按 tier 分组（保序），槽位居中对齐
	for lane_idx in LANE_ORDER.size():
		var branch: String = String(LANE_ORDER[lane_idx])
		var branch_color: Color = SkillTree.get_branch_color(branch)
		var by_tier: Dictionary = {}
		var order: Array = []
		for nd in SkillTree.get_skills_for_branch(branch):
			var t: int = int(nd.get("tier", 0))
			if not by_tier.has(t):
				by_tier[t] = []
				order.append(t)
			by_tier[t].append(nd)
		for t in order:
			var row: Array = by_tier[t]
			var start_slot: int = int((LANE_SLOTS - row.size()) * 0.5)
			for j in row.size():
				var nd: Dictionary = row[j]
				var slot: int = start_slot + j
				var pos := Vector2(lane_x(lane_idx) + slot * SLOT_PITCH, HEADER_H + t * ROW_H)
				var chip := ChipWidget.new()
				var is_cap: bool = bool(nd.get("capstone", false))
				chip.setup(nd, SkillTree.CAPSTONE_COLOR if is_cap else branch_color)
				chip.position = pos
				chip.clicked.connect(_on_chip_clicked)
				add_child(chip)
				_node_geo[String(nd.get("id", ""))] = {
					"lane": lane_idx, "slot": slot, "tier": t,
					"x": int(pos.x), "y": int(pos.y), "chip": chip, "node": nd,
				}

	# 边收集（requires 展开）
	for nid in _node_geo:
		var nd: Dictionary = _node_geo[nid]["node"]
		for req in nd.get("requires", []):
			if _node_geo.has(String(req)):
				_edges.append({"from": String(req), "to": nid})
	_assign_pins()
	_assign_channels()


static func lane_x(lane_idx: int) -> int:
	return MARGIN_L + RULER_W + lane_idx * (LANE_W + LANE_GAP)


## 每芯片每侧的边分配引脚偏移（-14/0/+14 轮转），写入边表
func _assign_pins() -> void:
	var side_usage: Dictionary = {}   # "id|side" -> Array[边索引]
	for i in _edges.size():
		var e: Dictionary = _edges[i]
		var a: Dictionary = _node_geo[e["from"]]
		var b: Dictionary = _node_geo[e["to"]]
		var sa := ""
		var sb := ""
		if a["lane"] == b["lane"] and a["tier"] != b["tier"]:
			sa = "bottom"
			sb = "top"
		elif a["lane"] == b["lane"]:
			if int(b["x"]) >= int(a["x"]):
				sa = "right"
				sb = "left"
			else:
				sa = "left"
				sb = "right"
		else:
			if int(b["lane"]) > int(a["lane"]):
				sa = "right"
				sb = "left"
			else:
				sa = "left"
				sb = "right"
		e["a_side"] = sa
		e["b_side"] = sb
		var key_a := "%s|%s" % [e["from"], sa]
		var key_b := "%s|%s" % [e["to"], sb]
		if not side_usage.has(key_a):
			side_usage[key_a] = []
		side_usage[key_a].append(i)
		if not side_usage.has(key_b):
			side_usage[key_b] = []
		side_usage[key_b].append(i)
	for key in side_usage:
		var arr: Array = side_usage[key]
		for j in arr.size():
			var e: Dictionary = _edges[arr[j]]
			var off: int = PIN_OFFSETS[j % PIN_OFFSETS.size()]
			# key 形如 "id|side"：判断本边在该芯片上是不是 from 端
			if e["from"] + "|" + e["a_side"] == key:
				e["a_pin"] = off
			else:
				e["b_pin"] = off
	# 兜底（理论不触达）：未赋值的边给 0
	for e in _edges:
		if not e.has("a_pin"):
			e["a_pin"] = 0
		if not e.has("b_pin"):
			e["b_pin"] = 0


## 跨轨走线分配轨间通道子通道（±6px 交错），同通道 y 区间不重叠
func _assign_channels() -> void:
	var groups: Dictionary = {}   # gap 编号(0/1) -> Array[边索引]
	for i in _edges.size():
		var e: Dictionary = _edges[i]
		var a: Dictionary = _node_geo[e["from"]]
		var b: Dictionary = _node_geo[e["to"]]
		if a["lane"] == b["lane"]:
			e["ch_off"] = 0
			continue
		var gap := mini(int(a["lane"]), int(b["lane"]))
		if not groups.has(gap):
			groups[gap] = []
		groups[gap].append(i)
	for gap in groups:
		var arr: Array = groups[gap]
		arr.sort_custom(func(i1, i2):
			return int(_node_geo[_edges[i1]["from"]]["tier"]) < int(_node_geo[_edges[i2]["from"]]["tier"]))
		for j in arr.size():
			_edges[arr[j]]["ch_off"] = -4 if j % 2 == 0 else 4


# ─────────────────────────────────────────────
#  状态刷新（换装不重建）
# ─────────────────────────────────────────────

## mgr 为 null（如 headless --script 模式）时全树按断路态渲染
func refresh(mgr: Node) -> void:
	var unlocked: Dictionary = {}
	var standby: Dictionary = {}
	if mgr != null:
		for nid in _node_geo:
			if mgr.is_unlocked(nid):
				unlocked[nid] = true
			elif mgr.can_unlock_node(nid).get("ok", false):
				standby[nid] = true
	for nid in _node_geo:
		var chip: ChipWidget = _node_geo[nid]["chip"]
		if unlocked.has(nid):
			chip.apply_state(ChipState.POWERED)
		elif standby.has(nid):
			chip.apply_state(ChipState.STANDBY)
		else:
			chip.apply_state(ChipState.LOCKED)
	_trace_layer.refresh(mgr, _edges, _node_geo, _selected_id)


func select(node_id: String) -> void:
	if _selected_id != "" and _node_geo.has(_selected_id):
		(_node_geo[_selected_id]["chip"] as ChipWidget).set_selected(false)
	_selected_id = node_id if _node_geo.has(node_id) else ""
	if _selected_id != "":
		(_node_geo[_selected_id]["chip"] as ChipWidget).set_selected(true)


func get_chip_count() -> int:
	return _node_geo.size()


func get_edge_count() -> int:
	return _edges.size()


## 已解锁节点数（探针栏默认态文案用）
func count_unlocked(mgr: Node) -> int:
	if mgr == null:
		return 0
	var n := 0
	for nid in _node_geo:
		if mgr.is_unlocked(nid):
			n += 1
	return n


## 下一个可推进节点（面板「⚡ 下一个」跳转用）。
## 优先返回 standby（前置+点数皆备，立即可通电）；无 standby 再返回
## no_points（前置已备、仅缺点数，跳过去看差多少）。同类内按
## tier 深者优先（延续最深的推进线），tier 内按轨序/槽位。
func find_next(mgr: Node) -> Dictionary:
	if mgr == null:
		return {"id": "", "kind": ""}
	var best_standby := ""
	var best_standby_score := -99999
	var best_blocked := ""
	var best_blocked_score := -99999
	for nid in _node_geo:
		if mgr.is_unlocked(nid):
			continue
		var can: Dictionary = mgr.can_unlock_node(nid)
		var is_standby := bool(can.get("ok", false))
		var is_blocked := String(can.get("reason", "")) == "not_enough_points"
		if not is_standby and not is_blocked:
			continue
		var g: Dictionary = _node_geo[nid]
		var score: int = int(g["tier"]) * 1000 - int(g["lane"]) * 10 - int(g["slot"])
		if is_standby and score > best_standby_score:
			best_standby_score = score
			best_standby = nid
		elif is_blocked and score > best_blocked_score:
			best_blocked_score = score
			best_blocked = nid
	if best_standby != "":
		return {"id": best_standby, "kind": "standby"}
	return {"id": best_blocked, "kind": "no_points" if best_blocked != "" else ""}


## 芯片中心坐标（面板滚动定位用）
func get_chip_center(node_id: String) -> Vector2:
	if not _node_geo.has(node_id):
		return Vector2.ZERO
	var g: Dictionary = _node_geo[node_id]
	return Vector2(int(g["x"]) + CHIP * 0.5, int(g["y"]) + CHIP * 0.5)


## 跳转到达的聚焦脉冲（比解锁演出轻一档）
func play_focus_pulse(node_id: String) -> void:
	if DT.is_motion_reduce() or not _node_geo.has(node_id):
		return
	var chip: ChipWidget = _node_geo[node_id]["chip"]
	chip.pivot_offset = chip.size * 0.5
	var pulse := func(t: float) -> void:
		if is_instance_valid(chip):
			chip.scale = Vector2.ONE * (1.0 + 0.10 * sin(PI * t))
	create_tween().tween_method(pulse, 0.0, 1.0, 0.2)


func _on_chip_clicked(node_id: String) -> void:
	chip_clicked.emit(node_id)


# ─────────────────────────────────────────────
#  解锁演出：芯片通电脉冲 + 入线光点
# ─────────────────────────────────────────────

func play_unlock_effect(node_id: String) -> void:
	if DT.is_motion_reduce() or not _node_geo.has(node_id):
		return
	var chip: ChipWidget = _node_geo[node_id]["chip"]
	chip.pivot_offset = chip.size * 0.5
	var pulse := func(t: float) -> void:
		if is_instance_valid(chip):
			chip.scale = Vector2.ONE * (1.0 + 0.16 * sin(PI * t))
	create_tween().tween_method(pulse, 0.0, 1.0, DT.MOTION_POP)
	# 光点沿第一条通电入线扫过（源节点已解锁 → 该线本就通电）
	var incoming: Array = _trace_layer.get_incoming_edges(node_id)
	if not incoming.is_empty():
		var ed: Dictionary = incoming[0]
		var pts: PackedVector2Array = ed["pts"]
		var dot := SparkDot.new()
		dot.dot_color = ed["color"]
		add_child(dot)
		var travel := func(t: float) -> void:
			if is_instance_valid(dot):
				dot.position = point_along(pts, t) - Vector2(6, 6)
		var tw := create_tween()
		tw.tween_method(travel, 0.0, 1.0, 0.3)
		tw.tween_callback(dot.queue_free)


static func point_along(pts: PackedVector2Array, t: float) -> Vector2:
	if pts.size() < 2:
		return pts[0] if pts.size() > 0 else Vector2.ZERO
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var target := total * clampf(t, 0.0, 1.0)
	var acc := 0.0
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if acc + seg >= target:
			var f := (target - acc) / seg if seg > 0.0 else 0.0
			return pts[i].lerp(pts[i + 1], f)
		acc += seg
	return pts[pts.size() - 1]


# ═════════════════════════════════════════════
#  基板层（静态，画一次）
# ═════════════════════════════════════════════
class SubstrateLayer:
	extends Control
	var _via_tex: ImageTexture
	var _vignette_tex: GradientTexture2D
	var _wash_tex: GradientTexture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		img.set_pixel(8, 8, Color(1.0, 1.0, 1.0, 0.045))
		_via_tex = ImageTexture.create_from_image(img)
		# 边缘暗角（径向渐变，板面纵深）
		_vignette_tex = GradientTexture2D.new()
		_vignette_tex.fill = GradientTexture2D.FILL_RADIAL
		_vignette_tex.fill_from = Vector2(0.5, 0.5)
		_vignette_tex.fill_to = Vector2(1.05, 0.5)
		var gv := Gradient.new()
		gv.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		gv.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.20)])
		_vignette_tex.gradient = gv
		# 轨道洗色（纵向渐淡，乘分支色后为轨道晕染）
		_wash_tex = GradientTexture2D.new()
		_wash_tex.fill_from = Vector2(0.5, 0.0)
		_wash_tex.fill_to = Vector2(0.5, 1.0)
		var gw := Gradient.new()
		gw.offsets = PackedFloat32Array([0.0, 1.0])
		gw.colors = PackedColorArray([Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0)])
		_wash_tex.gradient = gw

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), DT.COLOR_PANEL_DEEP)
		if _via_tex != null:
			draw_texture_rect(_via_tex, Rect2(Vector2.ZERO, size), true)
		# 轨道基质洗色（分支色纵向渐淡，三轨基板有可感知的色差）
		# 注：lane_x 是外部静态函数，内部类不可调，就地展开
		var zone_top := HEADER_H - 6.0
		var zone_h := size.y - zone_top - 10.0
		for i in LANE_ORDER.size():
			var lx := MARGIN_L + RULER_W + i * (LANE_W + LANE_GAP)
			if _wash_tex != null:
				draw_texture_rect(_wash_tex, Rect2(Vector2(lx, zone_top), Vector2(LANE_W, zone_h)),
						false, Color(SkillTree.get_branch_color(String(LANE_ORDER[i])), 0.09))
			else:
				draw_rect(Rect2(Vector2(lx, zone_top), Vector2(LANE_W, zone_h)),
						Color(SkillTree.get_branch_color(String(LANE_ORDER[i])), 0.04))
		# 对位十字（轨道边界的装配基准标记，PCB 丝印意象）
		var plus_col := Color(1, 1, 1, 0.05)
		for i in LANE_ORDER.size():
			var lx2 := MARGIN_L + RULER_W + i * (LANE_W + LANE_GAP)
			for xpx in [lx2, lx2 + LANE_W]:
				var t2 := 1
				while t2 < TIERS:
					var py := HEADER_H + t2 * ROW_H - 12
					draw_line(Vector2(xpx - 4, py), Vector2(xpx + 4, py), plus_col)
					draw_line(Vector2(xpx, py - 4), Vector2(xpx, py + 4), plus_col)
					t2 += 2
		# 层分隔线（tier 行上界）
		for t in TIERS:
			var y := HEADER_H + t * ROW_H - 12
			draw_line(Vector2(MARGIN_L + RULER_W, y), Vector2(size.x - MARGIN_R, y), GRID_LINE)
		draw_line(Vector2(MARGIN_L + RULER_W, HEADER_H - 12), Vector2(size.x - MARGIN_R, HEADER_H - 12), Color(1.0, 1.0, 1.0, 0.06))
		# 深层电路分界（T5 上界：基础层 tier0-4 与深层 tier5-15 的板面分区）
		var deep_y := HEADER_H + 5 * ROW_H - 12
		draw_line(Vector2(MARGIN_L + RULER_W, deep_y), Vector2(size.x - MARGIN_R, deep_y), Color(1.0, 1.0, 1.0, 0.10))
		var font := get_theme_default_font()
		draw_string(font, Vector2(size.x * 0.5 - 70, deep_y - 4), "深层电路 DEEP CIRCUIT",
				HORIZONTAL_ALIGNMENT_LEFT, -1, DT.FONT_SIZE_SMALL, Color(DT.COLOR_TEXT_MID, 0.6))
		# 四角安装孔
		for p in [Vector2(13, 20), Vector2(size.x - 13, 20), Vector2(13, size.y - 13), Vector2(size.x - 13, size.y - 13)]:
			draw_circle(p, 4.2, Color(0, 0, 0, 0.6))
			draw_arc(p, 6.0, 0, TAU, 32, Color(0.55, 0.62, 0.75, 0.35), 1.5, true)
		# 底部丝印
		draw_string(font, Vector2(size.x * 0.5 - 90, size.y - 4), "PHW-SKILL-MB REV 22.1 · 74 NODES",
				HORIZONTAL_ALIGNMENT_LEFT, -1, DT.FONT_SIZE_XSMALL, Color(1, 1, 1, 0.30))
		# tier 标尺：刻度 + 标签（每 5 层加长刻度；纯英文/数字 10px 合规）
		for t in TIERS:
			var ty := HEADER_H + t * ROW_H + CHIP * 0.5
			var strong := t % 5 == 0
			draw_line(Vector2(12 if strong else 15, ty), Vector2(19, ty),
					Color(DT.COLOR_TEXT_MID, 1.0 if strong else 0.55))
			draw_string(font, Vector2(2, HEADER_H + t * ROW_H + 14), "T%d" % t,
					HORIZONTAL_ALIGNMENT_LEFT, -1, DT.FONT_SIZE_XSMALL,
					Color(DT.COLOR_TEXT_MID, 0.9))
		# 边缘暗角收束（最后画，压住全部底纹）
		if _vignette_tex != null:
			draw_texture_rect(_vignette_tex, Rect2(Vector2.ZERO, size), false)


# ═════════════════════════════════════════════
#  走线层
# ═════════════════════════════════════════════
class TraceLayer:
	extends Control
	# 缓存的绘制数据：[{pts, color, lit, from, to}]
	var _draw_list: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func refresh(mgr: Node, edges: Array, geo: Dictionary, _selected: String) -> void:
		_draw_list.clear()
		for e in edges:
			var a: Dictionary = geo[e["from"]]
			var b: Dictionary = geo[e["to"]]
			var a_node: Dictionary = a["node"]
			var b_node: Dictionary = b["node"]
			var is_cap := bool(a_node.get("capstone", false)) or bool(b_node.get("capstone", false))
			var color: Color = SkillTree.CAPSTONE_COLOR if is_cap \
					else SkillTree.get_branch_color(String(b_node.get("branch", "")))
			var lit: bool = mgr != null and mgr.is_unlocked(String(e["from"]))
			var pts := _edge_polyline(e, geo)
			# 跨轨走线在通道两端的换层过孔（跨轨=换层，PCB 语义）
			var vias := PackedVector2Array()
			if a["lane"] != b["lane"] and pts.size() >= 4:
				vias.append(pts[2 if pts.size() >= 6 else 1])
				vias.append(pts[3 if pts.size() >= 6 else 2])
			_draw_list.append({
				"pts": pts, "color": color, "lit": lit, "cap": is_cap, "vias": vias,
				"from": e["from"], "to": e["to"],
			})
		queue_redraw()

	func _draw() -> void:
		for ed in _draw_list:
			var pts: PackedVector2Array = ed["pts"]
			var col: Color = ed["color"]
			if bool(ed["lit"]):
				# 奇点走线略宽于分支走线（主线/支线的层级感）
				var lw := 4.0 if bool(ed["cap"]) else 3.5
				var gw := 10.0 if bool(ed["cap"]) else 9.0
				draw_polyline(pts, Color(col, 0.20), gw, true)
				draw_polyline(pts, col, lw, true)
				# 端点焊盘：圆环锡盘（环 + 孔）
				for ep in [pts[0], pts[pts.size() - 1]]:
					draw_circle(ep, 3.2, Color(col, 0.35))
					draw_circle(ep, 1.7, col)
				for via in ed["vias"]:
					draw_circle(via, 3.0, Color(col, 0.30))
					draw_circle(via, 1.4, col)
			else:
				# 断路走线：末端留 8px 断口（物理断路意象）+ 暗色
				var draw_pts := pts
				if pts.size() >= 2:
					var last: Vector2 = pts[pts.size() - 1]
					var prev: Vector2 = pts[pts.size() - 2]
					var seg := last - prev
					if seg.length() > 14.0:
						draw_pts = pts.duplicate()
						draw_pts[draw_pts.size() - 1] = last - seg.normalized() * 8.0
				draw_polyline(draw_pts, TRACE_DEAD, 1.5, true)
				draw_circle(pts[0], 1.6, TRACE_DEAD)
				if draw_pts.size() == pts.size():
					draw_circle(pts[pts.size() - 1], 1.6, TRACE_DEAD)
				else:
					draw_circle(draw_pts[draw_pts.size() - 1], 1.6, TRACE_DEAD)
				for via in ed["vias"]:
					draw_circle(via, 2.0, TRACE_DEAD)

	## 已通电的入边（解锁光点演出用）
	func get_incoming_edges(node_id: String) -> Array:
		var out: Array = []
		for ed in _draw_list:
			if ed["to"] == node_id and ed["lit"]:
				out.append(ed)
		return out

	func _edge_polyline(e: Dictionary, geo: Dictionary) -> PackedVector2Array:
		var a: Dictionary = geo[e["from"]]
		var b: Dictionary = geo[e["to"]]
		var p1 := _side_point(a, e["a_side"], e["a_pin"])
		var p2 := _side_point(b, e["b_side"], e["b_pin"])
		if a["lane"] == b["lane"]:
			if a["tier"] != b["tier"]:
				return _vertical_elbow(p1, p2)
			return _horizontal_link(p1, p2)
		return _cross_lane(p1, p2, a, b, e["ch_off"])

	## 芯片某侧某引脚的接线点
	static func _side_point(geo: Dictionary, side: String, pin: int) -> Vector2:
		var cx := float(geo["x"]) + CHIP * 0.5
		var cy := float(geo["y"]) + CHIP * 0.5
		match side:
			"top":
				return Vector2(cx + pin, float(geo["y"]))
			"bottom":
				return Vector2(cx + pin, float(geo["y"]) + CHIP)
			"right":
				return Vector2(float(geo["x"]) + CHIP, cy + pin)
			_:
				return Vector2(float(geo["x"]), cy + pin)

	## 同轨上下层：45° 肘折线
	static func _vertical_elbow(p1: Vector2, p2: Vector2) -> PackedVector2Array:
		if absf(p1.x - p2.x) < 0.5:
			return PackedVector2Array([p1, p2])
		var yc := (p1.y + p2.y) * 0.5
		var s := signf(p2.x - p1.x)
		if yc - CHAMFER < p1.y or yc + CHAMFER > p2.y:
			return PackedVector2Array([p1, Vector2(p1.x, yc), Vector2(p2.x, yc), p2])
		return PackedVector2Array([
			p1,
			Vector2(p1.x, yc - CHAMFER),
			Vector2(p1.x + s * CHAMFER, yc),
			Vector2(p2.x - s * CHAMFER, yc),
			Vector2(p2.x, yc + CHAMFER),
			p2,
		])

	## 同层并列：水平直连（引脚 y 不同时退化直角肘）
	static func _horizontal_link(p1: Vector2, p2: Vector2) -> PackedVector2Array:
		if absf(p1.y - p2.y) < 0.5:
			return PackedVector2Array([p1, p2])
		var xc := (p1.x + p2.x) * 0.5
		return PackedVector2Array([p1, Vector2(xc, p1.y), Vector2(xc, p2.y), p2])

	## 跨轨：源侧引出 → 轨间通道 → 目标侧接入（8px 倒角）
	## 注：内部类不能调外部静态函数 lane_x()，通道 x 就地展开
	static func _cross_lane(p1: Vector2, p2: Vector2, a: Dictionary, b: Dictionary, ch_off: int) -> PackedVector2Array:
		var lane := maxi(int(a["lane"]), int(b["lane"]))
		var ch := float(MARGIN_L + RULER_W + lane * (LANE_W + LANE_GAP) - LANE_GAP * 0.5 + ch_off)
		var vy := signf(p2.y - p1.y)
		if absf(p2.y - p1.y) < CHAMFER * 2.5:
			return PackedVector2Array([p1, Vector2(ch, p1.y), Vector2(ch, p2.y), p2])
		var hx1 := signf(ch - p1.x)
		var hx2 := signf(p2.x - ch)
		return PackedVector2Array([
			p1,
			Vector2(ch - hx1 * CHAMFER, p1.y),
			Vector2(ch, p1.y + vy * CHAMFER),
			Vector2(ch, p2.y - vy * CHAMFER),
			Vector2(ch + hx2 * CHAMFER, p2.y),
			p2,
		])


# ═════════════════════════════════════════════
#  芯片（节点）
# ═════════════════════════════════════════════
class ChipWidget:
	extends Control
	signal clicked(node_id: String)

	const TYPE_LABELS := {
		"unit_mechanism": "兵种机制",
		"unit_ability": "兵种能力",
		"tactic": "战法",
		"card_skill": "卡片技能",
		"evolution": "进化形态",
		"affix": "词条系统",
	}

	## 解锁内容类型 → 器件封装风格
	static func style_for_node(p_node: Dictionary) -> int:
		var unlocks: Array = p_node.get("unlocks", [])
		if unlocks.is_empty() or not (unlocks[0] is Dictionary):
			return ChipStyle.QFN
		match String(unlocks[0].get("type", "")):
			"unit_mechanism", "unit_ability":
				return ChipStyle.MODULE
			"tactic":
				return ChipStyle.DIP
			"card_skill":
				return ChipStyle.CAN
			"evolution":
				return ChipStyle.QFP
			_:
				return ChipStyle.QFN

	## 解锁内容类型的玩家可读名（tooltip / 探针栏用）
	static func type_label_of(p_node: Dictionary) -> String:
		var unlocks: Array = p_node.get("unlocks", [])
		if unlocks.is_empty() or not (unlocks[0] is Dictionary):
			return "数值强化"
		return String(TYPE_LABELS.get(String(unlocks[0].get("type", "")), "数值强化"))

	var node: Dictionary = {}
	var accent: Color = Color.WHITE
	var is_capstone := false
	var state := ChipState.LOCKED
	var chip_style: int = ChipStyle.QFN
	var hover := false
	var selected := false
	var interactive := true

	var _name_label: Label = null
	var _die_label: Label = null
	var _cost_label: Label = null
	var _breath_tween: Tween = null

	## 管芯激光刻字（器件类型首字，IC 打标意象）
	const TYPE_GLYPHS := {
		ChipStyle.QFN: "数",
		ChipStyle.MODULE: "能",
		ChipStyle.DIP: "术",
		ChipStyle.CAN: "技",
		ChipStyle.QFP: "进",
	}

	func _ready() -> void:
		custom_minimum_size = Vector2(CHIP, CHIP)
		size = Vector2(CHIP, CHIP)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))
		if not interactive:
			mouse_filter = Control.MOUSE_FILTER_IGNORE

	## 可重复调用（探针栏预览芯片换节点）
	func setup(p_node: Dictionary, p_accent: Color) -> void:
		node = p_node
		accent = p_accent
		is_capstone = bool(p_node.get("capstone", false))
		chip_style = style_for_node(p_node)
		if _name_label == null:
			_build_labels()
		_name_label.text = String(p_node.get("name", ""))
		_die_label.visible = not is_capstone
		_die_label.text = String(TYPE_GLYPHS.get(chip_style, "数"))
		var cost := int(p_node.get("cost", 1))
		_cost_label.text = ("◈%d" if is_capstone else "◆%d") % cost
		tooltip_text = "［%s］%s%s\n%s\n消耗 %d 技能点" % [
			type_label_of(p_node),
			"◈奇点 " if is_capstone else "",
			String(p_node.get("name", "")),
			String(p_node.get("desc", "")),
			cost,
		]

	func _build_labels() -> void:
		# 名称带（12px 中文合规；唯一 6 字名"相位场壁垒"宽不与相邻标签相碰；描边增可读性）
		_name_label = Label.new()
		_name_label.position = Vector2(-7, CHIP + 3)
		_name_label.size = Vector2(CHIP + 16, 16)
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_name_label.add_theme_constant_override("outline_size", 2)
		add_child(_name_label)
		# 管芯刻字（20px，居中于管芯区）
		_die_label = Label.new()
		_die_label.position = Vector2(0, 17)
		_die_label.size = Vector2(CHIP, 32)
		_die_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_die_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_die_label.add_theme_font_size_override("font_size", 20)
		_die_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
		_die_label.add_theme_constant_override("outline_size", 2)
		add_child(_die_label)
		# 成本徽标（右上角，描边）
		_cost_label = Label.new()
		_cost_label.position = Vector2(CHIP - 30, 1)
		_cost_label.size = Vector2(28, 14)
		_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_cost_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		_cost_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_cost_label.add_theme_constant_override("outline_size", 2)
		add_child(_cost_label)

	func _gui_input(ev: InputEvent) -> void:
		if not interactive:
			return
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(String(node.get("id", "")))

	func _on_hover(h: bool) -> void:
		hover = h
		queue_redraw()

	func set_selected(sel: bool) -> void:
		selected = sel
		queue_redraw()

	func set_interactive(v: bool) -> void:
		interactive = v
		mouse_filter = Control.MOUSE_FILTER_IGNORE if not v else Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if v else Control.CURSOR_ARROW

	func apply_state(s: int) -> void:
		state = s
		if _name_label != null:
			match s:
				ChipState.POWERED:
					_name_label.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
				ChipState.STANDBY:
					_name_label.add_theme_color_override("font_color", DT.COLOR_GOLD)
				_:
					_name_label.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
		if _die_label != null:
			match s:
				ChipState.POWERED:
					_die_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
				ChipState.STANDBY:
					_die_label.add_theme_color_override("font_color", Color(DT.COLOR_GOLD, 0.85))
				_:
					_die_label.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_MID, 0.45))
		if _cost_label != null:
			if s == ChipState.POWERED:
				_cost_label.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_DIM, 0.8))
			elif is_capstone:
				_cost_label.add_theme_color_override("font_color", SkillTree.CAPSTONE_COLOR)
			else:
				_cost_label.add_theme_color_override("font_color", DT.COLOR_GOLD)
		_breath(s == ChipState.STANDBY)
		queue_redraw()

	func _breath(enabled: bool) -> void:
		if _breath_tween != null and _breath_tween.is_valid():
			_breath_tween.kill()
			modulate.a = 1.0
		_breath_tween = null
		if not enabled or DT.is_motion_reduce():
			return
		_breath_tween = create_tween().set_loops()
		_breath_tween.tween_property(self, "modulate:a", 0.72, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_breath_tween.tween_property(self, "modulate:a", 1.0, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _draw() -> void:
		var ring := accent
		# 状态配色
		var pkg_fill: Color
		var border_col: Color = TRACE_DEAD
		var bw := 1.0
		match state:
			ChipState.POWERED:
				pkg_fill = Color(ring, 0.26)
				border_col = ring
				bw = 3.0 if is_capstone else 2.0
			ChipState.STANDBY:
				pkg_fill = Color(DT.COLOR_GOLD, 0.16)
			_:
				pkg_fill = DT.COLOR_CARD
		var half := CHIP * 0.5
		# 悬停柔光（在封装下层，一圈极淡的外晕）
		if hover and interactive:
			draw_circle(Vector2(half, half), CHIP * 0.72, Color(1, 1, 1, 0.045))
			draw_circle(Vector2(half, half), CHIP * 0.58, Color(1, 1, 1, 0.05))
		# 引脚/引线（DIP 顶/底改短脚弱化；连接点位置所有封装一致）
		var pin_col: Color = Color(ring, 0.85) if state == ChipState.POWERED else PIN_METAL
		var short_tb := chip_style == ChipStyle.DIP
		var pad_col: Color = Color(ring, 0.9) if state == ChipState.POWERED else Color(PIN_METAL, 0.9)
		for off in PIN_OFFSETS:
			var tl := 3.0 if short_tb else 5.0
			draw_rect(Rect2(half + off - 2, 0, 4, tl), pin_col)
			draw_rect(Rect2(half + off - 2, CHIP - tl, 4, tl), pin_col)
			draw_rect(Rect2(0, half + off - 2, 5, 4), pin_col)
			draw_rect(Rect2(CHIP - 5, half + off - 2, 5, 4), pin_col)
			# 引脚根焊点（锡珠）
			draw_circle(Vector2(half + off, tl), 2.2, pad_col)
			draw_circle(Vector2(half + off, CHIP - tl), 2.2, pad_col)
			draw_circle(Vector2(5.0, half + off), 2.2, pad_col)
			draw_circle(Vector2(CHIP - 5.0, half + off), 2.2, pad_col)
		# 封装轮廓（器件类型决定形状，含斜面高光/阴影与内层填充）
		_draw_package(pkg_fill, border_col, bw, ring)
		# 待接入态的探针夹脚（方角括号统一识别，不随轮廓变化）
		if state == ChipState.STANDBY:
			_brackets(DT.COLOR_GOLD, 2.0, 10.0)
		# 管芯母题（刻字由 _die_label 承担）
		_draw_die(half, ring)
		# 悬停 / 选中
		if hover and interactive:
			draw_rect(Rect2(Vector2(-2, -2), Vector2(CHIP + 4, CHIP + 4)), Color(1, 1, 1, 0.22), false, 1.5)
		if selected:
			draw_rect(Rect2(Vector2(-4, -4), Vector2(CHIP + 8, CHIP + 8)), DT.COLOR_TEXT_BRIGHT, false, 2)

	## 封装轮廓：形状随器件类型变化；填充 → 内层填充 → 斜面高光/阴影 → 光晕 → 边框
	func _draw_package(fill: Color, border_col: Color, bw: float, ring: Color) -> void:
		match chip_style:
			ChipStyle.MODULE:
				# 八角功率模块
				var oct := _octagon(1.0, 13.0)
				var closed := oct.duplicate()
				closed.append(oct[0])
				draw_colored_polygon(oct, fill)
				var oct_in := _octagon(7.0, 10.0)
				draw_colored_polygon(oct_in, Color(fill.r, fill.g, fill.b, fill.a * 0.55))
				_bevel_polyline(closed, [7, 0, 1, 2], [3, 4, 5, 6])
				if state == ChipState.POWERED:
					draw_polyline(closed, Color(ring, 0.10), 6.0, true)
					draw_polyline(closed, Color(ring, 0.22), 4.0, true)
				draw_polyline(closed, border_col, bw, true)
			ChipStyle.CAN:
				# 圆罐晶振
				var c := Vector2(CHIP * 0.5, CHIP * 0.5)
				var r := 29.0
				draw_circle(c, r, fill)
				draw_circle(c, r - 6.0, Color(fill.r, fill.g, fill.b, fill.a * 0.55))
				draw_arc(c, r - 2.0, PI, PI * 1.5, 16, Color(1, 1, 1, 0.10), 1.5, true)
				draw_arc(c, r - 2.0, 0, PI * 0.5, 16, Color(0, 0, 0, 0.28), 1.5, true)
				if state == ChipState.POWERED:
					draw_arc(c, r, 0, TAU, 32, Color(ring, 0.10), 6.0, true)
					draw_arc(c, r, 0, TAU, 32, Color(ring, 0.22), 4.0, true)
				draw_arc(c, r, 0, TAU, 32, border_col, bw, true)
			ChipStyle.DIP:
				# 双列直插：方体 + 顶部定位缺口
				var body := Rect2(Vector2.ONE, Vector2(CHIP - 2, CHIP - 2))
				draw_rect(body, fill)
				draw_rect(Rect2(Vector2(7, 7), Vector2(CHIP - 14, CHIP - 14)), Color(fill.r, fill.g, fill.b, fill.a * 0.55))
				_bevel_rect(body)
				if state == ChipState.POWERED:
					draw_rect(Rect2(Vector2(-3, -3), Vector2(CHIP + 6, CHIP + 6)), Color(ring, 0.10), false, 6)
					draw_rect(Rect2(Vector2(-2, -2), Vector2(CHIP + 4, CHIP + 4)), Color(ring, 0.22), false, 4)
				draw_rect(body, border_col, false, bw)
				draw_circle(Vector2(CHIP * 0.5, 1), 4.0, DT.COLOR_VOID)
			_:
				# QFN 方片 / QFP 双框
				var body := Rect2(Vector2.ONE, Vector2(CHIP - 2, CHIP - 2))
				draw_rect(body, fill)
				draw_rect(Rect2(Vector2(7, 7), Vector2(CHIP - 14, CHIP - 14)), Color(fill.r, fill.g, fill.b, fill.a * 0.55))
				_bevel_rect(body)
				if state == ChipState.POWERED:
					draw_rect(Rect2(Vector2(-3, -3), Vector2(CHIP + 6, CHIP + 6)), Color(ring, 0.10), false, 6)
					draw_rect(Rect2(Vector2(-2, -2), Vector2(CHIP + 4, CHIP + 4)), Color(ring, 0.22), false, 4)
				draw_rect(body, border_col, false, bw)
				if chip_style == ChipStyle.QFP:
					draw_rect(Rect2(Vector2(6, 6), Vector2(CHIP - 12, CHIP - 12)), Color(border_col, 0.45), false, 1)

	## 方形封装斜面：上/左受光、下/右背光（1.5px 双向描边 = 塑封体积感）
	func _bevel_rect(body: Rect2) -> void:
		var x0 := body.position.x
		var y0 := body.position.y
		var x1 := body.position.x + body.size.x
		var y1 := body.position.y + body.size.y
		draw_line(Vector2(x0 + 1, y0 + 1), Vector2(x1 - 1, y0 + 1), Color(1, 1, 1, 0.10), 1.5)
		draw_line(Vector2(x0 + 1, y0 + 1), Vector2(x0 + 1, y1 - 1), Color(1, 1, 1, 0.10), 1.5)
		draw_line(Vector2(x0 + 1, y1 - 1), Vector2(x1 - 1, y1 - 1), Color(0, 0, 0, 0.28), 1.5)
		draw_line(Vector2(x1 - 1, y0 + 1), Vector2(x1 - 1, y1 - 1), Color(0, 0, 0, 0.28), 1.5)

	## 多边形斜面：light_idx/dark_idx 为折线顶点序号段
	func _bevel_polyline(closed: PackedVector2Array, light_idx: Array, dark_idx: Array) -> void:
		var light_pts := PackedVector2Array()
		for i in light_idx:
			light_pts.append(closed[i % closed.size()])
		var dark_pts := PackedVector2Array()
		for i in dark_idx:
			dark_pts.append(closed[i % closed.size()])
		draw_polyline(light_pts, Color(1, 1, 1, 0.10), 1.5, true)
		draw_polyline(dark_pts, Color(0, 0, 0, 0.28), 1.5, true)

	## 管芯母题：奇点=紫色菱形◈（外圈+内菱双层）；其余随封装（刻字由 Label 叠加）
	func _draw_die(half: float, ring: Color) -> void:
		var c := Vector2(half, half)
		var die_col: Color
		match state:
			ChipState.POWERED:
				die_col = Color(ring, 0.92)
			ChipState.STANDBY:
				die_col = Color(DT.COLOR_GOLD, 0.35)
			_:
				die_col = DIE_DARK
		if is_capstone:
			var r := 17.0
			draw_circle(c, r + 4.0, Color(die_col, 0.18))
			var dia := PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0),
			])
			draw_colored_polygon(dia, die_col)
			var dia_in := PackedVector2Array([
				c + Vector2(0, -r + 6), c + Vector2(r - 6, 0), c + Vector2(0, r - 6), c + Vector2(-r + 6, 0),
			])
			draw_polyline(dia_in, Color(0, 0, 0, 0.35), 1.0, true)
			return
		match chip_style:
			ChipStyle.MODULE:
				draw_rect(Rect2(c - Vector2(13, 13), Vector2(26, 26)), die_col)
				draw_rect(Rect2(c - Vector2(13, 13), Vector2(26, 26)), Color(0, 0, 0, 0.3), false, 1)
			ChipStyle.DIP:
				# 双芯并排（呼应双列引脚）
				draw_rect(Rect2(Vector2(18, 26), Vector2(13, 13)), die_col)
				draw_rect(Rect2(Vector2(35, 26), Vector2(13, 13)), die_col)
			ChipStyle.CAN:
				draw_circle(c, 13.0, die_col)
				draw_arc(c, 13.0, 0, TAU, 24, Color(0, 0, 0, 0.3), 1.0, true)
			ChipStyle.QFP:
				draw_rect(Rect2(c - Vector2(12, 12), Vector2(24, 24)), die_col)
			_:
				draw_rect(Rect2(c - Vector2(16, 16), Vector2(32, 32)), die_col)
				draw_rect(Rect2(c - Vector2(16, 16), Vector2(32, 32)), Color(0, 0, 0, 0.35), false, 1)
				draw_rect(Rect2(c - Vector2(11, 11), Vector2(22, 22)), Color(0, 0, 0, 0.25), false, 1)
		# 1 脚标记（方片/双框/八角）
		if chip_style == ChipStyle.QFN or chip_style == ChipStyle.QFP or chip_style == ChipStyle.MODULE:
			draw_circle(Vector2(7, 7), 1.6, Color(1, 1, 1, 0.45))

	static func _octagon(inset: float, ch: float) -> PackedVector2Array:
		var s := CHIP - inset * 2
		return PackedVector2Array([
			Vector2(inset + ch, inset), Vector2(inset + s - ch, inset),
			Vector2(inset + s, inset + ch), Vector2(inset + s, inset + s - ch),
			Vector2(inset + s - ch, inset + s), Vector2(inset + ch, inset + s),
			Vector2(inset, inset + s - ch), Vector2(inset, inset + ch),
		])

	## 四角 L 形括号（待接入态的"探针夹脚"）
	func _brackets(col: Color, w: float, len: float) -> void:
		var pts_tl := PackedVector2Array([Vector2(2, 2 + len), Vector2(2, 2), Vector2(2 + len, 2)])
		var pts_tr := PackedVector2Array([Vector2(CHIP - 2 - len, 2), Vector2(CHIP - 2, 2), Vector2(CHIP - 2, 2 + len)])
		var pts_bl := PackedVector2Array([Vector2(2, CHIP - 2 - len), Vector2(2, CHIP - 2), Vector2(2 + len, CHIP - 2)])
		var pts_br := PackedVector2Array([Vector2(CHIP - 2 - len, CHIP - 2), Vector2(CHIP - 2, CHIP - 2), Vector2(CHIP - 2, CHIP - 2 - len)])
		draw_polyline(pts_tl, col, w, true)
		draw_polyline(pts_tr, col, w, true)
		draw_polyline(pts_bl, col, w, true)
		draw_polyline(pts_br, col, w, true)


# ═════════════════════════════════════════════
#  解锁光点（临时节点，最顶层）
# ═════════════════════════════════════════════
class SparkDot:
	extends Control
	var dot_color: Color = Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(12, 12)

	func _draw() -> void:
		draw_circle(Vector2(6, 6), 5.0, Color(dot_color, 0.45))
		draw_circle(Vector2(6, 6), 2.4, dot_color)
