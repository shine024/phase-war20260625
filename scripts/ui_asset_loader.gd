extends RefCounted
class_name UiAssetLoader
## 静态工具：加载 `assets/ui/*`、`assets/card_icons/*` 等美术，带简单缓存。

const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const GC = preload("res://resources/game_constants.gd")

const UNITS_ICON_DIR := "res://assets/card_icons/units/"

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


static func _era_kind_fallback_path(era: int, combat_kind: int) -> String:
	var key: String = "%d_%d" % [clampi(era, 0, 4), clampi(combat_kind, 0, 4)]
	var vis_id: String = String(ERA_KIND_FALLBACK_ICON.get(key, ""))
	if vis_id.is_empty():
		return ""
	var path: String = "%s%s.png" % [UNITS_ICON_DIR, vis_id]
	return path if ResourceLoader.exists(path, "Texture2D") else ""


static func _path_for_shape_key(shape_key: String) -> String:
	var key: String = shape_key.strip_edges()
	if key.is_empty():
		return ""
	var vis_id: String = String(SHAPE_KEY_UNIT_ICON.get(key, ""))
	if not vis_id.is_empty():
		var unit_p: String = "%s%s.png" % [UNITS_ICON_DIR, vis_id]
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


## 背包/槽位：优先 `card_id` 对应卡面，否则退回 `get_shape_key()` 聚合图。

const CARD_FRAME_RARITIES: Array[String] = [
	"common", "uncommon", "rare", "epic", "legendary",
]


## 稀有度 PNG 卡框（5:8，透明中心）`assets/cards/frames/<rarity>.png`
static func card_frame_path_for(rarity: String) -> String:
	var r := rarity.strip_edges().to_lower()
	if r not in CARD_FRAME_RARITIES:
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
	var plat_cap: int = 0
	if seq > plat_cap:
		return ""
	var vis_idx: int = 1
	for e in range(era_idx):
		vis_idx += 0
	vis_idx += seq - 1
	var full: String = "res://assets/card_icons/units/vis_player_%03d.png" % vis_idx
	return full if ResourceLoader.exists(full, "Texture2D") else ""


static func card_icon_path_for(c: CardResource) -> String:
	if c == null:
		return ""
	# 1) 战斗卡 → manifest（card_id → foe_* → vis_player_*）
	if c.card_type == GC.CardType.COMBAT_UNIT:
		var plat_p: String = manifest_icon_path_for_platform_card_id(_platform_card_id_for_icon(c))
		if not plat_p.is_empty():
			return plat_p
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


## 清单原画默认朝左；`face_right` 为 true 时水平翻转（我方背包/相位仪/右向战场单位）。
static func apply_card_icon_facing(tr: TextureRect, face_right: bool) -> void:
	if tr == null:
		return
	tr.flip_h = face_right


static func setup_card_unit_icon(tr: TextureRect, tex: Texture2D, px: Vector2, face_right: bool = true) -> void:
	setup_texrect_icon(tr, tex, px)
	apply_card_icon_facing(tr, face_right)
