extends SceneTree
## tests/_tmp_batch5_save_restore_smoke.gd — 批次5（P1-4 存档损坏明示）验证
## 流程：slot 3 写入最小合法备份档 + 损坏主档 JSON → load_game()
## 断言：① 返回 true（备份 fallback 成功）② save_restored_from_backup 信号发出（slot=3）
## 注：不走 save_game（其 DEFERRED 延迟窗口在 --script 模式下不落盘），直接手写文件
## 只验证 fallback 判定与信号链——档内容合法性由 _load_from_path 对空段的默认值兜底。
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_batch5_save_restore_smoke.gd

var _signal_slot: int = -1
var _signal_count: int = 0

func _initialize() -> void:
	var errs: Array[String] = []
	var sm: Node = root.get_node("SaveManager")
	if sm == null:
		_print_fail(["SaveManager autoload 缺失"])
		return

	var slot := 3
	var prev_slot: int = int(sm.get_slot())
	sm.set_slot(slot)
	var main_path: String = "user://save_slot_%d.json" % slot
	var backup_path: String = "user://save_slot_%d_backup.json" % slot

	# ① 最小合法备份档（schema v8 空段——manager load_state 走默认值）
	var bf := FileAccess.open(backup_path, FileAccess.WRITE)
	bf.store_string('{"schema_version": 8}')
	bf.close()
	# ② 损坏主档（JSON 解析必败且非 inf/nan 可修复形态）
	var cf := FileAccess.open(main_path, FileAccess.WRITE)
	cf.store_string('{"schema_version": 8, "BROKEN')
	cf.close()

	# ③ 接信号 + 读档（SignalBus 经 root 取——裸 autoload 标识符在 --script 编译期不可用）
	var sb: Node = root.get_node("SignalBus")
	sb.save_restored_from_backup.connect(func(s: int):
		_signal_slot = s
		_signal_count += 1
	, CONNECT_ONE_SHOT)
	var loaded: bool = sm.load_game()
	if not loaded:
		errs.append("备份 fallback 应成功，实际失败")
	if _signal_count != 1 or _signal_slot != slot:
		errs.append("信号未按预期发出: count=%d slot=%d" % [_signal_count, _signal_slot])

	# 清理：删除测试槽位文件 + 恢复原槽位
	for p in [main_path, backup_path, "user://save_slot_%d.json.tmp" % slot]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	sm.set_slot(prev_slot)

	if errs.is_empty():
		print("BATCH5 CHECK: ALL PASS (fallback ok + signal emitted)")
		quit(0)
	else:
		_print_fail(errs)
		quit(1)

func _print_fail(errs: Array) -> void:
	for e in errs:
		printerr("FAIL: " + String(e))
