extends CharacterBody2D
## 敌方单位：卡图立绘（Sprite2D）+ 自动向左移动并攻击；已弃用 SpriteFrames 序列帧

const BulletScene = preload("res://scenes/units/bullet.tscn")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyStatResolver = preload("res://data/enemy_stat_resolver.gd")
const MuzzleAnchors = preload("res://data/muzzle_anchors.gd")
const ModuleEffectHandler = preload("res://scripts/battle/module_effect_handler.gd")
const GC = preload("res://resources/game_constants.gd")
const AttackPoseAnim = preload("res://scripts/battle/attack_pose_anim.gd")  # v9.x: 按武器分化的攻击姿态/攻击帧
const DT = preload("res://resources/design_tokens.gd")
const CardGridUnitVisuals = preload("res://scripts/card_grid_unit_visuals.gd")
const CardGridBattleLayout = preload("res://scripts/card_grid_battle_layout.gd")
const CardGridBuffStrip = preload("res://scripts/card_grid_buff_strip.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CardGridDamage = preload("res://scripts/card_grid_damage.gd")
const CombatTargeting = preload("res://scripts/combat_targeting.gd")
const RankRules = preload("res://data/rank_rules.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const TargetSelection = preload("res://scripts/battle/target_selection.gd")
const DamageAttenuation = preload("res://scripts/battle/damage_attenuation.gd")
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
const FortShieldAuraScript = preload("res://scripts/battle/fort_shield_aura.gd")
const ConstructUnitDeploy = preload("res://scripts/battle/construct_unit_deploy.gd")
const ConstructUnitAI = preload("res://scripts/battle/construct_unit_ai.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const BATTLE_MIN_X: float = 40.0
const BATTLE_MAX_X: float = 1240.0
# v9.3: 扩大 Y 硬夹范围（原 280~440 仅覆盖旧双行布局；三行布局下行 center+60
# 在高背景纹理关卡可能 >440；扩大到 200~560 覆盖三行全程 + 高/低车道中心）
const BATTLE_MIN_Y: float = 200.0
const BATTLE_MAX_Y: float = 560.0
## 单帧贴图超过此边长视为整张地图/错误资源，不使用（卡面立绘标准为 1024）
const MAX_ENEMY_FRAME_TEX_DIM := 1280
## 最终显示在战场上的最大宽高（像素），防止误配大图占满屏
const MAX_ENEMY_VISUAL_EXTENT_PX := 220.0
const ENABLE_ENEMY_VISUAL_EXTENT_CLAMP := true

var is_player: bool = false
var hp: float = 80.0
var max_hp: float = 80.0
## v7.1: 堡垒类(combat_kind==FORT)专属防护光环——纯视觉，让"在防护"可见化。
var _fort_shield_aura: Node2D = null
var _is_fort_aura_unit: bool = false
var _fort_aura_hit_boost: float = 0.0
# v7.4: 堡垒光环降频 redraw（对齐 construct_unit：正常态每4帧，承压时每帧）
var _aura_low_freq_frame: int = 0
var _fort_aura_meta_set: bool = false
var attack_damage: float = 10.0
var attack_range: float = 100.0
var attack_interval: float = 1.0
## v5.0 攻速分离: 三阶段攻击状态机 (IDLE=0, WINDUP=1, ACTIVE=2, COOLDOWN=3)
var _attack_phase: int = 0
var _attack_phase_timer: float = 0.0
var move_speed: float = 60.0
var defense: float = 5.0
var target: Node2D = null
var wave_index: int = 0
var archetype_id: String = "basic_infantry"
var damage_reduction: float = 0.0  # 用于卡牌特殊能力 debuff
var stats: UnitStats = null  # 用于词条效果计算
# v7.x: 敌方布置时间（部署虚影）——入场后半透明、不动、不开火，过 _ghost_materialize_time_left 秒后实体化投入战斗。
# is_deploy_ghost 被 battle_manager._is_active_combat_unit 鸭子识别，部署期不计入存活数。
# 与 ConstructUnit 不同：敌兵实体化时 NOT 回满血（保留布置期间被打掉的血，避免玩家输出被回满白费）。
var is_deploy_ghost: bool = false
var _ghost_materialize_time_left: float = 0.0
var _attack_weapon_index: int = 0  # 多武器时轮换
# 性能优化：缓存 archetype 配置，避免每次攻击查字典
var _cached_archetype_cfg: Dictionary = {}
var _incoming_damage_mul: float = 1.0
var last_damage_source: Node = null  # 记录最后造成伤害的单位
var _base_stats_ready: bool = false
var _base_max_hp: float = 80.0
var _base_attack_damage: float = 10.0
var _base_move_speed: float = 60.0
var _base_attack_interval: float = 1.0
# v6.3: 缓存三维基础攻击（律法减益重算时用）
var _cached_enemy_base: Dictionary = {}
var _visual_scale_archetype_id: String = ""
# 性能优化：缓存 HP 比率，避免每帧更新 UI
var _cached_hp_ratio: float = -1.0
# 性能优化：目标查找计时器，减少频繁查找
var _target_find_timer: float = 0.0
## v6.6: 缓存索敌间隔，避免每帧 has_method 反射；当单位数档位变化时才重算
var _cached_target_find_interval: float = -1.0
var _cached_interval_unit_count: int = -1
const TARGET_FIND_INTERVAL: float = 0.3  # 每300ms重新查找一次目标
## 性能优化：缓存攻击时序数据，避免每帧重新查字典
var _cached_timing: Dictionary = {}
var _cached_fire_range: float = -1.0
var _cached_weapon_type: int = -1
var _cached_target_ref: Node2D = null
# P0 性能优化：缓存战斗模式判定，避免每帧 has_method + is_card_grid_battle 反射调用链
var _cached_is_card_grid: bool = true
var _cached_combat_started: bool = false
## 跨实例共享的资源缓存
var _res_cache: Dictionary = {}
# v8: 行为 tag 缓存（fast/stealth/antitank 等），setup 时从 archetype cfg 一次性读取
# 供 TargetSelection._get_counter_priority 读取（antitank 覆盖），并驱动 fast/stealth 行为
var _behavior_tags_cached: Array = []
var _is_fast_unit: bool = false
var _is_stealth_unit: bool = false
# v8: stealth 开局减伤计时器（前 4 秒受伤 ×0.6，模拟"潜入到位"）
var _stealth_grace_timer: float = 0.0
const STEALTH_GRACE_DURATION: float = 4.0
const STEALTH_GRACE_DAMAGE_MUL: float = 0.6
# v8: fast 攻速加成倍率（attack_interval ×0.80 = 攻速 +20%）
const FAST_INTERVAL_MULT: float = 0.80
# v8 批次2: 精英词缀系统
const EnemyAffixes = preload("res://data/enemy_affixes.gd")
# 已应用的词缀列表（供 _do_attack 触发机制型效果 + UI 显示）
var _elite_affixes: Array = []
var _elite_spawn_type: String = "normal"

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

var _presentation_card_grid: bool = false
var _hp_status_refresh_accum: float = 0.0   ## v9.x 血条状态图标低频刷新累加器（不 gate 模式，两种战斗都刷新）
var _hpbar_ref: Node = null  ## v9.x（3c）：HpBar 节点引用缓存（原每 0.3s 字符串路径查找）
var _idle_spr: Sprite2D = null  ## v9.x（3d）：待机浮动手写推进用的立绘引用缓存

## v9.x（3c 性能批次）：HpBar 引用缓存——命中免字符串路径查找；
## 未挂载时保持重查（与原行为一致），被释放后自动失效重查。
func _get_hpbar_cached() -> Node:
	if _hpbar_ref == null or not is_instance_valid(_hpbar_ref):
		_hpbar_ref = get_node_or_null("HpBar")
	return _hpbar_ref
var _buff_strip_timer: float = 0.0  ## v8.x buff/改造条周期刷新累加器（与 construct_unit 对齐）
var _buff_strip_signature: String = ""  ## v8.x buff_strip signature 去重（避免无变化时重建）
var _hit_stun_left: float = 0.0
var _card_tween: Tween = null
var _rest_position: Vector2 = Vector2.ZERO
var _card_nudge_tween: Tween = null
var _fire_pulse_tween: Tween = null  ## 开火缩放脉冲（独立于 nudge/recoil，只动 Sprite2D 子节点）
var _card_grid_rest_x: float = NAN  ## 格子战术中卡片的归位 X
## v7.4: 受击视觉反馈（改手写计时动画，与 construct_unit 对齐；原每击 create_tween 2 个 Tween）
## v8.x: flash 已移除（改命中点血溅，单位保持卡图清晰），仅剩 shake 正计时分段插值（参考 damage_number_display._pop_age）
var _hit_shake_t: float = -1.0  # -1=未激活，>=0=激活
const _HIT_SHAKE_DURATION: float = 0.14  # v8.3: 0.12→0.14（4×0.035s）
var _death_fade_tween: Tween = null  ## v6.4: 死亡淡出 Tween
var _is_dying: bool = false  ## v6.4: 死亡中标志，防止 _die 重复触发

func _ready() -> void:
	# 战斗逻辑跟随暂停状态
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# P0 性能优化：缓存战斗模式判定，避免每帧 has_method + is_xxx 反射调用链
	# is_card_grid_battle() 恒为 true（卡牌格子战术是唯一模式），直接缓存 true
	_cached_is_card_grid = true
	if BattleManager != null and "battle_active" in BattleManager:
		_cached_combat_started = bool(BattleManager.battle_active)

func setup(_is_player: bool, p_wave: int, p_archetype_id: String = "basic_infantry") -> void:
	wave_index = p_wave
	archetype_id = p_archetype_id
	_apply_archetype_stats()
	# v6.6(剧情): 二周目难度提升（补剧情.txt L186 敌人属性×1.2）
	# 在 _apply_archetype_stats 设置基础值后、max_hp=hp 前统一应用倍率
	_apply_ng_plus_scaling()
	max_hp = hp
	add_to_group("enemy_units")
	var cs := get_node_or_null("CollisionShape2D")
	if cs:
		cs.disabled = false
	_update_shape()
	_update_hp_bar()

	# 性能优化：插入到空间分区网格
	_register_to_spatial_grid()
	# 无有效 archetype 时不会进入 _apply_visual_from_archetype，须仍关掉场景里遗留的编辑器占位。
	_suppress_stray_editor_visual_nodes()

func _suppress_stray_editor_visual_nodes() -> void:
	# 关闭场景中遗留的编辑器占位节点（原 AnimatedSprite2D2 / PreviewBackground）。
	for p: String in ["AnimatedSprite2D2", "PreviewBackground"]:
		var ci := get_node_or_null(p) as CanvasItem
		if ci != null:
			ci.visible = false

func apply_card_grid_enemy_presentation() -> void:
	_presentation_card_grid = true
	_rest_position = position
	velocity = Vector2.ZERO
	# 注意：Shape(旧Polygon2D占位)/AnimatedSprite2D(已弃用序列帧) 已从场景移除，
	# 用 get_node_or_null 防御性访问，避免场景缺少节点时 "Node not found" 报错。
	var spr: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var poly: Polygon2D = get_node_or_null("Shape") as Polygon2D
	if anim != null:
		anim.visible = false
		anim.sprite_frames = null
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	var card_res: CardResource = CardGridUnitVisuals.resolve_card_for_archetype(archetype_id)
	if card_res == null:
		card_res = CardGridUnitVisuals.synthetic_card_for_archetype(archetype_id, cfg)
	var tex: Texture2D = CardGridUnitVisuals.resolve_battle_icon_texture(card_res, archetype_id, cfg, false)
	var sprite_ok: bool = false
	if spr != null and tex != null and not _texture_exceeds_max_dim(tex, MAX_ENEMY_FRAME_TEX_DIM):
		var ad: float = attack_damage
		var ai: float = maxf(attack_interval, 0.05)
		# v6.3: 统一 power 计算（与玩家 combat_power_from_unit_stats 对齐）
		# 当 stats 可用时用完整三维 DPS，否则回退到简化版
		var pscore: float
		if stats != null:
			# 三维攻击取最大DPS维度，与玩家口径一致
			var dps_l: float = stats.attack_light / ai if stats.attack_light > 0 else 0.0
			var dps_a: float = stats.attack_armor / ai if stats.attack_armor > 0 else 0.0
			var dps_air: float = stats.attack_air / ai if stats.attack_air > 0 else 0.0
			var best_dps: float = maxf(dps_l, maxf(dps_a, dps_air))
			pscore = maxf(50.0, max_hp * 0.28 + best_dps * 2.2 + attack_range * 0.22)
		else:
			pscore = maxf(50.0, max_hp * 0.28 + (ad / ai) * 2.2)
		var rank_id: String = RankRules.get_rank_by_power("corporal", pscore)
		var rl: int = CardGridUnitVisuals.rank_level_from_id(rank_id)
		sprite_ok = CardGridUnitVisuals.apply_battle_unit_presentation(
			self, spr, card_res, tex, false, rl, self
		)
		# v7.x 战场视觉反馈：敌方改造图标条（从 archetype tags 推断）
		CardGridUnitVisuals.sync_mod_strip(self, self, spr)
	if poly != null:
		poly.visible = not sprite_ok
	# v7.x: 敌方格子战启用迷你 HP 条（与设计稿 v9 对齐——HP 条 + HP 数值配套）
	# 默认折叠态（4px），选中时展开（8px）；HP 数值在 HP 条下方独立显示
	var hb := get_node_or_null("HpBar") as CanvasItem
	if hb != null:
		hb.visible = true
		# 敌方 Sprite2D 有 z_index=1（见 enemy_unit.tscn），会盖住 z_index 默认 0 的 HpBar，
		# 导致血条和 HP 数字被立绘遮挡。抬高 HpBar 根节点 z_index 到立绘之上。
		(hb as Node2D).z_index = 10
		# 血条移到头顶：锚定实体顶部上方（与玩家单位对称）
		var top_y: float = CardGridUnitVisuals.entity_top_y(spr) if spr != null else -50.0
		hb.position = Vector2(0.0, top_y - 14.0)
		if hb.has_method("set_side"):
			hb.set_side(false)  # 敌方色（红）
		# v19: 战场等级文字（血条左侧）——相位师派生等级/关卡映射等级
		if hb.has_method("set_level_text"):
			hb.set_level_text(_resolve_display_level_text())
		if hb.has_method("set_folded"):
			hb.set_folded(true)  # 默认折叠，选中时展开（与玩家对称）
	var aura_ring := get_node_or_null("AuraRing") as CanvasItem
	var rank_badge := get_node_or_null("RankBadge") as CanvasItem
	if aura_ring != null:
		aura_ring.visible = false
	if rank_badge != null:
		rank_badge.visible = false


## 格子战术卡面攻击姿态（v9.x 由 AttackPoseAnim 取代——按武器类型分化前冲/后坐/上扬 + 攻击帧）


## 开火缩放脉冲：Sprite2D 子节点 scale 短暂放大再回弹，模拟开火反冲。
## 只动 Sprite2D 子节点 scale，不碰根节点 scale.x/rotation（与 construct_unit 对称）。
func _play_fire_scale_pulse() -> void:
	var spr: Sprite2D = get_node_or_null("Sprite2D")
	if spr == null:
		return
	if _fire_pulse_tween != null and _fire_pulse_tween.is_valid():
		_fire_pulse_tween.kill()
	var base_s: Vector2 = spr.scale
	_fire_pulse_tween = create_tween()
	_fire_pulse_tween.tween_property(spr, "scale", base_s * 1.10, 0.04)
	_fire_pulse_tween.tween_property(spr, "scale", base_s, 0.07)
	# v14: 方向冲撞(敌方朝左)——前倾→后坐→归位,本体参与开火演出
	var wt: int = stats.weapon_type if stats != null else 0
	CardGridUnitVisuals.fire_lunge_sprite(spr, false, wt in [1, 2, 3, 7, 9, 10, 11])


func _play_card_hit_recoil() -> void:
	if not _presentation_card_grid:
		return
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	const RECOIL_MAX_RAD: float = 0.22
	var rest_r: float = 0.0
	position = _rest_position
	rotation = rest_r
	_card_tween = create_tween()
	var peak_r: float = rest_r + RECOIL_MAX_RAD
	_card_tween.tween_property(self, "rotation", peak_r, 0.06)
	_card_tween.tween_property(self, "rotation", rest_r, 0.12)


# v9.x（P2-7范围B）：_apply_phase_law_passives 已随法则系统退役删除——
# 我方蓝槽法则对敌减益（burn_on_hit/anchor_field/static_domain 等）不再存在。

func _apply_archetype_stats() -> void:
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	_cached_archetype_cfg = cfg  # 性能优化：缓存配置
	_visual_scale_archetype_id = archetype_id
	var ctx = EnemyStatResolver.make_default_context(wave_index)
	var r: Dictionary = EnemyStatResolver.resolve_classic_enemy(archetype_id, ctx)
	hp = float(r.get("hp", 80.0))
	attack_damage = float(r.get("attack_damage", 10.0))
	attack_range = float(r.get("attack_range", 100.0))
	attack_interval = float(r.get("attack_interval", 1.0))
	move_speed = float(r.get("move_speed", 0.0))
	defense = float(r.get("defense", 5.0))
	velocity = Vector2.ZERO
	# v6.3: 构建完整 UnitStats，使 _do_attack 经典路径复用三维 AttackCalculator
	# （与相位师产兵的 stats != null 路径统一）
	_build_enemy_unit_stats(r, cfg)
	# v8: 缓存行为 tag 并应用 tag 驱动的数值差异（fast/stealth/antitank）
	_apply_behavior_tags(cfg)
	if cfg.is_empty():
		return
	_base_max_hp = hp
	_base_attack_damage = attack_damage
	_base_move_speed = move_speed
	_base_attack_interval = attack_interval
	_base_stats_ready = true
	_apply_visual_from_archetype(cfg)
	# v7.x(敌方加成来源明细): 把 resolve_classic_enemy 返回的加成明细挂到单位 meta，
	# 供情报面板显示"为什么这么强"。final_* 字段此时记录乘完乘区链的值（不含二周目/律法/词缀），
	# _apply_ng_plus_scaling 会更新 ng_plus；律法减益/精英词缀不计入（属"我方施加"或"词缀系统"）。
	var _breakdown: Dictionary = r.get("bonus_breakdown", {})
	if not _breakdown.is_empty():
		_breakdown["final_hp"] = float(hp)
		_breakdown["final_atk"] = float(attack_damage)
		_breakdown["final_def"] = float(defense)
		set_meta("enemy_bonus_breakdown", _breakdown)


## v8: 激活 archetype tags 驱动的行为差异（死字段→生效）。
## 路径B（纯数值，不解锁槽位吸附，零视觉风险）：
##   fast    → attack_interval ×0.80（攻速 +20%）
##   stealth → 标记，开局 4 秒受伤 ×0.6（_stealth_grace_timer 驱动，_process 递减）
##   antitank → 标记，TargetSelection._get_counter_priority 强制锁定 ARMOR
## 无 tag 的敌人完全不受影响（向后兼容）。
func _apply_behavior_tags(cfg: Dictionary) -> void:
	_behavior_tags_cached = []
	_is_fast_unit = false
	_is_stealth_unit = false
	var tags_var = cfg.get("tags", [])
	if not (tags_var is Array):
		return
	_behavior_tags_cached = tags_var.duplicate()
	# v10(H2): 高价值目标标记写入——target_selection._is_high_value_target 与
	# TAG_COUNTER_RULES 读 target_priority_tag，此前全项目零写入者（sniper 的
	# boss/elite 优先索敌空转，只剩 HP>500 启发分支）。
	if _behavior_tags_cached.has("boss"):
		set_meta("target_priority_tag", "boss")
	elif _behavior_tags_cached.has("elite"):
		set_meta("target_priority_tag", "elite")
	if _behavior_tags_cached.has("fast"):
		_is_fast_unit = true
		# fast：攻速 +20%（interval ×0.80）。同步裸字段、UnitStats 与武器槽 attack_speed。
		# 注意 WeaponResource 用 attack_speed（次/秒）而非 interval，故取倒数倍率 1/0.80=1.25。
		attack_interval = maxf(0.05, attack_interval * FAST_INTERVAL_MULT)
		if stats != null:
			stats.attack_interval = maxf(0.05, float(stats.attack_interval) * FAST_INTERVAL_MULT)
			# 三武器槽 attack_speed 等比放大（_process_attack_timing 优先读 weapon timing）
			var spd_mult: float = 1.0 / FAST_INTERVAL_MULT
			for w in stats.weapon_slots:
				if w != null and w.enabled:
					w.attack_speed = maxf(0.1, float(w.attack_speed) * spd_mult)
	if _behavior_tags_cached.has("stealth"):
		_is_stealth_unit = true
		_stealth_grace_timer = STEALTH_GRACE_DURATION
		# v20.15 真隐身：开局渗透期间不可被单体索敌选中（对侧有侦测源除外；AOE 豁免）。
		# hidden_grace_until 与 CardAbilityManager.is_unit_hidden 口径一致（毫秒）。
		set_meta("hidden_grace_until", Time.get_ticks_msec() + int(STEALTH_GRACE_DURATION * 1000.0))
		# 视觉：半透明（可见但打不到，玩家可感知渗透单位存在）
		modulate = Color(1.0, 1.0, 1.0, 0.45)


## v8: stealth 开局减伤——前 STEALTH_GRACE_DURATION 秒受伤 ×STEALTH_GRACE_DAMAGE_MUL。
## 在 _process 中递减；实际减伤在 take_damage 中读取 _is_stealth_in_grace() 判定。
## v20.15: 渗透隐身到期时清除 hidden 标记并恢复不透明度。
func _update_stealth_grace(delta: float) -> void:
	if not _is_stealth_unit or _stealth_grace_timer <= 0.0:
		return
	_stealth_grace_timer = maxf(0.0, _stealth_grace_timer - delta)
	if _stealth_grace_timer <= 0.0:
		if has_meta("hidden_grace_until"):
			remove_meta("hidden_grace_until")
		modulate = Color.WHITE


func _is_stealth_in_grace() -> bool:
	return _is_stealth_unit and _stealth_grace_timer > 0.0


## v8 批次2: 获取反伤比率（armor_reflect 词缀）。0.0=无反伤。
func _get_armor_reflect_ratio() -> float:
	if stats == null:
		return 0.0
	if "armor_reflect" in stats:
		return clampf(float(stats.armor_reflect), 0.0, 0.60)
	# 兜底：UnitStats 无此字段时读 meta（apply_to_stats 的 set_meta 路径）
	if stats.has_meta("armor_reflect"):
		return clampf(float(stats.get_meta("armor_reflect")), 0.0, 0.60)
	return 0.0


## v8 批次2: 应用精英词缀到本单位。
## 由 battle_spawn_system（经典波次）或 enemy_phase_field_driver（相位师产兵）在 setup 后调用。
## spawn_type: "normal" / "elite" / "boss"——决定 roll 词缀数量与稀有度池。
## 词缀效果分两类：
##   A 数值型（attack/max_hp/speed/dodge/crit/regen）：apply 时改 stats 字段，战斗路径自动读取。
##   B 机制型（kill_repair/chain/splash/shield/reflect）：apply 时改 stats 字段，
##     _do_attack / take_damage 读取字段触发 AffixCombatHandler。
## 注意：本方法应在 setup 完成（stats 就绪）后调用，且需同步裸 hp/max_hp（max_hp 词缀）。
## v7.x：把 stats 关键数值字段同步到裸字段（hp/max_hp/attack_damage/defense）。
## 用于 spawn 后加成函数（loadout tier / phase master bonus / elite affixes）
## 改完 stats 后让裸字段保持一致——take_damage 扣血、_update_hp_bar 血条、
## 死亡判定读裸字段，hp_regen 上限读 stats.max_hp，两套数据不一致会导致
## "面板显示 HP 高 / 实际脆"或"血条与实际血量不符"。
## 保持当前 hp/max_hp 比率，避免满血单位加成后突然不满血。
func _sync_bare_fields_from_stats() -> void:
	if stats == null:
		return
	var ratio: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0) if max_hp > 0.0 else 1.0
	max_hp = maxf(1.0, float(stats.max_hp))
	hp = maxf(1.0, max_hp * ratio)
	attack_damage = maxf(0.1, float(stats.attack_damage))
	if "defense" in stats:
		defense = maxf(0.0, float(stats.defense))
	_update_hp_bar()


func apply_elite_affixes(spawn_type: String) -> void:
	_elite_spawn_type = spawn_type
	# v10(H2): 波次 elite/boss 写高价值目标标记（target_priority_tag 此前全项目零写入者，
	# sniper 的 boss/elite 优先索敌与 TAG_COUNTER_RULES 的 target_tags 匹配全部空转）
	if spawn_type == "boss":
		set_meta("target_priority_tag", "boss")
	elif spawn_type == "elite":
		set_meta("target_priority_tag", "elite")
	if stats == null:
		return
	if spawn_type == "normal":
		return  # 普通怪不 roll
	# v19: 兵种/档位上下文——兵种专属词缀分池 + 独特词缀档位门槛
	# combat_kind 读 stats（resolver 已填）；tier 查统一卡表条目（缴获前缀等查不到回退 0）
	var kind_ctx: int = int(stats.combat_kind)
	var tier_ctx: int = _lookup_archetype_tier(archetype_id)
	var affixes: Array = EnemyAffixes.roll_affixes(spawn_type, null, kind_ctx, tier_ctx)
	if affixes.is_empty():
		return
	_elite_affixes = affixes
	EnemyAffixes.apply_to_stats(stats, affixes)
	# v7.x：无论 roll 到哪个词缀都同步裸字段（之前只在 max_hp 词缀命中时才同步，
	# 导致 tier/phase_master 加成对非 max_hp 词缀的怪完全失效——spawn 后加成只改 stats
	# 不传导到 hp/max_hp/attack_damage 裸字段，血条/伤害结算读到的是未加成值）。
	_sync_bare_fields_from_stats()


## v19: 查敌方卡在统一卡表的档位（词缀独特档门槛用；查不到回退 0）
## archetype_id 可能带 captured_ 前缀或不在 UCT（合成名），get_entry 空字典时自然回退。
func _lookup_archetype_tier(aid: String) -> int:
	if aid.is_empty():
		return 0
	var entry: Dictionary = UnifiedCardTable.get_entry(aid)
	return int(entry.get("tier", 0))


## v8 批次2: 获取本单位的词缀显示信息（供 card_info_panel 显示）。
func get_elite_affixes() -> Array:
	return _elite_affixes

## v19: 战场等级文字来源——优先外部注入 meta（产兵兜底路径），
## 相位师单位用战力派生显示等级（EnemyPhaseMasters.get_display_level_by_id），
## 经典敌兵用关卡映射（ceil(关卡×0.3)，Lv1-30，与 enemy_stat_resolver 同口径）。
## 解析结果缓存到 meta unit_level（悬浮面板等统一读取）。
func _resolve_display_level_text() -> String:
	var lv: int = _resolve_display_level()
	if lv > 0:
		set_meta("unit_level", lv)
		return "Lv%d" % lv
	return ""

func _resolve_display_level() -> int:
	if has_meta("unit_level"):
		return clampi(int(get_meta("unit_level", 1)), 1, 30)
	if archetype_id.begins_with("phase_master_"):
		return EnemyPhaseMasters.get_display_level_by_id(archetype_id)
	if GameManager != null and "current_level" in GameManager:
		return CardGrowthConfig.enemy_level_for_stage(int(GameManager.current_level))
	return 0


func get_elite_spawn_type() -> String:
	return _elite_spawn_type


## v6.6(剧情): 二周目敌人属性×1.2（补剧情.txt 第十二幕 L186）
## 仅对敌方单位生效（_is_player=false 的 enemy_unit），玩家单位不受影响
## 同时更新裸字段和 UnitStats 对象，确保 AttackCalculator 读取一致的数值
func _apply_ng_plus_scaling() -> void:
	# 本方法可能在 setup() 中、节点尚未加入场景树时被调用，
	# 故不能用 get_node_or_null("/root/...")（绝对路径要求节点已在树中）。
	# GameManager 是 autoload 单例，直接用全局标识符访问。
	if GameManager == null or not GameManager.has_method("is_ng_plus_active"):
		return
	if not GameManager.is_ng_plus_active():
		return
	var mult: float = float(GameManager.get_ng_plus_enemy_mult()) if GameManager.has_method("get_ng_plus_enemy_mult") else 1.2
	if mult <= 1.0:
		return
	# 裸字段（战斗中直接读取的属性）
	hp = maxf(1.0, hp * mult)
	attack_damage = maxf(0.1, attack_damage * mult)
	defense = maxf(0.0, defense * mult)
	# UnitStats 对象（AttackCalculator / 词条效果读取的属性）
	if stats != null:
		stats.max_hp = maxf(1.0, float(stats.max_hp) * mult)
		stats.attack_damage = maxf(0.1, float(stats.attack_damage) * mult)
		stats.attack_light = maxf(0.1, float(stats.attack_light) * mult)
		stats.attack_armor = maxf(0.1, float(stats.attack_armor) * mult)
		stats.attack_air = maxf(0.1, float(stats.attack_air) * mult)
		if "defense" in stats:
			stats.defense = maxf(0.0, float(stats.defense) * mult)
	# v7.x(敌方加成来源明细): 二周目叠加后更新明细的 ng_plus 字段与 final 值，
	# 让面板的"总倍率"包含二周目、"最终值"反映乘完二周目后的当前值。
	if has_meta("enemy_bonus_breakdown"):
		var _bd: Dictionary = get_meta("enemy_bonus_breakdown")
		_bd["ng_plus"] = mult
		_bd["final_hp"] = float(hp)
		_bd["final_atk"] = float(attack_damage)
		_bd["final_def"] = float(defense)
		set_meta("enemy_bonus_breakdown", _bd)


## v6.4: 推断敌人 unit_subtype（炮兵/支援/堡垒/防空）
## 基于 combat_kind + archetype tags/weapon_type/attack_range
func _infer_enemy_subtype(combat_kind: int, cfg: Dictionary) -> int:
	# 堡垒：tags 含 fort/bunker，或 combat_kind == FORT
	var tags = cfg.get("tags", [])
	if tags is Array:
		for t in tags:
			if String(t) in ["fort", "bunker", "structure", "static"]:
				return GC.UnitSubType.FORT
	if combat_kind == GC.CombatKind.FORT:
		return GC.UnitSubType.FORT
	# 防空：tags 含 anti_air/aa，或 weapon_type 是防空类
	if tags is Array:
		for t in tags:
			if String(t) in ["anti_air", "aa", "flak", "sam"]:
				return GC.UnitSubType.ANTI_AIR
	# 炮兵：combat_kind == SUPPORT 且 attack_range >= 400（远程间接火力）
	if combat_kind == GC.CombatKind.SUPPORT:
		# v8.7: 对空攻击主导的 SUPPORT 单位是防空特化（zsu23/m6/patriot 等）。
		# 原仅按 range>=400 判火炮，防空炮射程 500px 被误判成 ARTILLERY——
		# 拿到反炮兵而非空域封锁（+25% 对空），与玩家侧子类口径不一致。
		var al_v: float = float(cfg.get("attack_light", 0.0))
		var aa_v: float = float(cfg.get("attack_armor", 0.0))
		var aair_v: float = float(cfg.get("attack_air", 0.0))
		if aair_v > al_v and aair_v > aa_v and aair_v > 0.0:
			return GC.UnitSubType.ANTI_AIR
		var atk_range: float = float(cfg.get("attack_range", attack_range))
		if atk_range >= 400.0:
			return GC.UnitSubType.ARTILLERY
		# 近距离支援（如工兵、医疗）→ SUPPORT
		return GC.UnitSubType.SUPPORT
	return GC.UnitSubType.NONE


## v6.3: 从 resolve_classic_enemy 的结果构建 UnitStats（三维攻防），存到 self.stats
## 这样 _do_attack 的 stats != null 分支自动生效，敌人用三维攻击/防御。
func _build_enemy_unit_stats(r: Dictionary, cfg: Dictionary) -> void:
	var s: UnitStats = UnitStats.new()
	s.card_id = archetype_id
	s.combat_kind = int(r.get("combat_kind", int(cfg.get("combat_kind", 0))))
	# v6.4: 按 combat_kind + archetype 特征推断 unit_subtype，激活差异化修正
	# （炮兵无闪避/堡垒+HP/防空高def_air/支援特殊）
	s.unit_subtype = _infer_enemy_subtype(s.combat_kind, cfg)
	s.max_hp = float(r.get("hp", hp))
	s.attack_range = float(r.get("attack_range", attack_range))
	s.attack_interval = float(r.get("attack_interval", attack_interval))
	s.move_speed = float(r.get("move_speed", move_speed))
	s.defense = float(r.get("defense", defense))
	# 三维攻击
	s.attack_light = float(r.get("attack_light", attack_damage))
	s.attack_armor = float(r.get("attack_armor", 0.0))
	s.attack_air = float(r.get("attack_air", 0.0))
	s.attack_damage = s.attack_light  # 兼容别名
	# 缓存三维基础攻击（律法减益重算时用）
	_cached_enemy_base = {
		"attack_light": s.attack_light,
		"attack_armor": s.attack_armor,
		"attack_air": s.attack_air,
	}
	# v8.1: 三维攻速——优先读三维 interval（防空特化单位对空高频），回退单一 interval 统一
	var ivl_l: float = float(r.get("attack_light_interval", s.attack_interval))
	var ivl_a: float = float(r.get("attack_armor_interval", s.attack_interval))
	var ivl_air: float = float(r.get("attack_air_interval", s.attack_interval))
	s.attack_light_speed = (1.0 / ivl_l) if ivl_l > 0.0 else 1.0
	s.attack_armor_speed = (1.0 / ivl_a) if ivl_a > 0.0 else 1.0
	s.attack_air_speed = (1.0 / ivl_air) if ivl_air > 0.0 else 1.0
	s.attack_light_windup = 0.2
	s.attack_armor_windup = 0.2
	s.attack_air_windup = 0.2
	s.attack_light_active = 0.1
	s.attack_armor_active = 0.1
	s.attack_air_active = 0.1
	# 三维防御
	s.defense_light = float(r.get("defense_light", defense))
	s.defense_armor = float(r.get("defense_armor", defense))
	s.defense_air = float(r.get("defense_air", defense))
	# 武器类型（用于射程衰减/弹道路由）
	s.weapon_type = int(r.get("weapon_type", int(cfg.get("weapon_type", 0))))
	# v15: legacy 签名弹道值（>3：SNIPER/LASER/OMEGA/RAIL）同步记录，
	# 供子弹 VFX 回退链与信息面板武器型号查询使用（与 UCT _entry_to_card 同口径）。
	if s.weapon_type > 3:
		s.legacy_weapon_type = s.weapon_type
	s.weapon_label = String(r.get("weapon_label", String(cfg.get("weapon_label", ""))))
	# 初始化武器槽位（让 AttackCalculator.get_weapon_for_target 生效）
	s.weapon_slots.clear()
	_ensure_enemy_weapon_slots(s)
	# v8.5: 注入兵种专属机制（与 construct_unit 走 build_stats_from_card 对齐）。
	# 修复经典波次敌方跳过此函数导致堡垒 damage_reduction=0、侦察无闪避、防空无对空加成的 bug。
	# 纯数值字段写入（dodge_chance/damage_reduction/三维防御/HP×1.15 等）+ 被动 meta（is_recon_unit 等）。
	# v8.5 主动技能 tick（核武/护盾投射）不在此处——敌方无对应 tick 代码读取这些 meta，沿用现状。
	UnitStatsTable.apply_combat_kind_modifiers(s)
	# 关键：apply_combat_kind_modifiers 会按兵种放大 max_hp（如堡垒×1.15），
	# 必须同步回节点 hp 字段，否则 setup() 的 max_hp = hp 会用未放大的 hp 覆盖 stats.max_hp。
	hp = s.max_hp
	stats = s
	# v9 perf：stats 引用缓存（module_effect_handler._get_unit_stats 的 meta 快路径）
	set_meta("_meh_stats_cache", s)
	# v7.1: stats 就绪后判定并创建堡垒防护光环
	_ensure_fort_shield_aura()


# ═════════════════════════════════════════════════════════════════
#  v7.1: 堡垒类防护光环（纯视觉）— 与 construct_unit 对称实现
# ═════════════════════════════════════════════════════════════════

## 判定并创建防护光环。堡垒类(combat_kind==FORT)才挂。
func _ensure_fort_shield_aura() -> void:
	_is_fort_aura_unit = false
	if stats == null:
		return
	if stats.combat_kind != GC.CombatKind.FORT:
		return
	_is_fort_aura_unit = true
	if _fort_shield_aura != null and is_instance_valid(_fort_shield_aura):
		_fort_aura_hit_boost = 0.0
		return
	var aura: Node2D = Node2D.new()
	aura.set_script(FortShieldAuraScript)
	aura.name = "FortShieldAura"
	aura.z_index = -1
	add_child(aura)
	_fort_shield_aura = aura

## 每帧驱动光环呼吸 + 衰减受击强化。非堡垒单位直接返回（零开销）。
## v7.4: 降频 redraw（对齐 construct_unit：正常态每4帧，承压闪光每帧）+ is_player meta 仅设一次
func _update_fort_shield_aura(delta: float) -> void:
	if not _is_fort_aura_unit:
		return
	if _fort_shield_aura == null or not is_instance_valid(_fort_shield_aura):
		return
	if _fort_aura_hit_boost > 0.0:
		_fort_aura_hit_boost = maxf(0.0, _fort_aura_hit_boost - delta * 2.0)
	# v7.4: is_player 恒为 false，仅首次设置（原每帧 set_meta）
	if not _fort_aura_meta_set:
		_fort_shield_aura.set_meta(&"is_player", false)  # 敌方光环用红色系
		_fort_aura_meta_set = true
	_fort_shield_aura.set_meta(&"hit_boost", _fort_aura_hit_boost)
	# v7.4: 承压闪光时每帧 redraw，正常态每4帧一次（呼吸动画降频）
	if _fort_aura_hit_boost > 0.0 or (_aura_low_freq_frame % 4) == 0:
		_fort_shield_aura.queue_redraw()
	_aura_low_freq_frame += 1


## v6.3: 为敌人 UnitStats 初始化3个武器槽位（轻装/装甲/对空），复用三维攻击值
## v8.1: 槽位 weapon_type 不再直接复制单位枚举（SUPPORT=3 会与 legacy ROCKET=3 冲突），
##        改用与玩家卡一致的按槽位分配逻辑（_default_enemy_slot_weapon_type）。
func _ensure_enemy_weapon_slots(s: UnitStats) -> void:
	var GC2 = preload("res://resources/game_constants.gd")
	# 槽位0=对轻装, 槽位1=对装甲, 槽位2=对空
	var slot_configs: Array = [
		{"target_kind": GC2.CombatKind.LIGHT, "dmg": s.attack_light, "spd": s.attack_light_speed},
		{"target_kind": GC2.CombatKind.ARMOR, "dmg": s.attack_armor, "spd": s.attack_armor_speed},
		{"target_kind": GC2.CombatKind.AIR, "dmg": s.attack_air, "spd": s.attack_air_speed},
	]
	for i in range(slot_configs.size()):
		var cfg_w: Dictionary = slot_configs[i]
		var w = WeaponResource.new()
		w.enabled = float(cfg_w.dmg) > 0.0
		w.damage = float(cfg_w.dmg)
		w.attack_speed = float(cfg_w.spd)
		w.range_value = maxi(1, int(round(s.attack_range / 100.0)))
		w.weapon_type = _default_enemy_slot_weapon_type(i, s.weapon_type, s.combat_kind, GC2)
		# v9.x: 武器名→弹道覆盖统一走 CardResource 共享解析器（与玩家侧同口径，关键词表不再两处维护）：
		# ① v15 精确表命中签名武器专属弹道——修复敌方 UCT 特殊 weapon_type(6/10/11) 在槽位层被
		#    降级的配置错误：攻城电磁炮→RAIL(11) 磁轨穿透 / 重型等离子加农炮→OMEGA(10) 径向放电 /
		#    磁轨狙击炮→SNIPER(6) 光束（此前统一落进光束关键词→SNIPER，RAIL/OMEGA 签名特效丢失）；
		# ② 光束关键词 → SNIPER(6)（v9.x 扩展到曲射槽位，敌方曲射单位的光束武器与玩家一致）；
		# ③ 曲射弹药形态（仅 INDIRECT 单位：机枪/近防炮点防直射、火箭低平弧、导弹中弧）。
		if (w.weapon_type == GC2.WeaponType.DIRECT or w.weapon_type == GC2.WeaponType.INDIRECT) \
				and not str(s.weapon_label).is_empty():
			var _traj: int = CardResource.trajectory_override_for_weapon_name(str(s.weapon_label), s.weapon_type)
			if _traj >= 0:
				w.weapon_type = _traj
		w.windup = 0.2
		w.active = 0.1
		w.display_name = s.weapon_label
		s.weapon_slots.append(w)

## v9.5: 按槽位分配敌方武器弹道类型（与玩家卡 _default_weapon_type_for_slot 对齐）。
## v9.5 修复：原函数直接比较 unit_weapon_type == GC2.WeaponType.INDIRECT(1)，
## 但 waves 敌方的 stats.weapon_type 来自 resolver 透传——UCT 层是新枚举(0-3)、
## 非 UCT 原型是 legacy(0-11)。legacy RIFLE(1) 会被误判为曲射、legacy ROCKET(3)
## 匹配不上 INDIRECT(1) 被当直射。现引入 combat_kind 消歧义：
##   - combat_kind==AIR → 三槽全 AERIAL(2)（空射弹道）
##   - legacy 3/7/9/11 或 新枚举 INDIRECT(1)+ck=SUPPORT → 三槽全 INDIRECT(1)（曲射弹道）
##   - 新枚举 AERIAL(2) 非航空单位 → 兜底仍走 AERIAL(2)
##   - 其余 → 直射槽位：轻装 DIRECT(0)、装甲 DIRECT(0)、对空 MISSILE(9)
static func _default_enemy_slot_weapon_type(slot_idx: int, unit_weapon_type: int, combat_kind: int, GC2) -> int:
	# 航空单位 → 全槽空射弹道
	if combat_kind == GC2.CombatKind.AIR:
		return GC2.WeaponType.AERIAL
	# 曲射：legacy 3(ROCKET)/7(FLAK)/9(MISSILE)/11(RAIL) → 全槽曲射
	if unit_weapon_type == 3 or unit_weapon_type == 7 or unit_weapon_type == 9 or unit_weapon_type == 11:
		return GC2.WeaponType.INDIRECT
	# 曲射：UCT 新枚举 INDIRECT(1) + combat_kind=SUPPORT（炮兵）→ 全槽曲射
	if unit_weapon_type == GC2.WeaponType.INDIRECT and combat_kind == GC2.CombatKind.SUPPORT:
		return GC2.WeaponType.INDIRECT
	# 空射：新枚举 AERIAL(2) 非航空单位兜底（数据一致性）
	if unit_weapon_type == GC2.WeaponType.AERIAL:
		return GC2.WeaponType.AERIAL
	# 直射：legacy 0/1/2/4/5/6/8/10 和 新枚举 0(DIRECT)/3(SUPPORT)
	match slot_idx:
		0:
			return GC2.WeaponType.DIRECT  # 对轻装：直射曳光
		1:
			return GC2.WeaponType.DIRECT  # v9.4: 对装甲改直射（原 SNIPER(6) 光束——满屏贯穿长线）。真光束武器由武器名覆盖保留。
		2:
			return 9  # MISSILE：对空导弹
		_:
			return GC2.WeaponType.DIRECT

func _apply_visual_from_archetype(cfg: Dictionary) -> void:
	_suppress_stray_editor_visual_nodes()
	var poly: Polygon2D = get_node_or_null("Shape") as Polygon2D
	var spr: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null:
		return
	if anim != null:
		anim.visible = false
		anim.sprite_frames = null
		anim.position = Vector2.ZERO
	spr.position = Vector2.ZERO
	spr.texture = null
	spr.visible = false

	var template_id: String = ""
	var sprite_path: String = String(cfg.get("sprite_path", ""))
	var sprite_frames_path: String = String(cfg.get("sprite_frames_path", ""))
	if sprite_path.is_empty() and sprite_frames_path.is_empty():
		template_id = EnemyArchetypes.get_generated_enemy_visual_template_id(archetype_id)

	var merged_cfg: Dictionary = cfg.duplicate(true)
	if not template_id.is_empty():
		var template_cfg: Dictionary = EnemyArchetypes.get_config(template_id)
		for k in ["sprite_path", "card_icon_path"]:
			if String(merged_cfg.get(k, "")).is_empty() and template_cfg.has(k):
				merged_cfg[k] = template_cfg[k]

	var lookup_id: String = archetype_id if template_id.is_empty() else template_id
	_visual_scale_archetype_id = lookup_id

	var icon_path: String = EnemyArchetypes.resolve_card_icon_texture_path(archetype_id, merged_cfg, lookup_id)
	if not icon_path.is_empty() and _sprite_resource_path_suspicious(icon_path):
		push_warning("[EnemyUnit] 可疑的敌人卡图路径，已忽略: %s (%s)" % [archetype_id, icon_path])
		icon_path = ""

	var sprite_ok: bool = false
	if not icon_path.is_empty():
		var tex: Texture2D = _cached_load(icon_path) as Texture2D
		if tex != null:
			if _texture_exceeds_max_dim(tex, MAX_ENEMY_FRAME_TEX_DIM):
				push_warning(
					"[EnemyUnit] Archetype %s 卡图/静态贴图过大 (%dx%d)，回退几何占位"
					% [archetype_id, tex.get_width(), tex.get_height()]
				)
			else:
				spr.texture = tex
				spr.visible = true
				spr.offset = Vector2.ZERO
				sprite_ok = true

	if poly != null:
		poly.visible = not sprite_ok
	_finalize_enemy_sprite_transforms(sprite_ok)


func _finalize_enemy_sprite_transforms(sprite_ok: bool) -> void:
	if not sprite_ok:
		return
	var spr: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	# 格子战由 apply_card_grid_enemy_presentation 接管视觉，此处无需传统朝向/时代着色

func _update_shape() -> void:
	var poly: Polygon2D = get_node_or_null("Shape") as Polygon2D
	if poly == null:
		return
	# 敌方：小红圆 → 用多边形近似
	var s = 20.0
	var arr: PackedVector2Array = []
	for i in range(6):
		var a = TAU * i / 6.0
		arr.append(Vector2(cos(a)*s, sin(a)*s))
	poly.polygon = arr
	poly.color = Color(0.85, 0.2, 0.2)


func _enemy_fire_range_for_motion() -> float:
	var r: float = attack_range
	if _cached_is_card_grid:
		if _cached_combat_started:
			r *= CombatTargeting.CARD_GRID_RANGE_MULT
	return r


## 索敌半径：格子战术双方固定两端时，2.6*attack_range 常够不到我方，须单独拉大
func _enemy_acquisition_range() -> float:
	var r: float = _enemy_fire_range_for_motion()
	if _presentation_card_grid:
		return CombatTargeting.card_grid_enemy_acquisition_range(attack_range, true)
	return r


func _effective_fire_range() -> float:
	var rng: float = _enemy_fire_range_for_motion()
	if target != null and is_instance_valid(target) and CombatTargeting.is_phase_field_node(target):
		if not CombatTargeting.has_alive_player_units(BattleManager):
			return maxf(rng, _enemy_acquisition_range() * 1.5)
	return rng


func _physics_process(delta: float) -> void:
	# 安全检查：确保节点在场景树中
	if not is_inside_tree():
		return
	var tree := get_tree()
	var paused := tree.paused if tree else true
	if paused:
		return
	# v7.x: 部署虚影期间不移动/不索敌/不开火（可被攻击），实体化后才投入战斗
	if is_deploy_ghost:
		_update_enemy_deploy_ghost(delta)
		# v9.x（3d 复查）：虚影期同样推进待机浮动——原 Tween 实现不依赖
		# _physics_process（虚影也浮动），手写化后在此补推保持视觉等价
		if _idle_spr == null or not is_instance_valid(_idle_spr):
			_idle_spr = get_node_or_null("Sprite2D") as Sprite2D
		if _idle_spr != null:
			CardGridUnitVisuals.advance_idle_motion(_idle_spr, delta)
		return
	if _hit_stun_left > 0.0:
		_hit_stun_left -= delta
	# v8.6: 接入 ModuleEffectHandler.on_tick（与玩家单位对齐）。
	# 激活：hp_regen（替代下方手写段，避免双倍回血）、堡垒阵地光环 fort_shelter_aura 写入、
	# 雷场伤害、相位护盾、chem/burn/nano dot tick、怒气过期、区域光环。
	# 修复：敌方堡垒此前不 tick → fort_shelter_aura 双失效（不写入+不读取）。
	if stats != null and hp > 0.0:
		ModuleEffectHandler.on_tick(self, delta)
		# v10(H1): 势力 on_hit_debuff 过期恢复——此前仅玩家单位 tick，敌方中了 debuff 永不过期
		FactionSkillEffectHandler.process_debuff_expirations(self, delta)
	# v8: stealth 开局减伤计时器递减
	_update_stealth_grace(delta)
	# 性能优化：不再每帧更新 HP 条，改为在 HP 变化时更新
	# 性能优化：减少目标查找频率
	# v10(C1) 修复：同 construct_unit——清零移入触发分支内；无目标快速重试节流。
	# v9 perf：无目标重试 20Hz → 5Hz——敌侧索敌半径大（最小 1600px），
	# 无目标时全场都在探测，20Hz 重试是波次刷出/清场瞬间的同步尖峰源头；
	# 降频后目标出现最多晚 0.2s 锁定，行为无感。
	_target_find_timer += delta
	var should_find_target := false
	if target == null or not is_instance_valid(target):
		if _target_find_timer >= 0.2:
			should_find_target = true
			_target_find_timer = 0.0
	elif _target_find_timer >= _get_target_find_interval():
		should_find_target = true
		_target_find_timer = 0.0

	if should_find_target:
		_find_target(delta)
	# 格子战术：敌方单位固守当前格，不向己方推进（与卡面表现一致）
	if _cached_is_card_grid:
		velocity = Vector2.ZERO
	else:
		# 有目标且在攻击范围内则停下相互攻击，否则继续前进
		if target != null and is_instance_valid(target):
			var d: float = global_position.distance_to(target.global_position)
			if d <= _enemy_fire_range_for_motion():
				velocity = Vector2.ZERO
			else:
				velocity = Vector2(-move_speed, 0.0)
		else:
			velocity = Vector2(-move_speed, 0.0)
	if _hit_stun_left <= 0.0:
		_process_attack_timing(delta)
	move_and_slide()
	_clamp_inside_battlefield()
	# v7.1: 堡垒防护光环呼吸动画（仅堡垒类单位）
	_update_fort_shield_aura(delta)
	# v7.4: 受击闪白/抖动手写动画推进（与 construct_unit 对齐）
	_update_hit_animations(delta)
	# v9.x（3d）：待机浮动手写推进（原常驻循环 Tween 改 meta 参数，搭受击动画便车）
	if _idle_spr == null or not is_instance_valid(_idle_spr):
		_idle_spr = get_node_or_null("Sprite2D") as Sprite2D
	if _idle_spr != null:
		CardGridUnitVisuals.advance_idle_motion(_idle_spr, delta)
	# v8.x: buff/改造条周期刷新（与 construct_unit 对齐，敌方受光环时卡底图标才更新）
	if _cached_is_card_grid:
		_buff_strip_timer += delta
		if _buff_strip_timer >= 0.25:
			_buff_strip_timer = 0.0
			_update_card_grid_buff_strip()
	# v9.x 血条上方状态图标（buff/debuff）：不 gate 模式，两种战斗都刷新（与 construct_unit 对齐）
	_hp_status_refresh_accum += delta
	if _hp_status_refresh_accum >= 0.3:
		_hp_status_refresh_accum = 0.0
		var _hpbar := _get_hpbar_cached()
		if _hpbar != null and _hpbar.has_method("refresh_status_icons"):
			_hpbar.refresh_status_icons()
	# P2 性能优化：静止单位跳过空间网格更新（格子战敌人 velocity=0，原每帧无谓 update）
	if velocity != Vector2.ZERO:
		_update_in_spatial_grid()

func _get_target_find_interval() -> float:
	# v6.6: 仅在单位数档位变化时重新计算，避免每帧 has_method 反射
	var n: int = 0
	if BattleManager and BattleManager.has_method("get_enemy_unit_count"):
		n = BattleManager.get_enemy_unit_count()
	if n == _cached_interval_unit_count and _cached_target_find_interval >= 0.0:
		return _cached_target_find_interval
	_cached_interval_unit_count = n
	if n > 55:
		_cached_target_find_interval = 0.55
	elif n > 35:
		_cached_target_find_interval = 0.42
	else:
		_cached_target_find_interval = TARGET_FIND_INTERVAL
	return _cached_target_find_interval

func _should_retain_current_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if CombatTargeting.should_drop_phase_field_target(target, false, BattleManager):
		return false
	if CombatTargeting.is_phase_field_node(target):
		return not CombatTargeting.has_alive_player_units(BattleManager)
	# v20.15: 目标进入真隐身且敌方无侦测源 → 放弃锁定（重选可见目标）
	if CardAbilityManager.is_unit_hidden(target) and not CardAbilityManager.side_has_detection(false):
		return false
	# v10(L3): 平方比较（避免每周期 sqrt）
	var acq: float = _enemy_acquisition_range()
	return global_position.distance_squared_to(target.global_position) <= acq * acq


func _find_target(_delta: float) -> void:
	var acq: float = _enemy_acquisition_range()
	if _should_retain_current_target():
		return
	target = null

	# v7.x: 取武器类型用于索敌分流（与 _do_attack 的取值口径一致）
	var wt: int = _get_weapon_type_for_targeting()

	# 直射单位：优先空间分区（O(1) 最近目标，与 select_target_direct 结果等价，零行为变化）
	# 曲射/空射单位：走差异化索敌（迫击炮打克制 / 防空打空中 / 导弹按克制）
	if not GC.is_indirect_weapon_type(wt):
		# v8: antitank 单位优先打装甲/堡垒类目标（无视距离最近逻辑）
		# 命中则锁定；未命中回退到常规直射索敌（向后兼容）
		if _behavior_tags_cached.has("antitank"):
			var at_target: Node2D = _pick_antitank_priority_target(acq)
			if at_target != null:
				target = at_target
				return
		# 性能优化：优先使用空间分区系统
		if BattleManager and BattleManager.spatial_grid:
			var spatial_grid = BattleManager.spatial_grid
			if spatial_grid:
				# 使用空间网格查询最近目标（O(1)复杂度）
				var nearest_target = spatial_grid.query_nearest_target(
					global_position,
					false,  # 敌方单位
					acq
				)
				# v9.2: 分行索敌——同行优先，最近目标不同行时尝试找同行最近；无同行则接受原目标（跨行回退）
				if nearest_target != null and not CardGridBattleLayout.units_in_same_row(self, nearest_target):
					var same_row_t: Node2D = _query_nearest_same_row_player(spatial_grid, acq)
					if same_row_t != null:
						nearest_target = same_row_t
				# v20.15: 真隐身过滤——最近目标隐身且敌方无侦测源时放弃，落到下方传统扫描重选
				if nearest_target != null and not CardAbilityManager.is_unit_targetable(nearest_target, self):
					nearest_target = null
				if nearest_target != null:
					target = nearest_target
					return

		# 回退到传统方法（如果空间网格不可用）
		var tree = get_tree()
		if tree == null:
			return

		# 性能优化：使用距离平方比较，避免昂贵的平方根计算
		var attack_range_sq := acq * acq
		var gr: Array = BattleManager.get_cached_nodes_in_group("player_units") if BattleManager else get_tree().get_nodes_in_group("player_units")
		var found_alive: bool = false
		# v9.2: 分行索敌——两遍扫描：先找同行射程内目标，无则跨行（避免单位空转）
		# v10(H8): fallback 与 spatial_grid 路径口径对齐——取"最近"而非"组顺序第一个"
		# （原两套规则使同单位的目标选择依赖网格可用性）
		var same_row_hit: Node2D = null
		var same_row_best_d2: float = INF
		var any_row_hit: Node2D = null
		var any_row_best_d2: float = INF
		for n in gr:
			if not CombatTargeting.is_attackable_combat_unit(n):
				continue
			var n2d: Node2D = n as Node2D
			if n2d == null:
				continue
			found_alive = true
			# v20.15: 真隐身过滤（敌方无侦测源时不可选中；仍计入 found_alive——
			# 隐身单位在场不算"场上无单位"，不触发转打相位场）
			if not CardAbilityManager.is_unit_targetable(n2d, self):
				continue
			var dist_sq := global_position.distance_squared_to(n2d.global_position)
			if dist_sq > attack_range_sq:
				continue
			if dist_sq < any_row_best_d2:
				any_row_best_d2 = dist_sq
				any_row_hit = n2d
			if CardGridBattleLayout.units_in_same_row(self, n2d) and dist_sq < same_row_best_d2:
				same_row_best_d2 = dist_sq
				same_row_hit = n2d
		if same_row_hit != null:
			target = same_row_hit
			return
		if any_row_hit != null:
			target = any_row_hit
			return

		# 我方场上无单位时，攻击我方相位场
		if not found_alive:
			var phase_field: Node2D = CombatTargeting.find_opponent_phase_field(
				global_position, false, BattleManager, -1.0
			)
			if phase_field != null:
				target = phase_field
				return
		return

	# —— 曲射/空射单位：差异化索敌 ——
	var candidates: Array = _collect_player_candidates(acq)
	if not candidates.is_empty():
		# v8: stealth 单位优先打指挥/光环单位（模拟"渗透到关键目标"）
		# 复用 ConstructUnitAI 的 platform_type 判定口径（COMMAND=12, AURA=[3,4,5,8,9,10,12]）
		if _is_stealth_unit:
			var priority_target: Node2D = _pick_stealth_priority_target(candidates)
			if priority_target != null:
				target = priority_target
				return
		var mapped_wt: int = GC.legacy_weapon_to_new_weapon_type(wt, _is_aircraft_unit())
		var selected: Node2D = TargetSelection.select_target(self, candidates, mapped_wt)
		if selected != null:
			target = selected
			return

	# 射程内无可攻击的我方单位：若场上完全无我方单位，攻击我方相位场
	var has_alive_player: bool = false
	var gr2: Array = BattleManager.get_cached_nodes_in_group("player_units") if BattleManager else []
	for n in gr2:
		if CombatTargeting.is_attackable_combat_unit(n):
			has_alive_player = true
			break
	if not has_alive_player:
		var phase_field: Node2D = CombatTargeting.find_opponent_phase_field(
			global_position, false, BattleManager, -1.0
		)
		if phase_field != null:
			target = phase_field
			return


## v7.x: 索敌用的武器类型（与 _do_attack 口径一致：stats.weapon_type > cfg.weapon_type > DIRECT）
## 注意 _cached_weapon_type 在目标变化时才更新，索敌发生更早，故独立取值而非读缓存。
func _get_weapon_type_for_targeting() -> int:
	if stats != null:
		return stats.weapon_type
	var cfg: Dictionary = _cached_archetype_cfg
	return int(cfg.get("weapon_type", GC.WeaponType.DIRECT))


## v7.x: 收集射程内可攻击的我方单位候选（曲射/空射索敌用）
## v9.x: 曲射/空射全场索敌——不做同行收敛（直射才有跨行减伤，见 CardGridBattleLayout.cross_row_direct_multiplier）
func _collect_player_candidates(acq: float) -> Array:
	var result: Array = []
	var attack_range_sq := acq * acq
	var gr: Array = BattleManager.get_cached_nodes_in_group("player_units") if BattleManager else get_tree().get_nodes_in_group("player_units")
	for n in gr:
		if not CombatTargeting.is_attackable_combat_unit(n):
			continue
		var n2d: Node2D = n as Node2D
		# v20.15: 真隐身过滤（敌方无侦测源时不可选中）——覆盖曲射/空射/渗透优先整条链
		if not CardAbilityManager.is_unit_targetable(n2d, self):
			continue
		var dist_sq: float = global_position.distance_squared_to(n2d.global_position)
		if dist_sq <= attack_range_sq:
			result.append(n2d)
	return result


## v9.2: spatial_grid 行过滤辅助——敌方直射索敌时，在射程内找同行最近的玩家单位。
## 复用 spatial_grid.query_enemies 拿半径内所有玩家方单位（敌方视角 is_player=false 查玩家），
## 按同行过滤后取最近；无同行返回 null。
func _query_nearest_same_row_player(spatial_grid: Node, max_range: float) -> Node2D:
	# query_enemies(position, radius, is_player) 中 is_player 是"中心方是否为玩家"，
	# 敌方单位查玩家方目标时 is_player=false（敌方不是玩家），返回玩家方单位。
	var players: Array = spatial_grid.query_enemies(global_position, max_range, false)
	if players.is_empty():
		return null
	var best: Node2D = null
	var best_d2: float = INF
	for p in players:
		if p == null or not is_instance_valid(p) or not (p is Node2D):
			continue
		if not CardGridBattleLayout.units_in_same_row(self, p):
			continue
		var d2: float = global_position.distance_squared_to((p as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = p
	return best


## v8: stealth 单位优先级索敌——优先打指挥单位(platform_type==12)，其次光环单位。
## 与 ConstructUnitAI._scan_slot_targets 的 L1/L2 口径对齐（AURA=[3,4,5,8,9,10,12]）。
## 命中则返回最近的高价值目标；未命中返回 null（回退到常规克制索敌）。
const _STEALTH_AURA_PLATFORM_TYPES := [3, 4, 5, 8, 9, 10, 12]
func _pick_stealth_priority_target(candidates: Array) -> Node2D:
	var origin := global_position
	# L1 指挥单位
	var commanders: Array = []
	# L2 光环单位（含指挥）
	var aura_units: Array = []
	for n in candidates:
		if n == null or not is_instance_valid(n):
			continue
		var s: UnitStats = n.get("stats") as UnitStats
		if s == null:
			continue
		# v20.x 口径守卫：我方单位 stats.platform_type 为 CombatKind(0-4)，与 legacy
		# 指挥/光环平台值撞值（12=COMMAND / 3=FORTRESS / 4=RADAR）——我方候选不做
		# legacy 高价值分类（保持 v7 以来现行为；我方指挥/光环单位另有体系驱动）。
		if bool(n.get("is_player")):
			continue
		var pt: int = int(s.platform_type)
		if pt == 12:
			commanders.append(n)
		if pt in _STEALTH_AURA_PLATFORM_TYPES:
			aura_units.append(n)
	if not commanders.is_empty():
		return _nearest_node(origin, commanders)
	if not aura_units.is_empty():
		return _nearest_node(origin, aura_units)
	return null


## v8: 候选列表中距离最近的有效单位（单遍扫描，distance_squared_to）
func _nearest_node(origin: Vector2, candidates: Array) -> Node2D:
	var best: Node2D = null
	var best_d2: float = INF
	for c in candidates:
		if c == null or not is_instance_valid(c):
			continue
		var d2: float = origin.distance_squared_to((c as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = c
	return best


## v8: antitank 单位优先索敌——射程内优先打 ARMOR/FORT 类目标（反坦克语义）。
## 命中则返回最近的装甲类目标；射程内无装甲类时返回 null（回退常规直射）。
func _pick_antitank_priority_target(acq: float) -> Node2D:
	var attack_range_sq := acq * acq
	var origin := global_position
	var gr: Array = BattleManager.get_cached_nodes_in_group("player_units") if BattleManager else get_tree().get_nodes_in_group("player_units")
	var armor_targets: Array = []
	for n in gr:
		if not CombatTargeting.is_attackable_combat_unit(n):
			continue
		var s: UnitStats = n.get("stats") as UnitStats
		if s == null:
			continue
		# ARMOR=1, FORT=4（FORT 在攻防维度归 ARMOR，反坦克武器同样克制）
		if s.combat_kind == GC.CombatKind.ARMOR or s.combat_kind == GC.CombatKind.FORT:
			var dist_sq := origin.distance_squared_to((n as Node2D).global_position)
			if dist_sq <= attack_range_sq:
				armor_targets.append(n)
	if not armor_targets.is_empty():
		return _nearest_node(origin, armor_targets)
	return null


## v7.x: 判定空中单位（索敌映射 AERIAL 用）
## 优先 stats.combat_kind==AIR；无 stats 时回退 archetype cfg tags
func _is_aircraft_unit() -> bool:
	if stats != null and stats.combat_kind == GC.CombatKind.AIR:
		return true
	var cfg: Dictionary = _cached_archetype_cfg
	var tags: Array = cfg.get("tags", [])
	return tags.has("aircraft") or tags.has("air")

## v5.0 攻速分离: 三阶段攻击状态机
## idle(0) → windup(1) → active(2,发射) → cooldown(3) → idle(0)
func _process_attack_timing(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_attack_phase = 0
		_attack_phase_timer = 0.0
		return
	# v10(C4/H1): 攻速类 debuff 统一 delta 通道——ECM/EMP/势力攻速/周期技能攻速惩罚/减速光环。
	# 与玩家侧同源（ConstructUnitAI.get_attack_delta_scale，秒制时间戳 + 过期顺带清理），
	# 替换原硬编码 0.75（boss 削弱 30% 此前被硬编码吞成 25%）。
	var _atk_delta_mult: float = ConstructUnitAI.get_attack_delta_scale(self)
	if _atk_delta_mult < 1.0:
		delta = delta * _atk_delta_mult
	# 获取攻速参数：优先使用缓存（仅目标变化时重算）
	var timing: Dictionary
	var fire_range: float
	var wt: int
	# v10(M5): 缓存失效条件扩展——目标变化 或 当前武器攻速变化（攻速类效果改写
	# weapon.attack_speed 后原缓存永不重算）。武器查询是索引级开销，不进反射。
	var _timing_stale: bool = target != _cached_target_ref
	if not _timing_stale and stats != null and _cached_timing.has("speed"):
		var _ts_chk = target.get("stats") as UnitStats
		var _tk_chk: int = _ts_chk.combat_kind if _ts_chk != null else 0
		var _w_chk: WeaponResource = AttackCalculator.get_weapon_for_target(stats, _tk_chk)
		if _w_chk != null and _w_chk.enabled \
				and absf(float(_cached_timing.get("speed", 1.0)) - float(_w_chk.attack_speed)) > 0.0001:
			_timing_stale = true
	if _timing_stale:
		_cached_target_ref = target
		if stats != null:
			var target_stats = target.get("stats") as UnitStats
			var target_kind: int = target_stats.combat_kind if target_stats != null else 0
			var weapon = AttackCalculator.get_weapon_for_target(stats, target_kind)
			if weapon and weapon.enabled:
				_cached_timing = AttackCalculator.get_weapon_attack_timing(weapon)
				_cached_fire_range = AttackCalculator.get_weapon_range(weapon)
				_cached_weapon_type = weapon.weapon_type
			else:
				_cached_timing = AttackCalculator.get_attack_timing(stats, target_kind)
				_cached_fire_range = stats.attack_range
				_cached_weapon_type = stats.weapon_type
		else:
			var cfg: Dictionary = _cached_archetype_cfg
			_cached_weapon_type = int(cfg.get("weapon_type", GC.WeaponType.DIRECT))
			_cached_timing = {"cycle": attack_interval, "windup": attack_interval * 0.2, "active": 0.1, "cooldown": attack_interval * 0.7, "speed": 1.0 / maxf(0.001, attack_interval)}
			_cached_fire_range = attack_range
	timing = _cached_timing
	fire_range = _cached_fire_range
	wt = _cached_weapon_type
	# v6.4 修复：格子战开战时射程×2.6（与索敌判定一致）
	# P0 性能优化：用缓存字段替代 has_method + is_xxx 反射链
	var _is_card_grid_combat: bool = _cached_is_card_grid and _cached_combat_started
	if _is_card_grid_combat:
		fire_range *= CombatTargeting.CARD_GRID_RANGE_MULT

	var dist: float = global_position.distance_to(target.global_position)
	# 格子战：超射程不拦截（伤害由 calculate_damage_with_weapon 的 range_falloff 保底 30%）
	# 传统战场：直射超射程仍重置 IDLE
	if not _is_card_grid_combat and dist > fire_range and wt == GC.WeaponType.DIRECT:
		_attack_phase = 0
		_attack_phase_timer = 0.0
		return
	match _attack_phase:
		0:  # IDLE
			# 格子战：有目标即进入 WINDUP；传统战场：需在射程内
			if _is_card_grid_combat or dist <= fire_range:
				_attack_phase = 1
				_attack_phase_timer = 0.0
		1:  # WINDUP
			_attack_phase_timer += delta
			if _attack_phase_timer >= timing["windup"]:
				_attack_phase = 2
				_attack_phase_timer = 0.0
		2:  # ACTIVE
			_attack_phase_timer += delta
			if _attack_phase_timer < delta * 1.1:
				_do_attack()
			if _attack_phase_timer >= timing["active"]:
				_attack_phase = 3
				_attack_phase_timer = 0.0
		3:  # COOLDOWN
			_attack_phase_timer += delta
			if _attack_phase_timer >= timing["cooldown"]:
				_attack_phase = 0
				_attack_phase_timer = 0.0

func _do_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	if _hit_stun_left > 0.0:
		return
	var dist_t := global_position.distance_to(target.global_position)
	var miss := false
	var weapon_name_str: String = ""

	# 格子战标识：传给 calculate_damage_with_weapon，使其跳过防御减免（防御由 CardGridDamage 处理）
	# 且射程衰减改用 range_falloff 保底 30%（传统战场用 range_value×100 做 max_range 会归零）。
	var is_card_grid: bool = _cached_is_card_grid

	# v6.0: 从 stats 武器槽位获取 weapon_name 和 dmg
	var wt: int = GC.WeaponType.DIRECT
	var dmg_out: float = attack_damage
	var pre_calc := false
	# v7.x: 记录槽位 weapon_type，用于子弹 VFX 弹道差异化（按目标类型）
	var _slot_wt: int = -1
	# v8.4: 武器类改造专属视觉标识（从 weapon_resource._mod_effects 读出，曲射 batch / 独立 bullet 共用）
	var _vfx_variant: String = ""
	if stats != null:
		var target_stats = target.get("stats") as UnitStats
		var target_kind: int = target_stats.combat_kind if target_stats != null else 0
		var weapon = AttackCalculator.get_weapon_for_target(stats, target_kind)
		if weapon and weapon.enabled:
			wt = weapon.weapon_type
			_slot_wt = int(weapon.weapon_type)  # 槽位弹道类型（用于子弹 VFX）
			weapon_name_str = weapon.display_name
			if weapon is WeaponResource:
				_vfx_variant = String(weapon._mod_effects.get("vfx_variant", ""))
			dmg_out = AttackCalculator.calculate_damage_with_weapon(
				stats, target_stats, dist_t, weapon, 0, [], is_card_grid, is_card_grid
			)
			pre_calc = true
		else:
			wt = stats.weapon_type
			# 修复：使用attack_damage而非attack_light，避免未初始化导致的1点伤害
			dmg_out = stats.attack_damage
	else:
		var cfg: Dictionary = _cached_archetype_cfg
		wt = int(cfg.get("weapon_type", GC.WeaponType.DIRECT))
	# v9.x: 直射武器跨行射击减伤（同行全额；曲射/空射全场全额，不受行约束）
	dmg_out *= CardGridBattleLayout.cross_row_direct_multiplier(self, target, wt)
	# 开火反馈：炮口闪光 + Sprite2D 缩放脉冲（所有武器/所有战斗模式统一生效）
	# 复用玩家 AI 的静态方法——敌方攻击逻辑独立，但开火视觉反馈无耦合。
	# v17: 传武器名+敌方域标记，火花类别键经 WeaponVisualProfiles 统一解析
	# （武器名优先+legacy 域兜底，替代函数内部的朝向猜域启发式）。
	ConstructUnitAI._play_muzzle_feedback(self, wt, weapon_name_str, false)
	# v9.5: 曲射/空射必须在直射 batch 之前判定。
	# 避免新枚举 INDIRECT(1)/AERIAL(2) 被 BATCH_FIRE_WEAPON_TYPES=[0,4,1,2]（legacy 语义）误拦——
	# 导致敌方火炮/空射单位走直线曳光弹道（与玩家侧 construct_unit_ai 不对称）。
	if GC.is_indirect_weapon_type(wt):
		if BattleManager and is_instance_valid(BattleManager.enemy_indirect_batch):
			if BattleManager.enemy_indirect_batch.has_method("fire"):
				# v16: 发射点改炮口锚点（原传 global_position 脚底，炮弹从脚下钻出与炮口火脱节）
				BattleManager.enemy_indirect_batch.fire(_get_direct_fire_spawn_pos(), target, dmg_out, wt, self, stats, miss, weapon_name_str, _vfx_variant)
				AttackPoseAnim.play(self, wt)
				return
	if _try_fire_enemy_projectile_batch(target, wt, dmg_out, miss, weapon_name_str, _vfx_variant):
		AttackPoseAnim.play(self, wt)
		return
	AttackPoseAnim.play(self, wt)
	var pellet_n := 6 if wt == 5 else 1
	var pellet_dmg := dmg_out / float(pellet_n)
	var root_2d = get_parent().get_parent() if (get_parent() != null and get_parent().get_parent() != null) else self

	for _p in range(pellet_n):
		var bullet: Node2D = ObjectPoolManager.get_object("bullets")
		if bullet == null:
			bullet = BulletScene.instantiate()
		bullet.global_position = _get_direct_fire_spawn_pos()
		# v7.x: 子弹 VFX 优先用槽位 weapon_type（按目标类型差异化弹道），
		# 回退单位级 legacy_weapon_type（改造单位级默认），再回退 wt。
		var _vfx_wt: int = wt
		if _slot_wt >= 0:
			_vfx_wt = _slot_wt
		elif stats and stats.legacy_weapon_type > 0:
			_vfx_wt = stats.legacy_weapon_type
		bullet.setup(target, pellet_dmg, false, _vfx_wt, self, stats, miss, weapon_name_str, pre_calc, _vfx_variant)
		var current_parent: Node = bullet.get_parent()
		if current_parent != root_2d:
			if current_parent != null:
				current_parent.remove_child(bullet)
			root_2d.add_child(bullet)

func _try_fire_enemy_projectile_batch(p_target: Node2D, wt: int, p_damage: float = -1.0, p_miss: bool = false, p_weapon_name: String = "", p_vfx_variant: String = "") -> bool:
	if wt not in GC.BATCH_FIRE_WEAPON_TYPES:  # SMG, PISTOL, RIFLE, MG
		return false
	if BattleManager == null or BattleManager.enemy_projectile_batch == null:
		return false
	var dmg: float = attack_damage if p_damage < 0.0 else p_damage
	# v16: 透传 weapon_name/vfx_variant（高速直射路径此前丢失武器名亚类命中配方与改造专属视觉）
	BattleManager.enemy_projectile_batch.fire(_get_direct_fire_spawn_pos(), p_target, dmg, wt, self, stats, p_miss, p_weapon_name, p_vfx_variant)
	return true

## 获取武器发射起点（v16 起直射与曲射共用）：优先用 MuzzleAnchors 标注的枪口位置
## （fireX/fireY 独立二维；锚点表标注语义本就是"弹道起始点"），
## 无标注时回退到 entity_top_y * 0.5（实体垂直中点）。
func _get_direct_fire_spawn_pos() -> Vector2:
	var spr = get_node_or_null("Sprite2D") as Sprite2D
	var muzzle_offset: Vector2 = MuzzleAnchors.get_fire_offset(archetype_id, spr)
	if muzzle_offset != Vector2.ZERO:
		return global_position + muzzle_offset
	# 回退：无标注，用实体垂直中点
	var offsetY: float = 0.0
	if spr != null:
		offsetY = CardGridUnitVisuals.entity_top_y(spr) * 0.5
	return global_position + Vector2.UP * offsetY

func _update_hp_bar() -> void:
	if _presentation_card_grid:
		# v7.x: 格子战启用迷你 HP 条（与设计稿 v9 对齐——HP 条 + HP 数值配套）
		var bar_grid := get_node_or_null("HpBar")
		if bar_grid != null and bar_grid.has_method("set_ratio"):
			var grid_ratio := hp / max_hp if max_hp > 0 else 1.0
			if absf(grid_ratio - _cached_hp_ratio) >= 0.01:
				_cached_hp_ratio = grid_ratio
				bar_grid.set_side(false)
				bar_grid.set_ratio(grid_ratio)
				if typeof(SignalBus) == TYPE_NIL:
					bar_grid.set_folded(true)
				else:
					bar_grid.set_folded(BattleInputState.current_selected_unit != self)
				# HP 直接显示在血条内部（v9 perf：挪进 1% 门槛——原在门槛外每次受击都
				# "%d/%d" 格式化+Label 重排；construct_unit 同款已修，此处对齐）
				if bar_grid.has_method("set_hp_text"):
					bar_grid.set_hp_text(hp, max_hp)
		return
	var bar = get_node_or_null("HpBar")
	if bar == null or not bar.has_method("set_ratio"):
		return
	# 性能优化：只在 HP 比率变化时更新 UI
	var current_ratio := hp / max_hp if max_hp > 0 else 1.0
	if absf(current_ratio - _cached_hp_ratio) < 0.01:  # 变化小于1%时不更新
		return
	_cached_hp_ratio = current_ratio
	bar.set_side(false)
	bar.set_ratio(current_ratio)
	if typeof(SignalBus) == TYPE_NIL:
		bar.set_folded(true)
	else:
		bar.set_folded(BattleInputState.current_selected_unit != self)
	# v7.x: 现在HP直接显示在血条内部，调用set_hp_text同步显示
	if bar.has_method("set_hp_text"):
		bar.set_hp_text(hp, max_hp)

## v8.x: 刷新卡底 buff/改造图标条（与 construct_unit 对齐，signature 去重避免无变化时重建）
func _update_card_grid_buff_strip(force: bool = false) -> void:
	if not _presentation_card_grid:
		return
	var sig: String = CardGridBuffStrip.buff_signature(self)
	if not force and sig == _buff_strip_signature:
		return
	_buff_strip_signature = sig
	var spr: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	CardGridUnitVisuals.sync_buff_strip(self, self, spr)
	CardGridUnitVisuals.sync_mod_strip(self, self, spr)

func take_damage(amount: float, attacker: Variant = null) -> void:
	# v7.x 战场视觉反馈：记录最后攻击者，供 unit_killed 信号携带（击杀定帧/连杀提示依赖）
	if attacker != null and is_instance_valid(attacker):
		set_meta("_last_attacker", attacker)
	var hp_loss: float = amount
	if _cached_is_card_grid:
		var pen: float = 0.0
		# 攻击者类型（用于选对应维度的防御）
		var attacker_kind: int = -1
		if attacker != null and is_instance_valid(attacker) and "stats" in attacker:
			var atk_stats: Variant = attacker.get("stats")
			if atk_stats is UnitStats:
				# v6.2: 条件型穿甲（相克 MOD）按目标(自身)类型激活
				# 敌人无 combat_kind 字段，从 stats 读（敌人 stats 可能为 null，回退到 LIGHT）
				var self_kind: int = stats.combat_kind if stats != null else 0
				if (atk_stats as UnitStats).has_method("get_effective_armor_penetration"):
					pen = (atk_stats as UnitStats).get_effective_armor_penetration(self_kind)
				else:
					pen = float((atk_stats as UnitStats).armor_penetration)
				attacker_kind = int((atk_stats as UnitStats).combat_kind)
		# v6.6 修复：防御按攻击者类型选三维维度，而非用单一 defense 字段。
		# 修复前用 defense 单字段（多为配置旧值/5.0默认），三维 defense_light/armor/air 形同虚设，
		# 导致高防敌人被打像没防御。与 swarm_enemy_slot.take_damage 口径对齐。
		var base_def: float = defense  # 兜底：旧单字段
		if stats != null and attacker_kind >= 0:
			match attacker_kind:
				GC.CombatKind.LIGHT, GC.CombatKind.SUPPORT:
					base_def = stats.defense_light
				GC.CombatKind.ARMOR, GC.CombatKind.FORT:
					base_def = stats.defense_armor
				GC.CombatKind.AIR:
					base_def = stats.defense_air
		elif stats != null:
			# 攻击者类型未知时取三维最大值（保守，不致过脆）
			base_def = maxf(stats.defense_light, maxf(stats.defense_armor, stats.defense_air))
		var eff_def: float = CardGridDamage.effective_defense(base_def, pen)
		var dodge: float = 0.0
		if stats != null:
			# v10(H3): ECM 闪避削弱（带激活中的 _ecm_dodge_penalty 时扣减，此前四处写零读）
			dodge = maxf(0.0, float(stats.dodge_chance) - ModuleEffectHandler.get_ecm_dodge_penalty(self))
		# v10 打破型效果：俯冲修正失效期间（fort 克制命中触发 ground_aircraft）dodge 归零
		if dodge > 0.0 and ModuleEffectHandler.is_grounded_for_dodge(self):
			dodge = 0.0
		# v10 组合规则①：照明标记+曲射=必中（被标记目标受曲射攻击时闪避失效）
		if dodge > 0.0 and attacker != null and ModuleEffectHandler.is_marked_for_indirect(self, attacker):
			dodge = 0.0
		# v7.5: 传入 damage_reduction（此前全链路空转，现 resolve_hit 接入）
		# 优先 stats.damage_reduction（改造/词条加成），叠加节点 damage_reduction（卡牌能力 debuff）
		var dmg_red: float = 0.0
		if stats != null:
			dmg_red = float(stats.damage_reduction)
		dmg_red = minf(0.60, dmg_red + float(damage_reduction))
		var hit: Dictionary = CardGridDamage.resolve_hit(amount, eff_def, dodge, dmg_red)
		# v8.x: 闪避反馈——dodged 字段从不被读取，闪避时 hp_loss=0 静默走完流程且仍触发受击反馈。
		# 现闪避即飘 MISS 并提前 return（与 construct_unit 口径一致）。
		if bool(hit.get("dodged", false)):
			CombatFeedback.show_miss(global_position, self)
			return
		hp_loss = float(hit.get("hp_loss", amount))
		# v7.x: 新机制 meta 读取（破甲叠加/标记易伤/巷战免伤）——与 construct_unit 口径一致
		# 这些 meta 由攻击者的 ModuleEffectHandler.apply_on_hit_side_effects 挂载
		# v10(C9): 破甲带 8s 到期，过期惰性清理（原永久生效）
		if has_meta("_armor_break_stacks"):
			var _ab_expired: bool = false
			if has_meta("_armor_break_until") \
					and Time.get_ticks_msec() / 1000.0 >= float(get_meta("_armor_break_until", 0.0)):
				remove_meta("_armor_break_stacks")
				remove_meta("_armor_break_ratio")
				remove_meta("_armor_break_until")
				_ab_expired = true
			if not _ab_expired:
				var _ab_stacks: int = int(get_meta("_armor_break_stacks", 0))
				var _ab_ratio: float = float(get_meta("_armor_break_ratio", 0.0))
				if _ab_stacks > 0 and _ab_ratio > 0.0:
					hp_loss = hp_loss * maxf(0.1, 1.0 - _ab_stacks * _ab_ratio)
		if has_meta("_marked_until"):
			var _mark_expire: float = float(get_meta("_marked_until", 0.0))
			var _now: float = Time.get_ticks_msec() / 1000.0
			if _now < _mark_expire:
				var _vuln: float = float(get_meta("_mark_vuln_bonus", 0.0))
				if _vuln > 0.0:
					hp_loss = hp_loss * (1.0 + _vuln)
			else:
				remove_meta("_marked_until")
				remove_meta("_mark_vuln_bonus")
		# v8.x: 暴击标注惰性清理（加成按时间戳在 bullet.gd 判定，过期 meta 顺带清掉）
		if has_meta("_crit_marked_until"):
			var _cm_expire: float = float(get_meta("_crit_marked_until", 0.0))
			if Time.get_ticks_msec() / 1000.0 >= _cm_expire:
				remove_meta("_crit_marked_until")
				remove_meta("_crit_mark_bonus")
		# v7.x: 巷战免伤（敌方也可装备 infantry_mods 改造，若 stats 有 urban_defense_bonus 则生效）
		if stats != null and stats.urban_defense_bonus > 0.0 and attacker_kind >= 0:
			if attacker_kind == GC.CombatKind.ARMOR or attacker_kind == GC.CombatKind.AIR:
				hp_loss = hp_loss * (1.0 - stats.urban_defense_bonus)
		if bool(hit.get("apply_recoil", false)) and _presentation_card_grid:
			_play_card_hit_recoil()
		if bool(hit.get("apply_stun", false)):
			var extra: float = 0.08 + clampf(hp_loss / maxf(max_hp, 1.0), 0.0, 0.25) * 0.35
			_hit_stun_left = maxf(_hit_stun_left, extra)
	# v7.x 第二批：拦截判定（概率伤害归零，在 hp 扣减之前）
	if stats != null and ModuleEffectHandler.try_intercept(self):
		return  # 拦截成功，跳过所有伤害
	# 丢弃已释放的旧来源，避免死亡结算读到悬挂 Node
	if not is_instance_valid(last_damage_source):
		last_damage_source = null
	# 记录最后伤害来源（仅玩家单位）
	if attacker != null and is_instance_valid(attacker) and attacker is Node and attacker.is_in_group("player_units"):
		last_damage_source = attacker
	# v6.6 修复：_incoming_damage_mul（战场环境 burn_on_hit 等带来的额外受伤倍率）
	# 此前只作用于 hp 扣减，不作用于伤害数字显示，导致飘字与血条实际扣血矛盾。
	# 现统一用 final_loss 扣血、发信号、触发受击反馈，三者保持一致。
	var final_loss: float = hp_loss * _incoming_damage_mul
	# v8: stealth 开局减伤（前 4 秒模拟"潜入到位"，未就位时更耐打）
	if _is_stealth_in_grace():
		final_loss *= STEALTH_GRACE_DAMAGE_MUL
	# v8.6: 堡垒阵地坚守光环——范围内堡垒庇护 meta 减伤（与 construct_unit 对齐）。
	# _apply_fort_shelter_aura 在友方堡垒 on_tick 时挂载此 meta（敌方堡垒已接 on_tick，会写入）。
	if has_meta("_fort_shelter_until"):
		var _fs_expire: float = float(get_meta("_fort_shelter_until", 0.0))
		var _fs_now: float = Time.get_ticks_msec() / 1000.0
		if _fs_now < _fs_expire:
			var _fs_bonus: float = float(get_meta("_fort_shelter_bonus", 0.0))
			if _fs_bonus > 0.0:
				final_loss = final_loss * (1.0 - _fs_bonus)
	hp -= final_loss
	# v8 批次2: 反伤词缀（armor_reflect）——受到伤害时反弹给攻击者
	# 标记 _vfx_is_reflect 防止递归（反伤伤害不再触发对方的反伤）
	if final_loss > 0.0 and attacker != null and is_instance_valid(attacker):
		var reflect_ratio: float = _get_armor_reflect_ratio()
		if reflect_ratio > 0.0 and not (attacker.has_meta("_vfx_is_reflect") and attacker.get_meta("_vfx_is_reflect")):
			var reflect_dmg: float = final_loss * reflect_ratio
			if reflect_dmg > 0.0 and attacker.has_method("take_damage"):
				set_meta("_vfx_is_reflect", true)
				attacker.take_damage(reflect_dmg, self)
				set_meta("_vfx_is_reflect", false)
	# v6.4: 受击视觉反馈。v8.x: 去掉整体变色虚化（单位保持卡图清晰），改命中点血溅 + 保留抖动/击退
	if hp > 0 and final_loss > 0:
		_trigger_hit_shake()
		# v8.3: 受击击退——从攻击者位置推方向
		if attacker != null and is_instance_valid(attacker) and (attacker is Node2D):
			var kb_dir: Vector2 = global_position - (attacker as Node2D).global_position
			var kb_str: float = 6.0 if (attacker.get("explosion_radius") != null and float(attacker.get("explosion_radius")) > 0.0) else 3.0
			_trigger_hit_knockback(kb_dir, kb_str)
			# v8.x: 命中点血溅粒子（敌方暗红血色）
			VfxImpactFactory.spawn_hit_blood(get_parent(), global_position, kb_dir, kb_str, false)
		# v8.1: 血条受击闪白（接通 unit_hp_bar.trigger_damage_flash，原为未连线死功能）
		var _hpbar := get_node_or_null("HpBar")
		if _hpbar != null and _hpbar.has_method("trigger_damage_flash"):
			_hpbar.trigger_damage_flash()
		# v7.1: 堡垒防护光环受击强化（扩张+闪亮）
		if _is_fort_aura_unit:
			_fort_aura_hit_boost = 1.0
	# 性能优化：在 HP 变化时更新 HP 条
	_update_hp_bar()
	if SignalBus:
		SignalBus.unit_damaged.emit(self, false, final_loss, global_position)
	# v8.6: 接入 ModuleEffectHandler.on_damage_taken（与玩家单位对齐）。
	# 激活：怒气积累、反炮兵标记（敌方 ARTILLERY）、爆反装甲。此前敌方这些改造效果全空转。
	ModuleEffectHandler.on_damage_taken(self, attacker, final_loss)
	if hp <= 0:
		_die()

## v7.4: 受击缩放抖动触发（手写分段计时，不再 create_tween）。
## 基准必须固定为 (1,1) 并每次重置——连续高频受击时若不重置，scale 累积漂移导致敌人越打越小（历史 bug）。
func _trigger_hit_shake() -> void:
	scale = Vector2.ONE
	_hit_shake_t = 0.0


## v8.3: 受击击退位移——沿弹道反方向微位移（与 construct_unit 对齐）
var _knockback_tween: Tween = null
func _trigger_hit_knockback(direction: Vector2, strength: float) -> void:
	if DT.is_motion_reduce():
		return
	if direction == Vector2.ZERO or strength <= 0.0:
		return
	if _knockback_tween != null and _knockback_tween.is_valid():
		_knockback_tween.kill()
	var base_pos: Vector2 = position
	var off: Vector2 = direction.normalized() * strength
	_knockback_tween = create_tween()
	_knockback_tween.tween_property(self, "position", base_pos + off, 0.04)
	_knockback_tween.tween_property(self, "position", base_pos, 0.08)


## v7.4: 受击动画推进（每 physics 帧调用）。与 construct_unit._update_hit_animations 对齐。
## v8.x: flash 已移除（改命中点血溅），仅剩 shake 分段插值。
## v8.3: shake 振幅加大 段长 0.035s。
func _update_hit_animations(delta: float) -> void:
	if _hit_shake_t >= 0.0:
		_hit_shake_t += delta
		if _hit_shake_t >= _HIT_SHAKE_DURATION:
			scale = Vector2.ONE
			_hit_shake_t = -1.0
			modulate = Color.WHITE  # v10: 闪白结束复位(敌方正常态 modulate=WHITE)
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
			# v10: 受击闪白(复用 _hit_shake_t 计时,零新 tween 零 GC)——前 0.08s 把 modulate 推亮再回白
			# 敌方受击频繁,沿用本类"手写计时避免每击 create_tween GC"的既有设计。motion_reduce 跳过。
			if not DT.is_motion_reduce():
				var ft: float = clampf(_hit_shake_t / 0.08, 0.0, 1.0)
				var fb: float = 0.8 * (1.0 - ft)  # 0.8 → 0
				modulate = Color(1.0 + fb, 1.0 + fb, 1.0 + fb, 1.0)


## 治疗方法（用于击杀修复等回复效果）
func heal(amount: float) -> void:
	hp = min(hp + amount, max_hp)

func _die() -> void:
	if _is_dying:
		return
	_is_dying = true
	# v8.6: 接入 ModuleEffectHandler 复活检查（敌方若装 revive_on_death 改造）。
	# on_death 返回 true 表示复活成功，中止死亡流程（与 construct_unit 对齐）。
	var _killer_for_death: Variant = null
	if has_meta("_last_attacker"):
		_killer_for_death = get_meta("_last_attacker", null)
	if _killer_for_death != null and not is_instance_valid(_killer_for_death):
		_killer_for_death = null
	if ModuleEffectHandler.on_death(self, _killer_for_death):
		_is_dying = false  # 复活成功，清除死亡锁
		return
	# v8.6: 通知击杀者（玩家单位击杀敌方时，shield_on_kill 等击杀型改造）。
	if _killer_for_death != null:
		ModuleEffectHandler.on_kill(_killer_for_death)
	# 性能优化：从空间分区网格移除
	_unregister_from_spatial_grid()

	# 安全清理：防止死亡后继续处理事件
	_cleanup_before_destroy()
	if SignalBus:
		if BattleInputState.current_selected_unit == self:
			BattleInputState.current_selected_unit = null
		SignalBus.unit_died.emit(self, false)
		# v7.x 战场视觉反馈：emit unit_killed（含击杀者），供 BattleSpectacle/BattleLog/MVP
		# 用 has_meta 先判定，避免从未被玩家单位击中过的敌人打印 "no meta values" 警告。
		var _killer: Variant = null
		if has_meta("_last_attacker"):
			_killer = get_meta("_last_attacker", null)
		# v8.6: is_instance_valid 守卫必须在 on_kill 之后（on_kill 可能触发击杀者自身的
		# take_damage/死亡/释放，导致此处的 _killer 引用变为 freed object，as Node 会报错）。
		if _killer != null and not is_instance_valid(_killer):
			_killer = null
		# meta 取出的对象类型信息会退化为 Object 基类，emit 信号(killer: Node)严格检查会报转换错。
		# 显式 as Node 转换：是 Node 则传入，否则 null。
		var _killer_node: Node = _killer as Node if (_killer != null and is_instance_valid(_killer)) else null
		SignalBus.unit_killed.emit(self, _killer_node, false)
	# v6.4: 死亡淡出动画（缩放+透明度），逻辑结算已完成，仅做视觉收尾
	_play_death_fadeout()


## v6.4: 死亡视觉淡出——快速缩放并淡出后销毁节点（逻辑结算已完成，不依赖 _process）
func _play_death_fadeout() -> void:
	# v8.x: 死亡爆散反馈（阵营色冲击波 + 碎片），让死亡与受击产生明确视觉差
	VfxImpactFactory.spawn_death_burst(get_parent(), global_position, false)
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

func _battlefield_y_clamp_range() -> Vector2:
	if _cached_is_card_grid:
		if BattleManager and BattleManager.battlefield and BattleManager.battlefield.has_method("get_deploy_y_bounds"):
			return BattleManager.battlefield.get_deploy_y_bounds()
	return Vector2(BATTLE_MIN_Y, BATTLE_MAX_Y)


func _clamp_inside_battlefield() -> void:
	var gx := global_position
	var clamped_x := clampf(gx.x, BATTLE_MIN_X, BATTLE_MAX_X)
	var yb: Vector2 = _battlefield_y_clamp_range()
	var clamped_y := clampf(gx.y, yb.x, yb.y)
	if clamped_x != gx.x:
		global_position.x = clamped_x
	if clamped_y != gx.y:
		global_position.y = clamped_y
	_enforce_card_grid_lane_alignment()


func _enforce_card_grid_lane_alignment() -> void:
	if not _presentation_card_grid:
		return
	if not _cached_is_card_grid:
		return
	var esi: int = int(get_meta("card_grid_enemy_slot", -1))
	if esi < 0:
		return
	var bf: Node = BattleManager.battlefield if BattleManager else null
	if bf == null or not bf.has_method("get_card_grid_enemy_slot_global"):
		return
	var anchor: Vector2 = bf.get_card_grid_enemy_slot_global(esi)
	if global_position.distance_squared_to(anchor) > 0.25:
		global_position = anchor



func _sprite_resource_path_suspicious(path: String) -> bool:
	var p := path.to_lower().replace("\\", "/")
	return "background" in p or "/bg_" in p or "bg_level" in p or "/backgrounds/" in p


func _texture_exceeds_max_dim(tex: Texture2D, max_dim: int) -> bool:
	return tex.get_width() > max_dim or tex.get_height() > max_dim


## =========================================================================
## 性能优化：空间分区系统集成
## =========================================================================

## 注册到空间分区网格
func _register_to_spatial_grid() -> void:
	if not BattleManager or not BattleManager.spatial_grid:
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
	BattleManager.spatial_grid.update(self)


# ============================ v7.x: 敌方布置时间（部署虚影）============================
# 复用我方 calculate_deploy_delay 公式（基于 stats.deploy_speed，默认3→约7.5秒）。
# 与 ConstructUnit 的部署虚影语义对称但独立实现：敌兵不需要卡牌能力钩子/势力泛光/空间网格延迟注册，
# 且实体化时不回满血（保留布置期间累积的伤害，避免玩家输出被回满白费）。
# 布置期间：半透明 modulate.a=0.42、velocity=ZERO、target=null（不动不索敌），可被攻击。
# is_deploy_ghost 字段被 battle_manager._is_active_combat_unit 鸭子识别 → 部署期不计存活数。

## 启动敌方部署虚影（入场时由 spawn 挂钩调用）
func start_as_deploy_ghost() -> void:
	is_deploy_ghost = true
	var actual_delay: float = ConstructUnitDeploy.calculate_deploy_delay(stats)
	_ghost_materialize_time_left = maxf(0.05, actual_delay)
	modulate = Color(1.0, 1.0, 1.0, 0.42)

## 部署虚影每帧更新（由 _physics_process 调用，返回 true 表示本帧已实体化）
func _update_enemy_deploy_ghost(delta: float) -> bool:
	_ghost_materialize_time_left -= delta
	velocity = Vector2.ZERO
	target = null
	move_and_slide()
	_clamp_inside_battlefield()
	if _ghost_materialize_time_left <= 0.0:
		_materialize_enemy_deploy_ghost()
		return true
	return false

## 实体化部署虚影：恢复完全不透明，投入战斗（NOT 回满血——保留布置期间被打掉的血）
func _materialize_enemy_deploy_ghost() -> void:
	is_deploy_ghost = false
	_ghost_materialize_time_left = 0.0
	modulate = Color.WHITE
