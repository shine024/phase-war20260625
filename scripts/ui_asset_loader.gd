extends RefCounted
class_name UiAssetLoader
## 静态工具：加载 `assets/ui/*`、`assets/card_icons/*` 等美术，带简单缓存。

const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const GC = preload("res://resources/game_constants.gd")

const UNITS_ICON_DIR := "res://assets/card_icons/"

## 兵种聚合键 → manifest A 段代表图（根目录聚合 PNG 归档后的回退）
## 英文角色名 + 中文 combat_kind 短名双键（get_shape_key() 返回中文）
const SHAPE_KEY_UNIT_ICON: Dictionary = {
	# 英文角色名（遗留兼容）
	"hound": "vis_player_001",
	"titan": "vis_player_002",
	"fortress": "vis_player_003",
	"radar": "vis_player_004",
	"medic": "vis_player_005",
	"scout": "vis_player_006",
	"guard": "vis_player_007",
	"raider": "vis_player_009",
	"siege": "vis_player_011",
	"carrier": "vis_player_015",
	"stealth": "vis_player_023",
	"omega_platform": "vis_player_029",
	# 中文 combat_kind 短名 → 按兵种选代表图
	"轻": "vis_player_001",   # LIGHT → hound（轻装步兵）
	"甲": "vis_player_002",   # ARMOR → titan（装甲）
	"援": "vis_player_005",   # SUPPORT → medic（支援）
	"空": "vis_player_015",   # AIR → carrier（空中）
	"堡": "vis_player_003",   # FORTRESS → fortress（堡垒）
}

static var _tex_cache: Dictionary = {}

## 时代(0-4) + combat_kind(0-4) → 最接近的 vis_player 代表图
## key = "era_kind"，value = vis_player_NNN
const ERA_KIND_FALLBACK_ICON: Dictionary = {
	# 一战
	"0_0": "vis_player_004",  # WWI Light    → ww1_cavalry
	"0_1": "vis_player_001",  # WWI Armor    → ww1_rolls
	"0_2": "vis_player_003",  # WWI Support  → ww1_77mm
	"0_3": "vis_player_015",  # WWI Air      → cold_bmp1
	"0_4": "vis_player_003",  # WWI Fortress → ww1_77mm
	# 二战
	"1_0": "vis_player_009",  # WWII Light    → ww2_bazooka
	"1_1": "vis_player_007",  # WWII Armor    → ww2_sherman
	"1_2": "vis_player_011",  # WWII Support  → ww2_m81
	"1_3": "vis_player_022",  # WWII Air      → fut_scout_drone
	"1_4": "vis_player_011",  # WWII Fortress → ww2_m81
	# 冷战
	"2_0": "vis_player_018",  # Cold Light    → mod_technical
	"2_1": "vis_player_014",  # Cold Armor    → cold_t55
	"2_2": "vis_player_016",  # Cold Support  → cold_m113
	"2_3": "vis_player_015",  # Cold Air      → cold_bmp1
	"2_4": "vis_player_016",  # Cold Fortress → cold_m113
	# 现代
	"3_0": "vis_player_018",  # Modern Light    → mod_technical
	"3_1": "vis_player_019",  # Modern Armor    → mod_m1a1
	"3_2": "vis_player_020",  # Modern Support  → mod_m6
	"3_3": "vis_player_022",  # Modern Air      → fut_scout_drone
	"3_4": "vis_player_020",  # Modern Fortress → mod_m6
	# 近未来
	"4_0": "vis_player_024",  # Future Light    → fut_scout_mech
	"4_1": "vis_player_025",  # Future Armor    → fut_hovertank
	"4_2": "vis_player_020",  # Future Support  → mod_m6
	"4_3": "vis_player_022",  # Future Air      → fut_scout_drone
	"4_4": "vis_player_025",  # Future Fortress → fut_hovertank
}

