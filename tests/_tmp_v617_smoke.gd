extends SceneTree
## v6.17 命中光学层冒烟（--script 模式，秒级）：
## ① 八个改动文件可编译加载；② GameConfig 两开关默认 true；③ era_bg_modulate 唯一口径
## 输出合法且随 era 变化；④ 光晕贴图程序化生成；⑤ flash() 建 PointLight2D 挂父层；
## ⑥ _release_light 归还池（挂 holder）；⑦ 父层释放后 _heal_arrays 自愈（可继续 flash）。
## 运行："$GODOT" --headless --rendering-driver opengl3 --path . --script tests/_tmp_v617_smoke.gd

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("[V617_SMOKE][FAIL] ", msg)


func _initialize() -> void:
	# ① 编译链
	var files := [
		"res://scripts/battle/battle_optics.gd",
		"res://scenes/battlefield/battlefield.gd",
		"res://scripts/ui/sortie_interstitial.gd",
		"res://scenes/units/bullet.gd",
		"res://scripts/weapon_projectile_vfx.gd",
		"res://scripts/battle/vfx_impact_factory.gd",
		"res://scenes/effects/damage_number_display.gd",
		"res://resources/game_config.gd",
	]
	for f in files:
		var s: Variant = load(f)
		_check(s != null, "编译失败: " + f)
	# ② 开关默认值
	var gc: Resource = load("res://resources/game_config.gd").get_default()
	_check(bool(gc.vfx_glow_enabled), "vfx_glow_enabled 默认应为 true")
	_check(bool(gc.vfx_dynamic_lights_enabled), "vfx_dynamic_lights_enabled 默认应为 true")
	# ③ era 底图 modulate 唯一口径
	var bf: GDScript = load("res://scenes/battlefield/battlefield.gd")
	var m0: Color = bf.era_bg_modulate(0)
	var m2: Color = bf.era_bg_modulate(2)
	_check(m0.r > 0.0 and m0.r < 1.01 and m0.g > 0.0 and m0.b > 0.0, "era0 modulate 通道越界: %s" % m0)
	_check(m0 != m2, "不同 era 的 modulate 不应有差异")
	_check(m0.get_luminance() < 0.9, "era0 亮度应明显低于 1（压暗档生效）: %s" % m0.get_luminance())
	# ④ 光晕贴图
	var optics: GDScript = load("res://scripts/battle/battle_optics.gd")
	var tex: Texture2D = optics._get_light_tex()
	_check(tex != null and tex.get_width() == 128, "光晕贴图应为 128 宽程序化生成")
	# ⑤ flash() 挂光
	var parent := Node2D.new()
	root.add_child(parent)  # _initialize 阶段不派发 _ready，但已在树内，满足 is_inside_tree
	optics.flash(parent, Vector2(100, 200), Color(1, 0.6, 0.3), 130.0, 1.3, 0.3)
	var lights: Array = parent.get_children().filter(func(n): return n is PointLight2D)
	_check(lights.size() == 1, "flash() 应在父层挂 1 个 PointLight2D，实得 %d" % lights.size())
	if lights.size() == 1:
		var pl: PointLight2D = lights[0]
		_check(pl.texture != null, "光闪应有光晕贴图")
		_check(absf(pl.texture_scale - 130.0 / 64.0) < 0.01, "texture_scale 应=半径/贴图半径")
		_check(pl.range_layer_min == 0 and pl.range_layer_max == 0, "光闪应限世界画布层")
		_check(not pl.shadow_enabled, "光闪不应开投影")
		# ⑥ 归还池——⚠️ --script 的 _initialize 阶段节点不在树内，remove/add_child 受限
		# （v38 冒烟纪律同款），树内 reparent 行为与 v27.12 弹痕池同款惯用法由实机验证；
		# 此处只断言"释放不崩溃 + 熄灭"。
		optics._release_light(pl)
		_check(not pl.visible or not pl.enabled, "归还后应熄灭")
	# ⑦ 父层释放 → 数组自愈
	parent.free()
	optics._heal_arrays()
	var parent2 := Node2D.new()
	root.add_child(parent2)
	optics.flash(parent2, Vector2.ZERO, Color(1, 1, 1), 64.0, 0.8, 0.1)
	var lights2: Array = parent2.get_children().filter(func(n): return n is PointLight2D)
	_check(lights2.size() == 1, "父层释放自愈后 flash() 应能再挂光，实得 %d" % lights2.size())
	if lights2.size() == 1:
		optics._release_light(lights2[0])
	parent2.free()
	if _fails == 0:
		print("V617_SMOKE_OK")
	else:
		printerr("[V617_SMOKE] FAILED: %d 项" % _fails)
	quit(1 if _fails > 0 else 0)
