extends RefCounted
class_name EnemyUnitManifest
## 100 基本敌人 + 缴获卡绑定（与 docs/card_icon_manifest_100_zh.md 对齐）
##
## v3 重构：100张敌人卡自带完整属性，不再从旧平台卡克隆。
## captured_* 由 CapturedUnitCards 注册，不经 DropManager 对 platform_* 的拦截。
##
## v8.0: 数据源统一——A/B/D/E 段敌人的基础数值改从 UnifiedCardTable（统一卡牌表）读取，
## 与玩家卡/缴获卡共享同一套数值。原 _get_foe_stats 的硬编码 match 分支保留作 fallback。

const GC = preload("res://resources/game_constants.gd")
const BattleCardV3 = preload("res://data/battle_card_v3.gd")
const UnifiedCardTable = preload("res://data/unified_card_table.gd")

const MANIFEST_VERSION: int = 2
const CAPTURED_PREFIX: String = "captured_"

## A 段：新时代单位 → 敌人 archetype 前缀 foe_（28张，v3更新）
const FOE_PLATFORM_CARD_IDS: Array[String] = [
	# 一战（5个）
	"ww1_arm_rolls", "ww1_arm_ft17", "ww1_arty_77mm", "ww1_inf_cavalry", "ww1_sup_engineer",
	# 二战（7个）
	"ww2_inf_hellcat", "ww2_arm_sherman", "ww2_arm_tiger", "ww2_inf_bazooka", "ww2_inf_panzerschrek",
	"ww2_arty_m81", "ww1_arty_m81",
	# 冷战（5个）
	"cold_inf_btr60", "cold_arm_t55", "cold_inf_bmp1", "cold_sup_m113", "cold_sup_zsu23",
	# 现代系统（6个）
	"mod_inf_technical", "mod_arm_m1a1", "mod_sup_m6", "mod_arty_m270", "mod_inf_scout_drone",
	"mod_arm_m1a2sep",
	# 近未来（4个）
	"fut_inf_scout_mech", "fut_arm_hovertank", "fut_arm_prism", "fut_arm_heavy_mech",
	# 终极单位
	"fut_arm_nexus",
]

## B 段：原精英掉落平台（6张）
const FOE_SPECIAL_CARD_IDS: Array[String] = [
	"fut_sup_bulwark", "fut_arm_titan_mk2", "fut_inf_storm_rider", "fut_air_heavy_carrier", "fut_air_regen_frame", "mod_arm_abrams_mk2",
]

## C' 段：缴获卡面映射（C段固定敌人的玩家视角版本，14张）
const CAPTURED_ENEMY_IDS: Array[String] = [
	"ww1_inf_mp18", "ww1_inf_rifle", "ww1_sup_mg_nest", "ww1_arty_mortar",
	"ww1_inf_storm_e", "ww1_arm_rolls_e", "ww1_boss_av7",
	"ww2_inf_thompson", "ww2_inf_garand", "ww2_sup_mg42", "ww2_inf_panzerschreck_e",
	"ww2_inf_para_e", "ww2_arm_panther_e", "ww2_boss_kingtiger",
]

## E 段：堡垒类别（固定阵地类型，10张）
const FORT_ENEMY_IDS: Array[String] = [
	"ww1_fort_pillbox", "ww1_fort_artillery",
	"ww2_fort_bunker", "ww2_fort_flak",
	"cold_fort_missile", "cold_fort_radar",
	"mod_fort_citadel", "mod_fort_phalanx",
	"fut_fort_ion", "fut_fort_shield",
]

## C 段：固定敌人（与 enemy_archetypes.json 一致，36张）
## 前14张（索引0-13）缴获卡面 → vis_player_036~049（C'段已接入）
## 后22张（索引14-35）缴获卡面 → vis_player_050~071（需生成素材后接入）
const FIXED_ENEMY_IDS: Array[String] = [
	"ww1_inf_mp18", "ww1_inf_rifle", "ww1_sup_mg_nest", "ww1_arty_mortar",
	"ww1_inf_storm_e", "ww1_arm_rolls_e", "ww1_boss_av7",
	"ww2_inf_thompson", "ww2_inf_garand", "ww2_sup_mg42", "ww2_inf_panzerschreck_e",
	"ww2_inf_para_e", "ww2_arm_panther_e", "ww2_boss_kingtiger",
	"cold_inf_ak", "cold_inf_m60", "cold_arm_btr_e", "cold_air_m113_e",
	"cold_inf_spetsnaz_e", "cold_arm_t72_e", "cold_boss_mig",
	"mod_inf_marine", "mod_air_technical_e", "mod_arm_stryker_e", "mod_arty_mlrs_e",
	"mod_inf_delta_e", "mod_arm_abrams_e", "mod_air_apache_e", "mod_boss_command",
	"fut_air_drone", "fut_inf_cyborg", "fut_arm_mech_e", "fut_arm_hovertank_e",
	"fut_inf_spectre_e", "fut_arm_colossus_e", "fut_boss_nexus",
]

