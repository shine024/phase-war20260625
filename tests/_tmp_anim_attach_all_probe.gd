extends SceneTree
## v14 动画修复批 attach 全量探针（headless）：
##   1) 全库 anim.json 目录逐个走 UnitFrameAnim.attach 真身（挂载必须成功）
##   2) idle>=2 / attack 帧数==counts.attack / foot_frac 覆盖率
##   3) 专项断言：fut_inf_c96、ww1_arm_rolls 复活（原 counts 空=静默静止）
##   4) 别名表 ANIM_ALIAS 目标全部可达
## 输出 ANIMPROBE 行；任何 FAIL 退出码 1。

const UFA = preload("res://scripts/battle/unit_frame_anim.gd")

func _init() -> void:
	var root_path := "res://assets/effects/unit_anims"
	var dirs: Array[String] = []
	var d := DirAccess.open(root_path)
	if d == null:
		print("ANIMPROBE FAIL cannot open ", root_path)
		quit(1)
		return
	for name in d.get_directories():
		if FileAccess.file_exists(root_path + "/" + name + "/anim.json"):
			dirs.append(name)
	dirs.sort()
	var fails: Array[String] = []
	var foot_missing: Array[String] = []
	var attack_empty: Array[String] = []
	for key in dirs:
		var spr := Sprite2D.new()
		var meta: Dictionary = UFA._load_json(root_path + "/" + key + "/anim.json")
		var ok := UFA.attach(spr, key, false)
		if not ok:
			fails.append(key + ":attach=false")
			spr.free()
			continue
		var drv: Node = spr.get_node_or_null("UnitFrameAnimDriver")
		if drv == null:
			fails.append(key + ":no_driver")
			spr.free()
			continue
		var counts: Dictionary = meta.get("counts", {})
		if drv.idle_frames.size() < 2:
			fails.append(key + ":idle<2")
		if int(counts.get("attack", 0)) > 0 and drv.attack_frames.size() != int(counts["attack"]):
			fails.append(key + ":attack %d!=%d" % [drv.attack_frames.size(), int(counts["attack"])])
		if int(counts.get("attack", 0)) == 0:
			attack_empty.append(key)
		if float(meta.get("foot_frac", -1.0)) < 0.0:
			foot_missing.append(key)
		spr.free()
	# 专项：复活断言
	for key in ["fut_inf_c96", "ww1_arm_rolls"]:
		var spr := Sprite2D.new()
		if not UFA.attach(spr, key, false):
			fails.append(key + ":revive=false")
		else:
			var drv: Node = spr.get_node("UnitFrameAnimDriver")
			print("ANIMPROBE revive %s idle=%d attack=%d foot=%.4f" % [
				key, drv.idle_frames.size(), drv.attack_frames.size(),
				drv.sheet_foot_frac])
		spr.free()
	# 别名可达
	for id in UFA.ANIM_ALIAS.keys():
		if String(UFA._resolve_key(String(id))).is_empty():
			fails.append("alias:" + String(id))
	print("ANIMPROBE dirs=%d attach_ok=%d fail=%d foot_missing=%d attack_empty=%d" % [
		dirs.size(), dirs.size() - fails.size(), fails.size(),
		foot_missing.size(), attack_empty.size()])
	if not fails.is_empty():
		print("ANIMPROBE FAILS=", str(fails))
	if not foot_missing.is_empty():
		print("ANIMPROBE foot_missing=", str(foot_missing))
	if not attack_empty.is_empty():
		print("ANIMPROBE attack_empty=", str(attack_empty))
	quit(1 if not fails.is_empty() else 0)
