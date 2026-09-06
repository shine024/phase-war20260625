extends Node2D
## v27 黑门彼岸氛围层（美术定案：docs/无限模式_异族设定（草案）.md §5.1）
##
## 组成（均为程序化，零新美术）：
##   - 星云缓涌：intro/comic/b5_nebula.png 加色低 alpha + 慢速摆旋（呼应门心"旋转星空漩涡"）
##   - 暗淡星点闪烁：星光尽灭调（低亮度白/青/紫，密度随渗度上升）
##   - 晶脉发光网：青金蜿蜒折线（青金晶髓；金色占比按裂隙环境）
##   - 部署格线晶脉勾边：由 BattleSlotGrid 激活槽位导出行线/斜向连线（§5.1"部署格线由晶脉勾出"）
##   - 浮陆边缘裂纹：画面底缘更亮更碎的断裂纹（"浮陆四缘破碎悬空"）
##
## 强度轴 = 渗度（每 10 波 +1、封顶 5，EndlessBlackgateManager.depth_for_waves），
## 归一化 0..1 后驱动：晶脉亮度 / 星点数量与亮度 / 星云 alpha / 背景扭曲振幅（warp_material），
## 渗度 +1 时 4s 缓动过渡。
## 裂隙环境联动：读 BattleEnvEffects.rift_override，四种 env 各给晶脉基色/金色占比/流速微差异。
##
## 层级 z=-8：背景(-10)、半场着色(-9) 之上；槽位高亮(-2)、单位(0) 之下。
## 挂载/移除由 battlefield.gd _ensure_endless_rift_fx / _clear_endless_rift_fx 管理，普通关零影响。
## autoload 一律走 /root 运行时路径解析（本文件会被 --script 模式加载，禁全局 autoload 标识符）。

const _EndlessMgr := preload("res://managers/endless_blackgate_manager.gd")
const _BattleEnvEffects := preload("res://data/battle_env_effects.gd")
const _DT := preload("res://resources/design_tokens.gd")

const SEEPAGE_MAX: float = 5.0
const INTENSITY_RAMP_SEC: float = 4.0  ## 渗度 +1 后的缓动时长（避免视觉跳变）

## 裂隙环境 → 视觉微差异（vein=晶脉基色 / gold=金色晶脉占比 / nebula_a、warp=倍率）
const _ENV_LOOK_DEFAULT := {"vein": Color(0.25, 0.9, 0.85), "gold": 0.35, "nebula_a": 1.0, "warp": 1.0}
const _ENV_LOOK := {
	"psi_storm": {"vein": Color(0.66, 0.52, 1.0), "gold": 0.15, "nebula_a": 1.3, "warp": 1.25},
	"low_gravity": {"vein": Color(0.55, 0.85, 1.0), "gold": 0.15, "nebula_a": 0.8, "warp": 0.75},
	"rift_tide": {"vein": Color(0.34, 0.95, 0.88), "gold": 0.2, "nebula_a": 1.05, "warp": 1.4},
	"crystal_vein": {"vein": Color(0.3, 0.92, 0.85), "gold": 0.5, "nebula_a": 0.95, "warp": 1.0},
}

## 由 battlefield 注入：背景 Sprite 的 ShaderMaterial（endless_warp.gdshader），时间/振幅由本层驱动
var warp_material: ShaderMaterial = null
## 截图/测试用：true 时不再随 wave_spawned 变化（force_depth 即时生效）
var depth_locked := false
## 当前渗度（0-5；battlefield 换档底图读取）
var current_depth: int = 0
## 里程碑播报开关（QA 可关）
var announce_milestones := true

## v27: 渗度变化广播（battlefield 据此换档底图+交叉淡入）
signal seepage_changed(depth: int)

var _last_depth: int = -1

var _look: Dictionary = _ENV_LOOK_DEFAULT
var _n: float = 0.0
var _target_n: float = 0.0
var _time: float = 0.0
## 渗度提升脉冲能量（1→0 指数衰减，~1.6s）：每 10 波一次的全场可见反馈
## （晶脉闪亮/星云涌动/扭曲加剧），让档内波次推进也有可感知变化
var _pulse_energy: float = 0.0
var _motion_reduce: bool = false
var _nebula: Sprite2D = null
var _veins: VeinLayer = null
var _twinkle: TwinkleLayer = null
var _seepage_label: Label = null


