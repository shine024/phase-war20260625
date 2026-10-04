extends Node
## v6.42 实机探针：v6.39 指路标跨步堆积复现/验收。
## 实机主诉（截图）：基地同时挂 3 条「下一步」指路标（符文/制造/势力），且点了
## 指向的工位按钮提示也不自动关——消散链失效跨步堆积。
## 假设：show_step_pointer 同帧"queue_free 旧宿主 + add 同名新宿主"，新宿主撞名被
## Godot 改名 @TutorialStepPointer@N → 下次精确名 find_children 永远找不到=永不消散。
## 流程（真实链，truck_base._on_tutorial_pointer_requested 消费）：
##   S1 RUNES 等待亮标 → S2 切 EVOLUTION 亮标 → S3 切 FACTION_REP 亮标 →
##   S4 notify_surface_opened("faction")（=点了电台工位）→ 各阶段转储宿主名与计数。
## 跑法：GODOT --path . res://tests/_tmp_v642_pointer_probe.tscn --rendering-driver opengl3
## 截图落 res://.godot/v642_probe_pointer.png；退出前还原 TPM 内存态（不写存档）。

const TRUCK_SCENE := "res://scenes/bunker/truck_base.tscn"
const TutorialSpotlight = preload("res://scripts/ui/tutorial_spotlight.gd")

var _orig_tpm := {}

func _ready() -> void:
	var tpm := get_node("/root/TutorialProgressionManager")
	_orig_tpm = {
		"step": tpm.current_step,
		"chain": tpm.chain_paused,
		"pending": tpm.pending_close_surface,
		"completed": (tpm.completed_steps as Array).duplicate(),
	}
	GameConfig.get_default().feature_gates_enabled = false   # 探针开全部门（新档 evolution/faction 上锁会拦亮标）
	await get_tree().process_frame
	_force_waiting(tpm.TutorialStep.RUNES)
	var tb := (load(TRUCK_SCENE) as PackedScene).instantiate()
	tb.name = "ProbeTruckBase"
	get_tree().root.add_child(tb)
	await get_tree().process_frame
	get_tree().current_scene = tb
	await get_tree().process_frame

	print("\n[V642PROBE] ======== S1 RUNES 亮标 ========")
	_diag_resolve(tb, "backpack")
	tpm.tutorial_pointer_requested.emit(true)   # 真实链：complete_current_step 进等待同款
	await _settle()
	_dump_hosts(tb, "S1 RUNES")

	print("\n[V642PROBE] ======== S2 -> EVOLUTION 亮标 ========")
	tpm.current_step = tpm.TutorialStep.EVOLUTION
	tpm.tutorial_pointer_requested.emit(true)
	await _settle()
	_dump_hosts(tb, "S2 EVOLUTION")

	print("\n[V642PROBE] ======== S3 -> FACTION_REP 亮标 ========")
	tpm.current_step = tpm.TutorialStep.FACTION_REP
	tpm.tutorial_pointer_requested.emit(true)
	await _settle()
	_dump_hosts(tb, "S3 FACTION_REP")
	await RenderingServer.frame_post_draw
	_shot()   # S3 单标在场目检（v642_probe_pointer.png）

	print("\n[V642PROBE] ======== S4 点电台工位（notify faction）========")
	tpm.notify_surface_opened("faction")
	await _settle()
	_dump_hosts(tb, "S4 after notify")
	await RenderingServer.frame_post_draw
	_shot_s4()   # 点按钮后：标应消散、教程框接管（v642_probe_pointer_s4.png）
	tb.queue_free()
	await get_tree().process_frame
	tpm.current_step = _orig_tpm["step"]
	tpm.chain_paused = _orig_tpm["chain"]
	tpm.pending_close_surface = _orig_tpm["pending"]
	tpm.completed_steps = _orig_tpm["completed"]
	print("[V642PROBE] done")
	get_tree().quit()


func _force_waiting(step: int) -> void:
	var tpm := get_node("/root/TutorialProgressionManager")
	tpm.current_step = step
	tpm.chain_paused = true
	tpm.pending_close_surface = ""


func _settle() -> void:
	# 两帧：queue_free 帧末才生效，一帧后计数才是稳定态
	await get_tree().process_frame
	await get_tree().process_frame


func _dump_hosts(tb: Node, tag: String) -> void:
	var tpm := get_node("/root/TutorialProgressionManager")
	var hosts := tb.find_children("*TutorialStepPointer*", "Control", true, false)
	print("[V642PROBE] %s: pending_surface=%s pointer_hosts=%d" %
			[tag, String(tpm.get_pending_surface()), hosts.size()])
	for h in hosts:
		var sp := h.find_children("*", "Control", true, false)
		print("[V642PROBE]   host name=%s children=%d" % [String(h.name), sp.size()])


func _diag_resolve(tb: Node, surface: String) -> void:
	var target: Control = TutorialSpotlight.resolve_target(tb, surface)
	if target == null:
		print("[V642PROBE] diag %s: resolve=NULL" % surface)
	else:
		print("[V642PROBE] diag %s: target=%s visible=%s gate_locked=%s" %
				[surface, target.name, target.is_visible_in_tree(), target.get_meta("gate_locked", false)])


func _shot() -> void:
	# 同步截图：调用前调用方需 await RenderingServer.frame_post_draw；
	# 内部不得 await（调用方不 await 时协程拖到 queue_free 后=拍到清屏灰，v641 已踩）
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.godot/v642_probe_pointer.png")
	img.save_png(path)
	print("[V642PROBE] shot -> %s" % path)


func _shot_s4() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.godot/v642_probe_pointer_s4.png")
	img.save_png(path)
	print("[V642PROBE] shot -> %s" % path)
