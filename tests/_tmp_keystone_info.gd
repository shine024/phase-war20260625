extends SceneTree
const Reg = preload("res://scripts/systems/modification_registry.gd")
func _init() -> void:
	for k in ["inf_25_medic_sacrifice","arm_04_aps","arm_07_gun_missile","art_13_apfsds_sabot","art_14_counter_battery","aa_06_laser","aa_13_radar_lock","air_16_phase_shift","air_antiradiation_missile","rec_phased_radar","eng_12_reactive_engineering","for_11_advanced_minefield","gen_17_electronic_hijack","gen_unified_splash","gen_beam_splitter","gen_truestrike_pinpoint"]:
		var d: Dictionary = Reg.get_data(k)
		print("MOD ", k, " | ", d.get("name","?"), " | ", d.get("rarity","?"), " | ", str(d.get("desc","")).left(60))
	quit(0)
