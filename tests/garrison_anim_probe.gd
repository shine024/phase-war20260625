extends SceneTree
## 临时探针：相位师编成 36 平台单位 → UnitFrameAnim._resolve_key 真链核对
## 定位用户实机反馈"相位师敌方卡有些单位分帧动画错误"

func _initialize() -> void:
	var ufa := load("res://scripts/battle/unit_frame_anim.gd")
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/json/enemy_phase_masters.json")).get("data", [])
	var plats: Array[String] = []
	for m: Dictionary in data:
		for p: Variant in m.get("equipment", {}).get("platforms", []):
			var s := String(p)
			if not plats.has(s):
				plats.append(s)
	print("=== %d 相位师平台单位 ===" % plats.size())
	for uid in plats:
		var key := String(ufa.call("_resolve_key", uid))
		var manifest_fb := ""
		if key.is_empty():
			manifest_fb = String(load("res://data/enemy_unit_manifest.gd").call("visual_id_for_archetype", uid))
		print("%s -> '%s'%s" % [uid, key, ("" if key != "" else "  [miss→visual_id:'%s'→%s]" % [manifest_fb, ("HIT" if not manifest_fb.is_empty() and ResourceLoader.exists("res://assets/effects/unit_anims/%s/sheet_idle.png" % manifest_fb) else "MISS")])])
	quit(0)
