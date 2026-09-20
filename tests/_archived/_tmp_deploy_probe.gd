extends SceneTree
## 探针：验证①缴获卡/势力卡 UCT 查空 ②直入卡制造 roll 空池 ③deploy_uses 缺键语义

func _initialize() -> void:
	var UCT = load("res://data/unified_card_table.gd")
	var MP = load("res://data/manufacture_pools.gd")
	var Manifest = load("res://data/enemy_unit_manifest.gd")
	var Fec = load("res://data/faction_exclusive_cards.gd")

	print("== 1. UCT 查表 ==")
	var cap_id: String = Manifest.captured_card_id_for("ww1_inf_storm_e")
	var e_cap: Dictionary = UCT.get_entry(cap_id)
	print("captured id 样本: ", cap_id, "  get_entry=", "EMPTY" if e_cap.is_empty() else "OK")
	var fe_id: String = ""
	if Fec.EXCLUSIVE_CARDS.size() > 0:
		fe_id = String(Fec.EXCLUSIVE_CARDS[0].get("id", ""))
	var e_fe: Dictionary = UCT.get_entry(fe_id) if fe_id != "" else {}
	print("fe_ 卡样本: ", fe_id, "  get_entry=", "EMPTY" if e_fe.is_empty() else "OK")
	var n_cap := 0
	var n_fe := 0
	for e in UCT.get_all_entries():
		var cid := String(e.get("card_id", ""))
		if cid.begins_with("captured_"):
			n_cap += 1
		if cid.begins_with("fe_"):
			n_fe += 1
	print("UCT 中 captured_ 键数=", n_cap, "  fe_ 键数=", n_fe)

	print("== 2. 制造 roll（直入卡口径 intel=0.0）==")
	var r0: String = MP.roll_rarity(0.0, 0, 1.0)
	print("roll_rarity(0.0,0,1.0) = '", r0, "'  (空=制造必失败)")
	var r_gate: String = MP.roll_rarity(0.25, 0, 1.0)
	print("roll_rarity(0.25,0,1.0) = '", r_gate, "'  (_pool_base 特判口径)")

	print("== 3. deploy_uses 缺键语义（模拟 _has_deploy_uses）==")
	var pool := {}
	var key := cap_id + "#1"
	print("missing key -> uses=", int(pool.get(key, 0)), " -> has_uses=", int(pool.get(key, 0)) > 0, " (false=拒绝部署)")
	quit(0)