## D 段：补充敌人（29张）
const POOL_ENEMY_IDS: Array[String] = [
	"ww1_inf_enfield", "ww1_arm_rolls_mk2", "ww1_sup_vickers", "ww1_sup_ford_ambulance", "ww1_inf_mp18_x",
	"ww2_arm_garand_para", "ww2_arty_hummel", "ww2_arty_pak40", "ww2_sup_gmc_truck", "ww2_inf_kar98k",
	"cold_arty_bmd1", "cold_sup_bmp1_x", "cold_inf_metis", "cold_arm_p18", "cold_arty_brem1",
	"mod_sup_m4_carbine", "mod_inf_patriot", "mod_arm_himars", "mod_arty_rq7", "mod_sup_growler",
	"fut_inf_neural", "fut_arm_hk07", "fut_arty_hel30", "fut_sup_nrepair", "fut_inf_x9",
	"fut_inf_c96", "fut_arm_sdkfz", "fut_arty_ssc1", "fut_sup_ps9",
]

## D段显示名
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

const UNITS_ICON_DIR := "res://assets/card_icons/"
## 根据 visual_id + 敌我确定子目录：
## - vis_player_/vis_enemy_ 前缀：按前缀定目录（for_player 可改写前缀）
## - 非 vis_ 前缀（如 D 段新 id cold_inf_metis）：按 for_player 分流到 player/enemy
static func _icon_subdir(visual_id: String, for_player: bool = true) -> String:
	if visual_id.begins_with("vis_player_"):
		return "player/"
	if visual_id.begins_with("vis_enemy_"):
		return "enemy/"
	# 非 vis_ 前缀：直接按敌我分流（图文件名为 <新id>.png）
	return "player/" if for_player else "enemy/"

# ─────────────────────────────────────────────
#  A/B段敌人卡属性表（直接定义，不从旧平台卡克隆）
#  新格式: { "kind": combat_kind, "hp": base_hp,
#            "weapon_type": WeaponTypeNew, "deploy_speed": 0-7,
#            "attack_light/armor/air": 多维攻击,
#            "defense_light/armor/air": 多维防御,
#            "rng": base_range, "ivl": base_interval,
#            "spd": base_speed, "weapon": weapon_label }
# ─────────────────────────────────────────────

## FOE_PLATFORM_CARD_IDS 直接 ID → 已有 platform_* 属性键映射
const _FOE_ID_TO_PLATFORM: Dictionary = {
	"ww1_arm_rolls": "platform_ww1_medium",
	"ww1_arm_ft17": "platform_ww1_medium",
	"ww1_arty_77mm": "platform_ww1_fort",
	"ww1_inf_cavalry": "platform_ww1_light",
	"ww1_sup_engineer": "platform_ww1_medic",
	"ww2_inf_hellcat": "platform_ww2_raider",
	"ww2_arm_sherman": "platform_ww2_medium",
	"ww2_arm_tiger": "platform_ww2_heavy",
	"ww2_inf_bazooka": "platform_ww2_light",
	"ww2_inf_panzerschrek": "platform_ww2_light",
	"ww2_arty_m81": "platform_ww2_fortress",
	"ww1_arty_m81": "platform_ww1_fort",
	"cold_inf_btr60": "platform_cold_ifv",
	"cold_arm_t55": "platform_cold_medium",
	"cold_inf_bmp1": "platform_cold_ifv",
	"cold_sup_m113": "platform_cold_carrier",
	"cold_sup_zsu23": "platform_cold_radar",
	"fut_inf_scout_mech": "platform_future_light",
	"fut_arm_hovertank": "platform_future_medium",
	"fut_arm_prism": "platform_future_heavy",
	"fut_arm_heavy_mech": "platform_future_heavy",
	"fut_arm_nexus": "fut_arm_omega",
		# 现代时代（FOE_PLATFORM_CARD_IDS 现代段）
		"mod_inf_technical": "platform_modern_light",
		"mod_arm_m1a1": "platform_modern_medium",
		"mod_sup_m6": "platform_modern_radar",
		"mod_arty_m270": "platform_modern_spg",
		"mod_inf_scout_drone": "platform_modern_stealth",
		"mod_arm_m1a2sep": "platform_modern_guard_heavy",
	}

