extends GdUnitTestSuite
## 批②未尽 #2 回归锁（2026-09-11 落地）：
## 1) q_helix_speed_clear 的 90 秒时限此前是纯文案（objective=裸 win_battles 零校验）——
##    现由 time_limit_sec 字段驱动（notify_battle_result 校验，_notify_battle_won 跳过防双计）
## 2) "收集 N 种现代时代的战斗卡"此前无时代过滤任意卡计数——现由 card_era 字段驱动
## JSON 为运行时优先源、LEGACY_QUESTS 为兜底源，双源字段必须一致，否则 fallback 行为分叉。

const QuestDefs = preload("res://data/quest_definitions.gd")

func _legacy_entry(qid: String) -> Dictionary:
	for entry in QuestDefs.LEGACY_QUESTS:
		if String(entry.get("id", "")) == qid:
			return entry
	return {}

func test_speed_clear_time_limit_both_sources() -> void:
	var q: Dictionary = QuestDefs.get_by_id("q_helix_speed_clear")
	assert_int(int(q.get("time_limit_sec", 0))).is_equal(90)
	var legacy_q: Dictionary = _legacy_entry("q_helix_speed_clear")
	assert_int(int(legacy_q.get("time_limit_sec", 0))).is_equal(90)

func test_collect_modern_era_filter_both_sources() -> void:
	# JSON 运行时源（get_by_id 读 JSON 优先）
	var q: Dictionary = QuestDefs.get_by_id("q_helix_collect_modern")
	assert_int(int(q.get("card_era", -1))).is_equal(3)
	# LEGACY 兜底源两条（helix 委托 + aether 经典）
	assert_int(int(_legacy_entry("q_helix_collect_modern").get("card_era", -1))).is_equal(3)
	assert_int(int(_legacy_entry("q_collect_modern").get("card_era", -1))).is_equal(3)

func test_collect_rare_min_rarity_both_sources() -> void:
	var q: Dictionary = QuestDefs.get_by_id("q_collect_rare")
	assert_str(String(q.get("card_min_rarity", ""))).is_equal("rare")
	assert_str(String(_legacy_entry("q_collect_rare").get("card_min_rarity", ""))).is_equal("rare")

func test_plain_quests_unaffected() -> void:
	# 无时限任务不受 time_limit 分支影响（字段缺省 = 0 = 旧行为）
	var q: Dictionary = QuestDefs.get_by_id("q_win_3")
	assert_int(int(q.get("time_limit_sec", 0))).is_equal(0)
	# 无过滤收集任务（任意卡种）不受 card_era/card_min_rarity 影响
	var c: Dictionary = QuestDefs.get_by_id("q_frag_smg")
	assert_int(int(c.get("card_era", -1))).is_equal(-1)
	assert_str(String(c.get("card_min_rarity", ""))).is_equal("")
