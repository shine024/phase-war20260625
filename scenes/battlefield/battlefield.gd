extends Node2D
## 战场根节点：左侧为我方出生，右侧为敌方出生

@onready var player_units: Node2D = $PlayerUnits
@onready var enemy_units: Node2D = $EnemyUnits
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var enemy_spawn: Marker2D = $EnemySpawn
@onready var background: ColorRect = $Background
@onready var ground: ColorRect = $Ground
@onready var level10_bg: Sprite2D = $Level10Background

const PhaseDriverScene = preload("res://scenes/units/phase_field_driver.tscn")
const EnemyPhaseDriverScene = preload("res://scenes/units/enemy_phase_field_driver.tscn")
const COMMON_BATTLE_BG_PATH := "res://assets/backgrounds/bg_level_01.png"
const LEVEL_BG_PATH_FMT := "res://assets/backgrounds/bg_level_%02d.png"
## 缺省 PNG 时生成的战场背景尺寸（与常见关卡图比例接近）
const _PROCEDURAL_BG_WIDTH: int = 1280
const _PROCEDURAL_BG_HEIGHT: int = 720
const _BattlePerfMonScript: Script = preload("res://scripts/battle_performance_monitor.gd")
## 道路带位置（基于背景纹理比例）：用于敌我刷新与部署区
const BATTLE_LANE_CENTER_RATIO := 0.80
const BATTLE_LANE_HEIGHT_RATIO := 0.14

const _BattleSlotGridScript: Script = preload("res://scenes/battlefield/battle_slot_grid.gd")

## 结算/清场时保留的战场子节点（勿在此列表外的节点会被 queue_free）
const PERSISTENT_CHILD_NAMES: Dictionary = {
	"PlayerUnits": true,
	"EnemyUnits": true,
	"PhaseFieldDriver": true,
	"EnemyPhaseFieldDriver": true,
	"BattleHUD": true,
	"Level10Background": true,
	"Background": true,
	"BattleSlotGrid": true,
	"Ground": true,
	"PlayerSpawn": true,
	"EnemySpawn": true,
	"BattlePerformanceMonitor": true,
}

# 性能优化：调试日志文件句柄缓存
var _last_flush_time: int = 0

## 异步背景：避免大纹理同步 load 卡主线程
var _bg_loading_path: String = ""
var _bg_load_generation: int = 0
var _bg_pending_level: int = 1
var _bg_pending_era: int = 0
var _bg_pending_battle_bottom_y: float = 580.0

func _ready() -> void:
	if OS.is_debug_build() and not Engine.is_editor_hint():
		var pm := Node.new()
		pm.name = "BattlePerformanceMonitor"
		pm.set_script(_BattlePerfMonScript)
		add_child(pm)
	if get_node_or_null("BattleSlotGrid") == null:
		var sg: Node2D = _BattleSlotGridScript.new() as Node2D
		sg.name = "BattleSlotGrid"
		add_child(sg)
	_update_background()
	call_deferred("_sync_battle_slot_grid_lane")


func _sync_battle_slot_grid_lane() -> void:
	var sg: Node = get_node_or_null("BattleSlotGrid")
	if sg == null or not sg.has_method("sync_lane"):
		return
	var cy: float = 360.0
	if player_spawn:
		cy = player_spawn.position.y
	sg.sync_lane(cy, _deploy_y_min, _deploy_y_max)
	snap_card_grid_units_to_slots()

func _process(_delta: float) -> void:
	if _bg_loading_path.is_empty():
		set_process(false)
		return
	var path_loading := _bg_loading_path
	var gen := _bg_load_generation
	var st := ResourceLoader.load_threaded_get_status(path_loading)
	match st:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			_bg_loading_path = ""
			set_process(false)
			if gen != _bg_load_generation:
				return
			var res: Resource = ResourceLoader.load_threaded_get(path_loading)
			if res is Texture2D:
				_apply_background_texture(res as Texture2D)
			else:
				var tex_fallback: Texture2D = _load_texture_from_source_file(path_loading)
				if tex_fallback != null:
					_apply_background_texture(tex_fallback)
				elif _try_apply_alternative_background(_bg_pending_level, _bg_pending_era):
					pass
				else:
					_resolve_missing_background(_bg_pending_level, _bg_pending_era)
		ResourceLoader.THREAD_LOAD_FAILED:
			_bg_loading_path = ""
			set_process(false)
			if gen == _bg_load_generation:
				var tex_fallback_fail: Texture2D = _load_texture_from_source_file(path_loading)
				if tex_fallback_fail != null:
					_apply_background_texture(tex_fallback_fail)
				elif _try_apply_alternative_background(_bg_pending_level, _bg_pending_era):
					pass
				else:
					_resolve_missing_background(_bg_pending_level, _bg_pending_era)
		_:
			pass

