class_name ModConsumableTest
extends GdUnitTestSuite
## v26.x 改造消耗品化单测
## 覆盖：安装消耗图纸（成功/库存0拒绝/纳米不足不扣图纸/总开关回退旧"永久解锁"）、
## 见过集合（消耗光仍在、存档往返、空数据复位、旧档回填=库存∪已装）、
## 制造通道（定向扣费入包/epic 分区拒绝/未见拒绝/随机箱单池确定性+pity+存档往返/出率归一）、
## preview_install_cost 与实际扣款同源。
## 状态隔离：IntelItemBag/BasicResourceManager 存量快照+清零基线+测后恢复，
## 实例用后 dispose；BlueprintManager._suppress_auto_save 期间压住防测试写真存档。

const _BAG_SRC := "res://managers/intel_item_bag.gd"
const _MGR_SRC := "res://managers/manufacture_manager.gd"
const _KNEE_BP := "blueprint_inf_14_knee_pads"      # 唯一 common（GRUNT 档）模块
const _COMPOSITE_BP := "blueprint_arm_02_composite_armor"  # epic（随机箱区）

var _bag: Node
var _mgr: Node
var _inv_backup: Dictionary
var _seen_backup: Dictionary
var _nano_backup: int
var _energy_backup: int
var _alloy_backup: int
var _toggle_backup: bool
var _suppress_backup: bool
var _created_ids: Array[String] = []


func before_test() -> void:
	_inv_backup = IntelItemBag.get_all_inventory()
	_seen_backup = IntelItemBag._seen.duplicate()
	_nano_backup = BasicResourceManager.total_nano_materials
	_energy_backup = BasicResourceManager.total_energy_block
	_alloy_backup = BasicResourceManager.total_alloy
	_toggle_backup = GameConfig.get_default().mod_consumable_enabled
	_suppress_backup = BlueprintManager._suppress_auto_save
	# 隔离基线：清空背包/见过/三资源，测后恢复
	IntelItemBag._inventory.clear()
	IntelItemBag._seen.clear()
	BasicResourceManager.total_nano_materials = 0
	BasicResourceManager.total_energy_block = 0
	BasicResourceManager.total_alloy = 0
	GameConfig.get_default().mod_consumable_enabled = true
	BlueprintManager._suppress_auto_save = true
	_bag = Node.new()
	_bag.set_script(load(_BAG_SRC))
	add_child(_bag)
	_mgr = Node.new()
	_mgr.set_script(load(_MGR_SRC))
	add_child(_mgr)


func after_test() -> void:
	for iid in _created_ids:
		InstanceRegistry.dispose_instance(iid)
	_created_ids.clear()
	IntelItemBag._inventory = _inv_backup
	IntelItemBag._seen = _seen_backup
	BasicResourceManager.total_nano_materials = _nano_backup
	BasicResourceManager.total_energy_block = _energy_backup
	BasicResourceManager.total_alloy = _alloy_backup
	GameConfig.get_default().mod_consumable_enabled = _toggle_backup
	BlueprintManager._suppress_auto_save = _suppress_backup
	for n: Node in [_mgr, _bag]:
		if n != null and is_instance_valid(n):
			if n.is_inside_tree():
				remove_child(n)
			n.queue_free()
	_mgr = null
	_bag = null


func _fresh_infantry_instance() -> CardResource:
	var inst: CardResource = InstanceRegistry.create_instance("ww1_mauser")
	if inst != null:
		_created_ids.append(String(inst.instance_id))
	return inst


# ── A. 见过集合（局部 _bag，不碰 autoload） ──────────────────────────────

func test_seen_survives_consume() -> void:
	_bag.add_item(_KNEE_BP, 1)
	assert_bool(_bag.has_item(_KNEE_BP)).is_true()
	assert_bool(_bag.has_seen(_KNEE_BP)).is_true()
	assert_bool(_bag.consume_item(_KNEE_BP)).is_true()
	assert_int(_bag.get_count(_KNEE_BP)).is_equal(0)
	assert_bool(_bag.has_item(_KNEE_BP)).is_false()
	# 消耗光后"得到过"仍在——制造门槛依赖此集合而非库存
	assert_bool(_bag.has_seen(_KNEE_BP)).is_true()


