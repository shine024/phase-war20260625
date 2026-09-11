extends GdUnitTestSuite
## v27 改造升级系统（Lv1→3）+ 改造2.0 数据完整性测试
# 引擎侧零改动口径：registry.apply_with_level 从条目读 level（clamp 1-3），
# _resolve_mod_effects 优先 level_effects[lv]——本套锁升级 API 守卫/费用/等级解析与新批次数据。

var ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
var ModManager = preload("res://managers/evolution/mod_manager.gd")
var PowerTiers = preload("res://data/power_tiers.gd")
var IntelManualItems = preload("res://data/intel_manual_items.gd")
var ComboTactics = preload("res://data/combo_tactics.gd")

# ── 升级 API（BlueprintManager 实例化，auto_free 管生命周期）──

func _make_bpm():
	return auto_free(load("res://managers/blueprint_manager.gd").new())

func _make_card() -> CardResource:
	var card := CardResource.new()
	card.card_id = "ww1_mauser"
	card.instance_id = "ww1_mauser#1"
	card.display_name = "毛瑟步枪班"
	card.combat_kind = 0
	card.power = 120
	return card

func test_upgrade_info_guards_template() -> void:
	var bpm = _make_bpm()
	var card := _make_card()
	card.instance_id = ""  # 模拟共享模板
	var info: Dictionary = bpm.get_mod_upgrade_info(card, 0)
	assert_bool(bool(info.get("can_upgrade", true))).is_false()

func test_upgrade_info_rejects_no_level_effects() -> void:
	var bpm = _make_bpm()
	var card := _make_card()
	# gen_08_nbc_protection effects 全布尔（nbq_immunity）——backfill 判定不可缩放，无 level_effects
	card.mods.append({id = "gen_08_nbc_protection", enabled = true})
	var info: Dictionary = bpm.get_mod_upgrade_info(card, 0)
	assert_bool(bool(info.get("can_upgrade", true))).is_false()
	assert_str(String(info.get("reason", ""))).is_not_empty()

func test_upgrade_info_chain_l1_to_l3_then_maxed() -> void:
	var bpm = _make_bpm()
	var card := _make_card()
	card.mods.append({id = "inf_29_iron_sights", enabled = true})
	# Lv1（旧档无 level 字段默认 1）→ 可升
	var i1: Dictionary = bpm.get_mod_upgrade_info(card, 0)
	assert_bool(bool(i1.get("can_upgrade", false))).is_true()
	assert_int(int(i1.get("level", 0))).is_equal(1)
	# 手动推进等级（扣费链依赖 autoload，等级推进语义由 entry.level 表达）
	card.mods[0]["level"] = 2
	var i2: Dictionary = bpm.get_mod_upgrade_info(card, 0)
	assert_bool(bool(i2.get("can_upgrade", false))).is_true()
	assert_int(int(i2.get("level", 0))).is_equal(2)
	card.mods[0]["level"] = 3
	var i3: Dictionary = bpm.get_mod_upgrade_info(card, 0)
	assert_bool(bool(i3.get("can_upgrade", true))).is_false()
	assert_str(String(i3.get("reason", ""))).contains("满级")

func test_preview_upgrade_cost_formula() -> void:
	var bpm = _make_bpm()
	var card := _make_card()
	card.power = 200
	card.mods.append({id = "inf_29_iron_sights", enabled = true})
	# 安装基准：200×0.5×(1+0.12×1)=112；Lv2 ×1.5=168、Lv3 ×2.5=280；图纸 = 目标等级−1
	var c2: Dictionary = bpm.preview_upgrade_cost(card, 0)
	assert_int(int(c2.get("blueprints", -1))).is_equal(1)
	assert_int(int(c2.get("nano", -1))).is_equal(168)
	card.mods[0]["level"] = 2
	var c3: Dictionary = bpm.preview_upgrade_cost(card, 0)
	assert_int(int(c3.get("blueprints", -1))).is_equal(2)
	assert_int(int(c3.get("nano", -1))).is_equal(280)

