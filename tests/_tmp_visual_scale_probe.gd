extends SceneTree
## _tmp 战场视觉校准探针（v6.14.8 内容感知缩放模型目检用）
## 批量渲染 全部玩家卡 + 全部敌形原型，每个单位：
##   绿框=内容 bbox（扫描）｜红线十字=标注开火点｜黑横线=地面线（脚线）
##   单位按新模型缩放（内容宽归一 × 兵种档位系数）
## 输出：.godot/agent_tools/scale_probe_p*.png（玩家）/ scale_probe_e*.png（敌形）
##      .godot/agent_tools/scale_probe_report.txt（逐单位 id/kind/内容占比/缩放/内容屏宽）
## 用法：godot --path . --script tests/_tmp_visual_scale_probe.gd（需窗口渲染，勿 --headless）

const CardGridUnitVisuals = preload("res://scripts/card_grid_unit_visuals.gd")
const CardGridThumbnailScale = preload("res://scripts/card_grid_thumbnail_scale.gd")
const CardFootAnchors = preload("res://data/card_foot_anchors.gd")
const PlayerMuzzleAnchors = preload("res://data/player_muzzle_anchors.gd")
const MuzzleAnchors = preload("res://data/muzzle_anchors.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const GC = preload("res://resources/game_constants.gd")

const CELL_W := 150.0
const CELL_H := 205.0
const COLS := 8
const ROWS := 5
const BASELINE_IN_CELL := 168.0
const VP_W := 1240
const VP_H := 1080

var _report: PackedStringArray = []


func _initialize() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(VP_W, VP_H)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	root.add_child(sv)

	var units_p := _collect_player()
	var units_e := _collect_enemy()
	var sheet_idx := 0
	for tag in [["p", units_p], ["e", units_e]]:
		var list: Array = tag[1]
		var per := COLS * ROWS
		var n_sheets := int(ceil(float(list.size()) / float(per)))
		for s in range(n_sheets):
			var sheet := _build_sheet(list, s * per, mini((s + 1) * per, list.size()))
			sv.add_child(sheet)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = sv.get_texture().get_image()
			var path := "res://.godot/agent_tools/scale_probe_%s%d.png" % [tag[0], sheet_idx]
			img.save_png(ProjectSettings.globalize_path(path))
			print("SAVED ", path)
			sheet_idx += 1
			sv.remove_child(sheet)
			sheet.queue_free()
			await process_frame
	_write_report()
	quit(0)


func _collect_player() -> Array:
	var out: Array = []
	for c in DefaultCards.create_all():
		if c == null or int(c.card_type) != int(GC.CardType.COMBAT_UNIT):
			continue
		out.append({"id": String(c.card_id), "card": c, "is_player": true})
	return out


func _collect_enemy() -> Array:
	var out: Array = []
	for row in EnemyUnitManifest.get_entries():
		var id := String(row.get("archetype_id", row.get("id", "")))
		if id.is_empty():
			continue
		# 与真实管线同口径：enemy_unit 用 synthetic 卡走 get_visual_scale(card)
		out.append({"id": id, "card": CardGridUnitVisuals.synthetic_card_for_archetype(id, {}), "is_player": false})
	return out


func _build_sheet(units: Array, from: int, to: int) -> Node2D:
	var sheet := Node2D.new()
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.18, 0.20)
	bg.size = Vector2(VP_W, VP_H)
	sheet.add_child(bg)
	for i in range(from, to):
		var idx := i - from
		var cx := (float(idx % COLS) + 0.5) * CELL_W + 20.0
		var cy := float(idx / COLS) * CELL_H + BASELINE_IN_CELL
		_add_unit(sheet, units[i], Vector2(cx, cy))
	return sheet


