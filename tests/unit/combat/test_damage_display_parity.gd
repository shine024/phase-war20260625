class_name DamageDisplayParityTest
extends GdUnitTestSuite
## 口径统一回归锁（2026-10-08）：显示=加成=结算 一个真相源。
## 背景（"攻 9000 实扣几百"主诉闭环）：
##  ① 词条 attack_damage/attack_range 只写 stats 不同步 weapon_slots → 实战空转（已修：同步进槽）
##  ② 巷战掩蔽在 resolve_hit 与 take_damage 内联段各扣一次 → ×0.85² 双扣（已修：删内联段）
##  ③ 悬停 HUD/卡详情/背包预览读 attack_* 而结算读槽 → 面板 470 实战 564 两套账（已修：读槽）
## 本锁防三类复发。

const _AFFIX_MGR := "res://managers/affix_manager.gd"
const _UCT := "res://resources/unit_stats_table.gd"
const _DC := "res://data/default_cards.gd"
const _CGD := "res://scripts/card_grid_damage.gd"


func _make_affix(effect_key: String, val: float) -> Resource:
	var a = load("res://resources/affix_resource.gd").new()
	a.affix_id = "probe_" + effect_key
	a.effect_key = effect_key
	a.current_value = val
	return a


func _make_mgr() -> Node:
	var m: Node = Node.new()
	m.set_script(load(_AFFIX_MGR))
	return m


## ① 词条伤害同步：attack_damage 词条必须进对轻槽（weapon_slots[0]）
func test_attack_damage_affix_syncs_into_light_slot() -> void:
	var card = (load(_DC) as GDScript).get_card_by_id("ww1_a7v")
	var UST = load(_UCT)
	var stats: UnitStats = UST.build_stats_from_card(card)
	var base_slot: float = float(stats.weapon_slots[0].damage)
	var base_atk: float = float(stats.attack_light)
	assert_float(base_slot).is_greater(0.0)
	var mgr := _make_mgr()
	add_child(mgr)
	mgr._card_affixes["_probe_0"] = [_make_affix("attack_damage", 0.15)]
	mgr._apply_card_affixes(stats, "_probe_0")
	# 槽位与 stats 同维同比例——两套账禁令
	assert_float(float(stats.weapon_slots[0].damage)).is_equal_approx(base_slot * 1.15, 0.5)
	assert_float(float(stats.attack_light)).is_equal_approx(base_atk * 1.15, 0.5)
	mgr.queue_free()


## ①b 词条射程同步：attack_range 词条必须进各槽 range_value
func test_attack_range_affix_syncs_into_slots() -> void:
	var card = (load(_DC) as GDScript).get_card_by_id("ww1_a7v")
	var UST = load(_UCT)
	var stats: UnitStats = UST.build_stats_from_card(card)
	var base_r: int = int(stats.weapon_slots[0].range_value)
	assert_int(base_r).is_greater(0)
	var mgr := _make_mgr()
	add_child(mgr)
	mgr._card_affixes["_probe_0"] = [_make_affix("attack_range", 0.20)]
	mgr._apply_card_affixes(stats, "_probe_0")
	assert_int(int(stats.weapon_slots[0].range_value)).is_equal(int(round(float(base_r) * 1.2)))
	mgr.queue_free()


## ③ 显示=实战：卡详情/背包预览/悬停三处读的"攻三维"必须等于结算基数（槽位伤害）
func test_display_trio_equals_slot_damage() -> void:
	var card = (load(_DC) as GDScript).get_card_by_id("fut_arm_omega")
	var UST = load(_UCT)
	var stats: UnitStats = UST.build_stats_from_card(card)
	# omega 是 ARMOR 类：装甲碾压 +20% 只同步进对轻槽 → attack_light(470) ≠ slot[0](564)
	# 显示层若读 attack_* 即两套账；三处显示助手都必须读槽。
	var slot0: float = float(stats.weapon_slots[0].damage)
	assert_float(slot0).is_equal_approx(float(stats.attack_light) * 1.2, 1.0)
	var cip = load("res://scenes/ui/card_info_panel.gd").new()
	var trio_cip: Array[float] = cip._display_atk_trio(stats)
	assert_float(trio_cip[0]).is_equal_approx(slot0, 0.01)
	assert_float(trio_cip[1]).is_equal_approx(float(stats.weapon_slots[1].damage), 0.01)
	cip.free()
	var bcp = load("res://scenes/ui/backpack_combat_preview.gd")
	var trio_bcp: Array[float] = bcp._slot_dmg_trio(stats)
	assert_float(trio_bcp[0]).is_equal_approx(slot0, 0.01)
	var uhi = load("res://scenes/ui/unit_hover_info.gd").new()
	var trio_uhi: Array = uhi._combat_atk_trio(stats)
	assert_float(float(trio_uhi[0])).is_equal_approx(slot0, 0.01)
	uhi.free()


## ② 掩蔽单次：urban_defense_bonus 目标被 ARMOR 攻击者打一发，
## hp_loss == 攻击 × 50/(50+def) × (1-urban)，仅扣一次（防双扣复活）。
## 真实 enemy_unit 端到端（复刻实机对射探针 ww1_inf_rifle 场景）。
func test_urban_mitigation_applied_exactly_once() -> void:
	# 单位必须挂在 Node2D 宿主下（死亡链 spawn_death_burst 需要 Node2D 祖先）
	var host := Node2D.new()
	add_child(host)
	# 攻击者=ARMOR 类玩家单位（掩蔽仅对 ARMOR/AIR 攻击者生效，attacker=null 不触发）
	var UST = load(_UCT)
	var DC = load(_DC)
	var attacker = load("res://scenes/units/construct_unit.tscn").instantiate()
	host.add_child(attacker)
	attacker.setup(true, UST.build_stats_from_card(DC.get_card_by_id("ww1_a7v")))
	var EnemyUnitScene := load("res://scenes/units/enemy_unit.tscn")
	var e = EnemyUnitScene.instantiate()
	host.add_child(e)
	e.setup(false, 1, "ww1_inf_rifle")
	var stats: UnitStats = e.stats
	assert_float(float(stats.urban_defense_bonus)).is_equal_approx(0.15, 0.001)
	var raw: float = 1971.0
	var expected: float = raw * (50.0 / (50.0 + float(stats.defense_light))) * (1.0 - 0.15)
	var before: float = float(e.hp)
	e.take_damage(raw, attacker)
	var loss: float = before - float(e.hp)
	assert_float(loss).is_equal_approx(expected, expected * 0.02)
	e.queue_free()
	attacker.queue_free()
	host.queue_free()
