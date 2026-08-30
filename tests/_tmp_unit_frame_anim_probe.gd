extends SceneTree
## 探针 v2: 雪碧图版帧动画 —— 编译/key解析/AtlasTexture/scale补偿/开火切换

func _init() -> void:
	var ufa := load("res://scripts/battle/unit_frame_anim.gd")
	if ufa == null:
		push_error("unit_frame_anim.gd load FAIL")
		quit(1)
		return
	print("unit_frame_anim compile OK")
	var key = ufa._resolve_key("foe_mod_inf_scout_drone")
	var key2 = ufa._resolve_key("ww2_tiger")
	print("resolve drone->'", key, "'  tiger->'", key2, "'")
	# 静态底图 512² 模拟（真实链路: apply_uniform_card_sprite 先上静态卡图, attach 最后）
	var pt := PlaceholderTexture2D.new()
	pt.size = Vector2i(512, 512)
	var spr := Sprite2D.new()
	spr.texture = pt
	spr.scale = Vector2(0.5, 0.5)
	spr.offset = Vector2(0.0, -20.0)
	root.add_child(spr)
	await process_frame
	var attached: bool = ufa.attach(spr, "foe_mod_inf_scout_drone")
	print("attach:", attached)
	await process_frame
	await process_frame
	var drv = spr.get_node_or_null("UnitFrameAnimDriver")
	print("driver:", drv != null)
	var tex_ok: bool = spr.texture is AtlasTexture
	if tex_ok:
		var at: AtlasTexture = spr.texture
		print("AtlasTexture region:", at.region, " frame_w:", spr.texture.get_width())
	var comp_ok: bool = is_equal_approx(spr.scale.x, 1.0)  # 0.5 × (512/256)
	print("scale after compensate:", spr.scale, " offset.y:", spr.offset.y)
	var offset_ok: bool = is_equal_approx(spr.offset.y, -10.0)  # -20 × (256/512)
	ufa.notify_fire(spr)
	await process_frame
	var mode_ok: bool = drv != null and String(drv._mode) == "attack"
	# v24.2: 我方镜像路径 — 直接用卡 id(无 foe_ 前缀) + face_right=true → flip_h
	var spr2 := Sprite2D.new()
	spr2.texture = pt
	root.add_child(spr2)
	await process_frame
	var attached2: bool = ufa.attach(spr2, "mod_inf_scout_drone", true)
	var drv2 = spr2.get_node_or_null("UnitFrameAnimDriver")
	var flip_ok: bool = attached2 and drv2 != null and spr2.flip_h
	# v25: 空中垂直动态合成 — _air_dy 高度补偿 + 俯冲 tween
	var cgv := load("res://scripts/card_grid_unit_visuals.gd")
	var air := Sprite2D.new()
	air.texture = pt
	root.add_child(air)
	air.set_meta("_air_lift", 40.0)
	air.set_meta("_air_dy", 40.0)  # 起飞起点：地面
	air.set_meta("_idle_params", {"base_y": -40.0, "amp": 4.0, "half": 1.0, "t": 0.0})
	cgv.advance_idle_motion(air, 0.016)
	var ground_y: float = air.position.y  # 应≈0（巡航-40 + 补偿+40 - 浮动微差）
	air.set_meta("_air_dy", 0.0)
	cgv.advance_idle_motion(air, 0.016)
	var cruise_y: float = air.position.y  # 应≈-40
	cgv.fire_lunge_sprite(air, false, true)  # 俯冲投弹（重武器）
	var dive_ok: bool = air.has_meta("_air_vert_tw") and air.has_meta("_air_dy")
	var air_ok: bool = absf(ground_y) < 8.0 and absf(cruise_y + 40.0) < 8.0 and dive_ok
	print("air: ground_y=%.1f cruise_y=%.1f dive=%s" % [ground_y, cruise_y, dive_ok])
	var ok: bool = key == "mod_inf_scout_drone" and key2 == "ww2_tiger" \
			and attached and drv != null and tex_ok and comp_ok and offset_ok and mode_ok \
			and flip_ok and air_ok
	if ok:
		print("PROBE PASS")
	else:
		print("PROBE FAIL  flip_ok=", flip_ok, " air_ok=", air_ok)
	quit(0 if ok else 1)
