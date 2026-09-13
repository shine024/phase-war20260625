extends Node2D
## 战场根节点：左侧为我方出生，右侧为敌方出生

@onready var player_units: Node2D = $PlayerUnits
@onready var enemy_units: Node2D = $EnemyUnits
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var enemy_spawn: Marker2D = $EnemySpawn
@onready var background: ColorRect = $Background
@onready var ground: ColorRect = $Ground
@onready var level10_bg: Sprite2D = $Level10Background
## v6.4: 战场相机（挂 screen_shake.gd），仅作用于 SubViewport 内渲染，不影响外层 HUD
@onready var battle_camera: Camera2D = $BattleCamera

const PhaseDriverScene = preload("res://scenes/units/phase_field_driver.tscn")
const EnemyPhaseDriverScene = preload("res://scenes/units/enemy_phase_field_driver.tscn")
## v28 T3: 地面 dressing（弹坑/碎石/履带印/枯草撒点，纯视觉）
const _GroundDressingScript = preload("res://scripts/battle/ground_dressing.gd")
var _dressing: Node2D = null
const COMMON_BATTLE_BG_PATH := "res://assets/backgrounds/bg_level_01.png"
const LEVEL_BG_PATH_FMT := "res://assets/backgrounds/bg_level_%02d.png"
## v26.9: 背景整体压暗一档（叠乘在时代 tint 上，略偏冷）——"背景永远比单位暗"，
## 让单位深色描边/投影把轮廓从亮底（沙漠/雪原）里衬出来，弹道特效也更跳。
const BG_DIM := Color(0.80, 0.80, 0.87)
## 缺省 PNG 时生成的战场背景尺寸（与常见关卡图比例接近）
const _PROCEDURAL_BG_WIDTH: int = 1280
const _PROCEDURAL_BG_HEIGHT: int = 720
const _BattlePerfMonScript: Script = preload("res://scripts/battle_performance_monitor.gd")
## 道路带位置（基于背景纹理比例）：用于敌我刷新与部署区
const BATTLE_LANE_CENTER_RATIO := 0.80
## 三行布局：车道带需覆盖上行(center - 30)到下行(center + 60)全程，故从 0.14 提到 0.28。
## 0.28 × 背景高(720) ≈ 200px，半高 100px > 60px 偏移，三行 Y 不会被 _deploy_y clamp 截断。
const BATTLE_LANE_HEIGHT_RATIO := 0.28

const _BattleSlotGridScript: Script = preload("res://scenes/battlefield/battle_slot_grid.gd")
const _CardGridLayout = preload("res://scripts/card_grid_battle_layout.gd")
## v27 黑门彼岸氛围层 + 背景微扭曲（仅无尽模式挂载，见 _ensure_endless_rift_fx）
const _EndlessRiftAmbienceScript: Script = preload("res://scripts/battle/endless_rift_ambience.gd")
const _EndlessWarpShader: Shader = preload("res://shaders/endless_warp.gdshader")

## 结算/清场时保留的战场子节点（勿在此列表外的节点会被 queue_free）
const PERSISTENT_CHILD_NAMES: Dictionary = {
	"PlayerUnits": true,
	"EnemyUnits": true,
	"PhaseFieldDriver": true,
	"EnemyPhaseDriver": true,
	"BattleHUD": true,
	"Level10Background": true,
	"Background": true,
	"BattleSlotGrid": true,
	"Ground": true,
	"PlayerSpawn": true,
	"EnemySpawn": true,
	"BattlePerformanceMonitor": true,
	"BattleCamera": true,  # v6.4: 屏幕震动相机，清场时保留
}

# 性能优化：调试日志文件句柄缓存
var _last_flush_time: int = 0

