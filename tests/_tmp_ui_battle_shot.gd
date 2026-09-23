extends Node
## v26.2 战斗界面实机验收截图（全视口含 HUD；临时工具）
## 模式文件 .godot/ui_battle_shot_mode.txt：`level=20 frame=520`
## v27 追加：`endless=1`（黑门无限模式进场）+ `depth=N`（锁定渗度 0-5 供视觉对比）

const OUT := "res://.godot/agent_tools/battle_ui_v262.png"
const MODE_FILE := "res://.godot/ui_battle_shot_mode.txt"

var _level := 20
var _shot_frame := 520
var _endless := false
var _depth := -1
var _out_path := OUT
## v27: 真实波次验证——自然推进到指定波后定时抓拍（"10,3.5,20,6"=第10波后3.5s、第20波后6s 各拍一张；
## 覆盖渗度播报与档位交叉淡入的真实时序；空=老行为按 frame 抓拍）
var _snap_waves: Array = []


func _ready() -> void:
	if FileAccess.file_exists(MODE_FILE):
		for kv in FileAccess.get_file_as_string(MODE_FILE).split(" ", false):
			var p := kv.split("=")
			if p.size() == 2:
				if p[0] == "level": _level = int(p[1])
				elif p[0] == "frame": _shot_frame = int(p[1])
				elif p[0] == "endless": _endless = int(p[1]) == 1
				elif p[0] == "depth": _depth = int(p[1])
				elif p[0] == "snapwave":
					var toks := p[1].split(",", false)
					var i := 0
					while i + 1 < toks.size():
						_snap_waves.append({"wave": int(toks[i]), "delay": float(toks[i + 1])})
						i += 2
	print("[UiBattleShot] level=", _level, " shot_frame=", _shot_frame,
		" endless=", _endless, " depth=", _depth)
	if _endless:
		_out_path = "res://.godot/agent_tools/battle_ui_v27_endless.png"
		if _depth >= 0:
			_out_path = "res://.godot/agent_tools/battle_ui_v27_endless_d%d.png" % _depth
	_run()


