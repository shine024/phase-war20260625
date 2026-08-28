extends Node2D
## 余烬要塞 · 氛围动画层 v21 动效批次
## 叠在大背景图之上、房间覆盖层之下（bunker_main 控制添加顺序）：
##   1. 星空闪烁 —— 可见天空带 12 个微光点 alpha 呼吸（避让地球弧区）
##   2. 状态灯呼吸 —— 可用房右上角青灯缓慢明暗
##   3. 电梯井能量流 —— 沿井线上下巡行的微粒光点
##   4. 修复火花 —— 修复中房间内无状态伪随机的小火花下落
## 全部 _draw 自绘（每帧十几个图元，无实例开销）；动效减弱选项下静默。

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")
const DT = preload("res://resources/design_tokens.gd")

const STAR_COL := Color(0.80, 0.88, 1.0)
const LAMP_COL := Color(0.0, 0.94, 1.0)
const FLOW_COL := Color(0.0, 0.94, 1.0)
const SPARK_COL := Color(1.0, 0.72, 0.25)

var _manager: Node
var _time := 0.0
var _stars: Array = []          # {pos, phase, speed, r}
var _room_rects: Dictionary = {}  # room_id -> Rect2（由 bunker_main 注入）
var _active_ids: Array = []     # 状态灯呼吸的房间
var _repairing_ids: Array = []  # 修复火花房间

func setup(manager: Node, room_rects: Dictionary) -> void:
	_manager = manager
	_room_rects = room_rects
	z_index = 5
	_gen_stars()
	refresh_states()
	if SignalBus and not SignalBus.bunker_room_state_changed.is_connected(_on_room_state_changed):
		SignalBus.bunker_room_state_changed.connect(_on_room_state_changed)

func _gen_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bunker_ambient_stars")
	var tries := 0
	while _stars.size() < 14 and tries < 200:
		tries += 1
		var pos := Vector2(rng.randf_range(20.0, 1260.0), rng.randf_range(18.0, 118.0))
		_stars.append({
			"pos": pos,
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.6, 1.6),
			"r": rng.randf_range(0.7, 1.4),
		})

func _on_room_state_changed(room_id: String, _new_state: int) -> void:
	refresh_states()

func refresh_states() -> void:
	_active_ids.clear()
	_repairing_ids.clear()
	if _manager == null:
		return
	for room_id in _room_rects:
		var st: int = _manager.get_room_state(room_id)
		if st == BunkerRoomDefs.STATE_ACTIVE:
			_active_ids.append(room_id)
		elif st == BunkerRoomDefs.STATE_REPAIRING:
			_repairing_ids.append(room_id)

func _process(delta: float) -> void:
	if DT.is_motion_reduce():
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	# 1) 星空闪烁
	for s in _stars:
		var a := 0.28 + 0.30 * (0.5 + 0.5 * sin(_time * s["speed"] + s["phase"]))
		draw_circle(s["pos"], s["r"], Color(STAR_COL, a))
	# 2) 状态灯呼吸（可用房右上角）
	var i := 0
	for room_id in _active_ids:
		var rect: Rect2 = _room_rects[room_id]
		var c := rect.position + Vector2(rect.size.x - 12.0, 9.0)
		var a := 0.16 + 0.14 * (0.5 + 0.5 * sin(_time * 1.1 + i * 1.7))
		draw_circle(c, 4.5, Color(LAMP_COL, a))
		i += 1
	# 3) 电梯井能量流：三个微粒沿井线上/下巡行（两端渐隐）
	var shaft: Dictionary = BunkerRoomDefs.GRID["shaft"]
	var ex: float = (float(shaft["x1"]) + float(shaft["x2"])) * 0.5
	var top: float = float(shaft["top_y"])
	var bot: float = float(shaft["bottom_y"])
	for k in 3:
		var span := bot - top
		var t := fposmod(_time * (46.0 + k * 14.0) * (1.0 if k % 2 == 0 else -1.0) + k * span / 3.0, span)
		var y := top + t
		var edge := 1.0
		if t < 30.0:
			edge = t / 30.0
		elif t > span - 30.0:
			edge = (span - t) / 30.0
		draw_circle(Vector2(ex, y), 1.6, Color(FLOW_COL, 0.55 * clampf(edge, 0.0, 1.0)))
	# 4) 修复火花：无状态伪随机（每 0.4s 换一批，1/2 概率出火花，0.3s 生命周期）
	var bucket := int(_time / 0.4)
	for j in _repairing_ids.size():
		var room_id2: String = _repairing_ids[j]
		var rect2: Rect2 = _room_rects[room_id2]
		var h := hash(room_id2 + str(bucket))
		if h % 2 != 0:
			continue
		var prog := float((h >> 5) % 100) / 100.0   # 火花下落进度
		var sx := rect2.position.x + 30.0 + float((h >> 11) % 100) / 100.0 * (rect2.size.x - 60.0)
		var sy := rect2.position.y + 22.0 + prog * 26.0
		draw_circle(Vector2(sx, sy), 1.3, Color(SPARK_COL, (1.0 - prog) * 0.9))
