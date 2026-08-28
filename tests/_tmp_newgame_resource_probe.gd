extends SceneTree
## tests/_tmp_newgame_resource_probe.gd — 新游戏开局资源探针（只读审计，临时脚本）
##
## 目的：拿到 start_new_game() 后的真实开局状态（资源/实例/槽位/符文/图纸），
##       作为"新开始要有合理的资源"任务的现状基线。
## 安全：挑空存档槽执行（全占用则拒绝启动）；结束删除探针槽文件并恢复原槽。
## 用法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_newgame_resource_probe.gd

var _phase := 0
var _waited := 0
var _orig_slot := -1
var _probe_slot := -1

func _process(_delta: float) -> bool:
	match _phase:
		0:
			_waited += 1
			var sm: Node = root.get_node_or_null("/root/SaveManager")
			if sm == null:
				if _waited > 600:
					print("[PROBE] FAIL: SaveManager 未就绪")
					return true
				return false
			# 挑空槽（绝不触碰非空槽）
			var slot := -1
			for info in sm.get_slot_info():
				if not bool(info.get("exists", true)):
					slot = int(info.get("slot", 0))
					break
			if slot <= 0:
				print("[PROBE] REFUSE: 无空存档槽——拒绝执行以保护真实进度")
				return true
			_orig_slot = int(sm.get_slot())
			_probe_slot = slot
			sm.set_slot(slot)
			print("[PROBE] 使用空槽 %d（原槽 %d）执行 start_new_game" % [slot, _orig_slot])
			sm.start_new_game()
			_phase = 1
			_waited = 0
		1:
			_waited += 1
			# 等待 deferred 管理器重置批次（每帧4个）+ 信号落定
			if _waited < 45:
				return false
			_report()
			_cleanup()
			return true
	return false

func _report() -> void:
	var brm: Node = root.get_node_or_null("/root/BasicResourceManager")
	if brm != null and brm.has_method("get_all_totals"):
		print("[PROBE] RESOURCES = %s" % JSON.stringify(brm.get_all_totals()))
	var ir: Node = root.get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_all_instance_ids"):
		print("[PROBE] INSTANCES = %s" % str(ir.get_all_instance_ids()))
	var pim: Node = root.get_node_or_null("/root/PhaseInstrumentManager")
	if pim != null:
		if pim.has_method("get_slot_card_ids"):
			print("[PROBE] SLOTS = %s" % JSON.stringify(pim.get_slot_card_ids()))
		if pim.has_method("get_owned_runes"):
			print("[PROBE] RUNES = %s" % str(pim.get_owned_runes()))
		if pim.has_method("get_phase_field_level"):
			print("[PROBE] PHASE_FIELD_LEVEL = %d" % int(pim.get_phase_field_level()))
		if pim.has_method("get_unspent_phase_field_points"):
			print("[PROBE] UNSPENT_PFP = %d" % int(pim.get_unspent_phase_field_points()))
	var bag: Node = root.get_node_or_null("/root/IntelItemBag")
	if bag != null and bag.has_method("get_all_inventory"):
		var inv: Dictionary = bag.get_all_inventory()
		print("[PROBE] BAG_TYPES = %d" % inv.size())
		print("[PROBE] BAG_TOTAL = %d" % int(bag.get_total_count()))
		var evo := 0
		var mod := 0
		for k in inv.keys():
			if String(k).begins_with("blueprint_evol_"):
				evo += 1
			elif String(k).begins_with("blueprint_"):
				mod += 1
		print("[PROBE] BAG_MOD_BLUEPRINTS = %d  BAG_EVO_BLUEPRINTS = %d" % [mod, evo])
	var pmsm: Node = root.get_node_or_null("/root/PhaseMasterSkillManager")
	if pmsm != null and pmsm.has_method("get_bonus_points"):
		print("[PROBE] PM_SKILL_BONUS_POINTS = %d" % int(pmsm.get_bonus_points()))

func _cleanup() -> void:
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	if sm != null and _probe_slot > 0:
		for suffix in ["", "_backup", "_temp"]:
			var p := "user://save_slot_%d%s.json" % [_probe_slot, suffix]
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		if _orig_slot > 0:
			sm.set_slot(_orig_slot)
	print("[PROBE] DONE（探针槽文件已清理，槽位已恢复 %d）" % _orig_slot)
