extends CharacterBody2D
## 我方装甲单位：根据 UnitStats 显示形状，自动向右移动并攻击
## 拆分模块：AI → ConstructUnitAI, 部署 → ConstructUnitDeploy

const GC = preload("res://resources/game_constants.gd")
const DT = preload("res://resources/design_tokens.gd")
const BulletScene = preload("res://scenes/units/bullet.tscn")
const ModuleEffectHandler = preload("res://scripts/battle/module_effect_handler.gd")
const ModAuraHandler = preload("res://scripts/battle/mod_aura_handler.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const RankRules = preload("res://data/rank_rules.gd")
const CardGridUnitVisuals = preload("res://scripts/card_grid_unit_visuals.gd")
const CardGridBuffStrip = preload("res://scripts/card_grid_buff_strip.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CardGridDamage = preload("res://scripts/card_grid_damage.gd")
const CombatTargeting = preload("res://scripts/combat_targeting.gd")
const TargetSelection = preload("res://scripts/battle/target_selection.gd")
const DamageAttenuation = preload("res://scripts/battle/damage_attenuation.gd")
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
const RuneSpecialHandler = preload("res://managers/rune_special_handler.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
const FortShieldAuraScript = preload("res://scripts/battle/fort_shield_aura.gd")
const CompanyDefs = preload("res://data/company_definitions.gd")  # v6.14: 部署阵营泛光用
# ObjectPoolManager 为 autoload
const BATTLE_MIN_X: float = 40.0
const BATTLE_MAX_X: float = 1240.0
const BATTLE_MIN_Y: float = 280.0
const BATTLE_MAX_Y: float = 440.0
## 我方单位前进上限（留出屏幕边缘余量）
var PLAYER_MAX_ADVANCE_X: float = BATTLE_MAX_X - 80.0
## 全装型静态回退：已对齐 manifest vis_player_029
const OMEGA_SPRITE_PATH := "res://assets/card_icons/player/vis_player_029.png"
static var _omega_tex_cache: Texture2D = null
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
## 我方平台类型 -> 用于显示的敌方原型 id
const PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM := {
	0: "ww1_inf_mp18",
	1: "ww2_inf_thompson",
	2: "ww1_arm_rolls_e",
	3: "ww1_sup_mg_nest",
	4: "mod_arm_stryker_e",
	5: "cold_arm_btr_e",
	6: "fut_arm_hovertank_e",
	7: "ww1_arty_mortar",
	8: "cold_air_m113_e",
	9: "mod_inf_marine",
	10: "fut_inf_spectre_e",
	11: "fut_arm_mech_e",
	12: "mod_inf_marine",  # 临时复用，后续替换专用图
}
var is_player: bool = true
var stats: UnitStats
var hp: float = 100.0
var shield: float = 0.0  # 护盾值
# v7.x 第二批：相位护盾当前值（独立池，由 on_tick 回复，take_damage 优先扣减）
var _phase_shield_current: float = 0.0
## v7.1: 堡垒类(combat_kind==FORT)专属防护光环——纯视觉，让"在防护"可见化。
## 站场上一动不动的防御单位会被玩家误以为"没作用"，此光环持续呼吸 + 受击闪亮强化。
var _fort_shield_aura: Node2D = null
var _is_fort_aura_unit: bool = false  # 缓存判定，避免每帧查 stats.combat_kind
## 受击强化值（0~1）：受击瞬间置1，每帧衰减；驱动护盾环短暂扩张+闪亮
var _fort_aura_hit_boost: float = 0.0
## v7.2: 护盾状态光环（青色外层环）——shield>0 时显示，耗尽消失。
## 巨型能量罩(20000)/符文护盾/法则护盾等所有护盾源都走此路径，让"有护盾"可见化。
var _shield_aura: Node2D = null
var _shield_aura_hit_boost: float = 0.0  # 护盾吸收伤害时的承压闪光
# v7.3 性能优化：光环降频 redraw + 仅变化时 set_meta。
# 原实现每帧 set_meta×2 + queue_redraw（_draw 分配40段PackedVector2Array），20个护盾单位=20次重绘/帧。
# 改为：hit_boost>0（承压闪光）时每帧 redraw；正常态每4帧 redraw 一次（呼吸2s周期，肉眼无感）。
# is_player 恒定（仅首次设），shield_ratio 仅变化超阈值才 set_meta。
var _aura_low_freq_frame: int = 0
var _shield_aura_last_ratio: float = -1.0
var _fort_aura_player_meta_set: bool = false
# ── v8 兵种固定机制运行时状态 ──
# 侦察潜入开局：前 15s 受伤 ×0.6（搬运 enemy_unit stealth grace 逻辑）
var _is_recon_unit: bool = false
var _recon_grace_timer: float = 0.0
const RECON_GRACE_DURATION: float = 15.0
const RECON_GRACE_DAMAGE_MUL: float = 0.6
# 空中突袭击速：前 10s 攻速 ×1.5（搬运 enemy_unit fast tag 逻辑）
var _is_air_assault: bool = false
var _air_assault_timer: float = 0.0
var _air_assault_base_interval: float = 0.0  # 缓存原 attack_interval，供突袭结束撤销
const AIR_ASSAULT_DURATION: float = 10.0
const AIR_ASSAULT_SPEED_MULT: float = 1.5
var attack_timer: float = 0.0
## v5.0 攻速分离: 三阶段攻击状态机 (idle → windup → active → cooldown → idle)
enum AttackPhase { IDLE, WINDUP, ACTIVE, COOLDOWN }
var _attack_phase: int = AttackPhase.IDLE
var _attack_phase_timer: float = 0.0
var target: Node2D = null
var _weapon_cfgs: Array = []
var _move_target: Vector2 = Vector2.INF
# 性能优化：缓存 HP 比率，避免每帧更新 UI
var _cached_hp_ratio: float = -1.0
# P0 性能优化：缓存战斗模式判定，避免每帧 has_method + is_card_grid_battle 反射调用链
var _cached_is_card_grid: bool = true
# 性能优化：目标查找计时器，减少频繁查找
var _target_find_timer: float = 0.0
const TARGET_FIND_INTERVAL: float = 0.3  # 每300ms重新查找一次目标
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
## 卡牌格子战术
var _presentation_card_grid: bool = false
var _hit_stun_left: float = 0.0
var _card_tween: Tween = null
var _card_nudge_tween: Tween = null
var _fire_pulse_tween: Tween = null  ## 开火缩放脉冲（独立于 nudge/recoil，只动 Sprite 子节点）
# v7.4 性能优化：受击闪白/抖动改手写计时动画（原每击 create_tween 2 个 Tween，密集命中时 GC 压力）
# 模式参考 unit_hp_bar._damage_flash（倒计时 + lerp）与 damage_number_display._pop_age（正计时 + 分段）
var _hit_flash_t: float = 0.0           # flash 剩余时间（秒），0=未激活
var _hit_flash_base_modulate: Color = Color.WHITE  # 触发瞬间快照，作 lerp 终点（防 faction_glow/clone 色调冲突）
var _hit_shake_t: float = -1.0          # shake 已用时间（秒），-1=未激活，>=0=激活
const _HIT_FLASH_DURATION: float = 0.15  # v8.3: 0.1→0.15（三阶段闪白）
const _HIT_SHAKE_DURATION: float = 0.14 # v8.3: 0.12→0.14（4×0.035s）
var _death_fade_tween: Tween = null  ## v6.4: 死亡淡出 Tween
var _is_dying: bool = false  ## v6.4: 死亡中标志，防止 _die 重复触发
## v6.14: 部署阵营泛光——实体化瞬间单位泛出激活势力色（0.5s 渐隐回白）
## 仅我方单位 + 有激活势力时触发，让"阵营技能在生效"可见化
var _faction_glow_tween: Tween = null
var _faction_glow_color: Color = Color.WHITE  ## setup 时缓存，materialize 时读取
var _card_grid_rest_x: float = NAN  ## 格子战术中卡片的归位 X（首次 nudge 时记录）
## 卡牌能力冷却 CD（本地 float，避免每帧 meta 字典读写）
var _medic_aura_cd: float = 0.0
var _storm_rider_cd: float = 0.0
var _repair_fortress_cd: float = 0.0
var _buff_strip_timer: float = 0.0
var _ability_accum: float = 0.0  ## 平台能力累加器（降低调用频率）
var _buff_strip_signature: String = ""
## 跨实例共享的资源缓存，避免运行时重复 load()
var _res_cache: Dictionary = {}

func _ready() -> void:
	# 战斗逻辑跟随暂停状态
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# P0 性能优化：is_card_grid_battle() 恒为 true，缓存避免每帧反射
	_cached_is_card_grid = true
	if SignalBus:
		if not SignalBus.unit_move_command.is_connected(_on_unit_move_command):
			SignalBus.unit_move_command.connect(_on_unit_move_command)
	# v6.8: 相位法则被动加成（我方）已停用；敌方减益不受影响

func setup(p_is_player: bool, p_stats: UnitStats, forced_enemy_visual_archetype_id: String = "") -> void:
	is_player = p_is_player
	stats = p_stats
	_using_enemy_archetype_visual = false
	if forced_enemy_visual_archetype_id.is_empty():
		_visual_archetype_id = ""
	else:
		_visual_archetype_id = forced_enemy_visual_archetype_id
	# v6.6: 把 stats 上的 rune_specials meta 复制到节点本身，
	# 否则 RuneSpecialHandler 读取 unit.has_meta("rune_specials") 时永远为 false
	# （Resource 的 meta 不会自动出现在持有它的 Node 上），导致 5 类符文特殊效果静默失效。
	if stats != null and stats.has_meta("rune_specials"):
		var rune_sp = stats.get_meta("rune_specials")
		if rune_sp is Array and not rune_sp.is_empty():
			set_meta("rune_specials", rune_sp)
	# v6.8: 复制改造光环配置 meta（由 _apply_mod_stat_effects 填充）
	# ModAuraHandler 读取节点 meta 后给全体友军广播 buff
	if stats != null and stats.has_meta("mod_aura_summary"):
		var aura_summary = stats.get_meta("mod_aura_summary")
		if aura_summary is Dictionary and not aura_summary.is_empty():
			set_meta("mod_aura_summary", aura_summary)
	# v8 兵种固定机制初始化（从 stats meta 读取 apply_combat_kind_modifiers 设置的标记）
	_init_unit_mechanisms()
	hp = stats.max_hp
	velocity = Vector2.ZERO
	_weapon_cfgs.clear()
	if stats != null and stats.weapons.size() > 0:
		for w in stats.weapons:
			var cfg: Dictionary = w.duplicate()
			if not cfg.has("timer"):
				cfg["timer"] = 0.0
			if not cfg.has("weapon_type"):
				cfg["weapon_type"] = GC.WeaponType.DIRECT
			if not cfg.has("damage"):
				cfg["damage"] = 0.0
			_weapon_cfgs.append(cfg)
	elif stats != null:
		# 确保 _weapon_cfgs 至少有一个占位项（兼容旧逻辑）
		var fallback: Dictionary = {"timer": 0.0, "weapon_type": GC.WeaponType.DIRECT, "damage": 0.0, "phase": AttackPhase.IDLE, "phase_timer": 0.0}
		_weapon_cfgs.append(fallback)
	remove_from_group("player_units")
	remove_from_group("enemy_units")
	if is_player:
		add_to_group("player_units")
	else:
		add_to_group("enemy_units")
	var cs := get_node_or_null("CollisionShape2D")
	if cs:
		cs.disabled = false
	_update_shape()
	_update_visual()
	_maybe_apply_card_grid_presentation()
	_update_hp_bar()

	# 性能优化：插入到空间分区网格
	_register_to_spatial_grid()

	# MEDIC 治疗光环由 _physics_process 内 _medic_aura_cd + apply_medic_heal_aura_tick 驱动（避免每帧 meta）
	if stats != null and stats.platform_type == 9:
		_medic_aura_cd = randf_range(0.0, 0.75)

	# 性能优化：注册其他光环到 AuraManager（setup 可能发生在尚未入树前）
	var aura_mgr: Node = _resolve_autoload(&"AuraManager")
	if aura_mgr:
		match stats.platform_type:
			4:
				aura_mgr.register_aura(self, aura_mgr.AuraType.RADAR_RANGE)
			5, 10:
				aura_mgr.register_aura(self, aura_mgr.AuraType.SCOUT_CRIT)
			3:
				aura_mgr.register_aura(self, aura_mgr.AuraType.FORTRESS_DEF)
			8:
				aura_mgr.register_aura(self, aura_mgr.AuraType.CARRIER_REPAIR)
			12:
					aura_mgr.register_aura(self, aura_mgr.AuraType.COMMAND_GLOBAL)

	# v6.8: 改造光环（ally_* 类改造）— 复用全体广播，给所有同阵营友军加 buff
	# 单位已加入 player_units/enemy_units 分组（上方 add_to_group），广播可正常查询
	ModAuraHandler.apply_mod_auras(self)
	# v7.x: 改造光环施加后刷新 buff_strip，让受影响友军立即显示光环图标
	_update_card_grid_buff_strip(true)

	# 性能优化：初始化卡牌能力缓存（setup时一次性查询）
	_has_regen_frame = CardAbilityManager.has_platform_card(stats.platform_card_id, "fut_air_regen_frame")
	_has_abrams_mk2 = CardAbilityManager.has_platform_card(stats.platform_card_id, "mod_arm_abrams_mk2")
	_has_storm_rider = CardAbilityManager.has_platform_card(stats.platform_card_id, "fut_inf_storm_rider")
	_has_repair_fortress = CardAbilityManager.has_platform_card(stats.platform_card_id, "drop_repair_fortress")
	_has_titan_mk2 = CardAbilityManager.has_platform_card(stats.platform_card_id, "fut_arm_titan_mk2")
	_has_bulwark = CardAbilityManager.has_platform_card(stats.platform_card_id, "fut_sup_bulwark")

	# v7.1: 堡垒类防护光环——纯视觉，让防御单位"在防护"可见化
	_ensure_fort_shield_aura()

	# v6.14: 缓存激活势力色（仅我方单位），供实体化时泛光使用
	# 一次查询避免每单位反射；无激活势力（前20关/未选）时留 WHITE，materialize 时跳过泛光
	_faction_glow_color = Color.WHITE
	if is_player:
		var fsm_node: Node = _resolve_autoload(&"FactionSystemManager")
		if fsm_node != null:
			var active_fid: String = String(fsm_node.get("active_faction")) if "active_faction" in fsm_node else ""
			if not active_fid.is_empty():
				_faction_glow_color = CompanyDefs.get_faction_color(active_fid)

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

## 根据单位 deploy_speed 计算实际部署延迟（委托给 ConstructUnitDeploy）
func _calculate_deploy_delay() -> float:
	return ConstructUnitDeploy.calculate_deploy_delay(stats)

func start_as_deploy_ghost(materialize_after_sec: float = -1.0) -> void:
	ConstructUnitDeploy.start_as_deploy_ghost(self, materialize_after_sec)

func _materialize_deploy_ghost() -> void:
	ConstructUnitDeploy.materialize_deploy_ghost(self)

func force_materialize_if_deploy_ghost() -> void:
	ConstructUnitDeploy.force_materialize_if_deploy_ghost(self)


func apply_card_grid_combat_started() -> void:
	if not is_player:
		return
	if _cached_is_card_grid:
		_enforce_card_grid_lane_alignment()


func _maybe_apply_card_grid_presentation() -> void:
	if stats == null:
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
	# 与敌方一致的双回退：先 UiAssetLoader，再 EnemyArchetypes.resolve_card_icon_texture_path
	# 优先用 setup_with_enemy_visual 注入的 _visual_archetype_id（敌方产兵/我方缴获外观复用），
	# 为空时才走 drops 反查；两者都空则回退 platform_card_id（我方卡走 PLAYER_ICON_OVERRIDE）。
	# 关键：敌方产兵的 platform_card_id 是平台 ID（如 steel_titan_expert），不在 drops 里，
	# get_visual_archetype_id_for_card 会返回空，但 _visual_archetype_id 已被正确设置为真实 archetype。
	var arch_for_icon: String = _visual_archetype_id
	if arch_for_icon.is_empty():
		arch_for_icon = EnemyArchetypes.get_visual_archetype_id_for_card(stats.platform_card_id)
	if arch_for_icon.is_empty():
		arch_for_icon = stats.platform_card_id
	var cfg: Dictionary = EnemyArchetypes.get_config(arch_for_icon)
	var tex: Texture2D = CardGridUnitVisuals.resolve_battle_icon_texture(card_res, arch_for_icon, cfg)
	var spr: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	var walk_sprite: AnimatedSprite2D = get_node_or_null("WalkSprite") as AnimatedSprite2D
	var poly: Polygon2D = get_node_or_null("Shape") as Polygon2D
	# 格子战必须统一走 presentation。
	# 关键修复：tex 解析失败时不能跳过 presentation，否则会残留 _update_visual() 设的
	# 敌方原型 visual_scale（每个 archetype 不同），导致同名卡两张一大一小。
	# tex 为 null 时用 _update_visual 已设到 spr.texture 的纹理兜底，保证 scale 一致。
	if spr != null:
		var use_tex: Texture2D = tex
		if use_tex == null:
			use_tex = spr.texture
		if use_tex != null:
			var rl: int = CardGridUnitVisuals.rank_level_from_id(rank_id)
			CardGridUnitVisuals.apply_battle_unit_presentation(self, spr, card_res, use_tex, true, rl)
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
	_update_card_grid_buff_strip()


func _update_card_grid_buff_strip(force: bool = false) -> void:
	if not _presentation_card_grid or is_preview_mode:
		return
	var sig: String = CardGridBuffStrip.buff_signature(self)
	if not force and sig == _buff_strip_signature:
		return
	_buff_strip_signature = sig
	var spr: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	CardGridUnitVisuals.sync_buff_strip(self, self, spr)
	# v7.x 战场视觉反馈：改造图标条（与 buff_strip 错位，放在更下方）
	CardGridUnitVisuals.sync_mod_strip(self, self, spr)


func _configure_card_grid_player_hp_bar(spr: Sprite2D) -> void:
	ConstructUnitDeploy._configure_card_grid_player_hp_bar(self, spr)


## 格子战术敌方（含相位师装备产兵）：卡面化并与波次格子敌一致固守
func apply_card_grid_enemy_presentation() -> void:
	if stats == null:
		return
	if is_player:
		return
	_presentation_card_grid = true
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
	# 优先用 setup_with_enemy_visual 注入的 _visual_archetype_id（敌方产兵真实 archetype），
	# 为空时才走 drops 反查；两者都空则回退 platform_card_id。
	# 关键修复：敌方产兵 platform_card_id 是平台 ID（如 steel_titan_expert），
	# get_visual_archetype_id_for_card 查不到，但 _visual_archetype_id 已被正确设置。
	var arch_for_icon: String = _visual_archetype_id
	if arch_for_icon.is_empty():
		arch_for_icon = EnemyArchetypes.get_visual_archetype_id_for_card(stats.platform_card_id)
	if arch_for_icon.is_empty():
		arch_for_icon = stats.platform_card_id
	var cfg: Dictionary = EnemyArchetypes.get_config(arch_for_icon)
	if card_res == null:
		card_res = CardGridUnitVisuals.resolve_card_for_archetype(arch_for_icon)
	if card_res == null:
		card_res = CardGridUnitVisuals.synthetic_card_for_archetype(arch_for_icon, cfg)
	var tex: Texture2D = CardGridUnitVisuals.resolve_battle_icon_texture(card_res, arch_for_icon, cfg, false)
	if spr != null and tex != null:
		sprite_ok = CardGridUnitVisuals.apply_battle_unit_presentation(
			self, spr, card_res, tex, false, rank_level
		)
		# v7.x 战场视觉反馈：敌方改造图标条（从 archetype tags 推断）
		CardGridUnitVisuals.sync_mod_strip(self, self, spr)
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
	_update_card_grid_buff_strip(true)


func _acquisition_range() -> float:
	return ConstructUnitAI.acquisition_range(self)


func _play_card_attack_nudge() -> void:
	ConstructUnitAI._play_card_attack_nudge(self)


## 开火缩放脉冲：Sprite 子节点 scale 短暂放大再回弹，模拟开火反冲。
## 只动 Sprite 子节点 scale，不碰根节点 scale.x（翻转符号）/rotation（受击占用）。
## 独立 _fire_pulse_tween 句柄，与 nudge/recoil 各不干扰。
func _play_fire_scale_pulse() -> void:
	var spr: Sprite2D = get_node_or_null("Sprite")
	if spr == null:
		return
	if _fire_pulse_tween != null and _fire_pulse_tween.is_valid():
		_fire_pulse_tween.kill()
	# 记录当前 scale 作回归点（可能被 faction_glow 等改过，不硬编码）
	var base_s: Vector2 = spr.scale
	_fire_pulse_tween = create_tween()
	_fire_pulse_tween.tween_property(spr, "scale", base_s * 1.10, 0.04)
	_fire_pulse_tween.tween_property(spr, "scale", base_s, 0.07)


func _play_card_hit_recoil() -> void:
	if not _presentation_card_grid:
		return
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	const RECOIL_MAX_RAD: float = 0.22
	var rest_r: float = 0.0
	rotation = rest_r
	_card_tween = create_tween()
	var peak_r: float = rest_r - RECOIL_MAX_RAD
	_card_tween.tween_property(self, "rotation", peak_r, 0.06)
	_card_tween.tween_property(self, "rotation", rest_r, 0.12)


## v7.4: 受击闪白触发（手写计时，不再 create_tween）。仅设状态变量，动画在 _update_hit_animations 推进。
func _trigger_hit_flash() -> void:
	if is_preview_mode:
		return
	# 连续命中时保留旧 base（让动画连续回原色，不被中间色截断）
	if _hit_flash_t <= 0.0:
		_hit_flash_base_modulate = modulate
	_hit_flash_t = _HIT_FLASH_DURATION
	modulate = Color.RED if is_player else Color.WHITE  # 瞬间染色


## v7.4: 受击缩放抖动触发（手写分段计时，不再 create_tween）。
func _trigger_hit_shake() -> void:
	if is_preview_mode:
		return
	scale = Vector2.ONE  # 关键：每次重置基准（防 scale 累积漂移）
	_hit_shake_t = 0.0   # 0.0=开始计时


## v8.3: 受击击退位移——沿弹道反方向微位移，给物理反馈（被击不再是"被风吹过"）
## strength：直射 3 / 爆炸 6 / 暴击 10。motion_reduce 时短路（仅保留 flash+shake）。
var _knockback_tween: Tween = null
func _trigger_hit_knockback(direction: Vector2, strength: float) -> void:
	if is_preview_mode or DT.is_motion_reduce():
		return
	if direction == Vector2.ZERO or strength <= 0.0:
		return
	if _knockback_tween != null and _knockback_tween.is_valid():
		_knockback_tween.kill()  # 连续受击时重置（取最新击退方向）
	var base_pos: Vector2 = position
	var off: Vector2 = direction.normalized() * strength
	_knockback_tween = create_tween()
	_knockback_tween.tween_property(self, "position", base_pos + off, 0.04)
	_knockback_tween.tween_property(self, "position", base_pos, 0.08)


## v7.4: 受击动画推进（每 physics 帧调用）。flash 倒计时 lerp 回原色；shake 正计时分段插值。
## v8.3: flash 改三阶段（基色→武器色→回原色 0.15s）；shake 振幅加大（0.78/1.12/0.92/1.0）段长 0.035s。
func _update_hit_animations(delta: float) -> void:
	# ── flash：三阶段（0-0.04s 基色全饱和 → 0.04-0.09s 武器色 → 0.09-0.15s lerp 回原色） ──
	if _hit_flash_t > 0.0:
		_hit_flash_t -= delta
		if _hit_flash_t <= 0.0:
			_hit_flash_t = 0.0
			modulate = _hit_flash_base_modulate
		else:
			var elapsed: float = _HIT_FLASH_DURATION - _hit_flash_t
			var base_color := Color.RED if is_player else Color.WHITE
			# 武器色：淡黄白（模拟弹体颜色反射）
			var weapon_tint := Color(1.0, 0.95, 0.7)
			if elapsed < 0.04:
				# 阶段1：基色全饱和
				modulate = base_color
			elif elapsed < 0.09:
				# 阶段2：基色 → 武器色过渡
				var k2: float = (elapsed - 0.04) / 0.05
				modulate = base_color.lerp(weapon_tint, k2)
			else:
				# 阶段3：武器色 → 原色 lerp
				var k3: float = (elapsed - 0.09) / 0.06
				modulate = weapon_tint.lerp(_hit_flash_base_modulate, k3)
	# ── shake：4 段关键帧（v8.3 加大振幅）0.78→1.12→0.92→1.0，每段 0.035s ──
	if _hit_shake_t >= 0.0:
		_hit_shake_t += delta
		if _hit_shake_t >= _HIT_SHAKE_DURATION:
			scale = Vector2.ONE
			_hit_shake_t = -1.0  # 停用
		else:
			var seg: int = int(_hit_shake_t / 0.035)
			if seg > 3:
				seg = 3
			var local_t: float = (_hit_shake_t - seg * 0.035) / 0.035
			var keys: Array = [0.78, 1.12, 0.92, 1.0]
			var s_start: float = 1.0 if seg == 0 else keys[seg - 1]
			var s_end: float = keys[seg]
			var s: float = lerpf(s_start, s_end, local_t)
			scale = Vector2(s, s)


## v6.6: 幻影克隆体入场脉冲——青色发光放大后回落，让玩家部署时立刻识别克隆体
## 基础半透明色调（青蓝 alpha 0.72）由 BattleSpawnSystem._apply_phantom_clone_buff 预设，
## 本方法仅播一次性入场脉冲，结束后回到该基础色调（非纯白）。
func _play_phantom_clone_spawn_pulse() -> void:
	if not is_instance_valid(self) or is_preview_mode:
		return
	var base_modulate := modulate  # 克隆体青蓝半透明
	# 先闪亮青白色，再回落到基础青蓝半透明
	modulate = Color(0.8, 1.0, 1.0, 0.95)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate", base_modulate, 0.45).set_ease(Tween.EASE_OUT)
	# 轻微放大脉冲，强化"幻影生成"的视觉冲击
	var start_scale := scale
	tw.tween_property(self, "scale", start_scale * 1.18, 0.12).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "scale", start_scale, 0.25).set_ease(Tween.EASE_IN_OUT)


## v6.14: 部署阵营泛光——实体化后单位泛出激活势力色，0.5s 渐隐回白
## 仅我方单位 + 有激活势力（_faction_glow_color 非 WHITE）时触发
## 让"阵营技能在生效"可见化（阵营 stat_bonus 此前完全静默应用，玩家无感知）
func _play_faction_glow_pulse() -> void:
	if not is_instance_valid(self) or is_preview_mode:
		return
	# 无激活势力（前20关/未选）→ 不泛光，零开销
	if _faction_glow_color == Color.WHITE:
		return
	# 克隆体已有自己的青色入场脉冲，跳过避免色调冲突
	if modulate != Color.WHITE:
		return
	# 先染阵营色（提高亮度让泛光醒目，不遮挡单位本身），再渐隐回白
	var glow := Color(_faction_glow_color.r, _faction_glow_color.g, _faction_glow_color.b, 1.0)
	glow = glow.lightened(0.35)  # 提亮，避免深色阵营色把单位染暗
	modulate = glow
	if _faction_glow_tween != null and _faction_glow_tween.is_valid():
		_faction_glow_tween.kill()
	_faction_glow_tween = create_tween()
	_faction_glow_tween.tween_property(self, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT)


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
	for i in range(min(_weapon_cfgs.size(), stats.weapons.size())):
		var cfg: Dictionary = _weapon_cfgs[i] as Dictionary
		var sw: Dictionary = stats.weapons[i] as Dictionary
		if sw.has("damage"):
			cfg["damage"] = float(sw["damage"])
		_weapon_cfgs[i] = cfg


func _update_shape() -> void:
	var poly: Polygon2D = get_node_or_null("Shape") as Polygon2D
	if poly == null:
		return
	var pts: PackedVector2Array = _shape_points()
	poly.polygon = pts
	# 我方蓝色，敌方红色（用于相位师等复用构装体场景的敌方单位）
	poly.color = Color(0.2, 0.4, 0.9) if is_player else Color(0.85, 0.2, 0.2)

# ═════════════════════════════════════════════════════════════════
#  v8: 兵种固定机制运行时处理（侦察潜入 / 空中突袭）
#  apply_combat_kind_modifiers 在 stats 上设 meta 标记，setup 时 _init_unit_mechanisms 读取并初始化。
#  _process 每 frame 递减计时器；take_damage 读 _is_recon_unit 判定减伤。
#  空中突袭需在结束时刻撤销攻速加成（恢复缓存的原 attack_interval）。
# ═════════════════════════════════════════════════════════════════

## v8: 从 stats meta 读取兵种固定机制标记，初始化运行时状态
func _init_unit_mechanisms() -> void:
	_is_recon_unit = false
	_recon_grace_timer = 0.0
	_is_air_assault = false
	_air_assault_timer = 0.0
	if stats == null:
		return
	# 侦察潜入开局
	if stats.has_meta("is_recon_unit") and bool(stats.get_meta("is_recon_unit", false)):
		_is_recon_unit = true
		_recon_grace_timer = RECON_GRACE_DURATION
	# 空中突袭击速
	if stats.has_meta("is_air_assault") and bool(stats.get_meta("is_air_assault", false)):
		_is_air_assault = true
		_air_assault_timer = AIR_ASSAULT_DURATION
		# 缓存原攻速并立即应用突袭加速（×1.5 攻速 = interval ×(1/1.5)）
		_air_assault_base_interval = stats.attack_interval
		var assault_interval: float = maxf(0.05, stats.attack_interval / AIR_ASSAULT_SPEED_MULT)
		stats.attack_interval = assault_interval
		attack_timer = minf(attack_timer, assault_interval)  # 防止已积累的攻击时间溢出
		# weapon_slots 攻速等比放大（_process_attack_timing 优先读 weapon timing）
		var spd_mult: float = AIR_ASSAULT_SPEED_MULT
		for w in stats.weapon_slots:
			if w != null and w.enabled:
				w.attack_speed = maxf(0.1, float(w.attack_speed) * spd_mult)


## v8: 侦察潜入开局计时器递减（_process 调用）
func _update_recon_grace(delta: float) -> void:
	if not _is_recon_unit or _recon_grace_timer <= 0.0:
		return
	_recon_grace_timer = maxf(0.0, _recon_grace_timer - delta)


func _is_recon_in_grace() -> bool:
	return _is_recon_unit and _recon_grace_timer > 0.0


## v8: 空中突袭击速计时器递减，归零时撤销攻速加成（_process 调用）
func _update_air_assault(delta: float) -> void:
	if not _is_air_assault or _air_assault_timer <= 0.0:
		return
	_air_assault_timer = maxf(0.0, _air_assault_timer - delta)
	if _air_assault_timer <= 0.0:
		# 突袭结束，撤销攻速加成
		_is_air_assault = false
		if stats != null and _air_assault_base_interval > 0.0:
			stats.attack_interval = _air_assault_base_interval
			# weapon_slots 攻速恢复
			for w in stats.weapon_slots:
				if w != null and w.enabled:
					w.attack_speed = maxf(0.1, float(w.attack_speed) / AIR_ASSAULT_SPEED_MULT)


# ═════════════════════════════════════════════════════════════════
#  v7.1: 堡垒类防护光环（纯视觉）
#  防御单位站场不动易被误以为"没作用"，加持续呼吸的护盾环 + 受击闪亮，
#  让"在防护"可见化。零数值影响，绘制由 FortShieldAura 子节点承担。
# ═════════════════════════════════════════════════════════════════

## 判定并创建堡垒防护光环。堡垒类(combat_kind==FORT)才挂，其他单位 _is_fort_aura_unit 保持 false。
func _ensure_fort_shield_aura() -> void:
	_is_fort_aura_unit = false
	if is_preview_mode or is_deploy_ghost:
		return
	if stats == null:
		return
	if stats.combat_kind != GC.CombatKind.FORT:
		return
	_is_fort_aura_unit = true
	if _fort_shield_aura != null and is_instance_valid(_fort_shield_aura):
		# 已创建（setup 可能在重置时重入）：重置受击强化，复用现有节点
		_fort_aura_hit_boost = 0.0
		return
	var aura: Node2D = Node2D.new()
	aura.set_script(FortShieldAuraScript)
	aura.name = "FortShieldAura"
	aura.z_index = -1  # 画在单位本体之下，作为环绕光晕
	aura.set_meta(&"mode", "fort")
	add_child(aura)
	_fort_shield_aura = aura

## v7.2: 创建护盾状态光环（shield>0 时懒创建）
func _ensure_shield_aura() -> void:
	if _shield_aura != null and is_instance_valid(_shield_aura):
		return
	var aura: Node2D = Node2D.new()
	aura.set_script(FortShieldAuraScript)
	aura.name = "ShieldAura"
	aura.z_index = -2  # 护盾环画在堡垒环之外（更外层"罩"）
	aura.set_meta(&"mode", "shield")
	aura.visible = false  # 默认隐藏，shield>0 时才显示
	add_child(aura)
	_shield_aura = aura

## 每帧驱动光环呼吸 + 衰减受击强化。
## 堡垒环仅堡垒单位生效；护盾环对任何 shield>0 的单位生效（耗尽自动隐藏）。
func _update_fort_shield_aura(delta: float) -> void:
	# 预览/虚影态不显示任何光环
	if is_preview_mode or is_deploy_ghost:
		if _fort_shield_aura != null and is_instance_valid(_fort_shield_aura):
			_fort_shield_aura.visible = false
		if _shield_aura != null and is_instance_valid(_shield_aura):
			_shield_aura.visible = false
		return

	# ── 堡垒职业环 ──
	if _is_fort_aura_unit and _fort_shield_aura != null and is_instance_valid(_fort_shield_aura):
		_fort_shield_aura.visible = true
		if _fort_aura_hit_boost > 0.0:
			_fort_aura_hit_boost = maxf(0.0, _fort_aura_hit_boost - delta * 2.0)
		# v7.3: is_player 恒定，仅首次设置（原每帧 set_meta）
		if not _fort_aura_player_meta_set:
			_fort_shield_aura.set_meta(&"is_player", is_player)
			_fort_aura_player_meta_set = true
		_fort_shield_aura.set_meta(&"hit_boost", _fort_aura_hit_boost)
		# v7.3: 承压闪光时每帧 redraw，正常态每4帧一次（呼吸动画降频）
		if _fort_aura_hit_boost > 0.0 or (_aura_low_freq_frame % 4) == 0:
			_fort_shield_aura.queue_redraw()

	# ── 护盾状态环（v7.2）──
	# shield>0 才显示，耗尽隐藏；护盾吸收伤害时(_shield_aura_hit_boost)承压闪光
	var has_shield: bool = shield > 0.0
	if has_shield:
		if _shield_aura == null or not is_instance_valid(_shield_aura):
			_ensure_shield_aura()
		if _shield_aura != null and is_instance_valid(_shield_aura):
			_shield_aura.visible = true
			if _shield_aura_hit_boost > 0.0:
				_shield_aura_hit_boost = maxf(0.0, _shield_aura_hit_boost - delta * 2.0)
			# 护盾比例（基于 max_hp*2 上限，与 add_shield 的 clamp 一致）
			var shield_cap: float = stats.max_hp * 2.0 if stats != null else 200.0
			var shield_ratio: float = clampf(shield / shield_cap, 0.0, 1.0) if shield_cap > 0.0 else 0.0
			# v7.3: shield_ratio 仅变化超0.02才 set_meta（原每帧 set_meta）
			if absf(shield_ratio - _shield_aura_last_ratio) > 0.02:
				_shield_aura.set_meta(&"shield_ratio", shield_ratio)
				_shield_aura_last_ratio = shield_ratio
			_shield_aura.set_meta(&"hit_boost", _shield_aura_hit_boost)
			# v7.3: 承压闪光或比例变化时每帧 redraw，正常态每4帧一次
			if _shield_aura_hit_boost > 0.0 or (_aura_low_freq_frame % 4) == 0:
				_shield_aura.queue_redraw()
	elif _shield_aura != null and is_instance_valid(_shield_aura):
		_shield_aura.visible = false  # 护盾耗尽，隐藏（节点保留，下次获得护盾复用）
	# v7.3: 帧计数推进（用于降频 redraw）
	_aura_low_freq_frame += 1


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

	var is_omega := stats != null and stats.platform_type == 11
	if is_player:
		# 我方：全装型与敌方「机甲步兵」同源精灵（fut_arm_mech_e），仅朝右；缺镜像时再回退静态 fallback
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


static func _load_omega_fallback_texture() -> Texture2D:
	if _omega_tex_cache != null:
		return _omega_tex_cache
	if ResourceLoader.exists(OMEGA_SPRITE_PATH):
		_omega_tex_cache = load(OMEGA_SPRITE_PATH) as Texture2D
	return _omega_tex_cache


## 优先用平台卡 id 查 manifest 卡图（fut_arm_omega → vis_player_029），再退回兵种镜像表
func _player_platform_visual_archetype_id() -> String:
	if stats == null:
		return ""
	var platform_cid: String = stats.platform_card_id.strip_edges()
	if not platform_cid.is_empty():
		var foe_arch: String = EnemyUnitManifest.archetype_id_for_platform_card(platform_cid)
		if not EnemyUnitManifest.get_unit_icon_path_for_archetype(foe_arch).is_empty():
			return foe_arch
	return String(PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM.get(int(stats.platform_type), ""))


func _apply_omega_static_player_visual(sprite: Sprite2D, walk_sprite: AnimatedSprite2D, poly: Polygon2D) -> void:
	if walk_sprite != null:
		walk_sprite.sprite_frames = null
		walk_sprite.visible = false
	var tex: Texture2D = _load_omega_fallback_texture()
	if sprite != null and tex != null:
		sprite.texture = tex
		sprite.visible = true
		_scale_static_sprite_to_enemy_archetype(sprite, "foe_fut_arm_omega")
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
	var archetype_id: String = _player_platform_visual_archetype_id()
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


func _clamp_enemy_archetype_sprite_extent(spr: Sprite2D) -> void:
	if spr == null or not spr.visible or spr.texture == null:
		return
	var w := float(spr.texture.get_width()) * absf(spr.scale.x)
	var h := float(spr.texture.get_height()) * absf(spr.scale.y)
	var m := maxf(w, h)
	if m <= 1.0 or m <= MAX_ENEMY_VISUAL_EXTENT_PX:
		return
	spr.scale *= MAX_ENEMY_VISUAL_EXTENT_PX / m

func _shape_points() -> PackedVector2Array:
	var s = 24.0
	match stats.platform_type:
		0:
			return PackedVector2Array([Vector2(0, -s), Vector2(s*0.8, s), Vector2(-s*0.8, s)])
		1:
			return PackedVector2Array([Vector2(-s,s), Vector2(s,s), Vector2(s,-s), Vector2(-s,-s)])
		2:
			return PackedVector2Array([Vector2(-s*1.2,s), Vector2(s*1.2,s), Vector2(s*1.2,-s), Vector2(-s*1.2,-s)])
		11:
			return PackedVector2Array([Vector2(-s*1.4,s), Vector2(s*1.4,s), Vector2(s*1.4,-s), Vector2(-s*1.4,-s)])
		3:
			var arr: PackedVector2Array = []
			for i in range(8):
				var a = TAU * i / 8.0
				arr.append(Vector2(cos(a)*s, sin(a)*s))
			return arr
		4:
			# 十字形雷达
			var arm = s * 0.4
			return PackedVector2Array([
				Vector2(0, -s), Vector2(arm, -arm), Vector2(s, 0),
				Vector2(arm, arm), Vector2(0, s), Vector2(-arm, arm),
				Vector2(-s, 0), Vector2(-arm, -arm)
			])
		5:
			return PackedVector2Array([Vector2(0, -s), Vector2(s*0.8, s), Vector2(-s*0.8, s)])
		6:
			return PackedVector2Array([Vector2(-s,s), Vector2(s,s), Vector2(s,-s), Vector2(-s,-s)])
		7:  # 迫击炮：与装甲(2)同形
			return PackedVector2Array([Vector2(-s*1.2,s), Vector2(s*1.2,s), Vector2(s*1.2,-s), Vector2(-s*1.2,-s)])
		8:
			return PackedVector2Array([Vector2(-s*1.1,s), Vector2(s*1.1,s), Vector2(s*1.1,-s), Vector2(-s*1.1,-s)])
		9:
			return PackedVector2Array([Vector2(-s,s), Vector2(s,s), Vector2(s,-s), Vector2(-s,-s)])
		10:
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
		if ConstructUnitDeploy.update_deploy_ghost(self, delta):
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
		ConstructUnitAI.find_target(self, delta)
	# 应用持续效果（回血）
	ConstructUnitAI.apply_continuous_effects(self, delta)
	# 格子战术：单位固守当前格，不位移
	velocity = Vector2.ZERO
	_move_target = Vector2.INF
	ConstructUnitAI.process_attack(self, delta)
	# v7.1: 堡垒防护光环呼吸动画（仅堡垒类单位，非堡垒时 _is_fort_aura_unit=false 直接返回）
	_update_fort_shield_aura(delta)
	# v8: 侦察潜入 + 空中突袭计时器递减
	_update_recon_grace(delta)
	_update_air_assault(delta)
	# v7.4: 受击闪白/抖动手写动画推进（原 create_tween 改手写计时）
	_update_hit_animations(delta)
	move_and_slide()
	_clamp_inside_battlefield()
	if not is_player and _cached_is_card_grid:
		velocity = Vector2.ZERO
	# 性能优化：静止单位跳过空间网格更新
	if velocity != Vector2.ZERO:
		_update_in_spatial_grid()
	# 卡牌特殊能力：平台效果（累加器降低调用频率，每0.2s结算一次）
	if _has_regen_frame or _has_abrams_mk2 or _has_storm_rider or _has_repair_fortress:
		if target == null:
			_ability_accum += delta
			if _ability_accum >= 0.2:
				var dt_acc: float = _ability_accum
				_ability_accum = 0.0
				if _has_regen_frame:
					if CardAbilityManager.apply_regen_frame_regen(self, dt_acc) > 0.0:
						_update_hp_bar()
				if _has_abrams_mk2:
					if CardAbilityManager.apply_abrams_mk2_regen(self, dt_acc) > 0.0:
						_update_hp_bar()
				if _has_storm_rider:
					CardAbilityManager.apply_storm_rider_speed(self, dt_acc)
				if _has_repair_fortress:
					CardAbilityManager.apply_repair_fortress_heal(self, dt_acc)

	# ── 平台类型光环系统（仅 MEDIC，其余由 AuraManager Timer 驱动） ──
	if stats != null and not is_deploy_ghost and not is_preview_mode:
		if stats.platform_type == 9:
			_medic_aura_cd -= delta
			if _medic_aura_cd <= 0.0:
				_medic_aura_cd = 3.0
				CardAbilityManager.apply_medic_heal_aura_tick(self)

	if _presentation_card_grid and not is_deploy_ghost and not is_preview_mode:
		_buff_strip_timer += delta
		if _buff_strip_timer >= 0.25:
			_buff_strip_timer = 0.0
			_update_card_grid_buff_strip()

func _apply_continuous_effects(delta: float) -> void:
	ConstructUnitAI.apply_continuous_effects(self, delta)

## v5.0 攻速分离: 单武器三阶段攻击状态机（委托给 ConstructUnitAI）
func _process_single_weapon_attack(delta: float) -> void:
	ConstructUnitAI._process_single_weapon_attack(self, delta)

func _process_multi_weapons(delta: float) -> void:
	ConstructUnitAI._process_multi_weapons(self, delta)


func _on_unit_move_command(unit: Node, target_pos: Vector2) -> void:
	# 预览模式不能接受移动指令
	if unit != self or stats == null or is_deploy_ghost or is_preview_mode:
		return
	if _cached_is_card_grid and is_player and int(get_meta("card_grid_slot", -1)) >= 0:
		target_pos.y = global_position.y
	_move_target = target_pos

func _battlefield_y_clamp_range() -> Vector2:
	if _cached_is_card_grid:
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
	if not _cached_is_card_grid:
		return
	var bf: Node = BattleManager.battlefield if BattleManager else null
	if bf == null:
		return
	if is_player:
		var si: int = int(get_meta("card_grid_slot", -1))
		if si < 0 or not bf.has_method("get_card_grid_player_slot_global"):
			return
		var anchor: Vector2 = bf.get_card_grid_player_slot_global(si)
		if global_position.distance_squared_to(anchor) > 0.25:
			global_position = anchor
		# 吸附后重置归位基准，避免下次 nudge 以偏移位置为起点
		_card_grid_rest_x = NAN
		return
	if not _presentation_card_grid:
		return
	var esi: int = int(get_meta("card_grid_enemy_slot", -1))
	if esi < 0 or not bf.has_method("get_card_grid_enemy_slot_global"):
		return
	var anchor: Vector2 = bf.get_card_grid_enemy_slot_global(esi)
	if global_position.distance_squared_to(anchor) > 0.25:
		global_position = anchor
		# 吸附后重置归位基准
		_card_grid_rest_x = NAN

func _get_target_find_interval() -> float:
	return ConstructUnitAI.get_target_find_interval(self)

func _targeting_opponent_phase_field_only() -> bool:
	return ConstructUnitAI.targeting_opponent_phase_field_only(self)


func _effective_fire_range() -> float:
	return ConstructUnitAI.effective_fire_range(self)


func _should_retain_current_target() -> bool:
	return ConstructUnitAI.should_retain_current_target(self)

func _find_target(_delta: float) -> void:
	ConstructUnitAI.find_target(self, _delta)

func _do_attack() -> void:
	ConstructUnitAI.do_attack(self)

func _do_attack_with_damage(damage: float, weapon_type_override: int = -1) -> void:
	ConstructUnitAI.do_attack_with_damage(self, damage, weapon_type_override)

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
	# v7.x 战场视觉反馈：记录最后攻击者，供 unit_killed 信号携带（击杀定帧/连杀提示依赖）
	if attacker != null and is_instance_valid(attacker):
		set_meta("_last_attacker", attacker)
	var hp_loss: float = amount
	if stats != null and _cached_is_card_grid:
		var pen: float = 0.0
		var attacker_kind: int = -1
		if attacker != null and is_instance_valid(attacker) and "stats" in attacker:
			var atk_stats: Variant = attacker.get("stats")
			if atk_stats is UnitStats:
				# v6.2: 条件型穿甲（相克 MOD）按目标(自身)类型激活
				if (atk_stats as UnitStats).has_method("get_effective_armor_penetration"):
					pen = (atk_stats as UnitStats).get_effective_armor_penetration(stats.combat_kind)
				else:
					pen = float((atk_stats as UnitStats).armor_penetration)
				attacker_kind = int((atk_stats as UnitStats).combat_kind)
		# v6.6 修复：防御按攻击者类型选三维维度，而非用单一 stats.defense 字段。
		# 修复前用 stats.defense（build 时的三维最大值快照，后续加成不更新且不分攻击类型），
		# 与实际三维脱节，导致高防单位被特定类型攻击打像没防御。与 swarm_enemy_slot 口径对齐。
		var base_def: float = stats.defense
		match attacker_kind:
			GC.CombatKind.LIGHT, GC.CombatKind.SUPPORT:
				base_def = stats.defense_light
			GC.CombatKind.ARMOR, GC.CombatKind.FORT:
				base_def = stats.defense_armor
			GC.CombatKind.AIR:
				base_def = stats.defense_air
			_:
				base_def = maxf(stats.defense_light, maxf(stats.defense_armor, stats.defense_air))
		# v7.x: 破甲叠加——读取自身 meta 的破甲层数，降低有效防御
		# 每层按 armor_break_ratio 比例降低防御（_apply_armor_break 在攻击者命中时挂载）
		if has_meta("_armor_break_stacks"):
			var _ab_stacks: int = int(get_meta("_armor_break_stacks", 0))
			var _ab_ratio: float = float(get_meta("_armor_break_ratio", 0.0))
			if _ab_stacks > 0 and _ab_ratio > 0.0:
				var _total_reduction: float = _ab_stacks * _ab_ratio
				base_def = base_def * maxf(0.1, 1.0 - _total_reduction)
		var eff_def: float = CardGridDamage.effective_defense(base_def, pen)
		var dodge: float = float(stats.dodge_chance)
		# v7.5: 传入 damage_reduction（此前全链路空转，现 resolve_hit 接入）
		var dmg_red: float = float(stats.damage_reduction)
		var hit: Dictionary = CardGridDamage.resolve_hit(amount, eff_def, dodge, dmg_red)
		hp_loss = float(hit.get("hp_loss", amount))
		# v7.x: 标记系统——被标记目标受额外伤害（_apply_mark 在攻击者命中时挂载）
		if has_meta("_marked_until"):
			var _mark_expire: float = float(get_meta("_marked_until", 0.0))
			var _now: float = Time.get_ticks_msec() / 1000.0
			if _now < _mark_expire:
				var _vuln: float = float(get_meta("_mark_vuln_bonus", 0.0))
				if _vuln > 0.0:
					hp_loss = hp_loss * (1.0 + _vuln)
			else:
				# 标记过期，清理 meta
				remove_meta("_marked_until")
				remove_meta("_mark_vuln_bonus")
		# v8.x: 暴击标注惰性清理（加成按时间戳在 bullet.gd 判定，过期 meta 顺带清掉）
		if has_meta("_crit_marked_until"):
			var _cm_expire: float = float(get_meta("_crit_marked_until", 0.0))
			if Time.get_ticks_msec() / 1000.0 >= _cm_expire:
				remove_meta("_crit_marked_until")
				remove_meta("_crit_mark_bonus")
		# v7.x: 巷战免伤——受 ARMOR/AIR 攻击时减免（步兵巷战教范）
		if stats.urban_defense_bonus > 0.0 and attacker_kind >= 0:
			if attacker_kind == GC.CombatKind.ARMOR or attacker_kind == GC.CombatKind.AIR:
				hp_loss = hp_loss * (1.0 - stats.urban_defense_bonus)
		# v8: 侦察潜入开局——前 15s 受伤 ×0.6（兵种固定机制）
		if _is_recon_in_grace():
			hp_loss = hp_loss * RECON_GRACE_DAMAGE_MUL
		# v8: 堡垒阵地坚守光环——范围内堡垒庇护 meta 减伤（兵种固定机制）
		# _apply_fort_shelter_aura 在友方堡垒 on_tick 时挂载此 meta（持续 1s 每 tick 刷新）
		if has_meta("_fort_shelter_until"):
			var _fs_expire: float = float(get_meta("_fort_shelter_until", 0.0))
			var _fs_now: float = Time.get_ticks_msec() / 1000.0
			if _fs_now < _fs_expire:
				var _fs_bonus: float = float(get_meta("_fort_shelter_bonus", 0.0))
				if _fs_bonus > 0.0:
					hp_loss = hp_loss * (1.0 - _fs_bonus)
		if bool(hit.get("apply_recoil", false)):
			_play_card_hit_recoil()
		if bool(hit.get("apply_stun", false)):
			var extra: float = 0.08 + clampf(hp_loss / maxf(stats.max_hp, 1.0), 0.0, 0.25) * 0.35
			_hit_stun_left = maxf(_hit_stun_left, extra)
	# v7.x 第二批：拦截判定（概率伤害归零，在 hp 扣减之前）
	if stats != null and ModuleEffectHandler.try_intercept(self):
		return  # 拦截成功，跳过所有伤害
	# 卡牌特殊能力：平台受伤修改
	if _has_bulwark:
		hp_loss *= CardAbilityManager.get_bulwark_damage_multiplier(self, attacker)
	if _has_titan_mk2:
		hp_loss = CardAbilityManager.apply_titan_mk2_damage_reduction(hp_loss)
	# v6.2: 符文之语特殊效果 — 受击时触发（护盾生成）
	RuneSpecialHandler.on_damaged(self, attacker, hp_loss)
	# v7.x 第二批：相位护盾分流（独立池，在常规护盾之前扣减）
	if stats != null and stats.phase_shield_pool > 0.0:
		if not ("_phase_shield_current" in self):
			_phase_shield_current = stats.phase_shield_pool
		if _phase_shield_current > 0.0 and hp_loss > 0.0:
			var phase_absorbed: float = min(_phase_shield_current, hp_loss)
			_phase_shield_current -= phase_absorbed
			hp_loss -= phase_absorbed
	# v6.6: 护盾吸收 — 优先从护盾值扣减，剩余伤害才扣 HP。
	# 修复前 shield 只增不减（add_shield 被 on_kill/law/rune 调用，但伤害从不走护盾吸收路径），
	# 导致击杀护盾、法则护盾、符文护盾全部"白给"。现在 take_damage 入口统一扣护盾。
	if shield > 0.0 and hp_loss > 0.0:
		var absorbed: float = min(shield, hp_loss)
		shield -= absorbed
		hp_loss -= absorbed
		# v7.2: 护盾承压闪光（护盾环扩张+变亮，让玩家感知"护盾在挡伤害"）
		_shield_aura_hit_boost = 1.0
		_update_hp_bar()
	hp -= hp_loss

	# 性能优化：在 HP 变化时更新 HP 条
	_update_hp_bar()
	if SignalBus:
		SignalBus.unit_damaged.emit(self, is_player, hp_loss, global_position)
	# v7.x: 触发受击型改造效果（怒气积累、反击标记等）
	# 注：on_damage_taken 需在 hp 扣减之后调用，让 handler 能读取当前 hp 状态
	ModuleEffectHandler.on_damage_taken(self, attacker, hp_loss)
	if hp <= 0:
		_die()
		return  # 死亡后跳过受击反馈（节点即将 freed，tween 会报错）

	# 受击闪白/抖动反馈（仅存活单位；死亡时 queue_free 后写 freed instance）
	_trigger_hit_flash()
	_trigger_hit_shake()
	# v8.3: 受击击退——从攻击者位置推方向（被击沿弹道反方向位移）
	if attacker != null and is_instance_valid(attacker) and (attacker is Node2D):
		var kb_dir: Vector2 = global_position - (attacker as Node2D).global_position
		# 强度按攻击者爆炸半径判定：爆炸类 6，否则直射 3
		var kb_str: float = 6.0 if (attacker.get("explosion_radius") != null and float(attacker.get("explosion_radius")) > 0.0) else 3.0
		_trigger_hit_knockback(kb_dir, kb_str)
	# v8.1: 血条受击闪白（接通 unit_hp_bar.trigger_damage_flash，原为未连线死功能）
	var _hpbar := get_node_or_null("HpBar")
	if _hpbar != null and _hpbar.has_method("trigger_damage_flash"):
		_hpbar.trigger_damage_flash()
	# v7.1: 堡垒防护光环受击强化（扩张+闪亮）
	if _is_fort_aura_unit:
		_fort_aura_hit_boost = 1.0

## 治疗方法（用于词条吸血效果）
func heal(amount: float) -> void:
	if stats == null:
		return
	hp = min(hp + amount, stats.max_hp)
	_update_hp_bar()

## 添加护盾（用于词条效果）
func add_shield(amount: float) -> void:
	if amount <= 0.0:
		return
	var old_shield = shield
	shield = min(shield + amount, stats.max_hp * 2.0)  # 护盾上限为双倍 HP
	# 更新护盾条显示
	var hpbar = get_node_or_null("HpBar") as Node2D
	if hpbar and hpbar.has_method("set_shield") and hpbar.has_method("trigger_shield_gain"):
		hpbar.set_shield(shield, stats.max_hp)
		if old_shield <= 0.0 or old_shield < shield * 0.5:  # 首次获得或大幅增加时触发闪光
			hpbar.trigger_shield_gain(amount, stats.max_hp)

## 扣除伤害时先扣护盾（护盾的防御优先级高）
## 返回实际扣除的 HP
func take_damage_with_shield(amount: float) -> float:
	var remaining_damage: float = amount

	# 平台HP变异：血量超过 80% 时额外减少 10% 伤害
	if stats and stats.has_platform_hp_mutation:
		if ModuleEffectHandler.check_platform_hp_mutation_extra_defense(self, stats):
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
	if _is_dying:
		return
	_is_dying = true
	# v6.2: 符文之语特殊效果 — 死亡复活检查（复活成功则中止死亡流程）
	if RuneSpecialHandler.on_death(self):
		return
	# v7.x 第二批：改造濒死复活（IFAK/急救包）+ 亡语治疗
	# on_death 返回 true 表示复活成功，中止死亡流程（亡语治疗不触发）
	var _killer_for_death: Variant = null
	if has_meta("_last_attacker"):
		_killer_for_death = get_meta("_last_attacker", null)
	if ModuleEffectHandler.on_death(self, _killer_for_death):
		return  # 复活成功
	# v7.x: 触发击杀型改造效果（击杀护盾 shield_on_kill 等）
	# 注：此前 on_kill 全项目零调用方，shield_on_kill 改造空转；此处接通断链
	# 取最后攻击者作为击杀者，传递给 ModuleEffectHandler
	var _killer_for_mod: Variant = null
	if has_meta("_last_attacker"):
		_killer_for_mod = get_meta("_last_attacker", null)
	if _killer_for_mod != null and is_instance_valid(_killer_for_mod):
		ModuleEffectHandler.on_kill(_killer_for_mod)
	# 性能优化：从空间分区网格移除
	_unregister_from_spatial_grid()

	# 性能优化：注销所有光环
	var aura_die: Node = _resolve_autoload(&"AuraManager")
	if aura_die:
		aura_die.unregister_all_auras(self)

	# v6.8: 撤销改造光环 buff（反向清除之前给友军施加的 ally_* 增益）
	ModAuraHandler.remove_mod_auras(self)

	# 卡牌特殊能力：僚机重生
	if has_meta("is_wingman") and bool(get_meta("is_wingman")):
		CardAbilityManager.schedule_wingman_respawn(self)

	# 清理平台光环（恢复友军属性）
	if stats != null:
		match stats.platform_type:
			4:
				CardAbilityManager.remove_radar_range_aura(self)
			5, 10:
				CardAbilityManager.remove_scout_crit_aura(self)
			3:
				CardAbilityManager.remove_fortress_defense_aura(self)
			12:
				CardAbilityManager.remove_command_global_aura(self)

	# 安全清理：防止死亡后继续处理事件
	_cleanup_before_destroy()
	if SignalBus:
		if BattleInputState.current_selected_unit == self:
			BattleInputState.current_selected_unit = null
		SignalBus.unit_died.emit(self, is_player)
		# v7.x 战场视觉反馈：emit unit_killed（含击杀者），供 BattleSpectacle/BattleLog/MVP
		# 用 has_meta 先判定，避免从未被击中过的单位打印 "no meta values" 警告。
		var _killer: Variant = null
		if has_meta("_last_attacker"):
			_killer = get_meta("_last_attacker", null)
		if _killer != null and not is_instance_valid(_killer):
			_killer = null
		SignalBus.unit_killed.emit(self, _killer, is_player)
	# v6.2: 符文之语特殊效果 — 敌方单位死亡时，触发玩家方单位的击杀回能
	if not is_player:
		_trigger_allied_kill_rewards()
	# v6.4: 死亡淡出动画（缩放+透明度），逻辑结算已完成，仅做视觉收尾
	_play_death_fadeout()


## v7.x 第二批：复活后状态重置（由 ModuleEffectHandler._revive_unit 调用）
func on_revived() -> void:
	# 重置 hp bar
	_update_hp_bar()
	# 重新注册空间分区网格（_die 时 _unregister 了，但复活在 _unregister 之前 return，所以可能还在）
	# 安全起见：若已注销则重新注册
	_register_to_spatial_grid_if_needed()
	# emit 复活信号供 UI/特效使用
	if SignalBus and SignalBus.has_signal("unit_damaged"):
		SignalBus.unit_damaged.emit(self, is_player, 0.0, global_position)


## v7.x 第二批：安全注册空间网格（若未注册）
func _register_to_spatial_grid_if_needed() -> void:
	# construct_unit 的 _unregister_from_spatial_grid 在复活 return 之后才执行，
	# 所以复活时单位仍在网格中，无需重复注册。此方法留作安全兜底（空实现）。
	pass


## v6.2: 敌方单位死亡时，触发所有携带 on_kill_regen_energy 的玩家方单位
## 每个符合条件的单位独立判定概率（非击杀者专属，而是光环式全局效果）
func _trigger_allied_kill_rewards() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	var allies: Array = tree.get_nodes_in_group("player_units")
	for ally in allies:
		if not is_instance_valid(ally):
			continue
		RuneSpecialHandler.on_kill(ally, self)


## v6.4: 死亡视觉淡出——快速缩放并淡出后销毁节点（逻辑结算已完成，不依赖 _process）
func _play_death_fadeout() -> void:
	if _death_fade_tween != null and _death_fade_tween.is_valid():
		_death_fade_tween.kill()
	var start_scale := scale
	_death_fade_tween = create_tween()
	_death_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_death_fade_tween.tween_property(self, "scale", start_scale * 1.15, 0.08)
	_death_fade_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	_death_fade_tween.tween_property(self, "scale", Vector2.ZERO, 0.17)
	_death_fade_tween.tween_callback(queue_free)


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
