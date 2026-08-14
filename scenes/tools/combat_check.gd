## 战斗效果检查场
## 左右各放一个单位（我方/敌方），选定后自动对射，可分别开关 / 暂停单帧 / 单发 / 调速。
## 100% 复用项目真实战斗效果：卡图缩放对齐 / muzzle 位置 / bullet 弹道 / 击中特效 / 伤害数字。
##
## 用法：主菜单 → 🔧 战斗效果检查 → 选我方卡 + 敌方 archetype → 切换 → 自动开打。
##
## 设计：零侵入，不改任何现有代码。单位/子弹/特效全部走原场景原脚本原池。
extends Node2D

const GC := preload("res://resources/game_constants.gd")
const DefaultCards := preload("res://data/default_cards.gd")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")
const UnitStatsTable := preload("res://resources/unit_stats_table.gd")
const CardFootAnchors := preload("res://data/card_foot_anchors.gd")
const MuzzleAnchors := preload("res://data/muzzle_anchors.gd")
const PlayerMuzzleAnchors := preload("res://data/player_muzzle_anchors.gd")  # 我方卡专属开火点（fireX 已按朝左转换）
const ConstructUnitAI := preload("res://scripts/battle/construct_unit_ai.gd")
const CardGridUnitVisuals := preload("res://scripts/card_grid_unit_visuals.gd")

const ConstructUnitScene := preload("res://scenes/units/construct_unit.tscn")
const EnemyUnitScene := preload("res://scenes/units/enemy_unit.tscn")

# 可视化开火点标记（红色十字 + 圆圈），单位实际开火时子弹从此处冒出
var _show_muzzle_marker: bool = true
var _player_muzzle_marker: Node2D = null
var _enemy_muzzle_marker: Node2D = null

# --- 对位坐标 ---
const PLAYER_POS_X := 380.0
const ENEMY_POS_X := 900.0
const GROUND_Y := 420.0

# --- 运行时状态 ---
var _player_unit: Node = null
var _enemy_unit: Node = null

var _player_card_id: String = ""
var _enemy_archetype_id: String = ""

# 下拉框数据（并行数组）
var _player_ids: Array = []   # String card_id
var _enemy_ids: Array = []    # String archetype_id

# 控制状态
var _player_fire_on: bool = true
var _enemy_fire_on: bool = true
var _stepping: bool = false

# UI 节点引用
@onready var _player_units_node: Node = $Battlefield/PlayerUnits
@onready var _enemy_units_node: Node = $Battlefield/EnemyUnits
@onready var _player_opt: OptionButton = $UiLayer/PlayerSelectPanel/PlayerOptionButton
@onready var _enemy_opt: OptionButton = $UiLayer/EnemySelectPanel/EnemyOptionButton
@onready var _player_switch_btn: Button = $UiLayer/PlayerSelectPanel/PlayerSwitchButton
@onready var _enemy_switch_btn: Button = $UiLayer/EnemySelectPanel/EnemySwitchButton
@onready var _player_fire_toggle: CheckButton = $UiLayer/ControlPanel/PlayerFireToggle
@onready var _enemy_fire_toggle: CheckButton = $UiLayer/ControlPanel/EnemyFireToggle
@onready var _play_pause_btn: Button = $UiLayer/ControlPanel/PlayPauseButton
@onready var _step_btn: Button = $UiLayer/ControlPanel/StepButton
@onready var _player_single_btn: Button = $UiLayer/ControlPanel/PlayerSingleShotButton
@onready var _enemy_single_btn: Button = $UiLayer/ControlPanel/EnemySingleShotButton
@onready var _reset_btn: Button = $UiLayer/ControlPanel/ResetButton
@onready var _back_btn: Button = $UiLayer/ControlPanel/BackButton
@onready var _muzzle_marker_toggle: CheckButton = $UiLayer/ControlPanel/MuzzleMarkerToggle
@onready var _speed_slider: HSlider = $UiLayer/ControlPanel/SpeedSlider
@onready var _speed_label: Label = $UiLayer/ControlPanel/SpeedLabel
@onready var _step_frames_slider: HSlider = $UiLayer/ControlPanel/StepFramesSlider
@onready var _step_frames_label: Label = $UiLayer/ControlPanel/StepFramesLabel
@onready var _info_panel: RichTextLabel = $UiLayer/InfoPanel
@onready var _effect_toggle_btn: Button = get_node_or_null("UiLayer/ControlPanel/EffectToggleButton")
@onready var _effect_panel: Control = get_node_or_null("UiLayer/EffectLabPanel")


