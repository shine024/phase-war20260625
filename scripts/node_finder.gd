extends RefCounted
## 节点查找工具：集中管理所有硬编码路径（无 Node 上下文，经 SceneTree.root 解析）

class_name NodeFinder


static func _scene_root() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root


static func _find(path: String) -> Node:
	var root: Node = _scene_root()
	if root == null or path.is_empty():
		return null
	return root.get_node_or_null(path)


## 获取背包面板
static func get_backpack_panel() -> Node:
	var paths := [
		"/root/Main/PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/BackpackPanel",
		"/root/Main/PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/backpack_panel",
		"/root/Main/PrepPanel/RootMargin/HBox/BackpackArea/Margin/VBox/BackpackScroll/BackpackPanel",
		"/root/Main/PrepPanel/BackpackArea/Margin/VBox/BackpackScroll/BackpackPanel",
	]
	for p in paths:
		var n: Node = _find(p)
		if n != null:
			return n
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var by_group: Array = tree.get_nodes_in_group("backpack_panel")
		if not by_group.is_empty() and by_group[0] is Node:
			return by_group[0] as Node
	return null


## 获取全局情报面板（挂在 InfoPanelLayer layer=90，不被 HUD 遮挡）
static func get_card_info_panel() -> Node:
	var paths := [
		"/root/Main/InfoPanelLayer/CardInfoPanel",
	]
	for p in paths:
		var n: Node = _find(p)
		if n != null:
			return n
	# fallback: root 下的旧式全局单例
	var legacy: Node = _find("/root/CardInfoPanel")
	if legacy != null:
		return legacy
	# 记录7#7: 独立场景（truck_base）没有 /root/Main——基地自挂的实例走分组兜底
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var by_group: Array = tree.get_nodes_in_group("card_info_panel")
		if not by_group.is_empty() and by_group[0] is Node:
			return by_group[0] as Node
	return null
