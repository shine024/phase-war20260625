extends SceneTree
## _tmp_extract_old_sheets_r19.gd —— 抢救 r19 五单位的旧部署 sheet
## 原理: 工作目录 sheet*.png 已被新卷覆盖且 PNG 不入 git; .godot/imported 里的
## ctex 仍是旧画 (本次未跑 --editor 重导入)。headless 非 editor 模式 load()
## 返回旧导入纹理, save_png 落审阅目录。用后即弃。
func _initialize():
	var units = ["ww2_sup_mg42", "ww2_pschreck", "cold_spetsnaz", "ww1_storm", "ww2_inf_panzerschrek"]
	for u in units:
		for kind in ["sheet_attack", "sheet_idle"]:
			var p = "res://assets/effects/unit_anims/%s/%s.png" % [u, kind]
			if not ResourceLoader.exists(p):
				print("MISS ", p)
				continue
			var tex = load(p)
			if tex == null or not (tex is Texture2D):
				print("NULL ", p)
				continue
			var img: Image = tex.get_image()
			var dir = "res://.godot/unit_review/flow_r19/review3/%s" % u
			DirAccess.make_dir_recursive_absolute(dir)
			var out = "%s/%s_old.png" % [dir, kind]
			img.save_png(out)
			print("OK ", p, " -> ", out, " ", img.get_size())
	quit()