## 异步背景：避免大纹理同步 load 卡主线程
var _bg_loading_path: String = ""
var _bg_load_generation: int = 0
var _bg_pending_level: int = 1
var _bg_pending_era: int = 0
var _bg_pending_battle_bottom_y: float = 648.0
## v27: 黑门档位底图缓存 [t0,t1,t2]（AI 专属图优先 bg_endless_gate_t{0,1,2}.png，程序化回退；
## 退出无尽在 _apply_background_texture 清除）+ 交叉淡入副底图状态
var _endless_tier_tex: Array = []
var _endless_bg_b: Sprite2D = null
var _endless_tier_cur: int = -1
var _endless_fading: bool = false

# v9.1 组合技浓度场 VFX：订阅 combo_field_state.field_changed 信号，按浓度绘制半透明区域
var _combo_field_state: RefCounted = null
var _field_vfx_dirty: bool = false
var _field_vfx_acc: float = 0.0
const _FIELD_VFX_REFRESH_SEC: float = 0.4
const _ComboFieldStateScript: Script = preload("res://scripts/battle/combo_field_state.gd")
const _VfxImpactFactory: Script = preload("res://scripts/battle/vfx_impact_factory.gd")

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
	# v28 T3: 地面 dressing 节点——树序钉在 Ground 之上（贴片压背景、被 Ambience/单位压）
	# 注意必须先于 _update_background() 创建：_apply_background_texture 尾部会对它 setup
	if _dressing == null:
		_dressing = _GroundDressingScript.new()
		_dressing.name = "GroundDressing"
		add_child(_dressing)
		var ground_node := get_node_or_null("Ground")
		move_child(_dressing, (ground_node.get_index() + 1) if ground_node != null else get_child_count() - 1)
	_update_background()
	call_deferred("_sync_battle_slot_grid_lane")
	# v6.4: 把震动相机对齐到视口中心，使其严格等价于无相机渲染（世界原点在视口左上）
	call_deferred("_align_battle_camera")
	# v9.1 组合技浓度场：延迟订阅（battle_manager 在 _ready 后才 setup combo_field_state）
	call_deferred("_subscribe_combo_field_state")


## v9.1 订阅 combo_field_state 的 field_changed 信号以驱动浓度场 VFX
func _subscribe_combo_field_state() -> void:
	var bm: Node = get_node_or_null("/root/BattleManager")
	if bm == null:
		bm = get_node_or_null("/root/Main/BattleManager")
	if bm == null:
		return
	if bm.has_method("get_combo_field_state"):
		_combo_field_state = bm.get_combo_field_state()
	if _combo_field_state != null and _combo_field_state.has_signal("field_changed"):
		if not _combo_field_state.field_changed.is_connected(_on_combo_field_changed):
			_combo_field_state.field_changed.connect(_on_combo_field_changed)


## v9.1 浓度变化回调：标记 dirty，下一帧 _process 重绘（避免信号密集触发时重复重建）
func _on_combo_field_changed(_tag: String, _amount: float) -> void:
	_field_vfx_dirty = true
	# 若 _process 因背景加载完成被停过，浓度变化时重新启用（确保 dirty 被消费）
	if not is_processing():
		set_process(true)


