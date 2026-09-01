extends GdUnitTestSuite
## v22 改造数值四通道 + 时代适配测试
## 覆盖：set 替换通道（含更优守卫/两遍历顺序/时代缩放）、显式 _pct 键、
## flat 时代缩放、era_band 兼容与装配过滤、攻击改造→武器槽伤害同步（存量空转 bug 回归锁）。

var ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
var UnitStatsTable = preload("res://resources/unit_stats_table.gd")
var DefaultCards = preload("res://data/default_cards.gd")

# ─── 百分比通道：float-on-base 旧写法 与 显式 _pct 等价 ───

func test_pct_float_on_base_key_legacy() -> void:
	# enh_dmg_up Lv1：attack_* 三维 float 0.15 → +15%（旧写法不变）
	# 注：registry 乘区用 int() 截断，100×1.15 浮点得 114.999… → 114（既有语义）
	var r: Dictionary = ModificationRegistry.apply_with_level(
		{"attack_light": 100}, [{"id": "enh_dmg_up", "level": 1}])
	assert_int(int(r["attack_light"])).is_equal(114)

func test_explicit_pct_key_equivalent() -> void:
	# arm_02 复合装甲 v22 改显式 defense_armor_pct = 0.30 —— 与旧 float 写法等价
	var r: Dictionary = ModificationRegistry.apply_with_level(
		{"defense_armor": 100}, [{"id": "arm_02_composite_armor", "level": 1}])
	assert_int(int(r["defense_armor"])).is_equal(130)

# ─── 替换通道（set）─────────────────────────────

func test_set_channel_replaces_when_higher() -> void:
	# inf_02 突击步枪化（band [1,2]，era1 基准 90）：60 → 替换为 90
	var r: Dictionary = ModificationRegistry.apply_with_level(
		{"attack_light": 60}, [{"id": "inf_02_assault_rifle", "level": 1}], {"era": 1})
	assert_int(int(r["attack_light"])).is_equal(90)

func test_set_guard_no_downgrade() -> void:
	# 更优才生效：基础 120 的卡装 set 90 → 不降级
	var r: Dictionary = ModificationRegistry.apply_with_level(
		{"attack_light": 120}, [{"id": "inf_02_assault_rifle", "level": 1}], {"era": 1})
	assert_int(int(r["attack_light"])).is_equal(120)

func test_set_applies_before_pct() -> void:
	# 两遍历顺序：先 set（60→90），后百分比（enh_dmg_up +15%）→ int(90×1.15)=103
	var r: Dictionary = ModificationRegistry.apply_with_level(
		{"attack_light": 60},
		[{"id": "inf_02_assault_rifle", "level": 1}, {"id": "enh_dmg_up", "level": 1}],
		{"era": 1})
	assert_int(int(r["attack_light"])).is_equal(103)

func test_set_value_era_scaling() -> void:
	# set 值随宿主时代缩放：era1 声明 90 → era2 宿主 90×(2.7/1.8)=135
	var r: Dictionary = ModificationRegistry.apply_with_level(
		{"attack_light": 60}, [{"id": "inf_02_assault_rifle", "level": 1}], {"era": 2})
	assert_int(int(r["attack_light"])).is_equal(135)

func test_set_pilot_smoothbore_gun() -> void:
	# arm_05 滑膛炮（v25.1 替换通道试点②，band [2,4]，era2 基准 560）：
	# era2 中位炮 508 → 560；era3 弱炮 740 → 560×(5.3/2.7)=1099；era4 顶级炮 1865 →
	# 缩放 1244 低于基础 → 更优才生效守卫不覆盖（"已有等效火力不重复换装"）
	var r2: Dictionary = ModificationRegistry.apply_with_level(
		{"attack_armor": 508}, [{"id": "arm_05_smoothbore", "level": 1}], {"era": 2})
	assert_int(int(r2["attack_armor"])).is_equal(560)
	var r3: Dictionary = ModificationRegistry.apply_with_level(
		{"attack_armor": 740}, [{"id": "arm_05_smoothbore", "level": 1}], {"era": 3})
	assert_int(int(r3["attack_armor"])).is_equal(1099)
	var r4: Dictionary = ModificationRegistry.apply_with_level(
		{"attack_armor": 1865}, [{"id": "arm_05_smoothbore", "level": 1}], {"era": 4})
	assert_int(int(r4["attack_armor"])).is_equal(1865)

func test_urban_cover_independent_multiplier() -> void:
	# v25.1 巷战掩蔽独立乘区：0 防御 0 闪避 0 减伤下，urban 0.15 → 伤害 ×0.85；
	# 与 dmg_red 独立乘算（0.30 + 0.15 → 100×0.70×0.85=59.5）；超帽 0.9 → 钳 0.75
	var CardGridDamage = load("res://scripts/card_grid_damage.gd")
	var h1: Dictionary = CardGridDamage.resolve_hit(100.0, 0.0, 0.0, 0.0, 0.15)
	assert_float(float(h1["hp_loss"])).is_equal_approx(85.0, 0.01)
	var h2: Dictionary = CardGridDamage.resolve_hit(100.0, 0.0, 0.0, 0.30, 0.15)
	assert_float(float(h2["hp_loss"])).is_equal_approx(59.5, 0.01)
	var h3: Dictionary = CardGridDamage.resolve_hit(100.0, 0.0, 0.0, 0.0, 0.90)
	assert_float(float(h3["hp_loss"])).is_equal_approx(25.0, 0.01)

# ─── 固定值（flat）时代缩放 ──────────────────────

