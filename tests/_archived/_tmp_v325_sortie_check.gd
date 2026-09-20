extends Node
## v32.5 A4 定向探针：出征黑幕战报与战备并行路径——带 META_PENDING 走 on_start_battle，
## 断言：战斗照常激活（等待环不挂起）、战报层最终收尾、离场后无残留。
## 用法：godot --path . res://tests/_tmp_v325_sortie_check.tscn

const SortieInterstitialScript = preload("res://scripts/ui/sortie_interstitial.gd")


func _ready() -> void:
	_run()


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	await _wait_frames(10)
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
	await _wait_frames(5)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await _wait_frames(120)
	# 装备至少一张战斗卡（部署链可用；战报路径本身不依赖）
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if pim != null and ir != null:
		var equipped := 0
		for id in ir.call("get_all_instance_ids"):
			if equipped >= 3:
				break
			var card = ir.call("get_instance", id)
			if card != null and int(card.get("card_type")) == 0:
				if pim.call("equip_card", equipped, card):
					equipped += 1
	# 关键：写出征 meta（模拟 truck_base._launch_battle / world_map 进关链）
	Engine.set_meta(SortieInterstitialScript.META_PENDING, true)
	var gm: Node = get_node_or_null("/root/GameManager")
	gm.call("set_current_level", 1)
	# 教程链冻结（QA 档可能带教程态；与 ui_battle_shot 同款纪律，不写档）
	var tpm: Node = get_node_or_null("/root/TutorialProgressionManager")
	if tpm != null:
		tpm.set("chain_paused", true)
		tpm.set("current_step", 13)  # FREEDOM_MODE：非教程态，战报应播
	var setup: RefCounted = main.get("_battle_setup")
	var bm: Node = get_node_or_null("/root/BattleManager")
	setup.call("on_start_battle")
	# 战报应已激活（present 同步创建）
	await _wait_frames(3)
	var showing_early: bool = SortieInterstitialScript.is_showing()
	print("[V325Check] interstitial showing right after start = ", showing_early)
	# 等战斗激活（并行战备应远快于旧串行闸）
	var waited := 0
	while waited < 600:
		if bm != null and bool(bm.get("battle_active")):
			break
		await _wait_frames(5)
		waited += 5
	print("[V325Check] battle_active = ", bm != null and bool(bm.get("battle_active")),
		" after ", waited, " frames")
	# 战报层应自行收尾（0.8s ≈ 48 帧 + 淡出）
	var waited2 := 0
	while waited2 < 300 and SortieInterstitialScript.is_showing():
		await _wait_frames(5)
		waited2 += 5
	print("[V325Check] interstitial finished = ", not SortieInterstitialScript.is_showing(),
		" after ", waited2, " more frames")
	# 部署链可用性（自动部署默认开：控制器应已启用）
	var bar: Node = main.get("bottom_instrument_bar")
	print("[V325Check] auto_deploy enabled = ",
		bar != null and bar.has_method("is_auto_deploy_enabled") and bar.call("is_auto_deploy_enabled"))
	var ok: bool = (bm != null and bool(bm.get("battle_active"))) \
		and not SortieInterstitialScript.is_showing()
	print("[V325Check] RESULT = ", "PASS" if ok else "FAIL")
	await _wait_frames(5)
	get_tree().quit(0 if ok else 1)