func test_preview_upgrade_cost_fallback_mode_no_blueprint() -> void:
	var bpm = _make_bpm()
	var card := _make_card()
	card.mods.append({id = "inf_29_iron_sights", enabled = true})
	var cfg = GameConfig.get_default()
	var old: bool = cfg.mod_consumable_enabled
	cfg.mod_consumable_enabled = false
	var c: Dictionary = bpm.preview_upgrade_cost(card, 0)
	cfg.mod_consumable_enabled = old
	assert_int(int(c.get("blueprints", -1))).is_equal(0)

# ── 等级解析（registry 档位消费口径）──

func test_resolve_mod_effects_by_level() -> void:
	var d: Dictionary = ModificationRegistry.get_data("gen_23_singularity_core")
	var e1: Dictionary = ModificationRegistry._resolve_mod_effects(d, 1)
	var e3: Dictionary = ModificationRegistry._resolve_mod_effects(d, 3)
	assert_float(float(e1.get("gravity_pulse_damage", 0.0))).is_equal(0.03)
	assert_float(float(e3.get("gravity_pulse_damage", 0.0))).is_equal(0.05)
	assert_float(float(e3.get("gravity_pulse_cd", 99.0))).is_less(float(e1.get("gravity_pulse_cd", 0.0)))

func test_backfilled_level_effects_monotonic() -> void:
	# 抽查 backfill 生成条目：Lv3 正值 > Lv1 正值；负副作用平坦
	var d: Dictionary = ModificationRegistry.get_data("aa_18_twin_mount")
	var e1: Dictionary = ModificationRegistry._resolve_mod_effects(d, 1)
	var e3: Dictionary = ModificationRegistry._resolve_mod_effects(d, 3)
	assert_float(float(e3.get("attack_air", 0.0))).is_greater(float(e1.get("attack_air", 0.0)))

# ── v27 新批次数据完整性 ──

const V27_NEW_IDS: Array = [
	"inf_28_combat_boots", "inf_29_iron_sights", "inf_30_load_vest", "inf_31_flash_suppressor",
	"inf_32_heavy_barrel", "inf_33_ammo_belt", "inf_34_kill_field_dressing", "inf_35_field_hospital",
	"arm_19_track_guards", "arm_20_commander_sight", "arm_21_turret_stabilizer",
	"arm_22_counter_pulse", "arm_23_platoon_datalink",
	"art_17_barrel_maintenance", "art_18_rapid_loader", "art_19_met_datalink",
	"art_20_last_stand", "art_21_saturation_director",
	"aa_16_ammo_cache", "aa_17_altimeter", "aa_18_twin_mount", "aa_19_barrage_computer",
	"air_23_cockpit_armor", "air_24_canard", "air_25_dual_mode_seeker", "air_26_drone_wingman",
	"rec_15_field_binoculars", "rec_16_silent_boots", "rec_17_multiband_sensor", "rec_18_target_database",
	"eng_15_entrenching_kit", "eng_16_field_generator", "eng_17_recovery_crane", "eng_18_defense_blueprints",
	"for_15_sandbag", "for_16_drainage", "for_17_hardened_bunker", "for_18_demolition_cache",
	"gen_18_pain_conductor", "gen_19_wave_surge", "gen_20_squad_tablet",
	"gen_21_vanguard_repair", "gen_22_aegis_protocol", "gen_23_singularity_core",
	"enh_crit_up", "enh_dodge_up", "enh_regen_up",
]

func test_v27_new_ids_count() -> void:
	assert_int(V27_NEW_IDS.size()).is_equal(47)

func test_v27_new_entries_complete_and_leveled() -> void:
	ModificationRegistry.register_all()
	for mod_id in V27_NEW_IDS:
		var d: Dictionary = ModificationRegistry.get_data(String(mod_id))
		assert_dict(d).override_failure_message("缺条目：%s" % mod_id).is_not_empty()
		assert_bool(d.has("name")).is_true()
		# enhancement 词条文件惯例只有 level_effects 无 effects（enh_hp_up 先例），二选一
		assert_bool(d.has("effects") or (d.get("level_effects", {}) as Dictionary).size() > 0) \
			.override_failure_message("%s 既无 effects 也无 level_effects" % mod_id).is_true()
		assert_bool((d.get("level_effects", {}) as Dictionary).size() >= 3) \
			.override_failure_message("%s 缺三档 level_effects（v27 新条目必须可升级）" % mod_id).is_true()

