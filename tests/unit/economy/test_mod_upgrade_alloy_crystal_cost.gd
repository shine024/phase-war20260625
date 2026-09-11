class_name ModUpgradeAlloyCrystalCostTest
extends GdUnitTestSuite
## v27.13: 改造升级合金/晶体消耗——preview 与扣款同源、Lv3 定价阶梯、余额守卫（不足拒绝不扣款）。
## fixture：ww1_mauser 实例卡 + inf_12_body_armor（save_manager 起始改造同款、有 level_effects 三档；
## 任务原提的 inf_05_ap_ammo 无 level_effects 不可升级，故换用同卡同先例的可升档模块）。
## 状态隔离抄 test_mod_consumable.gd：资源快照+清零基线+测后恢复、实例用后 dispose、压住自动存档。
## 图纸开关关闭（mod_consumable_enabled=false 只豁免图纸费，合金/晶体不受其控制——聚焦被测路径）。

const _MOD_ID := "inf_12_body_armor"

var _nano_backup: int
var _alloy_backup: int
var _crystal_backup: int
var _energy_backup: int
var _toggle_backup: bool
var _suppress_backup: bool
var _created_ids: Array[String] = []


func before_test() -> void:
	_nano_backup = BasicResourceManager.total_nano_materials
	_alloy_backup = BasicResourceManager.total_alloy
	_crystal_backup = BasicResourceManager.total_crystal
	_energy_backup = BasicResourceManager.total_energy_block
	_toggle_backup = GameConfig.get_default().mod_consumable_enabled
	_suppress_backup = BlueprintManager._suppress_auto_save
	# 隔离基线：四资源清零，测后恢复
	BasicResourceManager.total_nano_materials = 0
	BasicResourceManager.total_alloy = 0
	BasicResourceManager.total_crystal = 0
	BasicResourceManager.total_energy_block = 0
	GameConfig.get_default().mod_consumable_enabled = false
	BlueprintManager._suppress_auto_save = true


func after_test() -> void:
	for iid in _created_ids:
		InstanceRegistry.dispose_instance(iid)
	_created_ids.clear()
	BasicResourceManager.total_nano_materials = _nano_backup
	BasicResourceManager.total_alloy = _alloy_backup
	BasicResourceManager.total_crystal = _crystal_backup
	BasicResourceManager.total_energy_block = _energy_backup
	GameConfig.get_default().mod_consumable_enabled = _toggle_backup
	BlueprintManager._suppress_auto_save = _suppress_backup


func _fresh_lv1_card() -> CardResource:
	var inst: CardResource = InstanceRegistry.create_instance("ww1_mauser")
	assert_bool(inst != null).is_true()
	if inst == null:
		return null
	_created_ids.append(String(inst.instance_id))
	inst.mods.append({id = _MOD_ID, enabled = true, paid_cost = 30, level = 1})
	return inst


func test_preview_cost_contains_alloy_crystal() -> void:
	var card := _fresh_lv1_card()
	var cost: Dictionary = BlueprintManager.preview_upgrade_cost(card, 0)
	assert_bool(bool(cost.get("can_upgrade", false))).is_true()
	assert_int(int(cost.get("alloy", -1))).is_equal(40)
	assert_int(int(cost.get("crystal", -1))).is_equal(15)


func test_lv3_cost_scales() -> void:
	var card := _fresh_lv1_card()
	var entry: Dictionary = card.mods[0]
	entry["level"] = 2
	card.mods[0] = entry
	var cost: Dictionary = BlueprintManager.preview_upgrade_cost(card, 0)
	assert_bool(bool(cost.get("can_upgrade", false))).is_true()
	assert_int(int(cost.get("alloy", -1))).is_equal(100)
	assert_int(int(cost.get("crystal", -1))).is_equal(40)


func test_upgrade_consumes_and_guards_balance() -> void:
	BasicResourceManager.add_resource("alloy", 1000)
	BasicResourceManager.add_resource("crystal", 1000)
	BasicResourceManager.total_nano_materials = 100000
	var card := _fresh_lv1_card()
	var result: Dictionary = BlueprintManager.upgrade_modification(card, 0)
	assert_bool(result.success).is_true()
	assert_int(BasicResourceManager.total_alloy).is_equal(960)
	assert_int(BasicResourceManager.total_crystal).is_equal(985)
	# 合金压到 10（<40）→ 再升另一张 Lv1 卡：拒绝且不扣款（晶体/等级均不动）
	BasicResourceManager.total_alloy = 10
	var card2 := _fresh_lv1_card()
	var result2: Dictionary = BlueprintManager.upgrade_modification(card2, 0)
	assert_bool(result2.success).is_false()
	assert_int(BasicResourceManager.total_alloy).is_equal(10)
	assert_int(BasicResourceManager.total_crystal).is_equal(985)
	assert_int(int((card2.mods[0] as Dictionary).get("level", 1))).is_equal(1)
