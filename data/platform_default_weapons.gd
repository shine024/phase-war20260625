extends RefCounted
## 平台卡 → 默认武器 ID 映射
## 供 affix_panel 等面板查询平台卡绑定的默认武器名称

const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")

## 按 combat_kind 推断默认武器 card_id 前缀
static func resolve_default_weapon_id(platform_card_id: String) -> String:
	# 优先从敌方装备表查找（平台卡通常有 default_weapon 字段）
	var ew := EnemyPhaseEquipment.get_default_weapon_id_for_platform(platform_card_id)
	if not ew.is_empty():
		return ew

	# 回退：根据卡的 combat_kind 推断通用武器
	var card := DefaultCards.get_card_by_id(platform_card_id)
	if card == null:
		return ""
	var ck: int = card.combat_kind if card.combat_kind >= 0 else 0
	match ck:
		GC.CombatKind.LIGHT:
			return "weapon_infantry_mg"
		GC.CombatKind.ARMOR:
			return "weapon_tank_gun"
		GC.CombatKind.SUPPORT:
			return "weapon_artillery"
		GC.CombatKind.AIR:
			return "weapon_air_gun"
		GC.CombatKind.FORT:
			return "weapon_fort_gun"
		_:
			return ""
