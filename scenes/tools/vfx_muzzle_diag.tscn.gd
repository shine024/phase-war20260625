extends Node2D
## v19-R17c 诊断 v2：定位 Sprite2D 为何不渲染。多位置/巨缩放/ColorRect 对照。

func _ready() -> void:
	var sky := ColorRect.new()
	sky.color = Color(0.10, 0.12, 0.17, 1.0)
	sky.size = Vector2(1600, 1000)
	sky.position = Vector2(-400, -400)
	add_child(sky)
	await get_tree().process_frame
	await get_tree().process_frame

	var tex := load("res://assets/effects/particle_textures/muzzle_jet_sym.png")
	print("[diag] tex=", tex, " size=", tex.get_size() if tex else "N/A")

	# ① 巨缩放精灵 @ (360,430)
	var big := Sprite2D.new()
	big.texture = tex
	big.position = Vector2(360, 430)
	big.scale = Vector2(4.0, 4.0)
	add_child(big)
	print("[diag] big sprite xform=", big.global_transform)

	# ② 常规精灵 @ (600,200)（远离其他元素）
	var mid := Sprite2D.new()
	mid.texture = tex
	mid.position = Vector2(600, 200)
	mid.scale = Vector2(2.0, 2.0)
	add_child(mid)

	# ③ ColorRect 对照 @ (800,300)
	var cr := ColorRect.new()
	cr.color = Color(1.0, 0.3, 0.1, 1.0)
	cr.size = Vector2(60, 30)
	cr.position = Vector2(770, 285)
	add_child(cr)

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://docs/vfx_diag_render.png")
	# 分区统计
	var regions := {
		"big@(360,430)x4": Rect2i(150, 320, 340, 140),
		"mid@(600,200)x2": Rect2i(480, 130, 260, 100),
		"cr@(800,300)": Rect2i(740, 240, 120, 90),
	}
	for label in regions:
		var r: Rect2i = regions[label]
		var cnt := 0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := img.get_pixel(x, y)
				if c.a > 0.2 and (c.r8 > 140 or c.g8 > 140 or c.b8 > 140):
					cnt += 1
		print("[diag] region %s bright=%d" % [label, cnt])
	print("[diag] saved vfx_diag_render.png  viewport=%s" % get_viewport().get_visible_rect())
	get_tree().quit()
