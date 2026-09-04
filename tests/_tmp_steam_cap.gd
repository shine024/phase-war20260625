extends Node
## Steam 商店素材采集编排器（临时工具）。
## 由 agent_tools run.scene_headless 驱动加载；绝不 change_scene（会释放驱动器），
## 场景挂载用 root.add_child + current_scene 赋值。
## 模式经配置文件 .godot/steam_cap_mode.txt（每行 `模式 [选项...]`）：
##   title / map / base / panel            —— UI 截图（可选 resize=1024×576）
##   battle                                —— AFK 自动战斗 + 战场 SubViewport 超采样截图
##   battle_long                           —— 同 battle，长待机（供 --write-movie 录制）
## 战斗超采样：battlefield 的 SubViewport 渲染目标独立于窗口可超到 1920×1080，
## 相机 zoom 1.5 恰好复刻 1280×720 设计取景——截出来的是真 1080p 战场（无 HUD）。

const SHOT_DIR := "res://_steam_assets/shots/"
const MODE_FILE := "res://.godot/steam_cap_mode.txt"  # 运行前由采集脚本写入

var _battle_ss_done := false


func _ready() -> void:
	var spec := "title"
	if FileAccess.file_exists(MODE_FILE):
		spec = FileAccess.get_file_as_string(MODE_FILE).strip_edges()
	var parts := spec.split(" ", false)
	var mode := parts[0]
	var opts := {}
	for i in range(1, parts.size()):
		var kv := parts[i].split("=")
		opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if opts.has("resize"):
		var w := get_window()
		w.borderless = true
		w.size = Vector2i(1024, 576)
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	print("[SteamCap] mode=", spec, " window=", get_window().size)
	_run(mode, opts)


func _run(mode: String, opts: Dictionary) -> void:
	await _wait_frames(20)
	match mode:
		"title":
			var ts: Node = _mount("res://scenes/title_screen.tscn")
			# 商店截图：隐藏开发调试按钮（正式上架前应给这些按钮加 debug 门控）
			for bn in ["SwitchSlotButton", "CombatCheckButton", "Arena3v3Button", "ReplayIntroButton"]:
				var b: Node = ts.get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/" + bn)
				if b != null:
					b.visible = false
			await _wait_frames(240)  # 标题背景/字体收敛
			_shot("01_title.png")
		"map":
			var main: Node = await _boot_main()
			await _wait_frames(30)
			main.call("_on_world_map")
			await _wait_frames(60)
			_shot("02_world_map.png")
		"battle":
			var main: Node = await _boot_main()
			# 开战但不立即部署：先把战场世界规范化（背景地面线/泳道），再自动部署
			var gm2: Node = get_node_or_null("/root/GameManager")
			gm2.call("set_current_level", 100)
			var setup2: RefCounted = main.get("_battle_setup")
			setup2.call("on_start_battle")
			await _wait_frames(45)
			_battle_supersample(main)
			# 规范化地面线：直跑子进程时 get_viewport_rect() 可能回退默认 648，
			# 重摆背景/泳道/出生点到已知 bottom（编辑器跑实测 853），部署在其后进行
			var bottom := float(opts.get("bottom", "853"))
			_normalize_battle_world(bottom)
			_apply_cam(_cam, float(opts.get("cy", "493")),
				float(opts.get("zoom", "1.5")), float(opts.get("cx", "640")))
			_auto_deploy(main)
			var n_shots := int(opts.get("shots", "6"))
			var interval := int(opts.get("gap", "420"))
			for i in n_shots:
				await _wait_frames(interval)
				_shot_battle("battle_%d.png" % (i + 1), main)
		"mods":
			var main4: Node = await _boot_main()
			await _wait_frames(30)
			main4.call("_toggle_overlay", main4.get("modification_overlay"), "modification")
			await _wait_frames(90)
			_shot("06_mods.png")
		"make":
			var main5: Node = await _boot_main()
			await _wait_frames(30)
			main5.call("_toggle_overlay", main5.get("evolution_overlay"), "evolution")
			await _wait_frames(90)
			_shot("07_make.png")
		"battle_long":
			var main2: Node = await _boot_main()
			await _start_manual_battle(main2, 100)
			_battle_supersample(main2)
			_apply_cam(_cam, 495.0)
			await _wait_frames(1800)  # Movie Maker：固定 30fps 下 ≈60s 实机战斗
		"base":
			_load_save()
			await _wait_frames(10)
			_mount("res://scenes/bunker/bunker_main.tscn")
			await _wait_frames(120)
			_shot("04_base.png")
		"battle_diag":
			await _run_diag()
		"panel":
			var main3: Node = await _boot_main()
			await _wait_frames(30)
			main3.call("_on_progression_pressed")
			await _wait_frames(60)
			_shot("05_panel.png")
	get_tree().quit(0)


## 战场 SubViewport 超采样：脱离容器自管尺寸 → 1920×1080，相机 zoom 1.5 复刻设计取景。
## 只在首次调用（后续战斗截图复用同一状态）。
func _battle_supersample(main: Node) -> void:
	if _battle_ss_done:
		return
	_battle_ss_done = true
	var vp: SubViewport = main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport") as SubViewport
	var container: SubViewportContainer = main.get_node_or_null("BattleContainer/SubViewportContainer") as SubViewportContainer
	if vp == null or container == null:
		push_warning("[SteamCap] supersample 节点缺失")
		return
	container.stretch = false  # 停止容器回写视口尺寸
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# 自建第二相机（make_current 后游戏相机/screen_shake 不再影响取景）
	var bf: Node = vp.get_node_or_null("Battlefield")
	_bf = bf
	_cam = Camera2D.new()
	_cam.name = "SteamCapCamera"
	bf.add_child(_cam)
	_cam.make_current()
	_apply_cam(_cam, 360.0)
	print("[SteamCap] supersample on: vp=", vp.size)


