extends SceneTree
## v6.14 A4 行为冒烟：改造图纸掉落的时代过滤（--script 直跑，不启 autoload，秒级）
## v6.14.1 口径：普通件限当前时代；极特殊件（epic/legendary/mythic）可跨一级前瞻。
## 通过条件：max_era=0 的掉落全部"era0 兼容 或 (era1 兼容且史诗+)"；
##           max_era=-1 旧行为仍会出现该口径外条目。

func _ok(reg, mod_id: String, era: int) -> bool:
	var md: Dictionary = reg.get_data(mod_id)
	if reg.is_mod_era_compatible(md, era):
		return true
	var era_hi: int = mini(era + 1, 4)
	if era_hi == era:
		return false
	if not reg.is_mod_era_compatible(md, era_hi):
		return false
	return String(md.get("rarity", "common")) in ["epic", "legendary", "mythic"]

func _init() -> void:
	var items = load("res://data/intel_manual_items.gd")
	var reg = load("res://scripts/systems/modification_registry.gd")
	if items == null or reg == null:
		print("A4 SMOKE FAIL (load null)")
		quit(1)
		return
	var bad := 0
	var total := 0
	var lookahead := 0
	for i in 400:
		var d: Dictionary = items.roll_random_mod_blueprint("infantry", "normal", -1, [], 0)
		if d.is_empty():
			continue
		total += 1
		if _ok(reg, String(d["mod_id"]), 0):
			var md: Dictionary = reg.get_data(String(d["mod_id"]))
			if not reg.is_mod_era_compatible(md, 0):
				lookahead += 1
		else:
			bad += 1
	var legacy_bad := 0
	var legacy_total := 0
	for i in 200:
		var d2: Dictionary = items.roll_random_mod_blueprint("infantry", "boss", 4, [], -1)
		if d2.is_empty():
			continue
		legacy_total += 1
		if not _ok(reg, String(d2["mod_id"]), 0):
			legacy_bad += 1
	print("[A4] era0: rolls=%d bad=%d 前瞻件=%d | legacy(-1): rolls=%d 口径外=%d" % [
		total, bad, lookahead, legacy_total, legacy_bad])
	# v6.14.2 缴获语义：kit roll 只掉携带件
	var loadouts = load("res://data/enemy_fixed_loadouts.gd")
	var kit: Array = loadouts.get_mods_for_tier("ww1_inf_mp18", 1)
	var kit_bad := 0
	var kit_total := 0
	var kit_set := {}
	for m in kit:
		kit_set[String(m)] = true
	for i in 100:
		var kd: Dictionary = items.roll_mod_blueprint_from_kit(kit, 0)
		if kd.is_empty():
			continue
		kit_total += 1
		if not kit_set.has(String(kd["mod_id"])):
			kit_bad += 1
	print("[A4] kit: rolls=%d 越界=%d（要求 0；kit=%d 条）" % [kit_total, kit_bad, kit.size()])
	var ok := (bad == 0) and (legacy_bad > 0) and (total > 300) and (kit_total > 50) and (kit_bad == 0)
	# v6.14.4 发现腿：era0 口径 + 未见优先
	var seen_all := func(_m: String) -> bool: return true
	var d_bad := 0
	var d_total := 0
	for i in 200:
		var dd: Dictionary = items.roll_discovery_mod_blueprint("normal", -1, 0, seen_all)
		if dd.is_empty():
			continue
		d_total += 1
		var md: Dictionary = reg.get_data(String(dd["mod_id"]))
		if not (reg.is_mod_era_compatible(md, 0) or (String(md.get("rarity", "common")) in ["epic", "legendary", "mythic"] and reg.is_mod_era_compatible(md, 1))):
			d_bad += 1
	var seen_one := func(m: String) -> bool: return m != "inf_14_knee_pads"
	var tgt := 0
	for i in 60:
		var d2: Dictionary = items.roll_discovery_mod_blueprint("normal", -1, 0, seen_one)
		if not d2.is_empty() and String(d2["item_type"]) == "blueprint_inf_14_knee_pads":
			tgt += 1
	print("[A4] discovery: rolls=%d bad=%d 未见优先命中=%d/60" % [d_total, d_bad, tgt])
	ok = ok and (d_bad == 0) and (tgt > 0) and (d_total > 150)
	print("A4 SMOKE %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
# v6.14.4 发现腿（追加在 _init 内不可行——独立函数由末尾调用）
