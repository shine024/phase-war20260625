class_name SpecialRulesHooksTest
extends GdUnitTestSuite
## v26.13(B2) 数据锁：7 个新特殊规则键的消费链路回归锁。
## 覆盖：no_mods 真实行为（build_stats_from_card skip_mods 语义）、has_special_rule
## 管道（真实 BattleManager + GameManager 关卡路由）、摘要文案键覆盖（防误删）。

const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const DefaultCards = preload("res://data/default_cards.gd")

const NEW_KEYS := ["time_limit_sec", "no_heal", "no_mods", "elite_wave_bonus",
	"first_strike", "energy_starvation", "boss_enrage_half", "counter_bias_tags"]


func test_skip_mods_produces_base_stats() -> void:
	var base_card = DefaultCards.get_card_by_id("cold_t72")
	if base_card == null:
		print("  cold_t72 缺失，跳过")
		return
	# 模板只读——clone 后注入一个真实改造（数值通道必有可观差异的装甲件）
	var modded: CardResource = base_card.clone()
	var mod_id: String = "arm_01_sloped_armor"  # 倾斜装甲（防御类，必然改 stats）
	modded.mods = [{"id": mod_id, "level": 3}]
	var with_mods := UnitStatsTable.build_stats_from_card(modded, 2, false)
	var skipped := UnitStatsTable.build_stats_from_card(modded, 2, true)
	var base := UnitStatsTable.build_stats_from_card(base_card, 2, false)
	# skip_mods=true 必须与无改造基线一致（禁改造=数值回到未装状态）；
	# 倾斜装甲=固定+百分比防护双通道，主变化在 defense_armor
	assert_float(skipped.max_hp).is_equal(base.max_hp)
	assert_float(skipped.defense_armor).is_equal(base.defense_armor)
	# 不跳过时改造必然改变防护（通道活着）
	var changed: bool = (with_mods.defense_armor != base.defense_armor) or (with_mods.max_hp != base.max_hp)
	assert_bool(changed).is_true()


func test_has_special_rule_plumbing() -> void:
	var bm: Node = get_node_or_null("/root/BattleManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	if bm == null or gm == null or not bm.has_method("has_special_rule"):
		print("  autoload 不全，跳过")
		return
	# 无规则关（L1 教程关铁律：无任何条目）
	gm.set("current_level", 1)
	assert_bool(bm.has_special_rule("no_heal")).is_false()
	assert_bool(bm.has_special_rule("energy_mult")).is_false()
	# 有规则关（L5 回能减半 / L25 能量上限减半）
	gm.set("current_level", 5)
	assert_bool(bm.has_special_rule("energy_regen_mult")).is_true()
	gm.set("current_level", 25)
	assert_bool(bm.has_special_rule("energy_mult")).is_true()
	# 未知键恒 false
	assert_bool(bm.has_special_rule("__nonexistent__")).is_false()


func test_summary_formatter_covers_all_new_keys() -> void:
	# 摘要文案键覆盖锁：world_map._format_special_rules 必须识别全部 7 键（防误删）。
	# 格式化函数是 world_map 场景方法——直接实例化场景过重，退而锁"消费点源码引用"，
	# 真实文案由 B3 体感验证兜底。
	var src: String = FileAccess.get_file_as_string("res://scenes/world_map.gd")
	for key in NEW_KEYS:
		assert_bool(src.contains(key)).is_true()
	# enemy/spawn/consume 三侧消费点存在性
	var spawn_src: String = FileAccess.get_file_as_string("res://managers/battle/battle_spawn_system.gd")
	assert_bool(spawn_src.contains("elite_wave_bonus")).is_true()
	assert_bool(spawn_src.contains("_is_boss_unit")).is_true()
	# v6.16 反制配波：spawn 侧消费点存在性
	assert_bool(spawn_src.contains("_merged_wave_bias_tags")).is_true()
	var enemy_src: String = FileAccess.get_file_as_string("res://scenes/units/enemy_unit.gd")
	assert_bool(enemy_src.contains("first_strike")).is_true()
	assert_bool(enemy_src.contains("_enrage_active")).is_true()
	var bm_src: String = FileAccess.get_file_as_string("res://managers/battle/battle_manager.gd")
	assert_bool(bm_src.contains("time_limit_sec")).is_true()
	assert_bool(bm_src.contains("energy_starvation")).is_true()
	var cu_src: String = FileAccess.get_file_as_string("res://scenes/units/construct_unit.gd")
	assert_bool(cu_src.contains("no_heal")).is_true()


func test_level1_tutorial_stays_rule_free() -> void:
	# L1 教程关铁律：不挂任何 special_rules / 定制布局
	var li = preload("res://data/level_information.gd")
	var rules: Dictionary = li.get_shared().get_special_rules(1)
	assert_int(rules.size()).is_equal(0)
	var layouts = preload("res://data/level_battle_layouts.gd")
	assert_bool(layouts.has_custom_layout(1)).is_false()


func test_v616_counter_wave_mounting() -> void:
	# v6.16 反制配波挂载抽检：L33 教学关装甲反制 + L48 空域 + L1 铁律不受影响
	var li = preload("res://data/level_information.gd").get_shared()
	var l33: Array = li.get_special_rules(33).get("counter_bias_tags", [])
	assert_bool(l33.has("armored")).is_true()
	var l48: Array = li.get_special_rules(48).get("counter_bias_tags", [])
	assert_bool(l48.has("aircraft")).is_true()
	assert_bool(li.get_special_rules(1).has("counter_bias_tags")).is_false()
	# tag 词汇必须在本关时代池有匹配（题面必真；armored 在二战池存在）
	assert_bool(l33.has("tank") or l33.has("armored")).is_true()


func test_v2613_rule_mounting_and_merge() -> void:
	# B1 挂载抽检：L3 限时首秀 / L80 合并语义（旧 energy_mult + 新 boss_enrage_half 并存）
	var li = preload("res://data/level_information.gd").get_shared()
	var l3: Dictionary = li.get_special_rules(3)
	assert_int(int(l3.get("time_limit_sec", 0))).is_equal(240)
	var l80: Dictionary = li.get_special_rules(80)
	assert_bool(l80.has("energy_mult")).is_true()
	assert_bool(bool(l80.get("boss_enrage_half", false))).is_true()
	# 覆盖面抽检：规则关总数 ≥ 40（设计目标 41）
	var total: int = 0
	for lv in range(2, 101):
		if not li.get_special_rules(lv).is_empty():
			total += 1
	print("  规则关总数: %d（B1 前 10，不含 L1）" % total)
	assert_int(total).is_greater_equal(40)