## v6.4: 根据所在 SubViewport 实际尺寸，把 BattleCamera position 设为视口中心，
## 使相机的视野与"无 Camera2D"完全一致（FIXED 模式下 position 即视口中心对应世界点）。
func _align_battle_camera() -> void:
	if battle_camera == null or not is_instance_valid(battle_camera):
		return
	var vp := get_viewport()
	if vp == null:
		return
	var half: Vector2 = vp.get_visible_rect().size * 0.5
	battle_camera.global_position = half
	if OS.is_debug_build():
		print("[BattleCamera] aligned to viewport center: ", half)


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
	# v9.1 组合技浓度场 VFX：dirty 标记驱动 + 定时衰减刷新
	if _combo_field_state != null:
		_field_vfx_acc += _delta
		if _field_vfx_dirty or _field_vfx_acc >= _FIELD_VFX_REFRESH_SEC:
			_field_vfx_acc = 0.0
			_field_vfx_dirty = false
			_redraw_combo_field_vfx()
	if _bg_loading_path.is_empty():
		# v9.1：浓度场需要持续刷新，不能直接 set_process(false)
		if _combo_field_state == null:
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
		battle_bottom_y = 648.0

	# v27 黑门无限模式：程序化星空背景（晶脉浮陆）——置于终局视觉判定之前，
	# 避免第 100 关哨兵把无尽 run 误染成记忆城市灰白调。无资产依赖（运行时
	# ImageTexture 点绘；AI 生图管线产出专属底图后可替换为贴图加载）。
	if GameManager != null and GameManager.has_method("is_endless_battle") and GameManager.is_endless_battle():
		_bg_pending_era = 5
		_bg_pending_battle_bottom_y = battle_bottom_y
		# v27: 渗度档位底图（0-1 初期 / 2-3 中期 / 4-5 深渊）；档位变化由
		# ambience 的 seepage_changed 信号触发交叉淡入（_switch_endless_tier）。
		var depth0 := 0
		var amb0 := get_node_or_null("EndlessRiftAmbience")
		if amb0 != null:
			depth0 = int(amb0.get("current_depth"))
		var tier0: int = _EndlessRiftAmbienceScript.tier_for_depth(depth0)
		_endless_tier_cur = tier0
		_apply_background_texture(_get_endless_tier_tex(tier0))
		return

	# v6.6(剧情): 第100关终战视觉模式（补剧情.txt L137 记忆场景）
	# 用灰白冷色调覆盖背景，表现"主角记忆中的城市/办公楼/小区"
	if _is_final_battle():
		_apply_final_battle_visuals()
		return

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

# ═══════════════════════════════════════════════════════════════════
# v6.6(剧情): 第100关终战视觉模式（补剧情.txt 第十幕 L137 记忆场景）
# ═══════════════════════════════════════════════════════════════════

## 是否为最终战（第100关/相位之主/噬时者降临）
func _is_final_battle() -> bool:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return false
	if gm.has_method("is_final_battle"):
		return gm.is_final_battle()
	return false

## 应用终战视觉：灰白冷色调背景（表现陈末记忆中的城市/办公楼）
func _apply_final_battle_visuals() -> void:
	if background != null and is_instance_valid(background):
		# 记忆场景色调：偏冷的灰白，暗示"这不是真实战场，是回忆"
		background.color = Color(0.18, 0.20, 0.26, 1.0)
	if level10_bg != null and is_instance_valid(level10_bg):
		level10_bg.visible = false
	# 显示终战字幕（延迟一帧确保场景树就绪）
	call_deferred("_show_final_battle_subtitle")