func _ready() -> void:
	z_index = -8
	_motion_reduce = _read_motion_reduce()
	var env_key := _read_rift_env()
	if _ENV_LOOK.has(env_key):
		_look = _ENV_LOOK[env_key]
	var geo := _collect_geometry()
	_build_nebula(float(geo["w"]), float(geo["h"]))
	_twinkle = TwinkleLayer.new()
	_twinkle.name = "RiftTwinkle"
	add_child(_twinkle)
	_twinkle.setup(float(geo["w"]), float(geo["ground_top"]) - 46.0, _motion_reduce)
	_veins = VeinLayer.new()
	_veins.name = "RiftVeins"
	add_child(_veins)
	_veins.build(geo, _look, env_key)
	_connect_wave_signal()
	_sync_initial_depth()
	_apply_intensity()


func _exit_tree() -> void:
	var sb := get_node_or_null("/root/SignalBus")
	if sb != null and sb.has_signal("wave_spawned") and sb.wave_spawned.is_connected(_on_wave_spawned):
		sb.wave_spawned.disconnect(_on_wave_spawned)


func _process(delta: float) -> void:
	_time += delta
	if _pulse_energy > 0.0:
		_pulse_energy = maxf(0.0, _pulse_energy - delta / 1.6)
	if _n != _target_n or _pulse_energy > 0.0:
		if _n != _target_n:
			_n = move_toward(_n, _target_n, delta / INTENSITY_RAMP_SEC)
		_apply_intensity()
	if warp_material != null:
		warp_material.set_shader_parameter("time_acc", _time)
	if _nebula != null and not _motion_reduce:
		# 极慢摆旋 + 横漂（振幅小到不暴露贴图四角；scale 1.42 下 ±2° 安全）
		_nebula.rotation = sin(_time * 0.05) * 0.035
		_nebula.position.x = _nebula.get_meta("base_x", 640.0) + sin(_time * 0.021) * 14.0


## 渗度驱动（由 wave_spawned 触发；depth 0..5 → 归一化 0..1）
func set_depth(depth: int) -> void:
	current_depth = clampi(depth, 0, 5)
	_target_n = clampf(float(depth) / SEEPAGE_MAX, 0.0, 1.0)
	if current_depth != _last_depth:
		var increased := _last_depth >= 0 and current_depth > _last_depth
		_last_depth = current_depth
		seepage_changed.emit(current_depth)
		if increased:
			_pulse_energy = 1.0  # 晶脉闪亮/星云涌动/扭曲加剧（~1.6s 衰减）
			if announce_milestones:
				_announce_seepage(current_depth)


## 渗度档位（depth 0-1→初期 / 2-3→中期 / 4-5→深渊）；battlefield 换底图用同一映射
static func tier_for_depth(depth: int) -> int:
	return 0 if depth <= 1 else (1 if depth <= 3 else 2)


## 里程碑播报："更深了"的成就时刻。用专属 Label（顶部横条下方空闲区）而非
## TopCenterAnnouncer——announcer 在 HudLayer(40)，会被 ToastLayer(200) 的常驻
## toast（如部署失败重试）压住；渗度提升一局仅 5 次，值得独立显示位。
func _announce_seepage(depth: int) -> void:
	if _seepage_label == null or not is_instance_valid(_seepage_label):
		_seepage_label = Label.new()
		_seepage_label.name = "SeepageAnnounce"
		_seepage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_seepage_label.add_theme_font_size_override("font_size", 24)
		_seepage_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.9))
		_seepage_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.08, 0.92))
		_seepage_label.add_theme_constant_override("outline_size", 6)
		_seepage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_seepage_label.z_index = 5
		add_child(_seepage_label)
	var vp := get_viewport_rect().size
	_seepage_label.text = "◈ 渗度提升 · %d" % depth
	# 中央偏左真空带：避开波次横幅(中上 y108-152)、boss 大字(y170-215 x680+)、
	# toast(y258-296)、左侧 BUFF 面板(x<190)——渗度播报恰在波次切换瞬间触发，必须错峰
	_seepage_label.position = Vector2(280.0, 178.0)
	_seepage_label.size = Vector2(360.0, 34.0)
	_seepage_label.visible = true
	if _motion_reduce:
		_seepage_label.modulate.a = 1.0
		return
	_seepage_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_seepage_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(2.6)
	tw.tween_property(_seepage_label, "modulate:a", 0.0, 0.8)