func test_seen_save_load_roundtrip() -> void:
	_bag.add_item(_KNEE_BP, 2)
	_bag.add_item(_COMPOSITE_BP, 1)
	_bag.consume_item(_COMPOSITE_BP)
	var saved: Dictionary = _bag.save_state()
	var restored: Node = Node.new()
	restored.set_script(load(_BAG_SRC))
	add_child(restored)
	restored.load_state(saved)
	assert_bool(restored.has_seen(_COMPOSITE_BP)).is_true()
	assert_int(restored.get_count(_KNEE_BP)).is_equal(2)
	remove_child(restored)
	restored.queue_free()


func test_load_state_empty_resets_to_defaults() -> void:
	_bag.add_item(_KNEE_BP, 1)
	_bag.load_state({})
	assert_int(_bag.get_total_count()).is_equal(0)
	assert_array(_bag.get_seen_item_ids()).is_empty()


func test_backfill_seen_from_registry_covers_installed_mods() -> void:
	var inst := _fresh_infantry_instance()
	assert_bool(inst != null).is_true()
	inst.mods.append({id = "inf_14_knee_pads", enabled = true, paid_cost = 30})
	_bag.backfill_seen_from_registry()
	# 已装改造 → 见过（旧档回填口径：库存 ∪ 已装）
	assert_bool(_bag.has_seen(_KNEE_BP)).is_true()


# ── B. 安装消耗（autoload BlueprintManager） ──────────────────────────────

func test_install_consumes_one_blueprint_and_matches_preview() -> void:
	var inst := _fresh_infantry_instance()
	IntelItemBag.add_item(_KNEE_BP, 1)
	BasicResourceManager.total_nano_materials = 100000
	var preview: Dictionary = BlueprintManager.preview_install_cost(inst)
	var result: Dictionary = BlueprintManager.install_modification(inst, "inf_14_knee_pads")
	assert_bool(result.success).is_true()
	assert_int(IntelItemBag.get_count(_KNEE_BP)).is_equal(0)
	# 纳米扣款与 preview 同源
	assert_int(100000 - BasicResourceManager.total_nano_materials).is_equal(int(preview.nano))
	assert_int(int(preview.blueprints)).is_equal(1)
	assert_int(inst.mods.size()).is_equal(1)


func test_install_rejected_without_stock_nano_untouched() -> void:
	var inst := _fresh_infantry_instance()
	BasicResourceManager.total_nano_materials = 100000
	var result: Dictionary = BlueprintManager.install_modification(inst, "inf_14_knee_pads")
	assert_bool(result.success).is_false()
	# 库存 0 在蓝图 gate 处拒绝，纳米不动
	assert_int(BasicResourceManager.total_nano_materials).is_equal(100000)
	assert_int(inst.mods.size()).is_equal(0)


func test_install_nano_short_does_not_consume_blueprint() -> void:
	var inst := _fresh_infantry_instance()
	IntelItemBag.add_item(_KNEE_BP, 1)
	BasicResourceManager.total_nano_materials = 0
	var result: Dictionary = BlueprintManager.install_modification(inst, "inf_14_knee_pads")
	assert_bool(result.success).is_false()
	# 纳米不足在扣款前拒绝，图纸不扣
	assert_int(IntelItemBag.get_count(_KNEE_BP)).is_equal(1)
	assert_int(inst.mods.size()).is_equal(0)


func test_toggle_off_keeps_legacy_unlock_behavior() -> void:
	GameConfig.get_default().mod_consumable_enabled = false
	var inst := _fresh_infantry_instance()
	IntelItemBag.add_item(_KNEE_BP, 1)
	BasicResourceManager.total_nano_materials = 100000
	var result: Dictionary = BlueprintManager.install_modification(inst, "inf_14_knee_pads")
	assert_bool(result.success).is_true()
	# 回退旧"永久解锁"：图纸只验持有不消耗
	assert_int(IntelItemBag.get_count(_KNEE_BP)).is_equal(1)
	assert_int(int(BlueprintManager.preview_install_cost(inst).blueprints)).is_equal(0)