## v8.0: 统一表条目（玩家口径）→ foe_stats 口径转换。
## 字段映射：base_hp→hp, range_value格→rng像素(×100), atk_l_speed次/秒→ivl秒(1/speed),
##           base_speed正值→spd正值(manifest 内部再转负), combat_kind→kind
static func _unified_to_foe_stats(entry: Dictionary) -> Dictionary:
	var ck: int = int(entry.get("combat_kind", 0))
	var main_spd: float = float(entry.get("atk_l_speed", 1.0))
	# 取主攻维度的攻速（装甲取 atk_a_speed，空中取 atk_air_speed）
	if ck == 1:
		var a_spd: float = float(entry.get("atk_a_speed", 0.0))
		if a_spd > 0.0:
			main_spd = a_spd
	elif ck == 3:
		var air_spd: float = float(entry.get("atk_air_speed", 0.0))
		if air_spd > 0.0:
			main_spd = air_spd
	var ivl: float = (1.0 / main_spd) if main_spd > 0.0 else 1.0
	var rng_px: float = float(entry.get("range_value", 3)) * 100.0
	return {
		"kind": ck,
		"hp": float(entry.get("base_hp", 100.0)),
		"weapon_type": int(entry.get("weapon_type", 0)),
		"deploy_speed": int(entry.get("deploy_speed", 3)),
		"attack_light": float(entry.get("atk_l", 0.0)),
		"attack_armor": float(entry.get("atk_a", 0.0)),
		"attack_air": float(entry.get("atk_air", 0.0)),
		"defense_light": float(entry.get("def_l", 0.0)),
		"defense_armor": float(entry.get("def_a", 0.0)),
		"defense_air": float(entry.get("def_air", 0.0)),
		"rng": rng_px,
		"ivl": ivl,
		"spd": float(entry.get("base_speed", 0.0)),
		"weapon": String(entry.get("weapon_label", "")),
	}


static func _get_foe_stats(card_id: String) -> Dictionary:
	# v8.1: 统一表为唯一数据源。所有 foe 卡（含 platform_*）已全部进 unified_card_table。
	# 三级查询：① 直接 card_id → ② _FOE_ID_TO_PLATFORM 映射后的 platform_* → ③ 默认兜底
	var unified: Dictionary = UnifiedCardTable.get_entry(card_id)
	if not unified.is_empty():
		return _unified_to_foe_stats(unified)
	# 尝试通过 _FOE_ID_TO_PLATFORM 映射（如 ww2_arm_tiger → platform_ww2_heavy）
	var mapped_key: String = String(_FOE_ID_TO_PLATFORM.get(card_id, ""))
	if not mapped_key.is_empty():
		var mapped_unified: Dictionary = UnifiedCardTable.get_entry(mapped_key)
		if not mapped_unified.is_empty():
			return _unified_to_foe_stats(mapped_unified)
	# 兜底：D段池子卡默认值（理论上不应命中，所有池子卡已在统一表）
	push_warning("[EnemyUnitManifest] _get_foe_stats: card_id '%s' not in unified table, using fallback" % card_id)
	return {"kind": 0, "hp": 150.0, "weapon_type": 0, "deploy_speed": 4,
			"attack_light": 30.0, "attack_armor": 10.0, "attack_air": 0.0,
			"defense_light": 10.0, "defense_armor": 5.0, "defense_air": 3.0,
			"rng": 150.0, "ivl": 1.0, "spd": 80.0, "weapon": "步枪"}


## D段池子卡按 kind 的属性修正
static func _pool_stats_for_kind(kind: int) -> Dictionary:
	match kind:
		0: return {"hp": 55.0, "weapon_type": 0, "deploy_speed": 5,
				  "attack_light": 10.0, "attack_armor": 7.0, "attack_air": 6.0,
				  "defense_light": 4.0, "defense_armor": 3.0, "defense_air": 3.0,
				  "rng": 110.0, "ivl": 0.50, "spd": 120.0, "weapon": "冲锋枪"}
		1: return {"hp": 120.0, "weapon_type": 0, "deploy_speed": 3,
				  "attack_light": 16.0, "attack_armor": 11.0, "attack_air": 10.0,
				  "defense_light": 10.0, "defense_armor": 8.0, "defense_air": 8.0,
				  "rng": 155.0, "ivl": 0.90, "spd": 60.0, "weapon": "步枪"}
		2: return {"hp": 200.0, "weapon_type": 1, "deploy_speed": 0,
				  "attack_light": 25.0, "attack_armor": 18.0, "attack_air": 16.0,
				  "defense_light": 14.0, "defense_armor": 11.0, "defense_air": 11.0,
				  "rng": 180.0, "ivl": 1.50, "spd": 0.0, "weapon": "迫击炮"}
		3: return {"hp": 90.0, "weapon_type": 0, "deploy_speed": 3,
				  "attack_light": 8.0, "attack_armor": 6.0, "attack_air": 5.0,
				  "defense_light": 6.0, "defense_armor": 5.0, "defense_air": 5.0,
				  "rng": 130.0, "ivl": 0.40, "spd": 70.0, "weapon": "手枪"}
		_: return {"hp": 100.0, "weapon_type": 0, "deploy_speed": 4,
				  "attack_light": 14.0, "attack_armor": 10.0, "attack_air": 9.0,
				  "defense_light": 8.0, "defense_armor": 6.0, "defense_air": 6.0,
				  "rng": 155.0, "ivl": 0.95, "spd": 75.0, "weapon": "步枪"}


