extends RefCounted
## v37.3 战法件单位贴花挂载 helper（唯一挂载口）。
## 铁律：只往单位根下加兄弟 Sprite2D，**不直写 unit_spr.texture/scale**——v26.9 描边契约零触发。
## 敌我同构：我方读 card.mods、敌方读 get_meta("loadout_mods")；offset.x 与方向性贴花
## 对敌方自动镜像（敌方卡图朝左，enemy_unit.gd _suppress 同源节点纪律不受影响）。
## 性能：每单位最多 2 枚静态 Sprite2D，仅形象件命中时存在；极速推演无需压制（静态贴图）。

const DecalData = preload("res://data/mod_visual_decals.gd")

const _PREFIX := "ModDecal_"
## 内容包围盒缓存（贴图路径 → 局部坐标 Rect）：卡图透明边不参与计量，
## 贴花尺寸/锚点一律按"不透明像素 bbox"算（4px 采样，每贴图只算一次）
static var _bbox_cache: Dictionary = {}


static func _content_bounds(body: Sprite2D) -> Rect2:
	var tex := body.texture
	var path := tex.resource_path
	if path != "" and _bbox_cache.has(path):
		return _bbox_cache[path]
	var rect := body.get_rect()
	var bounds := rect
	var img := tex.get_image()
	if img != null:
		img.decompress()
		var w: int = img.get_width()
		var h: int = img.get_height()
		var lo_x := w
		var lo_y := h
		var hi_x := -1
		var hi_y := -1
		var y := 0
		while y < h:
			var x := 0
			while x < w:
				if img.get_pixel(x, y).a > 0.06:
					if x < lo_x: lo_x = x
					if x > hi_x: hi_x = x
					if y < lo_y: lo_y = y
					if y > hi_y: hi_y = y
				x += 4
			y += 4
		if hi_x >= 0:
			bounds = Rect2(lo_x, lo_y, hi_x - lo_x + 4, hi_y - lo_y + 4)
	if path != "":
		_bbox_cache[path] = bounds
	return bounds


static func mods_to_ids(mods: Array) -> Array:
	var ids: Array = []
	for m in mods:
		if m is Dictionary:
			ids.append(String(m.get("id", "")))
		else:
			ids.append(String(m))
	return ids


static func apply(unit: Node2D, mod_ids: Array, is_enemy: bool, _retry := 0) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	clear(unit)
	var decal_ids := DecalData.decals_for_mods(mod_ids)
	if decal_ids.is_empty():
		return
	var body := _resolve_body_sprite(unit)
	if body == null:
		# 立绘可能晚一帧配置（setup 内异步换图）——短延迟重入，至多 2 次
		if _retry < 2:
			var tree := unit.get_tree()
			if tree != null:
				tree.create_timer(0.05).timeout.connect(
					func() -> void: apply(unit, mod_ids, is_enemy, _retry + 1))
		return
	var tex_size := body.get_rect().size
	var bounds := _content_bounds(body)
	# bbox 中心相对贴图中心的局部偏移（Sprite2D centered：贴图中心即 body.position）
	var center_off := (bounds.get_center() - tex_size * 0.5) * body.scale
	var size_s: Vector2 = (bounds.size * body.scale).abs()
	if size_s.x <= 1.0 or size_s.y <= 1.0:
		return
	# v37.3b 钳制：贴花世界宽 ≤ 立绘当前画布世界宽×1.5——立绘若在挂载后被演出/形态
	# 切换重定时，竞态残留最多轻微偏大，不再可能渲染成"半个战场"级失控尺寸。
	var decal_cap_w: float = tex_size.x * absf(body.scale.x) * 1.5
	var mirror: float = -1.0 if is_enemy else 1.0
	for d_id in decal_ids:
		var cfg: Dictionary = DecalData.DECALS[d_id]
		var tex: Texture2D = load(String(cfg["tex"]))
		if tex == null:
			continue
		var spr := Sprite2D.new()
		spr.name = _PREFIX + d_id
		spr.texture = tex
		spr.modulate = Color(1, 1, 1, float(cfg["alpha"]))
		var s: float = size_s.x * float(cfg["w"]) / float(tex.get_width())
		var world_w: float = float(tex.get_width()) * s
		if world_w > decal_cap_w:
			s *= decal_cap_w / world_w
		spr.scale = Vector2(s, s)
		if bool(cfg["dir"]) and is_enemy:
			spr.flip_h = true
		var off: Vector2 = cfg["off"]
		var pos: Vector2
		match String(cfg["type"]):
			"foot":
				pos = center_off + Vector2(size_s.x * off.x * mirror, size_s.y * (0.5 + off.y))
			"mast", "side":
				pos = center_off + Vector2(size_s.x * off.x * mirror, size_s.y * off.y)
			_:  # drape
				pos = center_off + Vector2(0.0, size_s.y * off.y)
		spr.position = body.position + pos
		spr.z_index = 2
		spr.show_behind_parent = false
		unit.add_child(spr)


static func clear(unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	for c in unit.get_children():
		if c is Node and String(c.name).begins_with(_PREFIX):
			c.queue_free()


static func _resolve_body_sprite(unit: Node2D) -> Sprite2D:
	for path in ["Sprite", "Sprite2D"]:
		var spr := unit.get_node_or_null(path) as Sprite2D
		if spr != null and spr.texture != null:
			return spr
	if "_idle_spr" in unit:
		var cached: Sprite2D = unit.get("_idle_spr")
		if cached != null and is_instance_valid(cached) and cached.texture != null:
			return cached
	return null
