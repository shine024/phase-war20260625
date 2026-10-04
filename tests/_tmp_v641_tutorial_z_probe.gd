extends Node
## v6.41 实机探针：符文教程步 × 背包面板已开——教程框 z 序与"针对当前窗口"复现/验收。
## 主诉（2026-10-04 实机截图）：符文步提示框被背包面板盖住（卡格切割文字、按钮点不到），
## 且提示弹出时背包停在战斗卡页，没有针对当前打开的窗口。
##
## 真实渲染（窗口化，非 headless）跑两条真链：
##   P1 truck_base：强制 TPM 到 RUNES 点播 → _open_panel("backpack")（卡牌展示墙同链）
##   P2 main：      同态 → _on_backpack_pressed()（底栏卡仓同链）
## 每相转储：overlay 与面板层的树序关系 / 背包当前页 / 教程框与面板全局矩形 + 截图。
## 跑法：GODOT --path . res://tests/_tmp_v641_tutorial_z_probe.tscn --rendering-driver opengl3
## 截图落 res://.godot/v641_probe_{truck,main}.png（.godot 已 gitignore）。
## 探针只操纵 autoload 内存态并在退出前还原，不写存档（quit() 不触发 WM_CLOSE 自动存档）。

const TRUCK_SCENE := "res://scenes/bunker/truck_base.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"

var _orig_tpm := {}

func _ready() -> void:
	_save_tpm_state()
	await _run_truck_phase()
	await _run_main_phase()
	_restore_tpm_state()
	print("[V641PROBE] done")
	get_tree().quit()


func _save_tpm_state() -> void:
	var tpm := get_node("/root/TutorialProgressionManager")
	_orig_tpm = {
		"step": tpm.current_step,
		"chain": tpm.chain_paused,
		"pending": tpm.pending_close_surface,
		"completed": (tpm.completed_steps as Array).duplicate(),
	}
	# 时间线追踪：谁在何时拉 overlay / 步号何时变
	if not tpm.overlay_requested.is_connected(_on_ov_req):
		tpm.overlay_requested.connect(_on_ov_req)
	if not tpm.tutorial_step_changed.is_connected(_on_step_chg):
		tpm.tutorial_step_changed.connect(_on_step_chg)


func _on_ov_req() -> void:
	var tpm := get_node("/root/TutorialProgressionManager")
	print("[V641PROBE] >>> overlay_requested fired at frame=%d step=%d chain=%s" %
			[Engine.get_process_frames(), int(tpm.current_step), tpm.chain_paused])


func _on_step_chg(s: int) -> void:
	print("[V641PROBE] >>> tutorial_step_changed -> %d at frame=%d" % [s, Engine.get_process_frames()])


func _restore_tpm_state() -> void:
	var tpm := get_node("/root/TutorialProgressionManager")
	tpm.current_step = _orig_tpm["step"]
	tpm.chain_paused = _orig_tpm["chain"]
	tpm.pending_close_surface = _orig_tpm["pending"]
	tpm.completed_steps = _orig_tpm["completed"]


func _force_runes_waiting() -> void:
	var tpm := get_node("/root/TutorialProgressionManager")
	print("[V641PROBE] TPM before force: step=%d chain=%s (save 原始态)" % [int(tpm.current_step), tpm.chain_paused])
	tpm.current_step = tpm.TutorialStep.RUNES
	tpm.chain_paused = true
	tpm.pending_close_surface = ""
	print("[V641PROBE] TPM forced: step=RUNES(%d) chain_paused=true" % int(tpm.TutorialStep.RUNES))