# ─────────────────────────────────────────────
#  公开接口
# ─────────────────────────────────────────────

## 返回该 archetype 的卡图标文件路径。
## `for_player=true`（默认）：我方/UI 用，返回 vis_player_*（敌方原图的水平翻转图）。
## `for_player=false`：敌方战场单位用，返回 vis_enemy_*（原图）。
## 设计：落实"我方卡 = 敌方图水平反转"——敌我取图分流于文件名前缀。
##   vis_enemy_NNN = 敌方原图；vis_player_NNN = 其水平翻转（由 tools/generate_mirrored_player_icons.py 生成）。
##   _visual_id_for_source_id 已统一以 vis_player 命名我方映射；for_player=false 时把 vis_player 改写成 vis_enemy。
static func get_unit_icon_path_for_archetype(archetype_id: String, for_player: bool = true) -> String:
	var aid := String(archetype_id).strip_edges()
	if aid.is_empty():
		return ""
	_ensure_unit_icon_map()
	var rel: String = String(_unit_icon_by_archetype.get(aid, ""))
	# v8.2 修复：foe_ 前缀查不到时，去前缀再查。
	# 根因：ui_asset_loader 用 archetype_id_for_platform_card 给 card_id 加 foe_ 前缀再查本表，
	# 但 PLATFORM/SPECIAL 段的 key 是 foe_<id>（能命中），而 FIXED/CAPTURED/POOL/FORT 段的
	# key 是 <id>（无 foe_ 前缀，_make_fixed_row/_make_pool_row/_make_fort_row 用原 id）。
	# 这导致 FIXED 等段的卡（如 ww1_inf_mp18/fut_inf_cyborg/ww1_fort_pillbox）查询 miss → fallback 撞图。
	# 此兜底让两种 key 形式都能命中，零侵入修复全段。
	if rel.is_empty() and aid.begins_with("foe_"):
		rel = String(_unit_icon_by_archetype.get(aid.substr(4), ""))
	if rel.is_empty():
		return ""
	# 敌方取原图：把 vis_player 翻转图改写为 vis_enemy 原图（编号不变）。
	if not for_player and rel.begins_with("vis_player_"):
		rel = "vis_enemy_" + rel.substr(len("vis_player_"))
	var subdir := _icon_subdir(rel, for_player)
	var full := "%s%s%s.png" % [UNITS_ICON_DIR, subdir, rel]
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
	return 28 + 6 + 36 + 29 + 10  # A段 + B段 + C段 + D段 + E段堡垒


static func captured_card_id_for(archetype_id: String) -> String:
	return "%s%s" % [CAPTURED_PREFIX, String(archetype_id).strip_edges()]


static func is_captured_card_id(card_id: String) -> bool:
	return String(card_id).begins_with(CAPTURED_PREFIX)


static func archetype_id_for_platform_card(platform_card_id: String) -> String:
	return "foe_%s" % String(platform_card_id).strip_edges()


## 获取全部100张敌人条目
static func get_entries() -> Array:
	if not _entries_cache.is_empty():
		return _entries_cache
	var rows: Array = []
	for pid in FOE_PLATFORM_CARD_IDS:
		rows.append(_make_foe_row(pid))
	for sid in FOE_SPECIAL_CARD_IDS:
		rows.append(_make_foe_row(sid))
	for eid in FIXED_ENEMY_IDS:
		rows.append(_make_fixed_row(eid))
	for i in range(POOL_ENEMY_IDS.size()):
		rows.append(_make_pool_row(i))
	for fid in FORT_ENEMY_IDS:
		rows.append(_make_fort_row(fid))
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


# ─────────────────────────────────────────────
#  行构建（新模型：不再从 default_cards 克隆）
# ─────────────────────────────────────────────