func _update_background() -> void:
	var battle_bottom_y: float = get_viewport_rect().size.y
	if battle_bottom_y <= 0.0:
		battle_bottom_y = 580.0

	var level: int = 1
	if GameManager:
		level = clampi(GameManager.current_level, 1, 100)
	_bg_pending_level = level

	var era := 0
	if GameManager and GameManager.has_method("get_era"):
		era = GameManager.get_era(level)

	var level_bg: String = LEVEL_BG_PATH_FMT % level
	var bg_path: String
	if ResourceLoader.exists(level_bg):
		bg_path = level_bg
	else:
		var bg_paths: PackedStringArray = [
			"res://assets/backgrounds/bg_level_01.png",
			"res://assets/backgrounds/bg_01.png",
			"res://assets/backgrounds/bg_02.png",
			"res://assets/backgrounds/bg_03.png",
			"res://assets/backgrounds/bg_default.png",
		]
		bg_path = bg_paths[era % bg_paths.size()]
	_bg_pending_era = era
	_bg_pending_battle_bottom_y = battle_bottom_y

	if level10_bg == null:
		_show_fallback_background()
		return
	if not ResourceLoader.exists(bg_path):
		if _try_apply_alternative_background(level, era):
			return
		_resolve_missing_background(level, era)
		return

	if _bg_loading_path == bg_path:
		_bg_pending_era = era
		_bg_pending_battle_bottom_y = battle_bottom_y
		return

	# 若已有异步任务且路径变更：结束旧请求再发起新加载
	if not _bg_loading_path.is_empty() and _bg_loading_path != bg_path:
		var old_path: String = _bg_loading_path
		set_process(false)
		_bg_loading_path = ""
		_bg_load_generation += 1
		var old_st: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(old_path)
		if old_st == ResourceLoader.THREAD_LOAD_LOADED or old_st == ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(old_path)

	if Engine.is_editor_hint():
		var tex_ed: Texture2D = load(bg_path) as Texture2D
		if tex_ed != null:
			_apply_background_texture(tex_ed)
		else:
			var tex_fallback_ed: Texture2D = _load_texture_from_source_file(bg_path)
			if tex_fallback_ed != null:
				_apply_background_texture(tex_fallback_ed)
			elif _try_apply_alternative_background(level, era):
				pass
			else:
				_resolve_missing_background(level, era)
		return

	if ResourceLoader.has_cached(bg_path):
		var tex_c: Texture2D = ResourceLoader.load(bg_path) as Texture2D
		if tex_c != null:
			_apply_background_texture(tex_c)
		else:
			var tex_fallback_c: Texture2D = _load_texture_from_source_file(bg_path)
			if tex_fallback_c != null:
				_apply_background_texture(tex_fallback_c)
			elif _try_apply_alternative_background(level, era):
				pass
			else:
				_resolve_missing_background(level, era)
		return

	_bg_load_generation += 1
	var my_gen: int = _bg_load_generation
	_bg_loading_path = bg_path
	var err: Error = ResourceLoader.load_threaded_request(bg_path)
	if err != OK:
		_bg_loading_path = ""
		var tex_fallback_req: Texture2D = _load_texture_from_source_file(bg_path)
		if tex_fallback_req != null:
			_apply_background_texture(tex_fallback_req)
		elif _try_apply_alternative_background(level, era):
			pass
		else:
			_resolve_missing_background(level, era)
		return
	set_process(true)
	# 若同一帧已完成（极小资源），在首帧 _process 中处理
	if ResourceLoader.load_threaded_get_status(bg_path) == ResourceLoader.THREAD_LOAD_LOADED:
		_bg_loading_path = ""
		set_process(false)
		if my_gen != _bg_load_generation:
			return
		var res_fast: Resource = ResourceLoader.load_threaded_get(bg_path)
		if res_fast is Texture2D:
			_apply_background_texture(res_fast as Texture2D)
		else:
			var tex_fallback_fast: Texture2D = _load_texture_from_source_file(bg_path)
			if tex_fallback_fast != null:
				_apply_background_texture(tex_fallback_fast)
			elif _try_apply_alternative_background(level, era):
				pass
			else:
				_resolve_missing_background(level, era)

