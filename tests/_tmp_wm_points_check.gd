extends SceneTree
## 临时验证（v28 布点微调）：30/99 关覆写生效 + 与全图最小间距 ≥55px

func _init() -> void:
	var W := load("res://scenes/world_map.gd")
	W._layout_scheme11()
	var pts: Dictionary = W._s_level_points
	print("29=", pts[29], " 30=", pts[30], " 31=", pts[31])
	print("98=", pts[98], " 99=", pts[99], " 100=", pts[100])
	for lv in [30, 99]:
		var min_d := 1e9
		var nearest := -1
		for k in pts:
			if k == lv:
				continue
			var d: float = pts[lv].distance_to(pts[k])
			if d < min_d:
				min_d = d
				nearest = k
		print("level %d 最近邻= %d 间距= %.1f  %s" % [lv, nearest, min_d,
			"OK" if min_d >= 55.0 else "FAIL(<55)"])
	quit()