func _ready() -> void:
	# 接信号
	_player_switch_btn.pressed.connect(_on_player_switch)
	_enemy_switch_btn.pressed.connect(_on_enemy_switch)
	_player_fire_toggle.toggled.connect(_on_player_fire_toggled)
	_enemy_fire_toggle.toggled.connect(_on_enemy_fire_toggled)
	_play_pause_btn.pressed.connect(_on_play_pause)
	_step_btn.pressed.connect(_on_step)
	_player_single_btn.pressed.connect(_on_player_single_shot)
	_enemy_single_btn.pressed.connect(_on_enemy_single_shot)
	_reset_btn.pressed.connect(_on_reset)
	_back_btn.pressed.connect(_on_back)
	_speed_slider.value_changed.connect(_on_speed_changed)
	_step_frames_slider.value_changed.connect(_on_step_frames_changed)
	_muzzle_marker_toggle.toggled.connect(_on_muzzle_marker_toggled)
	if _effect_toggle_btn != null:
		_effect_toggle_btn.pressed.connect(_on_effect_toggle)
	if _effect_panel != null:
		# 用 getter 传单位引用（单位会随切换/重置重建，固持引用会失效）
		_effect_panel.configure(Callable(self, "_get_player_unit"), Callable(self, "_get_enemy_unit"), $Battlefield)

	# 让 BattleManager 进入战斗态（建 spatial_grid + 四个 batch，bullet 路径才完整）
	_setup_battle_manager()

	# 填充下拉框
	_populate_player_options()
	_populate_enemy_options()

	# 选默认项并生成单位
	if _player_ids.size() > 0:
		_player_card_id = _player_ids[0]
		_player_opt.select(0)
	if _enemy_ids.size() > 0:
		_enemy_archetype_id = _enemy_ids[0]
		_enemy_opt.select(0)

	_spawn_both()

	# 初始刷新 InfoPanel
	set_process(true)


func _exit_tree() -> void:
	# 还原 time_scale，避免影响其他场景
	Engine.time_scale = 1.0
	# 关闭 BattleManager 战斗态（避免它的 _process 继续跑）
	if BattleManager != null:
		BattleManager.battle_active = false


# ============================================================
# 效果实验室面板：接线（单位 getter + 切换按钮）
# ============================================================
func _get_player_unit() -> Node:
	if _player_unit != null and is_instance_valid(_player_unit):
		return _player_unit
	return null


func _get_enemy_unit() -> Node:
	if _enemy_unit != null and is_instance_valid(_enemy_unit):
		return _enemy_unit
	return null


func _on_effect_toggle() -> void:
	if _effect_panel != null:
		_effect_panel.toggle()


func _notify_effect_panel_units_changed() -> void:
	if _effect_panel != null:
		_effect_panel.notify_units_changed()


