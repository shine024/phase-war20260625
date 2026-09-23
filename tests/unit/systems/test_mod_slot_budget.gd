class_name ModSlotBudgetTest
extends GdUnitTestSuite
## v6.16 槽位预算回归锁：品质基础槽 + 兵种专属槽 + 通用件上限 + 旧档祖父条款。
## 真身：managers/evolution/mod_manager.gd（SLOT_BUDGET_BY_RARITY / FAMILY_SLOT_BONUS_BY_KIND）
## 消费链：card_resource.can_install_modification / blueprint_manager.install_modification /
## modification_panel._passes_filter / card_info_panel._refresh_mods_tiles。

const ModManager = preload("res://managers/evolution/mod_manager.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const GameCfg = preload("res://resources/game_config.gd")


func _card(rarity: String, kind: int, mods: Array = []) -> CardResource:
	var c := CardResource.new()
	c.card_id = "ut_%s_%d" % [rarity, kind]
	c.rarity = rarity
	c.combat_kind = kind
	c.mods = mods
	return c


func test_budget_by_rarity() -> void:
	assert_int(ModManager.get_base_mod_slots(_card("common", 0))).is_equal(5)
	assert_int(ModManager.get_base_mod_slots(_card("uncommon", 0))).is_equal(6)
	assert_int(ModManager.get_base_mod_slots(_card("rare", 0))).is_equal(7)
	assert_int(ModManager.get_base_mod_slots(_card("epic", 0))).is_equal(8)
	assert_int(ModManager.get_base_mod_slots(_card("legendary", 0))).is_equal(9)
	assert_int(ModManager.get_base_mod_slots(_card("mythic", 0))).is_equal(10)
	# 未知稀有度回退 9（v6.16 前旧口径，防误锁）
	assert_int(ModManager.get_base_mod_slots(_card("???", 0))).is_equal(9)


func test_family_bonus_by_kind() -> void:
	# 堡垒 +2，其余战斗兵种 +1
	for kind in [0, 1, 2, 3]:
		assert_int(ModManager.get_family_slot_bonus(_card("rare", kind))).is_equal(1)
	assert_int(ModManager.get_family_slot_bonus(_card("rare", 4))).is_equal(2)
	# 总槽 = 基础 + 专属
	assert_int(ModManager.get_max_mod_slots_for_card(_card("rare", 4))).is_equal(9)
	assert_int(ModManager.get_max_mod_slots_for_card(_card("mythic", 0))).is_equal(11)
	assert_int(ModManager.get_max_mod_slots_for_card(_card("common", 0))).is_equal(6)


func test_total_switch_restores_legacy_nine() -> void:
	# 总开关 false = 全卡恒 9（v6.16 前行为，一键回退）
	var cfg := GameCfg.get_default()
	var saved: bool = cfg.mod_slot_budget_enabled
	cfg.mod_slot_budget_enabled = false
	assert_int(ModManager.get_max_mod_slots_for_card(_card("common", 0))).is_equal(9)
	assert_int(ModManager.get_family_slot_bonus(_card("mythic", 4))).is_equal(0)
	cfg.mod_slot_budget_enabled = saved


func test_install_gate_generic_cap() -> void:
	ModRegistry.register_all()
	# common 轻装卡：基础 5 + 专属 1 = 6 总槽。
	# 通用件（enhancement 家族）最多占 5（基础预算），第 6 件通用被拒；
	# 兵种件（infantry 家族）可用满 6。
	var card := _card("common", 0)
	var gen_id := "enh_dmg_up"        # enhancement 家族（通用件）
	var fam_id := "inf_05_ap_ammo"    # infantry 家族（兵种件）
	assert_bool(ModRegistry.is_family_mod(gen_id)).is_false()
	assert_bool(ModRegistry.is_family_mod(fam_id)).is_true()
	for i in range(5):
		card.mods.append({"id": gen_id, "slot": i})
	# 总槽未满（5/6）但通用件已达基础预算 5 → 拒绝
	var r1: Dictionary = card.can_install_modification(gen_id)
	assert_bool(r1.can_install).is_false()
	assert_str(String(r1.reason)).contains("通用槽位已满")
	# 兵种件仍可装（第 6 槽 = 专属槽）
	var r2: Dictionary = card.can_install_modification(fam_id)
	assert_bool(r2.can_install).is_true()
	card.mods.append({"id": fam_id, "slot": 5})
	# 总槽满（6/6）→ 一律拒绝
	var r3: Dictionary = card.can_install_modification(fam_id)
	assert_bool(r3.can_install).is_false()
	assert_str(String(r3.reason)).contains("改造槽位已满")


func test_grandfather_overfull_legacy_loadout() -> void:
	# 旧档祖父条款：统一 9 槽时代装满 9 件的 common 卡——不剥离（mods 保持 9），
	# 只封新装（任何安装都拒）。
	var card := _card("common", 0)
	for i in range(9):
		card.mods.append({"id": "inf_05_ap_ammo", "slot": i})
	assert_int(card.mods.size()).is_equal(9)
	var r: Dictionary = card.can_install_modification("inf_05_ap_ammo")
	assert_bool(r.can_install).is_false()
	assert_str(String(r.reason)).contains("改造槽位已满")
	assert_int(card.mods.size()).is_equal(9)  # 未剥离
