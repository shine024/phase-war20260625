extends Node
## 记录4 视觉体检补拍：相位师档案真实入口（main._open_player_master_panel）单态验证。

func _ready() -> void:
	GameConfig.get_default().feature_gates_enabled = false
	var tpm := get_node_or_null("/root/TutorialProgressionManager")
	if tpm != null:
		tpm.set("current_step", 99)
	_go.call_deferred()

func _go() -> void:
	await _settle(5)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await _settle(10)
	main._open_player_master_panel()
	await _settle(15)
	var panel: Node = main.get_node_or_null("PopupLayer/PlayerMasterOverlay/CenterContainer/PlayerMasterPanel")
	if panel != null:
		var sum: Label = panel.get_node_or_null("Margin/VBox/SummaryLabel")
		var det: Label = panel.get_node_or_null("Margin/VBox/ScrollContainer/DetailLabel")
		print("PM sum=", sum.text if sum else "?")
		print("PM detail_head=", (det.text.left(220) if det else "?"))
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.godot/agent_tools/pm_probe.png")
	print("PM_DONE")
	get_tree().quit(0)

func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame
