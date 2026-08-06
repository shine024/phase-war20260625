## ConstructUnit Deploy Ghost / Progress Bar logic
## 提取自 construct_unit.gd，class_name 用于跨文件引用
class_name ConstructUnitDeploy
extends RefCounted

const _Anchors = preload("res://data/card_foot_anchors.gd")

## 根据单位 deploy_speed 计算实际部署延迟
## 公式：delay = (8.0 - deploy_speed) × 1.5
## deploy_speed=0 → 0秒（堡垒/要塞瞬间部署）
## deploy_speed=7 → 0.5秒
static func calculate_deploy_delay(stats: UnitStats) -> float:
	if stats == null:
		return 1.0
	var speed: int = stats.deploy_speed
	var base_delay: float
	if speed <= 0:
		base_delay = 0.0  # 堡垒/要塞瞬间部署
	elif speed >= 7:
		base_delay = 0.5
	else:
		base_delay = (8.0 - float(speed)) * 1.5
	# v6.9: move_speed 类改造重定向为部署延迟百分比加成
	# （玩家单位格子战术不移动，move_speed 为死属性，改造值经 registry 映射到此处）
	# 瞬部署（base=0）的堡垒/要塞跳过加成（无延迟可减）；其他档位乘 (1 + bonus)，下限 0.3 秒
	if base_delay <= 0.0:
		return 0.0
	return maxf(0.3, base_delay * (1.0 + stats.deploy_delay_bonus))

## 启动部署虚影模式
static func start_as_deploy_ghost(u: CharacterBody2D, materialize_after_sec: float = -1.0) -> void:
	u.is_deploy_ghost = true
	var actual_delay: float = materialize_after_sec
	if actual_delay < 0.0:
		actual_delay = calculate_deploy_delay(u.stats)
	u._ghost_materialize_time_left = maxf(0.05, actual_delay)
	u._ghost_total_time = u._ghost_materialize_time_left
	u.modulate = Color(1.0, 1.0, 1.0, 0.42)
	if u._presentation_card_grid and u.is_player:
		var hb_hide := u.get_node_or_null("HpBar") as CanvasItem
		if hb_hide != null:
			hb_hide.visible = false
	# 显示并重置进度条（格子战术只显示卡图，不显示部署条）
	if u._deploy_bar and not (GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle()):
		u._deploy_bar.set_visible(true)
		u._deploy_bar.set_progress(0.0)

## 实体化部署虚影
static func materialize_deploy_ghost(u: CharacterBody2D) -> void:
	u.is_deploy_ghost = false
	u._ghost_materialize_time_left = 0.0
	u.modulate = Color.WHITE
	u._move_target = Vector2.INF
	u.hp = u.stats.max_hp
	if u._presentation_card_grid and u.is_player:
		_configure_card_grid_player_hp_bar(u, u.get_node_or_null("Sprite") as Sprite2D)
		u._cached_hp_ratio = -1.0
		u._update_hp_bar()
	# 卡牌特殊能力：部署后初始化
	CardAbilityManager.on_unit_materialized(u)
	u._register_to_spatial_grid()
	u._update_card_grid_buff_strip(true)
	# v6.14: 实体化后播阵营泛光（我方单位 + 有激活势力时）
	u._play_faction_glow_pulse()
	# v8.x: 部署落地反馈（脚下涟漪 + 能量火花），仅玩家单位
	u._play_materialize_fx()
	# 隐藏进度条
	if u._deploy_bar:
		u._deploy_bar.set_visible(false)

## 强制立即实体化（如果当前是部署虚影）
static func force_materialize_if_deploy_ghost(u: CharacterBody2D) -> void:
	if u.is_deploy_ghost:
		u._ghost_materialize_time_left = 0.0
		materialize_deploy_ghost(u)

## 部署虚影每帧更新（由 _physics_process 调用）
## 返回 true 表示已实体化，主文件应 return
static func update_deploy_ghost(u: CharacterBody2D, delta: float) -> bool:
	u._ghost_materialize_time_left -= delta
	u.velocity = Vector2.ZERO
	u.target = null
	u.move_and_slide()
	u._clamp_inside_battlefield()
	# 更新部署进度条
	if u._deploy_bar and u._ghost_total_time > 0.0:
		var progress = 1.0 - (u._ghost_materialize_time_left / u._ghost_total_time)
		u._deploy_bar.set_progress(progress)
	if u._ghost_materialize_time_left <= 0.0:
		materialize_deploy_ghost(u)
		return true
	return false

## ===== 辅助函数 =====

static func should_card_grid_defend_stance() -> bool:
	return GameManager != null and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle()

static func _configure_card_grid_player_hp_bar(u: CharacterBody2D, spr: Sprite2D) -> void:
	var hb := u.get_node_or_null("HpBar")
	if hb == null:
		return
	if hb is CanvasItem:
		(hb as CanvasItem).visible = true
	# 血条移到头顶：锚定实体顶部上方（state 图标/buff 条占更上方）。
	# entity_top_y 为负值（实体顶在脚上方），血条再往上偏移留出状态图标空间。
	var top_y: float = _Anchors.entity_top_y_for_sprite(spr) if spr != null else -50.0
	hb.position = Vector2(0.0, top_y - 14.0)
	if hb.has_method("set_side"):
		hb.set_side(true)
	if hb.has_method("set_folded"):
		hb.set_folded(false)
