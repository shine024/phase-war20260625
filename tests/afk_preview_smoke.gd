# 无 GdUnit 依赖的快速校验：AFKPanel._refresh_battle_preview 不再报
# "Invalid assignment of property 'region_enabled'"。
# region 错误是运行时属性错误，--check-only 抓不到，必须实际调用函数。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/afk_preview_smoke.gd
extends SceneTree

class _MockAFKManager extends RefCounted:
	var is_running: bool = true


func _initialize() -> void:
	var code := 0
	var packed = load("res://scenes/ui/afk_panel.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("afk_panel.tscn load failed")
		quit(1)
		return
	var panel = packed.instantiate()
	root.add_child(panel)  # 触发 _ready / @onready

	# mock 挂机运行态 + 真实 SubViewport（带尺寸让 atlas 分支命中）
	panel._afk_manager = _MockAFKManager.new()
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 580)
	root.add_child(vp)
	panel._battle_viewport = vp

	# 旧代码此处报 Invalid assignment 'region_enabled'（TextureRect 无此属性）
	panel._refresh_battle_preview()

	var tex = panel.battle_preview.texture
	if not (tex is AtlasTexture):
		push_error("expected battle_preview.texture to be AtlasTexture, got %s" % str(tex))
		code = 1
	else:
		print("afk_preview_smoke: OK — _refresh_battle_preview ran, texture=AtlasTexture region=%s" % str(tex.region))

	vp.queue_free()
	panel.queue_free()
	quit(code)
