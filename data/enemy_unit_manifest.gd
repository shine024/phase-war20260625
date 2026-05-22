extends RefCounted
class_name EnemyUnitManifest
## 100 基本敌人 + 缴获卡绑定（与 docs/card_icon_manifest_100_zh.md 对齐）
##
## 目标：清单内条目均为战场敌人；击杀（或配置的时机）掉落 captured_* 成品卡进背包。
## captured_* 由 CapturedUnitCards 注册，不经 DropManager 对 platform_* 的拦截。

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const BattleCardV3 = preload("res://data/battle_card_v3.gd")

const MANIFEST_VERSION: int = 1
const CAPTURED_PREFIX: String = "captured_"

## A 段：原我方平台 → 敌人 archetype 前缀 foe_
const FOE_PLATFORM_CARD_IDS: Array[String] = [
	"platform_ww1_light", "platform_ww1_medium", "platform_ww1_fort", "platform_ww1_radar", "platform_ww1_medic",
	"platform_ww2_light", "platform_ww2_medium", "platform_ww2_heavy", "platform_ww2_raider", "platform_ww2_radar",
	"platform_ww2_siege", "platform_ww2_fortress",
	"platform_cold_light", "platform_cold_medium", "platform_cold_ifv", "platform_cold_scout", "platform_cold_radar",
	"platform_cold_carrier",
	"platform_modern_light", "platform_modern_medium", "platform_modern_radar", "platform_modern_spg",
	"platform_modern_stealth", "platform_modern_guard_heavy",
	"platform_future_light", "platform_future_medium", "platform_future_radar", "platform_future_heavy",
	"omega_platform",
]

## B 段：原精英掉落平台
const FOE_SPECIAL_CARD_IDS: Array[String] = [
	"bulwark", "titan_mk2", "storm_rider", "heavy_carrier", "regen_frame", "abrams_mk2",
]

## C 段：固定敌人（与 enemy_archetypes.json 一致）
const FIXED_ENEMY_IDS: Array[String] = [
	"enemy_ww1_infantry_basic", "enemy_ww1_infantry_rifle", "enemy_ww1_mg_nest", "enemy_ww1_mortar",
	"elite_ww1_storm", "elite_ww1_armored", "boss_ww1_av7",
	"enemy_ww2_infantry", "enemy_ww2_rifleman", "enemy_ww2_mg42", "enemy_ww2_panzerschreck",
	"elite_ww2_paratrooper", "elite_ww2_panther", "boss_ww2_kingtiger",
	"enemy_cold_ak", "enemy_cold_m60", "enemy_cold_btr", "enemy_cold_m113",
	"elite_cold_spetsnaz", "elite_cold_t72", "boss_cold_mig",
	"enemy_modern_marine", "enemy_modern_technical", "enemy_modern_stryker", "enemy_modern_mlrs",
	"elite_modern_delta", "elite_modern_abrams", "elite_modern_apache", "boss_modern_command",
	"enemy_future_drone", "enemy_future_cyborg", "enemy_future_mech", "enemy_future_hovertank",
	"elite_future_spectre", "elite_future_colossus", "boss_future_nexus",
]

## D 段：补充敌人（生成池视觉位，每时代 5 + 4 备用 = 29）
const POOL_ENEMY_IDS: Array[String] = [
	"foe_pool_001", "foe_pool_002", "foe_pool_003", "foe_pool_004", "foe_pool_005",
	"foe_pool_006", "foe_pool_007", "foe_pool_008", "foe_pool_009", "foe_pool_010",
	"foe_pool_011", "foe_pool_012", "foe_pool_013", "foe_pool_014", "foe_pool_015",
	"foe_pool_016", "foe_pool_017", "foe_pool_018", "foe_pool_019", "foe_pool_020",
	"foe_pool_021", "foe_pool_022", "foe_pool_023", "foe_pool_024", "foe_pool_025",
	"foe_pool_026", "foe_pool_027", "foe_pool_028", "foe_pool_029",
]