# ── P1 基地场景 ────────────────────────────────────────────────────
func _run_truck_phase() -> void:
	print("\n[V641PROBE] ======== P1 truck_base ========")
	# 探针 _ready 落在树建立期：先让一帧再挂兄弟场景，防 "parent busy setting up children"
	await get_tree().process_frame
	_force_runes_waiting()   # 必须先于 add_child：否则基地自举（step=NONE 档）会先拉欢迎框
	var tb := (load(TRUCK_SCENE) as PackedScene).instantiate()
	tb.name = "ProbeTruckBase"
	get_tree().root.add_child(tb)
	await get_tree().process_frame
	get_tree().current_scene = tb
	await get_tree().process_frame
	_force_runes_waiting()
	tb._open_panel("backpack")   # 真实链：卡牌展示墙工位
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw

	var ov: Control = tb.get_node_or_null("TutorialOverlay")
	var embed: Control = tb._embed_layer
	var tpm := get_node("/root/TutorialProgressionManager")
	print("[V641PROBE] truck: TPM after _open_panel: step=%d chain=%s" % [int(tpm.current_step), tpm.chain_paused])
	if ov != null and "_current_content" in ov:
		print("[V641PROBE] truck: overlay content title=%s step_label=%s" % [
			str(ov._current_content.get("title", "")),
			str(ov.get_node_or_null("TutorialBox/Margin/VBox/StepLabel").text if ov.get_node_or_null("TutorialBox/Margin/VBox/StepLabel") else "")])
	print("[V641PROBE] truck root children order:")
	for i in tb.get_child_count():
		var c := tb.get_child(i)
		print("  [%d] %s (%s)" % [i, c.name, c.get_class()])
	if ov == null:
		print("[V641PROBE] !! truck: TutorialOverlay NOT summoned")
	else:
		var rel := "ABOVE" if ov.get_index() > embed.get_index() else "BELOW"
		print("[V641PROBE] truck: overlay idx=%d vs _embed_layer idx=%d -> overlay %s embed layer" \
				% [ov.get_index(), embed.get_index(), rel])
		var box: Control = ov.get_node_or_null("TutorialBox")
		if box != null:
			print("[V641PROBE] truck: TutorialBox global_rect=%s" % box.get_global_rect())
	_dump_backpack_panel(tb._embed_wrappers.get("backpack", {}).get("panel"), "truck")
	_shot("v641_probe_truck.png")
	tb.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# ── P2 主场景 ──────────────────────────────────────────────────────
func _run_main_phase() -> void:
	print("\n[V641PROBE] ======== P2 main ========")
	_force_runes_waiting()
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	main.name = "ProbeMain"
	get_tree().root.add_child(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().process_frame
	main._on_backpack_pressed()   # 真实链：底栏卡仓键
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw

	for layer_name in ["HudLayer", "PopupLayer", "InfoPanelLayer", "TutorialLayer"]:
		var layer := main.get_node_or_null(layer_name)
		if layer != null:
			print("[V641PROBE] main: %s layer=%d" % [layer_name, layer.layer])
	var ov_old: Control = main.get_node_or_null("HudLayer/TutorialOverlay")
	var ov_new: Control = main.get_node_or_null("TutorialLayer/TutorialOverlay")
	var ov: Control = ov_new if ov_new != null else ov_old
	if ov == null:
		print("[V641PROBE] !! main: TutorialOverlay NOT summoned")
	else:
		print("[V641PROBE] main: overlay hosted at %s" % ("TutorialLayer" if ov_new != null else "HudLayer"))
		var popup: CanvasLayer = main.get_node("PopupLayer")
		var host_layer: CanvasLayer = ov.get_parent()
		var rel := "ABOVE" if host_layer.layer > popup.layer else "BELOW"
		print("[V641PROBE] main: overlay host layer=%d vs PopupLayer=%d -> overlay %s popup panels" \
				% [host_layer.layer, popup.layer, rel])
		var box: Control = ov.get_node_or_null("TutorialBox")
		if box != null:
			print("[V641PROBE] main: TutorialBox global_rect=%s" % box.get_global_rect())
	var bp: Control = main.get_node_or_null("PopupLayer/BackpackOverlay")
	if bp != null:
		print("[V641PROBE] main: backpack_overlay.visible=%s" % bp.visible)
		_dump_backpack_panel(bp.find_child("BackpackPanel", true, false), "main")
	_shot("v641_probe_main.png")
	main.queue_free()
	await get_tree().process_frame


func _dump_backpack_panel(panel: Node, tag: String) -> void:
	if panel == null:
		print("[V641PROBE] %s: backpack panel NOT created" % tag)
		return
	var tab := -1
	var runes_tab := -2
	if "_tab_container" in panel and panel._tab_container != null:
		tab = int(panel._tab_container.current_tab)
		runes_tab = int(panel.TabIndex.RUNES)
	print("[V641PROBE] %s: backpack panel visible=%s current_tab=%d (RUNES=%d) -> %s" %
			[tag, panel.visible, tab, runes_tab,
			"RUNES TAB ✓" if tab == runes_tab else "NOT runes tab ✗"])
	if panel is Control:
		print("[V641PROBE] %s: BackpackPanel global_rect=%s" % [tag, panel.get_global_rect()])


func _shot(fname: String) -> void:
	# 调用前已 await frame_post_draw：纹理取当前帧，禁止内部再 await
	# （此前内部 await 且调用方未 await，协程拖到 queue_free 之后才拍=全灰清屏色）
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.godot/" + fname)
	img.save_png(path)
	print("[V641PROBE] shot -> %s" % path)
