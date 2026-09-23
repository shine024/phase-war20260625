extends Control
## 开场链宽窗体检探针 v2：comic_intro（1280 标准窗 + 1720 宽窗）+ dream_battle（宽窗）
## 断言：跳过键全局右缘距屏幕右缘 ≤ 20px（真实屏幕角）；comic 舞台水平居中。
## 运行：godot --rendering-driver opengl3 --path . res://tests/_tmp_comic_probe.tscn

func _ready() -> void:
	# ── comic_intro：标准窗 ──
	var comic: Node = load("res://scenes/intro/comic_intro.tscn").instantiate()
	add_child(comic)
	await _wait(1.6)
	_dump_skip(comic, "comic@1280")
	_shot("comic_720")
	comic.queue_free()
	await _wait(0.2)
	# ── comic_intro：宽窗 ──
	get_window().size = Vector2i(1720, 760)
	await _wait(0.5)
	comic = load("res://scenes/intro/comic_intro.tscn").instantiate()
	add_child(comic)
	await _wait(1.6)
	_dump_skip(comic, "comic@wide")
	print("COMIC_PROBE wide viewport=", get_viewport_rect().size,
		" stage_x_centered_offset=", comic._stage.position.x)
	_shot("comic_wide")
	comic.queue_free()
	await _wait(0.2)
	# ── dream_battle：宽窗 ──
	var dream: Node = load("res://scenes/intro/dream_battle.tscn").instantiate()
	add_child(dream)
	await _wait(1.2)
	_dump_skip(dream, "dream@wide")
	_shot("dream_wide")
	dream.queue_free()
	await _wait(0.2)
	get_tree().quit()


func _dump_skip(scene: Node, tag: String) -> void:
	var skip: Control = null
	for n in _all_controls(scene):
		if n is Button and String((n as Button).text).begins_with("跳过"):
			skip = n
			break
	if skip == null:
		print("COMIC_PROBE %s skip=null !!", tag)
		return
	var r := skip.get_global_rect()
	var vp := get_viewport_rect().size
	var right_gap: float = vp.x - r.end.x
	print("COMIC_PROBE %s skip=%s right_gap=%.0f bottom_y=%.0f" % [tag, str(r), right_gap, r.end.y])
	if right_gap <= 20.0:
		print("COMIC_PROBE %s SKIP_AT_CORNER_OK" % tag)
	else:
		print("COMIC_PROBE %s SKIP_NOT_AT_CORNER_FAIL" % tag)


func _all_controls(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	for ch in node.get_children():
		if ch is Control:
			out.append(ch)
		out.append_array(_all_controls(ch))
	return out


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.godot/agent_tools/ui_audit/" + name + ".png")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
