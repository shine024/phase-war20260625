class_name BackpackFilterSort
extends RefCounted
## 背包筛选/排序系统（从 backpack_panel.gd 拆分）
## 负责：稀有度过滤、可见性重置、排序类型转换

## 宿主引用（由 backpack_panel 在 _ready 设置）
var _host: Node = null  # BackpackPanel

func setup(host: Node) -> void:
	_host = host

## 按稀有度过滤可见性
func apply_rarity_filter(rarity: String) -> void:
	if not _host:
		return
	var grid = _host.get_node_or_null("VBoxOuter/ScrollContainer/CardGrid")
	if not grid:
		return
	for child in grid.get_children():
		if child.has_meta("is_resource_slot") and child.get_meta("is_resource_slot"):
			continue
		if child.has_method("set_card"):
			var card: CardResource = child.card if "card" in child else null
			if card != null and card.rarity != rarity:
				child.visible = false
			else:
				child.visible = true

## 重置所有子节点可见性
func reset_visibility() -> void:
	if not _host:
		return
	var grid = _host.get_node_or_null("VBoxOuter/ScrollContainer/CardGrid")
	if not grid:
		return
	for child in grid.get_children():
		child.visible = true

## 排序类型字符串转 int（兼容 BackpackData.SortType）
func sort_type_string_to_int(sort_type: String) -> int:
	var BackpackDataScript = load("res://scenes/ui/backpack/backpack_data.gd")
	if BackpackDataScript == null:
		return 0
	match sort_type:
		"default": return BackpackDataScript.SortType.DEFAULT
		"name": return BackpackDataScript.SortType.NAME
		"cost": return BackpackDataScript.SortType.COST
		"rarity": return BackpackDataScript.SortType.RARITY
		_: return BackpackDataScript.SortType.DEFAULT
