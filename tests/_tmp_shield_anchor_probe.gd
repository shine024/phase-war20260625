extends Node
## 敌方护盾罩贴图位置复现探针（临时工具，可删）：
## 真实 construct_unit 走完整卡格敌方呈现链（apply_card_grid_enemy_presentation →
## UnitFrameAnim/BossIdleAnim 帧动画挂载）+ add_shield，转储 Sprite 纹理实况与
## sync_foot_anchor 计算值，并拍屏目检罩底 vs 脚线。
## 运行（窗口化）：$GODOT --path . res://tests/_tmp_shield_anchor_probe.tscn

const DefaultCards = preload("res://data/default_cards.gd")

const SHOT_PATH := "res://.godot/agent_tools/shield_anchor_probe.png"


func _ready() -> void:
	await _wait_frames(20)
	var root_world := Node2D.new()
	root_world.name = "World"
	add_child(root_world)

	# 沙地底色一块，便于目检
	var bg := ColorRect.new()
	bg.color = Color(0.42, 0.36, 0.28)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	root_world.add_child(bg)

	# card=该单位真实卡（stats.platform_card_id 驱动卡面解析——塞错卡会渲染成别的单位）
	# 6 台 = boss/普通 两体型 × 三构图（grounded 现行 / dome_ring 弧与气泡同心 / concentric 全同心）
	var specs := [
		{"arch": "fut_arm_heavy_mech", "card": "fut_arm_heavy_mech", "x": 250.0, "label": "机甲普通", "elite": "", "comp": ""},
		{"arch": "fut_arm_heavy_mech", "card": "fut_arm_heavy_mech", "x": 900.0, "label": "机甲boss", "elite": "boss", "comp": ""},
	]
	for s: Dictionary in specs:
		var unit: Node2D = (load("res://scenes/units/construct_unit.tscn") as PackedScene).instantiate()
		root_world.add_child(unit)
		unit.position = Vector2(float(s.x), 420.0)
		var card: CardResource = DefaultCards.get_card_by_id(String(s.card))
		if card == null:
			card = DefaultCards.get_card_by_id("ww1_arm_ft17")
		var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, -1)
		unit.setup_with_enemy_visual(false, stats, String(s.arch))
		# 精英/头目威压乘区与真实产兵同源（presentation 内 ×1.2/×1.6）
		if String(s.elite) != "":
			unit.set_meta("elite_spawn_type", String(s.elite))
		unit.apply_card_grid_enemy_presentation()
		# 帧动画：真实链内 anim_id 命中时由 presentation 自动挂载（重装机甲卡 id 即动画 key）
		unit.add_shield(9999.0)
		await _wait_frames(6)
		var aura = unit.get("_shield_aura")
		if aura != null and is_instance_valid(aura):
			(aura as Node).set_meta("composition", String(s.comp))
		# 堡垒环置于受击态（内环+受击色才显示，便于逐层目检）
		var faura0 = unit.get("_fort_shield_aura")
		if faura0 != null and is_instance_valid(faura0):
			(faura0 as Node).set_meta("hit_boost", 1.0)
			unit.set("_fort_aura_hit_boost", 1.0)
		await _wait_frames(14)
		_dump(String(s.label), unit)

	await _wait_frames(30)
	_shot()
	print("[probe] DONE")
	get_tree().quit(0)


func _dump(label: String, unit: Node2D) -> void:
	var spr := unit.get_node_or_null("Sprite") as Sprite2D
	if spr == null:
		print("[probe][%s] no Sprite" % label)
		return
	var tex := spr.texture
	var path: String = tex.resource_path if tex != null else "<null>"
	var fh: float = float(tex.get_height()) if tex != null else 0.0
	var fn: String = String(path).get_file().get_basename()
	var ff: float = CardFootAnchors.get_foot_frac(fn)
	var aura = unit.get("_shield_aura")
	var aura_pos: Vector2 = (aura as Node2D).position if aura != null and is_instance_valid(aura) else Vector2.INF
	var driver: Node = spr.get_node_or_null("UnitFrameAnimDriver")
	# 真实脚线：扫当前帧 alpha 内容底缘（AtlasTexture → 从 atlas 提区域）
	var real_foot_frac := _scan_content_bottom_frac(tex)
	var s: float = absf(spr.scale.y)
	# centered 空间 frac(-0.5..0.5) → 世界 y：× canvas_h × scale；再加 offset（纹理空间×scale）
	var real_foot_world: float = real_foot_frac * fh * s + spr.offset.y * s if real_foot_frac > -9000.0 else NAN
	print("[probe][%s] tex=%s class=%s size=%s scale=%.3f spr.y=%.1f" % [
		label, path.right(46), tex.get_class() if tex != null else "-", str(tex.get_size()) if tex != null else "-",
		spr.scale.y, spr.position.y])
	print("    fn='%s' foot_frac=%.3f tex_h=%.1f aura_pos=%s driver=%s" % [
		fn, ff, fh * s, str(aura_pos), "yes" if driver != null else "no"])
	print("    真实脚线y=%.1f  vs aura_y=%.1f  偏差=%+.1f px (正=罩底低于脚)" % [
		real_foot_world, aura_pos.y, aura_pos.y - real_foot_world])


## 扫纹理内容底缘（返回 centered 空间 frac：内容底行中心相对画布中心，脚线=最下方不透明像素行；失败返回 -9999）
func _scan_content_bottom_frac(tex: Texture2D) -> float:
	if tex == null:
		return -9999.0
	var img: Image = null
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var src: Texture2D = at.atlas
		if src == null:
			return -9999.0
		img = src.get_image()
		if img != null:
			img = img.get_region(at.region)
	else:
		img = tex.get_image()
	if img == null:
		return -9999.0
	if img.is_compressed():
		img.decompress()
	var bottom := -1
	for y in range(img.get_height() - 1, -1, -1):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.05:
				bottom = y
				break
		if bottom >= 0:
			break
	if bottom < 0:
		return -9999.0
	# 纹理空间(0..h) → Sprite 居中空间(-0.5h..+0.5h)
	return (float(bottom) + 0.5) / float(img.get_height()) - 0.5


func _shot() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/agent_tools"))
	var img: Image = get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(SHOT_PATH)
		print("[probe] shot -> ", SHOT_PATH)


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