## A/B段：直接从属性表生成
static func _make_foe_row(card_id: String) -> Dictionary:
	var era: int = _era_from_platform_id(card_id)
	var aid: String = archetype_id_for_platform_card(card_id)
	var s: Dictionary = _get_foe_stats(card_id)
	var display_name: String = _get_foe_display_name(card_id)
	var speed: float = 0.0
	if s.spd > 0.0:
		speed = -maxf(40.0, float(s.spd) * 0.65)
	return {
		"archetype_id": aid,
		"display_name": display_name,
		"era": era,
		"visual_id": _visual_id_for_source_id(card_id),
		"drop_card_id": captured_card_id_for(aid),
		"template_card_id": "",  # 不再需要旧模板
		"drop_trigger": "on_kill",
		"drop_chance": _default_drop_chance("frontline"),
		"archetype_config": {
			"era": era,
			"display_name": display_name,
			"hp": s.hp,
			"speed": speed,
			# v6.3: 三维攻击（完整透传，不再坍缩成单一 attack_damage）
			"attack_light": s.attack_light,
			"attack_armor": s.attack_armor,
			"attack_air": s.attack_air,
			"attack_range": s.rng,
			"attack_interval": s.ivl,
			"combat_kind": _manifest_kind_to_combat_kind(s.kind),
			"weapon_label": s.weapon,
			"weapon_type": int(s.weapon_type),
			# v6.3: 三维防御（完整透传，不再坍缩成单一 defense）
			"defense_light": s.defense_light,
			"defense_armor": s.defense_armor,
			"defense_air": s.defense_air,
			"tags": _tags_for_kind(s.kind),
			"swarm_unit": (s.kind == 0),
			"drops": [{"card_id": captured_card_id_for(aid), "chance": 0.08}],
		},
	}


## C段：固定敌人（基础配置来自 enemy_archetypes，此处只建掉落与 id）
static func _make_fixed_row(enemy_id: String) -> Dictionary:
	var era: int = _era_from_enemy_id(enemy_id)
	return {
		"archetype_id": enemy_id,
		"display_name": "",
		"era": era,
		"visual_id": _visual_id_for_source_id(enemy_id),
		"drop_card_id": captured_card_id_for(enemy_id),
		"template_card_id": "",
		"drop_trigger": "on_kill",
		"drop_chance": _default_drop_chance(_tag_tier_from_id(enemy_id)),
		"archetype_config": {},
	}


## D段：池子卡
## v8.0: 优先从统一卡牌表读取真实数据，废弃 _pool_stats_for_kind 的 kind 统一公式
static func _make_pool_row(index: int) -> Dictionary:
	var aid: String = POOL_ENEMY_IDS[index]
	var era: int = clampi(index / 5, 0, 4)
	var kind: int = index % 4
	var display_name: String = POOL_DISPLAY_NAMES[index] if index < POOL_DISPLAY_NAMES.size() else aid
	# v8.0: 优先从统一表读取；查不到回退 _pool_stats_for_kind（兼容兜底）
	var s: Dictionary
	var unified: Dictionary = UnifiedCardTable.get_entry(aid)
	if not unified.is_empty():
		s = _unified_to_foe_stats(unified)
		kind = int(unified.get("combat_kind", kind))
		era = int(unified.get("era", era))
	else:
		s = _pool_stats_for_kind(kind)
	var speed: float = 0.0
	if s.spd > 0.0:
		speed = -maxf(40.0, float(s.spd) * 0.65)
	return {
		"archetype_id": aid,
		"display_name": display_name,
		"era": era,
		"visual_id": aid,
		"drop_card_id": captured_card_id_for(aid),
		"template_card_id": "",
		"drop_trigger": "on_kill",
		"drop_chance": 0.08,
		"archetype_config": {
			"era": era,
			"display_name": display_name,
			"hp": s.hp,
			"speed": speed,
			# v6.3: 三维攻击（完整透传）
			"attack_light": s.attack_light,
			"attack_armor": s.attack_armor,
			"attack_air": s.attack_air,
			"attack_range": s.rng,
			"attack_interval": s.ivl,
			"combat_kind": kind,
			"weapon_label": s.weapon,
			"weapon_type": int(s.weapon_type),
			# v6.3: 三维防御（完整透传）
			"defense_light": s.defense_light,
			"defense_armor": s.defense_armor,
			"defense_air": s.defense_air,
			"tags": _tags_for_kind(kind),
			"swarm_unit": (kind == 0),
			"drops": [{"card_id": captured_card_id_for(aid), "chance": 0.08}],
		},
	}