func _apply_cam(cam: Camera2D, cy: float, czoom: float = 1.5, cx: float = 640.0) -> void:
	cam.zoom = Vector2(czoom, czoom)  # 1920/czoom × 1080/czoom 世界像素视口
	cam.position = Vector2(cx, cy)
	cam.reset_smoothing()


var _cam: Camera2D = null
var _bf: Node = null


## 战场世界规范化：把背景地面线重摆到已知 bottom 并重算泳道/出生点/槽位。
## 必须在自动部署之前调用（部署的单位才会落在新泳道上）。
func _normalize_battle_world(bottom: float) -> void:
	if _bf == null:
		return
	_bf.set("_bg_pending_battle_bottom_y", bottom)
	var lvl_bg: Sprite2D = _bf.get_node_or_null("Level10Background") as Sprite2D
	if lvl_bg != null and lvl_bg.texture != null:
		_bf.call("_apply_background_texture", lvl_bg.texture)
		print("[SteamCap] world normalized: bottom=", bottom)
	else:
		push_warning("[SteamCap] normalize skipped: bg sprite/texture missing")


## 自动部署（从 _start_manual_battle 拆出，供 battle 模式在规范化后调用）
func _auto_deploy(main: Node) -> void:
	var bar: Node = main.get("bottom_instrument_bar")
	var btn: Button = bar.get("_auto_deploy_btn") if bar != null else null
	if btn != null:
		btn.button_pressed = true
		btn.pressed.emit()
		print("[SteamCap] auto deploy ON")


# ── 公共步骤 ────────────────────────────────────────────────

func _load_save() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		var ok: bool = sm.call("load_game")
		print("[SteamCap] load_game=", ok)


func _mount(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst


func _boot_main() -> Node:
	_load_save()
	await _wait_frames(10)
	var main: Node = _mount("res://scenes/main.tscn")
	await _wait_frames(150)  # 主场景 ready + deferred 批次管理器收敛
	# 清掉离线奖励弹窗（截图用：不领取、不写存档，纯视觉清除）
	# ⚠️ 只删 offline 弹窗本体——popup_layer 下还驻留地图/成长等 overlay 面板，全清会断链
	var popup: Node = main.get("popup_layer")
	if popup != null:
		for c in popup.get_children():
			var sc: Script = c.get_script()
			if sc != null and "offline" in String(sc.resource_path):
				c.queue_free()
				print("[SteamCap] offline dialog removed")
	return main


## 复刻世界地图自由选关：set_current_level + on_start_battle，再开战斗内自动部署
## （不走 AFK 推图链——AFK 的 push override 会被 AFK 推图进度钳制，实测被压到 L1/2）。
## 关卡进度全通（first_completion 1-100），自由选关合法。
func _start_manual_battle(main: Node, level: int) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	gm.call("set_current_level", level)
	var setup: RefCounted = main.get("_battle_setup")
	setup.call("on_start_battle")
	await _wait_frames(45)  # 战斗启动序列收敛
	var bar: Node = main.get("bottom_instrument_bar")
	var btn: Button = bar.get("_auto_deploy_btn") if bar != null else null
	if btn != null:
		btn.button_pressed = true
		btn.pressed.emit()
		print("[SteamCap] auto deploy ON")
	print("[SteamCap] manual battle started at L", level)


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(fname: String) -> void:
	# 同步直取视口纹理（agent_tools driver 同款；frame_post_draw 在离屏窗口不触发会挂起）
	var vp := get_tree().root.get_viewport()
	var tex := vp.get_texture()
	if tex == null:
		push_warning("[SteamCap] no viewport texture")
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		push_warning("[SteamCap] empty capture")
		return
	var err := img.save_png(SHOT_DIR + fname)
	print("[SteamCap] shot ", fname, " err=", err, " size=", img.get_size())


## 战斗截图专用：直取战场 SubViewport 的纹理（超采样真 1080p，无 HUD）
func _shot_battle(fname: String, main: Node) -> void:
	var vp: SubViewport = main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport") as SubViewport
	if vp == null:
		push_warning("[SteamCap] battle vp missing")
		return
	var img: Image = vp.get_texture().get_image()
	if img == null or img.is_empty():
		push_warning("[SteamCap] battle empty capture")
		return
	var err := img.save_png(SHOT_DIR + fname)
	print("[SteamCap] battle shot ", fname, " err=", err, " size=", img.get_size())


## battle_diag：诊断战斗为何空场——打印状态 + 单位数
func _run_diag() -> void:
	var main: Node = await _boot_main()
	await _start_manual_battle(main, 100)
	for i in 3:
		await _wait_frames(300)
		var gm: Node = get_node_or_null("/root/GameManager")
		var bm: Node = get_node_or_null("/root/BattleManager")
		var pu: Node = main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport/Battlefield/PlayerUnits")
		var eu: Node = main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport/Battlefield/EnemyUnits")
		print("[SteamCap][diag] lvl=", gm.get("current_level") if gm else "?",
			" battle_active=", bm.get("battle_active") if bm else "?",
			" player_units=", pu.get_child_count() if pu else "?",
			" enemy_units=", eu.get_child_count() if eu else "?",
			" afk_running=", main.call("get_afk_manager").get("is_running"))
	_shot("diag_root.png")