## v7.x 我方战斗卡 → 专属 vis_player 图 override（74条）
## 背景：我方 card_id（如 ww2_panther）与敌方 card_id（如 ww2_arm_panther_e）命名体系不同，
## manifest 的 foe_* 映射查不到这些我方 ID，导致它们此前走 ERA_KIND 通用回退（如 7 种二战坦克
## 全显示成谢尔曼）。本表为每张我方卡指定语义最匹配的专属图编号，在 manifest 查询失败后、
## ERA_KIND 回退前生效。已 manifest 命中的 38 张卡不受影响。
const PLAYER_ICON_OVERRIDE: Dictionary = {
	# 一战
	"ww1_lanchest": "vis_player_001",   # 兰彻斯特装甲车 → 罗尔斯装甲车（同期轮式装甲车）
	"ww1_105mm": "vis_player_003",      # 105mm榴弹炮 → 77mm野战炮（重型火炮）
	"ww1_37mm": "vis_player_003",       # 37mm高射炮 → 77mm野战炮（火炮通用）
	"ww1_mp18": "vis_player_036",       # MP18突击班 → 步兵班·MP18 ★完美同名
	"ww1_mauser": "vis_player_037",     # 毛瑟步枪班 → 步兵班·步枪
	"ww1_enfield": "vis_player_037",    # 李恩菲尔德班 → 步兵班·步枪
	"ww1_mg08": "vis_player_038",       # MG08机枪巢 → 机枪巢 ★完美同名
	"ww1_vickers": "vis_player_038",    # 维克斯机枪巢 → 机枪巢
	"ww1_m76": "vis_player_039",        # 76mm迫击炮组 → 迫击炮组 ★完美同名
	"ww1_storm": "vis_player_040",      # 暴风突击队 → 暴风突击队 ★完美同名
	"ww1_flame": "vis_player_036",      # 火焰喷射兵 → 步兵班·MP18（步兵通用）
	"ww1_mark4": "vis_player_041",      # 马克IV型坦克 → 装甲车（同期装甲）
	"ww1_a7v": "vis_player_042",        # A7V重型坦克 → 圣沙蒙坦克（同期重坦）
	"ww1_saint": "vis_player_042",      # 圣沙蒙坦克 → 圣沙蒙坦克 ★完美同名
	# 二战
	"ww2_pz3": "vis_player_007",        # 三号坦克 → M4谢尔曼（中型坦克通用）
	"ww2_pz4": "vis_player_007",        # 四号坦克 → M4谢尔曼
	"ww2_t34_76": "vis_player_007",     # T-34/76 → M4谢尔曼
	"ww2_t34_85": "vis_player_007",     # T-34/85 → M4谢尔曼
	"ww2_is2": "vis_player_008",        # IS-2重型坦克 → 虎式坦克（重型坦克）
	"ww2_m120": "vis_player_011",       # 120mm重迫击炮 → 81mm迫击炮
	"ww2_mp40": "vis_player_043",       # MP40班 → 步兵班·汤普森（冲锋枪班）
	"ww2_ppsh": "vis_player_043",       # 波波沙班 → 步兵班·汤普森
	"ww2_thompson": "vis_player_043",   # 汤普森班 → 步兵班·汤普森 ★完美同名
	"ww2_garand": "vis_player_044",     # 加兰德班 → 步枪班·加兰德 ★完美同名
	"ww2_mg42": "vis_player_045",       # MG42机枪组 → MG42机枪组 ★完美同名
	"ww2_browning": "vis_player_045",   # 勃朗宁机枪组 → MG42机枪组（机枪通用）
	"ww2_panther": "vis_player_048",    # 黑豹坦克 → 黑豹坦克 ★完美同名
	"ww2_kingtiger": "vis_player_049",  # 虎王坦克 → 虎王坦克 ★完美同名
	# 冷战
	"cold_sam7": "vis_player_017",      # 萨姆-7防空组 → ZSU-23-4自行高炮（防空）
	"cold_rpg": "vis_player_046",       # RPG火箭筒组 → 反坦克组
	"cold_m60": "vis_player_045",       # M60机枪班 → MG42机枪组（机枪通用）
	"cold_rpk": "vis_player_045",       # RPK机枪班 → MG42机枪组
	"cold_ak47": "vis_player_050",      # AK-47步兵班 → 苏军步兵
	"cold_m14": "vis_player_051",       # M14步兵班 → 美军步兵
	"cold_leo1": "vis_player_052",      # 豹1坦克 → BTR装甲车（西方装甲）
	"cold_m1": "vis_player_052",        # M1主战坦克 → BTR装甲车
	"cold_m60t": "vis_player_052",      # M60坦克 → BTR装甲车
	"cold_bradley": "vis_player_053",   # M2布雷德利 → M113装甲车（步战车）
	"cold_spetsnaz": "vis_player_054",  # 阿尔法特种部队 → 特种部队 ★完美同名
	"cold_chieftain": "vis_player_055", # 酋长坦克 → T-72坦克（重型坦克）
	"cold_t62": "vis_player_055",       # T-62坦克 → T-72坦克（苏系坦克）
	"cold_t72": "vis_player_055",       # T-72坦克 → T-72坦克 ★完美同名
	"cold_f4": "vis_player_056",        # F-4鬼怪战机 → 米格-29（战机）
	"cold_mig21": "vis_player_056",     # 米格-21战机 → 米格-29（米格系列）
	# 现代
	"mod_t90": "vis_player_055",        # T-90坦克 → T-72坦克（苏系现代坦克）
	"mod_marine": "vis_player_057",     # 海军陆战队 → 海军陆战队 ★完美同名
	"mod_hummer_m2": "vis_player_058",  # 悍马·M2 → 皮卡武装（轮式车辆）
	"mod_hummer_tow": "vis_player_058", # 悍马·陶式 → 皮卡武装
	"mod_stryker_m2": "vis_player_059", # 斯特赖克M2 → 斯特赖克装甲车 ★完美同名
	"mod_stryker_mgs": "vis_player_059",# 斯特赖克MGS → 斯特赖克装甲车
	"fut_aa_hover": "vis_player_060",   # 防空悬浮车 → 火箭炮车（自行火炮）
	"fut_howitzer": "vis_player_060",   # 悬浮自行火炮 → 火箭炮车
	"mod_ranger": "vis_player_061",     # 游骑兵 → 三角洲部队（精锐步兵）
	"mod_challenger2": "vis_player_062",# 挑战者2 → M1A2坦克（西方主战坦克）
	"mod_leo2a6": "vis_player_062",     # 豹2A6 → M1A2坦克
	"mod_m1a2": "vis_player_062",       # M1A2艾布拉姆斯 → M1A2坦克 ★完美同名
	"mod_ah1": "vis_player_063",        # AH-1眼镜蛇 → 阿帕奇直升机（武装直升机）
	"mod_ah64": "vis_player_063",       # AH-64阿帕奇 → 阿帕奇直升机 ★完美同名
	"mod_stinger": "vis_player_063",    # 毒刺导弹兵 → 阿帕奇直升机（防空/飞行器）
	"mod_uh60": "vis_player_063",       # UH-60黑鹰 → 阿帕奇直升机（直升机通用）
	"mod_javelin": "vis_player_046",    # 标枪导弹兵 → 反坦克组（导弹步兵）
	# 近未来
	"fut_attack_drone": "vis_player_065",   # 攻击无人机 → 无人机群
	"fut_nano_drone": "vis_player_065",     # 纳米修复机 → 无人机群
	"fut_space_fighter": "vis_player_065",  # 空天战斗机 → 无人机群（飞行器）
	"fut_stealth_bomber": "vis_player_065", # 隐形轰炸机 → 无人机群
	"fut_swarm": "vis_player_065",          # 蜂群无人机 → 无人机群 ★完美同名
	"fut_cyborg": "vis_player_066",         # 机械步兵 → 机械步兵 ★完美同名
	"fut_heavy_trooper": "vis_player_066",  # 重装机兵 → 机械步兵
	"fut_assault_mech": "vis_player_067",   # 突击机甲 → 机甲步兵
	"fut_spectre": "vis_player_069",        # 幽灵特工 → 幽灵特工 ★完美同名
	"fut_arm_omega": "vis_player_070",      # 全装型机动舱 → 巨神机甲（重型机甲）
	"fut_colossus": "vis_player_070",       # 巨神机甲 → 巨神机甲 ★完美同名
	"fut_stormcore": "vis_player_071",      # 风暴核心原型 → 风暴核心 ★完美同名
	"fut_shield": "vis_player_081",         # 力场发生器 → 能量护盾发生器 ★完美同名
}


