extends CharacterBody2D
## 敌方单位：卡图立绘（Sprite2D）+ 自动向左移动并攻击；已弃用 SpriteFrames 序列帧

const BulletScene = preload("res://scenes/units/bullet.tscn")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyStatResolver = preload("res://data/enemy_stat_resolver.gd")
const ModuleEffectHandler = preload("res://scripts/battle/module_effect_handler.gd")
const GC = preload("res://resources/game_constants.gd")
const CardGridUnitVisuals = preload("res://scripts/card_grid_unit_visuals.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CardGridDamage = preload("res://scripts/card_grid_damage.gd")
const CombatTargeting = preload("res://scripts/combat_targeting.gd")
const RankRules = preload("res://data/rank_rules.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const TargetSelection = preload("res://scripts/battle/target_selection.gd")
const DamageAttenuation = preload("res://scripts/battle/damage_attenuation.gd")
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
const BATTLE_MIN_X: float = 40.0
const BATTLE_MAX_X: float = 1240.0
const BATTLE_MIN_Y: float = 280.0
const BATTLE_MAX_Y: float = 440.0
## 单帧贴图超过此边长视为整张地图/错误资源，不使用（卡面立绘标准为 1024）
const MAX_ENEMY_FRAME_TEX_DIM := 1280
## 最终显示在战场上的最大宽高（像素），防止误配大图占满屏
const MAX_ENEMY_VISUAL_EXTENT_PX := 220.0
const ENABLE_ENEMY_VISUAL_EXTENT_CLAMP := true

var is_player: bool = false
var hp: float = 80.0
var max_hp: float = 80.0
var attack_damage: float = 10.0
var attack_range: float = 100.0
var attack_interval: float = 1.0
var attack_timer: float = 0.0
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
var _hit_stun_left: float = 0.0
var _card_tween: Tween = null
var _rest_position: Vector2 = Vector2.ZERO
var _card_nudge_tween: Tween = null
var _card_grid_rest_x: float = NAN  ## 格子战术中卡片的归位 X
## v6.4: 受击视觉反馈（复用 construct_unit 的闪白/抖动模式，Tween 复用避免每击 new）
var _hit_flash_tween: Tween = null
var _hit_shake_tween: Tween = null
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
	if SignalBus and SignalBus.has_signal("phase_law_runtime_changed"):
		SignalBus.phase_law_runtime_changed.connect(_on_phase_law_runtime_changed)

func setup(_is_player: bool, p_wave: int, p_archetype_id: String = "basic_infantry") -> void:
	wave_index = p_wave
	archetype_id = p_archetype_id
	_apply_archetype_stats()
	# setup 在 add_child() 之前被调用时，当前节点不在有效场景树内；
	# 延后执行可避免 Godot 报绝对路径 get_node/active scene tree 相关警告。
	if is_inside_tree():
		_apply_phase_law_passives()
	else:
		call_deferred("_apply_phase_law_passives")
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
	var spr: Sprite2D = $Sprite2D as Sprite2D
	var anim: AnimatedSprite2D = $AnimatedSprite2D as AnimatedSprite2D
	var poly: Polygon2D = $Shape as Polygon2D
	if anim != null:
		anim.visible = false
		anim.sprite_frames = null
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	var card_res: CardResource = CardGridUnitVisuals.resolve_card_for_archetype(archetype_id)
	if card_res == null:
		card_res = CardGridUnitVisuals.synthetic_card_for_archetype(archetype_id, cfg)
	var tex: Texture2D = CardGridUnitVisuals.resolve_battle_icon_texture(card_res, archetype_id, cfg)
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
			self, spr, card_res, tex, false, rl
		)
	if poly != null:
		poly.visible = not sprite_ok
	var hb := get_node_or_null("HpBar") as CanvasItem
	if hb != null:
		hb.visible = false
	var aura_ring := get_node_or_null("AuraRing") as CanvasItem
	var rank_badge := get_node_or_null("RankBadge") as CanvasItem
	if aura_ring != null:
		aura_ring.visible = false
	if rank_badge != null:
		rank_badge.visible = false


func _play_card_attack_nudge() -> void:
	if not _presentation_card_grid:
		return
	# 首次 nudge 时记录归位 X
	if is_nan(_card_grid_rest_x):
		_card_grid_rest_x = position.x
	# 若有正在播放的 nudge tween，先 kill 并把 position 修正回归位点
	if _card_nudge_tween != null and _card_nudge_tween.is_valid():
		_card_nudge_tween.kill()
		position.x = _card_grid_rest_x
	_card_nudge_tween = create_tween()
	# 与我方 ConstructUnit 一致：前冲向目标侧；我方 +x，敌方面左，用 -x
	var dir: float = -1.0
	var rest_x: float = _card_grid_rest_x
	_card_nudge_tween.tween_property(self, "position:x", rest_x + dir * 22.0, 0.07)
	_card_nudge_tween.tween_property(self, "position:x", rest_x, 0.09)


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


func _apply_phase_law_passives() -> void:
	if not _base_stats_ready:
		_base_max_hp = max_hp
		_base_attack_damage = attack_damage
		_base_move_speed = move_speed
		_base_attack_interval = attack_interval
		_base_stats_ready = true
	var plm := get_node_or_null("/root/PhaseLawManager")
	if not plm or not plm.has_method("get_passive_runtime_tags_for_side"):
		return
	var tags: Array = plm.get_passive_runtime_tags_for_side(false)
	var hp_mult: float = 1.0
	var dmg_mult: float = 1.0
	var move_mult: float = 1.0
	var atkspd_mult: float = 1.0
	_incoming_damage_mul = 1.0
	for t in tags:
		if not (t is Dictionary):
			continue
		var effect: String = String(t.get("effect", ""))
		var v: float = float(t.get("value", 0.0))
		match effect:
			"burn_on_hit":
				_incoming_damage_mul *= 1.0 + clampf(v * 0.05, 0.0, 0.8)
			"anchor_field", "ion_net", "gravity_well":
				move_mult *= max(0.2, 1.0 - v)
			"static_domain":
				dmg_mult *= max(0.6, 1.0 - v * 0.01)
				atkspd_mult *= max(0.6, 1.0 - v * 0.01)
			_:
				continue
	var old_max: float = maxf(1.0, max_hp)
	var hp_ratio: float = clampf(hp / old_max, 0.0, 1.0)
	max_hp = _base_max_hp * hp_mult
	hp = maxf(1.0, max_hp * hp_ratio)
	attack_damage = _base_attack_damage * dmg_mult
	move_speed = _base_move_speed * move_mult
	attack_interval = max(0.1, _base_attack_interval / atkspd_mult)
	# v6.3: 同步更新 stats（_do_attack 走 stats 三维路径时需要反映律法减益）
	if stats != null:
		stats.max_hp = max_hp
		stats.attack_damage = attack_damage
		stats.attack_light = _base_attack_damage * dmg_mult
		stats.attack_armor = float(_cached_enemy_base.get("attack_armor", 0.0)) * dmg_mult
		stats.attack_air = float(_cached_enemy_base.get("attack_air", 0.0)) * dmg_mult
		stats.move_speed = move_speed
		stats.attack_interval = attack_interval
		# 同步武器槽位伤害
		if stats.weapon_slots.size() >= 3:
			for i in range(mini(3, stats.weapon_slots.size())):
				var w = stats.weapon_slots[i]
				if w != null and w.enabled:
					var base_key: String = ["attack_light", "attack_armor", "attack_air"][i]
					w.damage = float(_cached_enemy_base.get(base_key, 0.0)) * dmg_mult

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
	if cfg.is_empty():
		return
	_base_max_hp = hp
	_base_attack_damage = attack_damage
	_base_move_speed = move_speed
	_base_attack_interval = attack_interval
	_base_stats_ready = true
	_apply_visual_from_archetype(cfg)


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
	# 三维攻速：敌人只有单一 attack_interval，三组攻速统一
	var spd: float = 1.0 / s.attack_interval if s.attack_interval > 0.0 else 1.0
	s.attack_light_speed = spd
	s.attack_armor_speed = spd
	s.attack_air_speed = spd
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
	s.weapon_label = String(r.get("weapon_label", String(cfg.get("weapon_label", ""))))
	# 初始化武器槽位（让 AttackCalculator.get_weapon_for_target 生效）
	s.weapon_slots.clear()
	_ensure_enemy_weapon_slots(s)
	stats = s


## v6.3: 为敌人 UnitStats 初始化3个武器槽位（轻装/装甲/对空），复用三维攻击值
func _ensure_enemy_weapon_slots(s: UnitStats) -> void:
	var GC2 = preload("res://resources/game_constants.gd")
	# 槽位0=对轻装, 槽位1=对装甲, 槽位2=对空
	var slot_configs: Array = [
		{"target_kind": GC2.CombatKind.LIGHT, "dmg": s.attack_light, "spd": s.attack_light_speed},
		{"target_kind": GC2.CombatKind.ARMOR, "dmg": s.attack_armor, "spd": s.attack_armor_speed},
		{"target_kind": GC2.CombatKind.AIR, "dmg": s.attack_air, "spd": s.attack_air_speed},
	]
	for cfg_w in slot_configs:
		var w = WeaponResource.new()
		w.enabled = float(cfg_w.dmg) > 0.0
		w.damage = float(cfg_w.dmg)
		w.attack_speed = float(cfg_w.spd)
		w.range_value = maxi(1, int(round(s.attack_range / 100.0)))
		w.weapon_type = s.weapon_type
		w.windup = 0.2
		w.active = 0.1
		w.display_name = s.weapon_label
		s.weapon_slots.append(w)

func _apply_visual_from_archetype(cfg: Dictionary) -> void:
	_suppress_stray_editor_visual_nodes()
	var poly: Polygon2D = $Shape as Polygon2D
	var spr: Sprite2D = $Sprite2D as Sprite2D
	var anim: AnimatedSprite2D = $AnimatedSprite2D as AnimatedSprite2D
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
	var spr: Sprite2D = $Sprite2D as Sprite2D
	var poly: Polygon2D = $Shape as Polygon2D
	if spr == null:
		return
	if _presentation_card_grid:
		return
	_apply_facing(spr, null)
	_apply_era_and_type_visuals(poly, spr, null)
	_clamp_unit_visual_extent(spr, null)
	_apply_facing(spr, null)

func _apply_facing(spr: Sprite2D, anim: Variant) -> void:
	# 资源统一按"朝右"制作；运行时按阵营翻转：我方朝右、敌方朝左。
	var facing_right: bool = is_player
	if anim != null:
		anim.flip_h = not facing_right
	if spr != null:
		var sx: float = absf(spr.scale.x)
		spr.scale.x = sx if facing_right else -sx

func _update_shape() -> void:
	var poly: Polygon2D = $Shape as Polygon2D
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
			r *= 2.6
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
	if _hit_stun_left > 0.0:
		_hit_stun_left -= delta
	# 性能优化：不再每帧更新 HP 条，改为在 HP 变化时更新
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
	# P2 性能优化：静止单位跳过空间网格更新（格子战敌人 velocity=0，原每帧无谓 update）
	if velocity != Vector2.ZERO:
		_update_in_spatial_grid()

func _get_target_find_interval() -> float:
	var n: int = 0
	if BattleManager and BattleManager.has_method("get_enemy_unit_count"):
		n = BattleManager.get_enemy_unit_count()
	if n > 55:
		return 0.55
	if n > 35:
		return 0.42
	return TARGET_FIND_INTERVAL

func _should_retain_current_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if CombatTargeting.should_drop_phase_field_target(target, false, BattleManager):
		return false
	if CombatTargeting.is_phase_field_node(target):
		return not CombatTargeting.has_alive_player_units(BattleManager)
	var d: float = global_position.distance_to(target.global_position)
	return d <= _enemy_acquisition_range()


func _find_target(_delta: float) -> void:
	var acq: float = _enemy_acquisition_range()
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
				false,  # 敌方单位
				acq
			)
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
	for n in gr:
		if not CombatTargeting.is_attackable_combat_unit(n):
			continue
		found_alive = true
		var dist_sq := global_position.distance_squared_to(n.global_position)
		if dist_sq <= attack_range_sq:
			target = n as Node2D
			return

	# 我方场上无单位时，攻击我方相位场
	if not found_alive:
		var phase_field: Node2D = CombatTargeting.find_opponent_phase_field(
			global_position, false, BattleManager, -1.0
		)
		if phase_field != null:
			target = phase_field
			return