## 终战开场字幕（补剧情.txt L139 "你愿意为通关付出什么？"）
func _show_final_battle_subtitle() -> void:
	var label := Label.new()
	label.text = "第100关 · 最终试炼\n「这里的每一寸土地，都是你的记忆。」"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 0.95))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 字幕包进半透明背景面板（v7.x 界面一致性修复：原裸 Label 浮在记忆场景灰白背景上几乎不可读）
	var panel := PanelContainer.new()
	panel.name = "FinalBattleSubtitle"
	# 半透明深色底 + 内边距 + 圆角 + 细边框
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.09, 0.78)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.83, 1.0, 0.35)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(label)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position.y = 30
	# 加到 Background 上层（ColorRect 是 Control，可加子节点）
	if background != null and is_instance_valid(background):
		background.add_child(panel)
		# 5秒后淡出
		create_tween().tween_property(panel, "modulate:a", 0.0, 2.0).set_delay(5.0)
		create_tween().tween_callback(panel.queue_free).set_delay(7.5)

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
	# v27 修复：黑门入口"先关卡后标记"（set_current_level 会清无尽标记，故先关卡后
	# start_endless_battle）——boot 时战场 _ready / 选关信号触发的刷新 / 迟到的地球图
	# 异步加载回调，都会带着地球图走到这里且此时 endless 标志已置真。endless 态下收到
	# 非档位底图一律重走选图（_update_background 的 endless 分支换星空）；档位底图放行。
	var endless_now: bool = GameManager != null and GameManager.has_method("is_endless_battle") and GameManager.is_endless_battle()
	if endless_now and not _endless_tier_tex.has(tex):
		_update_background()
		return
	if not endless_now:
		_endless_tier_tex = []
		_endless_tier_cur = -1
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
		Color(0.92, 0.94, 1.0),  # v27 era=5 星冥（近中性冷白，星空底图自带色调）
	]
	level10_bg.modulate = era_tints[era % era_tints.size()] * BG_DIM  # v26.9: 压暗一档
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
		# 基地对齐中行(row1)：lane_center + 中行偏移（在双方中行后面）
		driver.position.y = lane_center_y + _CardGridLayout.ROW_Y_OFFSETS[1]
	var enemy_driver := get_node_or_null("EnemyPhaseFieldDriver") as Node2D
	if enemy_driver != null:
		enemy_driver.position.y = lane_center_y + _CardGridLayout.ROW_Y_OFFSETS[1]
	_deploy_y_min = lane_top_y + 8.0
	_deploy_y_max = lane_bottom_y - 8.0
	_sync_battle_slot_grid_lane()
	level10_bg.visible = true
	if background:
		background.visible = false
	if ground:
		ground.visible = false
	# v27 黑门：无尽 run 挂彼岸氛围层 + 背景微扭曲；普通关确保清除
	# （战场节点跨场复用，材质/氛围层不摘会串场到普通关）
	if GameManager != null and GameManager.has_method("is_endless_battle") and GameManager.is_endless_battle():
		_ensure_endless_rift_fx()
	else:
		_clear_endless_rift_fx()
	# v28 T3: 地面 dressing——tint 对齐背景，撒点参数随关复现（setup 内部按 key 幂等）
	if _dressing != null and is_instance_valid(_dressing):
		_dressing.modulate = level10_bg.modulate
		var endless_for_dressing: bool = GameManager != null \
			and GameManager.has_method("is_endless_battle") and GameManager.is_endless_battle()
		_dressing.setup(GameManager.current_level if GameManager != null else 1,
			lane_top_y, lane_bottom_y, endless_for_dressing)


# ═══════════════════════════════════════════════════════════════════
# v27 黑门彼岸视觉（美术定案 docs/无限模式_异族设定（草案）.md §5.1；
# 层内容见 endless_rift_ambience.gd：晶脉/格线/星点/星云 + 渗度驱动强度）
# ═══════════════════════════════════════════════════════════════════

func _ensure_endless_rift_fx() -> void:
	if level10_bg.material == null \
			or not (level10_bg.material is ShaderMaterial) \
			or (level10_bg.material as ShaderMaterial).shader != _EndlessWarpShader:
		var mat := ShaderMaterial.new()
		mat.shader = _EndlessWarpShader
		level10_bg.material = mat
	var amb := get_node_or_null("EndlessRiftAmbience")
	if amb == null or not is_instance_valid(amb):
		amb = Node2D.new()
		amb.name = "EndlessRiftAmbience"
		amb.set_script(_EndlessRiftAmbienceScript)
		amb.set("warp_material", level10_bg.material)
		add_child(amb)
	else:
		amb.set("warp_material", level10_bg.material)
	# 渗度变化 → 换档底图交叉淡入（字符串 connect：amb 为 Node 类型，信号是脚本动态成员）
	if not amb.is_connected("seepage_changed", Callable(self, "_on_endless_seepage_changed")):
		amb.connect("seepage_changed", Callable(self, "_on_endless_seepage_changed"))


func _clear_endless_rift_fx() -> void:
	if level10_bg.material != null:
		level10_bg.material = null
	var amb := get_node_or_null("EndlessRiftAmbience")
	if amb != null and is_instance_valid(amb):
		amb.queue_free()
	if _endless_bg_b != null and is_instance_valid(_endless_bg_b):
		_endless_bg_b.queue_free()
	_endless_bg_b = null
	_endless_tier_cur = -1
	_endless_fading = false