func _run() -> void:
	await _wait_frames(20)
	# 载档（玩家卡组/仪器档位来自存档；无档也能开战，只有初始配置）
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		print("[UiBattleShot] load_game=", sm.call("load_game"))
	await _wait_frames(10)
	# 挂主场景（绝不 change_scene——会释放驱动器）
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await _wait_frames(150)
	# 清离线奖励弹窗（纯视觉，不领取不写档）
	var popup: Node = main.get("popup_layer")
	if popup != null:
		for c in popup.get_children():
			var sc: Script = c.get_script()
			if sc != null and "offline" in String(sc.resource_path):
				c.queue_free()
	# v27: 空 QA 存档仪器槽无装备 → 自动部署无卡可用、驱动器数秒被毁、战斗早终结算。
	# 战前程序化装备战斗卡（COMBAT_UNIT=0）；档里零实例时（QA 档被重置过）从初始三卡
	# 走 InstanceRegistry.create_instance 正规链补建实例（不触碰共享模板）。
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if pim != null and ir != null:
		var equipped := 0
		for id in ir.call("get_all_instance_ids"):
			if equipped >= 5:
				break
			var card = ir.call("get_instance", id)
			if card != null and int(card.get("card_type")) == 0:
				if pim.call("equip_card", equipped, card):
					equipped += 1
		if equipped == 0 and ir.has_method("create_instance"):
			for starter_id in ["ww1_mauser", "ww1_arty_m81", "ww1_arm_ft17"]:
				var inst = ir.call("create_instance", starter_id)
				if inst != null and pim.call("equip_card", equipped, inst):
					equipped += 1
		print("[UiBattleShot] equipped loadout cards=", equipped)
	# 选关开战 + 自动部署（复刻世界地图自由选关链路；endless 走黑门进场链）
	var gm: Node = get_node_or_null("/root/GameManager")
	if _endless:
		gm.call("set_current_level", 100)  # 黑门口径：档位/难度链以近未来满档为基准
		gm.call("start_endless_battle")
	else:
		gm.call("set_current_level", _level)
	var setup: RefCounted = main.get("_battle_setup")
	setup.call("on_start_battle")
	await _wait_frames(45)
	# v27: 等战斗真正激活再按自动部署（按钮处理有 battle_active 守卫，过早按压被弹回）
	var bm: Node = get_node_or_null("/root/BattleManager")
	var waited := 0
	while waited < 240:
		if bm != null and "battle_active" in bm and bool(bm.get("battle_active")):
			break
		await _wait_frames(5)
		waited += 5
	var bar: Node = main.get("bottom_instrument_bar")
	var btn: Button = bar.get("_auto_deploy_btn") if bar != null else null
	if btn != null:
		btn.button_pressed = true
		btn.pressed.emit()
	print("[UiBattleShot] battle L", _level, " endless=", _endless,
		" active=", bm != null and bool(bm.get("battle_active")), " auto-deploy ON")
	# QA: 冻结教程链 + 纯视觉隐藏引导覆盖层（不推进步骤、不写档；v28 实测替点"启程"
	# 会被步骤门拦住，且教程链可能在下一 run 接管战斗重开 L1 首战，都比弹窗更糟）
	var tpm: Node = get_node_or_null("/root/TutorialProgressionManager")
	if tpm != null:
		tpm.set("chain_paused", true)
	var t_ov: Node = main.get_node_or_null("HudLayer/TutorialOverlay") if main != null else null
	if t_ov != null and bool(t_ov.get("visible")):
		t_ov.set("visible", false)
		print("[UiBattleShot] tutorial overlay hidden")
	# 渗度锁定（视觉对比用）：跳过缓动即时生效，并不再随波次变化
	if _endless and _depth >= 0:
		var bf: Node = gm.get("battle_scene")
		var amb: Node = bf.get_node_or_null("EndlessRiftAmbience") if bf != null else null
		if amb != null and amb.has_method("force_depth"):
			amb.call("force_depth", _depth)
			print("[UiBattleShot] forced seepage depth=", _depth)
		else:
			print("[UiBattleShot] WARN: EndlessRiftAmbience not found")
	# v27: QA 保活等待——进入等待前把驱动器血池改为 10 亿（背景验收不需要公平战斗，
	# 只要求战斗存活到快照时刻；实测 200 血在低帧率下两刀就被 L100 敌方打穿）。
	var bf_root: Node = gm.get("battle_scene")
	if bf_root != null and is_instance_valid(bf_root):
		var drv0 := bf_root.get_node_or_null("PhaseFieldDriver")
		if drv0 != null and is_instance_valid(drv0) and "hp" in drv0:
			drv0.set("max_hp", 1.0e9)
			drv0.set("hp", 1.0e9)
	var frames_left := _shot_frame
	while frames_left > 0:
		var step := mini(5, frames_left)
		await _wait_frames(step)
		frames_left -= step
		if bf_root == null or not is_instance_valid(bf_root):
			break
		if t_ov != null and is_instance_valid(t_ov) and bool(t_ov.get("visible")):
			t_ov.set("visible", false)
		# 驱动器是开战链延迟 spawn 的：tick 里发现即补血池（含首补）
		var drv := bf_root.get_node_or_null("PhaseFieldDriver")
		if drv != null and is_instance_valid(drv) and "hp" in drv:
			if float(drv.get("max_hp")) < 1.0e8:
				drv.set("max_hp", 1.0e9)
			drv.set("hp", float(drv.get("max_hp")))
	# v27 真实波次验证模式：订阅 wave_spawned，自然推进到目标波后按延时抓拍
	# （播报入队到显示有排队延迟，延时 3~6s 抓正显示中的文案；拍完最后一张即退出。
	#  ⚠ GDScript lambda 按值捕获标量——状态走字典引用持有者）
	if not _snap_waves.is_empty():
		var sb := get_node_or_null("/root/SignalBus")
		var snaps: Array = _snap_waves.duplicate()
		var state := {"scheduled": 0, "completed": 0}
		if sb != null and sb.has_signal("wave_spawned"):
			var on_wave := func(wave_index: int) -> void:
				for s in snaps:
					if not s.get("done", false) and int(s["wave"]) == wave_index:
						s["done"] = true
						state["scheduled"] += 1
						_snap_wave_after(float(s["delay"]), state, "res://.godot/agent_tools/battle_ui_v27_w%d.png" % int(s["wave"]))
			sb.wave_spawned.connect(on_wave)
		# 保活等波（最长 6 分钟；全部抓拍完成后 1s 收尾退出）。
		# QA 加速：每 4s 清一次敌方场——弱 QA 卡组杀不动 L100 口径敌兵，9 槽堵死会让
		# 波次计数停滞（spawn 前置校验空槽），波次信号链本身仍是真实计时器驱动。
		var clear_acc := 0.0
		var t_end: int = Time.get_ticks_msec() + 360_000  # 时间基准（帧率无关；低帧率下帧数上限会提前耗尽）
		while Time.get_ticks_msec() < t_end:
			await get_tree().process_frame
			var done_all: bool = state["scheduled"] >= snaps.size() and state["completed"] >= state["scheduled"]
			if done_all:
				break
			var drv_w := bf_root.get_node_or_null("PhaseFieldDriver") if bf_root != null and is_instance_valid(bf_root) else null
			if drv_w != null and is_instance_valid(drv_w) and "hp" in drv_w:
				drv_w.set("hp", float(drv_w.get("max_hp")))
			clear_acc += get_process_delta_time()
			if clear_acc >= 4.0:
				clear_acc = 0.0
				if bf_root != null and is_instance_valid(bf_root):
					var eu := bf_root.get_node_or_null("EnemyUnits")
					if eu != null:
						for e in eu.get_children():
							if is_instance_valid(e):
								e.queue_free()
		await _wait_sec(1.0)
		get_tree().quit()
		return
	# 全视口截图（含 HUD）
	var tex := get_tree().root.get_viewport().get_texture()
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		var err := img.save_png(_out_path)
		print("[UiBattleShot] saved ", _out_path, " err=", err, " size=", img.get_size())
	else:
		print("[UiBattleShot] EMPTY capture")
	get_tree().quit()


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## 真实波次模式：延时后抓拍一张（state 字典回填完成计数）
func _snap_wave_after(delay_sec: float, state: Dictionary, path: String) -> void:
	await _wait_sec(delay_sec)
	_capture_to(path)
	state["completed"] += 1


func _capture_to(path: String) -> void:
	var tex := get_tree().root.get_viewport().get_texture()
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		var err := img.save_png(path)
		print("[UiBattleShot] snap saved ", path, " err=", err, " size=", img.get_size())
	else:
		print("[UiBattleShot] EMPTY capture -> ", path)


func _wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout
