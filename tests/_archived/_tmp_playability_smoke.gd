extends SceneTree
## v6.14 可玩性冒烟（headless --script 模式，临时工具）
## 核心链路：slot 3 新档 → 挂主场景 → L1 首战自动部署 → 真实胜利判定 → 结算面板
##           → 11 个懒加载面板遍历 → 回基地（本分支新增 _on_back_to_base）→ 存读档回归
## ⚠️ 档位固定 slot 3（先删后建），绝不触碰 slot 1 正式档。
## ⚠️ 教程置完成态（step 13 终态）以隔离教学引导变量——教学链由 _tmp_v614_fix_check 单测覆盖。
## QA 加速：战斗期每 2s 把敌方单位 hp 压到 1（击杀仍走真实伤害/统计/掉落链），
##          同时补满我方驱动器血（隔离平衡变量，只验流程）。
## 退出码：0=全过，1=有 FAIL。运行期 GDScript 错误由 stderr 抓取统一判定。

var _fail: int = 0
var _pass: int = 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", msg)
	else:
		_fail += 1
		printerr("  FAIL  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	# ── 等autoload 就绪（裸 --script 的 _initialize 早于 autoload 注册，实测踩坑）──
	await _frames(2)

	print("== 可玩性冒烟：Phase 1 新档（slot 3） ==")
	var sm: Node = root.get_node("/root/SaveManager")
	var ir: Node = root.get_node("/root/InstanceRegistry")
	sm.call("set_slot", 3)
	sm.call("delete_slot", 3)
	sm.call("start_new_game")
	await _frames(10)
	var ids: Array = ir.call("get_all_instance_ids")
	_ok(ids.size() >= 3, "新档 starter 卡实例 ≥3（实际 %d）" % ids.size())
	var starter_hits := 0
	for want in ["ww1_mauser", "ww1_arty_m81", "ww1_arm_ft17"]:
		for id in ids:
			if String(id).begins_with(want):
				starter_hits += 1
				break
	_ok(starter_hits == 3, "starter 三卡（mauser/arty/ft17）全部实例化")
	# v6.14 回归锁：起始改造 5/5 预装成功（原清单 4/5 被时代带/档位门拦死）
	var mods_total := 0
	for id in ids:
		var card = ir.call("get_instance", id)
		if card != null and "mods" in card:
			mods_total += (card.mods as Array).size()
	_ok(mods_total == 5, "起始改造 5/5 预装（实际 %d）" % mods_total)
	var tm: Node = root.get_node("/root/TutorialProgressionManager")
	tm.call("load_state", {"version": 4, "current_step": 13, "completed_steps": [13]})
	print("  [i] 教程置完成态（隔离引导变量）")

	print("== 可玩性冒烟：Phase 2 首战（L1 自动部署 → 胜利判定） ==")
	var gm: Node = root.get_node("/root/GameManager")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(150)
	# 清离线奖励弹窗（纯视觉，同 _tmp_ui_battle_shot 口径）
	var popup: Node = main.get("popup_layer")
	if popup != null:
		for c in popup.get_children():
			var sc: Script = c.get_script()
			if sc != null and "offline" in String(sc.resource_path):
				c.queue_free()

	var sb: Node = root.get_node("/root/SignalBus")
	var battle_result := {"ended": false, "won": false}
	sb.battle_ended.connect(func(player_won: bool) -> void:
		battle_result["ended"] = true
		battle_result["won"] = player_won)

	gm.call("set_current_level", 1)
	var setup: RefCounted = main.get("_battle_setup")
	setup.call("on_start_battle")
	await _frames(45)
	var bm: Node = root.get_node("/root/BattleManager")
	var waited := 0
	while waited < 240:
		if "battle_active" in bm and bool(bm.get("battle_active")):
			break
		await _frames(5)
		waited += 5
	var battle_active := "battle_active" in bm and bool(bm.get("battle_active"))
	_ok(battle_active, "战斗激活（battle_active）")
	if not battle_active:
		_quit_report()
		return
	# 自动部署（复刻 _tmp_ui_battle_shot：先等激活再按压）
	var bar: Node = main.get("bottom_instrument_bar")
	var btn: Button = bar.get("_auto_deploy_btn") if bar != null else null
	if btn != null:
		btn.button_pressed = true
		btn.pressed.emit()
	_ok(btn != null, "自动部署按钮存在且已按压")

	# 战斗加速：每 2s 敌方 hp→1、驱动器血补满；等真实 battle_ended（上限 180s）
	var t_end: int = Time.get_ticks_msec() + 180_000
	var acc := 0.0
	var boost_frames := 0
	while Time.get_ticks_msec() < t_end and not bool(battle_result["ended"]):
		await process_frame
		acc += root.get_process_delta_time()
		if acc >= 2.0:
			acc = 0.0
			var bf: Node = gm.get("battle_scene")
			if bf != null and is_instance_valid(bf):
				var eu: Node = bf.get_node_or_null("EnemyUnits")
				if eu != null:
					for e in eu.get_children():
						if is_instance_valid(e) and "hp" in e:
							e.set("hp", 1.0)
				var drv: Node = bf.get_node_or_null("PhaseFieldDriver")
				if drv != null and is_instance_valid(drv) and "hp" in drv:
					drv.set("hp", drv.get("max_hp"))
					boost_frames += 1
	var battle_ms: int = 180_000 - (t_end - Time.get_ticks_msec())
	_ok(bool(battle_result["ended"]), "战斗在 180s 内真实结束（用时 %.1fs）" % (battle_ms / 1000.0))
	_ok(bool(battle_result["won"]), "首战胜利（player_won=true）")
	await _frames(60)  # 等 _on_battle_ended 延迟链 + 结算面板实例化
	var popup_names: Array[String] = []
	if popup != null:
		for c in popup.get_children():
			popup_names.append(c.name)
	print("  [i] 结算期 PopupLayer 子节点: ", popup_names)
	_ok(not popup_names.is_empty(), "结算面板已弹出")

	print("== 可玩性冒烟：Phase 3 懒加载面板遍历（11 项） ==")
	var uil: Node = root.get_node("/root/UILazyLoader")
	const PANELS: Array[String] = [
		"backpack", "growth", "quest", "store", "faction", "settings",
		"achievement", "help", "modification", "evolution", "collection",
	]
	var empty_panels: Array[String] = []
	for pid in PANELS:
		var p: Control = uil.call("get_panel", pid)
		if p == null or p.get_child_count() == 0:
			empty_panels.append(pid)
		else:
			uil.call("unload_panel", pid)
	_ok(empty_panels.is_empty(), "11 个懒加载面板全部可打开且非空 %s" % (str(empty_panels) if not empty_panels.is_empty() else ""))

	print("== 可玩性冒烟：Phase 4 回基地（v6.14 新链路） ==")
	_ok(main.has_method("_on_back_to_base"), "main._on_back_to_base 存在")
	main.call("_on_back_to_base")
	await _frames(120)
	var cur := current_scene
	var at_base: bool = cur != null and String(cur.scene_file_path).contains("truck_base")
	_ok(at_base, "回基地落 truck_base（当前场景 %s）" % (String(cur.scene_file_path) if cur != null else "<null>"))

	print("== 可玩性冒烟：Phase 5 存读档回归（slot 3） ==")
	var ok_save: bool = sm.call("save_game")
	_ok(ok_save == true, "save_game 成功")
	await _frames(20)
	var ids_after: Array = ir.call("get_all_instance_ids")
	var ok_load: bool = sm.call("load_game")
	await _frames(30)
	var ids_reload: Array = ir.call("get_all_instance_ids")
	_ok(ok_load == true, "load_game 成功")
	_ok(ids_reload.size() == ids_after.size(), "存读档后实例数一致（%d → %d）" % [ids_after.size(), ids_reload.size()])

	_quit_report()


func _quit_report() -> void:
	print("== 可玩性冒烟结果: %d PASS / %d FAIL ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