## 当 res://assets/backgrounds/*.png 全部缺失时，用关卡/时代驱动的渐变图代替，避免战场只剩纯色底。
func _resolve_missing_background(level: int, era: int) -> void:
	if level10_bg == null:
		_show_fallback_background()
		return
	var tex: Texture2D = _make_procedural_level_background_texture(level, era)
	_apply_background_texture(tex)


## v27 黑门档位底图（晶脉浮陆）：深空靛紫渐变 + 星点 + 底部晶脉地面。
## tier 0-2 = 渗度初期/中期/深渊——越深：天越暗紫、星点越密、星云越浓、晶脉越亮。
## 纯 fill_rect 点绘（无逐像素循环），一次性构建 ~1ms 级；Phase B 的 AI 专属图
## （bg_endless_gate_t{0,1,2}.png）落地后由 _get_endless_tier_tex 优先加载，本函数仅回退。
func _build_endless_starfield_texture(tier: int = 0) -> Texture2D:
	var w: int = 1280
	var h: int = 648
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	# 1) 深空渐变：天顶近黑靛 → 中段暗紫 → 地平线微亮（星云侧光）；tier 越高越暗紫
	var top: Color = Color(0.030, 0.020, 0.075).lerp(Color(0.012, 0.008, 0.050), tier * 0.4)
	var mid: Color = Color(0.075, 0.045, 0.150).lerp(Color(0.060, 0.032, 0.135), tier * 0.4)
	var hor: Color = Color(0.135, 0.105, 0.235).lerp(Color(0.155, 0.095, 0.260), tier * 0.4)
	var hor_y: int = int(h * 0.80)
	for y in range(h):
		var t: float = float(y) / float(hor_y) if y < hor_y else 1.0
		var c: Color
		if y < hor_y:
			c = top.lerp(mid, t * 0.85) if t < 0.6 else mid.lerp(hor, (t - 0.6) / 0.4)
		else:
			c = hor
		# 低频起伏（星云带），两段 sin 叠加；tier 越浓
		var wave: float = 0.5 + 0.5 * sin(float(y) * 0.021) * cos(float(y) * 0.008 + 1.7)
		c = c.lerp(Color(0.10, 0.06, 0.19), wave * (0.35 + 0.16 * tier))
		img.fill_rect(Rect2i(0, y, w, 1), c)
	# 2) 星点：上密下疏，白/青/紫三色，亮度分级（少数亮星画十字光芒）；tier 越密
	var rng := RandomNumberGenerator.new()
	rng.seed = 20270101
	var star_tints: Array[Color] = [
		Color(1.0, 1.0, 1.0), Color(0.78, 0.92, 1.0), Color(0.88, 0.80, 1.0),
	]
	var star_count: int = int(230.0 * (1.0 + 0.45 * tier))
	for i in range(star_count):
		var sy: int = int(pow(rng.randf(), 1.35) * float(hor_y))  # 幂分布：高处密
		var sx: int = rng.randi_range(0, w - 1)
		var bright: float = rng.randf_range(0.35, 1.0)
		var sc: Color = star_tints[rng.randi() % star_tints.size()] * bright
		img.fill_rect(Rect2i(sx, sy, 1, 1), sc)
		if bright > 0.88 and i % 9 == 0:
			# 亮星十字光芒（2px 臂）
			img.fill_rect(Rect2i(sx - 2, sy, 5, 1), sc * 0.55)
			img.fill_rect(Rect2i(sx, sy - 2, 1, 5), sc * 0.55)
	# 3) 晶脉浮陆地面：暗青岩体 + 发光晶脉纹（青色短线网）；tier 越亮越密
	var ground_y: int = int(h * 0.86)
	for y in range(ground_y, h):
		var gt: float = float(y - ground_y) / float(h - ground_y)
		var gc: Color = Color(0.050, 0.075, 0.095).lerp(Color(0.020, 0.032, 0.045), gt)
		img.fill_rect(Rect2i(0, y, w, 1), gc)
	var vein_count: int = int(260.0 * (1.0 + 0.35 * tier))
	for i in range(vein_count):
		var vy: int = rng.randi_range(ground_y + 2, h - 2)
		var vx: int = rng.randi_range(0, w - 3)
		var glow: float = rng.randf_range(0.45, 0.95) + 0.08 * tier
		img.fill_rect(Rect2i(vx, vy, rng.randi_range(2, 5), 1), Color(0.25, 0.90, 0.85) * minf(glow, 1.15))
	var tex := ImageTexture.create_from_image(img)
	return tex

