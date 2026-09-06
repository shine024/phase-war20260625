# v27 黑门彼岸氛围层加载冒烟（无 GdUnit 依赖）
# 验证：endless_rift_ambience.gd / endless_blackgate_manager / 截图工具在 --script
#       模式（无 autoload）下可编译加载；氛围层可实例化；渗度公式对账。
# ⚠️ 本模式不可 load battlefield.gd / .gdshader——它们（传递）preload 了 shader 资源，
#    --script 模式下会触发引擎 quit 关停挂死（2026-09-06 实测，窗口模式无此问题）。
#    battlefield.gd 编译验证由实机截图运行 + --check-only 兜底覆盖。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_rift_fx_load_check.gd
extends SceneTree


func _initialize() -> void:
	var code := [0]
	var fail := func(msg: String) -> void:
		push_error("[RiftFxCheck][FAIL] " + msg)
		code[0] = 1

	var amb = load("res://scripts/battle/endless_rift_ambience.gd")
	if amb == null:
		fail.call("endless_rift_ambience.gd 加载失败")
	else:
		print("  ✓ endless_rift_ambience.gd 编译通过")
		var node = amb.new()
		if node == null:
			fail.call("氛围层实例化失败")
		else:
			# 挂树触发进入树流程（稀疏环境：无 autoload/战场父节点，验证守卫分支不炸）
			root.add_child(node)
			# --script 模式 _initialize 阶段 add_child 不派发 _ready，手动补跑全链
			if not node.is_node_ready():
				node._ready()
			# z_index 约定：背景(-10)/半场着色(-9) 之上、槽位高亮(-2)/单位(0) 之下
			if node.z_index != -8:
				fail.call("z_index 期望 -8，实际 %d" % node.z_index)
			else:
				print("  ✓ 氛围层 _ready 全链跑通，z_index=-8")
			node.free()

	var shot = load("res://tests/_tmp_ui_battle_shot.gd")
	if shot == null:
		fail.call("_tmp_ui_battle_shot.gd 加载失败")
	else:
		print("  ✓ 截图工具编译通过")

	# 静态渗度公式对账（每 10 波 +1、封顶 5）
	var EndlessMgr = load("res://managers/endless_blackgate_manager.gd")
	for pair in [[0, 0], [1, 0], [9, 0], [10, 1], [25, 2], [50, 5], [100, 5]]:
		var got: int = EndlessMgr.depth_for_waves(int(pair[0]))
		if got != int(pair[1]):
			fail.call("depth_for_waves(%d) 期望 %d 实际 %d" % [pair[0], pair[1], got])
	print("  ✓ depth_for_waves 渗度映射对账通过")

	if code[0] == 0:
		print("[RiftFxCheck] ALL PASS")
	else:
		print("[RiftFxCheck] FAILED")
	quit(code[0])
