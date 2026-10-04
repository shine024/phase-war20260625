extends Node
## _tmp_storm_probe 监视节点（root 直挂，不随场景切换释放）
## 触发 SceneTransition.change(main.tscn)（对齐 truck_base 出击/世界地图返回链），
## 逐帧监视 current_scene 的树内状态，捕捉「main 启动链树外报错」风暴签名。

func _ready() -> void:
	print("[PROBE] monitor ready, wait 5 frames")
	for i in range(5):
		await get_tree().process_frame
	print("[PROBE] calling SceneTransition.change(main.tscn)")
	SceneTransition.change(get_tree(), "res://scenes/main.tscn")
	for i in range(300):
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs == null:
			if i % 20 == 0:
				print("[PROBE] f=%d current=null busy=%s" % [i, SceneTransition.is_busy()])
		else:
			var state := "IN_TREE" if cs.is_inside_tree() else "OUT_OF_TREE!!!"
			if i % 20 == 0 or state != "IN_TREE":
				print("[PROBE] f=%d current=%s %s" % [i, cs.name, state])
	print("[PROBE] done, quitting")
	get_tree().quit()