## 档位底图取用：AI 专属图（Phase B）优先，缺失回退程序化；按档惰性构建缓存
const _ENDLESS_TIER_TEX_PATHS: Array[String] = [
	"res://assets/backgrounds/bg_endless_gate_t0.png",
	"res://assets/backgrounds/bg_endless_gate_t1.png",
	"res://assets/backgrounds/bg_endless_gate_t2.png",
]

func _get_endless_tier_tex(tier: int) -> Texture2D:
	tier = clampi(tier, 0, 2)
	while _endless_tier_tex.size() <= tier:
		_endless_tier_tex.append(null)
	if _endless_tier_tex[tier] != null:
		return _endless_tier_tex[tier]
	var tex: Texture2D = null
	var p: String = _ENDLESS_TIER_TEX_PATHS[tier]
	if ResourceLoader.exists(p):
		tex = ResourceLoader.load(p) as Texture2D
	if tex == null:
		tex = _build_endless_starfield_texture(tier)
	_endless_tier_tex[tier] = tex
	return tex


## 渗度变化 → 换档底图 + 交叉淡入（ambience.seepage_changed 触发；战斗中实时）
func _on_endless_seepage_changed(depth: int) -> void:
	if not (GameManager != null and GameManager.has_method("is_endless_battle") and GameManager.is_endless_battle()):
		return
	var tier: int = _EndlessRiftAmbienceScript.tier_for_depth(int(depth))
	if tier == _endless_tier_cur or _endless_fading or level10_bg == null:
		return
	_switch_endless_tier(tier)


func _switch_endless_tier(tier: int) -> void:
	var new_tex: Texture2D = _get_endless_tier_tex(tier)
	if new_tex == null or level10_bg == null:
		return
	if _endless_tier_cur < 0:
		_endless_tier_cur = tier  # 首次由 _apply 直接呈现，无需淡入
		return
	_endless_tier_cur = tier
	if _endless_bg_b == null or not is_instance_valid(_endless_bg_b):
		_endless_bg_b = Sprite2D.new()
		_endless_bg_b.name = "EndlessBgB"
		_endless_bg_b.centered = false
		_endless_bg_b.z_index = level10_bg.z_index  # 同层 -10；树序在后 → 画在主底图上
		_endless_bg_b.material = level10_bg.material  # 共享扭曲材质（uniform 同步）
		add_child(_endless_bg_b)
	var mc := level10_bg.modulate
	_endless_bg_b.texture = new_tex
	_endless_bg_b.position = level10_bg.position
	_endless_bg_b.modulate = Color(mc.r, mc.g, mc.b, 0.0)
	_endless_fading = true
	var tw := create_tween()
	tw.tween_property(_endless_bg_b, "modulate:a", 1.0, 2.5)
	tw.tween_callback(func() -> void:
		if level10_bg != null and is_instance_valid(level10_bg) \
				and _endless_bg_b != null and is_instance_valid(_endless_bg_b):
			level10_bg.texture = _endless_bg_b.texture
			_endless_bg_b.modulate.a = 0.0
		_endless_fading = false)

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