func _load_texture_from_source_file(path: String) -> Texture2D:
	# 某些资源导入状态异常（例如 .import valid=false）时，退回原始 PNG 直读，避免关卡背景丢失。
	var img := Image.new()
	if img.load(path) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	return tex

func _try_apply_alternative_background(level: int, era: int) -> bool:
	var candidates: Array[int] = []
	var era_start: int = era * 20 + 1
	var era_end: int = era_start + 19
	# 同时代内按“邻近优先”回退，尽量保持风格一致
	for offset in range(20):
		var left: int = level - offset
		var right: int = level + offset
		if left >= era_start and left <= era_end and not candidates.has(left):
			candidates.append(left)
		if right >= era_start and right <= era_end and not candidates.has(right):
			candidates.append(right)
	# 时代锚点兜底
	for anchor in [era_start, era_start + 9, era_end]:
		if anchor >= 1 and anchor <= 100 and not candidates.has(anchor):
			candidates.append(anchor)
	# 全局保底
	for global_anchor in [1, 10, 20, 40, 60, 80]:
		if not candidates.has(global_anchor):
			candidates.append(global_anchor)

	for lv in candidates:
		var p: String = LEVEL_BG_PATH_FMT % lv
		var tex: Texture2D = _load_texture_from_resource_file(p)
		if tex != null:
			_apply_background_texture(tex)
			return true
	return false

func _load_texture_from_resource_file(path: String) -> Texture2D:
	if _is_import_marked_invalid(path):
		return null
	var tex: Texture2D = ResourceLoader.load(path) as Texture2D
	return tex

func _is_import_marked_invalid(path: String) -> bool:
	var import_path: String = "%s.import" % path
	if not FileAccess.file_exists(import_path):
		return false
	var f: FileAccess = FileAccess.open(import_path, FileAccess.READ)
	if f == null:
		return false
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line == "valid=false":
			return true
	return false

func _apply_background_texture(tex: Texture2D) -> void:
	if level10_bg == null:
		return
	var battle_bottom_y: float = _bg_pending_battle_bottom_y
	var era: int = _bg_pending_era
	level10_bg.texture = tex
	level10_bg.centered = false
	var tex_h: float = float(tex.get_height())
	var bg_top_y: float = battle_bottom_y - tex_h
	level10_bg.position = Vector2(0.0, bg_top_y)
	var era_tints: Array[Color] = [
		Color(1.0, 0.95, 0.85),
		Color(0.9, 0.95, 0.85),
		Color(0.85, 0.9, 1.0),
		Color(0.95, 0.95, 0.95),
		Color(0.85, 0.95, 1.0),
	]
	level10_bg.modulate = era_tints[era % era_tints.size()]
	var lane_center_y: float = bg_top_y + tex_h * BATTLE_LANE_CENTER_RATIO
	var lane_h: float = tex_h * BATTLE_LANE_HEIGHT_RATIO
	var lane_half_h: float = lane_h * 0.5
	var lane_top_y: float = lane_center_y - lane_half_h
	var lane_bottom_y: float = lane_center_y + lane_half_h
	lane_top_y = clampf(lane_top_y, 0.0, battle_bottom_y - 16.0)
	lane_bottom_y = clampf(lane_bottom_y, lane_top_y + 8.0, battle_bottom_y)
	lane_center_y = (lane_top_y + lane_bottom_y) * 0.5
	if player_spawn:
		player_spawn.position.y = lane_center_y
	if enemy_spawn:
		enemy_spawn.position.y = lane_center_y
	var driver := get_node_or_null("PhaseFieldDriver") as Node2D
	if driver != null:
		driver.position.y = lane_center_y
	var enemy_driver := get_node_or_null("EnemyPhaseFieldDriver") as Node2D
	if enemy_driver != null:
		enemy_driver.position.y = lane_center_y
	_deploy_y_min = lane_top_y + 8.0
	_deploy_y_max = lane_bottom_y - 8.0
	_sync_battle_slot_grid_lane()
	level10_bg.visible = true
	if background:
		background.visible = false
	if ground:
		ground.visible = false

