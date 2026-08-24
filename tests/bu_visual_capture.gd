extends Node
## BU（战斗界面美化）视觉验收截图——窗口渲染 + 自动退出，仅本机调试用。
## 用法：godot --path . res://tests/bu_visual_capture.tscn
## 产出：.godot/bu_shot_1_static.png（战前静态 UI）
##       .godot/bu_shot_2_battle.png（战斗中，含 ensure 敌方基地验证红光环）
##       .godot/bu_shot_3_deploy.png（部署待选高亮）
##       .godot/bu_shot_4_drawer.png（功能抽屉展开）
## v3：窗口尺寸诊断（v1/v2 均为 1024×768 异常）；探针路径修正（MenuBtn 在 Margin/HBox 下、
##     SlotHighlightLayer 通配）；战斗态补 ensure_enemy_phase_driver({}) 渲染敌方红光环
##     （普通关卡无相位师配置，正常游戏链路不会生成敌方基地——此处仅为视觉验证）。

const SHOT_DIR: String = "res://.godot"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[win] 期望1280x720 | before=", DisplayServer.window_get_size(),
		" scale=", DisplayServer.screen_get_scale(),
		" content_scale_factor=", get_window().content_scale_factor)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().process_frame
	print("[win] after window_set_size=", DisplayServer.window_get_size(),
		" window.size=", get_window().size, " viewport=", get_viewport().size)
	if get_viewport().size != Vector2i(1280, 720):
		get_window().size = Vector2i(1280, 720)
		await get_tree().process_frame
		print("[win] after window.size= ", get_window().size, " viewport=", get_viewport().size)

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	if main_scene == null:
		push_error("[BuCapture] main.tscn 加载失败")
		get_tree().quit(1)
		return
	var main: Node = main_scene.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	# 1) 战前静态：悬浮卡 + 顶部胶囊 + 地面着色 + 双基地光环 + 暗角
	await get_tree().create_timer(3.5).timeout
	await _capture("bu_shot_1_static.png")
	_probe(main, "static")

	# 2) 开战（与玩家按 Enter/点"2战"同链路）
	if main.has_method("_on_start_battle"):
		main._on_start_battle()
	await get_tree().create_timer(2.0).timeout
	# 普通关卡无相位师 → 手动 ensure 一个敌方基地（空配置全默认值）验证红光环视觉
	var bfs: Array = main.find_children("Battlefield", "Node2D", true, false)
	if not bfs.is_empty() and bfs[0].has_method("ensure_enemy_phase_driver"):
		bfs[0].ensure_enemy_phase_driver({})
	await get_tree().create_timer(4.0).timeout
	await _capture("bu_shot_2_battle.png")
	_probe(main, "battle")

	# 3) 部署待选高亮（与按数字键 1 同链路；绿槽无卡时强制 pending 验证高亮层视觉本身）
	var bib: Node = main.get_node_or_null("HudLayer/BattleBottomBar/BottomInstrumentBar")
	var deploy_ok: bool = false
	if bib != null and bib.has_method("begin_deploy_from_slot_index"):
		deploy_ok = bib.begin_deploy_from_slot_index(1)
	print("[deploy] begin_deploy(1)=", deploy_ok,
		" pending='", BattleInputState.pending_deploy_platform_card_id, "'")
	if BattleInputState.pending_deploy_platform_card_id.is_empty():
		BattleInputState.pending_deploy_platform_card_id = "debug_visual_check"
		print("[deploy] 绿槽无卡 → 强制 pending 验证高亮层")
	await get_tree().create_timer(1.2).timeout
	await _capture("bu_shot_3_deploy.png")
	_probe_deploy(main)
	# 取消部署（右键语义 = 清 pending）
	var bis: Node = get_node_or_null("/root/BattleInputState")
	if bis != null:
		bis.clear_all_pending()

	# 4) 功能抽屉展开
	var bfb: Node = main.get_node_or_null("HudLayer/BattleBottomBar/BottomFunctionBar")
	if bfb != null and bfb.has_method("set_drawer_open"):
		bfb.set_drawer_open(true, false)
	await get_tree().create_timer(0.8).timeout
	await _capture("bu_shot_4_drawer.png")

	print("[BuCapture] DONE 4 shots -> ", SHOT_DIR)
	get_tree().quit(0)

