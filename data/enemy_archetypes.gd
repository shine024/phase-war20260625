extends RefCounted
class_name EnemyArchetypes

const _ARCHETYPES_JSON_PATH := "res://data/json/enemy_archetypes.json"
const CapturedUnitCards = preload("res://data/captured_unit_cards.gd")

## 数据子模块预加载
const _ArchWW = preload("res://data/enemy_archetypes_ww.gd")
const _ArchColdModern = preload("res://data/enemy_archetypes_cold_modern.gd")
const _ArchFuture = preload("res://data/enemy_archetypes_future.gd")

static var _manifest_merged: Dictionary = {}
static var _manifest_building: bool = false

static func _load_json_dict(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != 1:
		return fallback
	var data = parsed.get("data", fallback)
	return data if typeof(data) == TYPE_DICTIONARY else fallback

## 敌人原型与掉落蓝图定义（数据驱动）
##
## 战斗数值以 hp / attack_damage / speed 等为基底；波次与关卡等叠乘由 enemy_stat_resolver.gd 统一解析。
##
## 每个 archetype 包含：
## - display_name: 显示名称
## - hp: 基础生命值
## - speed: 水平移动速度（负数表示向左）
## - attack_damage: 单次攻击伤害
## - attack_range: 攻击距离
## - attack_interval: 攻击间隔（秒）
## - weapon_type: 可选，GameConstants.WeaponType，用于攻击弹道/激光/导弹等显示
## - tags: AI / 行为标签数组（用于后续扩展）
## - drops: 掉落蓝图数组，每项为 {card_id, chance}
## - era: 时代 0=一战 1=二战 2=冷战 3=现代 4=近未来（与 LevelEras.Era 一致）
## - swarm_unit: 为 true 时使用蜂群轻量路径（无刚体血条、MultiMesh 绘制、死亡粒子）
## - card_icon_path（可选）: 战场/卡面用单张 PNG；未填时由 `resolve_card_icon_texture_path` 按 archetype 名推导
## - nano_materials_kill（可选）：击杀经 BasicResourceManager 发放纳米材料。false=关闭默认档；
##   int/float=固定数量（几率 1.0）；{ chance, min, max }=先判定 chance 再在 [min,max] 随机（数量可乘关卡掉落倍率上限 1）

## 合并所有时代原型数据的遗留字典（向后兼容）
const LEGACY_ARCHETYPES := {}

## 运行时合并子模块数据
static func _merged_legacy_archetypes() -> Dictionary:
	var d: Dictionary = {}
	d.merge(_ArchWW.DATA)
	d.merge(_ArchColdModern.DATA)
	d.merge(_ArchFuture.DATA)
	return d

static var ARCHETYPES: Dictionary = _load_json_dict(_ARCHETYPES_JSON_PATH, _merged_legacy_archetypes())

const GC = preload("res://resources/game_constants.gd")
const ERA_PREFIX: Array[String] = ["ww1", "ww2", "cold", "modern", "near"]
const TARGET_ARCHETYPE_COUNT: int = 150
## 100 基本敌人清单启用后关闭程序批量生成（见 data/enemy_unit_manifest.gd）
const GENERATED_PER_ERA: int = 0
## 每个时代前若干 bp_* 视为“平台蓝图”区间（与 enemy_blueprints.gd 生成顺序一致）
const ERA_BP_COUNT: Array[int] = [26, 26, 26, 26, 26]
const PLATFORM_BP_COUNT_BY_ERA: Array[int] = [10, 10, 9, 9, 10]

## 各时代可用武器类型（GC.WeaponType：0 SMG 1 RIFLE 2 MG 3 ROCKET 4 PISTOL 5 SHOTGUN 6 SNIPER 7 FLAK 8 LASER 9 MISSILE 10 OMEGA）
## 避免“现代坦克装一战手枪”等错配：按单位类型再过滤
const WEAPONS_BY_ERA: Array = [
	[0, 1, 2, 3, 4, 5, 6, 7],           # 一战：无激光/导弹/米加
	[0, 1, 2, 3, 4, 5, 6, 7],           # 二战：同上
	[0, 1, 2, 3, 4, 5, 6, 7, 9],        # 冷战：+导弹
	[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],     # 现代：+激光、导弹
	[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], # 近未来：全
]
## 步兵：轻武器（冲锋枪/步枪/手枪/霰弹），不会拿高射炮/米加炮当主武
const WEAPONS_INFANTRY: Array = [0, 1, 4, 5]
## 载具/坦克：车载火力，不用手枪/霰弹
const WEAPONS_VEHICLE: Array = [0, 1, 2, 3, 6, 7]
## 固定阵地：机枪/迫击炮/狙击/高射
const WEAPONS_TURRET: Array = [2, 3, 6, 7]
## 支援/轻装：冲锋枪、手枪
const WEAPONS_SUPPORT: Array = [0, 4]

enum UnitKind { INFANTRY, VEHICLE, TURRET, SUPPORT }
const UNIT_KIND_LABEL: Array[String] = ["步兵", "载具", "阵地", "支援"]
const DEFAULT_VISUAL_SCALE: float = 1.0
const ARCHETYPE_VISUAL_SCALE_OVERRIDES: Dictionary = {
	# WW1
	"enemy_ww1_infantry_basic": 0.378,
	"enemy_ww1_infantry_rifle": 0.474,
	"enemy_ww1_mg_nest": 0.318,
	"enemy_ww1_mortar": 0.33,
	"elite_ww1_storm": 0.432,
	"elite_ww1_armored": 0.6,
	"boss_ww1_av7": 0.66,
	# WW2
	"enemy_ww2_infantry": 0.312,
	"enemy_ww2_rifleman": 0.324,
	"enemy_ww2_mg42": 0.318,
	"enemy_ww2_panzerschreck": 0.324,
	"elite_ww2_paratrooper": 0.36,
	"elite_ww2_panther": 1.38,
	"boss_ww2_kingtiger": 0.66,
	# Cold War
	"enemy_cold_ak": 0.39,
	"enemy_cold_m60": 0.342,
	"enemy_cold_btr": 0.552,
	"enemy_cold_m113": 0.612,
	"elite_cold_spetsnaz": 0.438,
	"elite_cold_t72": 0.66,
	"boss_cold_mig": 1.44,
	# Modern
	"enemy_modern_marine": 0.456,
	"enemy_modern_technical": 0.312,
	"enemy_modern_stryker": 0.75,
	"enemy_modern_mlrs": 0.84,
	"elite_modern_delta": 0.552,
	"elite_modern_abrams": 0.36,
	"elite_modern_apache": 0.78,
	"boss_modern_command": 0.78,
	# Future
	"enemy_future_drone": 0.9,
	"enemy_future_cyborg": 0.66,
	"enemy_future_mech": 0.642,
	"enemy_future_hovertank": 0.66,
	"elite_future_spectre": 0.36,
	"elite_future_colossus": 0.66,
	"boss_future_nexus": 0.78,
}
## 若你希望所有敌人都显示完整精灵动画而非蜂群几何体，保持 false。
## 需要压测性能时可改回 true（仅对配置了 swarm_unit=true 的敌人生效）。
const ENABLE_SWARM_RENDER: bool = false

# ─────────────────────────────────────────────
# 更有意义的敌人名称生成
# ─────────────────────────────────────────────

## 各时代各兵种的前缀名称库（按序号循环使用）
const ERA_KIND_PREFIXES: Dictionary = {
	0: {  # 一战
		0: ["志愿兵", "突击队", "堑壕兵", "民兵", "征召兵"],
		1: ["装甲车", "侦察车", "突击炮", "运输车", "支援车"],
		2: ["机枪阵地", "迫击炮组", "野战炮", "碉堡", "防空炮"],
		3: ["医疗兵", "补给队", "通讯班", "工兵", "炊事班"]
	},
	1: {  # 二战
		0: ["步兵班", "伞兵", "狙击手", "突击队", "侦察兵"],
		1: ["坦克", "装甲车", "自行火炮", "半履带车", "突击炮"],
		2: ["机枪组", "反坦克炮", "高射炮", "火箭炮", "固定阵地"],
		3: ["后勤班", "医疗队", "修理组", "通讯排", "补给队"]
	},
	2: {  # 冷战
		0: ["步兵", "特种兵", "侦察兵", "支援兵", "空降兵"],
		1: ["主战坦克", "步兵战车", "装甲运输", "自行火炮", "防空车"],
		2: ["机枪阵地", "反坦克导弹", "高射炮", "火箭炮", "岸防炮"],
		3: ["后勤组", "维修班", "医疗分队", "雷达站", "通讯中心"]
	},
	3: {  # 现代
		0: ["陆战队员", "特种部队", "侦察兵", "突击队", "支援兵"],
		1: ["装甲车", "主战坦克", "步兵战车", "自行火炮", "防空系统"],
		2: ["机枪阵地", "反坦克组", "近防炮", "火箭炮", "导弹发射架"],
		3: ["后勤分队", "医疗队", "修理组", "无人机班", "电子战组"]
	},
	4: {  # 近未来
		0: ["机械步兵", "突击兵", "幽灵兵", "赛博兵", "猎杀者"],
		1: ["悬浮坦克", "机甲", "装甲车", "攻击平台", "运输舰"],
		2: ["能量炮台", "导弹阵地", "激光炮", "防御矩阵", "控制中心"],
		3: ["纳米维修", "能量补给", "战术支援", "数据单元", "相位站"]
	}
}

## 各时代各兵种的后缀名称库（用于多样化）
const ERA_KIND_SUFFIXES: Dictionary = {
	0: {  # 一战
		0: ["A队", "B队", "连", "排", "班"],
		1: ["Mk.I", "Mk.II", "型", "改进型", "改"],
		2: ["阵地", "阵位", "组", "班", "分队"],
		3: ["分队", "小组", "班", "组", "队"]
	},
	1: {  # 二战
		0: ["班", "排", "分队", "组", "小队"],
		1: ["型", "改", "改进型", "后期型", "量产型"],
		2: ["组", "阵地", "炮位", "分队", "班"],
		3: ["班", "组", "分队", "小队", "队"]
	},
	2: {  # 冷战
		0: ["班", "排", "分队", "组", "小队"],
		1: ["型", "改进型", "后期型", "现代化", "升级型"],
		2: ["组", "阵地", "导弹连", "炮位", "分队"],
		3: ["分队", "小组", "班", "组", "队"]
	},
	3: {  # 现代
		0: ["班", "分队", "组", "小队", "特遣队"],
		1: ["型", "改进型", "数字化", "先进型", "特种型"],
		2: ["组", "阵地", "系统", "炮位", "分队"],
		3: ["分队", "小组", "班", "特遣组", "支援队"]
	},
	4: {  # 近未来
		0: ["班", "小队", "特遣组", "猎杀组", "突击队"],
		1: ["型", "试验型", "量产型", "特种型", "精英型"],
		2: ["系统", "矩阵", "平台", "网络", "核心"],
		3: ["单元", "系统", "站", "中心", "节点"]
	}
}

## 生成更有意义的敌人名称
static func _generate_meaningful_enemy_name(era: int, kind: int, index: int) -> String:
	var era_name: String = ["一战", "二战", "冷战", "现代", "近未来"][era] if era >= 0 and era < 5 else "未知"
	var kind_prefixes: Array = ERA_KIND_PREFIXES.get(era, {}).get(kind, ["单位"])
	var kind_suffixes: Array = ERA_KIND_SUFFIXES.get(era, {}).get(kind, [""])

	# 使用序号循环选择前缀和后缀
	var prefix: String = kind_prefixes[index % kind_prefixes.size()]
	var suffix: String = kind_suffixes[(index + 1) % kind_suffixes.size()]

	# 组合名称
	if not suffix.is_empty():
		return "%s·%s%s" % [era_name, prefix, suffix]
	else:
		return "%s·%s" % [era_name, prefix]

static func _weapon_pool_for_era_and_kind(era: int, kind: int) -> Array:
	var era_list: Array = WEAPONS_BY_ERA[era] if era >= 0 and era < WEAPONS_BY_ERA.size() else WEAPONS_BY_ERA[0]
	var kind_list: Array = [WEAPONS_INFANTRY, WEAPONS_VEHICLE, WEAPONS_TURRET, WEAPONS_SUPPORT][kind] if kind >= 0 and kind <= 3 else WEAPONS_INFANTRY
	var out: Array = []
	for w in era_list:
		if w in kind_list:
			out.append(w)
	if out.is_empty():
		out.append(0)
	return out

static var _generated_cache: Dictionary = {}
static var _era_bp_count_cache: Dictionary = {}

static func _get_generated_archetypes() -> Dictionary:
	if not _generated_cache.is_empty():
		return _generated_cache
	var era_names: Array[String] = ["一战", "二战", "冷战", "现代", "近未来"]
	var out: Dictionary = {}
	for e in range(5):
		var prefix: String = ERA_PREFIX[e]
		var era_name: String = era_names[e]
		for i in range(GENERATED_PER_ERA):
			var id_key: String = "enemy_%s_%02d" % [prefix, i + 1]
			var kind: int = i % 4  # 0=步兵 1=载具 2=阵地 3=支援
			var pool: Array = _weapon_pool_for_era_and_kind(e, kind)
			var weapon_type: int = pool[ (e + i) % pool.size() ]
			# 约 20% 单位装备双武器（主武 + 同池次武）
			var weapon_types: Array = [weapon_type]
			if (e * GENERATED_PER_ERA + i) % 5 == 0 and pool.size() > 1:
				var second: int = pool[ (e + i + 1) % pool.size() ]
				if second != weapon_type:
					weapon_types.append(second)
			var kind_label: String = UNIT_KIND_LABEL[kind]
			# 使用更有意义的名称生成
			var meaningful_name: String = _generate_meaningful_enemy_name(e, kind, i / 4)
			var base: Dictionary = {
				"era": e,
				"display_name": meaningful_name,
				"hp": 70.0 + (e * 15) + (i % 5) * 8.0,
				"speed": -50.0 - (e * 5) - (20.0 if kind == 2 else 0.0),
				"attack_damage": 8.0 + e * 2 + (i % 4) * 2.0,
				"attack_range": 100.0 + (60.0 if kind == 2 else 0.0) + (e * 5),
				"attack_interval": 1.0 + (0.5 if kind == 2 else 0.0),
				"weapon_type": weapon_type,
				"tags": ["frontline"],
				"drops": _generated_blueprint_drops_for_archetype(e, i),
			}
			if weapon_types.size() > 1:
				base["weapon_types"] = weapon_types
			out[id_key] = base
	_generated_cache = out
	return _generated_cache

static func _generated_blueprint_id_for_archetype(era: int, index: int) -> String:
	var safe_era: int = clampi(era, 0, ERA_PREFIX.size() - 1)
	var prefix: String = ERA_PREFIX[safe_era]
	var count: int = _get_era_blueprint_count(safe_era)
	if count <= 0:
		return "bp_%s_%03d" % [prefix, 1]
	# 线性同余映射：通过互质步长打散索引，避免只命中低序号蓝图。
	var step: int = _pick_coprime_step(count)
	var offset: int = int((safe_era * 11 + 3) % count)
	var bp_idx: int = int((offset + index * step) % count)
	return "bp_%s_%03d" % [prefix, bp_idx + 1]

static func _generated_blueprint_drops_for_archetype(era: int, index: int) -> Array:
	var primary_id: String = _generated_blueprint_id_for_archetype(era, index)
	var primary_chance: float = 0.08 + era * 0.02 + (index % 3) * 0.01
	var drops: Array = [{"card_id": primary_id, "chance": primary_chance}]
	var count: int = _get_era_blueprint_count(era)
	if count > GENERATED_PER_ERA:
		var secondary_id: String = _generated_blueprint_id_for_archetype(era, index + GENERATED_PER_ERA)
		if secondary_id != primary_id:
			# 次要掉落用于扩展时代覆盖面，同时保持主掉落为主要来源。
			var secondary_chance: float = maxf(0.04, primary_chance * 0.5)
			drops.append({"card_id": secondary_id, "chance": secondary_chance})
	return drops

static func _get_era_blueprint_count(era: int) -> int:
	if _era_bp_count_cache.has(era):
		return int(_era_bp_count_cache[era])
	var safe_era: int = clampi(era, 0, ERA_PREFIX.size() - 1)
	var prefix: String = ERA_PREFIX[safe_era]
	var actual_count: int = 0
	for id_val in get_all_ids():
		var sid: String = String(id_val)
		if sid.begins_with("bp_%s_" % prefix):
			actual_count += 1
	if actual_count <= 0:
		actual_count = ERA_BP_COUNT[safe_era] if safe_era < ERA_BP_COUNT.size() else 56
	_era_bp_count_cache[safe_era] = actual_count
	return actual_count

static func _pick_coprime_step(modulo: int) -> int:
	if modulo <= 1:
		return 1
	var candidates: Array[int] = [23, 19, 17, 13, 11, 7, 5, 3, 2]
	for c in candidates:
		if c < modulo and _gcd(c, modulo) == 1:
			return c
	for c in range(modulo - 1, 1, -1):
		if _gcd(c, modulo) == 1:
			return c
	return 1

static func _gcd(a: int, b: int) -> int:
	var x: int = absi(a)
	var y: int = absi(b)
	while y != 0:
		var t: int = x % y
		x = y
		y = t
	return max(1, x)

static func _ensure_manifest_merged() -> void:
	if not _manifest_merged.is_empty():
		return
	if _manifest_building:
		return # 防重入：避免 CapturedUnitCards → _ensure_manifest_merged 循环
	_manifest_building = true
	CapturedUnitCards.register_into_default_cards_cache()
	_manifest_merged = EnemyUnitManifest.apply_capture_drops_to_archetypes(ARCHETYPES.duplicate(true))
	for row in EnemyUnitManifest.get_entries():
		if row is not Dictionary:
			continue
		var aid: String = String(row.get("archetype_id", ""))
		var sub: Dictionary = row.get("archetype_config", {})
		if aid.is_empty() or sub.is_empty():
			continue
		if not _manifest_merged.has(aid):
			_manifest_merged[aid] = sub.duplicate(true)
	_manifest_building = false

	# ─────────────────────────────────────────────
	# 合并生成敌人的数据，确保不覆盖已存在的 display_name
	# ─────────────────────────────────────────────
	var gen_archetypes: Dictionary = _get_generated_archetypes()
	for gen_id in gen_archetypes:
		var gen_cfg: Dictionary = gen_archetypes[gen_id]
		if not _manifest_merged.has(gen_id):
			# 生成敌人不存在，直接添加
			_manifest_merged[gen_id] = gen_cfg.duplicate(true)
		else:
			# 已存在，只合并非 display_name 字段，保留原有的中文名称
			var existing_cfg: Dictionary = _manifest_merged[gen_id]
			for key in gen_cfg:
				if key != "display_name":
					existing_cfg[key] = gen_cfg[key]
			_manifest_merged[gen_id] = existing_cfg


static func get_all_ids() -> Array:
	_ensure_manifest_merged()
	var ids: Array = []
	ids.append_array(_manifest_merged.keys())
	ids.append_array(_get_generated_archetypes().keys())
	return ids

## 格子战术防御：配置内 defense 优先，否则三维防御取最大值，最后按攻/HP/标签推算
## v6.3: 支持三维防御（defense_light/armor/air），取最大值作为单一 defense
static func compute_defense_from_config(cfg: Dictionary) -> int:
	if cfg.is_empty():
		return 5
	if cfg.has("defense"):
		return int(cfg["defense"])
	# v6.3: 三维防御存在则取最大值
	if cfg.has("defense_light") or cfg.has("defense_armor") or cfg.has("defense_air"):
		var dl: float = float(cfg.get("defense_light", 0.0))
		var da: float = float(cfg.get("defense_armor", 0.0))
		var dai: float = float(cfg.get("defense_air", 0.0))
		return int(maxf(dl, maxf(da, dai)))
	var atk: float = float(cfg.get("attack_damage", 10.0))
	var hp_v: float = float(cfg.get("hp", 80.0))
	var tags: Array = cfg.get("tags", [])
	var d: int = int(round(atk * 0.45 + hp_v * 0.015))
	if tags.has("boss"):
		d += 8
	elif tags.has("elite"):
		d += 4
	if absf(float(cfg.get("speed", -60.0))) < 1.0:
		d += 3
	if cfg.get("swarm_unit", false):
		d -= 1
	return clampi(d, 3, 40)


static func get_config(id: String) -> Dictionary:
	_ensure_manifest_merged()
	var c: Dictionary = _manifest_merged.get(id, {})
	if not c.is_empty():
		return c
	c = ARCHETYPES.get(id, {})
	if not c.is_empty():
		return c
	return _get_generated_archetypes().get(id, {})

## 敌人场上/镜像视觉：单张卡图路径（无 SpriteFrames 运行时）。
## 顺序：显式 card_icon_path → assets/card_icons/<lookup>.png → work_全卡面加工/<lookup>.png
## → cfg.sprite_path → Sprite Sheet/<lookup>.png → assets/enemies/<lookup>.png
const _CARD_ICON_DIR_PRIMARY := "res://assets/card_icons/"
const _CARD_ICON_DIR_WORK := "res://assets/card_icons/work_全卡面加工/"

## 与 `enemy_unit.gd` 生成敌人 ID（enemy_<era>_<n>）共用：美术回退到固定模板 archetype
const GENERATED_ENEMY_VISUAL_TEMPLATE_MAP := {
	"ww1": ["enemy_ww1_infantry_basic", "elite_ww1_armored", "enemy_ww1_mg_nest", "enemy_ww1_mortar"],
	"ww2": ["enemy_ww2_infantry", "elite_ww2_panther", "enemy_ww2_mg42", "enemy_ww2_panzerschreck"],
	"cold": ["enemy_cold_ak", "enemy_cold_btr", "enemy_cold_m113", "enemy_cold_m60"],
	"modern": ["enemy_modern_marine", "enemy_modern_stryker", "enemy_modern_mlrs", "enemy_modern_technical"],
	"near": ["enemy_future_cyborg", "enemy_future_hovertank", "enemy_future_mech", "enemy_future_drone"],
}

static func get_generated_enemy_visual_template_id(id_key: String) -> String:
	var parts: PackedStringArray = id_key.split("_")
	if parts.size() != 3:
		return ""
	if parts[0] != "enemy":
		return ""
	var era_key: String = parts[1]
	if not GENERATED_ENEMY_VISUAL_TEMPLATE_MAP.has(era_key):
		return ""
	var idx_text: String = parts[2]
	if idx_text.is_empty() or not idx_text.is_valid_int():
		return ""
	var idx: int = maxi(0, int(idx_text) - 1)
	var kind_index: int = idx % 4
	var templates: Array = GENERATED_ENEMY_VISUAL_TEMPLATE_MAP[era_key]
	if kind_index < 0 or kind_index >= templates.size():
		return ""
	return String(templates[kind_index])


static func resolve_card_icon_texture_path(archetype_id: String, cfg: Dictionary, lookup_id: String = "") -> String:
	var lid: String = String(lookup_id).strip_edges()
	if lid.is_empty():
		lid = String(archetype_id)
	var explicit: String = String(cfg.get("card_icon_path", "")).strip_edges()
	if not explicit.is_empty() and ResourceLoader.exists(explicit):
		return explicit
	var manifest_unit: String = EnemyUnitManifest.get_unit_icon_path_for_archetype(archetype_id)
	if not manifest_unit.is_empty():
		return manifest_unit
	for dir in [_CARD_ICON_DIR_PRIMARY, _CARD_ICON_DIR_WORK]:
		var p: String = "%s%s.png" % [dir, lid]
		if ResourceLoader.exists(p):
			return p
	var sp: String = String(cfg.get("sprite_path", "")).strip_edges()
	if not sp.is_empty() and ResourceLoader.exists(sp):
		return sp
	var p_sheet: String = "res://assets/enemies/Sprite Sheet/%s.png" % lid
	if ResourceLoader.exists(p_sheet):
		return p_sheet
	var p_root: String = "res://assets/enemies/%s.png" % lid
	if ResourceLoader.exists(p_root):
		return p_root
	var tpl: String = get_generated_enemy_visual_template_id(archetype_id)
	if not tpl.is_empty() and tpl != lid:
		var tcfg: Dictionary = get_config(tpl)
		return resolve_card_icon_texture_path(archetype_id, tcfg, tpl)
	const PLACEHOLDER := "res://assets/card_icons/_enemy_placeholder.png"
	if FileAccess.file_exists(PLACEHOLDER):
		return PLACEHOLDER
	return ""

static func get_visual_scale_for_archetype(id: String, cfg: Dictionary) -> float:
	var explicit_scale: float = float(cfg.get("visual_scale", -1.0))
	if explicit_scale > 0.0:
		return explicit_scale
	var id_key: String = id
	if not id_key.is_empty() and ARCHETYPE_VISUAL_SCALE_OVERRIDES.has(id_key):
		return float(ARCHETYPE_VISUAL_SCALE_OVERRIDES[id_key])
	return DEFAULT_VISUAL_SCALE

static func get_visual_scale(cfg: Dictionary) -> float:
	return get_visual_scale_for_archetype("", cfg)

static func should_spawn_as_swarm(id: String) -> bool:
	if not ENABLE_SWARM_RENDER:
		return false
	return bool(get_config(id).get("swarm_unit", false))

static func get_ids_for_era(era: int) -> Array:
	var result: Array = []
	for id_key in get_all_ids():
		var cfg: Dictionary = get_config(id_key)
		if cfg.get("era", 0) == era:
			result.append(id_key)
	return result

static func get_drop_definitions(id: String) -> Array:
	var cfg: Dictionary = get_config(id)
	if cfg.is_empty():
		return []
	var drops: Array = cfg.get("drops", []).duplicate(true)
	# 设计目标：除极个别单位外，敌人应尽量提供可装备的平台/武器蓝图来源
	if _should_auto_add_platform_drop(id, cfg, drops):
		drops.append(_make_platform_drop_for_archetype(id, int(cfg.get("era", 0)), cfg))
	if _should_auto_add_weapon_drop(id, cfg, drops):
		drops.append(_make_weapon_drop_for_archetype(id, int(cfg.get("era", 0)), cfg))
	return drops


## 击杀时纳米材料：由 BattleDamageSystem 在敌方死亡时调用，写入 BasicResourceManager。
## drop_rate_mult：通常来自 GameManager.get_drop_rate_multiplier（与蓝图掉落倍率一致，且 clamp 到 [0,1] 用于几率上限）
static func roll_nano_materials_on_kill(archetype_id: String, drop_rate_mult: float) -> int:
	var cfg: Dictionary = get_config(archetype_id)
	if cfg.is_empty():
		return 0
	if cfg.get("nano_materials_kill", null) == false:
		return 0
	var def: Dictionary = _resolve_nano_kill_roll_definition(cfg)
	if def.is_empty():
		return 0
	var chance: float = clampf(float(def.get("chance", 0.0)) * drop_rate_mult, 0.0, 1.0)
	if randf() > chance:
		return 0
	var lo: int = maxi(0, int(def.get("min", 1)))
	var hi: int = maxi(lo, int(def.get("max", lo)))
	return randi_range(lo, hi)


static func _resolve_nano_kill_roll_definition(cfg: Dictionary) -> Dictionary:
	var raw: Variant = cfg.get("nano_materials_kill", null)
	if raw == false:
		return {}
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		var n: int = maxi(1, int(raw))
		return {"chance": 1.0, "min": n, "max": n}
	if raw is Dictionary:
		var d: Dictionary = raw
		var mn: int = maxi(0, int(d.get("min", 1)))
		var mx: int = maxi(mn, int(d.get("max", mn)))
		return {
			"chance": clampf(float(d.get("chance", 1.0)), 0.0, 1.0),
			"min": mn,
			"max": mx,
		}
	var tags: Array = cfg.get("tags", [])
	var is_swarm_foot: bool = bool(cfg.get("swarm_unit", false))
	if tags.has("boss"):
		return {"chance": 1.0, "min": 18, "max": 38}
	if tags.has("elite"):
		return {"chance": 0.88, "min": 5, "max": 12}
	if is_swarm_foot:
		return {"chance": 0.24, "min": 1, "max": 2}
	return {"chance": 0.42, "min": 2, "max": 7}


static func _should_auto_add_platform_drop(id: String, cfg: Dictionary, drops: Array) -> bool:
	# 极个别例外：纯空中单位不强制给平台掉落
	var tags: Array = cfg.get("tags", [])
	var is_air_only: bool = tags.has("aircraft") and not tags.has("vehicle")
	if is_air_only:
		return false
	for d in drops:
		if not (d is Dictionary):
			continue
		var card_id: String = String((d as Dictionary).get("card_id", ""))
		if card_id.is_empty():
			continue
	return true

static func _should_auto_add_weapon_drop(id: String, cfg: Dictionary, drops: Array) -> bool:
	# 新规则：玩家侧不再维护独立武器卡掉落通道
	return false

static func _make_platform_drop_for_archetype(archetype_id: String, era: int, cfg: Dictionary) -> Dictionary:
	var safe_era: int = clampi(era, 0, ERA_PREFIX.size() - 1)
	var prefix: String = ERA_PREFIX[safe_era]
	var platform_count: int = PLATFORM_BP_COUNT_BY_ERA[safe_era] if safe_era < PLATFORM_BP_COUNT_BY_ERA.size() else 8
	platform_count = maxi(platform_count, 1)
	var h: int = absi(archetype_id.hash())
	var platform_idx: int = (h % platform_count) + 1
	var card_id: String = "bp_%s_%03d" % [prefix, platform_idx]
	var tags: Array = cfg.get("tags", [])
	var chance: float = 0.10
	if tags.has("elite"):
		chance = 0.22
	if tags.has("boss"):
		chance = 0.45
	return {
		"card_id": card_id,
		"chance": chance,
	}

static func _make_weapon_drop_for_archetype(archetype_id: String, era: int, cfg: Dictionary) -> Dictionary:
	var safe_era: int = clampi(era, 0, ERA_PREFIX.size() - 1)
	var prefix: String = ERA_PREFIX[safe_era]
	var platform_count: int = PLATFORM_BP_COUNT_BY_ERA[safe_era] if safe_era < PLATFORM_BP_COUNT_BY_ERA.size() else 8
	var era_total: int = _get_era_blueprint_count(safe_era)
	var weapon_count: int = maxi(1, era_total - platform_count)
	var h: int = absi(archetype_id.hash())
	var weapon_offset: int = h % weapon_count
	var bp_idx: int = platform_count + weapon_offset + 1
	var card_id: String = "bp_%s_%03d" % [prefix, bp_idx]
	var tags: Array = cfg.get("tags", [])
	var chance: float = 0.12
	if tags.has("elite"):
		chance = 0.24
	if tags.has("boss"):
		chance = 0.50
	return {
		"card_id": card_id,
		"chance": chance,
	}

## 返回掉落该蓝图的敌人显示名（用于 UI 来源标注），若为默认蓝图则返回空字符串
static func get_source_enemy_name_for_blueprint(card_id: String) -> String:
	for arch_id in get_all_ids():
		var cfg: Dictionary = get_config(arch_id)
		var drops: Array = cfg.get("drops", [])
		for d in drops:
			if d is Dictionary and d.get("card_id", "") == card_id:
				return cfg.get("display_name", arch_id)
	return ""

## ─────────────────────────────────────────────
## card_id → archetype_id 反向索引（用于玩家方战斗单位的视觉同形）
##
## 数据源：archetype.drops[].card_id；同卡被多 archetype 命中时取 chance 最高，
## 同 chance 取数据遍历顺序最先（LEGACY_ARCHETYPES / JSON 自然序）。
## ─────────────────────────────────────────────
static var _card_to_archetype_lookup: Dictionary = {}
static var _card_to_archetype_lookup_built: bool = false

## 取该 card_id 应使用的 archetype 视觉 id；找不到时返回空串（调用方走兜底）
static func get_visual_archetype_id_for_card(card_id: String) -> String:
	if not _card_to_archetype_lookup_built:
		_build_card_to_archetype_lookup()
	return String(_card_to_archetype_lookup.get(card_id, ""))

## 强制重建反查表（数据热更新或测试时使用）
static func rebuild_card_to_archetype_lookup() -> void:
	_card_to_archetype_lookup_built = false
	_build_card_to_archetype_lookup()

static func _build_card_to_archetype_lookup() -> void:
	_card_to_archetype_lookup.clear()
	var best_chance: Dictionary = {}
	for arch_id in get_all_ids():
		var cfg: Dictionary = get_config(arch_id)
		var drops: Array = cfg.get("drops", [])
		for d in drops:
			if not (d is Dictionary):
				continue
			if not d.has("card_id"):
				continue
			var cid: String = String(d["card_id"])
			if cid.is_empty():
				continue
			var ch: float = float(d.get("chance", 0.0))
			if not best_chance.has(cid) or ch > float(best_chance[cid]):
				best_chance[cid] = ch
				_card_to_archetype_lookup[cid] = String(arch_id)
	_card_to_archetype_lookup_built = true
