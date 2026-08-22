extends SceneTree
## tests/_tmp_batch1_main_boot_smoke.gd — 批次1（P0-4+P0-5）验证②
## main.tscn headless boot → 就绪后再跑 300 帧，脚本层主动退出。
## "零错误"判定在进程层：bash 捕获 stdout/stderr，grep ERROR/SCRIPT ERROR 无命中才算过。
## 用法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_batch1_main_boot_smoke.gd

var _phase := 0
var _frame := 0
var _waited := 0

func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		0:
			change_scene_to_file("res://scenes/main.tscn")
			_phase = 1
			_frame = 0
		1:
			_waited += 1
			var main: Node = root.get_node_or_null("/root/Main")
			var gm: Node = root.get_node_or_null("/root/GameManager")
			if main != null and gm != null and gm.get("battle_scene") != null:
				_phase = 2
				_frame = 0
			elif _waited > 1200:
				printerr("[boot-smoke] FAIL: 主场景 1200 帧未就绪")
				quit(1)
				return true
		2:
			if _frame >= 300:
				print("[boot-smoke] OK: main boot + 300 帧完成")
				quit(0)
				return true
	return false
