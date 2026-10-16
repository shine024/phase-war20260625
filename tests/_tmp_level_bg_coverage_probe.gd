extends SceneTree
## 临时探针：逐关背景覆盖验证——1~100 关 + 黑门三档 + 标题，走游戏同款路径格式加载。
## 缺关 = 战场走 era 兜底图（玩家看错时代的图），属可玩性问题。

func _initialize() -> void:
	_run()

func _run() -> void:
	var missing: Array = []
	var small: Array = []
	var ok := 0
	for level in range(1, 101):
		var path := "res://assets/backgrounds/bg_level_%02d.png" % level
		if not ResourceLoader.exists(path):
			missing.append(level)
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			missing.append(level)
			continue
		if tex.get_width() < 1376:
			small.append("%d(%dpx)" % [level, tex.get_width()])
		ok += 1
	for extra in ["bg_default", "bg_endless_gate_t0", "bg_endless_gate_t1", "bg_endless_gate_t2", "title_bg"]:
		var p := "res://assets/backgrounds/%s.png" % extra
		if not ResourceLoader.exists(p) or load(p) == null:
			missing.append(extra)
		else:
			ok += 1
	print("[BgCoverage] OK=", ok, " missing=", missing, " subHD=", small)
	quit()
