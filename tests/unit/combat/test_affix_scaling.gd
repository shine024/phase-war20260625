class_name AffixScalingTest
extends GdUnitTestSuite

const _SOURCE := "res://managers/affix_manager.gd"

var _manager: Node


func before_test() -> void:
	_manager = Node.new()
	_manager.set_script(load(_SOURCE))
	add_child(_manager)


func after_test() -> void:
	# v7.x: 守卫 remove_child（manager _ready 异常时 parent 关系可能未建立），queue_free 更安全。
	if _manager != null and is_instance_valid(_manager):
		if _manager.is_inside_tree():
			remove_child(_manager)
		_manager.queue_free()
	_manager = null


func test_enhance_count_grows_with_level() -> void:
	# v7.x: Godot 4.5 无法从动态 _manager 方法推断返回类型，显式标注 int。
	var low: int = _manager._get_enhance_count_for_level(1)
	var high: int = _manager._get_enhance_count_for_level(60)
	assert_int(high).is_greater_equal(low)


func test_apply_affixes_to_stats_accepts_empty_cards() -> void:
	var dummy_stats = UnitStats.new()
	_manager.apply_affixes_to_stats(dummy_stats, null, [])
	assert_object(dummy_stats).is_not_null()


## ─── v27.1：传奇机制词条（special_mechanic）接线回归锁 ───────────────
## 三条词条此前 wired=false 被 roll 池过滤；接线后必须满足：
## ① wired=true 入池 ② apply_affixes_to_stats 把数值写进 UnitStats 对应字段。

const _SPECIAL_MECHANIC_IDS: Array = ["sm_crit_ensure_hit", "sm_fullhp_onslaught", "sm_double_tap"]


func test_special_mechanic_affixes_are_wired() -> void:
	for id_v in _SPECIAL_MECHANIC_IDS:
		var id: String = String(id_v)
		assert_bool(AffixDefinitions.get_definition(id).is_empty()).is_false()
		assert_bool(AffixDefinitions.is_affix_wired(id)).is_true()


func test_special_mechanic_stats_injection() -> void:
	var cases: Dictionary = {
		"sm_crit_ensure_hit": {"field": "crit_ensure_hit", "expect": 1.0},
		"sm_fullhp_onslaught": {"field": "full_hp_damage_bonus", "expect": 0.15},
		"sm_double_tap": {"field": "double_strike_chance", "expect": 0.08},
	}
	for id_v in _SPECIAL_MECHANIC_IDS:
		var id: String = String(id_v)
		var def: Dictionary = AffixDefinitions.get_definition(id)
		var affix := AffixResource.new()
		affix.affix_id = id
		affix.effect_key = String(def["effect_key"])
		affix.base_value = float(def["base_value"])
		affix.current_value = affix.base_value
		affix.rarity = "epic"
		var stats := UnitStats.new()
		_manager._card_affixes["test_%s_0" % id] = [affix]
		_manager._apply_card_affixes(stats, "test_%s_0" % id)
		var expect: float = float(cases[id]["expect"])
		assert_float(float(stats.get(String(cases[id]["field"])))).is_equal_approx(expect, 0.0001)


## ─── v27.2：星冥专属词条池 + 星髓洗练计费回归锁 ───────────────────────
## xeno_only 词条仅异族卡（captured_xeno_*）可出，普通卡 roll 池恒排除；
## 星冥卡洗练走星髓曲线，普通卡走纳米曲线。

const _XENO_AFFIX_IDS: Array = [
	"xeno_veil_step", "xeno_star_surge", "xeno_psi_carapace",
	"xeno_communion", "xeno_nova_burst", "xeno_apex_field",
]


func test_xeno_affixes_wired_and_gated() -> void:
	for id_v in _XENO_AFFIX_IDS:
		var id: String = String(id_v)
		assert_bool(AffixDefinitions.get_definition(id).is_empty()).is_false()
		# 全部复用已接线 effect_key，不允许死词条入池
		assert_bool(AffixDefinitions.is_affix_wired(id)).is_true()
		# 普通卡不可用；异族卡可用
		assert_bool(AffixDefinitions.is_affix_available_for(id, 0, 0, false)).is_false()
		assert_bool(AffixDefinitions.is_affix_available_for(id, 0, 0, true)).is_true()


func test_xeno_never_rolls_into_normal_pool() -> void:
	for i in range(300):
		var rid: String = AffixDefinitions.roll_random_affix_id(1, "", 0, 0, false)
		assert_bool(rid.begins_with("xeno_")).is_false()


func test_xeno_card_rolls_xeno_pool() -> void:
	var hit: int = 0
	for i in range(400):
		if AffixDefinitions.roll_random_affix_id(1, "", 0, 0, true).begins_with("xeno_"):
			hit += 1
	assert_int(hit).is_greater(0)