## 截图/测试用：锁定渗度并即时生效（跳过缓动与播报；仍广播信号以驱动档位换景）
func force_depth(depth: int) -> void:
	depth_locked = true
	current_depth = clampi(depth, 0, 5)
	_last_depth = current_depth
	_target_n = clampf(float(depth) / SEEPAGE_MAX, 0.0, 1.0)
	_n = _target_n
	_apply_intensity()
	seepage_changed.emit(current_depth)


func _apply_intensity() -> void:
	var n := _n
	var pulse := _pulse_energy * float(0 if _motion_reduce else 1)
	if _veins != null:
		_veins.modulate.a = clampf(lerpf(0.35, 1.0, n) * (1.0 + 0.8 * pulse), 0.0, 1.5)
	if _twinkle != null:
		_twinkle.set_intensity(n)
	if _nebula != null:
		_nebula.modulate.a = clampf(
			lerpf(0.06, 0.16, n) * float(_look.get("nebula_a", 1.0)) * (1.0 + 1.1 * pulse),
			0.0, 0.42)
	if warp_material != null:
		var amp: float = lerpf(0.0012, 0.0042, n) * float(_look.get("warp", 1.0)) * (1.0 + 2.5 * pulse)
		if _motion_reduce:
			amp = 0.0
		warp_material.set_shader_parameter("warp_amplitude", amp)


func _build_nebula(w: float, h: float) -> void:
	_nebula = Sprite2D.new()
	_nebula.name = "RiftNebula"
	_nebula.texture = load("res://assets/intro/comic/b5_nebula.png")
	_nebula.position = Vector2(w * 0.5, h * 0.46)
	_nebula.set_meta("base_x", w * 0.5)
	_nebula.scale = Vector2(1.42, 1.42)  # 覆盖摆旋角暴露
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_nebula.material = cm
	add_child(_nebula)


func _read_rift_env() -> String:
	var key := String(_BattleEnvEffects.get_rift_override())
	if key.is_empty():
		var ebm := get_node_or_null("/root/EndlessBlackgateManager")
		if ebm != null:
			key = String(ebm.get("current_rift_env"))
	return key


func _read_motion_reduce() -> bool:
	# DesignTokens 有 class_name（编译期强类型）：直接调静态方法，勿用 has_method/实例化
	return bool(_DT.is_motion_reduce())


func _connect_wave_signal() -> void:
	var sb := get_node_or_null("/root/SignalBus")
	if sb != null and sb.has_signal("wave_spawned") and not sb.wave_spawned.is_connected(_on_wave_spawned):
		sb.wave_spawned.connect(_on_wave_spawned)


func _on_wave_spawned(wave_index: int) -> void:
	if depth_locked:
		return
	set_depth(_EndlessMgr.depth_for_waves(int(wave_index)))


## 中途挂层（非战斗开头）时对齐当前波次的渗度
func _sync_initial_depth() -> void:
	var bm := get_node_or_null("/root/BattleManager")
	if bm == null:
		return
	var ss = bm.get("_spawn_system")
	if ss != null and ss.has_method("get_enemy_wave_index"):
		set_depth(_EndlessMgr.depth_for_waves(int(ss.get_enemy_wave_index())))


## 战场几何：部署带（=晶脉地面带）/ 画布尺寸 / 部署格线折线集
func _collect_geometry() -> Dictionary:
	var vp_size := get_viewport_rect().size
	var vp_w: float = 1280.0
	var vp_h: float = 648.0
	if vp_size.x > 1.0:
		vp_w = vp_size.x
	if vp_size.y > 1.0:
		vp_h = vp_size.y
	var deploy_min: float = vp_h * 0.67
	var deploy_max: float = vp_h * 0.925
	var bf := get_parent()
	if bf != null and bf.has_method("get_deploy_y_bounds"):
		var b: Vector2 = bf.get_deploy_y_bounds()
		if b.y > b.x:
			deploy_min = b.x
			deploy_max = b.y
	var lattice: Array = []
	if bf != null:
		var grid: Node = bf.get_node_or_null("BattleSlotGrid")
		if grid != null:
			lattice = _build_lattice(grid)
	return {
		"w": vp_w,
		"h": vp_h,
		"ground_top": deploy_min - 16.0,
		"ground_bottom": vp_h - 4.0,
		"lattice": lattice,
	}