## 当 res://assets/backgrounds/*.png 全部缺失时，用关卡/时代驱动的渐变图代替，避免战场只剩纯色底。
func _resolve_missing_background(level: int, era: int) -> void:
	if level10_bg == null:
		_show_fallback_background()
		return
	var tex: Texture2D = _make_procedural_level_background_texture(level, era)
	_apply_background_texture(tex)

func _make_procedural_level_background_texture(level: int, era: int) -> Texture2D:
	var g := Gradient.new()
	var lv: float = float(clampi(level, 1, 100))
	var phase: float = fmod(lv * 0.37 + float(era) * 1.13, TAU)
	# 五时代主色带：天顶 → 地平线 → 地面暗部
	var era_skies: Array[Color] = [
		Color(0.55, 0.48, 0.36),
		Color(0.42, 0.52, 0.38),
		Color(0.38, 0.44, 0.62),
		Color(0.40, 0.55, 0.58),
		Color(0.48, 0.34, 0.62),
	]
	var e: int = clampi(era, 0, era_skies.size() - 1)
	var sky_top: Color = era_skies[e]
	sky_top = sky_top.lerp(Color(0.75, 0.78, 0.92), 0.12 + 0.08 * sin(phase))
	var sky_mid: Color = sky_top.lerp(Color(0.28, 0.32, 0.42), 0.35 + 0.1 * cos(phase * 0.7))
	var ground: Color = Color(0.06, 0.065, 0.08).lerp(sky_mid, 0.12)
	g.offsets = PackedFloat32Array([0.0, 0.38, 0.62, 1.0])
	g.colors = PackedColorArray([sky_top, sky_mid, sky_mid.darkened(0.25), ground])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = _PROCEDURAL_BG_WIDTH
	gt.height = _PROCEDURAL_BG_HEIGHT
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	return gt

func _show_fallback_background() -> void:
	if Engine.is_editor_hint():
		if background:
			background.visible = true
		if ground:
			ground.visible = true
		if level10_bg:
			level10_bg.visible = false
		return
	if background:
		background.visible = true
	if ground:
		ground.visible = true
	if level10_bg:
		level10_bg.visible = false
	_sync_battle_slot_grid_lane()

func get_player_spawn_position() -> Vector2:
	if player_spawn:
		return player_spawn.global_position
	return Vector2(80, 300)

func get_enemy_spawn_position() -> Vector2:
	if enemy_spawn:
		return enemy_spawn.global_position
	return Vector2(1100, 300)

## 部署带：从我方出生点 X 向敌方方向延伸 (spawn_range_ratio × 至战场右缘距离)；Y 在战场常用高度内
const _DEPLOY_BATTLE_MIN_X: float = 40.0
const _DEPLOY_BATTLE_MAX_X: float = 1240.0
var _deploy_y_min: float = 40.0
var _deploy_y_max: float = 540.0
const _DEFAULT_DEPLOY_TOLERANCE_PX: float = 72.0

func is_position_in_player_deploy_zone(world_pos: Vector2, spawn_range_ratio: float) -> bool:
	var r: float = clampf(spawn_range_ratio, 0.05, 1.0)
	var ax: float = get_player_spawn_position().x
	var span: float = _DEPLOY_BATTLE_MAX_X - ax
	var max_x: float = ax + span * r
	var min_x: float = maxf(_DEPLOY_BATTLE_MIN_X, ax - 120.0)
	return world_pos.x >= min_x and world_pos.x <= max_x and world_pos.y >= _deploy_y_min and world_pos.y <= _deploy_y_max

## 返回玩家部署位置（含容错吸附）：若点击在允许范围附近，则吸附到合法区域并返回。
func get_player_deploy_position(world_pos: Vector2, spawn_range_ratio: float, tolerance_px: float = _DEFAULT_DEPLOY_TOLERANCE_PX) -> Dictionary:
	var r: float = clampf(spawn_range_ratio, 0.05, 1.0)
	var ax: float = get_player_spawn_position().x
	var span: float = _DEPLOY_BATTLE_MAX_X - ax
	var max_x: float = ax + span * r
	var min_x: float = maxf(_DEPLOY_BATTLE_MIN_X, ax - 120.0)
	var tol: float = maxf(0.0, tolerance_px)
	var near_enough: bool = (
		world_pos.x >= (min_x - tol)
		and world_pos.x <= (max_x + tol)
		and world_pos.y >= (_deploy_y_min - tol)
		and world_pos.y <= (_deploy_y_max + tol)
	)
	if not near_enough:
		return {}
	return {
		"position": Vector2(
			clampf(world_pos.x, min_x, max_x),
			clampf(world_pos.y, _deploy_y_min, _deploy_y_max)
		)
	}