# ============================================================
# BattleManager 就绪：建 spatial_grid + 四个 batch
# ============================================================
func _setup_battle_manager() -> void:
	if BattleManager == null:
		push_error("[CombatCheck] BattleManager autoload 不存在，无法启动")
		return
	BattleManager.battlefield = $Battlefield
	# 复用 BattleManager 自己的 setup 方法（会 add_child 到 battlefield）
	if BattleManager.spatial_grid == null or not is_instance_valid(BattleManager.spatial_grid):
		BattleManager._setup_spatial_grid()
	if BattleManager.player_projectile_batch == null or not is_instance_valid(BattleManager.player_projectile_batch):
		BattleManager._setup_player_projectile_batch()
	if BattleManager.enemy_projectile_batch == null or not is_instance_valid(BattleManager.enemy_projectile_batch):
		BattleManager._setup_enemy_projectile_batch()
	if BattleManager.player_indirect_batch == null or not is_instance_valid(BattleManager.player_indirect_batch):
		BattleManager._setup_player_indirect_batch()
	if BattleManager.enemy_indirect_batch == null or not is_instance_valid(BattleManager.enemy_indirect_batch):
		BattleManager._setup_enemy_indirect_batch()
	BattleManager.battle_active = true


# ============================================================
# 下拉框填充
# ============================================================
func _populate_player_options() -> void:
	_player_opt.clear()
	_player_ids.clear()
	# 用轻量版（不构建 133 张卡对象，启动快），再过滤出战斗卡
	var all_ids: Array = DefaultCards.get_all_blueprint_ids_lightweight()
	for cid in all_ids:
		var card = DefaultCards.get_card_by_id(cid)
		if card == null:
			continue
		if card.card_type != GC.CardType.COMBAT_UNIT:
			continue  # 排除能量卡
		var wt_name: String = GC.get_weapon_type_name(int(card.weapon_type))
		var era_name: String = GC.get_era_name(int(card.era))
		var dname: String = String(card.display_name)
		# 显示「中文名 (card_id) [时代·武器]」；无中文名时回退纯 ID
		var display: String
		if not dname.is_empty():
			display = "%s (%s) [%s·%s]" % [dname, cid, era_name, wt_name]
		else:
			display = "%s [%s·%s]" % [cid, era_name, wt_name]
		_player_opt.add_item(display)
		_player_ids.append(cid)
	# 按显示文本排序便于查找
	_sort_option_button(_player_opt, _player_ids)


func _populate_enemy_options() -> void:
	_enemy_opt.clear()
	_enemy_ids.clear()
	var all_ids: Array = EnemyArchetypes.get_all_ids()
	for aid in all_ids:
		var cfg: Dictionary = EnemyArchetypes.get_config(aid)
		var display_name: String = String(cfg.get("display_name", cfg.get("name", "")))
		var wt_name: String = GC.get_weapon_type_name(int(cfg.get("weapon_type", 0)))
		var display: String = "%s  [%s·%s]" % [aid, display_name, wt_name] if not display_name.is_empty() else "%s  [%s]" % [aid, wt_name]
		_enemy_opt.add_item(display)
		_enemy_ids.append(aid)
	_sort_option_button(_enemy_opt, _enemy_ids)


# OptionButton + 并行数组联动排序（按显示文本）
func _sort_option_button(opt: OptionButton, ids: Array) -> void:
	var n: int = opt.item_count
	# 简单选择排序（数据量 ~100，无需复杂算法）
	for i in n - 1:
		var best: int = i
		for j in range(i + 1, n):
			if opt.get_item_text(j) < opt.get_item_text(best):
				best = j
		if best != i:
			var tmp_text: String = opt.get_item_text(i)
			opt.set_item_text(i, opt.get_item_text(best))
			opt.set_item_text(best, tmp_text)
			var tmp_id = ids[i]
			ids[i] = ids[best]
			ids[best] = tmp_id


# ============================================================
# 单位生成
# ============================================================
func _spawn_both() -> void:
	_clear_units()
	_spawn_player()
	_spawn_enemy()
	# 互指目标
	if _player_unit != null and _enemy_unit != null:
		_player_unit.target = _enemy_unit
		_enemy_unit.target = _player_unit
	# 应用开火开关状态
	_apply_fire_toggles()
	_notify_effect_panel_units_changed()


func _spawn_player() -> void:
	if _player_card_id.is_empty():
		return
	var card = DefaultCards.get_card_by_id(_player_card_id)
	if card == null:
		push_error("[CombatCheck] 找不到我方卡牌: %s" % _player_card_id)
		return
	var card_clone = card.clone()  # 模板只读，用 clone 构建 stats（养成隔离铁律）
	var stats = UnitStatsTable.build_stats_from_card(card_clone)
	var u = ConstructUnitScene.instantiate()
	_player_units_node.add_child(u)
	u.setup(true, stats)  # is_player=true
	# 计算对位 X（若射程过大则拉远，保证在射程内）
	var px: float = PLAYER_POS_X
	var max_range: float = float(stats.attack_range) if stats != null else 300.0
	var spacing: float = ENEMY_POS_X - PLAYER_POS_X
	if max_range > spacing:
		px = ENEMY_POS_X - max_range - 60.0  # 留 60px 余量，保证在射程内
		px = clampf(px, 60.0, PLAYER_POS_X)
	u.global_position = Vector2(px, GROUND_Y)
	# 套格子战全套立绘+缩放+HP 条
	if u.has_method("apply_card_grid_combat_started"):
		u.apply_card_grid_combat_started()
	_player_unit = u


func _spawn_enemy() -> void:
	if _enemy_archetype_id.is_empty():
		return
	var e = EnemyUnitScene.instantiate()
	_enemy_units_node.add_child(e)
	e.setup(false, 1, _enemy_archetype_id)  # wave=1 不受难度缩放干扰
	e.global_position = Vector2(ENEMY_POS_X, GROUND_Y)
	# 套格子战全套立绘+缩放+HP 条
	if e.has_method("apply_card_grid_enemy_presentation"):
		e.apply_card_grid_enemy_presentation()
	_enemy_unit = e


func _clear_units() -> void:
	if _player_unit != null and is_instance_valid(_player_unit):
		_player_unit.queue_free()
	_player_unit = null
	if _enemy_unit != null and is_instance_valid(_enemy_unit):
		_enemy_unit.queue_free()
	_enemy_unit = null


# ============================================================
# 攻击控制
# ============================================================
func _apply_fire_toggles() -> void:
	if _player_unit != null and is_instance_valid(_player_unit):
		_player_unit.set_physics_process(_player_fire_on)
	if _enemy_unit != null and is_instance_valid(_enemy_unit):
		_enemy_unit.set_physics_process(_enemy_fire_on)


func _on_player_fire_toggled(pressed: bool) -> void:
	_player_fire_on = pressed
	_apply_fire_toggles()


func _on_enemy_fire_toggled(pressed: bool) -> void:
	_enemy_fire_on = pressed
	_apply_fire_toggles()


func _on_play_pause() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var now_paused: bool = tree.paused
	tree.paused = not now_paused
	_play_pause_btn.text = "▶ 播放" if tree.paused else "⏸ 暂停"


func _on_step() -> void:
	# 单帧步进：确保处于暂停态，然后临时放 N 个 physics_frame 再暂停
	_stepping = true
	var tree := get_tree()
	if tree == null:
		_stepping = false
		return
	tree.paused = true
	_play_pause_btn.text = "▶ 播放"
	var frames: int = int(_step_frames_slider.value)
	for _i in frames:
		await get_tree().physics_frame
	tree.paused = true
	_stepping = false


func _on_player_single_shot() -> void:
	# 手动触发一发（不依赖 _physics_process 循环）
	if _player_unit == null or not is_instance_valid(_player_unit):
		return
	# 确保目标指向有效
	if _player_unit.target == null or not is_instance_valid(_player_unit.target):
		_player_unit.target = _enemy_unit
	# 单发：临时暂停循环，调一次 _do_attack
	var was_physics: bool = _player_unit.is_physics_processing()
	_player_unit.set_physics_process(false)
	# 让单位处于可开火状态（重置 attack phase 到 IDLE）
	if "_attack_phase" in _player_unit:
		_player_unit._attack_phase = 0  # AttackPhase.IDLE
	if "_attack_phase_timer" in _player_unit:
		_player_unit._attack_phase_timer = 0.0
	# 直接调 do_attack（construct_unit.gd:1732 是公开方法）
	if _player_unit.has_method("_do_attack"):
		_player_unit._do_attack()
	# 恢复循环状态
	if was_physics:
		_player_unit.set_physics_process(_player_fire_on)


