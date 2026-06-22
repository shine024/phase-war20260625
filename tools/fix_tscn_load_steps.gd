## fix_tscn_load_steps.gd
## 自动修复 .tscn 文件中的 load_steps 不匹配问题
## 用法：在 Godot 编辑器中运行此脚本，或通过命令行执行

extends RefCounted

const FIX_PATTERNS = {
	"scenes/ui/active_law_cast_panel.tscn": 2,
	"scenes/ui/affix_panel.tscn": 4,
	"scenes/ui/backpack_card_item.tscn": 10,
	"scenes/ui/backpack_panel.tscn": 8,
	"scenes/ui/backpack_scroll.tscn": 1,
	"scenes/ui/battle_click_overlay.tscn": 1,
	"scenes/ui/battle_hud.tscn": 4,
	"scenes/ui/battle_info_display.tscn": 2,
	"scenes/ui/battle_result_dialog.tscn": 1,
	"scenes/ui/bottom_instrument_bar.tscn": 3,
	"scenes/ui/card_affix_tooltip.tscn": 1,
	"scenes/ui/card_enhancement_panel.tscn": 8,
	"scenes/ui/card_grid_battle_hud.tscn": 1,
	"scenes/ui/card_info_panel.tscn": 5,
	"scenes/ui/daily_task_panel.tscn": 1,
	"scenes/ui/drops_inventory_panel.tscn": 1,
	"scenes/ui/enemy_spawn_hud.tscn": 2,
	"scenes/ui/energy_bar.tscn": 4,
	"scenes/ui/equipped_passives_box.tscn": 2,
	"scenes/ui/evolution_panel.tscn": 1,
	"scenes/ui/faction_store_panel.tscn": 1,
	"scenes/ui/global_save_button.tscn": 1,
	"scenes/ui/health_bar.tscn": 5,
	"scenes/ui/help_panel.tscn": 1,
	"scenes/ui/intelligence_hub_panel.tscn": 1,
	"scenes/ui/interactive_tutorial.tscn": 2,
	"scenes/ui/leaderboard_panel.tscn": 5,
	"scenes/ui/level_info_panel.tscn": 1,
	"scenes/ui/level_select_panel.tscn": 1,
	"scenes/ui/modification_panel.tscn": 1,
	"scenes/ui/phase_instrument_panel.tscn": 8,
	"scenes/ui/phase_instrument_selector.tscn": 1,
	"scenes/ui/player_spawn_hud.tscn": 2,
	"scenes/ui/reinforcement_panel.tscn": 1,
	"scenes/ui/resource_bar.tscn": 1,
	"scenes/ui/resource_info_panel.tscn": 1,
	"scenes/ui/save_slot_manager.tscn": 1,
	"scenes/ui/settings_panel.tscn": 3,
	"scenes/ui/store_panel.tscn": 11,
	"scenes/ui/tutorial_overlay.tscn": 3,
	"scenes/ui/upgrade_panel.tscn": 12,
}

static func fix_all() -> void:
	print("开始修复 .tscn 文件的 load_steps...")

	var file = FileAccess.open("res://tools/fix_tscn_load_steps.gd", FileAccess.READ)
	var fixed_count := 0
	var skipped_count := 0

	for file_path in FIX_PATTERNS:
		var expected_steps = FIX_PATTERNS[file_path]
		var full_path = "res://" + file_path

		var tscn_file = FileAccess.open(full_path, FileAccess.READ)
		if not tscn_file:
			print("跳过: %s (无法打开)" % file_path)
			skipped_count += 1
			continue

		var content = tscn_file.get_as_text()
		tscn_file.close()

		# 查找并替换 load_steps
		var regex = RegEx.new()
		regex.compile("load_steps=\\d+")
		var result = regex.search(content)

		if result:
			var new_content = regex.sub(content, "load_steps=" + str(expected_steps))

			# 写回文件
			var output = FileAccess.open(full_path, FileAccess.WRITE)
			if output:
				output.store_string(new_content)
				output.close()
				print("修复: %s (load_steps=%d)" % [file_path, expected_steps])
				fixed_count += 1
			else:
				print("失败: %s (无法写入)" % file_path)
		else:
			print("跳过: %s (未找到 load_steps)" % file_path)
			skipped_count += 1

	print("\n修复完成！")
	print("已修复: %d 个文件" % fixed_count)
	print("跳过: %d 个文件" % skipped_count)

## 如果在编辑器中运行
func _init() -> void:
	fix_all()
