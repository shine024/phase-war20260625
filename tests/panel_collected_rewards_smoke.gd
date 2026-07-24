extends SceneTree
## v7.x 胜利面板漏显修复 — 独立加载验证（不依赖 autoload 顶层标识符）
## 仅验证 mvp_panel.gd（不依赖 autoload 顶层）和 DropTables 枚举。
## game_manager.gd / battle_damage_system.gd 因引用 autoload（BlueprintManager 等）
## 在 --script 模式下无法独立编译（项目既有限制），用 Grep 静态核对。

func _init() -> void:
	print("=== 胜利面板漏显修复 验证 ===\n")
	var all_ok := true

	# 1. 加载 mvp_panel.gd（不依赖 autoload 顶层，仅 preload 数据类 + 运行时 get_node_or_null）
	var MVP_script = load("res://scenes/ui/mvp_panel.gd")
	if MVP_script == null:
		print("❌ mvp_panel.gd 加载失败（可能因依赖链触及 autoload，详见下方）")
		all_ok = false
	else:
		print("✅ mvp_panel.gd 加载成功")
		# 2. 核对面板渲染方法存在
		var panel_apis := [
			"_render_collected_rewards",
			"_render_collected_section",
			"_collected_section_title",
			"_collected_entry_line",
			"_collected_entry_color",
			"_collected_rarity_name",
			"_collected_rarity_color",
			"_collected_resource_name",
		]
		for api in panel_apis:
			if MVP_script.has_method(api):
				print("  ✅ MvpPanel.%s" % api)
			else:
				print("  ❌ MvpPanel.%s 缺失" % api)
				all_ok = false
		# 3. 验证收集器条目渲染逻辑（纯静态函数）
		var test_entry := {"category": "card", "id": "test", "name": "测试卡", "count": 2, "source": "击杀缴获"}
		var line_text: String = MVP_script._collected_entry_line("card", test_entry)
		if line_text.find("测试卡") >= 0 and line_text.find("×2") >= 0:
			print("  ✅ 卡牌行: %s" % line_text)
		else:
			print("  ❌ 卡牌行异常: %s" % line_text)
			all_ok = false

		var rune_entry := {"category": "rune", "id": "attack_01", "name": "力量", "rarity": "rare", "source": "相位师战利品"}
		var rune_line: String = MVP_script._collected_entry_line("rune", rune_entry)
		if rune_line.find("力量") >= 0 and rune_line.find("稀有") >= 0:
			print("  ✅ 符文行: %s" % rune_line)
		else:
			print("  ❌ 符文行异常: %s" % rune_line)
			all_ok = false

		var inst_entry := {"category": "instrument", "id": "pi_special_rage", "name": "铁血元帅权杖", "star": 6, "source": "相位师掉落"}
		var inst_line: String = MVP_script._collected_entry_line("instrument", inst_entry)
		if inst_line.find("铁血元帅权杖") >= 0 and inst_line.find("★6") >= 0:
			print("  ✅ 相位仪行: %s" % inst_line)
		else:
			print("  ❌ 相位仪行异常: %s" % inst_line)
			all_ok = false

		var res_entry := {"category": "resource", "id": "nano_materials", "amount": 350, "source": "相位师战利品"}
		var res_line: String = MVP_script._collected_entry_line("resource", res_entry)
		if res_line.find("纳米材料") >= 0 and res_line.find("+350") >= 0:
			print("  ✅ 资源行: %s" % res_line)
		else:
			print("  ❌ 资源行异常: %s" % res_line)
			all_ok = false
	print("")

	# 4. 核对 DropTables 枚举（ENERGY_* 用于 P3 显示名修复）
	var DT = load("res://resources/drop_tables.gd")
	if DT != null:
		print("✅ drop_tables.gd 加载成功")
		# DropType 是 enum，作为类常量访问
		var ec = DT.DropType.ENERGY_CARD
		var ed = DT.DropType.ENERGY_DATA
		var eb = DT.DropType.ENERGY_BLUEPRINT
		print("  ✅ DropType.ENERGY_CARD=%d ENERGY_DATA=%d ENERGY_BLUEPRINT=%d" % [ec, ed, eb])
	else:
		print("❌ drop_tables.gd 加载失败")
		all_ok = false
	print("")

	# 5. 核对 card_drop_grants.gd（class_name CardDropGrants，依赖 DefaultCards preload 但不依赖 autoload 顶层）
	var CDG = load("res://scripts/card_drop_grants.gd")
	if CDG == null:
		print("❌ card_drop_grants.gd 加载失败")
		all_ok = false
	else:
		print("✅ card_drop_grants.gd 加载成功")
		var m = CDG.get_method_list()
		var found_grant := false
		for mi in m:
			if String(mi.name) == "grant_enemy_style_card":
				found_grant = true
				var args: Array = mi.args
				if args.size() >= 5:
					print("  ✅ grant_enemy_style_card 参数数 %d（含 source）" % args.size())
				else:
					print("  ❌ grant_enemy_style_card 参数数 %d，期望 >=5" % args.size())
					all_ok = false
				break
		if not found_grant:
			print("  ❌ grant_enemy_style_card 未找到")
			all_ok = false
		if CDG.has_method("_record_card_to_collector") and CDG.has_method("_get_game_manager"):
			print("  ✅ _record_card_to_collector / _get_game_manager 存在")
		else:
			print("  ❌ _record_card_to_collector 或 _get_game_manager 缺失")
			all_ok = false
	print("")

	# 说明：game_manager.gd / battle_damage_system.gd 引用 autoload 顶层（BlueprintManager/BasicResourceManager 等）
	# 在 --script 模式下无法独立编译，改用 Grep 静态核对（见验证报告）。
	print("ℹ️ game_manager.gd / battle_damage_system.gd 因引用 autoload 顶层，用 Grep 静态核对（不在此 smoke test 范围）")
	print("")

	if all_ok:
		print("=== ✅ 面板/蓝图层验证通过 ===")
	else:
		print("=== ❌ 有验证失败 ===")
	quit(0 if all_ok else 1)
