extends Node
## v5 教程整合批实机探针（窗口化，真实渲染）：
##   拍1 truck_base 新档欢迎框（瘦身文案+170半高）
##   拍2 装配步聚光（spotlight_key=backpack 热区，用户认可的闪光提示）
##   拍3 点播段指路标（ENHANCEMENT 等待=通讯架工位，0.30 柔和档）
##   拍4 WORLD_MAP 点播步弹框（断链修复验证：框必须弹在 world_map 场景里）
## 铁律：TPM 状态先于场景 add_child 设置（v6.41 探针教训①）；截图 await 帧后取（②）。
## 跑法：godot --path . res://tests/_tmp_v5_tutorial_probe.tscn（非 headless）
## 出图：.godot/v5_shots/*.png

const SHOT_DIR := "user://../../.godot/v5_shots"  # 相对 user:// 解析到项目根旁——改用绝对

var _truck: Node = null
var _map: Node = null
var _shot_idx := 0


func _ready() -> void:
	var dir := ProjectSettings.globalize_path("res://.godot/v5_shots")
	DirAccess.make_dir_recursive_absolute(dir)
	set_process(false)
	_run(dir)


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot_idx += 1
	var path := dir.path_join("%02d_%s.png" % [_shot_idx, name])
	img.save_png(path)
	print("[V5PROBE] shot -> ", path)


func _set_fresh(step: int, paused: bool) -> void:
	var tpm: Node = get_node("/root/TutorialProgressionManager")
	tpm.current_step = step
	tpm.completed_steps = []
	tpm.chain_paused = paused
	tpm.pending_close_surface = ""
	tpm.seen_surfaces = {}


func _run(dir: String) -> void:
	# root 忙窗（本节点 _ready 期间 add_child 会被拒——v6.20 同款踩坑）：推一帧再挂场景
	await get_tree().process_frame
	# ── 拍1：新档欢迎框（truck_base 自举 INTRO_WELCOME）──
	_set_fresh(0, false)  # 先于 add_child（铁律①）
	_truck = load("res://scenes/bunker/truck_base.tscn").instantiate()
	get_tree().root.add_child(_truck)
	for _i in 30:
		await get_tree().process_frame
	await _shot(dir, "welcome_box")

	# ── 拍2：装配步 + 聚光（点「启程」→ PHASE_INSTRUMENT 连讲框 + backpack 热区聚光）──
	var next_btn: Button = _truck.get_node_or_null("TutorialLayer/TutorialOverlay/TutorialBox/Margin/VBox/ButtonRow/NextButton")
	if next_btn == null:
		print("[V5PROBE] FAIL: welcome box NextButton 未找到（欢迎框未弹出）")
		_finish(dir, 1)
		return
	next_btn.pressed.emit()
	for _i in 20:
		await get_tree().process_frame
	await _shot(dir, "assembly_spotlight")

	# ── 拍3：点播段指路标（模拟首战后 ENHANCEMENT 等待——通讯架工位）──
	var tpm: Node = get_node("/root/TutorialProgressionManager")
	_set_fresh(int(tpm.TutorialStep.ENHANCEMENT), true)
	if _truck.has_method("_maybe_spawn_tutorial_pointer"):
		_truck._maybe_spawn_tutorial_pointer()
	for _i in 20:
		await get_tree().process_frame
	await _shot(dir, "pointer_growth_waiting")

	# ── 拍4：ENHANCEMENT 点播命中帧——教程框弹出 + skill_tree 气泡静默让位（v5 通道整合）──
	FeatureUnlockPopup._seen_cache.erase("skill_tree")  # 可重跑：擦键后由让位口重新消费
	PhaseMasterSkillHost.open(get_tree(), true)
	for _i in 20:
		await get_tree().process_frame
	await _shot(dir, "skill_tree_step_no_bubble")
	var fup_nodes: Array = get_tree().root.find_children("FeatureUnlockPopup*", "Control", false, false)
	var enh_box: Node = _truck.get_node_or_null("TutorialLayer/TutorialOverlay")
	print("[V5PROBE] ENHANCEMENT 帧教程框=", enh_box != null,
		" | FUP气泡数=", fup_nodes.size(),
		" | skill_tree已让位=", FeatureUnlockPopup._already_seen("skill_tree"))
	# 关技能树，让画面回基地再进下一拍
	var host_node: Node = get_tree().root.get_node_or_null("PhaseMasterSkillHost")
	if host_node != null and host_node.has_method("close"):
		host_node.close()
	for _i in 10:
		await get_tree().process_frame

	# ── 拍5：WORLD_MAP 点播步弹框（断链修复——框弹在 world_map 场景）
	_set_fresh(int(tpm.TutorialStep.WORLD_MAP), true)
	_truck.queue_free()
	_truck = null
	await get_tree().process_frame
	await get_tree().process_frame
	_map = load("res://scenes/world_map.tscn").instantiate()
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	for _i in 40:
		await get_tree().process_frame
	await _shot(dir, "world_map_box")
	var map_box: Node = _map.get_node_or_null("TutorialLayer/TutorialOverlay")
	print("[V5PROBE] world_map TutorialOverlay 存在=", map_box != null,
		" | chain_paused=", get_node("/root/TutorialProgressionManager").chain_paused)
	_finish(dir, 0)


func _finish(_dir: String, code: int) -> void:
	print("[V5PROBE] done code=", code)
	get_tree().quit(code)
