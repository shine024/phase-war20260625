## v8.2 卡图修复验证：manifest foe_ 前缀查询兜底
## 独立运行：D:\godot\Godot_v4.5.1.exe --headless --rendering-driver opengl3 --path . --script tests\v8_icon_fix_check.gd
extends SceneTree
const Manifest = preload("res://data/enemy_unit_manifest.gd")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	print("\n========== v8.2 卡图修复验证 ==========")

	# 之前确认的撞图卡（FIXED/CAPTURED/POOL/FORT段，foe_前缀查询miss）
	var test_cards: Array = [
		"ww1_inf_mp18", "ww1_inf_rifle", "ww1_sup_mg_nest", "ww1_arty_mortar",
		"ww1_fort_pillbox", "ww1_fort_artillery",
		"ww2_inf_thompson", "ww2_inf_garand", "ww2_sup_mg42",
		"cold_inf_ak", "cold_inf_m60",
		"mod_inf_marine",
		"fut_inf_cyborg", "fut_air_drone", "fut_fort_shield", "fut_fort_ion",
	]

	print("\n--- 验证：foe_前缀查询能命中专属图（修复前会miss→fallback撞图）---")
	for cid in test_cards:
		# 模拟运行时：card_id → foe_<id> → manifest 查图标
		var foe_key: String = "foe_" + cid
		var path: String = Manifest.get_unit_icon_path_for_archetype(foe_key)
		if not path.is_empty():
			_pass += 1
			print("  ✅ %s → foe_%s → %s" % [cid, cid, path.get_file()])
		else:
			_fail += 1
			print("  ❌ %s → foe_%s → (未命中，仍走fallback)" % [cid, cid])

	# 对照组：PLATFORM段卡（foe_前缀本就命中，不应受影响）
	print("\n--- 对照组：PLATFORM段卡（foe_前缀本就命中）---")
	var platform_cards: Array = ["ww1_arm_rolls", "ww2_arm_sherman", "fut_arm_nexus"]
	for cid in platform_cards:
		var path: String = Manifest.get_unit_icon_path_for_archetype("foe_" + cid)
		if not path.is_empty():
			_pass += 1
			print("  ✅ %s → %s" % [cid, path.get_file()])
		else:
			_fail += 1
			print("  ❌ %s → (未命中，回归!)" % cid)

	# 敌方查图（for_player=false）应返回 vis_enemy 原图
	print("\n--- 验证：敌方查图返回 vis_enemy 原图（编号不变）---")
	var enemy_path: String = Manifest.get_unit_icon_path_for_archetype("foe_ww1_inf_mp18", false)
	if enemy_path.contains("vis_enemy_036"):
		_pass += 1
		print("  ✅ 敌方 foe_ww1_inf_mp18 → vis_enemy_036.png")
	else:
		_fail += 1
		print("  ❌ 敌方查图异常: %s" % enemy_path)

	print("\n========== 结果 ==========")
	print("PASS: %d  FAIL: %d" % [_pass, _fail])
	if _fail > 0:
		print("❌ 有失败项")
	else:
		print("✅ 全部通过")
	quit(0 if _fail == 0 else 1)
