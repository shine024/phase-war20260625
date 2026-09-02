extends Node
## v24.2(挂机推图起点) 端到端临时验证：真 autoload + 真场景
## 覆盖：①推图起点跟随战役前沿 ②失败续推 off-by-one ③world_map override 优先
##       ④override 钳制到已解锁上限 ⑤选关器三态（✓通关/蓝未通关/灰未解锁）+ 搜索按裸关卡号
##       ⑥挂机面板推图起点显示
## 运行：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_afk_push_start_check.tscn
## 保留为可复跑验证件（tests/_tmp_* 惯例）。不触发存档（自建 AFK 实例，不连主场景）。

var _fail := 0

func _fail_msg(msg: String) -> void:
	_fail += 1
	push_error("[FAIL] " + msg)

func _ok(msg: String) -> void:
	print("  [OK] " + msg)

func _ready() -> void:
	print("═══ v24.2 挂机推图起点 + 选关器三态检查 ═══")
	var lp: Node = get_node_or_null("/root/LevelProgressManager")
	if lp == null or not lp.has_method("get_max_unlocked_level"):
		_fail_msg("LevelProgressManager autoload 不可用")
		_finish()
		return

	# 快照 LevelProgressManager 状态，结束后恢复（本测试不落盘，但防内存态污染）
	var snap := {
		"unlocked_levels": (lp.get("unlocked_levels") as Array).duplicate(),
		"level_stars": (lp.get("level_stars") as Dictionary).duplicate(),
		"first_completion": (lp.get("first_completion") as Dictionary).duplicate(),
		"max_unlocked_level": int(lp.get("max_unlocked_level")),
	}

	# 造战役进度：通关 1-49（first_completion+星级），解锁到 50
	var unlocked := []
	for i in range(1, 51):
		unlocked.append(i)
	lp.set("unlocked_levels", unlocked)
	lp.set("max_unlocked_level", 50)
	var stars := {}
	var fc := {}
	for i in range(1, 50):
		fc[i] = true
		stars[i] = 3 if i % 2 == 0 else 1
	lp.set("level_stars", stars)
	lp.set("first_completion", fc)

	var AFK = load("res://scripts/systems/afk_mode_manager.gd")
	var afk = AFK.new()
	afk.init(self, null)
	afk.set_mode(AFK.Mode.PUSH)

	# ── ① 战役前沿同步：push_level=1（旧档默认）+ max_unlocked=50 → 从 50 开打 ──
	afk.set("push_level", 1)
	if not afk.start_afk():
		_fail_msg("① start_afk 返回 false")
	else:
		if int(afk.get("push_level")) == 50:
			_ok("① push_level=1 + 战役前沿50 → 推图起点=50（不再从第1关打）")
		else:
			_fail_msg("① 推图起点=%d，期望 50" % int(afk.get("push_level")))
	afk.stop_afk()

	# ── ② 失败续推：push_level=49（失败关-1 回写值）→ 对齐到前沿 50，不再重刷已通关的 49 ──
	afk.set("push_level", 49)
	afk.start_afk()
	if int(afk.get("push_level")) == 50:
		_ok("② 失败续推 push_level=49 → 起点=50（修掉重打已通关关的 off-by-one）")
	else:
		_fail_msg("② 失败续推起点=%d，期望 50" % int(afk.get("push_level")))
	afk.stop_afk()

	# ── ③ world_map override：显式选 30（低于前沿）→ 精确从 30 开始 ──
	afk.set("push_level", 50)
	afk.set("push_start_override", 30)
	afk.start_afk()
	if int(afk.get("push_level")) == 30 and int(afk.get("push_start_override")) == 0:
		_ok("③ override=30 → 起点=30 且已消费（保住低级关刷本次语义）")
	else:
		_fail_msg("③ override 后起点=%d 残留=%d，期望 30/0" % [int(afk.get("push_level")), int(afk.get("push_start_override"))])
	afk.stop_afk()

	# ── ④ override 钳制：显式 99 > 已解锁上限 50 → 钳回 50 ──
	afk.set("push_start_override", 99)
	afk.start_afk()
	if int(afk.get("push_level")) == 50:
		_ok("④ override=99 → 钳制到已解锁上限 50")
	else:
		_fail_msg("④ override=99 钳制后起点=%d，期望 50" % int(afk.get("push_level")))
	afk.stop_afk()

	# ── ⑤ 选关器三态 ──
	var sel_packed: PackedScene = load("res://scenes/ui/afk_level_selector.tscn")
	if sel_packed == null:
		_fail_msg("⑤ afk_level_selector.tscn 加载失败")
	else:
		var sel: Control = sel_packed.instantiate()
		add_child(sel)
		await get_tree().process_frame
		# show_selector 形参要求 Control（self 是 Node），传哑 Control 即可（形参未消费）
		sel.show_selector(Control.new(), 0)
		var btns: Array = sel.get("_all_buttons")
		if btns.size() != 100:
			_fail_msg("⑤ 按钮数 %d != 100" % btns.size())
		else:
			# 通关关（2=有星）→ ✓ 前缀 + 可点 + tooltip 带星级
			var b2: Button = btns[1]
			if b2.text == "✓2" and not b2.disabled and b2.tooltip_text.contains("★"):
				_ok("⑤ 关2 已通关：文本=✓2 可点 tooltip 带★")
			else:
				_fail_msg("⑤ 关2 通关态异常 text=%s disabled=%s tip=%s" % [b2.text, str(b2.disabled), b2.tooltip_text])
			# 通关关（1=无星记录但 first_completion 有）→ ✓ 前缀
			var b1: Button = btns[0]
			if b1.text == "✓1" and not b1.disabled:
				_ok("⑤ 关1 已通关（first_completion 记录）：文本=✓1 可点")
			else:
				_fail_msg("⑤ 关1 通关态异常 text=%s disabled=%s" % [b1.text, str(b1.disabled)])
			# 已解锁未通关（50 = 前沿）→ 普通态可点
			var b50: Button = btns[49]
			if b50.text == "50" and not b50.disabled:
				_ok("⑤ 关50 已解锁未通关：普通态可点")
			else:
				_fail_msg("⑤ 关50 态异常 text=%s disabled=%s" % [b50.text, str(b50.disabled)])
			# 未解锁（51）→ 置灰禁点
			var b51: Button = btns[50]
			if b51.disabled and b51.tooltip_text.contains("未解锁"):
				_ok("⑤ 关51 未解锁：置灰禁点 + tooltip 说明")
			else:
				_fail_msg("⑤ 关51 未解锁态异常 disabled=%s tip=%s" % [str(b51.disabled), b51.tooltip_text])
			# 搜索：✓ 前缀不干扰精确匹配（旧实现读 text 会漏已通关关）
			sel.call("_on_search_changed", "2")
			if bool(btns[1].visible) and not bool(btns[11].visible):
				_ok("⑤ 搜索\"2\"只命中关2（✓前缀不干扰裸关卡号匹配）")
			else:
				_fail_msg("⑤ 搜索\"2\"命中异常 关2可见=%s 关12可见=%s" % [str(btns[1].visible), str(btns[11].visible)])
		sel.queue_free()

	# ── ⑥ 挂机面板推图起点显示 ──
	var panel_packed: PackedScene = load("res://scenes/ui/afk_panel.tscn")
	if panel_packed == null:
		_fail_msg("⑥ afk_panel.tscn 加载失败")
	else:
		var panel: Control = panel_packed.instantiate()
		add_child(panel)
		await get_tree().process_frame
		var panel_afk = AFK.new()
		panel_afk.init(self, null)
		panel_afk.set_mode(AFK.Mode.PUSH)
		panel_afk.set("push_level", 1)
		panel.call("set_afk_manager", panel_afk)
		var lbl: Label = panel.get_node_or_null("Panel/MarginContainer/MainVBox/StatsHBox/SlotsUsedLabel")
		if lbl != null and lbl.text == "推图起点: 第 50 关":
			_ok("⑥ 推图模式待机显示 起点:第 50 关（跟随战役前沿）")
		else:
			_fail_msg("⑥ 面板起点显示=%s，期望 \"推图起点: 第 50 关\"" % (lbl.text if lbl != null else "<无label>"))
		panel.queue_free()

	# 恢复 LevelProgressManager 内存态
	lp.set("unlocked_levels", snap["unlocked_levels"])
	lp.set("level_stars", snap["level_stars"])
	lp.set("first_completion", snap["first_completion"])
	lp.set("max_unlocked_level", snap["max_unlocked_level"])
	_finish()

func _finish() -> void:
	if _fail == 0:
		print("═══ ALL PASS ═══")
	else:
		print("═══ FAIL ×%d ═══" % _fail)
	get_tree().quit(_fail)