func _on_enemy_single_shot() -> void:
	if _enemy_unit == null or not is_instance_valid(_enemy_unit):
		return
	if _enemy_unit.target == null or not is_instance_valid(_enemy_unit.target):
		_enemy_unit.target = _player_unit
	var was_physics: bool = _enemy_unit.is_physics_processing()
	_enemy_unit.set_physics_process(false)
	if "_attack_phase" in _enemy_unit:
		_enemy_unit._attack_phase = 0
	if "_attack_phase_timer" in _enemy_unit:
		_enemy_unit._attack_phase_timer = 0.0
	if _enemy_unit.has_method("_do_attack"):
		_enemy_unit._do_attack()
	if was_physics:
		_enemy_unit.set_physics_process(_enemy_fire_on)


func _on_speed_changed(value: float) -> void:
	Engine.time_scale = value
	_speed_label.text = "速度: %.1fx" % value


func _on_step_frames_changed(value: float) -> void:
	_step_frames_label.text = "步进帧数: %d" % int(value)


func _on_muzzle_marker_toggled(pressed: bool) -> void:
	_show_muzzle_marker = pressed
	if not pressed:
		_hide_marker(_player_muzzle_marker)
		_hide_marker(_enemy_muzzle_marker)


# ============================================================
# 切换 / 重置 / 返回
# ============================================================
func _on_player_switch() -> void:
	var idx: int = _player_opt.selected
	if idx < 0 or idx >= _player_ids.size():
		return
	var new_id: String = _player_ids[idx]
	if new_id == _player_card_id:
		return
	_player_card_id = new_id
	# 只重生我方，敌方保留
	var prev_enemy_target = _enemy_unit
	if _player_unit != null and is_instance_valid(_player_unit):
		_player_unit.queue_free()
	_player_unit = null
	_spawn_player()
	if _player_unit != null and prev_enemy_target != null and is_instance_valid(prev_enemy_target):
		_player_unit.target = prev_enemy_target
		_enemy_unit.target = _player_unit
	_apply_fire_toggles()


func _on_enemy_switch() -> void:
	var idx: int = _enemy_opt.selected
	if idx < 0 or idx >= _enemy_ids.size():
		return
	var new_id: String = _enemy_ids[idx]
	if new_id == _enemy_archetype_id:
		return
	_enemy_archetype_id = new_id
	var prev_player_target = _player_unit
	if _enemy_unit != null and is_instance_valid(_enemy_unit):
		_enemy_unit.queue_free()
	_enemy_unit = null
	_spawn_enemy()
	if _enemy_unit != null and prev_player_target != null and is_instance_valid(prev_player_target):
		_enemy_unit.target = prev_player_target
		_player_unit.target = _enemy_unit
	_apply_fire_toggles()


func _on_reset() -> void:
	# 回满血 + 清弹幕（重新生一遍最干净）
	Engine.time_scale = 1.0
	_speed_slider.value = 1.0
	_speed_label.text = "速度: 1.0x"
	get_tree().paused = false
	_play_pause_btn.text = "⏸ 暂停"
	_spawn_both()


func _on_back() -> void:
	Engine.time_scale = 1.0
	if BattleManager != null:
		BattleManager.battle_active = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


# ============================================================
# InfoPanel：实时显示双方关键数据（检查辅助）
# ============================================================
func _process(_delta: float) -> void:
	_refresh_info_panel()
	_update_muzzle_markers()


