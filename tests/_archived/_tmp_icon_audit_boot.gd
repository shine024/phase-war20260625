extends Node
## 卡图终检引导（boot 场景模式）：用游戏自己的 UiAssetLoader.card_icon_path_for
## 对全卡求图标路径，报出 placeholder/文件不存在的卡。
## 跑法：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_icon_audit_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "IconAuditRunner"
	r.set_script(load("res://tests/_tmp_icon_audit_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