## v5.0 攻速分离: 三阶段攻击状态机
## idle(0) → windup(1) → active(2,发射) → cooldown(3) → idle(0)
func _process_attack_timing(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_attack_phase = 0
		_attack_phase_timer = 0.0
		return
	# 获取攻速参数：优先使用缓存（仅目标变化时重算）
	var timing: Dictionary
	var fire_range: float
	var wt: int
	if target != _cached_target_ref:
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
		fire_range *= 2.6

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
	if stats != null:
		var target_stats = target.get("stats") as UnitStats
		var target_kind: int = target_stats.combat_kind if target_stats != null else 0
		var weapon = AttackCalculator.get_weapon_for_target(stats, target_kind)
		if weapon and weapon.enabled:
			wt = weapon.weapon_type
			weapon_name_str = weapon.display_name
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
	if _try_fire_enemy_projectile_batch(target, wt, dmg_out, miss):
		if _presentation_card_grid:
			_play_card_attack_nudge()
		return
	# v6.2: 敌方曲射/空射走 indirect batch 批处理
	if wt in [GC.WeaponType.INDIRECT, GC.WeaponType.AERIAL]:
		if BattleManager and is_instance_valid(BattleManager.enemy_indirect_batch):
			if BattleManager.enemy_indirect_batch.has_method("fire"):
				BattleManager.enemy_indirect_batch.fire(global_position, target, dmg_out, wt, self, stats, miss, weapon_name_str)
				if _presentation_card_grid:
					_play_card_attack_nudge()
				return
	if _presentation_card_grid:
		_play_card_attack_nudge()
	var pellet_n := 6 if wt == 5 else 1
	var pellet_dmg := dmg_out / float(pellet_n)
	var root_2d = get_parent().get_parent() if (get_parent() != null and get_parent().get_parent() != null) else self

	for _p in range(pellet_n):
		var bullet: Node2D = ObjectPoolManager.get_object("bullets")
		if bullet == null:
			bullet = BulletScene.instantiate()
		bullet.global_position = global_position
		bullet.setup(target, pellet_dmg, false, wt, self, stats, miss, weapon_name_str, pre_calc)
		var current_parent: Node = bullet.get_parent()
		if current_parent != root_2d:
			if current_parent != null:
				current_parent.remove_child(bullet)
			root_2d.add_child(bullet)

func _try_fire_enemy_projectile_batch(p_target: Node2D, wt: int, p_damage: float = -1.0, p_miss: bool = false) -> bool:
	if wt not in [0, 4, 1, 2]:  # SMG, PISTOL, RIFLE, MG
		return false
	if BattleManager == null or BattleManager.enemy_projectile_batch == null:
		return false
	var dmg: float = attack_damage if p_damage < 0.0 else p_damage
	BattleManager.enemy_projectile_batch.fire(global_position, p_target, dmg, wt, self, stats, p_miss)
	return true

func _update_hp_bar() -> void:
	if _presentation_card_grid:
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

func take_damage(amount: float, attacker: Variant = null) -> void:
	var hp_loss: float = amount
	if _cached_is_card_grid:
		var pen: float = 0.0
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
		var eff_def: float = CardGridDamage.effective_defense(defense, pen)
		var dodge: float = 0.0
		if stats != null:
			dodge = float(stats.dodge_chance)
		var hit: Dictionary = CardGridDamage.resolve_hit(amount, eff_def, dodge)
		hp_loss = float(hit.get("hp_loss", amount))
		if bool(hit.get("apply_recoil", false)) and _presentation_card_grid:
			_play_card_hit_recoil()
		if bool(hit.get("apply_stun", false)):
			var extra: float = 0.08 + clampf(hp_loss / maxf(max_hp, 1.0), 0.0, 0.25) * 0.35
			_hit_stun_left = maxf(_hit_stun_left, extra)
	# 丢弃已释放的旧来源，避免死亡结算读到悬挂 Node
	if not is_instance_valid(last_damage_source):
		last_damage_source = null
	# 记录最后伤害来源（仅玩家单位）
	if attacker != null and is_instance_valid(attacker) and attacker is Node and attacker.is_in_group("player_units"):
		last_damage_source = attacker
	hp -= hp_loss * _incoming_damage_mul
	# v6.4: 受击视觉反馈（复用 construct_unit 的闪白/抖动模式）
	if hp > 0 and hp_loss > 0:
		_play_hit_flash()
		_play_hit_shake()
	# 性能优化：在 HP 变化时更新 HP 条
	_update_hp_bar()
	if SignalBus:
		SignalBus.unit_damaged.emit(self, false, hp_loss, global_position)
	if hp <= 0:
		_die()

## v6.4: 受击闪白反馈（复用 Tween，避免每击 new）
func _play_hit_flash() -> void:
	var flash_color := Color.WHITE
	var original_modulate := modulate
	modulate = flash_color
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", original_modulate, 0.1)


## v6.4: 受击缩放抖动反馈（复用 Tween，避免每击 new）
func _play_hit_shake() -> void:
	var base_scale := scale
	if _hit_shake_tween != null and _hit_shake_tween.is_valid():
		_hit_shake_tween.kill()
	_hit_shake_tween = create_tween()
	_hit_shake_tween.tween_property(self, "scale", base_scale * 0.85, 0.03)
	_hit_shake_tween.tween_property(self, "scale", base_scale * 1.05, 0.03)
	_hit_shake_tween.tween_property(self, "scale", base_scale * 0.95, 0.03)
	_hit_shake_tween.tween_property(self, "scale", base_scale, 0.03)


## 治疗方法（用于词条吸血效果）
func heal(amount: float) -> void:
	hp = min(hp + amount, max_hp)

func _die() -> void:
	if _is_dying:
		return
	_is_dying = true
	# 性能优化：从空间分区网格移除
	_unregister_from_spatial_grid()

	# 安全清理：防止死亡后继续处理事件
	_cleanup_before_destroy()
	if SignalBus:
		if BattleInputState.current_selected_unit == self:
			BattleInputState.current_selected_unit = null
		SignalBus.unit_died.emit(self, false)
	# v6.4: 死亡淡出动画（缩放+透明度），逻辑结算已完成，仅做视觉收尾
	_play_death_fadeout()


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
	if SignalBus and SignalBus.has_signal("phase_law_runtime_changed"):
		if SignalBus.phase_law_runtime_changed.is_connected(_on_phase_law_runtime_changed):
			SignalBus.phase_law_runtime_changed.disconnect(_on_phase_law_runtime_changed)

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

func _on_phase_law_runtime_changed() -> void:
	_apply_phase_law_passives()
	_update_hp_bar()

## 按时代和类型应用视觉区分
func _apply_era_and_type_visuals(poly: Polygon2D, spr: Sprite2D, anim: Variant) -> void:
	var level_for_era: int = maxi(1, wave_index)
	if GameManager:
		level_for_era = maxi(1, GameManager.current_level)
	var era = GC.get_era_for_level(level_for_era) if GC else 0
	var tags: Array = []

	# 获取敌人类型标签
	var scale_cfg: Dictionary = EnemyArchetypes.get_config(_visual_scale_archetype_id)
	var cfg = EnemyArchetypes.get_config(archetype_id)
	if not cfg.is_empty():
		tags = cfg.get("tags", [])

	# 定义时代颜色
	var era_colors = {
		0: Color(0.8, 0.7, 0.5),  # 一战：土黄
		1: Color(0.5, 0.6, 0.4),  # 二战：军绿
		2: Color(0.5, 0.6, 0.75), # 冷战：灰蓝
		3: Color(0.6, 0.6, 0.65), # 现代：灰
		4: Color(0.3, 0.7, 0.9)   # 近未来：科技蓝
	}

	var base_color = era_colors.get(era, Color.WHITE)

	# 检查是否是Boss或精英
	var is_boss = tags.has("boss")
	var is_elite = tags.has("elite")

	# 体型统一由数据层管理（支持 visual_scale 覆盖 + 标签默认比例）
	var base_scale: float = EnemyArchetypes.get_visual_scale_for_archetype(_visual_scale_archetype_id, scale_cfg)
	# Boss: 偏红（尺寸不再按分类额外放大）
	if is_boss:
		base_color = Color(1.0, 0.4, 0.4)
	# 精英: 偏金（尺寸不再按分类额外放大）
	elif is_elite:
		base_color = Color(1.0, 0.85, 0.3)

	var final_scale: float = base_scale

	# 应用颜色和缩放
	if spr:
		spr.modulate = base_color
		# 保留朝向（x 正负），只改绝对缩放尺寸
		var sx_sign: float = -1.0 if spr.scale.x < 0.0 else 1.0
		spr.scale = Vector2(final_scale * sx_sign, final_scale)
	elif poly:
		poly.color = base_color
		poly.scale = Vector2(final_scale, final_scale)
	# AnimatedSprite2D 翻转已由 _apply_facing 处理，此处仅设置尺寸
	if anim and anim.visible:
		anim.scale = Vector2(final_scale, final_scale)


func _sprite_resource_path_suspicious(path: String) -> bool:
	var p := path.to_lower().replace("\\", "/")
	return "background" in p or "/bg_" in p or "bg_level" in p or "/backgrounds/" in p


func _texture_exceeds_max_dim(tex: Texture2D, max_dim: int) -> bool:
	return tex.get_width() > max_dim or tex.get_height() > max_dim


func _clamp_unit_visual_extent(spr: Sprite2D, anim: Variant) -> void:
	if not ENABLE_ENEMY_VISUAL_EXTENT_CLAMP:
		return
	_clamp_visible_tex_node_extent(spr as Node2D, MAX_ENEMY_VISUAL_EXTENT_PX)
	_clamp_visible_tex_node_extent(anim as Node2D, MAX_ENEMY_VISUAL_EXTENT_PX)


func _clamp_visible_tex_node_extent(node: Node2D, max_extent: float) -> void:
	if node == null or not node.visible:
		return
	var tex: Texture2D = null
	if node is Sprite2D:
		tex = (node as Sprite2D).texture
	elif node is AnimatedSprite2D:
		var an := node as AnimatedSprite2D
		if an.sprite_frames != null and an.sprite_frames.has_animation(String(an.animation)):
			if an.sprite_frames.get_frame_count(String(an.animation)) > 0:
				tex = an.sprite_frames.get_frame_texture(String(an.animation), an.frame)
	if tex == null:
		return
	var w := float(tex.get_width()) * absf(node.scale.x)
	var h := float(tex.get_height()) * absf(node.scale.y)
	var m := maxf(w, h)
	if m <= 1.0 or m <= max_extent:
		return
	var r := max_extent / m
	node.scale *= r


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