## F12 截图：用 Godot 引擎内部截屏（绕过远程桌面 GPU 渲染问题）
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		var img := get_viewport().get_texture().get_image()
		var path := "user://combat_check_screenshot.png"
		img.save_png(path)
		print("[CombatCheck] 截图已保存: ", path)
		# 也存一份到项目目录（编辑器模式下可写）
		var path2 := "res://screenshot_panel.png"
		var f_err := img.save_png(path2)
		if f_err == OK:
			print("[CombatCheck] 截图已保存到项目目录: ", path2)
		else:
			print("[CombatCheck] 项目目录保存失败 err=", f_err, "，用 user:// 路径: ", path)


# ============================================================
# 可视化开火点标记：红色十字 + 圆圈，标在单位实际开火点
# 子弹/炮口火从此处冒出，方便肉眼核对位置对不对
# ============================================================
func _ensure_muzzle_marker(unit: Node) -> Node2D:
	# 标记挂在单位身上，跟随单位移动；offset 由 _update_muzzle_markers 每帧设
	if unit == null or not is_instance_valid(unit):
		return null
	# 复用已挂载的
	var existing: Node2D = unit.get_node_or_null("MuzzleMarker")
	if existing != null:
		return existing
	# 用 _draw 画十字+圆圈的内部节点类
	var marker := _MuzzleMarker.new()
	marker.name = "MuzzleMarker"
	unit.add_child(marker)
	return marker


func _update_muzzle_markers() -> void:
	if not _show_muzzle_marker:
		_hide_marker(_player_muzzle_marker)
		_hide_marker(_enemy_muzzle_marker)
		return
	if _player_unit != null and is_instance_valid(_player_unit):
		if _player_muzzle_marker == null or not is_instance_valid(_player_muzzle_marker):
			_player_muzzle_marker = _ensure_muzzle_marker(_player_unit)
		_position_player_marker()
	else:
		_player_muzzle_marker = null
	if _enemy_unit != null and is_instance_valid(_enemy_unit):
		if _enemy_muzzle_marker == null or not is_instance_valid(_enemy_muzzle_marker):
			_enemy_muzzle_marker = _ensure_muzzle_marker(_enemy_unit)
		_position_enemy_marker()
	else:
		_enemy_muzzle_marker = null


func _hide_marker(m: Node2D) -> void:
	if m != null and is_instance_valid(m):
		m.visible = false


## 解析我方单位开火点偏移（局部坐标），完全复刻 construct_unit_ai.gd:_get_direct_fire_spawn_pos。
## v9.x：PlayerMuzzleAnchors（按 card_id 直查，fireX 已按我方朝左转换）优先 → MuzzleAnchors 回退 → 实体中点。
## 返回 {"offset": Vector2, "src": String, "fallback": bool}
func _resolve_player_muzzle_offset(u: Node, spr: Node) -> Dictionary:
	var offset: Vector2 = Vector2.ZERO
	var src: String = ""
	# v9.x 优先：我方卡按 platform_card_id（回退 card_id）直查 PlayerMuzzleAnchors
	if u.get("stats") != null:
		var pcid: String = String(u.stats.platform_card_id)
		if pcid.is_empty() and "card_id" in u.stats:
			pcid = String(u.stats.card_id)
		if not pcid.is_empty() and PlayerMuzzleAnchors.has_anchor(pcid):
			offset = PlayerMuzzleAnchors.get_fire_offset(pcid, spr)
			if offset != Vector2.ZERO:
				src = pcid
	# 回退链：MuzzleAnchors（按 _visual_archetype_id → PLAYER_MIRROR → platform_card_id 反查）
	if offset == Vector2.ZERO:
		var aid: String = String(u.get("_visual_archetype_id"))
		if aid.is_empty() and u.get("stats") != null:
			var pt: int = int(u.stats.platform_type)
			if u.get("PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM") != null:
				aid = String(u.PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM.get(pt, ""))
			if aid.is_empty() and not u.stats.platform_card_id.is_empty():
				aid = u.stats.platform_card_id
		if not aid.is_empty():
			offset = MuzzleAnchors.get_fire_offset(aid, spr)
			if offset != Vector2.ZERO:
				src = aid
	# 最终回退：实体垂直中点（无锚点）
	if offset == Vector2.ZERO:
		if spr != null:
			offset = Vector2.UP * (CardGridUnitVisuals.entity_top_y(spr) * 0.5)
		return {"offset": offset, "src": "", "fallback": true}
	return {"offset": offset, "src": src, "fallback": false}