static func _era_kind_fallback_path(era: int, combat_kind: int) -> String:
	var key: String = "%d_%d" % [clampi(era, 0, 4), clampi(combat_kind, 0, 4)]
	var vis_id: String = String(ERA_KIND_FALLBACK_ICON.get(key, ""))
	if vis_id.is_empty():
		return ""
	var path: String = "%splayer/%s.png" % [UNITS_ICON_DIR, vis_id]
	return path if ResourceLoader.exists(path, "Texture2D") else ""


static func _path_for_shape_key(shape_key: String) -> String:
	var key: String = shape_key.strip_edges()
	if key.is_empty():
		return ""
	var vis_id: String = String(SHAPE_KEY_UNIT_ICON.get(key, ""))
	if not vis_id.is_empty():
		var unit_p: String = "%splayer/%s.png" % [UNITS_ICON_DIR, vis_id]
		if ResourceLoader.exists(unit_p, "Texture2D"):
			return unit_p
	var legacy: String = "res://assets/card_icons/%s.png" % key
	if ResourceLoader.exists(legacy, "Texture2D"):
		return legacy
	return ""


static func load_tex(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _tex_cache.has(path):
		var prev: Variant = _tex_cache[path]
		if prev is Texture2D:
			return prev as Texture2D
		_tex_cache.erase(path)
	if not ResourceLoader.exists(path):
		_tex_cache[path] = null
		return null
	var loaded: Resource = ResourceLoader.load(path)
	var t: Texture2D = loaded as Texture2D
	if t == null:
		_tex_cache[path] = null
		return null
	_tex_cache[path] = t
	return t


static func ui_icon(icon_basename: String) -> Texture2D:
	var base := "res://assets/ui/icons/%s" % icon_basename
	var svg_path := base + ".svg"
	if ResourceLoader.exists(svg_path):
		return load_tex(svg_path)
	return load_tex(base + ".png")


static func faction_logo_128(faction_id: String) -> Texture2D:
	return load_tex("res://assets/ui/factions/%s_128.png" % faction_id)


## 胜利星级图标（battle_result_panel 使用）
static func star_icon(star_level: int) -> Texture2D:
	var n: int = clampi(star_level, 1, 8)
	return load_tex("res://assets/ui/stars/star_%d.png" % n)


## 单颗金星（SVG），用于横排「几星几颗」
static func star_unit_gold_svg() -> Texture2D:
	return load_tex("res://assets/ui/stars/star_unit_gold.svg")


static func instrument_icon(pi_id: String) -> Texture2D:
	return load_tex("res://assets/ui/instruments/%s.png" % pi_id)


## 符文图标（按 rune_id 加载对应稀有度 PNG；缺失时返回 null，调用方回退到颜色染色）
static func rune_icon(rune_id: String) -> Texture2D:
	return load_tex(RuneDefinitions.icon_path_for(rune_id))


## 背包/槽位：优先 `card_id` 对应卡面，否则退回 `get_shape_key()` 聚合图。

const CARD_FRAME_RARITIES: Array[String] = [
	"common", "uncommon", "rare", "epic", "legendary", "mythic",
]


## 稀有度 PNG 卡框（5:8，透明中心）`res://assets/cards/frames/<rarity>.png`
## 注意：项目暂无 mythic.png 素材。mythic（神话）比 legendary 更稀有，
## 回退到 legendary 框（金色高级系，视觉最接近），而非 common（会导致神话卡显示普通框）。
static func card_frame_path_for(rarity: String) -> String:
	var r := rarity.strip_edges().to_lower()
	if r == "mythic":
		r = "legendary"
	elif r not in CARD_FRAME_RARITIES:
		r = "common"
	return "res://assets/cards/frames/%s.png" % r


static func card_frame_for_rarity(rarity: String) -> Texture2D:
	return load_tex(card_frame_path_for(rarity))


const CARD_BG_FACTION_IDS: Array[String] = [
	"neutral", "iron_wall_corp", "nova_arms", "aether_dynamics",
	"quantum_logistics", "helix_recon", "void_research", "frontier_union",
]


static func card_background_path_for(faction_id: String) -> String:
	var fid := faction_id.strip_edges().to_lower()
	if fid.is_empty() or fid not in CARD_BG_FACTION_IDS:
		fid = "neutral"
	if fid == "neutral":
		return "res://assets/cards/backgrounds/bg_neutral.png"
	return "res://assets/cards/backgrounds/bg_%s.png" % fid


static func card_background_for_faction(faction_id: String) -> Texture2D:
	return load_tex(card_background_path_for(faction_id))


static func archetype_id_for_card_icon(c: CardResource) -> String:
	if c == null:
		return ""
	var cid: String = c.card_id.strip_edges()
	if cid.begins_with("captured_"):
		return cid.substr(9)
	return cid


static func _manifest_icon_for_archetype(archetype_id: String) -> String:
	var aid: String = archetype_id.strip_edges()
	if aid.is_empty():
		return ""
	return EnemyUnitManifest.get_unit_icon_path_for_archetype(aid)


## 我方平台卡 `platform_*` / 精英平台 / `omega_platform` → `foe_*` → `units/vis_player_*`
static func manifest_icon_path_for_platform_card_id(platform_card_id: String) -> String:
	var cid: String = platform_card_id.strip_edges()
	if cid.is_empty():
		return ""
	return _manifest_icon_for_archetype(EnemyUnitManifest.archetype_id_for_platform_card(cid))


static func _platform_card_id_for_icon(c: CardResource) -> String:
	if c == null:
		return ""
	if c.card_type == GC.CardType.COMBAT_UNIT and not String(c.source_platform_id).strip_edges().is_empty():
		return String(c.source_platform_id).strip_edges()
	if c.card_type == GC.CardType.COMBAT_UNIT:
		return c.card_id.strip_edges()
	return ""


## 生成平台蓝图 `bp_<era>_<n>` → 清单 A 段 `vis_player_*`（仅平台条，不含武器蓝图）
static func _vis_player_path_for_bp_platform(card_id: String) -> String:
	var parts: PackedStringArray = card_id.split("_")
	if parts.size() != 3 or parts[0] != "bp":
		return ""
	var era_key: String = parts[1]
	var seq: int = int(parts[2])
	if seq <= 0:
		return ""
	var era_idx: int = ["ww1","ww2","cold","modern","near"].find(era_key)
	if era_idx < 0:
		return ""
	var vis_idx: int = 1
	for e in range(era_idx):
		vis_idx += 0
	vis_idx += seq - 1
	var full: String = "res://assets/card_icons/player/vis_player_%03d.png" % vis_idx
	return full if ResourceLoader.exists(full, "Texture2D") else ""


static func card_icon_path_for(c: CardResource) -> String:
	if c == null:
		return ""
	# 0) v6.5: 优先用专属卡面（card_icons/{card_id}.png），有专属图则不走 manifest 回退
	# 避免新加入的专属图被旧的 vis_player 通用图覆盖
	var dedicated: String = "res://assets/card_icons/%s.png" % c.card_id
	if ResourceLoader.exists(dedicated, "Texture2D"):
		return dedicated
	# 1) 战斗卡 → manifest（card_id → foe_* → vis_player_*）
	if c.card_type == GC.CardType.COMBAT_UNIT:
		var plat_p: String = manifest_icon_path_for_platform_card_id(_platform_card_id_for_icon(c))
		if not plat_p.is_empty():
			return plat_p
		# 1.5) v7.x 我方卡 override：我方 card_id 与敌方命名体系不同，manifest foe_* 查不到时，
		# 按本表取语义最匹配的专属 vis_player 图（避免走 ERA_KIND 通用回退导致大量撞图）
		var override_vis: String = String(PLAYER_ICON_OVERRIDE.get(c.card_id, ""))
		if not override_vis.is_empty():
			var override_p: String = "%splayer/%s.png" % [UNITS_ICON_DIR, override_vis]
			if ResourceLoader.exists(override_p, "Texture2D"):
				return override_p
	# 2) 缴获/敌人 archetype → units/<visual_id>.png
	var arch: String = archetype_id_for_card_icon(c)
	if not arch.is_empty():
		var manifest_p: String = _manifest_icon_for_archetype(arch)
		if not manifest_p.is_empty():
			return manifest_p
	# 3) 掉落表反查 archetype
	var drop_arch: String = EnemyArchetypes.get_visual_archetype_id_for_card(c.card_id)
	if not drop_arch.is_empty():
		var from_drop: String = _manifest_icon_for_archetype(drop_arch)
		if not from_drop.is_empty():
			return from_drop
		var arch_root: String = "res://assets/card_icons/%s.png" % drop_arch
		if ResourceLoader.exists(arch_root, "Texture2D"):
			return arch_root
	# 4) 法则 / 能量卡
	if c.card_type == GC.CardType.LAW:
		var law_id: String = c.linked_law_id.strip_edges()
		if law_id.is_empty():
			law_id = c.card_id.strip_edges()
		return law_slot_icon_path(law_id)
	if c.card_type == GC.CardType.ENERGY:
		var energy_by_id: String = "res://assets/card_icons/%s.png" % c.card_id
		if ResourceLoader.exists(energy_by_id, "Texture2D"):
			return energy_by_id
		var energy_shape: String = _path_for_shape_key("energy")
		if not energy_shape.is_empty():
			return energy_shape
	# 5) 根目录 card_id PNG
	var by_id: String = "res://assets/card_icons/%s.png" % c.card_id
	if ResourceLoader.exists(by_id, "Texture2D"):
		return by_id
	# 6) 时代+兵种代表图回退（所有不在 manifest 的战斗卡至少拿到同期同类图）
	if c.card_type == GC.CardType.COMBAT_UNIT:
		var era_kind_p: String = _era_kind_fallback_path(c.era, c.combat_kind)
		if not era_kind_p.is_empty():
			return era_kind_p
	# 7) 聚合 shape 键
	var shape_p: String = _path_for_shape_key(c.get_shape_key())
	if not shape_p.is_empty():
		return shape_p
	const PLACEHOLDER := "res://assets/card_icons/_enemy_placeholder.png"
	if ResourceLoader.exists(PLACEHOLDER, "Texture2D"):
		return PLACEHOLDER
	return ""


## 法则槽：优先 `law_id` 卡面，否则 `law` 聚合图，再否则 UI `icon_law`。
static func law_slot_icon_path(law_id: String) -> String:
	if not law_id.is_empty():
		var by_law: String = "res://assets/card_icons/%s.png" % law_id
		if ResourceLoader.exists(by_law, "Texture2D"):
			return by_law
	var law_shape: String = "res://assets/card_icons/law.png"
	if ResourceLoader.exists(law_shape, "Texture2D"):
		return law_shape
	return "res://assets/ui/icons/icon_law.svg"


static func apply_button_icon(btn: Button, icon_basename: String) -> void:
	var t: Texture2D = ui_icon(icon_basename)
	if t == null or btn == null:
		return
	btn.icon = t
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func apply_close_icons_recursive(root: Node) -> void:
	if root == null:
		return
	for ch in root.get_children():
		apply_close_icons_recursive(ch)
	if root is Button and root.name == "CloseButton":
		apply_button_icon(root as Button, "icon_close")


static func setup_texrect_icon(tr: TextureRect, tex: Texture2D, px: Vector2) -> void:
	if tr == null:
		return
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = px
	if tex != null:
		tr.texture = tex
		tr.visible = true
	else:
		tr.texture = null
		tr.visible = false


## v7.x: 图本身已携带朝向（vis_player=我方翻转图，vis_enemy=敌方原图），
## UI 取图经 card_icon_path_for 默认拿到 vis_player，故不再需要 flip_h 翻转。
## 保留 face_right 参数仅为兼容现有调用点，实际为 no-op。
static func apply_card_icon_facing(tr: TextureRect, face_right: bool) -> void:
	if tr == null:
		return
	tr.flip_h = false


static func setup_card_unit_icon(tr: TextureRect, tex: Texture2D, px: Vector2, face_right: bool = true) -> void:
	setup_texrect_icon(tr, tex, px)
	apply_card_icon_facing(tr, face_right)
