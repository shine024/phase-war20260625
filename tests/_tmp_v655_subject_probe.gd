extends Node2D
## v6.55 尺寸链视觉探针：旧链（复现公式）vs 新链（真呈现层）同屏对比。
## 运行：窗口化godot打开本场景，1s 后自动截图到 .godot/subject_audit/probe_compare.png 并退出。
## 单位样本 = 实测倒挂最狠的几对 + 各兵种代表。

const CardGridUnitVisuals = preload("res://scripts/card_grid_unit_visuals.gd")
const CardFootAnchors = preload("res://data/card_foot_anchors.gd")
const UnitFrameAnim = preload("res://scripts/battle/unit_frame_anim.gd")
const DefaultCards = preload("res://data/default_cards.gd")

# id, 显示名
const UNITS := [
	["ww1_enfield", "李恩菲尔德班(步)"],
	["ww1_mark4", "马克IV坦克(甲)"],
	["mod_t90", "T-90(甲)"],
	["xeno_mimic", "拟时者(步怪)"],
	["ww2_arm_sherman", "谢尔曼(抠底)"],
	["ww1_105mm", "105mm炮(支)"],
	["cold_air_bomber", "图-95(空)"],
	["ww1_fort_pillbox", "碉堡(垒)"],
]

const OLD_KIND_ERA := {0: 0.72, 1: 1.10, 2: 0.78, 3: 1.05, 4: 1.40}  # era0 简化（探针样本 era0-3，取档位下沿）


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.42, 0.38, 0.31)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)
	var title := Label.new()
	title.text = "上排=旧链(画布x2复现)  下排=新链(身高锚定)   ·   标注=实测主体屏高px"
	title.position = Vector2(20, 8)
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)
	await _run()


func _run() -> void:
	var old_ground := 288.0
	var new_ground := 600.0
	for gy in [old_ground + 4.0, new_ground + 4.0]:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(30, gy), Vector2(1250, gy)])
		line.default_color = Color(0.2, 0.16, 0.1, 0.8)
		line.width = 2.0
		add_child(line)
	var x := 92.0
	for u in UNITS:
		_spawn_pair(String(u[0]), String(u[1]), x, old_ground, new_ground)
		x += 148.0
	_measure_and_shoot()


func _resolve_card(id: String) -> CardResource:
	var c: CardResource = DefaultCards.get_card_by_id(id)
	if c != null:
		return c
	c = CardGridUnitVisuals.resolve_card_for_archetype(id)
	if c != null:
		return c
	c = CardGridUnitVisuals.synthetic_card_for_archetype(id, {})
	return c


func _spawn_pair(id: String, disp: String, x: float, old_gy: float, new_gy: float) -> void:
	# —— 旧链复现（v6.55 前公式：内容宽归一 × KIND_ERA 档位 × 画布×2）——
	var key: String = UnitFrameAnim._resolve_key(id)
	if not key.is_empty():
		var old_tex: Texture2D = load("res://assets/effects/unit_anims/%s/sheet_idle.png" % key)
		if old_tex != null:
			var meta: Dictionary = UnitFrameAnim._load_json("res://assets/effects/unit_anims/%s/anim.json" % key)
			var fs: int = int(meta.get("frame_size", 256))
			var icon_fn: String = String(CardGridUnitVisuals.resolve_battle_icon_texture(_resolve_card(id), id, {}, true).resource_path).get_file().get_basename()
			var iw: float = CardFootAnchors.get_content_w_frac(icon_fn)
			var sc: float = 58.9 / maxf(1.0, iw * 512.0)
			var era: int = _era_of(id)
			sc *= float(OLD_KIND_ERA.get(era, 1.0))
			var at := AtlasTexture.new()
			at.atlas = old_tex
			at.region = Rect2(0, 0, fs, fs)
			var spr := Sprite2D.new()
			spr.texture = at
			spr.flip_h = true
			spr.position = Vector2(x, old_gy)
			spr.scale = Vector2(sc * 2.0, sc * 2.0)
			spr.offset = Vector2(0, _icon_foot_offset(icon_fn) * 0.5)
			spr.z_index = 10
			add_child(spr)
	# —— 新链（真呈现层）——
	var card := _resolve_card(id)
	var host := Node2D.new()
	host.position = Vector2(x, new_gy)
	add_child(host)
	var spr2 := Sprite2D.new()
	host.add_child(spr2)
	var tex: Texture2D = CardGridUnitVisuals.resolve_battle_icon_texture(card, id, {}, true)
	if tex != null:
		CardGridUnitVisuals.apply_battle_unit_presentation(host, spr2, card, tex, true, 1, null)
	# 名条（两行共用）
	for gy in [old_gy + 26.0, new_gy + 26.0]:
		var lbl := Label.new()
		lbl.text = disp
		lbl.position = Vector2(x - 62.0, gy)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(1, 0.95, 0.8)
		add_child(lbl)


func _era_of(id: String) -> int:
	for pair in [["ww1", 0], ["ww2", 1], ["cold", 2], ["mod", 3], ["fut", 4], ["xeno", 4]]:
		if id.begins_with(String(pair[0])):
			return int(pair[1])
	return 0


func _icon_foot_offset(fn: String) -> float:
	return -(0.5 - CardFootAnchors.get_foot_frac(fn)) * 512.0


func _measure_and_shoot() -> void:
	for i in range(40):
		await get_tree().process_frame
	# 实测每只 sprite 屏上主体高，标注在名条上方
	var lines: Array[String] = []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c is Sprite2D and (c as Sprite2D).texture != null:
				var spr := c as Sprite2D
				var img: Image = spr.texture.get_image()
				if img != null:
					if img.is_compressed():
						img.decompress()
					var used := _alpha_bbox(img)
					if used.size.x > 0:
						var h_px: float = used.size.y * absf(spr.scale.y)
						var lbl := Label.new()
						lbl.text = "%.0fpx" % h_px
						lbl.global_position = spr.global_position + Vector2(-18.0, -used.position.y * absf(spr.scale.y) - 26.0)
						lbl.add_theme_font_size_override("font_size", 13)
						lbl.modulate = Color(0.5, 1.0, 1.0) if spr.flip_h else Color(0.3, 1.0, 0.4)
						add_child(lbl)
						var tag := "新" if spr.get_parent() != self else "旧"
						lines.append("%s@%.0f:%.0f" % [tag, spr.global_position.x, h_px])
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.godot/subject_audit/probe_compare.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/subject_audit"))
	img.save_png(out)
	print("[probe] saved ", out, " heights=", ",".join(lines))
	await get_tree().process_frame
	get_tree().quit(0)


func _alpha_bbox(img: Image) -> Rect2i:
	var W := img.get_width()
	var H := img.get_height()
	var minx := W
	var miny := H
	var maxx := -1
	var maxy := -1
	for y in range(H):
		for x in range(W):
			if img.get_pixel(x, y).a > 0.05:
				if x < minx:
					minx = x
				if x > maxx:
					maxx = x
				if y < miny:
					miny = y
				if y > maxy:
					maxy = y
	if maxx < 0:
		return Rect2i()
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
