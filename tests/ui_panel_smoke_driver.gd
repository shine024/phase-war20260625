extends Node
## UI 面板全量冒烟驱动（作为主场景 headless 运行，autoload 齐全）：
##   godot --headless --path . res://tests/ui_panel_smoke_driver.tscn
## 逐个 load + instantiate + add_child（2帧）+ free 全部 scenes/ui/*.tscn。
## 面板脚本报错会以 "SCRIPT ERROR" 打到 stderr（含脚本路径），事后按输出定位。
## 本驱动自身只打 [TEST]/[DONE] 进度标记。

const UI_DIR := "res://scenes/ui"
const FRAME_SETTLE := 2

var _scenes: Array[String] = []
var _idx: int = 0
var _fails: Array[String] = []

func _ready() -> void:
	print("=== UI PANEL SMOKE DRIVER START ===")
	print("root children at boot: %d" % get_tree().root.get_child_count())
	_collect_scenes()
	print("discovered %d .tscn" % _scenes.size())
	# 等首帧稳定（autoload deferred init）
	await get_tree().process_frame
	_next()

func _collect_scenes() -> void:
	var dir := DirAccess.open(UI_DIR)
	if dir == null:
		push_error("cannot open %s" % UI_DIR)
		return
	_walk(dir, UI_DIR)

func _walk(dir: DirAccess, base: String) -> void:
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var full := base.path_join(fname)
		if dir.current_is_dir() and not fname.begins_with("."):
			var sub := DirAccess.open(full)
			if sub:
				_walk(sub, full)
		elif fname.ends_with(".tscn"):
			_scenes.append(full)
		fname = dir.get_next()
	dir.list_dir_end()
	_scenes.sort()

func _next() -> void:
	if _idx >= _scenes.size():
		_finish()
		return
	var path: String = _scenes[_idx]
	_idx += 1
	print("[TEST] %s" % path)
	var packed: PackedScene = null
	packed = load(path)
	if packed == null:
		print("[FAIL] %s -> load() null" % path)
		_fails.append(path)
		call_deferred("_next")
		return
	var node: Node = packed.instantiate()
	if node == null:
		print("[FAIL] %s -> instantiate() null" % path)
		_fails.append(path)
		call_deferred("_next")
		return
	add_child(node)  # 触发 _ready（deferred 逻辑再等帧）
	for i in FRAME_SETTLE:
		await get_tree().process_frame
	node.queue_free()
	await get_tree().process_frame
	print("[DONE] %s" % path)
	call_deferred("_next")

func _finish() -> void:
	print("\n===== SMOKE SUMMARY =====")
	if _fails.is_empty():
		print("ALL PASS: %d scenes (hard-fail 0)" % _scenes.size())
	else:
		print("HARD FAIL %d / %d:" % [_fails.size(), _scenes.size()])
		for f in _fails:
			print("  %s" % f)
	print("=== UI PANEL SMOKE DRIVER END ===")
	get_tree().quit(1 if not _fails.is_empty() else 0)
