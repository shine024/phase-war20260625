extends GdUnitTestSuite
## v26.2 战斗环境效果 + 每关布局表 数据锁
## 覆盖：环境乘区聚合（默认关中性/显式关/时代默认叠加/总开关）、
## 布局激活态（默认 3×3 几何逐值不变、非默认关读表、废墟格、2 行偏移、L1 教程保护）。
## 注：布局用例会改 CardGridBattleLayout 静态激活态——每个用例前后 reset 防跨套件泄漏。

var BattleEnvEffectsRef = preload("res://data/battle_env_effects.gd")
var LayoutRef = preload("res://scripts/card_grid_battle_layout.gd")
var GameConfigRef = preload("res://resources/game_config.gd")

# ─── 环境效果：聚合 ───

func test_level1_default_env_all_neutral() -> void:
	# L1 = WW1 时代默认 clear/plain/normal/day → 全中性（教程关零干扰）
	var m: Dictionary = BattleEnvEffectsRef.get_level_env_mults(1)
	assert_bool(BattleEnvEffectsRef.has_any_effect(m)).is_false()
	for k in ["indirect_dmg", "direct_dmg", "all_dmg", "direct_range", "atk_speed", "regen"]:
		assert_float(float(m.get(k, 0.0))).is_equal_approx(1.0, 0.0001)

func test_level10_explicit_rain_city() -> void:
	# L10 显式 rain+city+dusk：分立桶 rain→indirect 0.90 / city→all 0.925 / dusk→direct_range 0.92，
	# 武器结算时组合：曲射 0.90×0.925=0.8325、直射 0.925（all_dmg 不单占 direct 桶）
	var m: Dictionary = BattleEnvEffectsRef.get_level_env_mults(10)
	assert_float(float(m.get("indirect_dmg"))).is_equal_approx(0.90, 0.0001)
	assert_float(float(m.get("direct_dmg"))).is_equal_approx(1.0, 0.0001)
	assert_float(float(m.get("all_dmg"))).is_equal_approx(0.925, 0.0001)
	assert_float(float(m.get("direct_range"))).is_equal_approx(0.92, 0.0001)
	assert_float(BattleEnvEffectsRef.damage_mult_for_weapon(m, 1)).is_equal_approx(0.8325, 0.0001)  # wt1=INDIRECT
	assert_float(BattleEnvEffectsRef.damage_mult_for_weapon(m, 0)).is_equal_approx(0.925, 0.0001)  # wt0=DIRECT
	assert_int((m.get("descs") as Array).size()).is_equal(3)

func test_level61_modern_era_default_stack() -> void:
	# L61 = MODERN 时代默认 storm+city+high_field+night：
	# 分立桶 direct 0.92 / all 0.925 / regen 1.15 / direct_range 0.88；直射武器组合 0.851
	var m: Dictionary = BattleEnvEffectsRef.get_level_env_mults(61)
	assert_float(float(m.get("direct_dmg"))).is_equal_approx(0.92, 0.001)
	assert_float(BattleEnvEffectsRef.damage_mult_for_weapon(m, 0)).is_equal_approx(0.851, 0.001)
	assert_float(float(m.get("regen"))).is_equal_approx(1.15, 0.001)
	assert_float(float(m.get("direct_range"))).is_equal_approx(0.88, 0.001)

func test_env_switch_off_returns_neutral() -> void:
	var cfg = GameConfigRef.get_default()
	var old: bool = bool(cfg.env_effects_enabled)
	cfg.env_effects_enabled = false
	var m: Dictionary = BattleEnvEffectsRef.get_level_env_mults(68)
	assert_bool(BattleEnvEffectsRef.has_any_effect(m)).is_false()
	cfg.env_effects_enabled = old

# ─── 布局：默认几何逐值不变（回归锁） ───

func test_layout_default_geometry_unchanged() -> void:
	LayoutRef.reset_to_default()
	assert_float(LayoutRef.column_width_px()).is_equal_approx(1200.0 / 7.0, 0.01)
	assert_int(LayoutRef.player_slots_total()).is_equal(9)
	assert_int(LayoutRef.enemy_slots_total()).is_equal(9)
	assert_bool(LayoutRef.is_slot_excluded(4, "player")).is_false()
	assert_float(LayoutRef.battle_card_width_px(false)).is_equal_approx(142.86, 0.1)

func test_layout_level1_is_default_for_tutorial() -> void:
	LayoutRef.reset_to_default()
	# L1 无布局条目——教程首战必须是最朴素的 3×3
	assert_bool(LayoutRef.apply_for_level(1)).is_false()
	assert_int(LayoutRef.player_slots_total()).is_equal(9)

# ─── 布局：非默认关读表 ───

func test_layout_level25_enemy_four_cols() -> void:
	LayoutRef.reset_to_default()
	assert_bool(LayoutRef.apply_for_level(25)).is_true()
	assert_int(LayoutRef.player_slots_total()).is_equal(9)
	assert_int(LayoutRef.enemy_slots_total()).is_equal(12)
	# 列宽除数 max(7, 3+4+1)=8；总宽恒不超 1200
	assert_float(LayoutRef.column_width_px()).is_equal_approx(1200.0 / 8.0, 0.01)
	assert_bool(LayoutRef.total_grid_width_px() <= 1200.0).is_true()
	LayoutRef.reset_to_default()

func test_layout_level10_rubble_slots() -> void:
	LayoutRef.reset_to_default()
	LayoutRef.apply_for_level(10)
	assert_bool(LayoutRef.is_slot_excluded(2, "player")).is_true()
	assert_bool(LayoutRef.is_slot_excluded(6, "player")).is_true()
	assert_bool(LayoutRef.is_slot_excluded(4, "player")).is_false()
	LayoutRef.reset_to_default()

func test_layout_level33_two_rows() -> void:
	LayoutRef.reset_to_default()
	LayoutRef.apply_for_level(33)
	assert_int(LayoutRef.active_rows()).is_equal(2)
	assert_int(LayoutRef.player_slots_total()).is_equal(6)
	# 2 行沿用 3 行上下边线
	assert_float(LayoutRef.row_y_offset(0)).is_equal(-120.0)
	assert_float(LayoutRef.row_y_offset(1)).is_equal(10.0)
	LayoutRef.reset_to_default()

func test_layout_switch_off_keeps_default() -> void:
	var cfg = GameConfigRef.get_default()
	var old: bool = bool(cfg.battle_layouts_enabled)
	cfg.battle_layouts_enabled = false
	assert_bool(LayoutRef.apply_for_level(25)).is_false()
	assert_int(LayoutRef.enemy_slots_total()).is_equal(9)
	cfg.battle_layouts_enabled = old
	LayoutRef.reset_to_default()