## E 段：堡垒类别（固定阵地，combat_kind=4）
## v8.0: 从 UnifiedCardTable（统一卡牌表）读取数值，解除对 CapturedCardStats 的反向依赖。
## 原 v6.13 从 captured_card_stats 读取是临时方案，现统一到单一数据源。
static func _make_fort_row(fort_id: String) -> Dictionary:
	var era: int = _era_from_fort_id(fort_id)
	var display_name: String = _get_fort_display_name(fort_id)
	# v8.0: 从统一表读取（fort_id 直接是统一表 card_id）
	var s: Dictionary = _unified_to_foe_stats(UnifiedCardTable.get_entry(fort_id))
	var hp: float = float(s.get("hp", 600.0))
	var rng: float = float(s.get("rng", 100.0))
	var ivl: float = float(s.get("ivl", 0.0))
	return {
		"archetype_id": fort_id,
		"display_name": display_name,
		"era": era,
		"visual_id": "vis_player_%03d" % (72 + FORT_ENEMY_IDS.find(fort_id)),
		"drop_card_id": captured_card_id_for(fort_id),
		"template_card_id": "",
		"drop_trigger": "on_kill",
		"drop_chance": 0.12,
		"archetype_config": {
			"era": era,
			"display_name": display_name,
			"hp": hp,
			"speed": 0.0,                                            # 堡垒不动
			"attack_light": float(s.get("attack_light", 0.0)),
			"attack_armor": float(s.get("attack_armor", 0.0)),
			"attack_air": float(s.get("attack_air", 0.0)),
			"attack_range": rng,
			"attack_interval": ivl,
			"combat_kind": 4,  # 堡垒
			"weapon_label": String(s.get("weapon", "")),
			"weapon_type": int(s.get("weapon_type", 0)),
			"defense_light": float(s.get("defense_light", 0.0)),
			"defense_armor": float(s.get("defense_armor", 0.0)),
			"defense_air": float(s.get("defense_air", 0.0)),
			"tags": ["fortress", "immobile"],
			"swarm_unit": false,
			"drops": [{"card_id": captured_card_id_for(fort_id), "chance": 0.12}],
		},
	}


# ─────────────────────────────────────────────
#  辅助函数
# ─────────────────────────────────────────────

static func _tags_for_kind(kind: int) -> Array:
	match kind:
		2: return ["turret", "sustained"]
		3: return ["support"]
		4: return ["fortress", "immobile"]  # v5.0 堡垒
		1: return ["vehicle", "armored"]
		_: return ["frontline"]


## manifest 的 kind（0=frontline步兵/1=vehicle装甲/2=turret火炮/3=support支援/4=fortress堡垒）
## → CombatKind（0=LIGHT/1=ARMOR/2=SUPPORT/3=AIR/4=FORT）
## 关键：manifest kind:3 的语义是"支援"，不是 CombatKind.AIR(3)；数值相同但含义不同。
## 不做映射的话，地面支援单位（BMP-1/维修框架/运载）会被错判成空中单位（缩放+悬浮）。
static func _manifest_kind_to_combat_kind(kind: int) -> int:
	match kind:
		0: return GC.CombatKind.LIGHT
		1: return GC.CombatKind.ARMOR
		2: return GC.CombatKind.SUPPORT
		3: return GC.CombatKind.SUPPORT   # manifest 的"支援"归 CombatKind.SUPPORT，绝不能是 AIR
		4: return GC.CombatKind.FORT
		_: return GC.CombatKind.LIGHT


