extends SceneTree
## v6.31b（记录4 答#6/#7 落地）冒烟：shield 脚线自适应 + AFK 部署埋点。
## --script 模式无 autoload：只做编译级 load + 方法存在性 + 纯数据断言。

var _fail := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok  ", label)
	else:
		_fail += 1
		printerr("  FAIL", label)

func _initialize() -> void:
	print("== v6.31b smoke ==")

	# ── 1) 编译级加载 ──
	for p in [
		"res://scripts/battle/fort_shield_aura.gd",
		"res://scenes/units/construct_unit.gd",
		"res://scripts/systems/afk_mode_manager.gd",
	]:
		var s: Script = load(p)
		_check(s != null and s.can_instantiate(), "load " + p)

	# ── 2) 记录4#6：aura sync_foot_anchor 存在+无 Sprite 回退原点 ──
	var aura_script: Script = load("res://scripts/battle/fort_shield_aura.gd")
	var aura: Node2D = aura_script.new()
	_check(aura.has_method("sync_foot_anchor"), "aura sync_foot_anchor exists")
	var host := Node2D.new()
	host.add_child(aura)  # 无 Sprite 子节点 → 回退原点
	aura.sync_foot_anchor()
	_check(aura.position == Vector2.ZERO, "no-sprite fallback origin (got %s)" % str(aura.position))
	# 带 Sprite 宿主：居中锚定、foot_frac=0（表外贴图）→ 脚线=+0.5×tex_h×scale
	var spr := Sprite2D.new()
	spr.name = "Sprite"  # sync_foot_anchor 按 "Sprite" 节点名取立绘
	spr.texture = ImageTexture.create_from_image(Image.create(40, 60, false, Image.FORMAT_RGBA8))
	spr.scale = Vector2(0.5, 0.5)
	host.add_child(spr)
	aura.sync_foot_anchor()
	var expect: float = 0.5 * 60.0 * 0.5  # (0.5-0)*tex_h*scale = 15.0
	_check(absf(aura.position.y - expect) < 0.01, "foot y = 0.5*tex_h*scale (got %s expect %s)" % [str(aura.position.y), str(expect)])
	aura.free()
	host.free()

	# ── 3) 记录4#7：AFM 部署链 TraceLog 埋点编译（load 已验），AFKM 实例化 ──
	var afk: Script = load("res://scripts/systems/afk_mode_manager.gd")
	_check(afk.new() != null, "AFKModeManager instantiable")

	print("V631B_SMOKE_OK" if _fail == 0 else "V631B_SMOKE_FAIL(%d)" % _fail)
	quit(1 if _fail > 0 else 0)
