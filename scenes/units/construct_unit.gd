extends CharacterBody2D
## 我方装甲单位：根据 UnitStats 显示形状，自动向右移动并攻击

const GC = preload("res://resources/game_constants.gd")
const BulletScene = preload("res://scenes/units/bullet.tscn")
const CardAbilityManager = preload("res://managers/card_ability_manager.gd")
const AffixCombatHandler = preload("res://managers/affix_combat_handler.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const RankRules = preload("res://data/rank_rules.gd")
const CardGridUnitVisuals = preload("res://scripts/card_grid_unit_visuals.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CardGridDamage = preload("res://scripts/card_grid_damage.gd")
const CombatTargeting = preload("res://scripts/combat_targeting.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
# ObjectPoolManager 为 autoload
const BATTLE_MIN_X: float = 40.0
const BATTLE_MAX_X: float = 1240.0
const BATTLE_MIN_Y: float = 280.0
const BATTLE_MAX_Y: float = 440.0
## 我方单位前进上限（留出屏幕边缘余量）
const PLAYER_MAX_ADVANCE_X: float = 1160.0
const OMEGA_SPRITE_PATH := "res://assets/unit_sprites/omega_platform.png"
const OmegaTex = preload("res://assets/unit_sprites/omega_platform.png")
## 与 EnemyUnit 一致：允许 1024 卡面，仍拒绝整张地图级贴图
const MAX_ENEMY_FRAME_TEX_DIM := 1280


## 部署/产兵常在 add_child 前 setup；未入树时不能用本节点的绝对路径 get_node
static func _resolve_autoload(autoload_name: StringName) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var root: Window = (loop as SceneTree).root
		if root != null:
			return root.get_node_or_null(NodePath(autoload_name))
	return null
const MAX_ENEMY_VISUAL_EXTENT_PX := 220.0
const ENEMY_VISUAL_ASSET_BASE := "res://assets/enemies"
## 我方平台类型 -> 用于显示的敌方原型 id（与 EnemyUnit 同源，直接读 ENEMY_VISUAL_ASSET_BASE，不再使用 player_from_enemy 副本目录）
const PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM := {
	GC.PlatformType.HOUND: "enemy_ww1_infantry_basic",
	GC.PlatformType.GUARD: "enemy_ww2_infantry",
	GC.PlatformType.TITAN: "elite_ww1_armored",
	GC.PlatformType.FORTRESS: "enemy_ww1_mg_nest",
	GC.PlatformType.RADAR: "enemy_modern_stryker",
	GC.PlatformType.SCOUT: "enemy_cold_btr",
	GC.PlatformType.RAIDER: "enemy_future_hovertank",
	GC.PlatformType.SIEGE: "enemy_ww1_mortar",
	GC.PlatformType.CARRIER: "enemy_cold_m113",
	GC.PlatformType.MEDIC: "enemy_modern_marine",
	GC.PlatformType.STEALTH: "elite_future_spectre",
	GC.PlatformType.OMEGA_PLATFORM: "enemy_future_mech",
}
var is_player: bool = true
var stats: UnitStats
var hp: float = 100.0
var shield: float = 0.0  # 护盾值
var attack_timer: float = 0.0
var target: Node2D = null
var _weapon_cfgs: Array = []
var _move_target: Vector2 = Vector2.INF
## 我方战场姿态：true=进攻（向敌侧推进），false=防守（无移动指令时固守当前位置）
var _field_stance_attack: bool = true
var _law_regen_per_sec: float = 0.0
var _base_stats_ready: bool = false
var _base_max_hp: float = 100.0
var _base_attack_damage: float = 10.0
var _base_move_speed: float = 0.0
var _base_attack_interval: float = 1.0
## 部署时各武器槽基础伤害，与相位法则伤害倍率相乘（多槽与 attack_damage 主行一致）
var _base_weapon_damages: Array = []
# 性能优化：缓存 HP 比率，避免每帧更新 UI
var _cached_hp_ratio: float = -1.0
# 性能优化：目标查找计时器，减少频繁查找
var _target_find_timer: float = 0.0
const TARGET_FIND_INTERVAL: float = 0.3  # 每300ms重新查找一次目标
# 性能优化：缓存动画状态，避免重复设置
var _current_walk_anim_state: bool = false  # 当前是否在播放行走动画
var _using_enemy_archetype_visual: bool = false
var _visual_archetype_id: String = ""
## 部署虚影：可被敌方攻击、不移动、不还击；计时结束后实体化
var is_deploy_ghost: bool = false
var _ghost_materialize_time_left: float = 0.0
var _ghost_total_time: float = 0.0  # 记录总部署时间，用于计算进度
## 预览模式：显示装配配置，半透明，不参与战斗
var is_preview_mode: bool = false
var _preview_time_left: float = 3.0  # 预览显示时间（秒）- 缩短为3秒避免引用问题

## UI引用
@onready var _deploy_bar: Node2D = get_node_or_null("DeployProgressBar")

# 性能优化：调试日志文件句柄缓存
var _last_flush_time: int = 0
# 性能优化：缓存卡牌能力查询，避免每帧字符串hash
var _has_regen_frame: bool = false
var _has_abrams_mk2: bool = false
var _has_storm_rider: bool = false
var _has_repair_fortress: bool = false
var _has_titan_mk2: bool = false
var _has_bulwark: bool = false
var _rank_name: String = ""
var _mod_color: Color = Color(0.5, 0.8, 1, 0.45)
## 卡牌格子战术
var _presentation_card_grid: bool = false
var _hit_stun_left: float = 0.0
var _card_tween: Tween = null
## 卡牌能力冷却 CD（本地 float，避免每帧 meta 字典读写）
var _medic_aura_cd: float = 0.0
var _storm_rider_cd: float = 0.0
var _repair_fortress_cd: float = 0.0
## 跨实例共享的资源缓存，避免运行时重复 load()
var _res_cache: Dictionary = {}

#region agent log
func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open("debug-1776fa.log", FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "1776fa",
		"runId": "law_bullet_debug_v1",
		"hypothesisId": hypothesis_id,
		"location": "construct_unit.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

func _ready() -> void:
	# 战斗逻辑跟随暂停状态
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if SignalBus:
		SignalBus.unit_move_command.connect(_on_unit_move_command)
		if SignalBus.has_signal("phase_law_runtime_changed"):
			SignalBus.phase_law_runtime_changed.connect(_on_phase_law_runtime_changed)
	# 应用相位法则的被动加成（如装甲增益）
	_apply_phase_law_passives()

func setup(p_is_player: bool, p_stats: UnitStats, forced_enemy_visual_archetype_id: String = "") -> void:
	is_player = p_is_player
	stats = p_stats
	_using_enemy_archetype_visual = false
	if forced_enemy_visual_archetype_id.is_empty():
		_visual_archetype_id = ""
	else:
		_visual_archetype_id = forced_enemy_visual_archetype_id
	hp = stats.max_hp
	_base_max_hp = stats.max_hp
	_base_attack_damage = stats.attack_damage
	_base_move_speed = stats.move_speed
	_base_attack_interval = stats.attack_interval
	_base_stats_ready = true
	velocity = Vector2.ZERO
	_weapon_cfgs.clear()
	if stats != null and stats.weapons.size() > 0:
		for w in stats.weapons:
			var cfg: Dictionary = w.duplicate()
			if not cfg.has("timer"):
				cfg["timer"] = 0.0
			_weapon_cfgs.append(cfg)
	_base_weapon_damages.clear()
	for w in stats.weapons:
		var d0 := 0.0
		if w is Dictionary:
			d0 = float((w as Dictionary).get("damage", 0.0))
		_base_weapon_damages.append(d0)
	remove_from_group("player_units")
	remove_from_group("enemy_units")
	if is_player:
		add_to_group("player_units")
		_field_stance_attack = true
	else:
		add_to_group("enemy_units")
	$CollisionShape2D.disabled = false
	_update_shape()
	_update_visual()
	_maybe_apply_card_grid_presentation()
	_update_hp_bar()
	_update_rank_and_aura_visual()

	# 性能优化：插入到空间分区网格
	_register_to_spatial_grid()

	# MEDIC 治疗光环由 _physics_process 内 _medic_aura_cd + apply_medic_heal_aura_tick 驱动（避免每帧 meta）
	if stats != null and stats.platform_type == GC.PlatformType.MEDIC:
		_medic_aura_cd = randf_range(0.0, 0.75)

	# 性能优化：注册其他光环到 AuraManager（setup 可能发生在尚未入树前）
	var aura_mgr: Node = _resolve_autoload(&"AuraManager")
	if aura_mgr:
		match stats.platform_type:
			GC.PlatformType.RADAR:
				aura_mgr.register_aura(self, aura_mgr.AuraType.RADAR_RANGE)
			GC.PlatformType.SCOUT, GC.PlatformType.STEALTH:
				aura_mgr.register_aura(self, aura_mgr.AuraType.SCOUT_CRIT)
			GC.PlatformType.FORTRESS:
				aura_mgr.register_aura(self, aura_mgr.AuraType.FORTRESS_DEF)

	# 性能优化：初始化卡牌能力缓存（setup时一次性查询）
	_has_regen_frame = CardAbilityManager.has_platform_card(stats.platform_card_id, "regen_frame")
	_has_abrams_mk2 = CardAbilityManager.has_platform_card(stats.platform_card_id, "abrams_mk2")
	_has_storm_rider = CardAbilityManager.has_platform_card(stats.platform_card_id, "storm_rider")
	_has_repair_fortress = CardAbilityManager.has_platform_card(stats.platform_card_id, "drop_repair_fortress")
	_has_titan_mk2 = CardAbilityManager.has_platform_card(stats.platform_card_id, "titan_mk2")
	_has_bulwark = CardAbilityManager.has_platform_card(stats.platform_card_id, "bulwark")

func setup_with_enemy_visual(p_is_player: bool, p_stats: UnitStats, p_visual_archetype_id: String) -> void:
	# 必须在 setup 内第一次 _update_visual 之前就带上缴获外观 id，否则会短暂套用 unit_sprites 我方机甲图
	setup(p_is_player, p_stats, p_visual_archetype_id)

## 设置为预览模式（用于显示装配的平台配置）
func setup_as_preview(p_is_player: bool, p_stats: UnitStats, p_card_name: String = "未知平台") -> void:
	is_preview_mode = true
	setup(p_is_player, p_stats)
	# 设置为半透明显示
	modulate = Color(1, 1, 1, 0.3)  # 30%不透明度
	# 禁用碰撞
	if $CollisionShape2D:
		$CollisionShape2D.disabled = true
	# 禁用血条显示
	if has_node("HpBar"):
		get_node("HpBar").visible = false
	print("[ConstructUnit] 设置为预览模式: %s" % p_card_name)

func start_as_deploy_ghost(materialize_after_sec: float) -> void:
	is_deploy_ghost = true
	_ghost_materialize_time_left = maxf(0.05, materialize_after_sec)
	_ghost_total_time = _ghost_materialize_time_left  # 记录总时间
	modulate = Color(1.0, 1.0, 1.0, 0.42)
	if _presentation_card_grid and is_player:
		var hb_hide := get_node_or_null("HpBar") as CanvasItem
		if hb_hide != null:
			hb_hide.visible = false

	# 显示并重置进度条（格子战术只显示卡图，不显示部署条）
	if _deploy_bar and not (GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle()):
		_deploy_bar.set_visible(true)
		_deploy_bar.set_progress(0.0)

func _materialize_deploy_ghost() -> void:
	is_deploy_ghost = false
	_ghost_materialize_time_left = 0.0
	modulate = Color.WHITE
	_field_stance_attack = not _should_card_grid_defend_stance()
	_move_target = Vector2.INF
	hp = stats.max_hp
	if _presentation_card_grid and is_player:
		_configure_card_grid_player_hp_bar(get_node_or_null("Sprite") as Sprite2D)
		_cached_hp_ratio = -1.0
		_update_hp_bar()
	# 卡牌特殊能力：部署后初始化（超频、泰坦计时、僚机等）
	CardAbilityManager.on_unit_materialized(self)
	_register_to_spatial_grid()

	# 隐藏进度条
	if _deploy_bar:
		_deploy_bar.set_visible(false)


func _should_card_grid_defend_stance() -> bool:
	return GameManager != null and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle()


func force_materialize_if_deploy_ghost() -> void:
	if is_deploy_ghost:
		_ghost_materialize_time_left = 0.0
		_materialize_deploy_ghost()


func apply_card_grid_combat_started() -> void:
	if not is_player:
		return
	if GameManager and GameManager.is_card_grid_battle():
		set_field_stance_defend()
		_enforce_card_grid_lane_alignment()


func _maybe_apply_card_grid_presentation() -> void:
	if stats == null:
		return
	if GameManager == null or not GameManager.is_card_grid_battle():
		return
	if not is_player:
		return
	_presentation_card_grid = true
	var bm: Node = _resolve_autoload(&"BlueprintManager")
	var rank_id: String = "corporal"
	var power_score: float = 120.0
	if bm and bm.has_method("get_rank_info") and not stats.platform_card_id.is_empty():
		var ri: Dictionary = bm.get_rank_info(stats.platform_card_id)
		rank_id = String(ri.get("rank_id", rank_id))
		power_score = float(ri.get("power_score", power_score))
	var card_res: CardResource = DefaultCards.get_card_by_id(stats.platform_card_id)
	var icon_path: String = UiAssetLoader.card_icon_path_for(card_res)
	var tex: Texture2D = UiAssetLoader.load_tex(icon_path)
	var spr: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	var walk_sprite: AnimatedSprite2D = get_node_or_null("WalkSprite") as AnimatedSprite2D
	var poly: Polygon2D = get_node_or_null("Shape") as Polygon2D
	if spr != null and tex != null:
		var rl: int = CardGridUnitVisuals.rank_level_from_id(rank_id)
		CardGridUnitVisuals.apply_battle_unit_presentation(self, spr, card_res, tex, true, rl)
	if walk_sprite != null:
		walk_sprite.visible = false
	if poly != null:
		poly.visible = false
	_configure_card_grid_player_hp_bar(spr)
	var aura_ring := get_node_or_null("AuraRing") as CanvasItem
	var rank_badge := get_node_or_null("RankBadge") as CanvasItem
	if aura_ring != null:
		aura_ring.visible = false
	if rank_badge != null:
		rank_badge.visible = false
	_update_hp_bar()


func _configure_card_grid_player_hp_bar(spr: Sprite2D) -> void:
	var hb := get_node_or_null("HpBar")
	if hb == null:
		return
	if hb is CanvasItem:
		(hb as CanvasItem).visible = true
	var half_h: float = 0.0
	if spr != null and spr.texture != null:
		half_h = float(spr.texture.get_height()) * absf(spr.scale.y) * 0.5
	hb.position = Vector2(0.0, half_h + 8.0)
	if hb.has_method("set_side"):
		hb.set_side(true)
	if hb.has_method("set_folded"):
		hb.set_folded(false)


## 格子战术敌方（含相位师装备产兵）：卡面化并与波次格子敌一致固守
func apply_card_grid_enemy_presentation() -> void:
	if stats == null:
		return
	if GameManager == null or not GameManager.has_method("is_card_grid_battle") or not GameManager.is_card_grid_battle():
		return
	if is_player:
		return
	_presentation_card_grid = true
	set_field_stance_defend()
	_move_target = Vector2.INF
	var spr: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	var walk_sprite: AnimatedSprite2D = get_node_or_null("WalkSprite") as AnimatedSprite2D
	var poly: Polygon2D = get_node_or_null("Shape") as Polygon2D
	var card_res: CardResource = DefaultCards.get_card_by_id(stats.platform_card_id)
	if card_res == null and not stats.platform_card_id.is_empty():
		card_res = EnemyPhaseEquipment.get_equipment_blueprint(stats.platform_card_id)
	var ad: float = 0.0
	var ai: float = 0.35
	if stats.weapons.size() > 0 and stats.weapons[0] is Dictionary:
		var w0: Dictionary = stats.weapons[0] as Dictionary
		ad = float(w0.get("damage", 0.0))
		ai = float(w0.get("fire_interval", w0.get("interval", 0.35)))
	var pscore: float = maxf(50.0, stats.max_hp * 0.28 + (ad / maxf(ai, 0.05)) * 2.2)
	var rank_id: String = RankRules.get_rank_by_power("corporal", pscore)
	var rank_level: int = CardGridUnitVisuals.rank_level_from_id(rank_id)
	var sprite_ok: bool = false
	var arch_for_icon: String = EnemyArchetypes.get_visual_archetype_id_for_card(stats.platform_card_id)
	if arch_for_icon.is_empty():
		arch_for_icon = stats.platform_card_id
	var cfg: Dictionary = EnemyArchetypes.get_config(arch_for_icon)
	if card_res == null:
		card_res = CardGridUnitVisuals.resolve_card_for_archetype(arch_for_icon)
	if card_res == null:
		card_res = CardGridUnitVisuals.synthetic_card_for_archetype(arch_for_icon, cfg)
	var tex: Texture2D = CardGridUnitVisuals.resolve_battle_icon_texture(card_res, arch_for_icon, cfg)
	if spr != null and tex != null:
		sprite_ok = CardGridUnitVisuals.apply_battle_unit_presentation(
			self, spr, card_res, tex, false, rank_level
		)
	if walk_sprite != null:
		walk_sprite.visible = false
	if poly != null:
		if not sprite_ok:
			poly.visible = true
		else:
			poly.visible = false
	var hb := get_node_or_null("HpBar") as CanvasItem
	if hb != null:
		hb.visible = false
	var aura_ring := get_node_or_null("AuraRing") as CanvasItem
	var rank_badge := get_node_or_null("RankBadge") as CanvasItem
	if aura_ring != null:
		aura_ring.visible = false
	if rank_badge != null:
		rank_badge.visible = false
	velocity = Vector2.ZERO


func _acquisition_range() -> float:
	if stats == null:
		return 120.0
	var combat_started: bool = (
		GameManager
		and GameManager.is_card_grid_battle()
		and BattleManager != null
		and BattleManager.has_method("is_card_grid_combat_started")
		and BattleManager.is_card_grid_combat_started()
	)
	if not is_player and GameManager and GameManager.is_card_grid_battle():
		return CombatTargeting.card_grid_enemy_acquisition_range(stats.attack_range, combat_started)
	var r: float = stats.attack_range
	if combat_started:
		r *= 2.6
	return r


func _play_card_attack_nudge() -> void:
	if not _presentation_card_grid:
		return
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	_card_tween = create_tween()
	var dir: float = 1.0 if is_player else -1.0
	var start_x := position.x
	_card_tween.tween_property(self, "position:x", start_x + dir * 22.0, 0.07)
	_card_tween.tween_property(self, "position:x", start_x, 0.09)


func _play_card_hit_recoil() -> void:
	if not _presentation_card_grid:
		return
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	# 格子战场卡面以竖直为姿态基准；若用当前 rotation 作回弹目标，连续受击会在「未回正」上叠角度，最后横倒
	const RECOIL_MAX_RAD: float = 0.22
	var rest_r: float = 0.0
	rotation = rest_r
	_card_tween = create_tween()
	var peak_r: float = rest_r - RECOIL_MAX_RAD
	_card_tween.tween_property(self, "rotation", peak_r, 0.06)
	_card_tween.tween_property(self, "rotation", rest_r, 0.12)

## 单武器：法则改写 `stats` 后，把唯一槽位 `_weapon_cfgs[0]` 与 `stats.weapons[0]` 与主行对齐
func _sync_single_weapon_cfg_from_stats() -> void:
	if stats == null or _weapon_cfgs.size() != 1:
		return
	var cfg: Dictionary = _weapon_cfgs[0] as Dictionary
	cfg["damage"] = stats.attack_damage
	cfg["interval"] = stats.attack_interval
	cfg["range"] = stats.attack_range
	_weapon_cfgs[0] = cfg
	if stats.weapons.size() == 1:
		var sw: Dictionary = stats.weapons[0] as Dictionary
		sw["damage"] = stats.attack_damage
		sw["interval"] = stats.attack_interval
		sw["range"] = stats.attack_range
		stats.weapons[0] = sw


func _sync_weapon_cfgs_from_stats() -> void:
	if stats == null:
		return
	if _weapon_cfgs.size() == 1 and stats.weapons.size() == 1:
		_sync_single_weapon_cfg_from_stats()
		return
	for i in range(mini(_weapon_cfgs.size(), stats.weapons.size())):
		var cfg: Dictionary = _weapon_cfgs[i] as Dictionary
		var sw: Dictionary = stats.weapons[i] as Dictionary
		if sw.has("damage"):
			cfg["damage"] = float(sw["damage"])
		_weapon_cfgs[i] = cfg


func _apply_phase_law_passives() -> void:
	if stats == null:
		return
	if not _base_stats_ready:
		_base_max_hp = stats.max_hp
		_base_attack_damage = stats.attack_damage
		_base_move_speed = stats.move_speed
		_base_attack_interval = stats.attack_interval
		_base_stats_ready = true
	if not PhaseLawManager or not PhaseLawManager.has_method("get_passive_runtime_tags_for_side"):
		return
	var tags: Array = PhaseLawManager.get_passive_runtime_tags_for_side(true)
	var hp_mult: float = 1.0
	var dmg_mult: float = 1.0
	var move_mult: float = 1.0
	var atkspd_mult: float = 1.0
	_law_regen_per_sec = 0.0
	for t in tags:
		if not t is Dictionary:
			continue
		var effect: String = String(t.get("effect", ""))
		var v: float = float(t.get("value", 0.0))
		match effect:
			"armor_buff", "aegis_link", "fortify_protocol", "resonant_plate":
				hp_mult *= 1.0 + max(0.0, v)
			"afterburn", "entropy_lens":
				dmg_mult *= 1.0 + max(0.0, v)
			"arc_beacon":
				atkspd_mult *= 1.0 + max(0.0, v)
			"surge_drive", "phase_cloak":
				move_mult *= 1.0 + max(0.0, v)
			"regen_out_of_combat":
				_law_regen_per_sec += max(0.0, v)
			_:
				pass

	var old_max_hp: float = maxf(1.0, stats.max_hp)
	var hp_ratio: float = clampf(hp / old_max_hp, 0.0, 1.0)
	stats.max_hp = _base_max_hp * hp_mult
	stats.attack_damage = _base_attack_damage * dmg_mult
	if _base_weapon_damages.size() == stats.weapons.size() and not stats.weapons.is_empty():
		for i in range(stats.weapons.size()):
			var w: Dictionary = stats.weapons[i] as Dictionary
			w["damage"] = maxf(0.0, float(_base_weapon_damages[i]) * dmg_mult)
			stats.weapons[i] = w
	elif stats.weapons.size() == 1:
		var w1: Dictionary = stats.weapons[0] as Dictionary
		w1["damage"] = stats.attack_damage
		stats.weapons[0] = w1
	stats.move_speed = _base_move_speed * move_mult
	stats.attack_interval = max(0.1, _base_attack_interval / atkspd_mult)
	_sync_weapon_cfgs_from_stats()
	hp = maxf(1.0, stats.max_hp * hp_ratio)

func _on_phase_law_runtime_changed() -> void:
	if stats == null:
		return
	_apply_phase_law_passives()
	_update_hp_bar()

func _update_shape() -> void:
	var poly: Polygon2D = $Shape as Polygon2D
	if poly == null:
		return
	var pts: PackedVector2Array = _shape_points()
	poly.polygon = pts
	# 我方蓝色，敌方红色（用于相位师等复用构装体场景的敌方单位）
	poly.color = Color(0.2, 0.4, 0.9) if is_player else Color(0.85, 0.2, 0.2)

## 缓存 load()：同一资源路径只加载一次，后续从内存字典取
func _cached_load(path: String, type_hint: int = -1) -> Resource:
	if path.is_empty():
		return null
	if _res_cache.has(path):
		var cached = _res_cache[path]
		if is_instance_valid(cached):
			return cached
		_res_cache.erase(path)
	if not ResourceLoader.exists(path):
		return null
	var res: Resource
	if type_hint >= 0:
		# Godot 4.5: ResourceLoader.load 最多 3 个参数
		res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	else:
		res = load(path)
	if res != null:
		_res_cache[path] = res
	return res


## 全装型等静态整图：按敌方原型 visual_scale 与典型帧边长换算，并套用与敌方单位相同的最大边长上限
const _STATIC_TEX_REF_FRAME_PX: float = 256.0

func _scale_static_sprite_to_enemy_archetype(sprite: Sprite2D, archetype_id: String) -> void:
	if sprite == null or sprite.texture == null:
		return
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	var vs: float = EnemyArchetypes.get_visual_scale_for_archetype(archetype_id, cfg)
	var tex: Texture2D = sprite.texture
	var tm: float = maxf(float(tex.get_width()), float(tex.get_height()))
	var s: float = (vs * _STATIC_TEX_REF_FRAME_PX) / maxf(1.0, tm)
	var rendered: float = tm * s
	if rendered > MAX_ENEMY_VISUAL_EXTENT_PX:
		s *= MAX_ENEMY_VISUAL_EXTENT_PX / maxf(1.0, rendered)
	sprite.scale = Vector2(s, s)

func _update_visual() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite")
	var walk_sprite: AnimatedSprite2D = get_node_or_null("WalkSprite")
	var poly: Polygon2D = get_node_or_null("Shape")
	# 我方战斗单位视觉同形：先尝试显式 archetype（由 BattleSpawnSystem 反查 drops 表后通过
	# setup_with_enemy_visual 注入），再走 platform_type 镜像兜底，最后才几何占位。
	# 老的 unit_sprites/<platform_id>.frames.tres 路径已废弃，全部下沉到 EnemyArchetypes 数据驱动。
	_using_enemy_archetype_visual = _apply_enemy_archetype_visual(sprite, walk_sprite, poly)
	if _using_enemy_archetype_visual:
		return

	var is_omega := stats != null and stats.platform_type == GC.PlatformType.OMEGA_PLATFORM
	if is_player:
		# 我方：全装型与敌方「机甲步兵」同源精灵（enemy_future_mech），仅朝右；缺镜像时再回退静态 omega_platform.png
		if is_omega:
			if _try_apply_player_mirrored_enemy_visual(sprite, walk_sprite, poly):
				_using_enemy_archetype_visual = true
				return
			_apply_omega_static_player_visual(sprite, walk_sprite, poly)
			return
		if _try_apply_player_mirrored_enemy_visual(sprite, walk_sprite, poly):
			_using_enemy_archetype_visual = true
			return
		_apply_geometry_fallback_visual(sprite, walk_sprite, poly)
		return

	# 敌方 ConstructUnit（如相位师装备兵）：缴获外观未命中时直接走几何占位，
	# 不再回退到玩家专属的 unit_sprites。
	_apply_geometry_fallback_visual(sprite, walk_sprite, poly)


func _apply_omega_static_player_visual(sprite: Sprite2D, walk_sprite: AnimatedSprite2D, poly: Polygon2D) -> void:
	if walk_sprite != null:
		walk_sprite.sprite_frames = null
		walk_sprite.visible = false
	if sprite != null:
		sprite.texture = OmegaTex
		sprite.visible = true
		_scale_static_sprite_to_enemy_archetype(sprite, String(PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM.get(GC.PlatformType.OMEGA_PLATFORM, "enemy_future_mech")))
		_apply_enemy_visual_facing(sprite, walk_sprite)
	if poly != null:
		poly.visible = false


func _apply_geometry_fallback_visual(sprite: Sprite2D, walk_sprite: AnimatedSprite2D, poly: Polygon2D) -> void:
	if walk_sprite != null:
		walk_sprite.scale = Vector2(0.2, 0.2)
		walk_sprite.visible = false
	if sprite != null:
		sprite.visible = false
	if poly != null:
		poly.visible = true

func _update_rank_and_aura_visual() -> void:
	if _presentation_card_grid:
		return
	var aura_ring: Line2D = get_node_or_null("AuraRing")
	var rank_badge: Label = get_node_or_null("RankBadge")
	if aura_ring == null or rank_badge == null:
		return
	if stats == null or stats.platform_card_id.is_empty() or BlueprintManager == null:
		aura_ring.visible = false
		rank_badge.visible = false
		return
	var mod_count: int = BlueprintManager.get_modification_count(stats.platform_card_id) if BlueprintManager.has_method("get_modification_count") else 0
	_mod_color = _get_mod_aura_color(mod_count)
	aura_ring.default_color = _mod_color
	aura_ring.width = 2.0 + float(mod_count)
	# 近似圆环，避免新贴图资产依赖
	var radius: float = 22.0 + float(mod_count) * 1.5
	var pts: PackedVector2Array = PackedVector2Array()
	var seg: int = 28
	for i in range(seg + 1):
		var a: float = TAU * float(i) / float(seg)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	aura_ring.points = pts
	aura_ring.visible = mod_count > 0
	var rank_info: Dictionary = BlueprintManager.get_rank_info(stats.platform_card_id) if BlueprintManager.has_method("get_rank_info") else {}
	_rank_name = String(rank_info.get("rank_name", ""))
	if _rank_name.is_empty():
		rank_badge.visible = false
	else:
		rank_badge.text = _rank_name
		rank_badge.visible = true

func _get_mod_aura_color(mod_count: int) -> Color:
	match mod_count:
		1: return Color(0.45, 0.85, 1.0, 0.55) # A光环
		2: return Color(0.55, 1.0, 0.55, 0.58) # B光环
		3: return Color(1.0, 0.72, 0.45, 0.62) # C光环
		_: return Color(0.5, 0.8, 1.0, 0.45)

func _apply_enemy_archetype_visual(sprite: Sprite2D, walk_sprite: AnimatedSprite2D, poly: Polygon2D) -> bool:
	if _visual_archetype_id.is_empty():
		return false
	var cfg: Dictionary = EnemyArchetypes.get_config(_visual_archetype_id)
	if cfg.is_empty():
		return false
	return _apply_enemy_card_texture_for_archetype_id(sprite, walk_sprite, poly, _visual_archetype_id, cfg)


func _apply_enemy_card_texture_for_archetype_id(sprite: Sprite2D, walk_sprite: AnimatedSprite2D, poly: Polygon2D, archetype_id: String, cfg: Dictionary) -> bool:
	var icon_path: String = EnemyArchetypes.resolve_card_icon_texture_path(archetype_id, cfg, archetype_id)
	if icon_path.is_empty() or _enemy_visual_resource_path_suspicious(icon_path):
		return false
	var tex: Texture2D = _cached_load(icon_path) as Texture2D
	if tex == null:
		return false
	if tex.get_width() > MAX_ENEMY_FRAME_TEX_DIM or tex.get_height() > MAX_ENEMY_FRAME_TEX_DIM:
		return false
	var scale_v: float = EnemyArchetypes.get_visual_scale_for_archetype(archetype_id, cfg)
	if walk_sprite != null:
		walk_sprite.sprite_frames = null
		walk_sprite.visible = false
	if sprite != null:
		sprite.texture = tex
		sprite.visible = true
		sprite.scale = Vector2(scale_v, scale_v)
		if poly != null:
			poly.visible = false
		_apply_enemy_visual_facing(sprite, walk_sprite)
		_clamp_enemy_archetype_sprite_extent(sprite)
		return true
	return false


func _try_apply_player_mirrored_enemy_visual(sprite: Sprite2D, walk_sprite: AnimatedSprite2D, poly: Polygon2D) -> bool:
	if stats == null:
		return false
	var archetype_id: String = String(PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM.get(int(stats.platform_type), ""))
	if archetype_id.is_empty():
		return false
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	if cfg.is_empty():
		return false
	return _apply_enemy_card_texture_for_archetype_id(sprite, walk_sprite, poly, archetype_id, cfg)

func _apply_enemy_visual_facing(sprite: Sprite2D, walk_sprite: AnimatedSprite2D) -> void:
	# 敌方资源复用于我方时按阵营切换朝向：我方朝右，敌方朝左。
	var facing_right: bool = is_player
	if walk_sprite != null:
		walk_sprite.flip_h = not facing_right
	if sprite != null:
		var sx: float = absf(sprite.scale.x)
		sprite.scale.x = sx if facing_right else -sx


func _enemy_visual_resource_path_suspicious(path: String) -> bool:
	var p := path.to_lower().replace("\\", "/")
	return "background" in p or "/bg_" in p or "bg_level" in p or "/backgrounds/" in p


func _clamp_enemy_archetype_walk_extent(anim: AnimatedSprite2D) -> void:
	if anim == null or not anim.visible or anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation(String(anim.animation)):
		return
	if anim.sprite_frames.get_frame_count(String(anim.animation)) <= 0:
		return
	var ft: Texture2D = anim.sprite_frames.get_frame_texture(String(anim.animation), anim.frame)
	if ft == null:
		return
	var w := float(ft.get_width()) * absf(anim.scale.x)
	var h := float(ft.get_height()) * absf(anim.scale.y)
	var m := maxf(w, h)
	if m <= 1.0 or m <= MAX_ENEMY_VISUAL_EXTENT_PX:
		return
	anim.scale *= MAX_ENEMY_VISUAL_EXTENT_PX / m


func _clamp_enemy_archetype_sprite_extent(spr: Sprite2D) -> void:
	if spr == null or not spr.visible or spr.texture == null:
		return
	var w := float(spr.texture.get_width()) * absf(spr.scale.x)
	var h := float(spr.texture.get_height()) * absf(spr.scale.y)
	var m := maxf(w, h)
	if m <= 1.0 or m <= MAX_ENEMY_VISUAL_EXTENT_PX:
		return
	spr.scale *= MAX_ENEMY_VISUAL_EXTENT_PX / m

func _update_animation() -> void:
	if _presentation_card_grid:
		return
	if _using_enemy_archetype_visual:
		return
	var walk_sprite: AnimatedSprite2D = get_node_or_null("WalkSprite")
	if walk_sprite == null or walk_sprite.sprite_frames == null:
		return
	if not walk_sprite.sprite_frames.has_animation("walk"):
		return

	var moving := absf(velocity.x) > 1.0
	# 性能优化：只在动画状态变化时更新
	if moving != _current_walk_anim_state:
		_current_walk_anim_state = moving
		if moving:
			if not walk_sprite.is_playing():
				walk_sprite.play("walk")
		else:
			walk_sprite.stop()

func _shape_points() -> PackedVector2Array:
	var s = 24.0
	match stats.platform_type:
		GC.PlatformType.HOUND:
			return PackedVector2Array([Vector2(0, -s), Vector2(s*0.8, s), Vector2(-s*0.8, s)])
		GC.PlatformType.GUARD:
			return PackedVector2Array([Vector2(-s,s), Vector2(s,s), Vector2(s,-s), Vector2(-s,-s)])
		GC.PlatformType.TITAN:
			return PackedVector2Array([Vector2(-s*1.2,s), Vector2(s*1.2,s), Vector2(s*1.2,-s), Vector2(-s*1.2,-s)])
		GC.PlatformType.OMEGA_PLATFORM:
			return PackedVector2Array([Vector2(-s*1.4,s), Vector2(s*1.4,s), Vector2(s*1.4,-s), Vector2(-s*1.4,-s)])
		GC.PlatformType.FORTRESS:
			var arr: PackedVector2Array = []
			for i in range(8):
				var a = TAU * i / 8.0
				arr.append(Vector2(cos(a)*s, sin(a)*s))
			return arr
		GC.PlatformType.RADAR:
			# 十字形雷达
			var arm = s * 0.4
			return PackedVector2Array([
				Vector2(0, -s), Vector2(arm, -arm), Vector2(s, 0),
				Vector2(arm, arm), Vector2(0, s), Vector2(-arm, arm),
				Vector2(-s, 0), Vector2(-arm, -arm)
			])
		GC.PlatformType.SCOUT:
			return PackedVector2Array([Vector2(0, -s), Vector2(s*0.8, s), Vector2(-s*0.8, s)])
		GC.PlatformType.RAIDER:
			return PackedVector2Array([Vector2(-s,s), Vector2(s,s), Vector2(s,-s), Vector2(-s,-s)])
		GC.PlatformType.SIEGE:
			return PackedVector2Array([Vector2(-s*1.2,s), Vector2(s*1.2,s), Vector2(s*1.2,-s), Vector2(-s*1.2,-s)])
		GC.PlatformType.CARRIER:
			return PackedVector2Array([Vector2(-s*1.1,s), Vector2(s*1.1,s), Vector2(s*1.1,-s), Vector2(-s*1.1,-s)])
		GC.PlatformType.MEDIC:
			return PackedVector2Array([Vector2(-s,s), Vector2(s,s), Vector2(s,-s), Vector2(-s,-s)])
		GC.PlatformType.STEALTH:
			return PackedVector2Array([Vector2(0, -s*0.9), Vector2(s*0.7, s*0.9), Vector2(-s*0.7, s*0.9)])
	return PackedVector2Array([Vector2(-s,s), Vector2(s,s), Vector2(s,-s), Vector2(-s,-s)])

func _physics_process(delta: float) -> void:
	# 安全检查：确保节点在场景树中
	if not is_inside_tree():
		return
	# 预览模式：安全检查和自动清理
	if is_preview_mode:
		_preview_time_left -= delta
		# 渐渐消失效果
		modulate = Color(1, 1, 1, 0.3 * maxf(0.0, _preview_time_left / 5.0))
		if _preview_time_left <= 0:
			print("[ConstructUnit] 预览时间结束，移除预览单位")
			# queue_free 在本帧末才移除节点；若已把 is_preview_mode=false，下几帧会走完整战斗 AI，可能卡死或与敌单位交互
			set_physics_process(false)
			queue_free()
			return  # 立即返回，避免执行其他逻辑
		return  # 预览期间不执行其他逻辑

	var tree := get_tree()
	var paused := tree.paused if tree else true
	if paused:
		return
	if stats == null:
		return
	if _hit_stun_left > 0.0:
		_hit_stun_left -= delta
	# 性能优化：不再每帧更新 HP 条，改为在 HP 变化时更新
	if is_deploy_ghost:
		_ghost_materialize_time_left -= delta
		velocity = Vector2.ZERO
		target = null
		move_and_slide()
		_clamp_inside_battlefield()

		# 更新部署进度条
		if _deploy_bar and _ghost_total_time > 0.0:
			var progress = 1.0 - (_ghost_materialize_time_left / _ghost_total_time)
			_deploy_bar.set_progress(progress)

		if _ghost_materialize_time_left <= 0.0:
			_materialize_deploy_ghost()
		return

	# 性能优化：减少目标查找频率
	_target_find_timer += delta
	var should_find_target := false
	if target == null or not is_instance_valid(target):
		should_find_target = true
	elif _target_find_timer >= _get_target_find_interval():
		should_find_target = true
		_target_find_timer = 0.0

	if should_find_target:
		_find_target(delta)
	# 应用持续效果（回血）
	_apply_continuous_effects(delta)
	# 格子战术：单位固守当前格，不位移
	velocity = Vector2.ZERO
	_move_target = Vector2.INF
	if _weapon_cfgs.size() > 0:
		_process_multi_weapons(delta)
	else:
		if _hit_stun_left <= 0.0:
			attack_timer += delta
			if target != null and attack_timer >= stats.attack_interval:
				var d_fire: float = global_position.distance_to(target.global_position)
				if d_fire <= _effective_fire_range():
					attack_timer = 0.0
					_do_attack()
	_update_animation()
	move_and_slide()
	_clamp_inside_battlefield()
	if not is_player and GameManager != null and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle():
		velocity = Vector2.ZERO
	# 性能优化：静止单位跳过空间网格更新
	if velocity != Vector2.ZERO:
		_update_in_spatial_grid()
	if _law_regen_per_sec > 0.0 and target == null and hp < stats.max_hp:
		hp = minf(stats.max_hp, hp + _law_regen_per_sec * delta)
		_update_hp_bar()  # 回血时更新 HP 条
	# 卡牌特殊能力：平台每帧效果（使用缓存的布尔值，避免每帧字符串hash）
	if _has_regen_frame or _has_abrams_mk2 or _has_storm_rider or _has_repair_fortress:
		if target == null:
			if _has_regen_frame:
				if CardAbilityManager.apply_regen_frame_regen(self, delta) > 0.0:
					_update_hp_bar()
			if _has_abrams_mk2:
				if CardAbilityManager.apply_abrams_mk2_regen(self, delta) > 0.0:
					_update_hp_bar()
		if _has_storm_rider:
			CardAbilityManager.apply_storm_rider_speed(self, delta)
		if _has_repair_fortress:
			CardAbilityManager.apply_repair_fortress_heal(self, delta)

	# ── 平台类型光环系统（仅 MEDIC，其余由 AuraManager Timer 驱动） ──
	if stats != null and not is_deploy_ghost and not is_preview_mode:
		if stats.platform_type == GC.PlatformType.MEDIC:
			_medic_aura_cd -= delta
			if _medic_aura_cd <= 0.0:
				_medic_aura_cd = 3.0
				CardAbilityManager.apply_medic_heal_aura_tick(self)

func _apply_continuous_effects(delta: float) -> void:
	if stats == null:
		return
	
	# 应用回血效果（纳米自愈词条）
	if stats.hp_regen > 0.0:
		var regen_mult: float = AffixCombatHandler.get_hp_regen_multiplier(self, stats)
		var effective_regen: float = stats.hp_regen * regen_mult
		AffixCombatHandler.apply_hp_regen(self, stats, delta)
	
	# 应用平台HP变异防御加成
	# （在 take_damage 中处理会更合适）

func _process_multi_weapons(delta: float) -> void:
	# 预览模式和部署虚影都不会攻击
	if is_deploy_ghost or is_preview_mode:
		return
	if _hit_stun_left > 0.0:
		return
	for i in range(_weapon_cfgs.size()):
		var w = _weapon_cfgs[i]
		var timer: float = float(w.get("timer", 0.0))
		timer += delta
		w["timer"] = timer
		if target == null or not is_instance_valid(target):
			continue
		var d = global_position.distance_to(target.global_position)
		var interval: float = float(w.get("interval", stats.attack_interval))
		var eff_rng: float = _effective_fire_range()
		if d <= eff_rng and timer >= interval:
			w["timer"] = 0.0
			var dmg: float = float(w.get("damage", stats.attack_damage))
			var wt: int = int(w.get("weapon_type", -1))
			_do_attack_with_damage(dmg, wt)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	# 性能优化和错误修复：确保节点在场景树中才处理输入
	if not is_inside_tree():
		return
	# 预览模式不能被点击选中
	if is_preview_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if SignalBus:
			SignalBus.unit_selected.emit(self, is_player, Vector2.ZERO)

func _on_unit_move_command(unit: Node, target_pos: Vector2) -> void:
	# 预览模式不能接受移动指令
	if unit != self or stats == null or is_deploy_ghost or is_preview_mode:
		return
	if GameManager and GameManager.is_card_grid_battle() and is_player and int(get_meta("card_grid_slot", -1)) >= 0:
		target_pos.y = global_position.y
	_move_target = target_pos

## 战场姿态：进攻（默认），单位会向敌侧推进并在射程内交战。
func set_field_stance_attack() -> void:
	if is_deploy_ghost or is_preview_mode:
		return
	# 格子战术敌方机甲：保持卡位固守，不按进攻姿态推进
	if not is_player and _presentation_card_grid:
		return
	if not is_player:
		return
	_field_stance_attack = true

## 战场姿态：防守，无其它指令时停留在当前位置，仍可射击；可用点击地面微调站位。
func set_field_stance_defend() -> void:
	if is_deploy_ghost or is_preview_mode:
		return
	# 格子战术敌方 Construct（如相位师产兵）：与 EnemyUnit 一致固守当前格
	if not is_player and not _presentation_card_grid:
		return
	_field_stance_attack = false
	_move_target = Vector2.INF

func is_field_stance_attack() -> bool:
	return _field_stance_attack

func _battlefield_y_clamp_range() -> Vector2:
	if GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle():
		if BattleManager and BattleManager.battlefield and BattleManager.battlefield.has_method("get_deploy_y_bounds"):
			return BattleManager.battlefield.get_deploy_y_bounds()
	return Vector2(BATTLE_MIN_Y, BATTLE_MAX_Y)


func _clamp_inside_battlefield() -> void:
	var gx := global_position
	var max_x: float = PLAYER_MAX_ADVANCE_X if is_player else BATTLE_MAX_X
	var clamped_x := clampf(gx.x, BATTLE_MIN_X, max_x)
	var yb: Vector2 = _battlefield_y_clamp_range()
	var clamped_y := clampf(gx.y, yb.x, yb.y)
	if clamped_x != gx.x:
		global_position.x = clamped_x
	if clamped_y != gx.y:
		global_position.y = clamped_y
	_enforce_card_grid_lane_alignment()


func _enforce_card_grid_lane_alignment() -> void:
	if GameManager == null or not GameManager.is_card_grid_battle():
		return
	var bf: Node = BattleManager.battlefield if BattleManager else null
	if bf == null:
		return
	if is_player:
		var si: int = int(get_meta("card_grid_slot", -1))
		if si < 0 or not bf.has_method("get_card_grid_player_slot_global"):
			return
		var lane_y: float = bf.get_card_grid_player_slot_global(si).y
		if absf(global_position.y - lane_y) > 0.01:
			global_position.y = lane_y
		return
	if not _presentation_card_grid:
		return
	var esi: int = int(get_meta("card_grid_enemy_slot", -1))
	if esi < 0 or not bf.has_method("get_card_grid_enemy_slot_global"):
		return
	var anchor: Vector2 = bf.get_card_grid_enemy_slot_global(esi)
	if global_position.distance_squared_to(anchor) > 0.25:
		global_position = anchor

func _get_target_find_interval() -> float:
	var n: int = 0
	if BattleManager and BattleManager.has_method("get_enemy_unit_count"):
		n = BattleManager.get_enemy_unit_count()
	if n > 55:
		return 0.55
	if n > 35:
		return 0.42
	return TARGET_FIND_INTERVAL

func _targeting_opponent_phase_field_only() -> bool:
	if is_player:
		return not CombatTargeting.has_alive_enemy_units(BattleManager)
	return not CombatTargeting.has_alive_player_units(BattleManager)


func _effective_fire_range() -> float:
	if stats == null:
		return 120.0
	var rng: float = stats.attack_range
	if (
		GameManager
		and GameManager.is_card_grid_battle()
		and BattleManager != null
		and BattleManager.has_method("is_card_grid_combat_started")
		and BattleManager.is_card_grid_combat_started()
	):
		rng *= 2.6
	if target != null and is_instance_valid(target) and CombatTargeting.is_phase_field_node(target):
		if _targeting_opponent_phase_field_only():
			return maxf(rng, _acquisition_range() * 1.5)
	return rng


func _should_retain_current_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if CombatTargeting.should_drop_phase_field_target(target, is_player, BattleManager):
		return false
	if CombatTargeting.is_phase_field_node(target):
		return _targeting_opponent_phase_field_only()
	var d: float = global_position.distance_to(target.global_position)
	return d <= _acquisition_range()


func _find_target(_delta: float) -> void:
	if _should_retain_current_target():
		return
	target = null

	# 性能优化：优先使用空间分区系统
	if BattleManager and BattleManager.spatial_grid:
		var spatial_grid = BattleManager.spatial_grid
		if spatial_grid:
			# 使用空间网格查询最近目标（O(1)复杂度）
			var nearest_target = spatial_grid.query_nearest_target(
				global_position,
				is_player,
				_acquisition_range()
			)
			if nearest_target != null:
				target = nearest_target
				return

	# 回退到传统方法（如果空间网格不可用）
	var tree = get_tree()
	if tree == null:
		return

	# 性能优化：使用提前退出和距离平方比较避免平方根计算
	var target_group: String = "enemy_units" if is_player else "player_units"
	var gr: Array = BattleManager.get_cached_nodes_in_group(target_group) if BattleManager else tree.get_nodes_in_group(target_group)
	var best_target: Node2D = null
	var acq: float = _acquisition_range()
	var best_dist_sq := acq * acq

	for n in gr:
		if not CombatTargeting.is_attackable_combat_unit(n):
			continue
		# 使用距离平方比较，避免昂贵的平方根计算
		var dist_sq := global_position.distance_squared_to(n.global_position)
		if dist_sq <= best_dist_sq:
			best_target = n as Node2D
			best_dist_sq = dist_sq
			break  # 找到第一个范围内的目标即可

	if best_target != null:
		target = best_target
		return

	# 无对方战斗单位时，攻击对方相位场（格子战可跨全场）
	if _targeting_opponent_phase_field_only():
		var phase_field: Node2D = CombatTargeting.find_opponent_phase_field(
			global_position, is_player, BattleManager, -1.0
		)
		if phase_field != null:
			target = phase_field
			return

func _do_attack() -> void:
	_do_attack_with_damage(stats.attack_damage, stats.weapon_type)

func _do_attack_with_damage(damage: float, weapon_type_override: int = -1) -> void:
	if is_deploy_ghost:
		return
	if _hit_stun_left > 0.0:
		return
	if target == null or not is_instance_valid(target):
		return
	var dist_t := global_position.distance_to(target.global_position)
	var miss := false
	var falloff: Dictionary = CombatTargeting.range_falloff(dist_t, stats.attack_range)
	if dist_t > stats.attack_range and stats.attack_range > 0.5:
		if randf() > float(falloff.get("p_hit", 1.0)):
			miss = true
			CombatFeedback.show_miss(target.global_position, target)
		else:
			damage *= float(falloff.get("damage_mult", 1.0))
	# 卡牌特殊能力：平台攻击修改
	if _has_titan_mk2:
		damage *= CardAbilityManager.get_titan_mk2_damage_multiplier(self)
	if _has_storm_rider:
		damage *= CardAbilityManager.get_storm_rider_damage_multiplier(self)
	var wt: int = weapon_type_override if weapon_type_override >= 0 else (stats.weapon_type if stats else GC.WeaponType.SMG)
	#region agent log
	_agent_log("H3_bullet_spawn", "construct_fire_attempt", {
		"unit": name,
		"target_valid": target != null and is_instance_valid(target),
		"damage": damage,
		"weapon_type": wt
	})
	#endregion
	if _presentation_card_grid:
		_play_card_attack_nudge()
	var bullet: Node2D = ObjectPoolManager.get_object("bullets")
	if bullet == null:
		# 对象池未初始化或已满，回退到直接创建
		bullet = BulletScene.instantiate()
	bullet.global_position = global_position
	# 传递射手和射手的数值信息到子弹，用于计算词条效果
	bullet.setup(target, damage, true, wt, self, stats, miss)
	# 子弹加入战场（与单位同一 SubViewport），否则会画到主场景
	var root_2d = get_parent().get_parent() if get_parent() else self
	var current_parent: Node = bullet.get_parent()
	if current_parent != root_2d:
		if current_parent != null:
			current_parent.remove_child(bullet)
		root_2d.add_child(bullet)

func _update_hp_bar() -> void:
	if _presentation_card_grid and not is_player:
		return
	var bar = get_node_or_null("HpBar")
	if bar == null or not bar.has_method("set_ratio") or stats == null:
		return
	# 性能优化：只在 HP 比率变化时更新 UI
	var current_ratio := hp / stats.max_hp if stats.max_hp > 0 else 1.0
	if absf(current_ratio - _cached_hp_ratio) < 0.01:  # 变化小于1%时不更新
		return
	_cached_hp_ratio = current_ratio
	bar.set_side(true)
	# 只显示 HP 比例（护盾单独显示或不显示）
	bar.set_ratio(current_ratio)
	if typeof(SignalBus) == TYPE_NIL:
		bar.set_folded(true)
	else:
		bar.set_folded(BattleInputState.current_selected_unit != self)

func take_damage(amount: float, attacker: Variant = null) -> void:
	# 预览模式不会受到伤害
	if is_preview_mode:
		return
	var hp_loss: float = amount
	if stats != null and GameManager and GameManager.is_card_grid_battle():
		var pen: float = 0.0
		if attacker != null and is_instance_valid(attacker) and "stats" in attacker:
			var atk_stats: Variant = attacker.get("stats")
			if atk_stats is UnitStats:
				pen = float((atk_stats as UnitStats).armor_penetration)
		var eff_def: float = CardGridDamage.effective_defense(stats.defense, pen)
		var dodge: float = float(stats.dodge_chance)
		var hit: Dictionary = CardGridDamage.resolve_hit(amount, eff_def, dodge)
		hp_loss = float(hit.get("hp_loss", amount))
		if bool(hit.get("apply_recoil", false)):
			_play_card_hit_recoil()
		if bool(hit.get("apply_stun", false)):
			var extra: float = 0.08 + clampf(hp_loss / maxf(stats.max_hp, 1.0), 0.0, 0.25) * 0.35
			_hit_stun_left = maxf(_hit_stun_left, extra)
	# 卡牌特殊能力：平台受伤修改
	if _has_bulwark:
		hp_loss *= CardAbilityManager.get_bulwark_damage_multiplier(self, attacker)
	if _has_titan_mk2:
		hp_loss = CardAbilityManager.apply_titan_mk2_damage_reduction(hp_loss)
	hp -= hp_loss
	# 性能优化：在 HP 变化时更新 HP 条
	_update_hp_bar()
	if SignalBus:
		SignalBus.unit_damaged.emit(self, is_player, hp_loss, global_position)
	if hp <= 0:
		_die()

## 治疗方法（用于词条吸血效果）
func heal(amount: float) -> void:
	if stats == null:
		return
	hp = min(hp + amount, stats.max_hp)
	_update_hp_bar()

## 添加护盾（用于词条效果）
func add_shield(amount: float) -> void:
	shield = min(shield + amount, stats.max_hp * 2.0)  # 护盾上限为双倍 HP

## 扣除伤害时先扣护盾（护盾的防御优先级高）
## 返回实际扣除的 HP
func take_damage_with_shield(amount: float) -> float:
	var remaining_damage: float = amount
	
	# 平台HP变异：血量超过 80% 时额外减少 10% 伤害
	if stats and stats.has_platform_hp_mutation:
		if AffixCombatHandler.check_platform_hp_mutation_extra_defense(self, stats):
			remaining_damage *= 0.9  # 额外减少 10%
	
	# 先从护盾中扣除
	var shield_absorbed: float = min(shield, remaining_damage)
	shield -= shield_absorbed
	remaining_damage -= shield_absorbed
	
	# 剩余伤害扣 HP
	if remaining_damage > 0:
		take_damage(remaining_damage)
	
	return remaining_damage

func _die() -> void:
	# 性能优化：从空间分区网格移除
	_unregister_from_spatial_grid()

	# 性能优化：注销所有光环
	var aura_die: Node = _resolve_autoload(&"AuraManager")
	if aura_die:
		aura_die.unregister_all_auras(self)

	# 卡牌特殊能力：僚机重生
	if has_meta("is_wingman") and bool(get_meta("is_wingman")):
		CardAbilityManager.schedule_wingman_respawn(self)

	# 清理平台光环（恢复友军属性）
	if stats != null:
		match stats.platform_type:
			GC.PlatformType.RADAR:
				CardAbilityManager.remove_radar_range_aura(self)
			GC.PlatformType.SCOUT, GC.PlatformType.STEALTH:
				CardAbilityManager.remove_scout_crit_aura(self)
			GC.PlatformType.FORTRESS:
				CardAbilityManager.remove_fortress_defense_aura(self)

	# 安全清理：防止死亡后继续处理事件
	_cleanup_before_destroy()
	if SignalBus:
		if BattleInputState.current_selected_unit == self:
			BattleInputState.current_selected_unit = null
		SignalBus.unit_died.emit(self, is_player)
	queue_free()

## 销毁前的安全清理
func _cleanup_before_destroy() -> void:
	# 禁用所有处理
	set_process_input(false)
	set_physics_process(false)
	set_process(false)
	# 断开信号连接
	if SignalBus:
		if SignalBus.has_signal("unit_move_command") and SignalBus.unit_move_command.is_connected(_on_unit_move_command):
			SignalBus.unit_move_command.disconnect(_on_unit_move_command)
		if SignalBus.has_signal("phase_law_runtime_changed") and SignalBus.phase_law_runtime_changed.is_connected(_on_phase_law_runtime_changed):
			SignalBus.phase_law_runtime_changed.disconnect(_on_phase_law_runtime_changed)

## =========================================================================
## 性能优化：空间分区系统集成
## =========================================================================

## 注册到空间分区网格
func _register_to_spatial_grid() -> void:
	if not BattleManager or not BattleManager.spatial_grid:
		return
	# 部署虚影也需入格，否则敌方在我方重新部署后索敌不到
	if is_preview_mode:
		return
	BattleManager.spatial_grid.insert(self)

## 从空间分区网格注销
func _unregister_from_spatial_grid() -> void:
	if not BattleManager or not BattleManager.spatial_grid:
		return
	BattleManager.spatial_grid.remove(self)

## 更新空间分区网格中的位置
func _update_in_spatial_grid() -> void:
	if not BattleManager or not BattleManager.spatial_grid:
		return
	if is_preview_mode:
		return
	BattleManager.spatial_grid.update(self)
