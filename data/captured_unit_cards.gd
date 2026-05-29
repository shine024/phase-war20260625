extends RefCounted
class_name CapturedUnitCards
## 100 张缴获成品卡（captured_*）：击杀敌人后进背包，可部署。
##
## v3 重构：直接从 EnemyUnitManifest 的 archetype_config 构建战斗卡，
## 不再从旧 default_cards 平台卡克隆。

const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const GC = preload("res://resources/game_constants.gd")

static var _cache_built: bool = false


static func register_into_default_cards_cache() -> void:
	if _cache_built:
		return
	# 使用 DefaultCards 的缓存机制（如果存在）
	var DefaultCards = load("res://data/default_cards.gd")
	if DefaultCards and DefaultCards.has_method("_ensure_card_cache"):
		DefaultCards._ensure_card_cache()
	for row in EnemyUnitManifest.get_entries():
		if row is not Dictionary:
			continue
		var drop_id: String = String(row.get("drop_card_id", ""))
		if drop_id.is_empty():
			continue
		var display_name: String = String(row.get("display_name", ""))
		var cfg: Dictionary = row.get("archetype_config", {})
		var card: CardResource = _build_captured_card(drop_id, display_name, cfg)
		if card == null:
			continue
		# 写入 DefaultCards 缓存（如果可用）
		if DefaultCards and DefaultCards.has_method("_ensure_card_cache"):
			if not DefaultCards._id_lookup_cache.has(drop_id):
				DefaultCards._all_cards_cache.append(card)
				DefaultCards._id_lookup_cache[drop_id] = card
	_cache_built = true


static func _build_captured_card(
	drop_id: String,
	display_name: String,
	cfg: Dictionary
) -> CardResource:
	var c: CardResource = CardResource.new()
	c.card_id = drop_id
	c.card_type = GC.CardType.COMBAT_UNIT  # 战斗卡
	c.is_dropped_card = true

	# 从 archetype_config 读取战斗卡属性
	if not display_name.is_empty():
		c.display_name = display_name
	elif cfg.has("display_name"):
		c.display_name = String(cfg.get("display_name", ""))
	else:
		c.display_name = drop_id

	var era: int = int(cfg.get("era", 0))
	c.era = era
	c.combat_kind = int(cfg.get("combat_kind", 1))
	c.base_hp = float(cfg.get("hp", 100.0))
	c.range_value = max(1, int(round(float(cfg.get("attack_range", 120.0)) / 100.0)))
	c.attack_speed = 1.0 / maxf(0.001, float(cfg.get("attack_interval", 1.0)))
	c.weapon_label = String(cfg.get("weapon_label", ""))

	# 新增：多维攻防
	c.weapon_type = int(cfg.get("weapon_type", 0))
	c.deploy_speed = int(cfg.get("deploy_speed", 3))
	c.attack_light = float(cfg.get("attack_light", 0.0))
	c.attack_armor = float(cfg.get("attack_armor", 0.0))
	c.attack_air = float(cfg.get("attack_air", 0.0))
	c.defense_light = float(cfg.get("defense_light", 0.0))
	c.defense_armor = float(cfg.get("defense_armor", 0.0))
	c.defense_air = float(cfg.get("defense_air", 0.0))

	# 移速：从 archetype_config 的 speed 字段推算（speed 是负值或 0）
	var raw_speed: float = float(cfg.get("speed", 0.0))
	if raw_speed < 0.0:
		c.base_speed = minf(absf(raw_speed) / 0.65, 200.0)
	else:
		c.base_speed = 0.0

	# type_line
	var era_label: String = ["一战", "二战", "冷战", "现代", "近未来"][clampi(era, 0, 4)]
	var kind_label: String = CardResource.get_combat_kind_name(c.combat_kind)
	c.type_line = "%s — 缴获%s" % [era_label, kind_label]

	return c
