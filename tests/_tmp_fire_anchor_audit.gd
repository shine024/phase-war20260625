extends SceneTree
## _tmp 开火锚点 × 现役卡图 审计 v2（像素级）
## 几何筛查（OUT_X/OUT_Y/REAR/MISSING）+ 像素级两查：
##   FLOAT  = 标注点所在纹理列在该高度是透明区（十字浮在形体旁边，"略偏高"类错的实锤）
##   TIP    = 前端最突出非透明列的竖直中心（枪口尖候选），与标注差 >15% 图高时给建议值
## 输出：.godot/agent_tools/fire_audit.txt（全量，含 tip 候选）
##      .godot/agent_tools/fire_audit_flagged.txt（需人工/目检修正的单位 P|id / E|id）
## 跑法：godot --headless --rendering-driver opengl3 --script tests/_tmp_fire_anchor_audit.gd

const PlayerMuzzleAnchors = preload("res://data/player_muzzle_anchors.gd")
const MuzzleAnchors = preload("res://data/muzzle_anchors.gd")
const CardFootAnchors = preload("res://data/card_foot_anchors.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")

const ALPHA_THRESH := 0.08


func _initialize() -> void:
	var lines := PackedStringArray()
	var flagged := PackedStringArray()
	for c in DefaultCards.create_all():
		if c == null or int(c.card_type) != int(GC.CardType.COMBAT_UNIT):
			continue
		var id := String(c.card_id)
		var path := "res://assets/card_icons/player/%s.png" % id
		if not ResourceLoader.exists(path):
			var vis: String = EnemyUnitManifest.visual_id_for_archetype(id)
			if not vis.is_empty():
				path = "res://assets/card_icons/player/%s.png" % vis
		_audit_unit(lines, flagged, "P", id, path, PlayerMuzzleAnchors.get_anchor(id))
	for row in EnemyUnitManifest.get_entries():
		var id := String(row.get("archetype_id", ""))
		if id.is_empty():
			continue
		var path: String = EnemyUnitManifest.get_unit_icon_path_for_archetype(id, false)
		_audit_unit(lines, flagged, "E", id, path, MuzzleAnchors.get_anchor(id))
	var f := FileAccess.open("res://.godot/agent_tools/fire_audit.txt", FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	var f2 := FileAccess.open("res://.godot/agent_tools/fire_audit_flagged.txt", FileAccess.WRITE)
	f2.store_string("\n".join(flagged))
	f2.close()
	print("FIRE_AUDIT_DONE units=%d flagged=%d" % [lines.size(), flagged.size()])
	quit(0)


func _load_img(path: String) -> Image:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img != null and img.is_compressed():
		img.decompress()
	return img


func _audit_unit(lines: PackedStringArray, flagged: PackedStringArray, side: String, id: String, path: String, anchor: Dictionary) -> void:
	var base: String = String(path).get_file().get_basename()
	var wf := CardFootAnchors.get_content_w_frac(base)
	var ff := CardFootAnchors.get_foot_frac(base)
	var hf := CardFootAnchors.get_head_frac(base)
	if wf <= 0.0:
		lines.append("%s|%s|NO_SCAN|path=%s" % [side, id, path])
		return
	var l := (1.0 - wf) * 0.5
	var r := 1.0 - l
	var top := hf
	var bot := 1.0 - ff
	# ── 像素级：前端 tip 候选 + 标注列透明检查
	var img := _load_img(path)
	var tip_x := -1.0
	var tip_y := -1.0
	var float_flag := false
	var fx := -1.0
	var fy := -1.0
	if not anchor.is_empty():
		fx = float(anchor.get("fireX", 0.5))
		fy = float(anchor.get("fireY_pct", 50.0)) / 100.0
	if img != null:
		var w := img.get_width()
		var h := img.get_height()
		# 前端最突出非透明列（我方右缘/敌方左缘），tip=该列±2px 竖直 alpha 中心
		var x0 := int(l * float(w))
		var x1 := int(r * float(w)) - 1
		var tip_col := -1
		if side == "P":
			for x in range(x1, x0 - 1, -1):
				if _col_has_alpha(img, x, top, bot):
					tip_col = x
					break
		else:
			for x in range(x0, x1 + 1):
				if _col_has_alpha(img, x, top, bot):
					tip_col = x
					break
		if tip_col >= 0:
			var ys := _col_alpha_extent(img, tip_col, top, bot)
			var ys2 := _col_alpha_extent(img, clampi(tip_col + (1 if side == "P" else -1), 0, w - 1), top, bot)
			var y_lo: float = minf(ys.x, ys2.x)
			var y_hi: float = maxf(ys.y, ys2.y)
			tip_x = (float(tip_col) + 0.5) / float(w)
			tip_y = (y_lo + y_hi) * 0.5
		# 标注列透明检查：fx 列在 fy 高度是否透明（±0.5% 容差窗口）
		if fx >= 0.0:
			var cx := clampi(int(fx * float(w)), 0, w - 1)
			var ext := _col_alpha_extent(img, cx, 0.0, 1.0)
			if ext.y < 0.0:
				float_flag = true
			elif fy < ext.x - 0.015 or fy > ext.y + 0.015:
				float_flag = true
	var flags := PackedStringArray()
	var is_missing := anchor.is_empty()
	if is_missing:
		flags.append("MISSING")
	else:
		if fx < l - 0.02 or fx > r + 0.02:
			flags.append("OUT_X")
		if fy < top - 0.02 or fy > bot + 0.02:
			flags.append("OUT_Y")
		var front := fx if side == "P" else 1.0 - fx
		if front < 0.30:
			flags.append("REAR")
		if float_flag:
			flags.append("FLOAT")
		if tip_y >= 0.0 and absf(fy - tip_y) > 0.15:
			flags.append("TIP_OFF")
	var st := "OK" if flags.is_empty() else ",".join(flags)
	# v3: 像素吸附——标注点吸附到半径内最近非透明像素（卡图换血后的残差修正数据）
	var sx := fx
	var sy := fy
	if fx >= 0.0 and img != null:
		var snapped := _snap_to_alpha(img, fx, fy)
		sx = snapped.x
		sy = snapped.y
	var line := "%s|%s|st=%s|fx=%.3f|fy=%.3f|tx=%.3f|ty=%.3f|wf=%.3f|ff=%.3f|hf=%.3f|sx=%.4f|sy=%.4f" % [
		side, id, st, fx, fy, tip_x, tip_y, wf, ff, hf, sx, sy]
	lines.append(line)
	if not flags.is_empty():
		flagged.append("%s|%s" % [side, id])


## (fx, fy) 半径内最近非透明像素（比例坐标）；0.06 内找不到扩到 0.12、再 0.2，仍无则原样返回
func _snap_to_alpha(img: Image, fx: float, fy: float) -> Vector2:
	var w := img.get_width()
	var h := img.get_height()
	var cx := int(fx * float(w))
	var cy := int(fy * float(h))
	for radius_frac in [0.06, 0.12, 0.2]:
		var rx := int(radius_frac * float(w))
		var ry := int(radius_frac * float(h))
		var best := -1.0
		var bx := -1
		var by := -1
		for y in range(maxi(cy - ry, 0), mini(cy + ry, h - 1) + 1):
			for x in range(maxi(cx - rx, 0), mini(cx + rx, w - 1) + 1):
				if img.get_pixel(x, y).a > ALPHA_THRESH:
					var d := float((x - cx) * (x - cx) + (y - cy) * (y - cy))
					if best < 0.0 or d < best:
						best = d
						bx = x
						by = y
		if best >= 0.0:
			return Vector2((float(bx) + 0.5) / float(w), (float(by) + 0.5) / float(h))
	return Vector2(fx, fy)


func _col_has_alpha(img: Image, x: int, y_lo: float, y_hi: float) -> bool:
	var h := img.get_height()
	var a := int(y_lo * float(h))
	var b := int(y_hi * float(h))
	for y in range(maxi(a, 0), mini(b, h - 1) + 1):
		if img.get_pixel(x, y).a > ALPHA_THRESH:
			return true
	return false


## 列 x 在 [y_lo, y_hi]（纹理比例）内的 alpha 竖直范围，返回 (top, bottom) 比例；全透明返回 (-1,-1)
func _col_alpha_extent(img: Image, x: int, y_lo: float, y_hi: float) -> Vector2:
	var h := img.get_height()
	var y0 := -1
	var y1 := -1
	var a := int(y_lo * float(h))
	var b := int(y_hi * float(h))
	for y in range(maxi(a, 0), mini(b, h - 1) + 1):
		if img.get_pixel(x, y).a > ALPHA_THRESH:
			if y0 < 0:
				y0 = y
			y1 = y
	if y0 < 0:
		return Vector2(-1.0, -1.0)
	return Vector2(float(y0) / float(h), float(y1) / float(h))
