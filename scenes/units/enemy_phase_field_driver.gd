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
const BattleSlotGrid = preload("res://scenes/battlefield/battle_slot_grid.gd")

## 兜底：EnemyArchetypes 生成（当没有装备数据时使用）
const USE_FALLBACK_SPAWN: bool = true
## 与 EnemyUnit 视觉一致：用 archetype 的 visual_scale × 典型精灵帧边长，再按整张贴图缩放到同量级
const _PHASE_BODY_REFERENCE_FRAME_PX: float = 256.0
## 与 enemy_unit.gd 中 MAX_ENEMY_VISUAL_EXTENT_PX 对齐（底座略大可等同上限）
const _PHASE_BODY_MAX_EXTENT_PX: float = 220.0
## v6.2: 累计召唤上限。相位师不死即无限产兵会导致战斗拖延；达上限后切换到疲劳间隔，
## 给玩家留出集中输出基地 HP 的窗口。
const TOTAL_SPAWN_CAP: int = 12
## v6.2: 累计达上限后的产兵间隔（原 spawn_interval 约 3~6s），大幅延长以缓解压制。
const FATIGUED_SPAWN_INTERVAL: float = 18.0

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
## v6.2: 累计召唤计数 + 疲劳标记（达 TOTAL_SPAWN_CAP 后切换到 FATIGUED_SPAWN_INTERVAL）
var _total_spawned: int = 0
var _spawn_fatigued: bool = false

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
	0: ["enemy_ww1_infantry_basic", "elite_ww1_armored", "enemy_ww1_mg_nest", "enemy_ww1_mortar"],
	1: ["enemy_ww2_infantry", "elite_ww2_panther", "enemy_ww2_mg42", "enemy_ww2_panzerschreck"],
	2: ["enemy_cold_ak", "enemy_cold_btr", "enemy_cold_m113", "enemy_cold_m60"],
	3: ["enemy_modern_marine", "enemy_modern_stryker", "enemy_modern_mlrs", "enemy_modern_technical"],
	4: ["enemy_future_cyborg", "enemy_future_hovertank", "enemy_future_mech", "enemy_future_drone"],
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

	## 尝试获取装备数据
	_equipment = master_config.get("equipment", {})
	_master_stats = master_config.get("stats", {})
	_unit_limit = int(_master_stats.get("unit_limit", 5))
	# 格子战场敌方仅 6 个可用槽位（SLOT_COUNT - 1）。数据表 unit_limit 可达 7~15，
	# 超出会导致产兵越过 6 上限、多单位挤同格。统一钳制到格子可用槽位数。
	# 注：master_power_evaluator 直接读原始配置 dict 评分，不受此钳制影响。
	_unit_limit = mini(_unit_limit, BattleSlotGrid.SLOT_COUNT - 1)

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
	# v6.2: 每次重建基地都重置累计召唤计数与疲劳标记
	_total_spawned = 0
	_spawn_fatigued = false
	if SignalBus:
		SignalBus.enemy_phase_driver_hp_changed.emit(hp, max_hp)
	var mode_str := "装备模式" if _has_equipment else "经典模式"
	# [LOG-v5.1] print("[EnemyPhaseDriver] 相位师 %s 基地建立 (HP=%d, era=%d, limit=%d, cap=%d, interval=%.1f) [%s]" % [master_name, int(max_hp), era, _unit_limit, TOTAL_SPAWN_CAP, spawn_interval, mode_str])
	_apply_body_visual_from_master(master_config)

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

func _process(delta: float) -> void:
	if _body != null:
		_body.rotation += deg_to_rad(rotate_speed_deg) * delta
	if not _battle_active or not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.paused:
		return
	_spawn_timer += delta
	# v6.2: 累计召唤达上限后切换到疲劳间隔，缓解无限产兵压制
	var interval: float = FATIGUED_SPAWN_INTERVAL if _spawn_fatigued else spawn_interval
	if _spawn_timer >= interval:
		_spawn_timer = 0.0
		_produce_unit()

## 从装备数据生成单位（使用 ConstructUnit）
func _produce_unit_with_equipment() -> void:
	if not BattleManager:
		return
	var current_count: int = BattleManager.get_enemy_unit_count()
	if current_count >= _unit_limit:
		return

	var platforms: Array = _equipment.get("platforms", [])
	var weapons: Array = _equipment.get("weapons", [])
	if platforms.is_empty():
		return

	# 验证平台数据有效性（保留所有平台类型，含 striker/sniper/stealth/mage）
	var valid_platforms: Array = []
	for pid in platforms:
		var pdata := EnemyPhaseEquipment.get_war_platform(String(pid))
		if not pdata.is_empty():
			valid_platforms.append(String(pid))

	if valid_platforms.is_empty():
		return

	## 随机选平台
	var platform_id: String = valid_platforms[randi() % valid_platforms.size()]
	var platform_data: Dictionary = EnemyPhaseEquipment.get_war_platform(platform_id)
	if platform_data.is_empty():
		return

	## 平台卡默认武器（非随机）；表无字段时在装备武器列表中按 id 排序取首项作为确定性回退
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
	var wt_int: int = _map_weapon_type(wdata.get("type", ""))
	if wt_int < 0:
		return
	var weapon_types: Array = [wt_int]

	## 映射平台类型
	var platform_type_int: int = _map_platform_type(platform_data.get("type", ""))
	if platform_type_int < 0:
		return

	## 构建 UnitStats
	# v6.12: 用真实 archetype 数据构建（替代通用平台表 build_multi_stats），让敌方产兵强度对齐
	# 同类型真实敌人。复用 _pick_visual_archetype_for_platform 的平台→archetype 映射取真实 cfg，
	# 查不到时回退通用表（永不破坏游戏）。
	var platform_type_str: String = String(platform_data.get("type", ""))
	var stats: UnitStats = _build_stats_from_archetype(era, platform_type_str, platform_type_int, weapon_types)

	## 用装备数据覆写基础属性（让不同装备的差异化体现）
	var plat_stats: Dictionary = platform_data.get("stats", {})
	if not plat_stats.is_empty():
		stats.max_hp = float(plat_stats.get("hp", stats.max_hp))
		stats.move_speed = 0.0
		if plat_stats.has("defense"):
			stats.defense = float(plat_stats["defense"])

	EnemyStatResolver.apply_phase_master_to_unit_stats(stats, _master_stats)
	stats.platform_card_id = platform_id

	## 生成 ConstructUnit
	var unit: Node2D = ConstructUnitScene.instantiate()
	# v7.1: 按平台类型匹配卡图（替代仅按时代选取，避免不同平台显示同一张图）
	# v6.12: platform_type_str 已在上方 stats 构建处声明，复用之
	var visual_archetype_id: String = _pick_visual_archetype_for_platform(era, platform_type_str)
	if unit.has_method("setup_with_enemy_visual"):
		unit.setup_with_enemy_visual(false, stats, visual_archetype_id)
	else:
		unit.setup(false, stats)
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
	if _has_equipment:
		_produce_unit_with_equipment()
	elif USE_FALLBACK_SPAWN:
		_produce_unit_fallback()

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
	return true


