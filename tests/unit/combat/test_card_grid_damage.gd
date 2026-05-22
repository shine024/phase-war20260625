class_name CardGridDamageTest
extends GdUnitTestSuite

const CardGridDamage = preload("res://scripts/card_grid_damage.gd")


func test_defense_damage_multiplier_at_bounds() -> void:
	assert_float(CardGridDamage.defense_damage_multiplier(0.0)).is_equal_approx(1.0, 0.001)
	assert_float(CardGridDamage.defense_damage_multiplier(16.0)).is_equal_approx(1.0 - 16.0 / 66.0, 0.001)
	assert_float(CardGridDamage.defense_damage_multiplier(50.0)).is_equal_approx(0.5, 0.001)


func test_resolve_hit_percent_mitigation() -> void:
	var hit: Dictionary = CardGridDamage.resolve_hit(100.0, 16.0, 0.0)
	var expected: float = maxf(1.0, 100.0 * CardGridDamage.defense_damage_multiplier(16.0))
	assert_float(float(hit["hp_loss"])).is_equal_approx(expected, 0.05)