# 我方开火点：复刻 construct_unit_ai.gd:_get_direct_fire_spawn_pos 的解析逻辑（项目真身）
func _position_player_marker() -> void:
	if _player_muzzle_marker == null:
		return
	var u = _player_unit
	var unit_spr: Sprite2D = u.get_node_or_null("Sprite")
	var r: Dictionary = _resolve_player_muzzle_offset(u, unit_spr)
	_player_muzzle_marker.position = Vector2(r["offset"])  # 相对单位原点的局部坐标
	_player_muzzle_marker.visible = true
	_player_muzzle_marker.set_meta("using_fallback", bool(r["fallback"]))
	_player_muzzle_marker.set_meta("archetype_id", String(r["src"]))


# 敌方开火点：复刻 enemy_unit.gd:1340 的逻辑（项目真身）
func _position_enemy_marker() -> void:
	if _enemy_muzzle_marker == null:
		return
	var e = _enemy_unit
	var spr: Sprite2D = e.get_node_or_null("Sprite2D")
	var aid: String = e.archetype_id
	var muzzle_offset: Vector2 = MuzzleAnchors.get_fire_offset(aid, spr)
	var using_fallback: bool = false
	if muzzle_offset == Vector2.ZERO:
		if spr != null:
			muzzle_offset = Vector2.UP * (CardGridUnitVisuals.entity_top_y(spr) * 0.5)
		using_fallback = true
	_enemy_muzzle_marker.position = muzzle_offset
	_enemy_muzzle_marker.visible = true
	_enemy_muzzle_marker.set_meta("using_fallback", using_fallback)


# 内部类：画红色十字 + 圆圈（回退态改黄色，区分"无锚点回退"）
class _MuzzleMarker extends Node2D:
	const COLOR_FOUND := Color(1.0, 0.2, 0.2, 0.95)    # 红色：有 muzzle 锚点
	const COLOR_FALLBACK := Color(1.0, 0.85, 0.2, 0.95) # 黄色：无锚点回退中点
	const RADIUS := 8.0
	const ARM := 12.0

	func _ready() -> void:
		z_index = 100  # 盖在卡图上方

	func _draw() -> void:
		var col: Color = COLOR_FALLBACK
		if has_meta("using_fallback") and not bool(get_meta("using_fallback")):
			col = COLOR_FOUND
		# 圆圈
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, col, 2.0)
		# 十字
		draw_line(Vector2(-ARM, 0), Vector2(ARM, 0), col, 2.0)
		draw_line(Vector2(0, -ARM), Vector2(0, ARM), col, 2.0)

	func _process(_delta: float) -> void:
		queue_redraw()  # 持续刷新（meta 可能变化）


func _refresh_info_panel() -> void:
	if _info_panel == null:
		return
	var p_text: String = _describe_player()
	var e_text: String = _describe_enemy()
	var extra: String = ""
	var tree := get_tree()
	var paused_str: String = "暂停" if (tree != null and tree.paused) else "运行"
	extra = "\n[color=#888][状态] %s | 速度 %.1fx | 我方开火 %s | 敌方开火 %s[/color]" % [
		paused_str, Engine.time_scale,
		"ON" if _player_fire_on else "OFF",
		"ON" if _enemy_fire_on else "OFF"
	]
	_info_panel.text = "[color=#3ce66c]【我方】[/color]\n%s\n\n[color=#f06666]【敌方】[/color]\n%s%s" % [p_text, e_text, extra]


