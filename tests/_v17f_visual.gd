extends Node2D
## 一次性验证：五张弹体贴图按新 content-width 标定并排渲染，截图量宽。用后即删。
const VF = preload("res://scripts/battle/vfx_impact_factory.gd")
func _ready() -> void:
	var bg := ColorRect.new(); bg.color = Color(0.08, 0.08, 0.1); bg.size = Vector2(900, 300); add_child(bg)
	var ids := ["ult_meteor", "ult_void_orb", "ult_orbital", "ult_inferno_bomb", "ult_divine_spear"]
	var tws := [64.0, 64.0, 64.0, 56.0, 50.0]
	for i in range(ids.size()):
		var tex: Texture2D = load("res://assets/effects/ultimate_projectiles/%s.png" % ids[i])
		var sp := Sprite2D.new()
		sp.texture = tex
		var cw: float = float(VF.ULT_PROJ_CONTENT_W[ids[i]])
		var ms: float = tws[i] / cw
		sp.scale = Vector2(ms, ms)
		sp.position = Vector2(90 + i * 180, 150)
		add_child(sp)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://v17f_proj_check.png")
	print("[v17f] 截图完成 user://v17f_proj_check.png")
	get_tree().quit(0)
