extends Node
## 风暴复现探针 v2（窗口化）：复现「返回标题 → 快速点继续 / 双击继续」竞态。
## 监视节点 root 直挂，逐帧记录 current_scene 树内状态。

var _phase := 0

func _ready() -> void:
	print("[PROBE2] monitor ready")
	for i in range(5):
		await get_tree().process_frame

	# ── Phase 1: 切到标题屏，过渡期内(0.1s, _busy=true)立刻模拟「继续」→ 走裸切换兜底 ──
	print("[PROBE2] P1: change(title) then FAST continue (busy reentry bare path)")
	SceneTransition.change(get_tree(), "res://scenes/title_screen.tscn")
	for i in range(6):  # ~0.1s，仍在 t 的 0.18s 淡入期内
		await get_tree().process_frame
	_mimic_continue()
	await _watch(240, "P1")

	# ── Phase 2: 标题屏稳定后，双击「继续」(50ms 间隔两次完整 _on_continue 语义) ──
	print("[PROBE2] P2: change(title), settle, then DOUBLE continue")
	SceneTransition.change(get_tree(), "res://scenes/title_screen.tscn")
	for i in range(100):  # ~1.7s，过渡完全结束
		await get_tree().process_frame
	_mimic_continue()
	for i in range(3):  # ~50ms
		await get_tree().process_frame
	_mimic_continue()
	await _watch(240, "P2")

	print("[PROBE2] done, quitting")
	get_tree().quit()

func _mimic_continue() -> void:
	# 复刻 title_screen._on_continue 语义（load_game + level_auto_start_pending meta + change(main)）
	if SaveManager and SaveManager.has_method("load_game"):
		var ok: bool = SaveManager.load_game()
		print("[PROBE2] load_game -> %s" % str(ok))
	Engine.set_meta("level_auto_start_pending", true)
	SceneTransition.change(get_tree(), "res://scenes/main.tscn")

func _watch(frames: int, tag: String) -> void:
	var last_state := ""
	for i in range(frames):
		await get_tree().process_frame
		var cs := get_tree().current_scene
		var state: String
		if cs == null:
			state = "null busy=%s" % str(SceneTransition.is_busy())
		else:
			state = "%s %s" % [cs.name, "IN" if cs.is_inside_tree() else "OUT!!!"]
		if state != last_state:
			print("[PROBE2] %s f=%d current=%s" % [tag, i, state])
			last_state = state
	# 额外确认: 每帧末尾 deferred canary —— 记录 flush 时 current_scene 是否在树内
	var cs2 := get_tree().current_scene
	if cs2 != null and not cs2.is_inside_tree():
		print("[PROBE2] %s AFTER-WATCH current OUT_OF_TREE: %s" % [tag, cs2.name])
