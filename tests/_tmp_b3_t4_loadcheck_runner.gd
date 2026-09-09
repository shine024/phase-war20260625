extends Node
## Task 4 载入校验（autoload 就绪后）：28 个改动文件逐个 load
const FILES := [
	"data/default_cards.gd", "data/enemy_blueprints.gd", "data/enemy_phase_equipment.gd",
	"data/intel_evolution_branches.gd", "data/intel_manual_items.gd",
	"data/leaderboard_definitions.gd", "data/phase_instruments.gd",
	"data/unit_lineage_config.gd", "data/bunker_room_defs.gd",
	"scenes/ui/bottom_instrument_bar.gd", "scenes/ui/store_panel.gd",
	"scenes/ui/card_info_panel.gd", "scenes/ui/help_panel.gd", "scenes/ui/growth_panel.gd",
	"scenes/ui/leaderboard/leaderboard_panel.gd", "scenes/ui/buff_fold_card.gd",
	"scenes/ui/intelligence_hub_panel.gd", "scenes/ui/unit_progression_detail_view.gd",
	"scripts/progression/evolution_graph_builder.gd", "scripts/systems/intel_discovery_manager.gd",
	"scripts/systems/intel_manual.gd", "managers/evolution/card_evolution_manager.gd",
	"managers/manager_lazy_loader.gd", "managers/phase_instrument_manager.gd",
	"scenes/bunker/bunker_main.gd", "scenes/world_map.gd",
	"managers/bunker_manager.gd", "scenes/bunker/ui/bunker_room_panel.gd",
]
func _ready() -> void:
	var bad: Array[String] = []
	for f in FILES:
		var s = load("res://" + f)
		if s == null or not (s is Script):
			bad.append(f)
	if bad.is_empty():
		print("[T4Load] %d/%d OK" % [FILES.size(), FILES.size()])
	else:
		for f in bad:
			printerr("[T4Load] FAIL: " + f)
	get_tree().quit(0 if bad.is_empty() else 1)
