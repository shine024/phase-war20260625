extends SceneTree
## _tmp 开火锚点标尺核对图（配合 tests/_tmp_fire_anchor_audit.gd 的 flagged 列表）
## 每单位一格：纹理空间 10% 网格 + 内容框(绿) + 现标注(红十字) + 枪口尖候选(黄十字)
##   我方图朝右（枪口偏右），敌方原图朝左（枪口偏左）
## 出图：.godot/agent_tools/fire_ruler_N.png（4×4/页）
## 跑法：godot --path . --resolution 1280x1200 --script tests/_tmp_fire_anchor_ruler.gd

const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")

const CELL_W := 310.0
const CELL_H := 300.0
const COLS := 4
const ROWS := 4
const TEX := 250.0


func _initialize() -> void:
	# 全量审计行（id → key=value 集）+ flagged id 列表
	var audit_rows := {}
	var audit_f := FileAccess.open("res://.godot/agent_tools/fire_audit.txt", FileAccess.READ)
	for l in audit_f.get_as_text().split("\n"):
		var t := l.strip_edges()
		if not t.contains("|"):
			continue
		var segs := t.split("|")
		if segs.size() < 3:
			continue
		audit_rows[String(segs[1])] = segs
	var flagged: Array = []
	var flag_f := FileAccess.open("res://.godot/agent_tools/fire_audit_flagged.txt", FileAccess.READ)
	for l in flag_f.get_as_text().split("\n"):
		var t := l.strip_edges()
		if t.contains("|"):
			flagged.append(audit_rows.get(t.split("|")[1], (t + "|st=?").split("|")))
	# id → path（与审计同解析）
	var paths := _resolve_paths()
	var sv := SubViewport.new()
	sv.size = Vector2i(int(COLS * CELL_W) + 20, int(ROWS * CELL_H) + 20)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var n_sheets := int(ceil(float(flagged.size()) / float(COLS * ROWS)))
	for s in range(n_sheets):
		var sheet := Node2D.new()
		var bg := ColorRect.new()
		bg.color = Color(0.13, 0.15, 0.17)
		bg.size = sv.size
		sheet.add_child(bg)
		for i in range(s * COLS * ROWS, mini((s + 1) * COLS * ROWS, flagged.size())):
			var ent: Array = flagged[i]
			var idx := i - s * COLS * ROWS
			var cx := (float(idx % COLS) + 0.5) * CELL_W + 10.0
			var cy := float(idx / COLS) * CELL_H + 10.0
			_add_cell(sheet, ent, Vector2(cx, cy), String(paths.get(ent[1], "")))
		sv.add_child(sheet)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = sv.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://.godot/agent_tools/fire_ruler_%d.png" % s))
		print("SAVED fire_ruler_%d.png" % s)
		sv.remove_child(sheet)
		sheet.queue_free()
		await process_frame
	quit(0)


func _resolve_paths() -> Dictionary:
	var out := {}
	for c in DefaultCards.create_all():
		if c == null or int(c.card_type) != int(GC.CardType.COMBAT_UNIT):
			continue
		var id := String(c.card_id)
		var path := "res://assets/card_icons/player/%s.png" % id
		if not ResourceLoader.exists(path):
			var vis: String = EnemyUnitManifest.visual_id_for_archetype(id)
			if not vis.is_empty():
				path = "res://assets/card_icons/player/%s.png" % vis
		out[id] = path
	for row in EnemyUnitManifest.get_entries():
		var id := String(row.get("archetype_id", ""))
		if not id.is_empty():
			out[id] = String(EnemyUnitManifest.get_unit_icon_path_for_archetype(id, false))
	return out


