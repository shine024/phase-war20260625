extends Node
## 批次③ Task 5 渐进曝光冒烟：
##  ① A4 三处实操门：装配（绿槽空）/符文（槽空）/加点（未分配）→ blocked；
##    装上/分配后 → 放行；门挡住时 complete_current_step 不推进
##  ② 按需点播：首战完成 → chain_paused；触达错面板不放行；触达对面板 → 放行+overlay_requested
##  ③ overlay 交互收敛：Background mouse_filter=IGNORE（底层可点击）；面板步框靠左锚定
##  ④ 越门保护：暂停链中 world_map 步只能由 world_map 触达面解锁
## 跑法：godot --headless --path . res://tests/_tmp_b3_t5_ftue_boot.tscn

var _fails: Array[String] = []
var _pass_log: Array[String] = []


func _ready() -> void:
	await _run()
	for p in _pass_log:
		print("[T5Ftue] PASS: " + p)
	for f in _fails:
		printerr("[T5Ftue] FAIL: " + f)
	print("[T5Ftue] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES"))
	await _wait(5)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _run() -> void:
	var tm: Node = get_node_or_null("/root/TutorialProgressionManager")
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if tm == null or pim == null:
		_fails.append("管理器缺失 tm=%s pim=%s" % [tm != null, pim != null])
		return
	var orig_step := int(tm.get("current_step"))
	var orig_paused := bool(tm.get("chain_paused"))

	# ── ① 实操门 ──
	# 装配门：绿槽 loadouts 空 → blocked
	pim.set("_loadouts_cache", [])
	pim.set("_loadouts_dirty", false)
	tm.set("current_step", 3)   # PHASE_INSTRUMENT
	if bool(tm.call("_step_gate_blocked", 3)):
		_pass_log.append("① 装配门：绿槽空 → 拦")
	else:
		_fails.append("① 装配门：绿槽空未拦")
	# 门挡推进（保持空载状态验证 complete 不跳步）
	var before := int(tm.get("current_step"))
	tm.call("complete_current_step")
	if int(tm.get("current_step")) == before:
		_pass_log.append("① 门挡推进：complete_current_step 未跳步")
	else:
		_fails.append("① 门挡推进失败：步被推进")
	pim.set("_loadouts_cache", [{"card_id": "ww1_mauser"}])
	if not bool(tm.call("_step_gate_blocked", 3)):
		_pass_log.append("① 装配门：已装配 → 放行")
	else:
		_fails.append("① 装配门：已装配仍拦")
	# 符文门
	var empty_slots: Array = [null, null, null, null, null, null]
	pim.set("_rune_slots", empty_slots)
	tm.set("current_step", 6)   # RUNES
	if bool(tm.call("_step_gate_blocked", 6)):
		_pass_log.append("① 符文门：槽空 → 拦")
	else:
		_fails.append("① 符文门：槽空未拦")
	var has_rune: Array = empty_slots.duplicate()
	has_rune[0] = "rune_test"
	pim.set("_rune_slots", has_rune)
	if not bool(tm.call("_step_gate_blocked", 6)):
		_pass_log.append("① 符文门：已装符文 → 放行")
	else:
		_fails.append("① 符文门：已装仍拦")
	# 加点门
	pim.set("phase_field_allocations", {})
	tm.set("current_step", 12)   # PHASE_FIELD_POINTS
	if bool(tm.call("_step_gate_blocked", 12)):
		_pass_log.append("① 加点门：未分配 → 拦")
	else:
		_fails.append("① 加点门：未分配未拦")
	pim.set("phase_field_allocations", {"atk_pct": 1})
	if not bool(tm.call("_step_gate_blocked", 12)):
		_pass_log.append("① 加点门：已分配 → 放行")
	else:
		_fails.append("① 加点门：已分配仍拦")

	# ── ② 按需点播链 ──
	tm.set("current_step", 7)   # FIRST_BATTLE
	tm.set("chain_paused", false)
	pim.set("_loadouts_cache", [{"card_id": "ww1_mauser"}])   # 保门放行
	tm.call("complete_current_step")
	if int(tm.get("current_step")) == 14 and bool(tm.get("chain_paused")):
		_pass_log.append("② 首战完成 → TRUCK_BASE + 链暂停")
	else:
		_fails.append("② 链暂停未生效 step=%s paused=%s" % [tm.get("current_step"), tm.get("chain_paused")])
	var fired := {"n": 0}
	tm.overlay_requested.connect(func() -> void: fired["n"] += 1)
	tm.call("notify_surface_opened", "growth")   # 错面板
	if bool(tm.get("chain_paused")) and fired["n"] == 0:
		_pass_log.append("② 触达错面板不放行")
	else:
		_fails.append("② 错面板误放行 paused=%s fired=%d" % [tm.get("chain_paused"), fired["n"]])
	tm.call("notify_surface_opened", "truck_base")   # 对面板
	if not bool(tm.get("chain_paused")) and fired["n"] == 1:
		_pass_log.append("② 触达对面板 → 放行 + overlay_requested")
	else:
		_fails.append("② 对面板未放行 paused=%s fired=%d" % [tm.get("chain_paused"), fired["n"]])

	# ── ③ overlay 交互收敛 ──
	tm.set("current_step", 2)   # CARD_COLLECTION（面板步 → 框靠左）
	var overlay: Node = (load("res://scenes/ui/tutorial_overlay.tscn") as PackedScene).instantiate()
	add_child(overlay)
	await _wait(3)
	var bg: ColorRect = overlay.get_node_or_null("Background")
	if bg != null and bg.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_pass_log.append("③ Background 放行底层点击（IGNORE）")
	else:
		_fails.append("③ Background mouse_filter=%s（应 IGNORE）" % (bg.mouse_filter if bg else "null"))
	var box: PanelContainer = overlay.get_node_or_null("TutorialBox")
	if box != null and absf(box.anchor_left - 0.01) < 0.001 and box.anchor_right <= 0.31:
		_pass_log.append("③ 面板步导航框靠左锚定")
	else:
		_fails.append("③ 导航框未靠左 anchor_left=%s" % (box.anchor_left if box else "null"))
	overlay.queue_free()
	await _wait(2)
	tm.set("current_step", 1)   # INTRO（居中）
	var overlay2: Node = (load("res://scenes/ui/tutorial_overlay.tscn") as PackedScene).instantiate()
	add_child(overlay2)
	await _wait(3)
	var box2: PanelContainer = overlay2.get_node_or_null("TutorialBox")
	if box2 != null and absf(box2.anchor_left - 0.5) < 0.001:
		_pass_log.append("③ 欢迎步导航框居中")
	else:
		_fails.append("③ 欢迎步未居中 anchor_left=%s" % (box2.anchor_left if box2 else "null"))
	overlay2.queue_free()

	# ── ④ WORLD_MAP 步只认 world_map 触达面 ──
	tm.set("current_step", 11)   # WORLD_MAP
	tm.set("chain_paused", true)
	tm.call("notify_surface_opened", "store")
	if bool(tm.get("chain_paused")):
		_pass_log.append("④ WORLD_MAP 步不认 store 触达")
	else:
		_fails.append("④ store 误解锁 WORLD_MAP 步")
	tm.call("notify_surface_opened", "world_map")
	if not bool(tm.get("chain_paused")):
		_pass_log.append("④ world_map 触达解锁 OK")
	else:
		_fails.append("④ world_map 触达未解锁")

	# 还原
	tm.set("current_step", orig_step)
	tm.set("chain_paused", orig_paused)