func test_xeno_reroll_billing_routing() -> void:
	# 身份判定（字符串前缀，headless 无 InstanceRegistry 也成立）
	assert_bool(_manager.is_xeno_card_identity("captured_xeno_swarmling#1")).is_true()
	assert_bool(_manager.is_xeno_card_identity("xeno_probe")).is_true()
	assert_bool(_manager.is_xeno_card_identity("ww1_mauser#1")).is_false()
	# 价目曲线：星髓 12 起 / 纳米 500 起
	var xkey: String = "captured_xeno_swarmling#1_0"
	var nkey: String = "ww1_mauser#1_0"
	assert_int(_manager.get_reroll_cost_for(xkey, 0)).is_equal(12)
	assert_int(_manager.get_reroll_cost_for(nkey, 0)).is_equal(500)
	assert_str(_manager.get_reroll_currency_label(xkey)).is_equal("星髓")
	assert_str(_manager.get_reroll_currency_label(nkey)).is_equal("纳米材料")


## ─── v27.3：兵种专属词条扩充回归锁 ───────────────────────────────────
## 每兵种 +2 常规（rare+）+1 冠军（epic+, min_tier 3），语义贴合兵种身份；
## 全部复用已接线 effect_key；kind 互斥 + 冠军档位门槛必须成立。

const _KIND_AFFIXES_V273: Dictionary = {
	"light_blitz": {"kind": 0, "tier": 0},
	"light_salvage": {"kind": 0, "tier": 0},
	"light_deadeye": {"kind": 0, "tier": 3},
	"armor_ap_shell": {"kind": 1, "tier": 0},
	"armor_intercept": {"kind": 1, "tier": 0},
	"armor_spearhead": {"kind": 1, "tier": 3},
	"support_ballistics": {"kind": 2, "tier": 0},
	"support_fortify": {"kind": 2, "tier": 0},
	"support_strategic_range": {"kind": 2, "tier": 3},
	"air_strafe": {"kind": 3, "tier": 0},
	"air_ecm_detach": {"kind": 3, "tier": 0},
	"air_double_rack": {"kind": 3, "tier": 3},
	"fort_flaknet": {"kind": 4, "tier": 0},
	"fort_selfrepair": {"kind": 4, "tier": 0},
	"fort_overwatch": {"kind": 4, "tier": 3},
}


func test_kind_affixes_v273_wired_and_gated() -> void:
	for id_v in _KIND_AFFIXES_V273.keys():
		var id: String = String(id_v)
		var cfg: Dictionary = _KIND_AFFIXES_V273[id]
		var kind: int = int(cfg["kind"])
		var tier: int = int(cfg["tier"])
		assert_bool(AffixDefinitions.get_definition(id).is_empty()).is_false()
		assert_bool(AffixDefinitions.is_affix_wired(id)).is_true()
		# 本兵种可用（冠军需 tier 达标），其它兵种恒不可用
		assert_bool(AffixDefinitions.is_affix_available_for(id, kind, tier, false)).is_true()
		for other in [0, 1, 2, 3, 4]:
			if other == kind:
				continue
			assert_bool(AffixDefinitions.is_affix_available_for(id, other, 3, false)).is_false()
		# 冠军词条低档位不可用
		if tier > 0:
			assert_bool(AffixDefinitions.is_affix_available_for(id, kind, tier - 1, false)).is_false()


## ─── v27.4：兵种专属词条再扩充回归锁（每兵种 +3 常规 +1 冠军） ─────────

const _KIND_AFFIXES_V274: Dictionary = {
	"light_penetration": {"kind": 0, "tier": 0},
	"light_dig_in": {"kind": 0, "tier": 0},
	"light_tandem": {"kind": 0, "tier": 0},
	"light_swarm": {"kind": 0, "tier": 3},
	"armor_autoloader": {"kind": 1, "tier": 0},
	"armor_def_skirt": {"kind": 1, "tier": 0},
	"armor_offroad": {"kind": 1, "tier": 0},
	"armor_thunder": {"kind": 1, "tier": 3},
	"support_heavy_charge": {"kind": 2, "tier": 0},
	"support_pioneers": {"kind": 2, "tier": 0},
	"support_escort": {"kind": 2, "tier": 0},
	"support_seismic": {"kind": 2, "tier": 3},
	"air_hardpoint": {"kind": 3, "tier": 0},
	"air_rockets": {"kind": 3, "tier": 0},
	"air_strato": {"kind": 3, "tier": 0},
	"air_ace_pride": {"kind": 3, "tier": 3},
	"fort_thick_walls": {"kind": 4, "tier": 0},
	"fort_servo_mount": {"kind": 4, "tier": 0},
	"fort_blast_door": {"kind": 4, "tier": 0},
	"fort_annihilator": {"kind": 4, "tier": 3},
}


func test_kind_affixes_v274_wired_and_gated() -> void:
	for id_v in _KIND_AFFIXES_V274.keys():
		var id: String = String(id_v)
		var cfg: Dictionary = _KIND_AFFIXES_V274[id]
		var kind: int = int(cfg["kind"])
		var tier: int = int(cfg["tier"])
		assert_bool(AffixDefinitions.get_definition(id).is_empty()).is_false()
		assert_bool(AffixDefinitions.is_affix_wired(id)).is_true()
		assert_bool(AffixDefinitions.is_affix_available_for(id, kind, tier, false)).is_true()
		for other in [0, 1, 2, 3, 4]:
			if other == kind:
				continue
			assert_bool(AffixDefinitions.is_affix_available_for(id, other, 3, false)).is_false()
		if tier > 0:
			assert_bool(AffixDefinitions.is_affix_available_for(id, kind, tier - 1, false)).is_false()