# ── C. 制造通道（局部 _mgr，走被清零基线的 autoload 背包/资源） ─────────────

func test_direct_craft_charges_and_grants() -> void:
	IntelItemBag.add_item(_KNEE_BP, 1)
	IntelItemBag.consume_item(_KNEE_BP)  # 消耗光仍可补给（见过即可）
	BasicResourceManager.total_nano_materials = 500
	BasicResourceManager.total_energy_block = 100
	var result: Dictionary = _mgr.craft_mod_blueprint_direct("inf_14_knee_pads")
	assert_bool(result.get("ok")).is_true()
	assert_int(IntelItemBag.get_count(_KNEE_BP)).is_equal(1)
	assert_int(BasicResourceManager.total_nano_materials).is_equal(420)
	assert_int(BasicResourceManager.total_energy_block).is_equal(90)


func test_direct_craft_rejects_epic_zone() -> void:
	IntelItemBag.add_item(_COMPOSITE_BP, 1)
	BasicResourceManager.total_nano_materials = 100000
	BasicResourceManager.total_energy_block = 1000
	BasicResourceManager.total_alloy = 1000
	var result: Dictionary = _mgr.craft_mod_blueprint_direct("arm_02_composite_armor")
	assert_bool(result.get("ok")).is_false()
	# 未扣资源也未发图纸
	assert_int(BasicResourceManager.total_nano_materials).is_equal(100000)
	assert_int(IntelItemBag.get_count(_COMPOSITE_BP)).is_equal(1)


func test_direct_craft_rejects_unseen() -> void:
	BasicResourceManager.total_nano_materials = 500
	BasicResourceManager.total_energy_block = 100
	var result: Dictionary = _mgr.craft_mod_blueprint_direct("inf_14_knee_pads")
	assert_bool(result.get("ok")).is_false()
	assert_int(BasicResourceManager.total_nano_materials).is_equal(500)


func test_random_box_single_pool_deterministic_and_pity_roundtrip() -> void:
	# 图鉴只放一张史诗图纸 → 开箱必出它；出史诗（非传说+）→ pity +1
	IntelItemBag.add_item(_COMPOSITE_BP, 1)
	BasicResourceManager.total_nano_materials = 1000
	BasicResourceManager.total_energy_block = 200
	BasicResourceManager.total_alloy = 100
	assert_bool(_mgr.can_craft_mod_random().get("ok")).is_true()
	var result: Dictionary = _mgr.craft_mod_blueprint_random()
	assert_bool(result.get("ok")).is_true()
	assert_str(String(result.get("mod_id"))).is_equal("arm_02_composite_armor")
	assert_int(_mgr.get_mod_box_pity()).is_equal(1)
	assert_int(IntelItemBag.get_count(_COMPOSITE_BP)).is_equal(2)
	# 存档往返（含 mod_box_pity）
	var saved: Dictionary = _mgr.save_state()
	assert_int(int(saved.get("mod_box_pity", -1))).is_equal(1)
	var mgr2: Node = Node.new()
	mgr2.set_script(load(_MGR_SRC))
	add_child(mgr2)
	mgr2.load_state(saved)
	assert_int(mgr2.get_mod_box_pity()).is_equal(1)
	remove_child(mgr2)
	mgr2.queue_free()


func test_random_box_rejects_empty_catalog() -> void:
	var result: Dictionary = _mgr.craft_mod_blueprint_random()
	assert_bool(result.get("ok")).is_false()


func test_mod_box_odds_normalized() -> void:
	IntelItemBag.add_item(_COMPOSITE_BP, 1)
	var odds: Array = _mgr.get_mod_box_odds()
	assert_int(odds.size()).is_equal(1)
	assert_bool(absf(float(odds[0]["pct"]) - 1.0) < 0.0001).is_true()
