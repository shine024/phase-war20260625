extends Node
## 动画工具类：提供常用的动画效果和过渡

## 淡入动画
static func fade_in(node: Control, duration: float = 0.3) -> Tween:
	if not node or not is_instance_valid(node):
		return null

	node.modulate.a = 0.0
	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT)
	return tween

## 淡出动画
static func fade_out(node: Control, duration: float = 0.3) -> Tween:
	if not node or not is_instance_valid(node):
		return null

	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	return tween

## 滑入动画
static func slide_in(node: Control, direction: Vector2 = Vector2.UP, duration: float = 0.3, distance: float = 50.0) -> Tween:
	if not node or not is_instance_valid(node):
		return null

	var original_pos = node.position
	node.position = original_pos + direction * distance

	var tween = node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "position", original_pos, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT)

	return tween

## 滑出动画
static func slide_out(node: Control, direction: Vector2 = Vector2.UP, duration: float = 0.3, distance: float = 50.0) -> Tween:
	if not node or not is_instance_valid(node):
		return null

	var target_pos = node.position + direction * distance

	var tween = node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "position", target_pos, duration).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)

	return tween

## 缩放动画
static func scale_animation(node: Control, target_scale: Vector2 = Vector2(1.1, 1.1), duration: float = 0.2) -> Tween:
	if not node or not is_instance_valid(node):
		return null

	var original_scale = node.scale
	var tween = node.create_tween()
	tween.tween_property(node, "scale", target_scale, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", original_scale, duration).set_ease(Tween.EASE_IN)
	return tween

## 弹跳动画
static func bounce_animation(node: Control, intensity: float = 0.2, duration: float = 0.4) -> Tween:
	if not node or not is_instance_valid(node):
		return null

	var original_scale = node.scale
	var tween = node.create_tween()

	tween.tween_property(node, "scale", original_scale * (1.0 + intensity), duration * 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", original_scale * (1.0 - intensity * 0.5), duration * 0.2).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "scale", original_scale, duration * 0.5).set_ease(Tween.EASE_OUT)

	return tween

## 旋转动画
static func rotate_animation(node: Node2D, rotations: float = 1.0, duration: float = 1.0) -> Tween:
	if not node or not is_instance_valid(node):
		return null

	var tween = node.create_tween()
	tween.tween_property(node, "rotation", node.rotation + rotations * PI * 2.0, duration).set_ease(Tween.EASE_IN_OUT)
	return tween

## 震动动画
static func shake_animation(node: Control, intensity: float = 5.0, duration: float = 0.5) -> Tween:
	if not node or not is_instance_valid(node):
		return null

	var original_pos = node.position
	var tween = node.create_tween()

	var shake_count = int(duration / 0.05)
	for i in range(shake_count):
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(node, "position", original_pos + offset, 0.025)
		tween.tween_property(node, "position", original_pos, 0.025)

	return tween

## 脉冲动画
static func pulse_animation(node: Control, min_scale: float = 0.95, max_scale: float = 1.05, duration: float = 1.0) -> Tween:
	if not node or not is_instance_valid(node):
		return null

	var tween = node.create_tween()
	tween.set_loops()
	tween.tween_property(node, "scale", Vector2(max_scale, max_scale), duration * 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2(min_scale, min_scale), duration * 0.5).set_ease(Tween.EASE_IN_OUT)
	return tween

## 颜色过渡动画
static func color_transition(node: Control, property: String, from_color: Color, to_color: Color, duration: float = 0.3) -> Tween:
	if not node or not is_instance_valid(node):
		return null

	var tween = node.create_tween()
	tween.tween_property(node, property, from_color, 0.0)
	tween.tween_property(node, property, to_color, duration).set_ease(Tween.EASE_IN_OUT)
	return tween

## 数字滚动动画
static func number_scroll(label: Label, from_value: int, to_value: int, duration: float = 1.0) -> Tween:
	if not label or not is_instance_valid(label):
		return null

	var tween = label.create_tween()
	tween.tween_method(_update_label_text.bind(label), from_value, to_value, duration).set_ease(Tween.EASE_OUT)
	return tween

func _update_label_text(label: Label, value: int) -> void:
	label.text = str(value)

## 进度条动画
static func progress_bar_animation(progress_bar: ProgressBar, from_value: float, to_value: float, duration: float = 0.5) -> Tween:
	if not progress_bar or not is_instance_valid(progress_bar):
		return null

	progress_bar.value = from_value
	var tween = progress_bar.create_tween()
	tween.tween_property(progress_bar, "value", to_value, duration).set_ease(Tween.EASE_OUT)
	return tween

## 延迟动画
static func delay_animation(duration: float) -> Tween:
	var tween = Tween.new()
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree:
		scene_tree.root.add_child(tween)
		tween.tween_interval(duration)
		tween.tween_callback(func(): tween.queue_free())
	return tween

## 序列动画
static func sequence_animation(animations: Array) -> Tween:
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		return null

	var tween = scene_tree.root.create_tween()
	for anim_data in animations:
		var node = anim_data.get("node")
		var properties = anim_data.get("properties", {})
		var duration = anim_data.get("duration", 0.3)
		var delay = anim_data.get("delay", 0.0)

		if delay > 0:
			tween.tween_interval(delay)

		if node and is_instance_valid(node):
			for property in properties:
				var value = properties[property]
				tween.parallel().tween_property(node, property, value, duration)

	return tween

## 并行动画
static func parallel_animation(animations: Array) -> Array:
	var tweens = []
	for anim_data in animations:
		var node = anim_data.get("node")
		var properties = anim_data.get("properties", {})
		var duration = anim_data.get("duration", 0.3)

		if node and is_instance_valid(node):
			var tween = node.create_tween()
			tween.set_parallel(true)
			for property in properties:
				var value = properties[property]
				tween.tween_property(node, property, value, duration).set_ease(Tween.EASE_OUT)
			tweens.append(tween)

	return tweens

## 停止所有动画
static func stop_all_animations(node: Node) -> void:
	if not node or not is_instance_valid(node):
		return

	for child in node.get_children():
		if child has_method("kill"):
			child.kill()

## 清理动画
static func cleanup_tween(tween: Tween) -> void:
	if tween and is_instance_valid(tween):
		tween.kill()
