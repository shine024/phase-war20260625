extends Control
class_name TagBadge
## 标签徽章组件
## 用于显示卡片和情报的标签

@export var tag_text: String = "":
	set(v):
		tag_text = v
		_update_display()

@export var tag_color: Color = Color(0.4, 0.6, 0.8, 0.8):
	set(v):
		tag_color = v
		_update_style()

var _label: Label = null

func _ready() -> void:
	# 创建标签显示
	_label = Label.new()
	_label.name = "Label"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

	# 设置基本样式
	custom_minimum_size = Vector2(60, 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_update_display()
	_update_style()

func _update_display() -> void:
	if _label:
		_label.text = tag_text

func _update_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = tag_color
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.border_color = tag_color.lightened(0.2)

	add_theme_stylebox_override("panel", style)

	if _label:
		_label.add_theme_color_override("font_color", Color.WHITE)
		_label.add_theme_font_size_override("font_size", 12)

## 创建标签徽章（静态工厂方法）
static func create(text: String, color: Color = Color(0.4, 0.6, 0.8, 0.8)) -> TagBadge:
	var badge = TagBadge.new()
	badge.tag_text = text
	badge.tag_color = color
	return badge

## 预定义标签颜色
static func get_color_for_tag(tag: String) -> Color:
	var tag_lower = tag.to_lower()
	match tag_lower:
		"战术", "步兵", "装甲", "支援", "空中":
			return Color(0.3, 0.5, 0.7, 0.8)
		"技术", "创新", "ai", "网络", "无人机":
			return Color(0.7, 0.3, 0.5, 0.8)
		"历史", "政治", "冷战", "一战", "二战", "现代", "未来":
			return Color(0.5, 0.4, 0.7, 0.8)
		"情报", "谍战", "密码", "信息战":
			return Color(0.7, 0.5, 0.3, 0.8)
		"危险", "化学武器", "核威慑":
			return Color(0.7, 0.2, 0.2, 0.8)
		"防御", "进攻":
			return Color(0.2, 0.6, 0.4, 0.8)
		_:
			return Color(0.4, 0.6, 0.8, 0.8)
