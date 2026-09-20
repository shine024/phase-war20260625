extends SceneTree
## v26.x: unit_outline.gdshader 像素级断言（uniform 数学检查之外的真渲染验证）。
## ⚠️ 必须非 headless 跑（--headless 是 dummy renderer，出不了真实像素）：
##   godot --path . --rendering-driver opengl3 --script tests/_tmp_outline_pixel_check.gd
##
## 验证两点（修复前双双 FAIL——历史上 fragment() 入口 COLOR 已含纹理色，
## 再乘 COLOR 会把纹理二次叠乘：外扩描边带 alpha 归零 + 不透明像素 rgb²）：
##   1. 中心不透明像素不被平方：0.5 灰应输出 ≈0.5（bug 版 = 0.25）
##   2. 外扩描边带真的着色：白底上一圈暗边（bug 版 alpha=0 → 透出白底 1.0）
##   3. 控制点：取样距离外保持白底（膨胀不越界）

var _frames := 0
var _vp: SubViewport


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(128, 128)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color(1.0, 1.0, 1.0)
	bg.size = Vector2(128, 128)
	_vp.add_child(bg)
	# 64² 贴图：中心 32² 不透明 0.5 灰方块（texel 16..47），四周透明边距。
	# 挂载后贴图覆盖 world (32,32)-(96,96)，不透明区 = world (48,48)-(80,80)。
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	img.fill_rect(Rect2i(16, 16, 32, 32), Color(0.5, 0.5, 0.5, 1.0))
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.position = Vector2(64, 64)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/unit_outline.gdshader")
	mat.set_shader_parameter("edge_texels", 6.0)
	mat.set_shader_parameter("region_uv", Vector4(0.0, 0.0, 1.0, 1.0))
	spr.material = mat
	_vp.add_child(spr)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 10:
		return  # 等 SubViewport 渲染稳定（前进程刚退出时首帧可能未就绪，多等防偶发）
	var img := _vp.get_texture().get_image()
	var fails := 0
	# 1. 中心不透明像素（world 64,64）：0.5 灰不被平方
	var center: float = img.get_pixel(64, 64).r
	if absf(center - 0.5) <= 0.08:
		print("  ✅ PASS: 中心 0.5 灰输出 %.3f（未平方）" % center)
	else:
		print("  ❌ FAIL: 中心 0.5 灰输出 %.3f（期望≈0.50，≈0.25=纹理被二次叠乘）" % center)
		fails += 1
	# 2. 外扩描边带（world 44,64 = 不透明左缘 x=48 外 4px，edge_texels=6 取样可达）
	var outline: float = img.get_pixel(44, 64).r
	if outline < 0.55:
		print("  ✅ PASS: 描边带着色 %.3f（白底 1.0 → 暗边可见）" % outline)
	else:
		print("  ❌ FAIL: 描边带 %.3f（≈1.0=外扩描边 alpha 归零，根本没画出来）" % outline)
		fails += 1
	# 3. 控制点（world 40,64 = 缘外 8px > 取样半径）：应保持白底
	var far_side: float = img.get_pixel(40, 64).r
	# 4. 控制点（world 36,36 = 离方块角 17px）：应保持白底
	var far_corner: float = img.get_pixel(36, 36).r
	if far_side > 0.9 and far_corner > 0.9:
		print("  ✅ PASS: 膨胀不越界（控制点 %.3f / %.3f 保持白底）" % [far_side, far_corner])
	else:
		print("  ❌ FAIL: 膨胀越界（控制点 %.3f / %.3f，期望 >0.9）" % [far_side, far_corner])
		fails += 1
	print("=== 汇总: %s ===" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