func _add_cell(sheet: Node2D, ent: Array, pos: Vector2, path: String) -> void:
	var side: String = ent[0]
	var id: String = ent[1]
	var parts := {}
	for i in range(2, ent.size()):
		var kv: PackedStringArray = String(ent[i]).split("=")
		if kv.size() == 2:
			parts[kv[0]] = kv[1]
	var status: String = parts.get("st", "?")
	var fx := float(parts.get("fx", "-1"))
	var fy := float(parts.get("fy", "-1"))
	var tx := float(parts.get("tx", "-1"))
	var ty := float(parts.get("ty", "-1"))
	var tex: Texture2D = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	# 纹理框（左上角对齐）
	var ox := pos.x - TEX * 0.5
	var oy := pos.y - TEX * 0.5 - 10.0
	# 网格：每 10% 一条
	for i in range(11):
		var t := float(i) * 0.1
		var c := Color(1, 1, 1, 0.10) if i % 5 != 0 else Color(1, 1, 1, 0.28)
		_line(sheet, Vector2(ox + t * TEX, oy), Vector2(ox + t * TEX, oy + TEX), c, 1.0)
		_line(sheet, Vector2(ox, oy + t * TEX), Vector2(ox + TEX, oy + t * TEX), c, 1.0)
	if tex != null:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.position = Vector2(ox, oy)
		spr.scale = Vector2(TEX / float(tex.get_width()), TEX / float(tex.get_height()))
		spr.modulate = Color(1, 1, 1, 0.92)
		sheet.add_child(spr)
	else:
		var nr := ColorRect.new()
		nr.color = Color(0.4, 0.1, 0.1)
		nr.position = Vector2(ox, oy)
		nr.size = Vector2(TEX, TEX)
		sheet.add_child(nr)
	# 内容框（绿）
	var wf := float(parts.get("wf", "1"))
	var ff := float(parts.get("ff", "0"))
	var hf := float(parts.get("hf", "0"))
	var l := (1.0 - wf) * 0.5
	_rect(sheet, Vector2(ox + l * TEX, oy + hf * TEX), Vector2(wf * TEX, (1.0 - ff - hf) * TEX), Color(0.3, 1, 0.3, 0.9))
	# 现标注（红十字）
	if fx >= 0.0:
		var p := Vector2(ox + fx * TEX, oy + fy * TEX)
		_line(sheet, p + Vector2(-6, 0), p + Vector2(6, 0), Color(1, 0.2, 0.2), 2.0)
		_line(sheet, p + Vector2(0, -6), p + Vector2(0, 6), Color(1, 0.2, 0.2), 2.0)
	# 枪口尖候选（黄十字）
	if tx >= 0.0:
		var tp := Vector2(ox + tx * TEX, oy + ty * TEX)
		_line(sheet, tp + Vector2(-6, 0), tp + Vector2(6, 0), Color(1, 0.9, 0.2), 2.0)
		_line(sheet, tp + Vector2(0, -6), tp + Vector2(0, 6), Color(1, 0.9, 0.2), 2.0)
	# 朝向箭头（顶部）：P → 右，E → 左
	var ay := oy - 4.0
	if side == "P":
		_line(sheet, Vector2(ox + TEX * 0.55, ay), Vector2(ox + TEX * 0.85, ay), Color(0.5, 0.8, 1), 2.0)
		_line(sheet, Vector2(ox + TEX * 0.85, ay), Vector2(ox + TEX * 0.78, ay - 3), Color(0.5, 0.8, 1), 2.0)
		_line(sheet, Vector2(ox + TEX * 0.85, ay), Vector2(ox + TEX * 0.78, ay + 3), Color(0.5, 0.8, 1), 2.0)
	else:
		_line(sheet, Vector2(ox + TEX * 0.45, ay), Vector2(ox + TEX * 0.15, ay), Color(0.5, 0.8, 1), 2.0)
		_line(sheet, Vector2(ox + TEX * 0.15, ay), Vector2(ox + TEX * 0.22, ay - 3), Color(0.5, 0.8, 1), 2.0)
		_line(sheet, Vector2(ox + TEX * 0.15, ay), Vector2(ox + TEX * 0.22, ay + 3), Color(0.5, 0.8, 1), 2.0)
	# 文本（纹理框下方）
	var lbl := Label.new()
	lbl.text = "%s %s [%s]\nfx=%s fy=%s tip=(%.2f,%.2f)" % [side, id, status, parts.get("fx", "-"), parts.get("fy", "-"), tx, ty]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1))
	lbl.position = Vector2(ox, oy + TEX + 4.0)
	sheet.add_child(lbl)


func _line(parent: Node2D, a: Vector2, b: Vector2, color: Color, w: float) -> void:
	var ln := Line2D.new()
	ln.points = PackedVector2Array([a, b])
	ln.default_color = color
	ln.width = w
	parent.add_child(ln)


func _rect(parent: Node2D, tl: Vector2, size: Vector2, color: Color) -> void:
	_line(parent, tl, tl + Vector2(size.x, 0), color, 1.0)
	_line(parent, tl + Vector2(size.x, 0), tl + size, color, 1.0)
	_line(parent, tl + size, tl + Vector2(0, size.y), color, 1.0)
	_line(parent, tl + Vector2(0, size.y), tl, color, 1.0)