## 与 card_icon_manifest 显示名一致（无时代前缀）；索引与 POOL / 平台顺序由策划表维护
const POOL_DISPLAY_NAMES: Array[String] = [
	"李-恩菲尔德志愿兵排", "劳斯莱斯 Mk.II 装甲车", "维克斯 .303 机枪阵地", "福特 T 型战地救护车", "MP18 突击队",
	"M1 加兰德伞兵班", "黄蜂 Hummel 自行火炮", "PaK 40 反坦克炮组", "GMC 2.5t 补给卡车", "毛瑟 Kar98k 狙击组",
	"BMD-1 空降战车", "BMP-1 步兵战车", "9K111 法特导弹组", "P-18 雷达警戒车", "BREM-1 装甲抢修车",
	"M4 卡宾特遣班", "爱国者 PAC-3 发射车", "HIMARS 火箭炮组", "RQ-7 影子无人机班", "EA-18G 电子战小组",
	"神经接口突击兵", "HK-07 量产机兵", "HEL-30 激光炮阵列", "N-Repair 纳米工程车", "X-9 猎杀者渗透组",
	"毛瑟 C96 征召兵排", "Sd.Kfz.251/1 半履带车", "SS-C-1 岸防导弹组", "PS-9 相位中继站",
]

static var _entries_cache: Array = []
static var _unit_icon_by_archetype: Dictionary = {}

const UNITS_ICON_DIR := "res://assets/card_icons/units/"


static func get_unit_icon_path_for_archetype(archetype_id: String) -> String:
	var aid := String(archetype_id).strip_edges()
	if aid.is_empty():
		return ""
	_ensure_unit_icon_map()
	var rel: String = String(_unit_icon_by_archetype.get(aid, ""))
	if rel.is_empty():
		return ""
	var full := "%s%s.png" % [UNITS_ICON_DIR, rel]
	return full if ResourceLoader.exists(full) else ""


static func _ensure_unit_icon_map() -> void:
	if not _unit_icon_by_archetype.is_empty():
		return
	for row in get_entries():
		if row is not Dictionary:
			continue
		var aid: String = String(row.get("archetype_id", ""))
		var vid: String = String(row.get("visual_id", ""))
		if aid.is_empty() or vid.is_empty():
			continue
		_unit_icon_by_archetype[aid] = vid


static func get_entry_count() -> int:
	return 29 + 6 + 36 + 29


static func captured_card_id_for(archetype_id: String) -> String:
	return "%s%s" % [CAPTURED_PREFIX, String(archetype_id).strip_edges()]


static func is_captured_card_id(card_id: String) -> bool:
	return String(card_id).begins_with(CAPTURED_PREFIX)


static func archetype_id_for_platform_card(platform_card_id: String) -> String:
	return "foe_%s" % String(platform_card_id).strip_edges()


static func get_entries() -> Array:
	if not _entries_cache.is_empty():
		return _entries_cache
	var rows: Array = []
	for pid in FOE_PLATFORM_CARD_IDS:
		rows.append(_make_platform_foe_row(pid))
	for sid in FOE_SPECIAL_CARD_IDS:
		rows.append(_make_platform_foe_row(sid))
	for eid in FIXED_ENEMY_IDS:
		rows.append(_make_fixed_row(eid))
	for i in range(POOL_ENEMY_IDS.size()):
		rows.append(_make_pool_row(i))
	_entries_cache = rows
	return _entries_cache


static func build_archetype_dictionary(base_archetypes: Dictionary) -> Dictionary:
	var out: Dictionary = base_archetypes.duplicate(true)
	for row in get_entries():
		if row is not Dictionary:
			continue
		var aid: String = String(row.get("archetype_id", ""))
		var cfg: Dictionary = row.get("archetype_config", {})
		if aid.is_empty() or cfg.is_empty():
			continue
		out[aid] = cfg
	return out


static func get_drop_card_id(archetype_id: String) -> String:
	return captured_card_id_for(archetype_id)


static func _make_platform_foe_row(platform_card_id: String) -> Dictionary:
	var card: CardResource = DefaultCards.get_card_by_id(platform_card_id)
	var era: int = _era_from_platform_id(platform_card_id)
	var aid: String = archetype_id_for_platform_card(platform_card_id)
	var display_name: String = card.display_name if card != null else platform_card_id
	return {
		"archetype_id": aid,
		"display_name": display_name,
		"era": era,
		"visual_id": _visual_id_for_source_id(platform_card_id),
		"drop_card_id": captured_card_id_for(aid),
		"template_card_id": platform_card_id,
		"drop_trigger": "on_kill",
		"drop_chance": _default_drop_chance("frontline"),
		"archetype_config": _archetype_config_from_platform_card(card, era, display_name, aid),
	}


