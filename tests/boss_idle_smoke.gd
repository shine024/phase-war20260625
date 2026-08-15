extends SceneTree
## BossIdleAnim 帧动画冒烟测试: 帧资产可加载 + attach 生效
func _init() -> void:
	var boss_idle = load("res://scripts/battle/boss_idle_anim.gd")
	var all_ok := true
	for bid in ["cold_boss_mig", "fut_boss_nexus"]:
		for i in range(6):
			var p := "res://assets/effects/unit_anims/%s/idle_f%d.png" % [bid, i]
			if not ResourceLoader.exists(p):
				print("[SMOKE] MISSING ", p); all_ok = false
		var spr := Sprite2D.new()
		root.add_child(spr)
		var ok: bool = boss_idle.attach(spr, bid)
		var drv: Node = spr.get_node_or_null("BossIdleFrameDriver")
		print("[SMOKE] %s attach=%s driver=%s frames=%s" % [bid, ok, drv != null, drv.frames.size() if drv else 0])
		if not ok or drv == null or drv.frames.size() != 6:
			all_ok = false
	print("[SMOKE] ", "ALL PASS" if all_ok else "FAIL")
	quit(0 if all_ok else 1)
