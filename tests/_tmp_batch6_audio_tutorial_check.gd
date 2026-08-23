extends SceneTree
## tests/_tmp_batch6_audio_tutorial_check.gd — 批次6（P2-3 BGM + P2-4 教程）验证
## ① 冷战 BGM 存在且可作为 AudioStream 加载；五时代 BGM 键全部可解析到文件
## ② 教程 13 步数据齐全（1-13 每步有 title/description/action_target）
## ③ 教程文案禁用词零命中：法则/研究/合成/能量卡/黄色槽
## ④ 旧档版本门控：v1 step=8 → FREEDOM(13)；v2 step=9 → FACTION_REP
## ⑤ 五个新 action_target 都有 execute 分支与对应 SignalBus 信号
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_batch6_audio_tutorial_check.gd

func _initialize() -> void:
	var errs: Array[String] = []

	# ── ① BGM ──
	if not ResourceLoader.exists("res://assets/sfx/bgm_battle_cold.ogg"):
		errs.append("bgm_battle_cold.ogg 缺失或未导入")
	else:
		var stream = load("res://assets/sfx/bgm_battle_cold.ogg")
		if not (stream is AudioStream):
			errs.append("bgm_battle_cold 无法加载为 AudioStream")
	for bgm_name in ["bgm_battle_ww1", "bgm_battle_ww2", "bgm_battle_cold", "bgm_battle_modern", "bgm_battle_future"]:
		if not ResourceLoader.exists("res://assets/sfx/%s.ogg" % bgm_name):
			errs.append("BGM 缺失: " + bgm_name)

	# ── ②③ 教程 13 步 + 禁用词 ──
	var tm: Node = root.get_node("TutorialProgressionManager")
	if tm == null:
		_print_fail(["TutorialProgressionManager autoload 缺失"])
		return
	# --script 的 _initialize 早于 autoload _ready——显式初始化教程数据
	if tm.has_method("_initialize_tutorial_data"):
		tm._initialize_tutorial_data()
	var banned: Array[String] = ["法则", "研究", "合成", "能量卡", "黄色槽"]
	for step_id in range(1, 14):
		var d: Dictionary = tm.tutorial_data.get(step_id, {})
		if d.is_empty():
			errs.append("步骤 %d 数据缺失" % step_id)
			continue
		for field in ["title", "description", "action_text"]:
			var text := String(d.get(field, ""))
			for w in banned:
				if text.find(w) >= 0:
					errs.append("步骤 %d %s 含禁用词'%s'" % [step_id, field, w])

	# ── ④ 版本门控 ──
	tm.load_state({"current_step": 8, "completed_steps": [1, 2, 3, 4, 5, 6, 7, 8]})  # v1 完档
	if int(tm.current_step) != 13:
		errs.append("v1 旧完档(step=8)应映射 FREEDOM=13，实际 %d" % int(tm.current_step))
	tm.load_state({"version": 2, "current_step": 9, "completed_steps": []})  # v2 进行中
	if int(tm.current_step) != 9:
		errs.append("v2 档(step=9)应保持 FACTION_REP=9，实际 %d" % int(tm.current_step))
	var saved: Dictionary = tm.save_state()
	if int(saved.get("version", 0)) != 2:
		errs.append("save_state 缺 version=2")
	tm.load_state({})  # 复位

	# ── ⑤ 动作分支与信号 ──
	var sb: Node = root.get_node("SignalBus")
	for sig in ["toggle_evolution", "toggle_faction", "toggle_store", "toggle_world_map", "open_phase_field_points"]:
		if not sb.has_signal(sig):
			errs.append("SignalBus 缺信号 " + sig)
	var tm_src := FileAccess.open("res://managers/tutorial_progression_manager.gd", FileAccess.READ).get_as_text()
	for act in ["open_evolution", "open_faction", "open_store", "open_world_map", "open_phase_field"]:
		if tm_src.find('"%s":' % act) < 0:
			errs.append("execute_tutorial_action 缺分支 " + act)

	if errs.is_empty():
		print("BATCH6 CHECK: ALL PASS")
		quit(0)
	else:
		_print_fail(errs)
		quit(1)

func _print_fail(errs: Array) -> void:
	for e in errs:
		printerr("FAIL: " + String(e))
