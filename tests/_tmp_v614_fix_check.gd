extends SceneTree
## v6.14 八项修复验证脚本（headless --script 模式）
## ⚠️ 必须推迟到首个 process_frame 再干活：裸 --script 模式的 _init 跑在 autoload
## 注册之前，任何引用 autoload 全局名的脚本在该时机 load() 必编译失败（实测踩坑：
## 还会污染脚本缓存拖垮后续 autoload 初始化）。首帧后全局名可用，加载即真实编译。
## ① 全部改动 .gd 严格编译通过（can_instantiate 校验，防"假非空"）
## ② 教程进度：chain_paused 入档/复位、TRUCK_BASE 暂停点不再被完成判定吞掉
## ③ dream_battle 跳过落点与 comic_intro 一致（truck_base）

var _fail: int = 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		_fail += 1
		printerr("  FAIL  ", msg)

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	print("== v6.14 fix check ==")

	# ── ① 改动文件全部严格编译通过 ──
	var files: Array[String] = [
		"res://scenes/ui/backpack_card_item.gd",
		"res://data/enemy_archetypes.gd",
		"res://scripts/battle/attack_pose_anim.gd",
		"res://scenes/units/bullet.gd",
		"res://scripts/systems/main_reward.gd",
		"res://scenes/intro/dream_battle.gd",
		"res://scenes/title_screen.gd",
		"res://managers/tutorial_progression_manager.gd",
		"res://scenes/bunker/truck_base.gd",
		"res://scenes/ui/phase_master_skill_panel.gd",
		"res://scenes/ui/intelligence_hub_panel.gd",
		"res://scenes/ui/afk_settlement_dialog.gd",
		"res://scenes/bunker/bunker_reward_bubble.gd",
		"res://scenes/ui/afk_panel.gd",
		"res://scenes/ui/achievement_panel.gd",
		"res://scenes/ui/affix_forge_panel.gd",
		"res://scenes/ui/faction_panel.gd",
		"res://scenes/ui/collection_panel.gd",
		"res://scenes/ui/help_panel.gd",
		"res://scenes/ui/player_master_panel.gd",
		"res://scenes/ui/store_panel.gd",
		"res://scenes/ui/occupation_panel.gd",
		"res://scenes/ui/settings_panel.gd",
		"res://scenes/ui/quest_panel.gd",
		"res://scenes/ui/leaderboard/leaderboard_panel.gd",
		"res://scenes/main.gd",
		"res://scenes/ui/top_hud_bar.gd",
		"res://scenes/ui/mvp_panel.gd",
	]
	var bad: Array[String] = []
	for f in files:
		var s = load(f)
		if s == null or not (s is Script) or not (s as Script).can_instantiate():
			bad.append(f)
	_ok(bad.is_empty(), "%d 个改动脚本严格编译通过 %s" % [files.size(), str(bad) if not bad.is_empty() else ""])

	# ── ④ 顶栏返回=回基地：main 场景接线与新函数存在 ──
	#（注意：Script 对象上的 has_method 查的是 Resource 自身，须实例化后查声明方法）
	var main_s = load("res://scenes/main.gd")
	var main_i: Control = main_s.new() if main_s != null and main_s.can_instantiate() else null
	_ok(main_i != null and main_i.has_method("_on_back_to_base"), "main 新增 _on_back_to_base（顶栏返回落基地）")
	_ok(main_i != null and main_i.has_method("_exit_battle_and_change"), "main 收尾链共用体 _exit_battle_and_change")
	if main_i != null:
		main_i.free()

	# ── ② 教程进度存读档回归 ──
	var tm_script = load("res://managers/tutorial_progression_manager.gd")
	var tm: Node = tm_script.new()
	# v4 档停在 TRUCK_BASE(14)（点播暂停点）——原 >=13 判定误拉回 FREEDOM
	tm.load_state({"version": 4, "current_step": 14, "completed_steps": [1, 2], "chain_paused": true})
	_ok(int(tm.current_step) == 14, "TRUCK_BASE(14) 暂停点原位续看")
	_ok(bool(tm.chain_paused), "chain_paused 从存档恢复")
	var saved: Dictionary = tm.save_state()
	_ok(bool(saved.get("chain_paused", false)), "chain_paused 入档")
	# 空段复位（读侧不变式：先重置再覆盖）
	tm.load_state({})
	_ok(not bool(tm.chain_paused), "空段 load_state 复位 chain_paused")
	# FREEDOM(13) 终态判定保留
	tm.load_state({"version": 4, "current_step": 13, "completed_steps": []})
	_ok(int(tm.current_step) == 13, "FREEDOM_MODE(13) 终态原位保留")
	# v1 旧档迁移不受影响
	tm.load_state({"version": 1, "current_step": 8, "completed_steps": []})
	_ok(int(tm.current_step) == 13, "v1 完档(step>=8) 仍判已完成")
	tm.free()

	# ── ③ 序章/标题屏入口 ──
	var db = load("res://scenes/intro/dream_battle.gd")
	_ok(String(db.BUNKER_SCENE).ends_with("truck_base.tscn"), "dream_battle 跳过落点=truck_base")
	var ci = load("res://scenes/intro/comic_intro.gd")
	_ok(String(ci.BUNKER_SCENE) == String(db.BUNKER_SCENE), "与 comic_intro 落点一致")

	print("== 结果: %s ==" % ("ALL PASS" if _fail == 0 else "%d FAIL" % _fail))
	quit(1 if _fail > 0 else 0)
