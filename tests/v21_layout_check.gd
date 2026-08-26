extends SceneTree
## v21.x 相位仪布局重设计验证脚本（一次性冒烟，不依赖 GdUnit）
## 用法: godot --headless --rendering-driver opengl3 --path . --script tests/v21_layout_check.gd
## 验证点：
##   1. 8 个布局表 1-7 星完整、green 全部 ≥ MIN_GREEN_SLOTS(3)、无 spawn_range_ratio 键
##   2. 7星总格：Generic=12 / Aegis=10 / Helix=13 / Nova=13 / Iron=13 / Umbra=11 / Atlas=13 / Eon=13
##   3. 新能力：aegis_barrier / generic_overdrive 存在且参数正确
##   4. 升级能力：phantom_clone(7) deploy=3/atk1.2/hp1.0（低星仍=2）；piercing_shot(7) pierce=3
##   5. 代表性仪器 slot_counts 落地正确；_make_def 输出无 spawn_range_ratio
##   6. get_all() 全量构建不报错

var errors: Array[String] = []

func _initialize() -> void:
	var PI = load("res://data/phase_instruments.gd")

	# ── 1. 布局表完整性 ──
	var tables: Dictionary = {
		"Generic(_STAR_LAYOUT)": PI._STAR_LAYOUT,
		"Aegis": PI._FACTION_LAYOUT_AEGIS,
		"Helix": PI._FACTION_LAYOUT_HELIX,
		"Nova": PI._FACTION_LAYOUT_NOVA,
		"Iron": PI._FACTION_LAYOUT_IRON,
		"Umbra": PI._FACTION_LAYOUT_UMBRA,
		"Atlas": PI._FACTION_LAYOUT_ATLAS,
		"Eon": PI._FACTION_LAYOUT_EON,
	}
	for tname in tables.keys():
		var t: Dictionary = tables[tname]
		for star in range(1, 8):
			if not t.has(star):
				errors.append("%s 缺 %d 星条目" % [tname, star])
				continue
			var e: Dictionary = t[star]
			var g: int = int(e.get("green", -1))
			var r: int = int(e.get("rune", -1))
			if g < PI.MIN_GREEN_SLOTS:
				errors.append("%s %d星 green=%d < MIN_GREEN_SLOTS(%d)" % [tname, star, g, PI.MIN_GREEN_SLOTS])
			if e.has("spawn_range_ratio"):
				errors.append("%s %d星 仍残留 spawn_range_ratio 键" % [tname, star])

	# ── 2. 7星总格（19款分布：13格×15 / 12格×3 / 11格×1）──
	var expect7 := {
		"Generic(_STAR_LAYOUT)": 13, "Aegis": 12, "Helix": 13, "Nova": 13,
		"Iron": 12, "Umbra": 11, "Atlas": 13, "Eon": 12,
	}
	for tname in expect7.keys():
		var e7: Dictionary = tables[tname][7]
		var total: int = int(e7["green"]) + int(e7["rune"])
		if total != int(expect7[tname]):
			errors.append("%s 7星总格=%d 期望=%d" % [tname, total, expect7[tname]])

	# ── 3. 新能力 ──
	var ab: Dictionary = PI.ability_aegis_barrier(7)
	if ab.get("id", "") != "aegis_barrier":
		errors.append("aegis_barrier id 错误: %s" % ab.get("id"))
	else:
		var p: Dictionary = ab["params"]
		if absf(float(p["shield_amount"]) - 6000.0) > 0.01: errors.append("aegis_barrier 7星护盾=%s 期望6000" % p["shield_amount"])
		if absf(float(p["damage_reduction"]) - 0.15) > 0.001: errors.append("aegis_barrier 7星减伤=%s 期望0.15" % p["damage_reduction"])
	var ov: Dictionary = PI.ability_generic_overdrive(7)
	if ov.get("id", "") != "generic_overdrive":
		errors.append("generic_overdrive id 错误: %s" % ov.get("id"))
	else:
		var p2: Dictionary = ov["params"]
		if absf(float(p2["attr_boost"]) - 0.10) > 0.001: errors.append("overdrive 7星属性=%s 期望0.10" % p2["attr_boost"])
		if int(p2["cost_reduce"]) != 3: errors.append("overdrive 7星能耗减免=%s 期望3" % p2["cost_reduce"])

	# ── 4. 升级能力 ──
	var pc7: Dictionary = PI.ability_phantom_clone(7)["params"]
	if int(pc7["deploy_count"]) != 3: errors.append("phantom_clone(7) deploy_count=%s 期望3" % pc7["deploy_count"])
	if absf(float(pc7["clone_atk_bonus"]) - 1.2) > 0.001: errors.append("phantom_clone(7) atk=%s 期望1.2" % pc7["clone_atk_bonus"])
	if absf(float(pc7["clone_hp_bonus"]) - 1.0) > 0.001: errors.append("phantom_clone(7) hp=%s 期望1.0" % pc7["clone_hp_bonus"])
	for low_star in [3, 5]:
		var pcl: Dictionary = PI.ability_phantom_clone(low_star)["params"]
		if int(pcl["deploy_count"]) != 2:
			errors.append("phantom_clone(%d) deploy_count=%s 期望保持2" % [low_star, pcl["deploy_count"]])
	var ps7: Dictionary = PI.ability_piercing_shot(7)["params"]
	if int(ps7["pierce_targets"]) != 3: errors.append("piercing_shot(7) pierce=%s 期望3" % ps7["pierce_targets"])
	var ps6: Dictionary = PI.ability_piercing_shot(6)["params"]
	if int(ps6["pierce_targets"]) != 1: errors.append("piercing_shot(6) pierce=%s 期望保持1" % ps6["pierce_targets"])

	# ── 5. 代表性仪器 slot_counts ──
	var all: Array = PI.get_all()
	var by_id: Dictionary = {}
	for d in all:
		by_id[String(d["id"])] = d
	var expect_slots := {
		"pi_generic_11": [9, 4], "pi_generic_12": [9, 4], "pi_omega_01": [9, 4],
		"pi_aegis_04": [7, 5], "pi_helix_04": [9, 4], "pi_nova_03": [9, 4],
		"pi_iron_03": [8, 4], "pi_umbra_04": [5, 6], "pi_atlas_04": [8, 5],
		"pi_eon_03": [8, 4], "pi_special_nova": [9, 4],
		"pi_helix_01": [3, 0], "pi_generic_01": [3, 2], "pi_steel_01": [3, 2],
	}
	for iid in expect_slots.keys():
		if not by_id.has(iid):
			errors.append("缺少仪器定义: %s" % iid)
			continue
		var sc: Dictionary = by_id[iid]["slot_counts"]
		var want: Array = expect_slots[iid]
		if int(sc["green"]) != int(want[0]) or int(sc["rune"]) != int(want[1]):
			errors.append("%s slot=(%d,%d) 期望=(%d,%d)" % [iid, sc["green"], sc["rune"], want[0], want[1]])
		if by_id[iid].has("spawn_range_ratio"):
			errors.append("%s 输出字典仍含 spawn_range_ratio" % iid)

	# ── 5b. 能力挂载 ──
	if by_id.has("pi_aegis_04") and String(by_id["pi_aegis_04"]["active_ability"].get("id", "")) != "aegis_barrier":
		errors.append("pi_aegis_04 未挂 aegis_barrier: %s" % by_id["pi_aegis_04"]["active_ability"].get("id", ""))
	if by_id.has("pi_generic_11") and String(by_id["pi_generic_11"]["active_ability"].get("id", "")) != "generic_overdrive":
		errors.append("pi_generic_11 未挂 generic_overdrive")
	if by_id.has("pi_generic_12") and String(by_id["pi_generic_12"]["active_ability"].get("id", "")) != "mega_shield":
		errors.append("pi_generic_12 应保持 mega_shield")

	# ── 6. 全量构建 ──
	if all.size() < 60:
		errors.append("get_all() 数量=%d 异常（期望≥60）" % all.size())

	# ── 7. 7星分布统计（用户要求：13格占多数/极个别12/极个别11，绿8~9占多数，符6极个别）──
	var star7_list: Array = []
	for d in all:
		if int(d.get("star", 0)) == 7:
			star7_list.append(d)
	var total13: int = 0
	var total12: int = 0
	var total11: int = 0
	var rune6_count: int = 0
	var green89_count: int = 0
	for d in star7_list:
		var sc7: Dictionary = d["slot_counts"]
		var t7: int = int(sc7["green"]) + int(sc7["rune"])
		match t7:
			13: total13 += 1
			12: total12 += 1
			11: total11 += 1
			_: errors.append("7星 %s 总格=%d（不在 11/12/13 内）" % [d["id"], t7])
		if int(sc7["rune"]) == 6:
			rune6_count += 1
		if int(sc7["green"]) >= 8 and int(sc7["green"]) <= 9:
			green89_count += 1
	if star7_list.size() != 19:
		errors.append("7星仪器数=%d 期望19" % star7_list.size())
	if total13 != 15 or total12 != 3 or total11 != 1:
		errors.append("7星总格分布 13格×%d/12格×%d/11格×%d 期望 15/3/1" % [total13, total12, total11])
	if rune6_count != 1:
		errors.append("符6的7星款数=%d 期望1（仅Umbra）" % rune6_count)
	if green89_count != 17:
		errors.append("绿8~9的7星款数=%d 期望17" % green89_count)

	# ── 汇总 ──
	if errors.is_empty():
		print("[v21_layout_check] PASS — %d 款相位仪；7星19款：13格×%d/12格×%d/11格×%d，绿8~9×%d款，符6×%d款" % [all.size(), total13, total12, total11, green89_count, rune6_count])
		quit(0)
	else:
		print("[v21_layout_check] FAIL — %d 处问题：" % errors.size())
		for i in range(errors.size()):
			print("  %d. %s" % [i + 1, errors[i]])
		quit(1)