## v6.2: 单位成功进入战场后累计召唤计数；达 TOTAL_SPAWN_CAP 后切换到疲劳间隔。
func _record_spawn_and_check_fatigue() -> void:
	_total_spawned += 1
	if not _spawn_fatigued and _total_spawned >= TOTAL_SPAWN_CAP:
		_spawn_fatigued = true
		_spawn_timer = 0.0  # 重置计时器，让疲劳间隔从现在起算

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
	hp -= amount
	if SignalBus:
		SignalBus.enemy_phase_driver_hp_changed.emit(maxf(hp, 0.0), max_hp)
		SignalBus.unit_damaged.emit(self, false, amount, global_position)
	if hp <= 0:
		_on_destroyed()

func _on_destroyed() -> void:
	stop_production()
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
func _pick_visual_archetype_for_platform(era: int, platform_type: String) -> String:
	var target_tag: String = _PLATFORM_TYPE_TO_TAG.get(platform_type, "")
	if target_tag.is_empty():
		return _pick_visual_archetype_for_era(era)  # 未知平台类型回退
	var candidates: Array = []
	for archetype_id in EnemyArchetypes.get_ids_for_era(era):
		var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
		if cfg.is_empty():
			continue
		var tags: Array = cfg.get("tags", [])
		if not tags.has(target_tag):
			continue
		if EnemyArchetypes.resolve_card_icon_texture_path(archetype_id, cfg, archetype_id).is_empty():
			continue
		candidates.append(archetype_id)
	if candidates.is_empty():
		return _pick_visual_archetype_for_era(era)  # 该类型无候选，回退原逻辑
	# 用平台类型哈希确定性选取（同一类型每次出同一张图，避免战斗中卡图闪烁）
	var pick: int = absi(platform_type.hash()) % candidates.size()
	return String(candidates[pick])


## v6.12: 用真实 archetype 数据构建 UnitStats（替代通用平台表 build_multi_stats）。
## 复用 _pick_visual_archetype_for_platform 的平台→archetype 映射取真实 cfg，
## 让敌方产兵基础值与同类型真实敌人一致；archetype 查不到时回退通用表。
func _build_stats_from_archetype(era: int, platform_type_str: String, fallback_platform_int: int, fallback_weapon_types: Array) -> UnitStats:
	var archetype_id: String = _pick_visual_archetype_for_platform(era, platform_type_str)
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	if cfg.is_empty():
		# 兜底：archetype 查不到时回退原通用表（永不破坏游戏）
		return UnitStatsTable.build_multi_stats(fallback_platform_int, fallback_weapon_types, era)
	var c := CardResource.new()
	c.card_type = GC.CardType.COMBAT_UNIT
	c.era = int(cfg.get("era", era))
	c.combat_kind = _archetype_combat_kind(cfg, fallback_platform_int)
	c.legacy_weapon_type = int(cfg.get("weapon_type", 1))
	c.weapon_type = int(cfg.get("weapon_type", 1))
	c.base_hp = float(cfg.get("hp", 100.0))
	# archetype speed 是负值（朝左行进），build_stats_from_card 需要绝对值
	c.base_speed = absf(float(cfg.get("speed", -80.0)))
	c.range_value = max(1, int(round(float(cfg.get("attack_range", 120.0)) / 100.0)))
	var interval: float = float(cfg.get("attack_interval", 1.0))
	c.attack_speed = 1.0 / maxf(0.001, interval)
	var dmg: float = float(cfg.get("attack_damage", 10.0))
	# 三维攻击派生（复用 build_multi_stats 的同款比例：轻1.0/甲0.8/空0.7）
	c.attack_light = dmg
	c.attack_armor = dmg * 0.8
	c.attack_air = dmg * 0.7
	# 三维防御沿用平台通用表（archetype 无防御字段）
	var pd: float = float(UnitStatsTable._PLATFORM_DEFENSE.get(fallback_platform_int, 8))
	c.defense_light = pd
	c.defense_armor = pd * 1.2
	c.defense_air = pd * 0.6
	var stats := UnitStatsTable.build_stats_from_card(c, era)
	stats.platform_type = fallback_platform_int
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
