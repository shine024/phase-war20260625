extends GdUnitTestSuite
## v6.14 改造图纸掉落时代过滤回归锁
## 契约：roll_random_mod_blueprint(max_era=N) 只掉 era_band 覆盖 N 的改造（无 band=全带恒过）；
##       v6.14.1：极特殊件（epic/legendary/mythic）允许跨一级——era_band 覆盖 N+1 的也可掉；
##       max_era<0 保持旧行为（不过滤）；过滤后空池回退全量（era_band 全在 [0,4]，0-4 恒非空）。

const IntelManualItems = preload("res://data/intel_manual_items.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const EnemyFixedLoadouts = preload("res://data/enemy_fixed_loadouts.gd")

const ROLLS := 120
## 允许跨一级前瞻的稀有度（与 roll_random_mod_blueprint 内的极特殊件口径一致）
const LOOKAHEAD_RARITIES := ["epic", "legendary", "mythic"]


func _drop_ok_for_era(mod_id: String, era: int) -> bool:
	if ModRegistry.is_mod_era_compatible(ModRegistry.get_data(mod_id), era):
		return true
	var era_hi: int = mini(era + 1, 4)
	if era_hi == era:
		return false
	if not ModRegistry.is_mod_era_compatible(ModRegistry.get_data(mod_id), era_hi):
		return false
	return String(ModRegistry.get_data(mod_id).get("rarity", "common")) in LOOKAHEAD_RARITIES


func test_era0_rolls_always_era_compatible_or_lookahead() -> void:
	for i in ROLLS:
		var drop: Dictionary = IntelManualItems.roll_random_mod_blueprint("infantry", "normal", -1, [], 0)
		if drop.is_empty():
			continue
		assert_bool(_drop_ok_for_era(String(drop["mod_id"]), 0)).is_true()


func test_era4_rolls_always_era_compatible() -> void:
	for i in ROLLS:
		var drop: Dictionary = IntelManualItems.roll_random_mod_blueprint("armor", "elite", 3, [], 4)
		if drop.is_empty():
			continue
		assert_bool(_drop_ok_for_era(String(drop["mod_id"]), 4)).is_true()


func test_era0_common_drops_stay_current_era() -> void:
	# 普通件（common/uncommon）不允许跨一级——前期供给必须即时可装
	for i in ROLLS:
		var drop: Dictionary = IntelManualItems.roll_random_mod_blueprint("infantry", "normal", -1, [], 0)
		if drop.is_empty():
			continue
		var rarity := String(drop.get("rarity", "common"))
		if rarity in ["common", "uncommon"]:
			assert_bool(ModRegistry.is_mod_era_compatible(ModRegistry.get_data(String(drop["mod_id"])), 0)).is_true()


func test_negative_era_keeps_legacy_behavior() -> void:
	# max_era=-1（旧行为）不过滤：步兵全池含 era0 装不上的条目，多次 roll 必然出现
	var seen_incompatible := false
	for i in 400:
		var drop: Dictionary = IntelManualItems.roll_random_mod_blueprint("infantry", "boss", 4, [], -1)
		if drop.is_empty():
			continue
		if not _drop_ok_for_era(String(drop["mod_id"]), 0):
			seen_incompatible = true
			break
	assert_bool(seen_incompatible).is_true()


func test_era0_pool_still_supplies_common() -> void:
	# 过滤不应把前期供给打空：era0 池里必须还有普通档（v26.10 教程第 6 步依赖 common 图纸）
	var rarities := {}
	for i in 300:
		var drop: Dictionary = IntelManualItems.roll_random_mod_blueprint("infantry", "normal", -1, [], 0)
		if drop.is_empty():
			continue
		rarities[String(drop.get("rarity", ""))] = true
	assert_bool(rarities.has("common")).is_true()


## ── v6.14.2 缴获语义（带什么掉什么）──────────────────────

func test_kit_roll_only_drops_carried_mods() -> void:
	# 有配装的敌人：掉落必须来自它实际携带的模块切片（档位 cuts 内）
	var kit: Array = EnemyFixedLoadouts.get_mods_for_tier("ww1_inf_mp18", 1)
	assert_int(kit.size()).is_greater(0)
	var kit_set := {}
	for m in kit:
		kit_set[String(m)] = true
	for i in 100:
		var drop: Dictionary = IntelManualItems.roll_mod_blueprint_from_kit(kit, 0)
		assert_bool(drop.is_empty()).is_false()
		assert_bool(kit_set.has(String(drop["mod_id"]))).is_true()


func test_kit_roll_respects_era_guard() -> void:
	# max_era 守卫：era_band 不符的携带件被剔除（正常配装全 era 兼容，此为保险）
	var kit: Array = EnemyFixedLoadouts.get_mods_for_tier("ww1_inf_mp18", 1)
	for i in 50:
		var drop: Dictionary = IntelManualItems.roll_mod_blueprint_from_kit(kit, 0)
		if drop.is_empty():
			continue
		assert_bool(ModRegistry.is_mod_era_compatible(
			ModRegistry.get_data(String(drop["mod_id"])), 0)).is_true()


func test_kit_roll_empty_kit_returns_empty() -> void:
	# 空配装（缴获/星冥/未配卡）返回空字典——调用方回退发现腿/全池 roll
	assert_bool(IntelManualItems.roll_mod_blueprint_from_kit([], 0).is_empty()).is_true()


## ── v6.14.4 比例发现腿（75/25 分流）──────────────────────

func test_discovery_leg_era_guard() -> void:
	# 发现腿与缴获/全池同时代口径：era0 下普通件必须 era0 兼容，跨一级仅限史诗+
	for i in 100:
		var drop: Dictionary = IntelManualItems.roll_discovery_mod_blueprint(
			"normal", -1, 0, func(_mid: String) -> bool: return false)
		if drop.is_empty():
			continue
		var md: Dictionary = ModRegistry.get_data(String(drop["mod_id"]))
		var ok: bool = ModRegistry.is_mod_era_compatible(md, 0) \
			or (String(md.get("rarity", "common")) in LOOKAHEAD_RARITIES
				and ModRegistry.is_mod_era_compatible(md, 1))
		assert_bool(ok).is_true()


func test_discovery_leg_prefers_unseen() -> void:
	# 全部伪装已见过 → 退化全池（仍能出货）
	var all_seen: Callable = func(_mid: String) -> bool: return true
	var d: Dictionary = IntelManualItems.roll_discovery_mod_blueprint("normal", -1, -1, all_seen)
	assert_bool(d.is_empty()).is_false()
	# 仅一件"未见过" → 发现腿恒出该件（发现语义直接怼缺口）
	var target := "inf_14_knee_pads"
	var seen_one: Callable = func(mid: String) -> bool: return mid != target
	var hits := 0
	for i in 60:
		var d2: Dictionary = IntelManualItems.roll_discovery_mod_blueprint("normal", -1, -1, seen_one)
		if not d2.is_empty() and String(d2["mod_id"]) == target:
			hits += 1
	assert_int(hits).is_greater(0)