## 敌方刷新位置：X 可轻微抖动，Y 始终锁在小道内
func get_enemy_spawn_position_in_lane(x_jitter: float = 20.0, y_jitter: float = 8.0) -> Vector2:
	var base: Vector2 = get_enemy_spawn_position()
	return Vector2(
		base.x + randf_range(-absf(x_jitter), absf(x_jitter)),
		clampf(base.y + randf_range(-absf(y_jitter), absf(y_jitter)), _deploy_y_min, _deploy_y_max)
	)


## 当前关卡背景的部署带 Y 范围（战场局部坐标，与车道/部署吸附一致）
func get_deploy_y_bounds() -> Vector2:
	return Vector2(_deploy_y_min, _deploy_y_max)


func _card_grid_slot_local_to_global(slot_local: Vector2) -> Vector2:
	var grid: Node2D = get_node_or_null("BattleSlotGrid") as Node2D
	if grid == null:
		return slot_local
	var clamped: Vector2 = Vector2(slot_local.x, clampf(slot_local.y, _deploy_y_min, _deploy_y_max))
	return to_global(grid.position + clamped)


## 格子战术：我方槽位 → 战场全局坐标（与敌槽同一车道 Y）
func get_card_grid_player_slot_global(slot_idx: int) -> Vector2:
	var grid: Node2D = get_node_or_null("BattleSlotGrid") as Node2D
	if grid == null or not grid.has_method("get_player_slot_center"):
		return get_player_spawn_position()
	return _card_grid_slot_local_to_global(grid.get_player_slot_center(slot_idx))


## 格子战术：敌槽位 → 全局坐标；Y 与 `_deploy_y_*` 对齐，避免槽位 Y 与单位脚本 280~440 硬夹不一致导致叠点、错位
func get_card_grid_enemy_slot_global(slot_idx: int) -> Vector2:
	var grid: Node2D = get_node_or_null("BattleSlotGrid") as Node2D
	if grid == null or not grid.has_method("get_enemy_slot_center"):
		return get_enemy_spawn_position()
	return _card_grid_slot_local_to_global(grid.get_enemy_slot_center(slot_idx))