## 由激活槽位导出部署格线：行线（贯穿同排槽）+ 相邻排槽位间斜向晶脉连线（v9.5 斜阵语言）
func _build_lattice(grid: Node) -> Array:
	var lines: Array = []
	for side in ["player_slot_centers", "enemy_slot_centers"]:
		var centers_v = grid.get(side)
		if centers_v == null or (centers_v as Array).is_empty():
			continue
		var gpos_v = grid.get("position")
		var gpos: Vector2 = gpos_v if gpos_v is Vector2 else Vector2.ZERO
		# 按 y 聚行（4px 桶），行内按 x 排序
		var rows: Array = []  # [{y: float, pts: Array[Vector2]}]
		for c in centers_v:
			var p: Vector2 = gpos + (c as Vector2)
			var placed := false
			for row in rows:
				if absf(float(row["y"]) - p.y) < 6.0:
					(row["pts"] as Array).append(p)
					placed = true
					break
			if not placed:
				rows.append({"y": p.y, "pts": [p]})
		rows.sort_custom(func(a, b): return float(a["y"]) < float(b["y"]))
		for row in rows:
			var pts: Array = row["pts"]
			if pts.size() < 2:
				continue
			pts.sort_custom(func(a, b): return (a as Vector2).x < (b as Vector2).x)
			var y: float = float(row["y"])
			var x0: float = (pts[0] as Vector2).x - 16.0
			var x1: float = (pts[pts.size() - 1] as Vector2).x + 16.0
			lines.append(PackedVector2Array([Vector2(x0, y), Vector2(x1, y)]))
		# 相邻行：每个槽位连到下一行最近槽（距离近才连，构成斜向晶脉格）
		for ri in range(rows.size() - 1):
			var cur: Array = rows[ri]["pts"]
			var nxt: Array = rows[ri + 1]["pts"]
			for a in cur:
				var pa: Vector2 = a
				var best: Vector2 = pa
				var best_d: float = 1e9
				for b2 in nxt:
					var d: float = pa.distance_to(b2)
					if d < best_d:
						best_d = d
						best = b2
				if best_d < 130.0:
					lines.append(PackedVector2Array([pa, best]))
	return lines


