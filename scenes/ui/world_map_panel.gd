extends Control
## 世界地图面板：在主场景中显示的世界地图界面

## 性能优化：预加载场景，避免运行时 load()
const WorldMapScene = preload("res://scenes/world_map.tscn")

var world_map_content: Node = null

func _ready() -> void:
	# v9.x 性能：不再在主场景实例化时同步构建世界地图（100 关按钮 + 星空 + 样式）。
	# MapOverlay 启动即隐藏，启动期构建纯属占用主线程——是"进游戏后要等一会"的构成之一。
	# 懒实例化：首次可见或首次 refresh 时再建；world_map 自身 _build_level_map 有幂等守卫，
	# refresh_for_open 也会兜底未构建状态，时序安全。
	visibility_changed.connect(_on_visibility_changed_lazy)
	# 调试钩子：WM_AUTO_OPEN=1 时启动自动展开地图层（复现嵌入式布局，仅调试用）
	if OS.has_environment("WM_AUTO_OPEN"):
		_ensure_content.call_deferred()
		_auto_open.call_deferred()

func _auto_open() -> void:
	await get_tree().create_timer(0.5).timeout
	var overlay := get_parent()
	if overlay is Control:
		(overlay as Control).visible = true
	refresh()

func _on_visibility_changed_lazy() -> void:
	if visible:
		_ensure_content()

func _ensure_content() -> void:
	if world_map_content != null and is_instance_valid(world_map_content):
		return
	if WorldMapScene == null:
		return
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
	_ensure_content()
	# 打开地图时仅做轻量刷新，避免每次重建100关按钮
	if world_map_content == null:
		return
	if world_map_content.has_method("refresh_for_open"):
		world_map_content.refresh_for_open()
	elif world_map_content.has_method("refresh_levels"):
		world_map_content.refresh_levels()
