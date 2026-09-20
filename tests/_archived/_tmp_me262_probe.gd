extends Node
## Me-262 确定性战场视觉探针——直接走 card_grid_unit_visuals 呈现链实拍，
## 不靠随机出兵抽卡。同框三机对照：Me-262（新图）/ 流星 F.3（同批管线）/ 斯图卡（v26 基线）。
## 跑法：godot --path . res://tests/_tmp_me262_probe.tscn（带窗，需渲染）

func _ready() -> void:
	var root := Node2D.new()
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.18, 0.20)
	bg.size = Vector2(1366, 768)
	root.add_child(bg)
	var ids := ["ww2_air_me262", "ww2_air_meteor_e", "ww2_air_dive_bomber"]
	for i in ids.size():
		var aid: String = ids[i]
		var card: CardResource = CardGridUnitVisuals.resolve_card_for_archetype(aid)
		var cfg: Dictionary = EnemyArchetypes.get_config(aid)
		var tex: Texture2D = CardGridUnitVisuals.resolve_battle_icon_texture(card, aid, cfg, false)
		var host := Node2D.new()
		var spr := Sprite2D.new()
		host.add_child(spr)
		root.add_child(host)
		var ok: bool = CardGridUnitVisuals.apply_battle_unit_presentation(host, spr, card, tex, false, 1)
		host.position = Vector2(280 + i * 400, 384)
		var path: String = tex.resource_path if tex != null else "null"
		var placeholder: bool = tex == null or not path.ends_with(aid + ".png")
		var lift: float = float(host.get_meta("air_lift_y", 0.0))
		print("[MeProbe] %s presented=%s tex=%s placeholder=%s scale=%.3f air_lift=%.1f" % [
			aid, ok, path.get_file(), placeholder, spr.scale.x, lift])
	# 等两帧让描边 shader/纹理 settle，再实拍
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.godot/agent_tools/me262_probe.png")
	print("[MeProbe] saved me262_probe.png")
	get_tree().quit()