## 部署带 Y 边界（车道高度范围；X 向部署带功能已随 spawn_range_ratio 下线，v21.x 删除）
var _deploy_y_min: float = 40.0
var _deploy_y_max: float = 540.0
# v21.x: 删除 is_position_in_player_deploy_zone / get_player_deploy_position 及
# _DEPLOY_BATTLE_MIN_X/_DEPLOY_BATTLE_MAX_X/_DEFAULT_DEPLOY_TOLERANCE_PX——
# spawn_range_ratio 部署带功能下线，全项目零调用方。

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


## 格子战术：敌槽位 → 全局坐标；Y 与 `_deploy_y_*` 对齐，避免槽位 Y 与单位脚本硬夹不一致导致叠点、错位
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
		driver.global_position = get_player_spawn_position() + Vector2(-40, _CardGridLayout.ROW_Y_OFFSETS[1])  # Y 对齐中行(row1)

func ensure_enemy_phase_driver(master_config: Dictionary = {}) -> Node2D:
	var driver := get_node_or_null("EnemyPhaseFieldDriver") as Node2D
	if driver == null:
		driver = EnemyPhaseDriverScene.instantiate()
		add_child(driver)
		driver.global_position = get_enemy_spawn_position() + Vector2(80, _CardGridLayout.ROW_Y_OFFSETS[1])  # Y 对齐中行(row1)
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
			# v7.x 修复：跳过非单位节点（伤害数字、特效等混在容器里时会被误判为可点单位）
			if not (child.is_in_group("player_units") or child.is_in_group("enemy_units")):
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
	# 我方相位师基地同样挂在战场根节点（不在 PlayerUnits 容器内），需对称兜底
	# 未加此前点击我方基地 get_unit_at_position 返回空 → 点击无反应（敌方有上面兜底故可点）
	var player_driver := get_node_or_null("PhaseFieldDriver") as Node2D
	if player_driver != null and is_instance_valid(player_driver):
		var pd := viewport_pos.distance_to(player_driver.global_position)
		if pd < hit_radius and pd < best_d:
			best_d = pd
			best = {"unit": player_driver, "is_player": true}
	return best


## v6.4: 触发屏幕震动（命中/爆炸反馈）。强度档位建议：
## 命中 ~2-3，爆炸 ~5-6，Boss死亡 ~10。duration 单位秒。
func request_screen_shake(intensity: float, duration: float) -> void:
	if battle_camera == null or not is_instance_valid(battle_camera):
		return
	if battle_camera.has_method("start_shake"):
		battle_camera.start_shake(intensity, duration, true)


## v6.4: 获取战场相机（供外部系统如 BattleManager 读取）
func get_battle_camera() -> Camera2D:
	return battle_camera


# ═══════════════════════════════════════════════════════════════════
# v9.1 组合技浓度场 VFX（战场地面半透明区域）
# ═══════════════════════════════════════════════════════════════════

## 重绘战场浓度场（纳米/化学）。由 _process 节流（dirty 或 0.4s 周期）。
func _redraw_combo_field_vfx() -> void:
	if _combo_field_state == null:
		return
	var center := _get_field_vfx_center()
	var nano_amt: float = _combo_field_state.get_field(_ComboFieldStateScript.FIELD_NANO)
	var chem_amt: float = _combo_field_state.get_field(_ComboFieldStateScript.FIELD_CHEM)
	_VfxImpactFactory.spawn_nano_field(self, center, nano_amt)
	_VfxImpactFactory.spawn_chem_field(self, center, chem_amt)


## 浓度场中心：取玩家单位与敌方单位的战场中心点（让区域覆盖双方交战区）
func _get_field_vfx_center() -> Vector2:
	var cx: float = 640.0
	var cy: float = 360.0
	if player_spawn != null and enemy_spawn != null:
		cx = (player_spawn.position.x + enemy_spawn.position.x) * 0.5
		cy = (player_spawn.position.y + enemy_spawn.position.y) * 0.5
	return Vector2(cx, cy)
