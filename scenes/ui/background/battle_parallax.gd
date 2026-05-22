extends ParallaxBackground
## 战斗场景简易 Parallax 背景（2-3 层）

const DT = preload("res://resources/design_tokens.gd")

func _ready() -> void:
	_create_layers()

func _create_layers() -> void:
	# 远景：深色星空
	var far_layer := ParallaxLayer.new()
	far_layer.motion_scale = Vector2(0.1, 0.0)
	var far_rect := ColorRect.new()
	far_rect.color = DT.get_bg_color()
	far_rect.offset_left = -400
	far_rect.offset_top = -300
	far_rect.offset_right = 1680
	far_rect.offset_bottom = 900
	far_layer.add_child(far_rect)
	add_child(far_layer)

	# 中景：淡紫色能量云
	var mid_layer := ParallaxLayer.new()
	mid_layer.motion_scale = Vector2(0.3, 0.0)
	var mid_rect := ColorRect.new()
	mid_rect.color = DT.get_accent_color("purple", true) * Color(1, 1, 1, 0.15)
	mid_rect.offset_left = -400
	mid_rect.offset_top = -200
	mid_rect.offset_right = 1680
	mid_rect.offset_bottom = 800
	mid_layer.add_child(mid_rect)
	add_child(mid_layer)

	# 近景：青色扫描线条
	var near_layer := ParallaxLayer.new()
	near_layer.motion_scale = Vector2(0.6, 0.0)
	var near_rect := ColorRect.new()
	near_rect.color = DT.get_accent_color("cyan") * Color(1, 1, 1, 0.08)
	near_rect.offset_left = -400
	near_rect.offset_top = -50
	near_rect.offset_right = 1680
	near_rect.offset_bottom = 750
	near_layer.add_child(near_rect)
	add_child(near_layer)

