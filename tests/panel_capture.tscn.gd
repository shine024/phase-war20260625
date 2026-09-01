extends Node
## 真实大面板实拍驱动：情报中心/商店/背包三个 textured 面板框在真实尺寸下的效果。
## 用法：godot --path . res://tests/panel_capture.tscn（窗口短暂闪现 ~20s）
## 产出：.godot/panel_info.png / panel_store.png / panel_backpack.png
## 注意：驱动内已把 get_tree().current_scene 指回 main——懒加载面板路径依赖它，
## 复制本驱动改打其他面板时保留该行。

const SHOT_DIR := "res://.godot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().process_frame

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = main_scene.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	# 懒加载路径用 get_tree().current_scene 解析——驱动场景下必须指回 main，否则面板打不开
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().create_timer(3.5).timeout

	# 1) 情报中心（violet accent 面板）
	main._on_info_pressed()
	await get_tree().create_timer(2.0).timeout
	await _capture("panel_info.png")
	main._close_top_overlay()
	await get_tree().create_timer(0.6).timeout

	# 2) 商店（gold accent 面板）
	main._on_store_pressed()
	await get_tree().create_timer(2.0).timeout
	await _capture("panel_store.png")
	main._close_top_overlay()
	await get_tree().create_timer(0.6).timeout

	# 3) 背包（cyan accent 全出血面板）
	main._on_backpack_pressed()
	await get_tree().create_timer(2.0).timeout
	await _capture("panel_backpack.png")

	print("[PanelCapture] DONE")
	get_tree().quit()


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(SHOT_DIR + "/" + file_name)
	print("[PanelCapture] saved ", file_name, " ", img.get_size())
