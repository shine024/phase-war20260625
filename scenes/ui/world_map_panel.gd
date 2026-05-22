extends Control
## 世界地图面板：在主场景中显示的世界地图界面

## 性能优化：预加载场景，避免运行时 load()
const WorldMapScene = preload("res://scenes/world_map.tscn")

var world_map_content: Node = null

func _ready() -> void:
	# 加载世界地图场景
	if WorldMapScene:
		world_map_content = WorldMapScene.instantiate()
		# 嵌入模式：世界地图返回时关闭 overlay，而不是切场景。
		world_map_content.set_meta("embedded_mode", true)
		add_child(world_map_content)

		# 连接返回信号
		if world_map_content.has_signal("back_to_main"):
			world_map_content.back_to_main.connect(_on_back_to_main)

func _on_back_to_main() -> void:
	# 关闭整层地图 Overlay（而非仅隐藏 CenterContainer），避免透明层残留拦截输入导致“卡住”。
	var node: Node = self
	while node != null:
		if node is Control and node.name == "MapOverlay":
			(node as Control).hide()
			return
		node = node.get_parent()
	# 兜底：至少隐藏当前容器
	if get_parent() is Control:
		(get_parent() as Control).hide()

func refresh() -> void:
	# 打开地图时仅做轻量刷新，避免每次重建100关按钮
	if world_map_content == null:
		return
	if world_map_content.has_method("refresh_for_open"):
		world_map_content.refresh_for_open()
	elif world_map_content.has_method("refresh_levels"):
		world_map_content.refresh_levels()
