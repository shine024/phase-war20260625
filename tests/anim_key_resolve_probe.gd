extends SceneTree
## 探针：敌方步枪班/玩家毛瑟 步枪班分帧动画挂载验证（v6.15b 步枪班动画修复）
## 用途：动画目录孤儿/映射链命中判定（见 AGENTS.md「动画部署 key 纪律」节）
## 验证点：
##   1. UnitFrameAnim._resolve_key("ww1_inf_rifle") = "ww1_mauser"（经 EnemyCardModMap 间接命中）
##   2. UnitFrameAnim._resolve_key("ww1_mauser") = "ww1_mauser"（玩家起始卡直连命中）
##   3. idle 8 帧 / attack 12 帧（anim.json counts）
##   4. is_outline_baked = true（预烘焙描边，运行期不再挂 shader）

var _checked := 0
var _failed := 0

func _check(name: String, ok: bool, detail: String = "") -> void:
	_checked += 1
	if ok:
		print("  PASS: ", name, " ", detail)
	else:
		_failed += 1
		printerr("  FAIL: ", name, " ", detail)

func _initialize() -> void:
	print("== rifle anim mount probe ==")
	var ufa := load("res://scripts/battle/unit_frame_anim.gd")
	_check("load unit_frame_anim.gd", ufa != null)
	if ufa == null:
		quit(0 if _failed == 0 else 1)
		return

	var key_enemy: String = String(ufa.call("_resolve_key", "ww1_inf_rifle"))
	_check("enemy ww1_inf_rifle resolves", key_enemy == "ww1_mauser", "-> '%s'" % key_enemy)
	var key_player: String = String(ufa.call("_resolve_key", "ww1_mauser"))
	_check("player ww1_mauser resolves", key_player == "ww1_mauser", "-> '%s'" % key_player)

	# 帧序列（镜像 attach() 的加载口径：json counts + _load_seq）
	var meta: Dictionary = ufa.call("_load_json", "res://assets/effects/unit_anims/ww1_mauser/anim.json")
	var counts: Dictionary = meta.get("counts", {})
	var fs: int = int(meta.get("frame_size", 256))
	var idle: Array = ufa.call("_load_seq", "ww1_mauser", "idle", int(counts.get("idle", 0)), fs)
	var atk: Array = ufa.call("_load_seq", "ww1_mauser", "attack", int(counts.get("attack", 0)), fs)
	_check("idle frames", idle.size() == 8, "n=%d" % idle.size())
	_check("attack frames", atk.size() == 12, "n=%d" % atk.size())
	var all_tex: bool = idle.size() > 0 and atk.size() > 0
	for t in idle:
		if t == null or not (t is Texture2D):
			all_tex = false
			break
	if all_tex:
		for t in atk:
			if t == null or not (t is Texture2D):
				all_tex = false
				break
	_check("all frames are Texture2D", all_tex)

	var baked: bool = bool(ufa.call("is_outline_baked", "ww1_inf_rifle"))
	var baked_p: bool = bool(ufa.call("is_outline_baked", "ww1_mauser"))
	_check("enemy baked outline", baked)
	_check("player baked outline", baked_p)

	print("== RESULT: checked=%d failed=%d ==" % [_checked, _failed])
	print("RIFLE_ANIM_PROBE_OK" if _failed == 0 else "RIFLE_ANIM_PROBE_FAILED")
	quit(0 if _failed == 0 else 1)
