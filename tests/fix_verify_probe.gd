extends Node
## 修复验证：art_14 shots+2 链路 / inf_05 grant_slot 换装覆盖
##   godot --headless --path . res://tests/fix_verify_probe.tscn
const UST = preload("res://resources/unit_stats_table.gd")
const DC = preload("res://data/default_cards.gd")

func _ready() -> void:
	await get_tree().process_frame
	var mr: Node = get_node("/root/ModificationRegistry")

	# 1) art_14: m270 白板 vs modded 的 counter_battery_shots
	var m270: CardResource = DC.get_card_by_id("mod_arty_m270")
	var bare_a = UST.build_stats_from_card(m270.duplicate(true), 0)
	var mod_a: CardResource = m270.duplicate(true)
	mod_a.mods = [{"id": "art_14_counter_battery", "enabled": true}]
	var modded_a = UST.build_stats_from_card(mod_a, 0)
	print("[art_14] m270 shots 白板=%d → 装后=%d（应 +2）has=%s→%s" % [
		bare_a.counter_battery_shots, modded_a.counter_battery_shots,
		bare_a.has_counter_battery, modded_a.has_counter_battery])

	# 2) inf_05: mp18 对装甲槽 白板 vs 装后（换装覆盖验证）
	var mp18: CardResource = DC.get_card_by_id("ww1_mp18")
	var bare_b = UST.build_stats_from_card(mp18.duplicate(true), 0)
	var mod_b: CardResource = mp18.duplicate(true)
	mod_b.mods = [{"id": "inf_05_ap_ammo", "enabled": true}]
	var modded_b = UST.build_stats_from_card(mod_b, 0)
	var w_dps := func(s) -> float:
		var v: float = 0.0
		for w in s.weapon_slots:
			if w is WeaponResource and w.enabled and float(w.damage) > 0.0:
				v += float(w.damage) * float(w.attack_speed)
		return v
	print("[inf_05] mp18 weapon_dps 白板=%.1f → 装后=%.1f（应上升：对装甲槽换装 0.8×基准）" % [
		w_dps.call(bare_b), w_dps.call(modded_b)])

	get_tree().quit(0)