func _describe_player() -> String:
	if _player_unit == null or not is_instance_valid(_player_unit):
		return "(未生成)"
	var u = _player_unit
	var s = u.get("stats")
	var lines: Array = []
	var vis_id: String = String(u.get("_visual_archetype_id"))
	# 卡名（中文名）+ ID
	var card = DefaultCards.get_card_by_id(_player_card_id)
	var dname: String = String(card.display_name) if card != null else ""
	if not dname.is_empty():
		lines.append("卡名: %s" % dname)
	lines.append("ID: %s" % (vis_id if not vis_id.is_empty() else _player_card_id))
	if s != null:
		lines.append("武器: %s | 射程: %dpx(%d格)" % [GC.get_weapon_type_name(int(s.weapon_type)), int(s.attack_range), int(s.attack_range / 100.0)])
		lines.append("伤害: 轻%.0f/甲%.0f/空%.0f" % [float(s.attack_light), float(s.attack_armor), float(s.attack_air)])
		lines.append("攻速: %.2f/s | 间隔: %.2fs" % [float(s.attack_light_speed), float(s.attack_interval)])
	var max_hp: float = float(s.max_hp) if s != null else float(u.hp)
	lines.append("血量: %.0f / %.0f" % [float(u.hp), max_hp])
	# 开火点：复刻 construct_unit_ai.gd:_get_direct_fire_spawn_pos（PlayerMuzzleAnchors 优先 → MuzzleAnchors → 中点回退）
	var spr = u.get_node_or_null("Sprite")
	var mr: Dictionary = _resolve_player_muzzle_offset(u, spr)
	var mp: Vector2 = Vector2(mr["offset"])
	if spr != null:
		if mp != Vector2.ZERO and not bool(mr["fallback"]):
			lines.append("开火点(本地): (%d, %d) [锚点: %s]" % [int(mp.x), int(mp.y), String(mr["src"])])
		else:
			lines.append("开火点: [color=yellow]无锚点→回退中点[/color] [查: %s]" % String(mr["src"]))
	return "\n".join(lines)


func _describe_enemy() -> String:
	if _enemy_unit == null or not is_instance_valid(_enemy_unit):
		return "(未生成)"
	var e = _enemy_unit
	var cfg: Dictionary = EnemyArchetypes.get_config(_enemy_archetype_id)
	var lines: Array = []
	lines.append("ID: %s" % _enemy_archetype_id)
	var dname: String = String(cfg.get("display_name", cfg.get("name", "")))
	if not dname.is_empty():
		lines.append("名称: %s" % dname)
	lines.append("武器: %s | 射程: %dpx(%d格)" % [GC.get_weapon_type_name(int(cfg.get("weapon_type", 0))), int(cfg.get("attack_range", e.attack_range)), int(float(cfg.get("attack_range", e.attack_range)) / 100.0)])
	lines.append("伤害: %.0f | 攻速: %.2f/s" % [float(cfg.get("attack_damage", e.attack_damage)), 1.0 / maxf(0.05, float(cfg.get("attack_interval", e.attack_interval)))])
	lines.append("血量: %.0f / %.0f" % [float(e.hp), float(e.max_hp)])
	# muzzle 锚点：敌方 _get_direct_fire_spawn_pos 是实例方法，优先用；否则用 MuzzleAnchors
	var spr = e.get_node_or_null("Sprite2D")
	if spr != null:
		var mp: Vector2 = MuzzleAnchors.get_fire_offset(_enemy_archetype_id, spr)
		if mp != Vector2.ZERO:
			lines.append("开火点(本地): (%d, %d)" % [int(mp.x), int(mp.y)])
		else:
			lines.append("开火点: 无锚点(回退中点)")
	return "\n".join(lines)
