# v26.9 单位描边/投影/背景压暗 加载校验（无 GdUnit 依赖，--script 模式）
# 验证：
#   1) shaders/unit_outline.gdshader 可加载（语法解析）
#   2) UnitOutline.apply 幂等挂材质 + refresh 两项 uniform 数学正确：
#      - 整图：edge_texels = OUTLINE_PX/scale，region_uv=(0,0,1,1)
#      - AtlasTexture（雪碧图帧动画）：region_uv 收敛到当前帧 UV 区
#   3) air_unit_shadow 地面/悬空双模式 setup 不炸
#   4) card_grid_unit_visuals / unit_frame_anim / boss_idle_anim / battlefield 脚本链加载
#
# Usage: <godot> --headless --rendering-driver opengl3 --path . --script tests/_tmp_outline_check.gd
extends SceneTree

const UnitOutline = preload("res://scripts/battle/unit_outline.gd")
const AirUnitShadow = preload("res://scripts/battle/air_unit_shadow.gd")

var _fails: Array[String] = []


func _check(cond: bool, tag: String) -> void:
	if not cond:
		_fails.append(tag)
		print("  FAIL ", tag)
	else:
		print("  ok   ", tag)


func _approx(a: float, b: float, eps: float, tag: String) -> void:
	_check(absf(a - b) <= eps, "%s (%.4f vs %.4f)" % [tag, a, b])


func _initialize() -> void:
	print("== 1) shader 加载 ==")
	var sh: Shader = load("res://shaders/unit_outline.gdshader")
	_check(sh != null, "shader 资源加载非空")

	print("== 2) UnitOutline uniform 数学 ==")
	# 8x8 半透明圆点图当整图贴图
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(200, 200, 100, 100), Color(0.5, 0.5, 0.5, 1.0))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var spr := Sprite2D.new()
	get_root().add_child(spr)
	spr.texture = tex
	spr.scale = Vector2(0.115, 0.115)
	UnitOutline.apply(spr)
	var mat := spr.material as ShaderMaterial
	_check(mat != null and mat.shader == load("res://shaders/unit_outline.gdshader"), "apply 挂 ShaderMaterial")
	var opx: float = float(UnitOutline.OUTLINE_PX)
	_approx(float(mat.get_shader_parameter("edge_texels")), opx / 0.115, 0.01, "整图 edge_texels=OUTLINE_PX/scale")
	var reg: Vector4 = mat.get_shader_parameter("region_uv")
	_check(reg == Vector4(0, 0, 1, 1), "整图 region_uv=全幅")
	# 幂等：重复 apply 不换材质对象
	var mat_before: Material = spr.material
	UnitOutline.apply(spr)
	_check(spr.material == mat_before, "重复 apply 复用材质")

	# AtlasTexture：2 帧横条 1024x512，取第 2 帧
	var sheet_img := Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	sheet_img.fill(Color(0, 0, 0, 0))
	var sheet: ImageTexture = ImageTexture.create_from_image(sheet_img)
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(512, 0, 512, 512)
	spr.texture = at
	spr.scale = Vector2(0.23, 0.23)  # 模拟帧动画 scale×2 补偿后
	UnitOutline.refresh(spr)
	_approx(float(mat.get_shader_parameter("edge_texels")), opx / 0.23, 0.01, "雪碧图 edge_texels 随新 scale 重算")
	reg = mat.get_shader_parameter("region_uv")
	_approx(reg.x, 0.5, 0.001, "region_uv.x=帧起点 0.5")
	_approx(reg.z, 1.0, 0.001, "region_uv.z=帧终点 1.0")
	_check(reg.y == 0.0 and reg.w == 1.0, "region_uv.y/w 全高")
	# 无材质时 refresh 静默（不炸）
	var bare := Sprite2D.new()
	UnitOutline.refresh(bare)
	_check(true, "无材质 refresh 静默")

	print("== 3) AirUnitShadow 双模式 ==")
	var sh_ground: AirUnitShadow = AirUnitShadow.new()
	get_root().add_child(sh_ground)
	sh_ground.setup(60.0, true)
	_approx(sh_ground._rx, clampf(60.0 * 0.42, 14.0, 40.0), 0.01, "贴地影 rx=h*0.42")
	sh_ground.setup(60.0, false)
	_approx(sh_ground._rx, clampf(60.0 * 0.30, 16.0, 34.0), 0.01, "悬空影 rx=h*0.30")

	print("== 4) 改动脚本链加载 ==")
	for p in [
		"res://scripts/card_grid_unit_visuals.gd",
		"res://scripts/battle/unit_frame_anim.gd",
		"res://scripts/battle/boss_idle_anim.gd",
		"res://scenes/battlefield/battlefield.gd",
	]:
		var s: Script = load(p)
		_check(s != null and s.can_instantiate(), "load+parse: " + p)
	var bf: Script = load("res://scenes/battlefield/battlefield.gd")
	_check(bf.get_script_constant_map().has("BG_DIM"), "battlefield.BG_DIM 常量存在")

	print("")
	if _fails.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED: %d" % _fails.size())
		quit(1)
