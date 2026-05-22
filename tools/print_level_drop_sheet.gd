extends SceneTree
## 一次性打印：关卡 → 时代、BasicResources 结算预览、战后 DropTables 时代池
## 用法: Godot --headless --path . --script tools/print_level_drop_sheet.gd

const LevelEras = preload("res://data/level_eras.gd")
const BasicResources = preload("res://data/basic_resources.gd")


func _init() -> void:
	print("level,era,era_name,nano,alloy,crystal,energy_block,research_points,post_battle_pool")
	for lv in range(1, 101):
		var era: int = LevelEras.get_era(lv)
		var d: Dictionary = BasicResources.get_drops_for_level(lv)
		var en: String = LevelEras.get_era_name(era)
		var pool: String = _pool_label(era)
		print(
			"%d,%d,%s,%d,%d,%d,%d,%d,%s"
			% [
				lv,
				era,
				en,
				int(d.get(BasicResources.ID_NANO_MATERIALS, 0)),
				int(d.get(BasicResources.ID_ALLOY, 0)),
				int(d.get(BasicResources.ID_CRYSTAL, 0)),
				int(d.get(BasicResources.ID_ENERGY_BLOCK, 0)),
				int(d.get(BasicResources.ID_RESEARCH_POINTS, 0)),
				pool,
			]
		)
	quit()


func _pool_label(era: int) -> String:
	match era:
		0:
			return "ww1_common+保底"
		1:
			return "ww2_common+保底"
		2:
			return "cold_war_common+保底"
		3:
			return "modern_common+保底"
		4:
			return "near_future_common+保底"
		_:
			return "material_drops+保底"