func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		push_error("[BuCapture] 截图为空: " + file_name)
		return
	img.save_png(SHOT_DIR + "/" + file_name)
	print("[BuCapture] saved ", file_name, " size=", img.get_size())

## 结构探针：验证 BU 视觉层节点是否真实存在/可见（不依赖人眼看低 alpha 效果）
func _probe(main: Node, phase: String) -> void:
	print("=== [probe:", phase, "] 视口=", get_viewport().size, " ===")
	var vig: Node = main.get_node_or_null("VignetteLayer/Vignette")
	print("[probe] 暗角 VignetteLayer/Vignette: ", "存在" if vig else "缺失",
		" visible=", vig.visible if vig else "-")
	var bfs: Array = main.find_children("Battlefield", "Node2D", true, false)
	if bfs.is_empty():
		print("[probe] Battlefield 未找到")
		return
	var bf: Node = bfs[0]
	var amb: Node = bf.get_node_or_null("BattlefieldAmbience")
	if amb == null:
		print("[probe] 地面着色 BattlefieldAmbience: 缺失")
	else:
		var vis_children: Array = []
		for c in amb.get_children():
			vis_children.append("%s(v=%s)" % [c.name, c.visible])
		print("[probe] 地面着色 BattlefieldAmbience: visible=", amb.visible,
			" z=", amb.z_index, " 子节点=", vis_children)
	var pd: Node = bf.get_node_or_null("PhaseFieldDriver")
	if pd == null:
		print("[probe] 我方基地 PhaseFieldDriver: 缺失")
	else:
		var aura: Node = pd.get_node_or_null("BaseAura")
		print("[probe] 我方基地: pos=", pd.position, " visible=", pd.visible,
			" BaseAura=", "有(v=%s)" % aura.visible if aura else "无")
	var ed: Node = bf.get_node_or_null("EnemyPhaseFieldDriver")
	if ed == null:
		print("[probe] 敌方基地: 无（", phase, " 阶段）")
	else:
		var ea: Node = ed.get_node_or_null("BaseAura")
		print("[probe] 敌方基地: pos=", ed.position, " BaseAura=", "有(v=%s)" % ea.visible if ea else "无")
	var hls: Array = bf.find_children("SlotHighlight*", "Node2D", true, false)
	print("[probe] 部署高亮 SlotHighlightLayer: ", "存在 visible=%s" % hls[0].visible if not hls.is_empty() else "缺失")
	var bib: Node = main.get_node_or_null("HudLayer/BattleBottomBar/BottomInstrumentBar")
	var menus: Array = [] if bib == null else bib.find_children("MenuBtn", "Button", true, false)
	var erows: Array = [] if bib == null else bib.find_children("EnergyRow*", "", true, false)
	print("[probe] 菜单按钮 MenuBtn: ", "存在" if not menus.is_empty() else "缺失",
		" 能量行: ", "存在" if not erows.is_empty() else "缺失",
		" 能量=", EnergyManager.get_current() if EnergyManager else "-",
		"/", EnergyManager.get_max() if EnergyManager else "-")

## 部署态探针：高亮层是否真亮了（visible/alpha/槽心数量）
func _probe_deploy(main: Node) -> void:
	var bfs: Array = main.find_children("Battlefield", "Node2D", true, false)
	if bfs.is_empty():
		return
	var bf: Node = bfs[0]
	var hl: Node = bf.get_node_or_null("BattleSlotGrid/SlotHighlightLayer")
	if hl == null:
		var hls: Array = bf.find_children("SlotHighlight*", "", true, false)
		hl = hls[0] if not hls.is_empty() else null
	if hl == null:
		print("[probe:deploy] 高亮层: 缺失")
	else:
		print("[probe:deploy] 高亮层: visible=", hl.visible, " alpha=", hl.modulate.a)
	var grid: Node = bf.get_node_or_null("BattleSlotGrid")
	if grid != null and "player_slot_centers" in grid:
		print("[probe:deploy] 我方槽心数=", grid.player_slot_centers.size())
