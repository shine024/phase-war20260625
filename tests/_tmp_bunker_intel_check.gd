extends SceneTree
## v26.12 基地房间情报补全——快速验证（无 GdUnit 依赖，几秒出结果）
## 覆盖：bunker_room_defs 新增三个情报函数 + overlay/panel 两脚本可编译
## 用法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_bunker_intel_check.gd

func _init() -> void:
	var defs := load("res://data/bunker_room_defs.gd")
	# lambda 按值捕获标量（v4.5 语义）——计数/失败列表装字典/数组按引用传递
	var state := {"total": 0, "fail": []}
	var check := func(name: String, cond: bool):
		state["total"] += 1
		if not cond:
			state["fail"].append(name)
		print(("PASS  " if cond else "FAIL  ") + name)

	# ── 升级行 ──
	var l2: String = defs.upgrade_line("weather_station", 2)
	print("  upgrade_line L2: ", l2)
	check.call("upgrade_line 含 Lv2 与成本", l2.begins_with("Lv2") and "纳米" in l2)
	check.call("upgrade_line 越档返回空", defs.upgrade_line("weather_station", 4) == "")
	check.call("无升级档房间空行", defs.upgrade_line("monument", 2) == "")

	# ── 升级线预览 ──
	var prev: String = defs.upgrade_lines_preview("weather_station")
	print("  preview: ", prev)
	check.call("preview 含 Lv2/Lv3", "Lv2" in prev and "Lv3" in prev)
	check.call("preview 无升级档为空", defs.upgrade_lines_preview("monument") == "")

	# ── 悬停情报三态 ──
	var locked: String = defs.hover_tooltip_text("archive", defs.STATE_LOCKED, 1, false, "")
	print("  locked: ", locked.replace("\n", " | "))
	check.call("锁定含修复需求", "修复需" in locked)
	check.call("锁定含功能预告", "修复后：" in locked and "情报中心" in locked)
	check.call("锁定含升级线", "Lv2 分析仪" in locked)
	var rep: String = defs.hover_tooltip_text("archive", defs.STATE_REPAIRING, 1, false, "", 0.5)
	check.call("修复中含进度+功能", "50%" in rep and "修复后：" in rep)
	var frozen_rep: String = defs.hover_tooltip_text("comms", defs.STATE_REPAIRING, 1, true, "")
	check.call("冻结提示", "冻结" in frozen_rep)
	var terminal: String = defs.hover_tooltip_text("observatory", defs.STATE_LOCKED, 1, false, "")
	check.call("终局房短文案", terminal.begins_with("终局房间"))
	var active: String = defs.hover_tooltip_text("depot", defs.STATE_ACTIVE, 1, false, "")
	print("  active: ", active.replace("\n", " | "))
	check.call("运转中含功能+升级预告", "打印" in active and "▲ 可升级" in active)
	var active_lv2: String = defs.hover_tooltip_text("depot", defs.STATE_ACTIVE, 2, false, "")
	check.call("Lv2 预告 Lv3", "· Lv2" in active_lv2 and "Lv3" in active_lv2)
	var maxed: String = defs.hover_tooltip_text("depot", defs.STATE_ACTIVE, 3, false, "")
	check.call("满级无升级预告", "▲ 可升级" not in maxed and "Lv3" in maxed)
	var upging: String = defs.hover_tooltip_text("depot", defs.STATE_ACTIVE, 1, false, "▲ 升级中 40%")
	check.call("升级中给目标档", "目标：Lv2" in upging and "40%" in upging)

	# ── 两个 UI 脚本可编译 ──
	# 注意：--script 模式不注册 autoload，panel 里既有的 SignalBus 引用会编译报错
	# （改动前就存在，报错行 _make_button）——此处只做软校验，硬校验靠 gdparse +
	# 编译器"只报 autoload 标识符"这一事实（新增标识符有错会一并报出）。
	var overlay_s: GDScript = load("res://scenes/bunker/bunker_room_overlay.gd")
	check.call("编译 overlay（无 autoload 引用）", overlay_s != null)
	var panel_s: GDScript = load("res://scenes/bunker/ui/bunker_room_panel.gd")
	print("  panel 加载: %s（null=仅 autoload 模式差异，非本轮回归）" % (panel_s != null))

	if state["fail"].is_empty():
		print("ALL PASS (%d checks)" % int(state["total"]))
		quit(0)
	else:
		print("FAILED %d/%d: %s" % [state["fail"].size(), int(state["total"]),
			", ".join(state["fail"])])
		quit(1)
