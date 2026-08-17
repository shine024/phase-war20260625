extends SceneTree
## 2026-08-17 性能修复验证（P0-1 / P0-2 / P1 三项，不依赖 autoload）
## 运行：Godot_console.exe --headless --rendering-driver opengl3 --path . --script tests/perf_fix_verify_20260817.gd

func _init() -> void:
	var pass_cnt := 0
	var fail_cnt := 0

	# ── P0-2 前提验证：stretch 容器入树改写 ALWAYS 后，补设 UPDATE_ONCE 是否保留 ──
	var host := Node.new()
	var svc := SubViewportContainer.new()
	svc.stretch = true
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	svc.add_child(vp)
	host.add_child(svc)
	root.add_child(host)
	await process_frame
	await process_frame
	var rewritten: bool = vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS
	print("[VPFIX] 容器入树后改写为 ALWAYS: ", rewritten, "（预期 true，复现问题）")
	if rewritten:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE  # 模拟 main.gd 修复补设
	await create_timer(1.0).timeout
	var kept: bool = vp.render_target_update_mode == SubViewport.UPDATE_ONCE
	print("[VPFIX] 补设 UPDATE_ONCE 1秒后保留: ", kept, "（期望 true）")
	if kept:
		pass_cnt += 1
	else:
		fail_cnt += 1
	host.queue_free()

	# ── P0-1 / P1 语法验证：三个改动文件能否编译（P0-1 修复前 bullet.gd 是 Parse Error）──
	var targets := {
		"res://scenes/units/bullet.gd": "P0-1",
		"res://scenes/ui/intelligence_hub_panel.gd": "P1",
		"res://scenes/ui/evolution_atlas_view.gd": "P1",
	}
	for path: String in targets:
		var scr = load(path)
		var ok: bool = scr != null
		print("[%s] %s 编译: %s" % [targets[path], path.get_file(), "OK" if ok else "FAIL"])
		if ok:
			pass_cnt += 1
		else:
			fail_cnt += 1

	# ── P1 逻辑验证：EvolutionAtlasView 分帧构建（入树 → 首帧批次 → 数帧内清空队列）──
	var atlas_ctrl: Control = load("res://scenes/ui/evolution_atlas_view.gd").new()
	root.add_child(atlas_ctrl)  # _ready → _build_ui + refresh（分帧启动）
	for i in range(30):
		await process_frame
		if atlas_ctrl.get("_pending_entries").is_empty():
			break
	var pending_left: int = atlas_ctrl.get("_pending_entries").size()
	var entries_built: int = atlas_ctrl.get("_unit_entries").size()
	print("[P1] atlas 分帧完成: pending剩余=%d（期望0）, 已建条目=%d（期望>0）" % [pending_left, entries_built])
	if pending_left == 0 and entries_built > 0:
		pass_cnt += 1
	else:
		fail_cnt += 1
	atlas_ctrl.queue_free()

	print("[RESULT] PASS=%d FAIL=%d" % [pass_cnt, fail_cnt])
	quit(1 if fail_cnt > 0 else 0)
