extends SceneTree
func _initialize() -> void:
	_run()

func _run() -> void:
	var mll := root.get_node_or_null("ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("achievement")
	for i in range(8):
		await process_frame
	var m := root.get_node_or_null("AchievementManager")
	if m == null:
		print("NO AchievementManager")
		quit(1); return
	var all: Array = m.get_all_achievements() if m.has_method("get_all_achievements") else []
	print("total=", all.size())
	var no_name := 0
	for a in all:
		if String(a.get("name", "")).is_empty():
			no_name += 1
			if no_name <= 5:
				print("NO_NAME keys=", a.keys())
	print("no_name_count=", no_name)
	for idname in ["battle_first_win", "battle_wins_10", "battle_progress_25"]:
		var p: Dictionary = m.get_achievement_progress(idname)
		print(idname, " unlocked=", p.get("unlocked"), " cur=", p.get("current"), "/", p.get("max"))
	quit(0)
