## ConstructUnit Deploy Ghost / Progress Bar logic
## 提取自 construct_unit.gd，class_name 用于跨文件引用
class_name ConstructUnitDeploy
extends RefCounted

## 根据单位 deploy_speed 计算实际部署延迟
## 公式：delay = (8.0 - deploy_speed) × 1.5
## deploy_speed=0 → 0秒（堡垒/要塞瞬间部署）
## deploy_speed=7 → 0.5秒
static func calculate_deploy_delay(stats: UnitStats) -> float:
	if stats == null:
		return 1.0
	var speed: int = stats.deploy_speed
	if speed <= 0:
		return 0.0  # 堡垒/要塞瞬间部署
	if speed >= 7:
		return 0.5
	return (8.0 - float(speed)) * 1.5

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
	# 血条定位基于"卡的底部"（势力底图 CardBattleBg 的底），与卡图底部对齐，大小不缩放（保持可读）
	var half_h: float = 0.0
	var spr_y: float = 0.0
	var bg_spr := u.get_node_or_null("CardBattleBg") as Sprite2D
	if bg_spr != null and bg_spr.texture != null:
		half_h = float(bg_spr.texture.get_height()) * absf(bg_spr.scale.y) * 0.5
		spr_y = spr.position.y if spr != null else 0.0
	elif spr != null and spr.texture != null:
		half_h = float(spr.texture.get_height()) * absf(spr.scale.y) * 0.5
		spr_y = spr.position.y
	hb.position = Vector2(0.0, spr_y + half_h + 8.0)
	if hb.has_method("set_side"):
		hb.set_side(true)
	if hb.has_method("set_folded"):
		hb.set_folded(false)