## 单个单位吸附到格子槽心（部署后 / 车道 Y 变更后调用）
func snap_card_grid_unit(unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var si: int = int(unit.get_meta("card_grid_slot", -1))
	if si >= 0:
		unit.global_position = get_card_grid_player_slot_global(si)
		return
	var esi: int = int(unit.get_meta("card_grid_enemy_slot", -1))
	if esi >= 0:
		unit.global_position = get_card_grid_enemy_slot_global(esi)


## 背景车道 Y 更新后，把已部署的我方/敌方单位重新吸附到槽位中心（修复异步加载背景前后的错位）
func snap_card_grid_units_to_slots() -> void:
	if GameManager == null or not GameManager.has_method("is_card_grid_battle") or not GameManager.is_card_grid_battle():
		return
	var grid: Node = get_node_or_null("BattleSlotGrid")
	if grid != null and grid.has_method("rebuild_slot_centers_now"):
		grid.rebuild_slot_centers_now()
	if player_units != null:
		for u in player_units.get_children():
			if is_instance_valid(u) and u is Node2D:
				snap_card_grid_unit(u as Node2D)
	if enemy_units != null:
		_snap_enemy_subtree_to_card_grid_slots(enemy_units)


func _snap_enemy_subtree_to_card_grid_slots(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n is Node2D:
		snap_card_grid_unit(n as Node2D)
	for child in n.get_children():
		_snap_enemy_subtree_to_card_grid_slots(child)


func get_player_units_node() -> Node2D:
	return player_units

func get_enemy_units_node() -> Node2D:
	return enemy_units

## 确保格子部署网格存在（被误删或早于 _ready 时由战斗流程补建）
func ensure_battle_slot_grid() -> Node2D:
	var sg: Node2D = get_node_or_null("BattleSlotGrid") as Node2D
	if sg != null and is_instance_valid(sg) and not sg.is_queued_for_deletion():
		return sg
	if sg != null and is_instance_valid(sg):
		sg.queue_free()
	sg = _BattleSlotGridScript.new() as Node2D
	sg.name = "BattleSlotGrid"
	add_child(sg)
	return sg


## 部署/开战前：重建槽位并与当前车道 Y、部署带对齐
func ensure_battle_slot_grid_ready() -> Node2D:
	var sg: Node2D = ensure_battle_slot_grid()
	if sg.has_method("sync_lane"):
		var cy: float = 360.0
		if player_spawn:
			cy = player_spawn.position.y
		sg.sync_lane(cy, _deploy_y_min, _deploy_y_max)
	elif sg.has_method("rebuild_slot_centers_now"):
		sg.rebuild_slot_centers_now()
	return sg


## 清除战斗临时节点（单位、弹道批处理等），保留 PERSISTENT_CHILD_NAMES
func prune_transient_children() -> void:
	for child in get_children():
		if child == null or not is_instance_valid(child):
			continue
		if PERSISTENT_CHILD_NAMES.has(child.name):
			continue
		child.queue_free()


func ensure_phase_driver() -> void:
	# 如上局被摧毁，则在原位置重新生成一个
	if not has_node("PhaseFieldDriver"):
		var driver: Node2D = PhaseDriverScene.instantiate()
		add_child(driver)
		driver.global_position = get_player_spawn_position() + Vector2(-40, 0)

func ensure_enemy_phase_driver(master_config: Dictionary = {}) -> Node2D:
	var driver := get_node_or_null("EnemyPhaseFieldDriver") as Node2D
	if driver == null:
		driver = EnemyPhaseDriverScene.instantiate()
		add_child(driver)
		driver.global_position = get_enemy_spawn_position() + Vector2(80, 0)
	if driver != null:
		if driver.has_method("stop_production"):
			driver.stop_production()
		if driver.has_method("setup"):
			driver.setup(master_config)
	return driver

func _resolve_pick_is_player(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_in_group("player_units") or node.is_in_group("phase_driver"):
		return true
	if node.is_in_group("enemy_units") or node.is_in_group("enemy_phase_driver"):
		return false
	if "is_player" in node:
		return bool(node.is_player)
	var p: Node = node.get_parent()
	while p != null:
		if p.name == "PlayerUnits":
			return true
		if p.name == "EnemyUnits":
			return false
		p = p.get_parent()
	return false


## 根据视口内坐标返回该位置上的单位（用于暂停时点击检测），返回 { "unit": Node, "is_player": bool } 或空字典
func get_unit_at_position(viewport_pos: Vector2) -> Dictionary:
	var hit_radius := 55.0
	var best: Dictionary = {}
	var best_d := 1e9
	# 优先使用空间网格，避免点击检测全量扫描单位节点
	if BattleManager != null and "spatial_grid" in BattleManager:
		var grid: Node = BattleManager.spatial_grid
		if grid != null and is_instance_valid(grid) and grid.has_method("query_nearby"):
			for node in grid.query_nearby(viewport_pos, hit_radius):
				if not is_instance_valid(node) or not (node is Node2D):
					continue
				# 跳过非单位节点（伤害数字、指示器等）
				if not (node.is_in_group("player_units") or node.is_in_group("enemy_units") or node.is_in_group("phase_driver") or node.is_in_group("enemy_phase_driver")):
					continue
				var d_grid := viewport_pos.distance_to((node as Node2D).global_position)
				if d_grid < best_d:
					best_d = d_grid
					best = {"unit": node, "is_player": _resolve_pick_is_player(node)}
	for is_player in [true, false]:
		var parent_node = player_units if is_player else enemy_units
		if parent_node == null:
			continue
		for child in parent_node.get_children():
			if not is_instance_valid(child):
				continue
			var d := viewport_pos.distance_to(child.global_position)
			if d < hit_radius and d < best_d:
				best_d = d
				best = {"unit": child, "is_player": _resolve_pick_is_player(child)}
	# 敌方相位师基地挂在战场根节点，不在 EnemyUnits 内
	var enemy_driver := get_node_or_null("EnemyPhaseFieldDriver") as Node2D
	if enemy_driver != null and is_instance_valid(enemy_driver):
		var dd := viewport_pos.distance_to(enemy_driver.global_position)
		if dd < hit_radius and dd < best_d:
			best_d = dd
			best = {"unit": enemy_driver, "is_player": false}
	return best
