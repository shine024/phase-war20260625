extends SceneTree
## _tmp 敌方卡图朝向审计：内容上带（头/武器区）alpha 质心偏侧筛查。
## 纪律：敌方原图朝左（敌左我右）。上带质心偏右（>0.56）= 疑似朝右，违例候选。
## 输出：.godot/agent_tools/facing_audit.txt（全量 frac 排序）+ 候选清单打印
## 跑法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_facing_audit.gd

const CardFootAnchors = preload("res://data/card_foot_anchors.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const ALPHA_THRESH := 0.08


func _initialize() -> void:
	var rows := []
	for row in EnemyUnitManifest.get_entries():
		var id := String(row.get("archetype_id", ""))
		if id.is_empty():
			continue
		var path: String = EnemyUnitManifest.get_unit_icon_path_for_archetype(id, false)
		var base: String = String(path).get_file().get_basename()
		var wf := CardFootAnchors.get_content_w_frac(base)
		var ff := CardFootAnchors.get_foot_frac(base)
		var hf := CardFootAnchors.get_head_frac(base)
		if wf <= 0.0:
			continue
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		var l := int((1.0 - wf) * 0.5 * float(w))
		var r := int((1.0 - (1.0 - wf) * 0.5) * float(w))
		# 上带：内容顶部起 35% 高（头/炮塔/武器区）
		var y0 := int(hf * float(h))
		var y1 := int((hf + 0.35 * maxf(1.0 - ff - hf, 0.1)) * float(h))
		var sum := 0.0
		var wsum := 0.0
		var y := y0
		while y <= y1:
			var x := l
			while x <= r:
				if img.get_pixel(x, y).a > ALPHA_THRESH:
					sum += float(x)
					wsum += 1.0
				x += 2
			y += 2
		if wsum < 20.0:
			continue
		var frac := ((sum / wsum) - float(l)) / maxf(wf * float(w), 1.0)
		rows.append([frac, id])
	rows.sort()
	lines_out(rows)
	quit(0)


var txt := ""


func lines_out(rows: Array) -> void:
	var flagged := []
	for r in rows:
		txt += "%.3f\t%s\n" % [r[0], r[1]]
		if r[0] > 0.56:
			flagged.append(r)
	var f := FileAccess.open("res://.godot/agent_tools/facing_audit.txt", FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	print("FACING_AUDIT_DONE total=%d right_facing=%d" % [rows.size(), flagged.size()])
	for r in flagged:
		print("  RIGHT? %.3f %s" % [r[0], r[1]])