static func _make_fixed_row(enemy_id: String) -> Dictionary:
	var base_cfg: Dictionary = {}  # 由 EnemyArchetypes.ARCHETYPES 在合并时填充；此处只建掉落与 id
	var era: int = _era_from_enemy_id(enemy_id)
	return {
		"archetype_id": enemy_id,
		"display_name": "",  # 合并时保留 JSON 内 display_name
		"era": era,
		"visual_id": _visual_id_for_source_id(enemy_id),
		"drop_card_id": captured_card_id_for(enemy_id),
		"template_card_id": "",
		"drop_trigger": "on_kill",
		"drop_chance": _default_drop_chance(_tag_tier_from_id(enemy_id)),
		"archetype_config": {},  # 空 = 使用 base ARCHETYPES 数值，仅覆盖 drops
	}


static func _make_pool_row(index: int) -> Dictionary:
	var aid: String = POOL_ENEMY_IDS[index]
	var era: int = clampi(index / 5, 0, 4)  # 每时代 5 条主条目 + 末代余量
	var kind: int = index % 4
	var display_name: String = POOL_DISPLAY_NAMES[index] if index < POOL_DISPLAY_NAMES.size() else aid
	var template_platform: String = _template_platform_for_pool(era, kind)
	var card: CardResource = DefaultCards.get_card_by_id(template_platform)
	return {
		"archetype_id": aid,
		"display_name": display_name,
		"era": era,
		"visual_id": "vis_pool_%03d" % (index + 1),
		"drop_card_id": captured_card_id_for(aid),
		"template_card_id": template_platform,
		"drop_trigger": "on_kill",
		"drop_chance": 0.08,
		"archetype_config": _archetype_config_from_platform_card(card, era, display_name, aid, kind),
	}


