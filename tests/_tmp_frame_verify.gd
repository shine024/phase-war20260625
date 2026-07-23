extends SceneTree

func _init():
	for r in ["common", "uncommon", "rare", "epic", "legendary", "mythic"]:
		var tex = load("res://assets/cards/frames/%s.png" % r)
		if tex == null:
			print("VERIFY %s: LOAD_NULL" % r)
			continue
		var img = tex.get_image()
		if img == null:
			print("VERIFY %s: NO_IMAGE" % r)
			continue
		var w = img.get_width()
		var h = img.get_height()
		# 画面范围 bbox（不透明像素）
		var min_x = w
		var max_x = 0
		var min_y = h
		var max_y = 0
		var transparent = 0
		var opaque = 0
		var samples = 0
		for y in range(0, h, max(1, h / 60)):
			for x in range(0, w, max(1, w / 60)):
				samples += 1
				var a = img.get_pixel(x, y).a8
				if a < 10:
					transparent += 1
				elif a > 30:
					opaque += 1
					if x < min_x: min_x = x
					if x > max_x: max_x = x
					if y < min_y: min_y = y
					if y > max_y: max_y = y
		var fill_w = float(max_x - min_x) / w * 100
		var fill_h = float(max_y - min_y) / h * 100
		print("VERIFY %s: %dx%d 画面占宽%.0f%%高%.0f%% 透明%.0f%%" % [r, w, h, fill_w, fill_h, float(transparent) / samples * 100])
	quit()
