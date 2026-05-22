extends CanvasLayer
## 格子战术：进场即开战，不再显示「战斗开始」等 HUD（保留节点供旧场景引用）

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 45


func configure_for_battle() -> void:
	visible = false
