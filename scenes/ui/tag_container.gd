extends HBoxContainer
class_name TagContainer
## 标签容器组件
## 用于显示多个标签徽章

@export var tags: Array[String] = []:
	set(v):
		tags = v
		_refresh_tags()

func _ready() -> void:
	name = "TagContainer"
	theme_override_constants.separation = 4
	_refresh_tags()

func _refresh_tags() -> void:
	# 清空现有标签
	for child in get_children():
		child.queue_free()

	# 添加新标签
	for tag in tags:
		if not tag.is_empty():
			var badge = TagBadge.create(tag, TagBadge.get_color_for_tag(tag))
			add_child(badge)

## 设置标签（从字符串数组）
func set_tags(tag_array: Array[String]) -> void:
	tags = tag_array

## 添加单个标签
func add_tag(tag: String) -> void:
	if not tag.is_empty() and not tag in tags:
		tags.append(tag)
		_refresh_tags()

## 移除标签
func remove_tag(tag: String) -> void:
	tags.erase(tag)
	_refresh_tags()