func _add_unit(sheet: Node2D, u: Dictionary, pos: Vector2) -> void:
	var id: String = u["id"]
	var card = u["card"]
	var is_player: bool = u["is_player"]
	var tex: Texture2D = null
	if is_player:
		tex = UiAssetLoader.battle_tex_for_path(UiAssetLoader.card_icon_path_for(card), card)
	else:
		var p: String = EnemyUnitManifest.get_unit_icon_path_for_archetype(id, false)
		tex = UiAssetLoader.battle_tex_for_path(p, null)
	if tex == null:
		_report.append("%s\tNO_TEX" % id)
		return
	# 与 apply_battle_unit_presentation 同口径：内容宽归一 × 档位系数
	var spr := Sprite2D.new()
	CardGridUnitVisuals.apply_uniform_card_sprite(spr, tex, false)
	var vs: float = CardFootAnchors.get_visual_scale(card)
	if vs > 0.0 and vs != 1.0:
		spr.scale *= vs
	spr.position = pos
	sheet.add_child(spr)
	var s: float = absf(spr.scale.y)
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	# 地面线（脚线）
	_line(sheet, pos + Vector2(-CELL_W * 0.48, 0.0), pos + Vector2(CELL_W * 0.48, 0.0), Color(0, 0, 0, 0.85), 2.0)
	# 内容 bbox（绿）：竖向按脚/头锚点精确，横向按内容宽居中近似
	var fn: String = CardFootAnchors.file_name_of(tex)
	var ff: float = CardFootAnchors.get_foot_frac(fn)
	var hf: float = CardFootAnchors.get_head_frac(fn)
	var wf: float = CardFootAnchors.get_content_w_frac(fn)
	var top_y: float = (ff + hf - 1.0) * th * s
	var box_h: float = maxf((1.0 - ff - hf) * th * s, 1.0)
	var box_w: float = wf * tw * s
	var tl := pos + Vector2(-box_w * 0.5, top_y)
	_rect(sheet, tl, Vector2(box_w, box_h), Color(0.3, 1.0, 0.3, 0.8), 1.0)
	# 标注开火点（红十字）
	var fire_off := Vector2.ZERO
	if is_player:
		fire_off = PlayerMuzzleAnchors.get_fire_offset(id, spr)
	else:
		fire_off = MuzzleAnchors.get_fire_offset(id, spr)
	if fire_off != Vector2.ZERO:
		var fp := pos + fire_off
		_line(sheet, fp + Vector2(-5, 0), fp + Vector2(5, 0), Color(1, 0.15, 0.15), 2.0)
		_line(sheet, fp + Vector2(0, -5), fp + Vector2(0, 5), Color(1, 0.15, 0.15), 2.0)
	# 标签（id + 缩放 + 兵种×时代 + 内容屏宽）
	var kind: int = int(card.get("combat_kind")) if card != null else EnemyUnitManifest.combat_kind_for(id)
	var era: int = int(card.get("era")) if card != null and int(card.get("era")) >= 0 else EnemyUnitManifest.era_for(id)
	var lbl := Label.new()
	lbl.text = "%s\n×%.2f k%de%d w=%.0f" % [id, vs, kind, era, box_w]
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	lbl.position = pos + Vector2(-CELL_W * 0.48, -BASELINE_IN_CELL + 4.0)
	sheet.add_child(lbl)
	_report.append("%s\tkind=%d\tera=%d\tcf=%.3f\tvs=%.2f\tw_px=%.0f\th_px=%.0f\tfire=%s" % [
		id, kind, era, wf, vs, box_w, box_h, str(fire_off != Vector2.ZERO)])


func _line(parent: Node2D, a: Vector2, b: Vector2, color: Color, w: float) -> void:
	var ln := Line2D.new()
	ln.points = PackedVector2Array([a, b])
	ln.default_color = color
	ln.width = w
	parent.add_child(ln)


func _rect(parent: Node2D, tl: Vector2, size: Vector2, color: Color, w: float) -> void:
	_line(parent, tl, tl + Vector2(size.x, 0), color, w)
	_line(parent, tl + Vector2(size.x, 0), tl + size, color, w)
	_line(parent, tl + size, tl + Vector2(0, size.y), color, w)
	_line(parent, tl + Vector2(0, size.y), tl, color, w)


func _write_report() -> void:
	var f := FileAccess.open("res://.godot/agent_tools/scale_probe_report.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_report))
		f.close()
	print("PROBE_DONE units=%d report=scale_probe_report.txt" % _report.size())
