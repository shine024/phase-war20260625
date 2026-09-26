extends Node
## 美术复核受控采集器（临时工具，可删）：
## 低关卡真实战斗连拍（部署/交火/受击/击毁）+ 前线近景特写 + 战后结算实况 + 基地镜头。
## 用法：把 .godot/steam_cap_mode.txt 写成 `art <level> <prefix> [closeup]`（战斗）
## 或 `truck`（移动基地整备舱），再窗口化运行本场景：
##   godot --rendering-driver opengl3 --path . res://tests/_tmp_art_cap.tscn

const SHOT_DIR := "res://_steam_assets/shots/"
const MODE_FILE := "res://.godot/steam_cap_mode.txt"

var _cam: Camera2D = null
var _bf: Node = null


func _ready() -> void:
	# 防遮挡：窗口被盖住时 Godot 停止绘制，SubViewport 采集会拿到陈旧帧（L28 实测）
	get_window().always_on_top = true
	var spec := "art 5 L5"
	if FileAccess.file_exists(MODE_FILE):
		spec = FileAccess.get_file_as_string(MODE_FILE).strip_edges()
	var parts := spec.split(" ", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await _wait_frames(20)
	if parts[0] == "truck":
		var sm: Node = get_node_or_null("/root/SaveManager")
		if sm != null and sm.has_method("load_game"):
			sm.call("load_game")
		await _wait_frames(10)
		_mount("res://scenes/bunker/truck_base.tscn")
		await _wait_frames(150)
		_shot("art_truck_base.png")
		get_tree().quit(0)
		return
	var level := int(parts[1]) if parts.size() > 1 else 5
	var prefix := parts[2] if parts.size() > 2 else "L%d" % level
	var closeup: bool = parts.has("closeup")
	var deploy_delay := 0
	for kv in parts:
		if kv.begins_with("delay="):
			deploy_delay = int(kv.get_slice("=", 1))
	# 强制 1× 战斗速度（存档偏好可能带 3×，会把 35s 战斗压到 12s 内拍不到动作）
	var cf := ConfigFile.new()
	cf.load("user://battle_speed.cfg")
	cf.set_value("speed", "user_scale", 1.0)
	cf.set_value("deploy", "auto_deploy", true)
	cf.save("user://battle_speed.cfg")
	var main: Node = await _boot_main()
	var gm: Node = get_node_or_null("/root/GameManager")
	gm.call("set_current_level", level)
	var setup: RefCounted = main.get("_battle_setup")
	setup.call("on_start_battle")
	await _wait_frames(45)
	_battle_supersample(main)
	_normalize_battle_world(853.0)
	_apply_cam(_cam, 493.0, 1.5, 640.0)
	# 延迟部署：先让敌方波次单独展开（拍单位/推进），再放我方进场（delay=N 帧）
	if deploy_delay > 0:
		for i in range(deploy_delay):
			await _wait_frames(15)
			_shot_battle("art_%s_e%02d.png" % [prefix, i], main)
	_auto_deploy(main)
	# closefirst：部署后立即近景（战斗前中期最激烈），再回全景连拍——
	# 原顺序（全景 45 拍后才近景）在快速结束的战斗里近景永远落空
	print("[ArtCap][DBG] parts=", parts, " has_closefirst=", parts.has("closefirst"), " cam=", _cam)
	if parts.has("closefirst") and _cam != null:
		_apply_cam(_cam, 493.0, 2.6, 640.0)
		for i in range(18):
			await _wait_frames(12)
			if _cam == null or not is_instance_valid(_cam):
				break
			_shot_battle("art_%s_z%02d.png" % [prefix, i], main)
		if _cam != null and is_instance_valid(_cam):
			_apply_cam(_cam, 493.0, 1.5, 640.0)
	# 密集连拍 45 张 × 15 帧（约 11s：亚 0.25s 间隔抓受击/击毁瞬间）
	for i in range(45):
		await _wait_frames(15)
		_shot_battle("art_%s_b%02d.png" % [prefix, i], main)
		if i % 3 == 0:
			_shot_full("art_%s_h%02d.png" % [prefix, i])
	if closeup and _cam != null and is_instance_valid(_cam):
		# 前线近景：zoom 2.6（≈3.9× 设计取景）对准中线交火区
		_apply_cam(_cam, 493.0, 2.6, 640.0)
		for i in range(20):
			await _wait_frames(10)
			if _cam == null or not is_instance_valid(_cam):
				break  # 战斗结束场景切换会释放相机
			_shot_battle("art_%s_c%02d.png" % [prefix, i], main)
	# 战后实况（HUD + 结算面板若已弹出）
	await _wait_frames(200)
	_shot_full("art_%s_after.png" % prefix)
	get_tree().quit(0)


# ── 以下助手与 tests/_tmp_steam_cap.gd 同源 ──────────────────

func _load_save() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")


func _mount(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst


func _boot_main() -> Node:
	_load_save()
	await _wait_frames(10)
	var main: Node = _mount("res://scenes/main.tscn")
	await _wait_frames(150)
	var popup: Node = main.get("popup_layer")
	if popup != null:
		for c in popup.get_children():
			var sc: Script = c.get_script()
			if sc != null and "offline" in String(sc.resource_path):
				c.queue_free()
	return main


func _battle_supersample(main: Node) -> void:
	var vp: SubViewport = main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport") as SubViewport
	var container: SubViewportContainer = main.get_node_or_null("BattleContainer/SubViewportContainer") as SubViewportContainer
	if vp == null or container == null:
		push_warning("[ArtCap] supersample 节点缺失")
		return
	container.stretch = false
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_bf = vp.get_node_or_null("Battlefield")
	_cam = Camera2D.new()
	_cam.name = "ArtCapCamera"
	_bf.add_child(_cam)
	_cam.make_current()
	print("[ArtCap] supersample on")


func _apply_cam(cam: Camera2D, cy: float, czoom: float = 1.5, cx: float = 640.0) -> void:
	cam.zoom = Vector2(czoom, czoom)
	cam.position = Vector2(cx, cy)
	cam.reset_smoothing()


func _normalize_battle_world(bottom: float) -> void:
	if _bf == null:
		return
	_bf.set("_bg_pending_battle_bottom_y", bottom)
	var lvl_bg: Sprite2D = _bf.get_node_or_null("Level10Background") as Sprite2D
	if lvl_bg != null and lvl_bg.texture != null:
		_bf.call("_apply_background_texture", lvl_bg.texture)


func _auto_deploy(main: Node) -> void:
	var bar: Node = main.get("bottom_instrument_bar")
	var btn: Button = bar.get("_auto_deploy_btn") if bar != null else null
	if btn != null:
		btn.button_pressed = true
		btn.pressed.emit()
		print("[ArtCap] auto deploy ON")


func _shot(fname: String) -> void:
	var vp := get_tree().root.get_viewport()
	var tex := vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return
	img.save_png(SHOT_DIR + fname)
	print("[ArtCap] shot ", fname)


func _shot_full(fname: String) -> void:
	var vp := get_tree().root.get_viewport()
	var tex := vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return
	img.save_png(SHOT_DIR + fname)
	print("[ArtCap] full ", fname)


func _shot_battle(fname: String, main: Node) -> void:
	var vp: SubViewport = main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport") as SubViewport
	if vp == null:
		return
	var img: Image = vp.get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.save_png(SHOT_DIR + fname)
	print("[ArtCap] battle ", fname)


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