func test_flat_int_no_ctx_keeps_legacy_absolute() -> void:
	# 旧调用方（无 host_ctx）：int flat 保持绝对值不缩放
	var r: Dictionary = ModificationRegistry.apply_with_level(
		{"attack_light": 100}, [{"id": "inf_03_small_caliber", "level": 1}])
	assert_int(int(r["attack_light"])).is_equal(107)

func test_flat_int_era_scaling() -> void:
	# inf_03 小口径化（band [2,4]，ref era2 声明 +7）：
	# era2 宿主 → +7；era4 宿主 → 7×(6.0/2.7)=15.56 → 16
	var r2: Dictionary = ModificationRegistry.apply_with_level(
		{"attack_light": 100}, [{"id": "inf_03_small_caliber", "level": 1}], {"era": 2})
	assert_int(int(r2["attack_light"])).is_equal(107)
	var r4: Dictionary = ModificationRegistry.apply_with_level(
		{"attack_light": 100}, [{"id": "inf_03_small_caliber", "level": 1}], {"era": 4})
	assert_int(int(r4["attack_light"])).is_equal(116)

func test_true_damage_era_scaling() -> void:
	# inf_07 光学瞄准镜 true_damage 8（era0 基准）：era3 宿主 → 8×5.3=42.4 → 42
	var r: Dictionary = ModificationRegistry.apply_with_level(
		{"true_damage": 0.0}, [{"id": "inf_07_optical_scope", "level": 1}], {"era": 3})
	assert_int(int(r["true_damage"])).is_equal(42)

# ─── 混合条目（flat + pct 并存）─────────────────

func test_sloped_armor_hybrid() -> void:
	# arm_01 倾斜装甲 Lv1：defense_armor +15 flat 且 ×1.08 → int((90+15)×1.08)=113
	var r: Dictionary = ModificationRegistry.apply_with_level(
		{"defense_armor": 90}, [{"id": "arm_01_sloped_armor", "level": 1}], {"era": 0})
	assert_int(int(r["defense_armor"])).is_equal(113)

# ─── era_band 兼容与装配过滤 ────────────────────

func test_era_band_compat() -> void:
	var scope: Dictionary = ModificationRegistry.get_data("inf_07_optical_scope")
	assert_bool(ModificationRegistry.is_mod_era_compatible(scope, 0)).is_true()
	assert_bool(ModificationRegistry.is_mod_era_compatible(scope, 3)).is_true()
	# 近未来激光卡（era4）装光学瞄准镜——主题违和由硬门拦截
	assert_bool(ModificationRegistry.is_mod_era_compatible(scope, 4)).is_false()
	var no_band: Dictionary = ModificationRegistry.get_data("enh_dmg_up")
	for era in range(5):
		assert_bool(ModificationRegistry.is_mod_era_compatible(no_band, era)).is_true()

func test_installable_mods_era_filter() -> void:
	# 一战坦克（era0）：倾斜装甲 [0,2] 可装，复合装甲 [2,4] 不可装
	var ids: Array = ModificationRegistry.get_installable_mods_for_card("ww1_arm_ft17", 0)
	assert_bool(ids.has("arm_01_sloped_armor")).is_true()
	assert_bool(ids.has("arm_02_composite_armor")).is_false()
	# 未过滤全集仍含两者（enemy_card_mod_map 等跨时代消费方依赖）
	var all: Array = ModificationRegistry.get_mods_for_card("ww1_arm_ft17")
	assert_bool(all.has("arm_01_sloped_armor")).is_true()
	assert_bool(all.has("arm_02_composite_armor")).is_true()

# ─── 存量空转 bug 回归锁：攻击改造必须进武器槽伤害 ───

func test_attack_mod_reaches_weapon_damage() -> void:
	var card = DefaultCards.get_card_by_id("ww1_arm_ft17").clone()
	var base = UnitStatsTable.build_stats_from_card(card, 0)
	assert_float(float(base.weapon_slots[1].damage)).is_equal(272.0)

	# enh_dmg_up +15%：stats.attack_armor 272→312，武器槽伤害必须同步（v22 前恒 272 空转）
	card.mods = [{"id": "enh_dmg_up", "level": 1, "enabled": true}]
	var modded = UnitStatsTable.build_stats_from_card(card, 0)
	assert_int(int(modded.attack_armor)).is_equal(312)
	assert_int(int(modded.weapon_slots[1].damage)).is_equal(312)

func test_set_mod_reaches_weapon_damage() -> void:
	# set 通道经比值同步落地武器槽：ww2_inf_bazooka（era1，对轻 60）→ 替换为 90
	var card = DefaultCards.get_card_by_id("ww2_inf_bazooka").clone()
	assert_float(float(card.attack_light)).is_equal(60.0)
	card.mods = [{"id": "inf_02_assault_rifle", "level": 1, "enabled": true}]
	var modded = UnitStatsTable.build_stats_from_card(card, 1)
	assert_int(int(modded.attack_light)).is_equal(90)
	assert_int(int(modded.weapon_slots[0].damage)).is_equal(90)

# ─── 装甲兵种加成武器槽同步死代码修复回归锁 ───

func test_kind_bonus_weapon_sync_resource_slots() -> void:
	# 装甲单位固定机制"装甲碾压 +20%"（attack_light_bonus）——v22 前
	# _sync_kind_bonus_to_weapon_slots 只认 Dictionary，WeaponResource 槽位全跳过
	var card = DefaultCards.get_card_by_id("ww1_arm_ft17").clone()
	var stats = UnitStatsTable.build_stats_from_card(card, 0)
	assert_float(float(stats.attack_light_bonus)).is_equal(0.20)
	# slot[0]（对轻）伤害应含 +20%：61 → 73（int 截断 73.2）
	assert_int(int(stats.weapon_slots[0].damage)).is_equal(73)