func test_v27_mythic_three_and_tier_gate() -> void:
	ModificationRegistry.register_all()
	var mythic_count := 0
	for id in ModificationRegistry.get_all_ids():
		if String(ModificationRegistry.get_data(String(id)).get("rarity", "")) == "mythic":
			mythic_count += 1
	assert_int(mythic_count).is_equal(3)
	# mythic 战力门槛=OVERLORD（修复 GRUNT 回退陷阱）
	assert_int(ModManager.get_min_power_tier_for_mod("gen_21_vanguard_repair")) \
		.is_equal(PowerTiers.Tier.OVERLORD)

func test_v27_mythic_drop_weight_enabled() -> void:
	assert_int(IntelManualItems._get_rarity_drop_weight("mythic", "normal")).is_equal(1)
	assert_int(IntelManualItems._get_rarity_drop_weight("mythic", "boss")).is_equal(3)

func test_v27_trigger_keys_classified_mechanic() -> void:
	# 面板"机制"分类依据：effects 命中 MECHANIC_EFFECT_KEYS 任一 key
	for pair in [["inf_34_kill_field_dressing", "kill_pulse_heal"],
			["arm_22_counter_pulse", "counter_pulse_damage"],
			["art_20_last_stand", "last_stand_burst"],
			["gen_18_pain_conductor", "pain_conduct_slow"],
			["gen_19_wave_surge", "wave_surge_shield"],
			["for_18_demolition_cache", "death_detonate_damage"],
			["gen_21_vanguard_repair", "vanguard_repair"],
			["gen_22_aegis_protocol", "aegis_pulse_shield"],
			["gen_23_singularity_core", "gravity_pulse_damage"]]:
		var d: Dictionary = ModificationRegistry.get_data(String(pair[0]))
		assert_bool((d.get("effects", {}) as Dictionary).has(String(pair[1]))) \
			.override_failure_message("%s 缺效果键 %s" % [pair[0], pair[1]]).is_true()
		assert_bool(ModificationRegistry.MECHANIC_EFFECT_KEYS.has(String(pair[1]))) \
			.override_failure_message("键 %s 未进 MECHANIC_EFFECT_KEYS（面板会误分类为数值）" % pair[1]).is_true()

# ── v27 新六套检测 ──

func test_v27_combo_sets_count() -> void:
	assert_int((ComboTactics.COMBOS as Dictionary).size()).is_equal(12)

func test_v27_combo_tier_detection() -> void:
	# 满档：集齐 4 件
	var full: Dictionary = ComboTactics.detect_card_combo_tiers(
		["arm_01_sloped_armor", "arm_02_composite_armor", "arm_03_reactive_armor", "arm_04_aps"])
	assert_str(String(full.get("armor_phalanx", ""))).is_equal(ComboTactics.TIER_FULL)
	# basic：2 件
	var basic: Dictionary = ComboTactics.detect_card_combo_tiers(["arm_01_sloped_armor", "arm_03_reactive_armor"])
	assert_str(String(basic.get("armor_phalanx", ""))).is_equal(ComboTactics.TIER_BASIC)
	# 混装不误触发：1 件不激活
	var none: Dictionary = ComboTactics.detect_card_combo_tiers(["arm_01_sloped_armor"])
	assert_bool(none.has("armor_phalanx")).is_false()

func test_v27_combo_sets_use_valid_mod_ids() -> void:
	ModificationRegistry.register_all()
	for combo_id in (ComboTactics.COMBOS as Dictionary).keys():
		var def: Dictionary = ComboTactics.COMBOS[String(combo_id)]
		for mid in def.get("mod_combo_full", []):
			assert_dict(ModificationRegistry.get_data(String(mid))) \
				.override_failure_message("套装 %s 引用不存在的改造 %s" % [combo_id, mid]).is_not_empty()
