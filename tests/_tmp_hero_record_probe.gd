extends Node
## v6.14 诊断：相位师战胜利后遗物记录是否真的落账

func _ready() -> void:
	ManagerLazyLoader.ensure_loaded("bunker")
	var bm: Node = ManagerLazyLoader.get_manager("bunker")
	print("[rec] mgr_ok=", bm != null)
	var i := 0
	while get_node_or_null("/root/BunkerManager") == null and i < 120:
		await get_tree().process_frame
		i += 1
	print("[rec] root_resolved_after_frames=", i, " before=", str(bm.get_hero_fragments()))
	GameManager.current_level = 49
	var cfg: Dictionary = GameManager.check_phase_master_encounter()
	print("[rec] encounter_id=", str(cfg.get("id", "<空>")), " is_pm=", str(GameManager.is_phase_master_battle()))
	SignalBus.battle_ended.emit(true)
	await get_tree().create_timer(0.6).timeout
	print("[rec] after=", str(bm.get_hero_fragments()))
	get_tree().quit(0)