static func _get_foe_display_name(card_id: String) -> String:
	match card_id:
		"platform_ww1_light": return "威克斯侦察车"
		"platform_ww1_medium": return "马克V型坦克"
		"platform_ww1_fort": return "要塞固定炮"
		"platform_ww1_radar": return "野战观测站"
		"platform_ww1_medic": return "野战救护车"
		"platform_ww2_light": return "M8灰狗装甲车"
		"platform_ww2_medium": return "谢尔曼坦克"
		"platform_ww2_heavy": return "虎式坦克"
		"platform_ww2_raider": return "BA-64轻型突击车"
		"platform_ww2_radar": return "雷达指挥车"
		"platform_ww2_siege": return "203毫米迫击炮"
		"platform_ww2_fortress": return "混凝土碉堡"
		"platform_cold_light": return "悍马侦察车"
		"platform_cold_medium": return "T-72主战坦克"
		"platform_cold_ifv": return "布雷德利步战车"
		"platform_cold_scout": return "BRDM-2侦察车"
		"platform_cold_radar": return "电子对抗站"
		"platform_cold_carrier": return "BMP步战车"
		"mod_inf_technical": return "皮卡武装"
		"mod_arm_m1a1": return "M1A1主战坦克"
		"mod_sup_m6": return "自行高炮M6"
		"mod_arty_m270": return "M270火箭炮"
		"mod_inf_scout_drone": return "侦察无人机"
		"mod_arm_m1a2sep": return "M1A2 SEP主战坦克"
		# 直接 ID 显示名（与 default_cards 对齐）
		"ww1_arm_rolls": return "罗尔斯装甲车"
		"ww1_arm_ft17": return "FT-17轻型坦克"
		"ww1_arty_77mm": return "77mm野战炮"
		"ww1_inf_cavalry": return "骑兵斥候"
		"ww1_sup_engineer": return "工兵班"
		"ww2_inf_hellcat": return "M18地狱猫"
		"ww2_arm_sherman": return "M4谢尔曼"
		"ww2_arm_tiger": return "虎式坦克"
		"ww2_inf_bazooka": return "巴祖卡组"
		"ww2_inf_panzerschrek": return "铁拳反坦克组"
		"ww2_arty_m81": return "81mm迫击炮"
		"ww1_arty_m81": return "81mm迫击炮组"
		"cold_inf_btr60": return "BTR-60装甲车"
		"cold_arm_t55": return "T-55坦克"
		"cold_inf_bmp1": return "BMP-1步战车"
		"cold_sup_m113": return "M113装甲车"
		"cold_sup_zsu23": return "ZSU-23-4自行高炮"
		"fut_inf_scout_mech": return "侦察机甲"
		"fut_arm_hovertank": return "悬浮坦克"
		"fut_arm_prism": return "光棱坦克"
		"fut_arm_heavy_mech": return "重装机甲"
		"fut_arm_nexus": return "虚空领主"
		"platform_modern_light": return "北极星全地形车"
		"platform_modern_medium": return "艾布拉姆斯坦克"
		"platform_modern_radar": return "相控阵雷达车"
		"platform_modern_spg": return "帕拉丁自行火炮"
		"platform_modern_stealth": return "光学隐匿侦察车"
		"platform_modern_guard_heavy": return "豹2A7主战坦克"
		"platform_future_light": return "光学侦察车"
		"platform_future_medium": return "悬浮坦克"
		"platform_future_radar": return "量子感知平台"
		"platform_future_heavy": return "机甲步行者"
		"fut_arm_omega": return "全装型机动舱"
		"fut_sup_bulwark": return "壁垒"
		"fut_arm_titan_mk2": return "泰坦Mk.II"
		"fut_inf_storm_rider": return "暴风骑士"
		"fut_air_heavy_carrier": return "重装母舰"
		"fut_air_regen_frame": return "再生骨架"
		"mod_arm_abrams_mk2": return "艾布拉姆斯Mk.II"
		_: return card_id


