extends RefCounted
class_name DefaultCards
## 默认背包卡片数据（用于演示） - v3 架构修复版

const GC = preload("res://resources/game_constants.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const EnemyBlueprints = preload("res://data/enemy_blueprints.gd")
const CapturedUnitCards = preload("res://data/captured_unit_cards.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
const RealWorldUnitLabels = preload("res://data/real_world_unit_labels.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const CardResource = preload("res://resources/card_resource.gd")

## 旧版法则卡 id → PhaseLaws.id（存档/商店兼容）
const LEGACY_LAW_CARD_ID_MAP: Dictionary = {
	"law_steel_passive_1": "steel_phase_armor",
	"law_steel_passive_2": "steel_quick_repair",
	"law_steel_active": "steel_bastion_wall",
	"law_flame_passive_1": "flame_heat_overload",
	"law_flame_passive_2": "flame_afterburn",
	"law_flame_active": "flame_front_bombard",
	"law_thunder_passive_1": "thunder_arc_beacon",
	"law_thunder_passive_2": "thunder_emp_storm",
	"law_thunder_active": "thunder_emp_storm",
	"law_void_passive_1": "void_entropy_lens",
	"law_void_passive_2": "void_time_ripple",
	"law_void_active": "void_time_ripple",
}

## 静态缓存：避免每次 get_card_by_id 都重新 create_all() 68 张卡
static var _all_cards_cache: Array = []
static var _id_lookup_cache: Dictionary = {}

## 确保 create_all 缓存已构建（整个游戏会话只构建一次）
static func _ensure_card_cache() -> void:
	if not _all_cards_cache.is_empty():
		return
	_all_cards_cache = create_all()
	for c in _all_cards_cache:
		if c is CardResource:

static func test():
    print("OK")
