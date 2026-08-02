extends Node2D
## 敌方相位场驱动器：相位师基地，被摧毁则玩家胜利；持续生产敌方单位
## 使用 EnemyPhaseMasters 的装备数据（平台/武器）生成 ConstructUnit

const GC = preload("res://resources/game_constants.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const ConstructUnitScene = preload("res://scenes/units/construct_unit.tscn")
const EnemyUnitScene = preload("res://scenes/units/enemy_unit.tscn")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyStatResolver = preload("res://data/enemy_stat_resolver.gd")
const RuneDefs = preload("res://data/runes.gd")
const BattleSlotGrid = preload("res://scenes/battlefield/battle_slot_grid.gd")
const EnemyAffixes = preload("res://data/enemy_affixes.gd")
# v9.0: 敌方相位师固定套路系统（补兵规则按套路走）
const MasterPatterns = preload("res://data/enemy_phase_master_patterns.gd")

## 兜底：EnemyArchetypes 生成（当没有装备数据时使用）
const USE_FALLBACK_SPAWN: bool = true
## 与 EnemyUnit 视觉一致：用 archetype 的 visual_scale × 典型精灵帧边长，再按整张贴图缩放到同量级
const _PHASE_BODY_REFERENCE_FRAME_PX: float = 256.0
## 与 enemy_unit.gd 中 MAX_ENEMY_VISUAL_EXTENT_PX 对齐（底座略大可等同上限）
const _PHASE_BODY_MAX_EXTENT_PX: float = 220.0
## 出兵疲劳阶梯（v7.x 扩展自 v6.2 的单档疲劳）。
## 相位师不死即无限产兵会导致长战斗拖延；改为三档阶梯递进→彻底枯竭停止，
## 给玩家「熬过兵力潮就赢」的终局，避免消耗战。
## 阈值按 _unit_limit 倍数动态派生（setup 时缓存），让高容量相位师总兵力也更多。
const FATIGUE_TIER1_MULT: int = 2   # 轻度疲劳阈值 = unit_limit × 2
const FATIGUE_TIER2_MULT: int = 4   # 重度疲劳阈值 = unit_limit × 4
const EXHAUSTION_MULT: int = 6      # 彻底枯竭阈值 = unit_limit × 6
## 轻度疲劳产兵间隔（原 spawn_interval 约 3~6s），大幅延长以缓解压制。
const FATIGUED_SPAWN_INTERVAL: float = 18.0
## 重度疲劳产兵间隔，进一步放慢。
const HEAVY_FATIGUE_INTERVAL: float = 30.0

@export var max_hp: float = 500.0
@export var spawn_interval: float = 6.0
@export var rotate_speed_deg: float = -30.0

var hp: float = 500.0
var master_name: String = "相位师"
var era: int = 4
@onready var _body: Node2D = $Body

var _spawn_timer: float = 0.0
var _battle_active: bool = false

## 装备数据（从 EnemyPhaseMasters 配置传入）
var _equipment: Dictionary = {}
var _master_stats: Dictionary = {}
var _unit_limit: int = 6
var _has_equipment: bool = false
# v6.14: 相位师符文 + 出兵序列（程序化派生，见 EnemyPhaseMasters.get_enriched_equipment）
var _master_runes: Array = []           # 相位师自带符文 id 列表
var _spawn_sequence: Array = []         # 出兵序列 [{platform, type}, ...]
var _spawn_seq_index: int = 0           # 当前序列游标
# v7.x: 敌方相位仪主动能力缓存（setup 时从相位仪配置读取）
var _enemy_active_ability: Dictionary = {}
# v8.5: boss 主动/被动技能缓存（setup 时从 master_config 透传，供 EnemyMasterSkillEngine 读取）
var _boss_active_spells: Array = []
var _boss_passive_spells: Array = []
# v8.5: boss 技能引擎引用（setup 时由 BattleManager 注入，用于 _on_destroyed 触发死亡被动）
var _master_skill_engine: RefCounted = null
# v8.5: boss 护盾/反伤（由 EnemyMasterSkillEngine 的 shield_base/thorn_armor 类被动设置）
var _boss_shield: float = 0.0
var _boss_thorn_pct: float = 0.0
# v7.x: 产兵 tier 按关卡难度递进（替代旧"恒定 TIER_HIGH"）
# _game_level：当前游戏关卡号（1-100），0=未知 fallback 到主等级映射
# _era_progress：当前时代内进度 0.0~1.0（驱动 enhance/tier/rune_count 限量）
# _pm_tier：相位师产兵配置档位（TIER_MID/TIER_HIGH），setup 末尾缓存一次
var _game_level: int = 0
var _era_progress: float = 0.5
var _pm_tier: int = 2  # 默认 TIER_MID，setup 末尾按 era_progress 重算
## 出兵疲劳阶梯：0=正常, 1=轻度疲劳(18s), 2=重度疲劳(30s), 3=枯竭(停止产兵)
var _fatigue_tier: int = 0
## 累计召唤计数（达阈值推进 _fatigue_tier）
var _total_spawned: int = 0
## 阶梯阈值缓存（setup 时按 _unit_limit 倍数计算）
var _tier1_cap: int = 10
var _tier2_cap: int = 20
var _exhaustion_cap: int = 30
## 缓存 setup 时设置的 Body 原始 tint，供疲劳视觉反馈叠加暗化使用
var _base_body_tint: Color = Color.WHITE

# ─── v9.0 套路补兵系统 ───
## 当前相位师套路 id（setup 时识别/读取，见 MasterPatterns.get_pattern）
var _pattern_id: String = MasterPatterns.PATTERN_NONE
## 套路配置缓存（respawn_delay/max_respawns 等）
var _pattern_cfg: Dictionary = {}
## master_config 引用（补兵时按平台 id 查 archetype cfg 用）
var _master_config_cache: Dictionary = {}
## 待补兵队列：[{slot_index, platform_id, kind, due_time, remaining_retries}]
## 单位死亡时入队，_process 中检查 due_time 到点即补
var _respawn_queue: Array = []
## 每个槽位已补兵次数（slot_index -> count），达 max_respawns 后该槽永久留空
var _slot_respawn_counts: Dictionary = {}
## 玩家近期击杀间隔（秒）滑动窗口（用于动态调整补兵延迟）
var _recent_kill_intervals: Array = []
var _last_kill_time: float = -1.0
const _KILL_WINDOW_SIZE: int = 5  # 滑动窗口大小

## 平台类型字符串 -> GC.PlatformType 映射
const _PLATFORM_TYPE_MAP: Dictionary = {
	"fortress": 3,
	"titan": 2,
	"raider": 6,
	"siege": 7,
	"striker": 0,
	"sniper": 5,
	"stealth": 10,
	"mage": 1,
}

## 武器类型字符串 -> GC.WeaponType 映射
## 取最接近的 GC 类型（部分敌方武器无精确对应）
const _WEAPON_TYPE_MAP: Dictionary = {
	"machinegun": 2,
	"minigun": 2,
	"machinegun_advanced": 2,
	"cannon": 3,
	"railcannon": 11,
	"flamethrower": 5,
	"mortar": 3,
	"tesla": 2,
	"railgun": 11,
	"lance": 1,
	"gravity": 6,
}
const _ERA_VISUAL_ARCHETYPES: Dictionary = {
	0: ["ww1_inf_mp18", "ww1_arm_rolls_e", "ww1_sup_mg_nest", "ww1_arty_mortar"],
	1: ["ww2_inf_thompson", "ww2_arm_panther_e", "ww2_sup_mg42", "ww2_inf_panzerschreck_e"],
	2: ["cold_inf_ak", "cold_arm_btr_e", "cold_air_m113_e", "cold_inf_m60"],
	3: ["mod_inf_marine", "mod_arm_stryker_e", "mod_arty_mlrs_e", "mod_air_technical_e"],
	4: ["fut_inf_cyborg", "fut_arm_hovertank_e", "fut_arm_mech_e", "fut_air_drone"],
}
## v7.1: 平台类型 → archetype tag 映射（用于选取与平台类型匹配的卡图）
## fortress=要塞/阵地, titan/raider/siege=载具系, striker/sniper/stealth/mage=步兵系
const _PLATFORM_TYPE_TO_TAG: Dictionary = {
	"fortress": "turret",
	"titan": "vehicle",
	"raider": "vehicle",
	"siege": "vehicle",
	"striker": "infantry",
	"sniper": "infantry",
	"stealth": "infantry",
	"mage": "infantry",
}
## v7.3: 平台类型 → 匹配 tag 列表（多 tag 匹配，让 titan 平台也能匹配 tank/armored 精英兵种）
## 相位师产兵优先选高基础值兵种，多 tag 匹配确保 elite/boss 级高HP兵种能被选中。
const _PLATFORM_TYPE_TO_TAGS: Dictionary = {
	"fortress": ["turret", "support"],
	"titan": ["vehicle", "tank", "armored"],
	"raider": ["vehicle", "fast"],
	"siege": ["vehicle", "artillery"],
	"striker": ["infantry", "frontline"],
	"sniper": ["infantry", "elite"],
	"stealth": ["infantry", "fast"],
	"mage": ["infantry", "elite"],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func setup(master_config: Dictionary) -> void:
	stop_production()
	master_name = master_config.get("name", "相位师")
	var era_override: String = String(master_config.get("era", ""))
	if not era_override.is_empty():
		era = _era_string_to_int(era_override)
	else:
		era = _era_from_level(int(master_config.get("level", 15)))
	# v7.x: 读游戏关卡号 → 算时代进度 → 缓存产兵 tier（替代旧"恒定 TIER_HIGH"）
	_game_level = int(master_config.get("game_level", 0))
	if _game_level > 0:
		var era_local_level: int = ((_game_level - 1) % 20) + 1
		_era_progress = clampf(float(era_local_level - 1) / 19.0, 0.0, 1.0)
	else:
		# fallback：无 game_level 时用主等级(5-30)粗映射到 0.0~1.0
		var master_lv: int = int(master_config.get("level", 15))
		_era_progress = clampf(float(master_lv - 5) / 25.0, 0.0, 1.0)
	var _ELT_init = preload("res://data/enemy_loadout_tiers.gd")
	_pm_tier = _ELT_init.get_phase_master_tier(_era_progress)

	## 尝试获取装备数据
	_equipment = master_config.get("equipment", {})
	_master_stats = master_config.get("stats", {})
	# v6.14: 用 EnemyPhaseMasters 程序化派生增强装备（补全 runes / spawn_sequence）。
	# 若 master_config 带 id 且 EnemyPhaseMasters 能查到，则取 enriched equipment。
	var _master_id: String = String(master_config.get("id", ""))
	if not _master_id.is_empty():
		var _enriched: Dictionary = EnemyPhaseMasters.get_enriched_equipment(_master_id)
		if not _enriched.is_empty():
			_equipment = _enriched
	# 缓存派生的 runes / spawn_sequence（供产兵序列和符文加成使用）
	_master_runes = _equipment.get("runes", [])
	_spawn_sequence = _equipment.get("spawn_sequence", [])
	_spawn_seq_index = 0
	# v7.x: 缓存敌方相位仪的主动能力（供 EnemyPhaseInstrumentAbilities 读取）
	_enemy_active_ability = _read_enemy_active_ability()
	# v8.5: 缓存 boss 主动/被动技能（透传自 master_config，供 EnemyMasterSkillEngine 定时触发）
	_boss_active_spells = master_config.get("active_spells", []) if master_config.has("active_spells") else []
	_boss_passive_spells = master_config.get("passive_spells", []) if master_config.has("passive_spells") else []
	_unit_limit = int(_master_stats.get("unit_limit", 5))
	# v7.x: 相位仪战斗卡槽数限制产兵数——"出兵x相位仪，绿槽数y成为限制"。
	# v7.x 统一池：读 slot_counts.green（玩家同款 schema），按星级梯度 1~6（见 _STAR_LAYOUT）。
	# 与 stats.unit_limit 取最小，让低配相位师产兵数更少（战斗卡可高级但数目受限）。
	# 缺省（无 slot_counts / green）时不约束：_cap 回退到 _unit_limit → mini 不改变值。
	var _inst_id_for_cap: String = String(_equipment.get("phase_instrument", ""))
	if not _inst_id_for_cap.is_empty():
		var _inst_cfg_for_cap: Dictionary = EnemyPhaseEquipment.get_phase_instrument(_inst_id_for_cap)
		var _sc: Dictionary = _inst_cfg_for_cap.get("slot_counts", {})
		var _cap: int = int(_sc.get("green", _unit_limit))
		if _cap > 0:
			_unit_limit = mini(_unit_limit, _cap)
	# 格子战场敌方仅 6 个可用槽位（SLOT_COUNT - 1）。数据表 unit_limit 可达 7~15，
	# 超出会导致产兵越过 6 上限、多单位挤同格。统一钳制到格子可用槽位数。
	# 注：master_power_evaluator 直接读原始配置 dict 评分，不受此钳制影响。
	_unit_limit = mini(_unit_limit, BattleSlotGrid.SLOT_COUNT - 1)
	# v7.x: 出兵疲劳阶梯阈值按 _unit_limit 倍数派生（钳制后计算，保证与实际场上容量一致）
	_tier1_cap = _unit_limit * FATIGUE_TIER1_MULT
	_tier2_cap = _unit_limit * FATIGUE_TIER2_MULT
	_exhaustion_cap = _unit_limit * EXHAUSTION_MULT

	if not _equipment.is_empty() and _equipment.has("platforms") and _equipment.has("weapons"):
		_has_equipment = true
		## 使用相位师的属性设定基地 HP
		max_hp = float(_master_stats.get("max_hp", 300.0 + era * 80.0))
		## 能量恢复越高，出兵越快（基础间隔6秒，最低3秒）
		var energy_regen: float = float(_master_stats.get("energy_regen", 2.0))
		spawn_interval = maxf(3.0, 8.0 - energy_regen * 1.0)
	else:
		_has_equipment = false
		max_hp = 300.0 + era * 80.0
		spawn_interval = 6.0

	hp = max_hp
	add_to_group("enemy_phase_driver")
	# 每次重建基地都重置累计召唤计数与疲劳阶梯
	_total_spawned = 0
	_fatigue_tier = 0
	# v9.0: 识别套路 + 初始化补兵系统
	_master_config_cache = master_config
	_pattern_id = MasterPatterns.get_pattern(master_config)
	_pattern_cfg = MasterPatterns.get_pattern_config(_pattern_id)
	_respawn_queue.clear()
	_slot_respawn_counts.clear()
	_recent_kill_intervals.clear()
	_last_kill_time = -1.0
	# v9.0: 连接 unit_died 信号——敌方单位死亡时按套路精准补位
	if SignalBus and not SignalBus.unit_died.is_connected(_on_any_unit_died):
		SignalBus.unit_died.connect(_on_any_unit_died)
	if SignalBus:
		SignalBus.enemy_phase_driver_hp_changed.emit(hp, max_hp)
	var mode_str := "装备模式" if _has_equipment else "经典模式"
	# [LOG-v5.1] print("[EnemyPhaseDriver] 相位师 %s 基地建立 (HP=%d, era=%d, limit=%d, exhaust=%d, interval=%.1f) [%s]" % [master_name, int(max_hp), era, _unit_limit, _exhaustion_cap, spawn_interval, mode_str])
	_apply_body_visual_from_master(master_config)

## v7.x: 从当前装备的相位仪读取 active_ability（供 EnemyPhaseInstrumentAbilities 使用）
func _read_enemy_active_ability() -> Dictionary:
	var inst_id: String = String(_equipment.get("phase_instrument", ""))
	if inst_id.is_empty():
		return {}
	var inst_cfg: Dictionary = EnemyPhaseEquipment.get_phase_instrument(inst_id)
	return inst_cfg.get("active_ability", {}) if not inst_cfg.is_empty() else {}

## v7.x: 暴露给 EnemyPhaseInstrumentAbilities 读取当前敌方相位仪的 active_ability
func get_active_ability() -> Dictionary:
	return _enemy_active_ability

## v8.5: 暴露 boss 主动技能数组（供 EnemyMasterSkillEngine 定时触发）
func get_boss_active_spells() -> Array:
	return _boss_active_spells

## v8.5: 暴露 boss 被动技能数组（事件触发型，如死亡爆炸/复活）
func get_boss_passive_spells() -> Array:
	return _boss_passive_spells

## v8.5: 暴露 boss 属性表（max_hp/attack_power/defense/...）供 EnemyMasterSkillEngine 派生技能伤害。
## _master_stats 是私有字段（无 public stats 属性），engine 旧代码 _driver.get("stats") 恒 null，
## 导致 _compute_boss_damage 永远走 max_hp×0.05 fallback，attack_power 从不生效。
func get_master_stats() -> Dictionary:
	return _master_stats

func _apply_body_visual_from_master(master_config: Dictionary) -> void:
	var spr := get_node_or_null("Body") as Sprite2D
	if spr == null:
		return
	# 底座在战场右侧，贴图若按「朝右」绘制则需翻转以面向道路 / 我方
	spr.flip_h = true
	var ef: String = String(master_config.get("enemy_faction", ""))
	if ef.is_empty():
		ef = _player_company_faction_to_enemy_visual_faction(String(master_config.get("faction", "")))
	var tints: Dictionary = {
		"steel": Color(0.82, 0.88, 1.0),
		"flame": Color(1.0, 0.78, 0.72),
		"thunder": Color(0.88, 0.84, 1.0),
		"void": Color(0.86, 0.76, 1.0),
	}
	spr.modulate = tints.get(ef, Color.WHITE)
	# 缓存原始 tint，供出兵疲劳阶梯视觉反馈叠加暗化使用
	_base_body_tint = spr.modulate
	# 缩放：与当前时代下「默认可用敌方原型」同一套 visual_scale 数据（见 _pick_visual_archetype_for_era）
	var tex: Texture2D = spr.texture
	if tex != null:
		var ref_arch: String = _pick_visual_archetype_for_era(era)
		var vs: float = 0.4
		if not ref_arch.is_empty():
			var cfg_r: Dictionary = EnemyArchetypes.get_config(ref_arch)
			vs = EnemyArchetypes.get_visual_scale_for_archetype(ref_arch, cfg_r)
		var tex_max: float = maxf(float(tex.get_width()), float(tex.get_height()))
		var s: float = (vs * _PHASE_BODY_REFERENCE_FRAME_PX) / maxf(1.0, tex_max)
		var rendered: float = tex_max * s
		if rendered > _PHASE_BODY_MAX_EXTENT_PX:
			s *= _PHASE_BODY_MAX_EXTENT_PX / maxf(1.0, rendered)
		spr.scale = Vector2(s, s)


static func _player_company_faction_to_enemy_visual_faction(company_faction: String) -> String:
	var m: Dictionary = {
		"aether_dynamics": "steel",
		"helix_recon": "thunder",
		"nova_arms": "flame",
		"iron_wall_corp": "steel",
		"void_research": "void",
		"quantum_logistics": "steel",
		"frontier_union": "thunder",
	}
	return String(m.get(company_faction, company_faction))

func start_production() -> void:
	if _battle_active:
		return
	_battle_active = true
	_spawn_timer = 3.0  # 首次出兵在3秒后

func stop_production() -> void:
	_battle_active = false

## v8.5: 强制立即产兵一次（补满到 unit_limit）。供 EnemyMasterSkillEngine 召唤类技能调用。
## 格子战约束：敌方槽位上限 6，补满即止，不会越界。
## v9.1c 修复：召唤技能也受疲劳系统约束——枯竭（_fatigue_tier>=3）或总召唤数超上限时停止，
## 防止 boss 无限召唤导致玩家永远打不完。原实现 force_produce_once 绕过疲劳系统，
## 即使 _process 定时产兵已停，boss 召唤技能仍每 CD 补满，造成"一直召唤"问题。
func force_produce_once() -> void:
	if not is_instance_valid(self):
		return
	# 疲劳守卫：枯竭后停止召唤（与 _process 定时产兵一致）
	if _fatigue_tier >= 3:
		return
	# 总召唤数守卫：超 exhaustion_cap 后不再召唤（防 boss 技能绕过疲劳无限补兵）
	if _total_spawned >= _exhaustion_cap:
		return
	_produce_unit()

## v8.5: 由 BattleManager 注入技能引擎引用（用于死亡时触发死亡类被动）
func set_master_skill_engine(engine: RefCounted) -> void:
	_master_skill_engine = engine

func _process(delta: float) -> void:
	if _body != null:
		_body.rotation += deg_to_rad(rotate_speed_deg) * delta
	if not _battle_active or not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.paused:
		return
	_spawn_timer += delta
	# v9.0: 套路补兵队列处理（单位死亡后按套路精准补位，独立于波次产兵）
	_process_respawn_queue()
	# 枯竭后彻底停止产兵（_fatigue_tier >= 3），玩家只需专注输出基地 HP
	if _fatigue_tier >= 3:
		return
	var interval: float = _get_current_spawn_interval()
	if _spawn_timer >= interval:
		_spawn_timer = 0.0
		_produce_unit()

## 按当前疲劳阶梯返回产兵间隔：正常=spawn_interval, 轻度疲劳=18s, 重度疲劳=30s。
## 枯竭(tier>=3)由 _process 短路，不会走到这里。
func _get_current_spawn_interval() -> float:
	match _fatigue_tier:
		2: return HEAVY_FATIGUE_INTERVAL
		1: return FATIGUED_SPAWN_INTERVAL
		_: return spawn_interval


# ============================ v8: 反应式 AI ============================
# 相位师侦测玩家场上主力兵种（combat_kind 分布），按概率出克制兵。
# 克制关系复用 enemy_stat_resolver 的 combat_kind→三维攻击比例：
#   玩家多 ARMOR  → 出 SUPPORT/FORT（对装甲强 1.2~1.3x）
#   玩家多 AIR    → 出 AIR（对空中强 1.0x，其他兵种对空弱 0.2~0.3x）
#   玩家多 LIGHT  → 出 ARMOR（对轻装 0.7x 但血厚碾压）/ FORT（对轻 0.5x 但阵地硬）
#   SUPPORT/FORT 在攻防维度归 ARMOR/LIGHT，不单独处理

## 统计玩家场上各 combat_kind 的单位数量。返回 {combat_kind_int: count}。
func _tally_player_combat_kinds() -> Dictionary:
	var tally: Dictionary = {}
	if BattleManager == null:
		return tally
	var gr: Array = BattleManager.get_cached_nodes_in_group("player_units")
	for n in gr:
		if n == null or not is_instance_valid(n):
			continue
		var s = n.get("stats")
		if s == null:
			continue
		var ck: int = int(s.combat_kind)
		tally[ck] = int(tally.get(ck, 0)) + 1
	return tally


## 找出玩家主力 combat_kind（数量最多；并列取 CombatKind 枚举值小的）。
func _dominant_player_kind(tally: Dictionary) -> int:
	var best_kind: int = -1
	var best_count: int = 0
	for ck in tally:
		var cnt: int = int(tally[ck])
		if cnt > best_count or (cnt == best_count and (best_kind < 0 or int(ck) < best_kind)):
			best_count = cnt
			best_kind = int(ck)
	return best_kind


## 反查克制表：给定玩家主力 kind，返回应出的克制 combat_kind。
## 返回 -1 表示无明确克制（回退原序列）。
func _counter_kind_for(player_kind: int) -> int:
	match player_kind:
		GC.CombatKind.ARMOR:
			# 玩家堆装甲 → 出反坦克（SUPPORT 对装甲 1.2x 或 FORT 1.3x）
			# 优先 SUPPORT（可移动推进），FORT 作备选
			return GC.CombatKind.SUPPORT
		GC.CombatKind.AIR:
			# 玩家堆空军 → 出空军对空（其他兵种对空太弱 0.2~0.3x）
			return GC.CombatKind.AIR
		GC.CombatKind.LIGHT:
			# 玩家堆轻装步兵 → 出装甲碾压（血厚+对轻 0.7x 仍能打）
			return GC.CombatKind.ARMOR
		GC.CombatKind.SUPPORT:
			# 玩家堆支援/炮兵 → 出装甲冲锋（支援对装甲弱，直接贴脸）
			return GC.CombatKind.ARMOR
		GC.CombatKind.FORT:
			# 玩家堆堡垒 → 出 SUPPORT/FORT 反阵地
			return GC.CombatKind.SUPPORT
	return -1


## 反应式选 platform：按 reactive_chance 概率，从 valid_platforms 中筛出
## combat_kind 匹配克制关系的候选。返回选中的 platform_id；不触发或无候选时返回 ""。
func _pick_reactive_platform(valid_platforms: Array, reactive_chance: float) -> String:
	if randf() > reactive_chance:
		return ""
	var tally: Dictionary = _tally_player_combat_kinds()
	if tally.is_empty():
		return ""
	var dom_kind: int = _dominant_player_kind(tally)
	if dom_kind < 0:
		return ""
	var target_kind: int = _counter_kind_for(dom_kind)
	if target_kind < 0:
		return ""
	# 在 valid_platforms 中筛出 combat_kind 匹配的候选
	var matched: Array = []
	for pid in valid_platforms:
		var pid_str := String(pid)
		var arch_cfg := EnemyArchetypes.get_config(pid_str)
		if arch_cfg.is_empty():
			continue
		var ck: int = int(arch_cfg.get("combat_kind", -1))
		# v6.8: tags 含 aircraft 的判为 AIR（与 enemy_stat_resolver 口径一致）
		var tags: Array = arch_cfg.get("tags", [])
		if ck != GC.CombatKind.AIR and tags.has("aircraft"):
			ck = GC.CombatKind.AIR
		if ck == target_kind:
			matched.append(pid_str)
	# 克制候选为空时尝试备选 kind（SUPPORT↔FORT 互通，都对装甲强）
	if matched.is_empty() and target_kind == GC.CombatKind.SUPPORT:
		for pid in valid_platforms:
			var pid_str := String(pid)
			var arch_cfg := EnemyArchetypes.get_config(pid_str)
			if not arch_cfg.is_empty() and int(arch_cfg.get("combat_kind", -1)) == GC.CombatKind.FORT:
				matched.append(pid_str)
	if matched.is_empty():
		return ""
	return String(matched[randi() % matched.size()])


## 从装备数据生成单位（使用 ConstructUnit）。
## override_platform_id（v9.0）：非空时强制用该平台产兵（套路补位"那个兵掉了补那个兵"），
## 空时走 spawn_sequence + 反应式 AI 选平台（原逻辑）。
func _produce_unit_with_equipment(override_platform_id: String = "") -> void:
	if not BattleManager:
		return
	var current_count: int = BattleManager.get_enemy_unit_count()
	if current_count >= _unit_limit:
		return

	var platforms: Array = _equipment.get("platforms", [])
	var weapons: Array = _equipment.get("weapons", [])
	if platforms.is_empty():
		return

	# v7.x: platforms 字段现在直接存 archetype id（旧平台卡层已删除）。
	# 兼容回退：若 id 在 EnemyArchetypes 查不到 cfg，再尝试当平台卡 id 查（_legacy_platforms 路径）。
	var valid_platforms: Array = []
	var direct_archetype_ids: Dictionary = {}  # pid -> archetype_id（直引模式）
	var legacy_platform_ids: Array = []         # 旧平台卡模式
	for pid in platforms:
		var pid_str := String(pid)
		var arch_cfg := EnemyArchetypes.get_config(pid_str)
		if not arch_cfg.is_empty():
			# 直引 archetype 模式
			valid_platforms.append(pid_str)
			direct_archetype_ids[pid_str] = pid_str
		else:
			var pdata := EnemyPhaseEquipment.get_war_platform(pid_str)
			if not pdata.is_empty():
				valid_platforms.append(pid_str)
				legacy_platform_ids.append(pid_str)

	if valid_platforms.is_empty():
		return

	# v9.0: 套路补位优先——override_platform_id 非空时直接用该平台（"那个兵掉了补那个兵"）。
	# 仅 override 无效/为空时才走 spawn_sequence + 反应式 AI 原逻辑。
	var platform_id: String = ""
	var seq_entry_type: String = "normal"
	if not override_platform_id.is_empty() and valid_platforms.has(override_platform_id):
		platform_id = override_platform_id
		# override 补位走 normal 类型（不走 elite/boss 序列标记，避免重复加成）
		seq_entry_type = "normal"
	elif not _spawn_sequence.is_empty():
		# v6.14: 按 spawn_sequence 序列选平台（替代纯随机），序列耗尽则循环。
		var entry: Dictionary = _spawn_sequence[_spawn_seq_index % _spawn_sequence.size()]
		_spawn_seq_index += 1
		platform_id = String(entry.get("platform", ""))
		seq_entry_type = String(entry.get("type", "normal"))
		# 验证平台有效（序列里的平台可能不在 valid_platforms，回退随机）
		if not valid_platforms.has(platform_id):
			platform_id = String(valid_platforms[randi() % valid_platforms.size()])
	else:
		platform_id = String(valid_platforms[randi() % valid_platforms.size()])

	# v8: 反应式 AI——相位师侦测玩家主力兵种，按概率出克制兵。
	# 70% 概率覆盖序列选择为克制玩家主力 combat_kind 的 platform；30% 保留原序列（维持出兵节奏）。
	# v9.0: override 补位时跳过反应式 AI（精准补位优先于反制）。
	if override_platform_id.is_empty() and valid_platforms.size() > 1:
		# valid_platforms 池中无克制候选时回退原选择（向后兼容）。
		# entry 的 reactive_chance 字段（可选）可覆盖默认 0.7 概率，让不同相位师有不同"聪明度"。
		var reactive_chance: float = 0.7
		if not _spawn_sequence.is_empty():
			var cur_entry: Dictionary = _spawn_sequence[(_spawn_seq_index - 1) % _spawn_sequence.size()]
			reactive_chance = float(cur_entry.get("reactive_chance", 0.7))
		var reactive_pick: String = _pick_reactive_platform(valid_platforms, reactive_chance)
		if not reactive_pick.is_empty():
			platform_id = reactive_pick

	# v7.x: 分流——直引 archetype vs 旧平台卡
	var direct_archetype_id: String = String(direct_archetype_ids.get(platform_id, ""))
	var platform_data: Dictionary = {}
	if direct_archetype_id.is_empty():
		# 旧平台卡模式：查平台数据
		platform_data = EnemyPhaseEquipment.get_war_platform(platform_id)
		if platform_data.is_empty():
			return

	## 平台卡默认武器（非随机）；表无字段时在装备武器列表中按 id 排序取首项作为确定性回退
	var wt_int: int = -1
	var weapon_types: Array = []
	var platform_type_int: int = -1
	var platform_type_str: String = ""
	var direct_cfg: Dictionary = {}
	if not direct_archetype_id.is_empty():
		# v7.x 直引 archetype 模式：武器/平台类型从 archetype cfg 推导，跳过平台卡/武器表查询。
		direct_cfg = EnemyArchetypes.get_config(direct_archetype_id)
		var legacy_wt: int = int(direct_cfg.get("weapon_type", 1))
		wt_int = _legacy_weapon_to_new_weapon_type(legacy_wt, direct_cfg)
		if wt_int < 0:
			return
		weapon_types = [legacy_wt]  # build_stats_from_archetype 内部读 legacy 值
		# platform_type 由 archetype 的 tags 推导（复用 _archetype_combat_kind 的 tag 判断）
		platform_type_int = _archetype_combat_kind(direct_cfg, 1)
		platform_type_str = ""  # 直引模式不依赖平台 type 字符串
	else:
		# 旧平台卡模式（_legacy_platforms 回退）：武器走平台默认武器 + 装备武器列表
		var wid: String = EnemyPhaseEquipment.get_default_weapon_id_for_platform(platform_id)
		if wid.is_empty():
			if weapons.is_empty():
				return
			var sorted_w: Array = weapons.duplicate()
			sorted_w.sort()
			wid = String(sorted_w[0])
		var wdata: Dictionary = EnemyPhaseEquipment.get_war_weapon(wid)
		if wdata.is_empty():
			return
		wt_int = _map_weapon_type(wdata.get("type", ""))
		if wt_int < 0:
			return
		weapon_types = [wt_int]
		## 映射平台类型
		platform_type_str = String(platform_data.get("type", ""))
		platform_type_int = _map_platform_type(platform_type_str)
		if platform_type_int < 0:
			return

	## 构建 UnitStats
	# v7.x: 直引 archetype 时直接用该 archetype cfg；旧平台卡模式复用 _pick_visual_archetype_for_platform 映射。
	# 让敌方产兵强度对齐同类型真实敌人；archetype 查不到时回退通用表（永不破坏游戏）。
	var stats: UnitStats = _build_stats_from_archetype(era, platform_type_str, platform_type_int, weapon_types, direct_archetype_id)

	# v7.3: 移除平台 stats 对 HP/defense/move_speed 的覆写。
	# 原逻辑用 platform.stats（如 steel_titan_expert.hp=3500/defense=200）覆写真实 archetype 值，
	# 但 platform.stats 是"平台作为可部署防御工事"的设计值（几千），用在"产兵"上语义错配，
	# 导致产兵 HP 失控（第49关单个产兵 HP 达 7400~11000，是同关普通敌兵 ~186 的 40~60 倍）。
	# v6.12"用真实 archetype 数据"的意图被此覆写抵消。现移除覆写，产兵 HP/防御/速度
	# 全部使用 _build_stats_from_archetype 构建的真实 archetype 值（如 cold_arm_btr_e hp=120），
	# 与普通波次敌兵对齐量级。master_stats/战场难度/符文/相位仪/序列等加成乘区不变。
	# platform_data 仍用于：平台类型判定（_map_platform_type）、视觉 archetype 选取（_pick_visual_archetype_for_platform）、
	# 以及 platform_id 记录（stats.platform_card_id）。平台间的差异化由这些维度 + master 装备配置体现。

	# v7.x(敌方加成来源明细): 产兵 7 层加成明细收集。
	# 策略：每步加成前后记录 stats.max_hp / attack_damage / defense 的值，用前后比值作为该步倍率。
	# 比从配置反算更准确（与实际应用的数值完全一致，含各种 maxf 保护后的真实值）。
	var _sb_base_hp: float = float(stats.max_hp)
	var _sb_base_atk: float = float(stats.attack_damage)
	var _sb_base_def: float = float(stats.defense)
	var _sb_sources: Array = []
	var _sb_hp_before: float = _sb_base_hp
	var _sb_atk_before: float = _sb_base_atk
	var _sb_def_before: float = _sb_base_def

	# v8.2 简化：产兵乘区收敛为 4 个 —— 符文 × boss波序列 × 相位仪 × 配档(高档)。
	# 砍掉的旧乘区：master_stats（apply_phase_master_to_unit_stats）、战场难度（wave/level/faction，
	# 即 apply_field_multipliers_to_unit_stats）、精英词缀（roll_affixes）。
	# base 属性已含时代递进，产兵不再吃经典敌兵的难度链；高档位+相位仪+符文+boss波已体现 boss 强度。

	# 乘区1：符文加成 —— master 自带符文的 primary_effect 应用到产兵 stats。
	_apply_master_rune_bonus(stats)
	_sb_sources = _record_spawn_step(_sb_sources, "符文", _sb_hp_before, _sb_atk_before, _sb_def_before, stats)
	_sb_hp_before = float(stats.max_hp)
	_sb_atk_before = float(stats.attack_damage)
	_sb_def_before = float(stats.defense)
	# 乘区2：出兵序列 elite/boss 标记加成 —— elite +25%攻/血，boss +50%，普通×1.0。
	_apply_sequence_entry_bonus(stats, seq_entry_type)
	var _seq_label: String = "出兵序列(%s)" % (seq_entry_type if not seq_entry_type.is_empty() else "普通")
	_sb_sources = _record_spawn_step(_sb_sources, _seq_label, _sb_hp_before, _sb_atk_before, _sb_def_before, stats)
	_sb_hp_before = float(stats.max_hp)
	_sb_atk_before = float(stats.attack_damage)
	_sb_def_before = float(stats.defense)
	# 乘区3：相位师相位仪加成 —— pi_atk/pi_def/pi_hp。
	_apply_enemy_phase_instrument_bonus(stats)
	_sb_sources = _record_spawn_step(_sb_sources, "相位仪", _sb_hp_before, _sb_atk_before, _sb_def_before, stats)
	_sb_hp_before = float(stats.max_hp)
	_sb_atk_before = float(stats.attack_damage)
	_sb_def_before = float(stats.defense)
	# 乘区4：配档加成（高档位 atk+100%/hp+100%/def+100%，即×2.0）。
	# EnemyLoadoutTiers.TIER_MODIFICATIONS 里的改造ID 未注册，故用 TIER_BONUS 数值直接乘。
	# 配合 _build_stats_from_archetype 的 enhance_level（按同 tier 派生），产兵达成对称平衡。
	var _ELT = preload("res://data/enemy_loadout_tiers.gd")
	var _pm_bonus: Dictionary = _ELT.get_bonus_for_tier(_pm_tier)
	var _tier_hp: float = float(_pm_bonus.get("hp_pct", 0.0))
	var _tier_atk: float = float(_pm_bonus.get("atk_pct", 0.0))
	var _tier_def: float = float(_pm_bonus.get("def_pct", 0.0))
	if _tier_hp > 0.0:
		stats.max_hp = maxf(1.0, stats.max_hp * (1.0 + _tier_hp))
	if _tier_atk > 0.0:
		# v8.x 修复：attack_damage 是 attack_light 的 getter/setter 别名（unit_stats.gd:22-28），
		# 与 attack_light 同乘会让 attack_light 被乘两次（实际 ×mult²）。
		# 原 bug 导致第49关产兵 attack_light ≈ 9000（应为 ~2150）。
		stats.attack_light = maxf(0.1, stats.attack_light * (1.0 + _tier_atk))
		stats.attack_armor = maxf(0.1, stats.attack_armor * (1.0 + _tier_atk))
		stats.attack_air = maxf(0.1, stats.attack_air * (1.0 + _tier_atk))
		# v7.x H2: 同步武器槽伤害。
		_sync_enemy_weapon_slot_damage(stats, 1.0 + _tier_atk)
	if _tier_def > 0.0:
		stats.defense = maxf(0.0, stats.defense * (1.0 + _tier_def))
		stats.defense_light = maxf(0.0, stats.defense_light * (1.0 + _tier_def))
		stats.defense_armor = maxf(0.0, stats.defense_armor * (1.0 + _tier_def))
		stats.defense_air = maxf(0.0, stats.defense_air * (1.0 + _tier_def))
	var _tier_name: String = str(_pm_bonus.get("name", _pm_tier))
	_sb_sources = _record_spawn_step(_sb_sources, "配档(%s)" % _tier_name, _sb_hp_before, _sb_atk_before, _sb_def_before, stats)
	stats.platform_card_id = platform_id

	## v8.x boss 唯一性限制：同名 boss 单位战场上只能存在 1 个
	# 提前计算 visual_archetype_id（供 boss 检查 + 后续 ConstructUnit 初始化共用）
	var visual_archetype_id: String = ""
	if not direct_archetype_id.is_empty():
		visual_archetype_id = direct_archetype_id
	else:
		visual_archetype_id = _pick_visual_archetype_for_platform(era, platform_type_str)
	# 确定实际 archetype（直引模式用 direct_archetype_id；旧平台卡回退 visual）
	var effective_archetype: String = direct_archetype_id if not direct_archetype_id.is_empty() else visual_archetype_id
	var _is_boss: bool = false
	if not effective_archetype.is_empty():
		var _e_cfg = EnemyArchetypes.get_config(effective_archetype)
		_is_boss = _e_cfg.get("tags", []).has("boss")
	if _is_boss and _effective_archetype_exists_on_field(effective_archetype):
		return  # 场上已有同名 boss，跳过本次产兵

	## 生成 ConstructUnit
	var unit: Node2D = ConstructUnitScene.instantiate()
	if unit.has_method("setup_with_enemy_visual"):
		unit.setup_with_enemy_visual(false, stats, visual_archetype_id)
	else:
		unit.setup(false, stats)
	# v8.x boss 唯一性：记录 archetype_id 到 meta，供后续 boss 数量统计（ConstructUnit 无 archetype_id 裸字段）
	if not effective_archetype.is_empty():
		unit.set_meta("archetype_id", effective_archetype)
	# v9.0 fix: 记录产兵用的 platform_id 到 meta，供套路补兵"同款优先"精准匹配。
	# 直引模式下 platform_id == archetype_id，旧平台卡模式下两者不同（archetype_id 是视觉 archetype，
	# platform_id 才是产兵来源）。补兵时优先读 spawn_platform_id，避免旧平台卡模式下规则1 失效。
	unit.set_meta("spawn_platform_id", platform_id)
	# v7.x(敌方加成来源明细): 把产兵 7 层加成明细挂到单位 meta，供情报面板显示。
	# base 取 _build_stats_from_archetype 后的值（含 enhance_level，未乘任何战场加成）；
	# final 取乘完所有加成后的 stats 值；total_*_mul = base→final 的总比值。
	var _sb_total_hp: float = _safe_ratio(float(stats.max_hp), _sb_base_hp)
	var _sb_total_atk: float = _safe_ratio(float(stats.attack_damage), _sb_base_atk)
	unit.set_meta("enemy_bonus_breakdown", {
		"base_hp": _sb_base_hp,
		"base_atk": _sb_base_atk,
		"base_def": _sb_base_def,
		"final_hp": float(stats.max_hp),
		"final_atk": float(stats.attack_damage),
		"final_def": float(stats.defense),
		"sources": _sb_sources,
		"ng_plus": 1.0,            # 产兵无二周目加成
		"total_hp_mul": _sb_total_hp,
		"total_atk_mul": _sb_total_atk,
		"kind": "spawn",
	})
	# v7.x: 敌方产兵也有布置时间——入战后启动部署虚影（与我方对称，复用 calculate_deploy_delay 公式）。
	# 部署期间半透明、不动、不开火，可被攻击；is_deploy_ghost 字段被 battle_manager 鸭子识别，
	# 部署期不计入存活数（不影响产兵上限与胜负判定）。
	if unit.has_method("start_as_deploy_ghost"):
		unit.start_as_deploy_ghost()
	if _add_unit_to_battle(unit, current_count):
		_record_spawn_and_check_fatigue()

## 兜底：使用经典 EnemyArchetypes 生成
func _produce_unit_fallback() -> void:
	if not BattleManager:
		return
	var current_count: int = BattleManager.get_enemy_unit_count()
	if current_count >= _unit_limit:
		return
	var parent = get_parent()
	if parent == null:
		return
	var era_ids: Array = EnemyArchetypes.get_ids_for_era(era)
	if era_ids.is_empty():
		return
	var archetype_id: String = String(era_ids[randi() % era_ids.size()])
	var wave_idx: int = 0
	if BattleManager != null and BattleManager.has_method("get_enemy_wave_index"):
		wave_idx = BattleManager.get_enemy_wave_index()
	var unit = EnemyUnitScene.instantiate()
	unit.setup(false, wave_idx, archetype_id)
	if _add_unit_to_battle(unit, current_count):
		_record_spawn_and_check_fatigue()

func _produce_unit() -> void:
	# v7.x: 一次产满全部槽位（而非每次1个）。相位师开局直接上场6个单位，
	# 之后等场上单位阵亡后再补满。这样战斗节奏更紧凑，玩家面对的是完整波次的压力。
	var attempts: int = 0
	while attempts < _unit_limit:
		attempts += 1
		if _has_equipment:
			_produce_unit_with_equipment()
		elif USE_FALLBACK_SPAWN:
			_produce_unit_fallback()
		# 检查是否已满——每次产兵后重新判断，避免一口气出太多
		var current_count: int = BattleManager.get_enemy_unit_count() if BattleManager else 0
		if current_count >= _unit_limit:
			break

## 返回 true 表示单位已成功进入战场（用于累计召唤计数）；false 表示场地已满被丢弃。
func _add_unit_to_battle(unit: Node2D, current_count: int) -> bool:
	if BattleManager != null and BattleManager.has_method("spawn_enemy_unit_on_card_grid"):
		if BattleManager.spawn_enemy_unit_on_card_grid(unit):
			return true
	# 主路径返回 false 通常意味着场地已满（enemy_unit_count >= 6）。
	# 不应继续产兵，否则会越过 6 上限、导致多单位挤同格。
	var field_cap: int = BattleSlotGrid.SLOT_COUNT - 1
	if current_count >= field_cap:
		if is_instance_valid(unit):
			unit.queue_free()
		return false
	var battlefield_node: Node = get_parent()
	if battlefield_node == null:
		return false
	var enemy_container: Node = battlefield_node.get_node_or_null("EnemyUnits")
	if enemy_container == null and BattleManager and "enemy_units_node" in BattleManager:
		enemy_container = BattleManager.enemy_units_node
	if enemy_container == null:
		enemy_container = battlefield_node
	enemy_container.add_child(unit)
	# 回退路径：扫描实际占用，选真正空闲的敌槽（与 spawn_system._card_grid_next_free_enemy_slot_index 对齐）。
	# 旧实现用 current_count % SLOT_COUNT 推算 slot，不做占用检查——当主路径因 battle_active 不同步 /
	# cap 满 / 槽满而返回 false 时，推算出的 slot 会撞上已占用槽，导致两单位 meta 相同、被吸附到同一点
	# （表现为"同一位置刷新两张牌"）。
	var slot_i: int = _fallback_pick_free_enemy_slot()
	if battlefield_node.has_method("get_card_grid_enemy_slot_global"):
		unit.global_position = battlefield_node.get_card_grid_enemy_slot_global(slot_i)
		unit.set_meta("card_grid_enemy_slot", slot_i)
	elif battlefield_node.has_method("get_enemy_spawn_position_in_lane"):
		var lane_off: float = float(slot_i) * 18.0 - 72.0
		unit.global_position = battlefield_node.get_enemy_spawn_position_in_lane(15.0, 10.0) + Vector2(lane_off, 0.0)
	if unit.has_method("apply_card_grid_enemy_presentation"):
		unit.apply_card_grid_enemy_presentation()
	BattleManager.set_enemy_unit_count(current_count + 1)
	if SignalBus:
		SignalBus.unit_spawned.emit(unit, false)
	# v7.x: 敌方布置时间——回退路径（非格子战/主路径失败）的 EnemyUnit 同样启动部署虚影。
	# ConstructUnit 在 _produce_unit_with_equipment 已调过 start_as_deploy_ghost，此处守卫跳过重复触发。
	if unit.has_method("start_as_deploy_ghost") and not (unit.get("is_deploy_ghost") if "is_deploy_ghost" in unit else false):
		unit.start_as_deploy_ghost()
	return true


## 单位成功进入战场后累计召唤计数；按阶梯阈值推进 _fatigue_tier（0→1→2→3 枯竭停止）。
func _record_spawn_and_check_fatigue() -> void:
	_total_spawned += 1
	var old_tier := _fatigue_tier
	if _total_spawned >= _exhaustion_cap:
		_fatigue_tier = 3
	elif _total_spawned >= _tier2_cap:
		_fatigue_tier = 2
	elif _total_spawned >= _tier1_cap:
		_fatigue_tier = 1
	if _fatigue_tier > old_tier:
		_spawn_timer = 0.0  # 阶梯跃迁重置计时器，让新间隔从现在起算
		_on_fatigue_tier_changed(_fatigue_tier)

## 疲劳阶梯跃迁反馈：视觉暗化（兵力流失感）+ Toast 提示玩家。
func _on_fatigue_tier_changed(tier: int) -> void:
	_apply_fatigue_visual(tier)
	if SignalBus == null:
		return
	var msg: String = ""
	match tier:
		1: msg = "敌方相位师兵力告急，出兵减缓！"
		2: msg = "敌方相位师兵力枯竭，出兵大幅减缓！"
		3: msg = "敌方相位师弹尽粮绝，停止出兵！集中火力攻击！"
		_: return
	if not msg.is_empty():
		SignalBus.show_toast.emit(msg)

## 按 _fatigue_tier 在原始阵营 tint 基础上叠加暗化偏红，体现兵力流失。
func _apply_fatigue_visual(tier: int) -> void:
	var spr := get_node_or_null("Body") as Sprite2D
	if spr == null:
		return
	var base: Color = _base_body_tint
	match tier:
		0: spr.modulate = base
		1: spr.modulate = base.lerp(Color(0.5, 0.3, 0.3), 0.35)
		2: spr.modulate = base.lerp(Color(0.35, 0.2, 0.2), 0.55)
		3: spr.modulate = base.lerp(Color(0.2, 0.1, 0.1), 0.7)

# ============================ v9.0 套路补兵系统 ============================
# 核心流程：敌方单位死亡 → unit_died 信号 → _on_any_unit_died 判定是否该补位
#   → 入 _respawn_queue（带 due_time）→ _process 每 tick 检查 due_time 到点 → 补位产兵。
# 补位规则："那个兵掉了补那个兵"——优先补同款 archetype；池中无同款才退套路 preferred 选兵。
# 补兵频率随玩家击杀速度动态调整（杀得快→延迟拉长，杀得慢→延迟缩短）。

## unit_died 信号回调：仅处理敌方单位死亡。
func _on_any_unit_died(unit: Node, is_player: bool) -> void:
	if is_player:
		return   # 玩家单位死亡不管
	# v9.0 同时记录玩家击杀速度（用于动态调整补兵延迟）——仅当死因有玩家攻击者时
	_record_kill_interval()
	if _pattern_id == MasterPatterns.PATTERN_NONE:
		return   # 未识别套路：走原波次补兵，不套路补位
	if _fatigue_tier >= 3:
		return   # 弹尽粮绝：不再补兵
	_schedule_respawn_for_dead_unit(unit)

## 记录玩家击杀间隔（滑动窗口），供 compute_respawn_delay 用。
func _record_kill_interval() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if _last_kill_time > 0.0:
		var interval: float = now - _last_kill_time
		if interval > 0.0 and interval < 120.0:   # 过滤异常值（战斗中断/暂停）
			_recent_kill_intervals.append(interval)
			if _recent_kill_intervals.size() > _KILL_WINDOW_SIZE:
				_recent_kill_intervals.pop_front()
	_last_kill_time = now

## 单位死亡时判定是否补位 + 入队。
func _schedule_respawn_for_dead_unit(dead_unit: Node) -> void:
	if dead_unit == null:
		return
	# v9.0 fix: 取死亡单位的产兵来源 platform_id（套路补位"那个兵掉了补那个兵"的关键）。
	# 优先读 spawn_platform_id meta（产兵时写入，直引/旧平台卡模式都准），
	# 回退 archetype_id（兼容无 spawn_platform_id 的老单位/经典模式产兵）。
	var dead_arch: String = ""
	if dead_unit.has_meta("spawn_platform_id"):
		dead_arch = String(dead_unit.get_meta("spawn_platform_id"))
	if dead_arch.is_empty():
		if "archetype_id" in dead_unit:
			dead_arch = String(dead_unit.archetype_id)
		elif dead_unit.has_meta("archetype_id"):
			dead_arch = String(dead_unit.get_meta("archetype_id"))
	# 取槽位（用于 max_respawns_per_slot 计数）
	var slot_i: int = -1
	if "card_grid_enemy_slot" in dead_unit:
		slot_i = int(dead_unit.card_grid_enemy_slot)
	elif dead_unit.has_meta("card_grid_enemy_slot"):
		slot_i = int(dead_unit.get_meta("card_grid_enemy_slot"))
	# 槽位补兵次数上限检查（鼓励玩家速杀，超过上限该槽永久留空）
	if slot_i >= 0:
		var count: int = int(_slot_respawn_counts.get(slot_i, 0))
		var max_r: int = int(_pattern_cfg.get("max_respawns_per_slot", 3))
		if count >= max_r:
			return   # 该槽已补满次数上限，不再补
	# 计算补兵延迟（随玩家击杀速度动态调整）
	var delay: float = MasterPatterns.compute_respawn_delay(_pattern_id, _recent_kill_intervals)
	# 取 combat_kind（套路 preferred 选兵兜底用）
	var dead_kind: int = -1
	var stats_v: Variant = dead_unit.get("stats") if "stats" in dead_unit else null
	if stats_v != null and "combat_kind" in stats_v:
		dead_kind = int(stats_v.combat_kind)
	# 入队
	_respawn_queue.append({
		"dead_arch": dead_arch,
		"dead_kind": dead_kind,
		"slot_index": slot_i,
		"due_time": Time.get_ticks_msec() / 1000.0 + delay,
		"delay": delay,
	})

## 每 tick 检查补兵队列：到点的补位任务立即执行补兵。
func _process_respawn_queue() -> void:
	if _respawn_queue.is_empty():
		return
	if not _has_equipment:
		return   # 无装备模式不支持套路补兵（走经典 fallback 产兵）
	var now: float = Time.get_ticks_msec() / 1000.0
	# 场上单位已满时不补（避免越界 6 上限）
	if BattleManager and BattleManager.get_enemy_unit_count() >= _unit_limit:
		return
	var i: int = 0
	while i < _respawn_queue.size():
		var task: Dictionary = _respawn_queue[i]
		if float(task.get("due_time", now)) <= now:
			# 到点：先记录产兵前数量，用于判断是否真的补成功
			var count_before: int = BattleManager.get_enemy_unit_count() if BattleManager else 0
			_respawn_queue.remove_at(i)
			var spawned: bool = _do_respawn(task)
			if not spawned:
				# v9.0 fix: 产兵失败（场上满/平台池空/valid_platforms 空等）→ 任务不能直接丢弃，
				# 否则死亡的单位永久不补。改为推后 due_time 重新入队重试（最多 3 次，防卡队列）。
				var retries: int = int(task.get("retries", 0)) + 1
				if retries <= 3 and count_before < _unit_limit:
					task["retries"] = retries
					task["due_time"] = now + 0.5   # 0.5s 后重试
					_respawn_queue.append(task)
			# 补兵后若场上满则停（一次 tick 只补一个，避免瞬间刷出多个）
			if BattleManager and BattleManager.get_enemy_unit_count() >= _unit_limit:
				break
		else:
			i += 1

## 执行单个补兵任务：按套路选平台 + 调 _produce_unit_with_equipment(override)。
## 返回 true 表示真的产兵成功（场上单位数 +1），false 表示产兵失败（调用方据此决定是否重试）。
func _do_respawn(task: Dictionary) -> bool:
	var platforms_pool: Array = _equipment.get("platforms", [])
	if platforms_pool.is_empty():
		return false
	# 场上已满时直接返回 false（让调用方推后重试，而非丢弃任务）
	if BattleManager and BattleManager.get_enemy_unit_count() >= _unit_limit:
		return false
	var count_before: int = BattleManager.get_enemy_unit_count() if BattleManager else 0
	var dead_arch: String = String(task.get("dead_arch", ""))
	var dead_kind: int = int(task.get("dead_kind", -1))
	# 收集存活单位（协同套路补缺元素用）
	var alive_units: Array = []
	var tree: SceneTree = get_tree()
	if tree != null:
		alive_units = tree.get_nodes_in_group("enemy_units")
	# 套路选平台：核心规则"那个兵掉了补那个兵"（dead_arch 命中池则补同款）
	var picked: String = MasterPatterns.pick_respawn_platform(
		_pattern_id, platforms_pool, dead_arch, dead_kind, alive_units,
		Callable(EnemyArchetypes, "get_config"))
	# picked 为空时退平台池首项（兜底，避免卡死）
	if picked.is_empty():
		picked = String(platforms_pool[0])
	# 执行补兵（override_platform_id = picked，跳过序列/反应式 AI）
	_produce_unit_with_equipment(picked)
	# 判断是否真的产兵成功（数量 +1 才算成功，避免 _produce_unit_with_equipment 内部静默 return 吞任务）
	var count_after: int = BattleManager.get_enemy_unit_count() if BattleManager else 0
	if count_after <= count_before:
		return false   # 产兵失败，调用方据此重试
	# 产兵成功：槽位补兵计数 +1（计数推迟到成功后，避免"计数加了没补成"导致槽位提前达上限）
	var slot_i: int = int(task.get("slot_index", -1))
	if slot_i >= 0:
		_slot_respawn_counts[slot_i] = int(_slot_respawn_counts.get(slot_i, 0)) + 1
	return true

## 暴露当前套路 id（供 UI 显示"敌方套路：钢铁壁垒"等）
func get_pattern_id() -> String:
	return _pattern_id

## 暴露套路配置（供 UI/调试用）
func get_pattern_config() -> Dictionary:
	return _pattern_cfg

## 回退路径：扫描 enemy_units 组，从远端(最大索引)倒序找第一个空闲敌槽；
## 敌方仅 slot N-1（位置 15，最右靠屏幕边）禁放，可用 slot 0~N-2。
func _fallback_pick_free_enemy_slot() -> int:
	var tree: SceneTree = get_tree()
	if tree == null:
		return BattleSlotGrid.SLOT_COUNT - 2
	var occupied := {}
	for n in tree.get_nodes_in_group("enemy_units"):
		if n == null or not is_instance_valid(n):
			continue
		var esi: int = int(n.get_meta("card_grid_enemy_slot", -1))
		if esi >= 0 and esi < BattleSlotGrid.SLOT_COUNT:
			occupied[esi] = true
	# 从远端(最大索引 N-2)倒序至 slot 0；敌方仅 slot N-1 禁放
	for si in range(BattleSlotGrid.SLOT_COUNT - 2, -1, -1):
		if not occupied.has(si):
			return si
	# 全满兜底：用最大可用索引 N-2（避免返回 -1 导致 get_card_grid_enemy_slot_global 越界）
	return BattleSlotGrid.SLOT_COUNT - 2

func take_damage(amount: float, attacker: Variant = null) -> void:
	var actual: float = amount
	# v8.5: boss 护盾优先扣减（shield_base/iron_dome 等被动给 boss 加的护盾）
	if _boss_shield > 0.0:
		var absorbed: float = minf(_boss_shield, actual)
		_boss_shield -= absorbed
		actual -= absorbed
		if _boss_shield <= 0.0:
			_boss_shield = 0.0
	hp -= actual
	# v8.5: boss 反伤被动（thorn_armor_fire/lightning_thorn 等）——受击时给攻击者反伤
	if _boss_thorn_pct > 0.0 and actual > 0.0 and attacker != null:
		var reflect: float = actual * _boss_thorn_pct
		if attacker.has_method("take_damage"):
			attacker.take_damage(reflect, self)
	if SignalBus:
		SignalBus.enemy_phase_driver_hp_changed.emit(maxf(hp, 0.0), max_hp)
		SignalBus.unit_damaged.emit(self, false, amount, global_position)
	if hp <= 0:
		_on_destroyed()

## v8.5: boss 护盾/反伤由 EnemyMasterSkillEngine 设置（shield_base/thorn_armor 类被动）
func add_boss_shield(amount: float) -> void:
	_boss_shield += amount
func set_boss_thorn(pct: float) -> void:
	_boss_thorn_pct = pct
func get_boss_shield() -> float:
	return _boss_shield

func _on_destroyed() -> void:
	stop_production()
	# v9.0: 基地被摧毁时断开 unit_died 信号（停止补兵）+ 清空补兵队列
	_respawn_queue.clear()
	if SignalBus and SignalBus.unit_died.is_connected(_on_any_unit_died):
		SignalBus.unit_died.disconnect(_on_any_unit_died)
	# v8.5: 死亡类被动（death_explosion 等）必须在 queue_free 前触发（此时 driver 仍有效）
	if _master_skill_engine != null and _master_skill_engine.has_method("on_boss_destroyed"):
		_master_skill_engine.on_boss_destroyed()
	if SignalBus:
		SignalBus.enemy_phase_driver_destroyed.emit()
	queue_free()

## 平台类型映射
static func _map_platform_type(type_str: String) -> int:
	var result: int = _PLATFORM_TYPE_MAP.get(type_str, -1)
	if result < 0:
		result = 1
	return result

## 武器类型映射
static func _map_weapon_type(type_str: String) -> int:
	var result: int = _WEAPON_TYPE_MAP.get(type_str, -1)
	if result < 0:
		result = 2
	return result

static func _era_string_to_int(era_str: String) -> int:
	match era_str:
		"ww1": return 0
		"ww2": return 1
		"cold": return 2
		"modern": return 3
		"future", "near_future": return 4
		_: return 4

## 无显式 era 时按等级推算时代
## Lv5-9→WW1(0), Lv10-14→WW2(1), Lv15-19→Cold(2), Lv20-24→Modern(3), Lv25+→Future(4)
static func _era_from_level(level: int) -> int:
	return clampi(floori(float(maxi(level, 5) - 5) / 5.0), 0, 4)

func _pick_visual_archetype_for_era(target_era: int) -> String:
	var candidates: Array = _ERA_VISUAL_ARCHETYPES.get(target_era, [])
	for candidate in candidates:
		var archetype_id: String = String(candidate)
		var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
		if cfg.is_empty():
			continue
		if not EnemyArchetypes.resolve_card_icon_texture_path(archetype_id, cfg, archetype_id).is_empty():
			return archetype_id
	return ""

## v7.1: 按平台类型匹配卡图（替代仅按时代的硬编码列表，避免不同平台显示同一张图）
## 返回该时代下与平台类型 tag 匹配、且有有效卡图的 archetype ID
## v7.3: 相位师产兵优先选高基础值兵种（让Boss战敌方用 elite/boss 级高HP兵种卡，
## 拉近敌我差距；同一平台类型候选里取 HP 最高的，而非随机/哈希选取）。
func _pick_visual_archetype_for_platform(era: int, platform_type: String) -> String:
	var target_tags: Array = _PLATFORM_TYPE_TO_TAGS.get(platform_type, [])
	if target_tags.is_empty():
		return _pick_visual_archetype_for_era(era)  # 未知平台类型回退
	var candidates: Array = []
	for archetype_id in EnemyArchetypes.get_ids_for_era(era):
		var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
		if cfg.is_empty():
			continue
		var tags: Array = cfg.get("tags", [])
		# 匹配任一目标 tag（v7.3: titan/raider/siege 同时匹配 vehicle/tank/armored）
		var matched: bool = false
		for tt in target_tags:
			if tags.has(tt):
				matched = true
				break
		if not matched:
			continue
		if EnemyArchetypes.resolve_card_icon_texture_path(archetype_id, cfg, archetype_id).is_empty():
			continue
		candidates.append(archetype_id)
	if candidates.is_empty():
		return _pick_visual_archetype_for_era(era)  # 该类型无候选，回退原逻辑
	# v7.3: 优先选基础 HP 最高的候选（让Boss战产兵用高基础兵种卡，如 cold_arm_t72_e 而非 cold_arm_btr_e）
	candidates.sort_custom(func(a_id: String, b_id: String) -> bool:
		var a_hp: float = float(EnemyArchetypes.get_config(a_id).get("hp", 0.0))
		var b_hp: float = float(EnemyArchetypes.get_config(b_id).get("hp", 0.0))
		return a_hp > b_hp)
	return String(candidates[0])


## v6.12: 用真实 archetype 数据构建 UnitStats（替代通用平台表 build_multi_stats）。
## v7.x: direct_archetype_id 非空时直接用该 archetype（删除平台卡层后直引模式），
## 否则复用 _pick_visual_archetype_for_platform 的平台→archetype 映射取真实 cfg（旧平台卡回退）。
## archetype 查不到时回退通用表。
func _build_stats_from_archetype(era: int, platform_type_str: String, fallback_platform_int: int, fallback_weapon_types: Array, direct_archetype_id: String = "") -> UnitStats:
	var archetype_id: String = direct_archetype_id
	if archetype_id.is_empty():
		archetype_id = _pick_visual_archetype_for_platform(era, platform_type_str)
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	if cfg.is_empty():
		# 兜底：archetype 查不到时回退原通用表（永不破坏游戏）
		return UnitStatsTable.build_multi_stats(fallback_platform_int, fallback_weapon_types, era)
	var c := CardResource.new()
	c.card_type = GC.CardType.COMBAT_UNIT
	c.era = int(cfg.get("era", era))
	c.combat_kind = _archetype_combat_kind(cfg, fallback_platform_int)
	# v7.3: 相位师产兵填充等量强化等级（对称我方强化系统）。
	# build_stats_from_card 内部会调用 apply_enhance_level_bonus，按 combat_kind 应用
	# 等量我方的 hp/atk/特殊能力加成（装甲9级=hp×1.315/atk×1.189+dmg_reduction+6.3%）。
	# v7.x: 强化等级按关卡难度递进（setup 缓存的 _pm_tier），不再恒定 TIER_HIGH(9级)。
	# 时代早期/中段 → enh6（中配），时代后期/Boss → enh9（高配满强化）。
	var EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")
	c.enhance_level = int(EnemyLoadoutTiers.get_bonus_for_tier(_pm_tier).get("enhance_level", 0))
	# v6.13: archetype 表的 weapon_type 是 legacy 12 值（SMG=0…OMEGA=10），
	# 不能直接当新 4 值 WeaponType（DIRECT/INDIRECT/AERIAL/SUPPORT）用——
	# 否则 MG(2) 被误判成 AERIAL(2) → 信息卡显示"空射武器"。
	# legacy 原值存入 legacy_weapon_type（弹道/bullet 复用），新枚举经映射后写入 weapon_type。
	var legacy_wt: int = int(cfg.get("weapon_type", 1))
	c.legacy_weapon_type = legacy_wt
	c.weapon_type = _legacy_weapon_to_new_weapon_type(legacy_wt, cfg)
	c.base_hp = float(cfg.get("hp", 100.0))
	# archetype speed 是负值（朝左行进），build_stats_from_card 需要绝对值
	c.base_speed = absf(float(cfg.get("speed", -80.0)))
	c.range_value = max(1, int(round(float(cfg.get("attack_range", 120.0)) / 100.0)))
	var interval: float = float(cfg.get("attack_interval", 1.0))
	c.attack_speed = 1.0 / maxf(0.001, interval)
	# v7.x 修复：三维攻击优先读 UCT 覆盖字段（EnemyArchetypes._ensure_manifest_merged 已用
	# UnifiedCardTable.build_enemy_archetype_config 覆盖 attack_light/attack_armor/attack_air）。
	# 旧代码无条件读 attack_damage（旧表单维字段）再按 0.8/0.7 比例派生三维，完全无视 UCT
	# 真实三维数据——巨神机甲 atk_a 应 878，旧路径算成 55×0.8=44，差 20 倍。
	# 回退路径与 resolve_classic_enemy（enemy_stat_resolver.gd:213-250）同款：combat_kind 智能派生。
	if cfg.has("attack_light") or cfg.has("attack_armor") or cfg.has("attack_air"):
		c.attack_light = float(cfg.get("attack_light", 0.0))
		c.attack_armor = float(cfg.get("attack_armor", 0.0))
		c.attack_air = float(cfg.get("attack_air", 0.0))
	else:
		var dmg_fallback: float = float(cfg.get("attack_damage", 10.0))
		c.attack_light = dmg_fallback
		c.attack_armor = dmg_fallback * 0.8
		c.attack_air = dmg_fallback * 0.7
	# v7.x 修复：三维攻速优先读 UCT 覆盖的 per-target interval（防空特化单位对空高频对地低频）。
	# 旧代码只读单一 attack_interval，丢失三维独立攻速。
	var ivl_l: float = float(cfg.get("attack_light_interval", interval))
	var ivl_a: float = float(cfg.get("attack_armor_interval", interval))
	var ivl_air: float = float(cfg.get("attack_air_interval", interval))
	c.attack_light_speed = 1.0 / maxf(0.001, ivl_l)
	c.attack_armor_speed = 1.0 / maxf(0.001, ivl_a)
	c.attack_air_speed = 1.0 / maxf(0.001, ivl_air)
	# 三维防御沿用平台通用表（archetype 无防御字段）
	var pd: float = float(UnitStatsTable._PLATFORM_DEFENSE.get(fallback_platform_int, 8))
	c.defense_light = pd
	c.defense_armor = pd * 1.2
	c.defense_air = pd * 0.6
	var stats := UnitStatsTable.build_stats_from_card(c, era)
	stats.platform_type = fallback_platform_int
	# v7.3: 防御对齐真实敌兵量级。
	# build_stats_from_card 内部的 derive_defense_by_unit_type 用的是"我方单位防御模板"
	# （堡垒防装甲140×era、装甲防装甲90×era 等），量级是敌兵的 10~30 倍——
	# 普通敌兵 resolve_classic_enemy 从 cfg.defense（通常5~15）派生三维防御。
	# 产兵复用 build_stats_from_card 会导致防御失控（第49关产兵防御达数百甚至上千）。
	# 现用 EnemyStatResolver.resolve_classic_enemy 同款逻辑覆盖三维防御：
	# 取 archetype 的单一 defense（无则 compute_defense_from_config 推导，量级 ~5~15），
	# 按 combat_kind 派生低量级三维防御，与普通敌兵对齐。
	var single_def: int = EnemyArchetypes.compute_defense_from_config(cfg)
	var ck: int = c.combat_kind
	# tags 含 aircraft 的判为 AIR（与 resolve_classic_enemy L194 一致）
	var cfg_tags: Array = cfg.get("tags", [])
	if ck != GC.CombatKind.AIR and cfg_tags.has("aircraft"):
		ck = GC.CombatKind.AIR
	var def_l: float = float(single_def)
	var def_a: float = float(single_def)
	var def_air: float = float(single_def)
	match ck:
		GC.CombatKind.LIGHT:
			def_l = float(single_def); def_a = float(single_def) * 0.5; def_air = float(single_def) * 0.3
		GC.CombatKind.ARMOR:
			def_l = float(single_def) * 0.7; def_a = float(single_def); def_air = float(single_def) * 0.6
		GC.CombatKind.SUPPORT:
			def_l = float(single_def) * 0.5; def_a = float(single_def) * 0.7; def_air = float(single_def) * 0.3
		GC.CombatKind.AIR:
			def_l = float(single_def) * 0.6; def_a = float(single_def) * 0.4; def_air = float(single_def)
		GC.CombatKind.FORT:
			def_l = float(single_def) * 1.3; def_a = float(single_def) * 1.5; def_air = float(single_def) * 0.8
	stats.defense_light = def_l
	stats.defense_armor = def_a
	stats.defense_air = def_air
	# 综合防御取三维最大值（与 build_stats_from_card 末尾逻辑一致，供格子战护甲公式用）
	stats.defense = maxf(def_l, maxf(def_a, def_air))
	return stats


## v6.12: 根据 archetype tags 推断 combat_kind；查不到用平台映射兜底
func _archetype_combat_kind(cfg: Dictionary, fallback_platform_int: int) -> int:
	var tags: Array = cfg.get("tags", [])
	if tags.has("infantry"):
		return int(GC.CombatKind.LIGHT)
	if tags.has("vehicle") or tags.has("armor") or tags.has("tank"):
		return int(GC.CombatKind.ARMOR)
	if tags.has("turret") or tags.has("fort") or tags.has("fortress"):
		return int(GC.CombatKind.FORT)
	if tags.has("air") or tags.has("aircraft"):
		return int(GC.CombatKind.AIR)
	# 兜底：沿用平台→combat_kind 映射
	return int(UnitStatsTable.PLATFORM_TO_COMBAT_KIND.get(fallback_platform_int, GC.CombatKind.LIGHT))


## v6.13: archetype 表的 weapon_type 是 legacy 12 值（WeaponTypeLegacy），
## 这里映射到新 4 值 WeaponType（DIRECT/INDIRECT/AERIAL/SUPPORT）。
## v7.x: 映射真身已上移到 GameConstants.legacy_weapon_to_new_weapon_type，
## 此处仅保留本文件签名（cfg 参数），从 cfg 判 is_aircraft 后委托 GC 版，
## 保证敌方标准敌兵(enemy_unit.gd)与相位师产兵两路径共用一处真身，避免漂移。
## 规则（详见 GC.legacy_weapon_to_new_weapon_type 注释）：
## - 空中平台（tags 含 aircraft/air）→ AERIAL
## - 曲射类 legacy（ROCKET=3/FLAK=7/MISSILE=9/RAIL=11）→ INDIRECT
## - 其余 → DIRECT
func _legacy_weapon_to_new_weapon_type(legacy_wt: int, cfg: Dictionary) -> int:
	var tags: Array = cfg.get("tags", [])
	var is_aircraft: bool = tags.has("air") or tags.has("aircraft")
	return GC.legacy_weapon_to_new_weapon_type(legacy_wt, is_aircraft)


## v6.14: 应用相位师自带符文的加成到产兵 stats。
## 读每个 rune 的 primary_effect（{stat, value}），value 为百分比（0.12 = +12%）。
## stat 映射：attack→三维攻击, defense→三维防御, hp→max_hp, attack_speed→提速。
## 与玩家符文之语不同，相位师符文只取 primary_effect（简化版，避免复刻整套敌方符文引擎）。
func _apply_master_rune_bonus(stats: UnitStats) -> void:
	if _master_runes.is_empty():
		return
	# v7.x: 符文按 tier 限量应用（替代旧"应用全部符文"）。
	# _master_runes 来自 _derive_runes（已按 level 选稀有度梯度），顺序天然偏稀有度优先。
	# LOW=1 / MID=3 / HIGH=6 个符文，超出 tier 上限的符文不应用到产兵。
	var _ELT_runes = preload("res://data/enemy_loadout_tiers.gd")
	var _rune_cap: int = int(_ELT_runes.get_bonus_for_tier(_pm_tier).get("rune_count", 99))
	var _applied: int = 0
	for rune_id in _master_runes:
		if _applied >= _rune_cap:
			break  # 超出 tier 上限的符文不应用
		var rune: Dictionary = RuneDefs.get_rune(String(rune_id))
		if rune.is_empty():
			continue
		var fx: Dictionary = rune.get("primary_effect", {})
		if fx.is_empty():
			continue
		var stat: String = String(fx.get("stat", ""))
		var val: float = float(fx.get("value", 0.0))
		if val == 0.0:
			continue
		var mult: float = 1.0 + val
		match stat:
			"attack":
				# v8.x 修复：attack_damage 是 attack_light 别名，同乘会乘两次（见配档乘区注释）。
				stats.attack_light *= mult
				stats.attack_armor *= mult
				stats.attack_air *= mult
				# v7.x 修复(H2): attack 乘区同步到 weapon_slots[].damage——
				# AI/AttackCalculator 的伤害结算读 weapon_slots[i].damage（非 attack_damage），
				# 原漏同步导致符文/序列/仪器加成不进实际伤害。
				_sync_enemy_weapon_slot_damage(stats, mult)
			"defense":
				stats.defense_light *= mult
				stats.defense_armor *= mult
				stats.defense_air *= mult
				stats.defense *= mult
			"hp":
				stats.max_hp *= mult
			"attack_speed":
				stats.attack_light_speed /= mult
				stats.attack_armor_speed /= mult
				stats.attack_air_speed /= mult
				stats.attack_interval /= mult
		_applied += 1


## v6.14: 出兵序列 elite/boss 标记加成。
## 序列里标记的 elite/boss 产兵额外加成，让出兵有强度节奏（非所有产兵都一样强）。
func _apply_sequence_entry_bonus(stats: UnitStats, entry_type: String) -> void:
	match entry_type:
		"elite":
			# v8.x 修复：attack_damage 是 attack_light 别名，同乘会乘两次（见配档乘区注释）。
			stats.attack_light *= 1.25
			stats.attack_armor *= 1.25
			stats.attack_air *= 1.25
			stats.max_hp *= 1.25
			_sync_enemy_weapon_slot_damage(stats, 1.25)  # v7.x H2: 同步武器槽伤害
		"boss":
			stats.attack_light *= 1.50
			stats.attack_armor *= 1.50
			stats.attack_air *= 1.50
			stats.max_hp *= 1.50
			# v7.x 修复(H1): 补齐三维防御（原只乘标量 defense，与 elite/instrument 分支不一致；
			# 防御实际由三维驱动，单乘标量导致 boss 防御加成不完整）。
			stats.defense *= 1.50
			stats.defense_light *= 1.50
			stats.defense_armor *= 1.50
			stats.defense_air *= 1.50
			_sync_enemy_weapon_slot_damage(stats, 1.50)


## v6.14/v7.x: 相位师相位仪加成（读统一池 properties 数组 pi_atk/pi_def/pi_hp）。
## 统一池 properties value 已是百分比小数（0.15 = +15%，见 PhaseInstruments.build_property_display），
## 直接用不再 ×0.05。直接在 driver 内读数据，避免改 phase_instrument_manager 的私有方法可见性。
func _apply_enemy_phase_instrument_bonus(stats: UnitStats) -> void:
	var instrument_id: String = String(_equipment.get("phase_instrument", ""))
	if instrument_id.is_empty():
		return
	var cfg: Dictionary = EnemyPhaseEquipment.get_phase_instrument(instrument_id)
	if cfg.is_empty():
		return
	# v7.x: 读统一池 properties（pi_atk/pi_def/pi_hp），value 已是百分比小数
	var props: Array = cfg.get("properties", [])
	var atk_pct: float = 0.0
	var def_pct: float = 0.0
	var hp_pct: float = 0.0
	for p in props:
		match String(p.get("id", "")):
			"pi_atk": atk_pct = float(p.get("value", 0.0))
			"pi_def": def_pct = float(p.get("value", 0.0))
			"pi_hp":  hp_pct  = float(p.get("value", 0.0))
	if atk_pct > 0.0:
		# v8.x 修复：attack_damage 是 attack_light 别名，同乘会乘两次（见配档乘区注释）。
		stats.attack_light *= (1.0 + atk_pct)
		stats.attack_armor *= (1.0 + atk_pct)
		stats.attack_air *= (1.0 + atk_pct)
		_sync_enemy_weapon_slot_damage(stats, 1.0 + atk_pct)  # v7.x H2: 同步武器槽伤害
	if hp_pct > 0.0:
		stats.max_hp *= (1.0 + hp_pct)
	if def_pct > 0.0:
		stats.defense *= (1.0 + def_pct)
		stats.defense_light *= (1.0 + def_pct)
		stats.defense_armor *= (1.0 + def_pct)
		stats.defense_air *= (1.0 + def_pct)


## v7.x 修复(H2): 把攻击乘区同步到 weapon_slots[].damage。
## AI/AttackCalculator 的伤害结算（calculate_damage_with_weapon L208 base_damage = weapon.damage）
## 读的是 UnitStats.weapon_slots[i].damage（WeaponResource 对象），而非 stats.attack_damage。
## 此前的 rune/sequence/instrument/tier 乘区只乘 attack_damage/attack_*，漏了 weapon_slots，
## 导致敌方产兵的这些加成在实际开火伤害里失效（敌方 DPS 偏低）。
## 复用 evolution_helpers._multiply_attack_damage_and_weapon_slots 的同款逻辑：
## 遍历 weapon_slots，逐个乘 factor（带 enabled/对象校验，缺字段不崩）。
func _sync_enemy_weapon_slot_damage(stats: UnitStats, factor: float) -> void:
	if stats == null or factor == 1.0:
		return
	var slots: Array = stats.weapon_slots
	for i in range(slots.size()):
		var w = slots[i]
		if w == null:
			continue
		# WeaponResource 是 Resource（非 Dictionary），用 set/get 访问 damage 字段
		if "damage" in w:
			w.damage = float(w.damage) * factor


## v7.x(敌方加成来源明细): 记录产兵单步加成的 HP/攻击/防御倍率到 sources 数组。
## 通过前后值比值反推倍率（比从配置反算更准确，与实际应用值完全一致）。
## 追加一条 {label, hp_mul, atk_mul, def_mul} 记录，若该步无任何变化（全×1.0）也记录（便于完整追溯）。
func _record_spawn_step(sources: Array, label: String, hp_before: float, atk_before: float, def_before: float, stats: UnitStats) -> Array:
	var hp_after: float = float(stats.max_hp)
	var atk_after: float = float(stats.attack_damage)
	var def_after: float = float(stats.defense)
	var hp_mul: float = _safe_ratio(hp_after, hp_before)
	var atk_mul: float = _safe_ratio(atk_after, atk_before)
	var def_mul: float = _safe_ratio(def_after, def_before)
	var parts: Array = []
	if absf(hp_mul - 1.0) > 0.005:
		parts.append("血×%.2f" % hp_mul)
	if absf(atk_mul - 1.0) > 0.005:
		parts.append("攻×%.2f" % atk_mul)
	if absf(def_mul - 1.0) > 0.005:
		parts.append("防×%.2f" % def_mul)
	var full_label: String = label
	if not parts.is_empty():
		full_label += "(%s)" % " ".join(parts)
	else:
		full_label += "(无加成)"
	sources.append({"label": full_label, "hp_mul": hp_mul, "atk_mul": atk_mul, "def_mul": def_mul})
	return sources


## v7.x(敌方加成来源明细): 安全比值（除零保护）。after/before，before≤0 时返回 1.0。
func _safe_ratio(after: float, before: float) -> float:
	if before <= 0.0:
		return 1.0
	return after / before


# ───────────────────────────────────────────────────────────────
## v8.x: boss 唯一性 — 按 archetype_id 统计场上存活同名 boss 数量
## 注：非 static（需访问 self.get_parent()，仅由 driver 实例调用）
func _effective_archetype_exists_on_field(archetype_id: String) -> bool:
	if archetype_id.is_empty():
		return false
	var enemy_container: Node = null
	# 路径1：父节点是 Battlefield，直接查 EnemyUnits
	var bf: Node = get_parent()
	if bf != null:
		enemy_container = bf.get_node_or_null("EnemyUnits")
	# 路径2：fallback → BattleManager.enemy_units_node
	if enemy_container == null:
		var bm: Node = get_node_or_null("/root/BattleManager")
		if bm != null and "enemy_units_node" in bm:
			enemy_container = bm.enemy_units_node
	if enemy_container == null:
		return false
	for n in enemy_container.get_children():
		if n == null or not is_instance_valid(n):
			continue
		if "_is_dying" in n and n._is_dying:
			continue
		if "is_deploy_ghost" in n and n.is_deploy_ghost:
			continue
		# 读取 archetype_id（EnemyUnit 裸字段 / ConstructUnit meta / stats.platform_card_id）
		var aid: String = ""
		if "archetype_id" in n:
			aid = str(n.archetype_id)
		elif n.has_meta("archetype_id"):
			aid = str(n.get_meta("archetype_id"))
		elif "stats" in n and n.stats != null:
			var st = n.stats
			if "platform_card_id" in st:
				aid = String(st.platform_card_id)
		if aid == archetype_id:
			return true
	return false