static func _merge_fixed_config(row: Dictionary, base_cfg: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_cfg.duplicate(true)
	var aid: String = String(row.get("archetype_id", ""))
	var chance: float = float(row.get("drop_chance", 0.08))
	var drop_id: String = String(row.get("drop_card_id", ""))
	if not drop_id.is_empty():
		cfg["drops"] = [{"card_id": drop_id, "chance": chance}]
	return cfg


## 供 EnemyArchetypes 调用：在固定 JSON 配置上追加缴获掉落。
## v7.x 修复：原逻辑无条件覆盖 cfg["drops"]，导致 JSON 配置的特色掉落卡
## （如 drop_smg_mk2 / drop_mega_particle_cannon）被 captured_* 完全替换、
## 从未运行时生效。改为追加模式——保留已有 drops（特色卡），仅补充 captured_* 缴获卡。
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
			# 追加 captured_* 缴获卡（若已有 drops 中未含同前缀项则补充，保留特色卡）
			var existing_drops: Array = cfg.get("drops", [])
			if not _has_drop_with_prefix(existing_drops, "captured_"):
				existing_drops.append({"card_id": drop_id, "chance": chance})
				cfg["drops"] = existing_drops
			if not String(row.get("display_name", "")).is_empty():
				cfg["display_name"] = String(row.get("display_name", ""))
			out[aid] = cfg
	return out


## 检查 drops 数组中是否已存在指定前缀的 card_id 项（防重复追加 captured_*）
static func _has_drop_with_prefix(drops: Array, prefix: String) -> bool:
	for d in drops:
		if d is Dictionary:
			var cid: String = String((d as Dictionary).get("card_id", ""))
			if cid.begins_with(prefix):
				return true
	return false


static func _era_from_platform_id(card_id: String) -> int:
	if card_id.contains("ww1"):
		return 0
	if card_id.contains("ww2"):
		return 1
	if card_id.contains("cold"):
		return 2
	if card_id.contains("modern") or card_id.begins_with("mod_"):
		return 3
	if card_id.contains("future") or card_id.begins_with("fut_") or card_id == "fut_arm_omega":
		return 4
	return 0


static func _era_from_enemy_id(enemy_id: String) -> int:
	if enemy_id.contains("ww1"):
		return 0
	if enemy_id.contains("ww2"):
		return 1
	if enemy_id.contains("cold"):
		return 2
	# v7.x 修复：mod_ 前缀（如 mod_fort_*）不会 contains("modern")，需显式前缀判定
	if enemy_id.contains("modern") or enemy_id.begins_with("mod_"):
		return 3
	# v7.x 修复：fut_ 前缀（如 fut_fort_*）不会 contains("future")，需显式前缀判定
	if enemy_id.contains("future") or enemy_id.contains("near") or enemy_id.begins_with("fut_"):
		return 4
	return 0


static func _era_from_fort_id(fort_id: String) -> int:
	if fort_id.contains("ww1"):
		return 0
	if fort_id.contains("ww2"):
		return 1
	if fort_id.contains("cold"):
		return 2
	# v7.x 修复：堡垒 id 用 mod_ 前缀（mod_fort_citadel/mod_fort_phalanx），不含 "modern" 子串——
	# 原仅 contains("modern") 判定会让 mod_fort_* 全部回退到 era=0（一战），现代堡垒混入一战池。
	if fort_id.contains("modern") or fort_id.begins_with("mod_"):
		return 3
	# v7.x 修复：堡垒 id 用 fut_ 前缀（fut_fort_ion/fut_fort_shield），不含 "future" 子串——
	# 原仅 contains("future") 判定会让 fut_fort_*（含 3000 血能量护盾）全部回退到 era=0（一战），
	# 近未来堡垒混入第 1 关。补 begins_with("fut_") 前缀判定。
	if fort_id.contains("future") or fort_id.begins_with("fut_"):
		return 4
	return 0


static func _get_fort_display_name(fort_id: String) -> String:
	match fort_id:
		"ww1_fort_pillbox": return "混凝土机枪碉堡"
		"ww1_fort_artillery": return "要塞炮台"
		"ww2_fort_bunker": return "混凝土碉堡"
		"ww2_fort_flak": return "88mm防空塔"
		"cold_fort_missile": return "导弹发射井"
		"cold_fort_radar": return "雷达站"
		"mod_fort_citadel": return "要塞核心"
		"mod_fort_phalanx": return "近防炮系统"
		"fut_fort_ion": return "离子炮台"
		"fut_fort_shield": return "能量护盾发生器"
		_: return fort_id


static func _tag_tier_from_id(enemy_id: String) -> String:
	# v7.x 修复：原 begins_with("boss_") 无法匹配 cold_boss_mig / mod_boss_command /
	# fut_boss_nexus（boss 在中间非前缀），导致 3 个时代 Boss 缴获掉率被误判为 8%。
	# 改用 contains 判定，同时兼容 *_elite_* 命名变体。
	if enemy_id.contains("boss"):
		return "boss"
	if enemy_id.contains("elite"):
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


## 与 docs/card_icon_manifest_100_agent_prompts.md 编号一致
static func _visual_id_for_source_id(source_id: String) -> String:
	var sid: String = source_id.strip_edges()
	## 堡垒类别 → vis_player_072~081（我方翻转图；敌方经 for_player=false 改写为 vis_enemy_072~081 原图）
	for i in range(FORT_ENEMY_IDS.size()):
		if sid == FORT_ENEMY_IDS[i]:
			return "vis_player_%03d" % (72 + i)
	## 缴获卡面 → vis_player_036~049
	for i in range(CAPTURED_ENEMY_IDS.size()):
		if sid == CAPTURED_ENEMY_IDS[i]:
			return "vis_player_%03d" % (36 + i)
	## 固定敌人缴获卡面 → vis_player_036~071
	## 索引0-13 → vis_player_036~049 (C'段)
	## 索引14-35 → vis_player_050~071 (C''段)
	var fixed_idx: int = FIXED_ENEMY_IDS.find(sid)
	if fixed_idx >= 0:
		return "vis_player_%03d" % (36 + fixed_idx)
	## 补充池 → 直接用新 id 作图名（enemy/<新id>.png + player/<新id>.png）
	var pool_idx: int = POOL_ENEMY_IDS.find(sid)
	if pool_idx >= 0:
		return sid
	## 特殊/精英 → vis_player_030~035
	var special_idx: int = FOE_SPECIAL_CARD_IDS.find(sid)
	if special_idx >= 0:
		return "vis_player_%03d" % (30 + special_idx)
	## 平台 → vis_player_001~028
	var platform_idx: int = FOE_PLATFORM_CARD_IDS.find(sid)
	if platform_idx >= 0:
		return "vis_player_%03d" % (platform_idx + 1)
	return sid