static func _merge_fixed_config(row: Dictionary, base_cfg: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_cfg.duplicate(true)
	var aid: String = String(row.get("archetype_id", ""))
	var chance: float = float(row.get("drop_chance", 0.08))
	var drop_id: String = String(row.get("drop_card_id", ""))
	if not drop_id.is_empty():
		cfg["drops"] = [{"card_id": drop_id, "chance": chance}]
	return cfg


## 供 EnemyArchetypes 调用：在固定 JSON 配置上强制写入缴获掉落
static func apply_capture_drops_to_archetypes(archetypes: Dictionary) -> Dictionary:
	var out: Dictionary = archetypes.duplicate(true)
	for row in get_entries():
		if row is not Dictionary:
			continue
		var aid: String = String(row.get("archetype_id", ""))
		if aid.is_empty():
			continue
		var drop_id: String = String(row.get("drop_card_id", ""))
		var chance: float = float(row.get("drop_chance", 0.08))
		var sub: Dictionary = row.get("archetype_config", {})
		if not out.has(aid):
			if sub is Dictionary and not sub.is_empty():
				out[aid] = sub.duplicate(true)
			else:
				continue
		var cfg: Dictionary = out[aid]
		if cfg is Dictionary:
			cfg["drops"] = [{"card_id": drop_id, "chance": chance}]
			if not String(row.get("display_name", "")).is_empty():
				cfg["display_name"] = String(row.get("display_name", ""))
			out[aid] = cfg
	return out


static func _archetype_config_from_platform_card(
	card: CardResource,
	era: int,
	display_name: String,
	archetype_id: String,
	kind_override: int = -1
) -> Dictionary:
	var pt: int = GC.PlatformType.GUARD
	var wt: int = GC.WeaponType.RIFLE
	if card != null:
		pt = int(card.platform_type)
		wt = int(card.default_weapon_type) if int(card.default_weapon_type) >= 0 else GC.WeaponType.RIFLE
	var stats = UnitStatsTable.build_stats(pt, wt, era)
	var kind: int = kind_override if kind_override >= 0 else _kind_from_platform_type(pt)
	var speed: float = 0.0
	if not stats.is_stationary:
		speed = -maxf(40.0, float(stats.move_speed) * 0.65)
	var tags: Array = ["frontline"]
	match kind:
		2:
			tags = ["turret", "sustained"]
		3:
			tags = ["support"]
		1:
			tags = ["vehicle", "armored"]
	return {
		"era": era,
		"display_name": display_name,
		"hp": stats.max_hp,
		"speed": speed,
		"attack_damage": stats.attack_damage,
		"attack_range": stats.attack_range,
		"attack_interval": stats.attack_interval,
		"weapon_type": wt,
		"tags": tags,
		"swarm_unit": pt == GC.PlatformType.HOUND or pt == GC.PlatformType.SCOUT,
		"drops": [{"card_id": captured_card_id_for(archetype_id), "chance": 0.08}],
	}


static func _era_from_platform_id(card_id: String) -> int:
	if card_id.contains("ww1"):
		return 0
	if card_id.contains("ww2"):
		return 1
	if card_id.contains("cold"):
		return 2
	if card_id.contains("modern"):
		return 3
	if card_id.contains("future") or card_id == "omega_platform":
		return 4
	return 0


static func _era_from_enemy_id(enemy_id: String) -> int:
	if enemy_id.contains("ww1"):
		return 0
	if enemy_id.contains("ww2"):
		return 1
	if enemy_id.contains("cold"):
		return 2
	if enemy_id.contains("modern"):
		return 3
	if enemy_id.contains("future") or enemy_id.contains("near"):
		return 4
	return 0


static func _tag_tier_from_id(enemy_id: String) -> String:
	if enemy_id.begins_with("boss_"):
		return "boss"
	if enemy_id.begins_with("elite_"):
		return "elite"
	return "frontline"


static func _default_drop_chance(tier: String) -> float:
	match tier:
		"boss":
			return 0.55
		"elite":
			return 0.22
		_:
			return 0.08


static func _kind_from_platform_type(pt: int) -> int:
	match pt:
		GC.PlatformType.FORTRESS, GC.PlatformType.RADAR, GC.PlatformType.SIEGE:
			return 2
		GC.PlatformType.MEDIC, GC.PlatformType.CARRIER:
			return 3
		GC.PlatformType.HOUND, GC.PlatformType.SCOUT, GC.PlatformType.STEALTH:
			return 0
		_:
			return 1


static func _template_platform_for_pool(era: int, kind: int) -> String:
	# 必须为 DefaultCards 中存在的 platform_*（勿填 enemy_/elite_ 原型 id）
	var table: Array = [
		["platform_ww1_light", "platform_ww1_medium", "platform_ww1_fort", "platform_ww1_medic"],
		["platform_ww2_light", "platform_ww2_heavy", "platform_ww2_siege", "platform_ww2_raider"],
		["platform_cold_light", "platform_cold_medium", "platform_cold_ifv", "platform_cold_carrier"],
		["platform_modern_light", "platform_modern_medium", "platform_modern_spg", "platform_modern_marine"],
		["platform_future_light", "platform_future_heavy", "platform_future_medium", "platform_future_radar"],
	]
	if era < 0 or era >= table.size():
		return "platform_ww1_light"
	var row: Array = table[era]
	return String(row[kind % row.size()])


## 与 docs/card_icon_manifest_100_agent_prompts.md 编号一致：A 段 001–029、B 段 030–035、C 段 vis_enemy_036+、D 段 vis_pool_*
static func _visual_id_for_source_id(source_id: String) -> String:
	var sid: String = source_id.strip_edges()
	var special_idx: int = FOE_SPECIAL_CARD_IDS.find(sid)
	if special_idx >= 0:
		return "vis_player_%03d" % (30 + special_idx)
	var platform_idx: int = FOE_PLATFORM_CARD_IDS.find(sid)
	if platform_idx >= 0:
		return "vis_player_%03d" % (platform_idx + 1)
	var fixed_idx: int = FIXED_ENEMY_IDS.find(sid)
	if fixed_idx >= 0:
		return "vis_enemy_%03d" % (36 + fixed_idx)
	var pool_idx: int = POOL_ENEMY_IDS.find(sid)
	if pool_idx >= 0:
		return "vis_pool_%03d" % (pool_idx + 1)
	return sid
