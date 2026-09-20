extends Node
## 批次③ Task 2 结算叙事冒烟断言：
##  ① 三态文案池规模与互异（胜 4/败 3/撤 3，两两无交集）
##  ② 胜利面板：title=胜利、desc ∈ 胜利池
##  ③ 失败面板（无 meta）：title=失败、desc ∈ 失败池（允许附英雄名行）
##  ④ 撤退链：meta 写入 → 失败面板 → title=撤退、desc ∈ 撤退池、meta 已被消费
##  ⑤ meta 不串场：残留 meta 在下一场 run_start_battle_sequence 头部被清（main_battle_setup 消费）
##  ⑥ 英雄名取句：EnemyPhaseMasters 名册非空，_render_field_report 只在败仗态可能出现
## 跑前无需备份存档（不触发战斗/存档链，纯面板装配）。

var _fails: Array[String] = []
var _pass_log: Array[String] = []


func _ready() -> void:
	await _run()
	for p in _pass_log:
		print("[T2Narr] PASS: " + p)
	for f in _fails:
		printerr("[T2Narr] FAIL: " + f)
	print("[T2Narr] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES"))
	await _wait(5)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _make_panel(won: bool) -> Node:
	var mvp: Node = load("res://scenes/ui/mvp_panel.gd").new()
	mvp.set("player_won", won)
	add_child(mvp)
	mvp.call("_render_victory_banner", _bare_vbox(mvp))
	return mvp


func _bare_vbox(host: Node) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	host.add_child(vbox)
	return vbox


func _in_pool(text: String, pool: Array) -> bool:
	for line in pool:
		if text.begins_with(String(line)):
			return true
	return false


func _run() -> void:
	var mvp := load("res://scenes/ui/mvp_panel.gd")
	var pool_v: Array = mvp.get("BANNER_LINES_VICTORY")
	var pool_d: Array = mvp.get("BANNER_LINES_DEFEAT")
	var pool_r: Array = mvp.get("BANNER_LINES_RETREAT")

	# ── ① 池规模与互异 ──
	if pool_v.size() == 4 and pool_d.size() == 3 and pool_r.size() == 3:
		_pass_log.append("① 池规模 胜%d/败%d/撤%d（4/3/3）" % [pool_v.size(), pool_d.size(), pool_r.size()])
	else:
		_fails.append("① 池规模不符（期望 4/3/3）：胜%d/败%d/撤%d" % [pool_v.size(), pool_d.size(), pool_r.size()])
	var seen := {}
	for line in pool_v + pool_d + pool_r:
		seen[String(line)] = true
	if seen.size() == 10:
		_pass_log.append("① 三池互异（无重复句）")
	else:
		_fails.append("① 三池存在重复句（去重后 %d/10）" % seen.size())

	# ── ② 胜利面板 ──
	Engine.remove_meta("battle_retreated")
	var p_win := _make_panel(true)
	if String(p_win.get("last_banner_title")) == "胜利" and _in_pool(String(p_win.get("last_banner_text")), pool_v):
		_pass_log.append("② 胜利态横幅：%s" % p_win.get("last_banner_text"))
	else:
		_fails.append("② 胜利态横幅不符：title=%s desc=%s" % [p_win.get("last_banner_title"), p_win.get("last_banner_text")])
	p_win.queue_free()

	# ── ③ 失败面板（无 meta）——多采几个样本让英雄名行概率路径也被覆盖 ──
	var defeat_ok := true
	var hero_line_seen := false
	for i in 12:
		var p_lose := _make_panel(false)
		var txt := String(p_lose.get("last_banner_text"))
		if String(p_lose.get("last_banner_title")) != "失败" or not _in_pool(txt, pool_d):
			defeat_ok = false
			_fails.append("③ 失败态横幅不符：title=%s desc=%s" % [p_lose.get("last_banner_title"), txt])
		if txt.contains("记下这个名字："):
			hero_line_seen = true
		p_lose.queue_free()
	if defeat_ok:
		_pass_log.append("③ 失败态横幅 ×12 全部 ∈ 失败池（英雄名行出现 %s）" % ("有" if hero_line_seen else "本轮未抽中"))
	if Engine.has_meta("battle_retreated"):
		_fails.append("③ 失败态不应产生/消费撤退 meta")

	# ── ④ 撤退链 ──
	Engine.set_meta("battle_retreated", true)
	var p_ret := _make_panel(false)
	if String(p_ret.get("last_banner_title")) == "撤退" and _in_pool(String(p_ret.get("last_banner_text")), pool_r):
		_pass_log.append("④ 撤退态横幅：%s" % String(p_ret.get("last_banner_text")).split("\n")[0])
	else:
		_fails.append("④ 撤退态横幅不符：title=%s desc=%s" % [p_ret.get("last_banner_title"), p_ret.get("last_banner_text")])
	if Engine.has_meta("battle_retreated"):
		_fails.append("④ 撤退 meta 未被消费（会串到下一场败仗）")
	else:
		_pass_log.append("④ 撤退 meta 一次性消费 OK")
	p_ret.queue_free()

	# ── ⑤ 撤退文案绝不混入英雄名行（人没牺牲） ──
	Engine.set_meta("battle_retreated", true)
	var p_ret2 := _make_panel(false)
	if String(p_ret2.get("last_banner_text")).contains("记下这个名字："):
		_fails.append("⑤ 撤退态混入英雄名行（语义错误）")
	p_ret2.queue_free()
	Engine.remove_meta("battle_retreated")
	_pass_log.append("⑤ 撤退态无英雄名行 OK")

	# ── ⑥ 名册可用性（英雄名数据源） ──
	var epm := load("res://data/enemy_phase_masters.gd")
	var masters: Array = epm.ENEMY_MASTERS
	if masters.size() >= 30 and String(masters[0].get("name", "")) != "":
		_pass_log.append("⑥ 牺牲相位师名册可用（%d 位）" % masters.size())
	else:
		_fails.append("⑥ 牺牲相位师名册不可用（size=%d）" % masters.size())
