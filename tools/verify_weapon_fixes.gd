extends SceneTree
## 武器配置修复验证（--script 模式，秒级）
## 1) 锚点文件可编译（重复键已清除）+ fut_air_drone 保留值正确
## 2) 统一表 6 项修复生效

const Foot := preload("res://data/card_foot_anchors.gd")
const Muzzle := preload("res://data/muzzle_anchors.gd")
const UCT := preload("res://data/unified_card_table.gd")

func _init() -> void:
	var fails: Array = []

	# ── 1) 锚点：单键 + 保留 HEAD 的扫描值 ──
	if absf(float(Foot.VISUAL_SCALE.get("fut_air_drone", 0.0)) - 1.25) > 0.001:
		fails.append("VISUAL_SCALE fut_air_drone=%s（期望 1.25）" % str(Foot.VISUAL_SCALE.get("fut_air_drone")))
	if absf(float(Foot.FOOT_FRAC.get("fut_air_drone", -1.0)) - 0.297) > 0.001:
		fails.append("FOOT_FRAC fut_air_drone=%s（期望 0.297）" % str(Foot.FOOT_FRAC.get("fut_air_drone")))
	if absf(float(Foot.HEAD_FRAC.get("fut_air_drone", -1.0)) - 0.295) > 0.001:
		fails.append("HEAD_FRAC fut_air_drone=%s（期望 0.295）" % str(Foot.HEAD_FRAC.get("fut_air_drone")))
	var mz: Dictionary = Muzzle.MUZZLE.get("fut_air_drone", {})
	if absf(float(mz.get("fireX", -1.0)) - 0.0656) > 0.0001 or absf(float(mz.get("fireY_pct", -1.0)) - 43.07) > 0.01:
		fails.append("MUZZLE fut_air_drone=%s（期望 fireX=0.0656 fireY_pct=43.07）" % str(mz))

	# ── 2) 统一表修复项 ──
	var checks := {
		"platform_cold_ifv": {"key": "weapon_type", "want": 0, "label": "步战车武器类型→直射"},
		"fut_boss_nexus": {"key": "weapon_type", "want": 1, "label": "风暴核心武器类型→曲射"},
		"mod_sup_growler": {"key": "weapon_type", "want": 2, "label": "电子战机武器类型→空射"},
		"mod_boss_command": {"key": "atk_air", "want": 70, "label": "指挥中枢对空=70"},
		"ww1_boss_av7": {"key": "atk_air", "want": 20, "label": "圣沙蒙对空=20"},
		"mod_arty_mlrs_e": {"key": "range_value", "want": 5, "label": "火箭炮车射程=5"},
	}
	for cid in checks:
		var spec: Dictionary = checks[cid]
		var e: Dictionary = UCT.get_entry(cid)
		if e.is_empty():
			fails.append("%s 条目缺失" % cid)
			continue
		var got = e.get(spec["key"])
		if int(got) != int(spec["want"]):
			fails.append("%s %s=%s（期望 %s）" % [cid, spec["key"], str(got), str(spec["want"])])

	if fails.is_empty():
		print("[PASS] 锚点重复键已清除（4 项保留值正确）+ 统一表 6 项修复全部生效")
	else:
		for f in fails:
			push_error("[FAIL] " + f)
		print("[FAIL] %d 项未通过" % fails.size())
	quit(0)