## 晶脉/格线/裂纹静态层（构建一次；渗度强度走整体 modulate.a，无需重绘）
class VeinLayer extends Node2D:
	const _GOLD := Color(1.0, 0.82, 0.45)

	var _lines: Array = []  # {pts: PackedVector2Array, col: Color, glow_w, core_w, glow_a, core_a}

	func build(geo: Dictionary, look: Dictionary, env_key: String) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(hash("rift_veins_" + env_key)) + 7  # 同裂隙环境同晶脉走向（可复现）
		var vein_base: Color = look.get("vein", Color(0.25, 0.9, 0.85))
		var gold_frac: float = float(look.get("gold", 0.35))
		var w: float = float(geo.get("w", 1280.0))
		var top: float = float(geo.get("ground_top", 420.0))
		var bottom: float = float(geo.get("ground_bottom", 644.0))
		# 1) 主晶脉网：蜿蜒折线（青金晶髓）
		for i in range(14):
			_lines.append(_make_meander(rng, w, top, bottom, vein_base, gold_frac))
		# 2) 部署格线晶脉勾边（更淡，让位给 BU-5 部署高亮）
		for pts in geo.get("lattice", []):
			_lines.append({"pts": pts, "col": vein_base, "glow_w": 4.0, "core_w": 1.2, "glow_a": 0.05, "core_a": 0.20})
		# 3) 浮陆边缘裂纹：底缘更亮更碎（四缘破碎悬空）
		for i in range(10):
			_lines.append(_make_fracture(rng, w, bottom, vein_base, gold_frac))
		queue_redraw()

	func _draw() -> void:
		for ln in _lines:
			var col: Color = ln["col"]
			draw_polyline(ln["pts"], Color(col.r, col.g, col.b, float(ln["glow_a"])), float(ln["glow_w"]))
			draw_polyline(ln["pts"], Color(col.r, col.g, col.b, float(ln["core_a"])), float(ln["core_w"]))

	func _make_meander(rng: RandomNumberGenerator, w: float, top: float, bottom: float, vein_base: Color, gold_frac: float) -> Dictionary:
		var col := vein_base
		if rng.randf() < gold_frac:
			col = vein_base.lerp(_GOLD, rng.randf_range(0.4, 0.75))
		var pts := PackedVector2Array()
		var x := rng.randf_range(30.0, w - 30.0)
		var y := rng.randf_range(top, maxf(top + 8.0, bottom - 20.0))
		pts.append(Vector2(x, y))
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		for _s in range(rng.randi_range(6, 12)):
			x += dir * rng.randf_range(20.0, 70.0)
			if x < 20.0 or x > w - 20.0:
				dir = -dir
				x += dir * 44.0
			y = clampf(y + rng.randf_range(-34.0, 34.0), top, bottom - 6.0)
			pts.append(Vector2(x, y))
		return {"pts": pts, "col": col, "glow_w": 5.0, "core_w": 1.6, "glow_a": 0.10, "core_a": 0.42}

	func _make_fracture(rng: RandomNumberGenerator, w: float, bottom: float, vein_base: Color, gold_frac: float) -> Dictionary:
		var col := vein_base
		if rng.randf() < gold_frac:
			col = vein_base.lerp(_GOLD, 0.5)
		var pts := PackedVector2Array()
		var x := rng.randf_range(40.0, w - 40.0)
		var y := rng.randf_range(bottom - 34.0, bottom - 8.0)
		pts.append(Vector2(x, y))
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		for _s in range(rng.randi_range(3, 6)):
			x += dir * rng.randf_range(10.0, 30.0)
			y = clampf(y + rng.randf_range(-7.0, 7.0), bottom - 40.0, bottom - 3.0)
			pts.append(Vector2(x, y))
		return {"pts": pts, "col": col.lightened(0.15), "glow_w": 4.0, "core_w": 1.4, "glow_a": 0.15, "core_a": 0.55}


## 暗淡星点闪烁层（星光尽灭调：低亮度白/青/紫；数量与亮度随渗度上升）
class TwinkleLayer extends Node2D:
	const STAR_COUNT := 44

	var _stars: Array = []
	var _t: float = 0.0
	var _n: float = 0.0
	var _static := false

	func setup(w: float, sky_bottom: float, motion_reduce: bool) -> void:
		_static = motion_reduce
		var rng := RandomNumberGenerator.new()
		rng.seed = 20270906
		var tints: Array[Color] = [Color(1, 1, 1), Color(0.75, 0.9, 1.0), Color(0.85, 0.78, 1.0)]
		for i in range(STAR_COUNT):
			_stars.append({
				"pos": Vector2(rng.randf_range(16.0, w - 16.0), rng.randf_range(24.0, sky_bottom)),
				"phase": rng.randf_range(0.0, TAU),
				"speed": rng.randf_range(0.6, 1.8),
				"base_a": rng.randf_range(0.18, 0.5),
				"col": tints[rng.randi() % tints.size()],
				"size": 1.0 if rng.randf() < 0.7 else 2.0,
			})
		if _static:
			_t = 1.0  # 减动效：定格在中间相位，静态可见
			queue_redraw()

	func set_intensity(n: float) -> void:
		_n = clampf(n, 0.0, 1.0)

	func _process(delta: float) -> void:
		if _static:
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var max_i: int = int(STAR_COUNT * lerpf(0.45, 1.0, _n))
		for i in range(mini(max_i, _stars.size())):
			var s: Dictionary = _stars[i]
			var tw: float = 0.5 + 0.5 * sin(_t * float(s["speed"]) + float(s["phase"]))
			var a: float = float(s["base_a"]) * lerpf(0.4, 1.0, _n) * lerpf(0.35, 1.0, tw)
			var c: Color = s["col"]
			draw_rect(Rect2(s["pos"], Vector2(float(s["size"]), float(s["size"]))), Color(c.r, c.g, c.b, a))
