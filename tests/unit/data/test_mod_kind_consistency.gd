extends GdUnitTestSuite
## 改造审查报告（2026-09-11）5.1 回归锁
## _guess_combat_kind 与卡表 combat_kind 全量一致性——前缀链漏判的卡会被静默归为
## LIGHT(0)，错过大量通用改造。修复后 _guess 优先读卡表正身，本锁防未来回归
## （新卡入库自动覆盖，前缀链仅作卡表缺失兜底）。
## 引用方式照抄 test_battle_card_v3.gd 先例（preload，非全局类名）。

const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")
const ModModules = preload("res://data/modification_modules/__init__.gd")

func test_guess_combat_kind_matches_card_table() -> void:
	DefaultCards._ensure_card_cache()
	var ids: Array = DefaultCards.get_all_blueprint_ids()
	var checked: int = 0
	var mismatches: Array[String] = []
	for card_id in ids:
		var card: CardResource = DefaultCards.get_card_by_id(card_id)
		if card == null:
			continue
		if card.card_type == GC.CardType.ENERGY or card.card_type == GC.CardType.LAW:
			continue
		var guessed: int = ModModules._guess_combat_kind(card_id)
		if guessed != card.combat_kind:
			mismatches.append("%s:guess=%d,table=%d" % [card_id, guessed, card.combat_kind])
		checked += 1
	assert_bool(mismatches.is_empty()) \
		.override_failure_message("前缀链误判 %d 张卡 → %s" % [mismatches.size(), ", ".join(mismatches)]) \
		.is_true()
	assert_int(checked).is_greater_equal(110)  # 守护：确认枚举真覆盖了玩家卡池（~117 张战斗卡）
