extends SceneTree
## 真字体宽度审计：Noto 11px 下战场名超 62px 的条目（排除 platform_*）
func _init() -> void:
	var UCT = load("res://data/unified_card_table.gd")
	var Strip = load("res://scripts/card_grid_name_strip.gd")
	var font: Font = load("res://assets/fonts/NotoSansSC-Regular.ttf")
	var avail: float = 58.9 * 1.12 - 4.0
	var over := 0
	for id in UCT.get_all_card_ids():
		if id.begins_with("platform_"):
			continue
		var c = UCT.build_card_resource(id)
		if c == null:
			continue
		var name: String = Strip.battlefield_display_name(c)
		var w: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		if w > avail:
			over += 1
			print("%6.1f  %s  (%s -> %s)" % [w, c.display_name, id, name])
	print("avail=%.1f overflow=%d" % [avail, over])
	quit()
