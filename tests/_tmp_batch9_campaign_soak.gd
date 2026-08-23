extends SceneTree
## tests/_tmp_batch9_campaign_soak.gd — 批次9（P1-2）全流程通关验收 · headless 自动推图 soak
##
## 驱动链：空槽保护挑槽 → SaveManager.start_new_game()（真·新档：初始卡+初始装备）
##   → main._auto_start_afk_from_world_map(START)（AFK 推图：自动布阵/战斗/过关推进）
##   → meta-bot 每 N 关按战力重装 4 槽（模拟玩家换卡，防初始卡中期卡关）
## 监控：每场 level/won/相位师关标记；orphan/内存轨迹；停止条件三选一。
##
## 安全：绝不触碰非空存档槽（get_slot_info 全占则拒绝启动）；结束时切回槽 1。
## 用法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_batch9_campaign_soak.gd
##   环境参数：BATCH9_START_LEVEL(1) / BATCH9_MAX_LEVEL(100) / BATCH9_TIME_SCALE(6.0)
##             BATCH9_WALL_LIMIT_SEC(2400) / BATCH9_REEQUIP_EVERY(5) / BATCH9_SLOT(0=自动挑空槽)

var _phase := 0
var _frame := 0
var _waited := 0
var _t0 := 0

# 配置
var _start_level := 1
var _max_level := 100
var _time_scale := 6.0
var _wall_limit_ms := 2400000
var _reequip_every := 5
var _forced_slot := 0

# 状态
var _main: Node = null
var _afk: RefCounted = null
var _slot_used := -1
var _battles: Array = []            # 每场 {level, won, pm, frames}
var _cur_battle := {}
var _orphan_samples: Array = []
var _mem_samples: Array = []
var _last_reequip_level := -10
var _errors := 0
var _stop_reason := ""
var _finished := false
var _max_won_level := 0
## 僵持处理（批次9 实测发现：相位师基地战 bot 打不动也打不死 → 无限僵持）
## 链2起：僵持阈值 12000→6000（PM 僵持是吞吐大头）；失败重试上限压到 1 次（run4
## 实测 L10+ bot 全败属 bot 弱于真实玩家的预期，3 次重试纯属浪费墙钟）。
var _stalemate_frames := 6000    # 单场 10 游戏分钟无结算判僵持
var _stalemates: Array = []      # 被跳过的僵持关
var _skip_pending := 0           # 僵持后要跳到的关卡（0=无）
var _ignore_next_end := false    # 强制结算的 battle_ended 跳过 telemetry（防 0 帧错位记录）
var _loss_skips: Array = []      # 连败墙跳过的关（bot 打不过≠游戏问题；L12 起敌档×2.00 高配，
                                 # 裸 bot 无强化打不过是预期——soak 目标=全关战斗发生，胜负不设）
var _resume_target := 0          # 跳关重启目标关（0=无）
var _resume_wait := 0            # 落定等待帧数（立即重启会撞游戏战斗管线延迟收尾链，
                                 # 曾致重试战斗卡 pre-active 永不结算）
var _last_event_frame := 0       # 最近 battle_started/ended 事件帧（事件间隔型看门狗基準）

# UCT 不用顶层 preload：其依赖链（card_resource.gd:472）裸引用 ModificationRegistry
# autoload，--script 模式下 autoload 注册前编译会炸（批次7 审计脚本同患）。
# 改运行时 load()（autoload 就绪后编译，与批次5 冒烟同款模式）。
var _uct = null


func _init() -> void:
	_start_level = maxi(1, int(OS.get_environment("BATCH9_START_LEVEL")))
	_max_level = maxi(_start_level, int(OS.get_environment("BATCH9_MAX_LEVEL")))
	_time_scale = maxf(1.0, float(OS.get_environment("BATCH9_TIME_SCALE")))
	_wall_limit_ms = maxi(60000, int(OS.get_environment("BATCH9_WALL_LIMIT_SEC")) * 1000)
	_reequip_every = maxi(1, int(OS.get_environment("BATCH9_REEQUIP_EVERY")))
	_forced_slot = int(OS.get_environment("BATCH9_SLOT"))
	Engine.time_scale = _time_scale
	_start_freeze_watchdog()
	Engine.max_fps = 0  # 解除帧率上限（headless 默认 ~60fps 是链跑吞吐瓶颈）
	_t0 = Time.get_ticks_msec()


## 帧冻结侦测线程：主循环单帧死循环时 _process 不再推进（L43 复现冻结用）。
## 线程只读 _frame 计数并 print（线程安全），30s 无推进即报。
func _start_freeze_watchdog() -> void:
	var wd := Thread.new()
	wd.start(func() -> void:
		var last := -1
		var stable_since := 0
		while true:
			OS.delay_msec(5000)
			var cur := _frame
			if cur == last:
				stable_since += 5
				if stable_since >= 30:
					print("[BATCH9] FRAME-FROZEN at frame=%d（单帧死循环/引擎冻结，看门狗无法触发）" % cur)
					stable_since = -1000000  # 只报一次
			else:
				stable_since = 0
			last = cur
	)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame % 3000 == 0:
		print("[BATCH9] ALIVE frame=%d wall=%ds" % [_frame, (Time.get_ticks_msec() - _t0) / 1000])
	match _phase:
		0:
			change_scene_to_file("res://scenes/main.tscn")
			_phase = 1
			_waited = 0
		1:
			_waited += 1
			_main = root.get_node_or_null("/root/Main")
			var gm: Node = root.get_node_or_null("/root/GameManager")
			if _main != null and gm != null and _main.get("_afk_manager") != null:
				_setup_run()
				_phase = 15  # 新档落定等待
				_waited = 0
			elif _waited > 3600:
				_fail("主场景/AFK 管理器 %d 帧未就绪" % _waited)
				return true
		15:
			# start_new_game 的管理器重置是 deferred 的；starter 卡走 InstanceRegistry
			# （_equip_starter_cards_for_new_game 是 no-op，绿槽开局为空玩家手动装备——
			# bot 必须自己装）。等注册表出现战斗卡实例（或超时兜底）再换装+开 AFK。
			_waited += 1
			var ready := _combat_instance_count() > 0
			if ready or _waited > 600:
				if not ready:
					print("[BATCH9] WARN: 600 帧后注册表仍无战斗卡——start_new_game 发放未落定")
				_meta_requip("new-game")
				_last_reequip_level = 0
				_main.call("_auto_start_afk_from_world_map", _start_level)
				_phase = 2
			return false
		2:
			return _monitor()
	return false


# ───────────────────────── 启动 ─────────────────────────

func _setup_run() -> void:
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	if sm == null:
		_fail("SaveManager 缺失")
		return
	# 1) 挑空槽（安全前提：绝不覆盖既有存档）
	var slot := _forced_slot
	if slot <= 0:
		var infos: Array = sm.get_slot_info()
		for info in infos:
			if not bool(info.get("exists", true)):
				slot = int(info.get("slot", 0))
				break
	if slot <= 0:
		_fail("无空存档槽（1-3 全占用）——拒绝启动以免覆盖真实进度")
		return
	_slot_used = slot
	# 2) 空槽新档（start_new_game 删的是空槽的（不存在 的）文件，安全）
	sm.set_slot(slot)
	sm.start_new_game()
	# 2.5) 链跑支持：START>1 时先解锁到起始关（新档 max_unlocked=1 会把起点钳回 1）。
	#     complete_level 发首通奖励属经济噪音，soak 槽位无所谓。
	if _start_level > 1:
		var lp: Node = root.get_node_or_null("/root/LevelProgressManager")
		if lp != null and lp.has_method("complete_level"):
			for lvl in range(1, _start_level):
				lp.complete_level(lvl, 3)
			print("[BATCH9] chain: 已解锁 1~%d 关" % (_start_level - 1))
	_afk = _main.get("_afk_manager")
	# 3) 信号钩子（--script 模式下 autoload 非全局标识符，统一 root 查找）
	var sb: Node = root.get_node_or_null("/root/SignalBus")
	if _afk != null:
		_afk.level_completed.connect(_on_level_completed)
		_afk.state_changed.connect(_on_afk_state_changed)
	if sb != null and sb.has_signal("battle_started"):
		sb.battle_started.connect(_on_battle_started)
	if sb != null and sb.has_signal("battle_ended"):
		sb.battle_ended.connect(_on_battle_ended)
	print("[BATCH9] START slot=%d start=%d max=%d scale=%.1f wall=%ds reequip_every=%d" % [
		_slot_used, _start_level, _max_level, _time_scale, _wall_limit_ms / 1000, _reequip_every])


# ───────────────────────── 监控循环 ─────────────────────────

func _monitor() -> bool:
	if _frame % 120 == 0:
		# Godot 4.5 无 ORPHAN 监视器：用对象/节点总数轨迹看泄漏趋势
		# （恒增不回落 = 泄漏信号；瞬时回落 = 正常清理）
		_orphan_samples.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
		_mem_samples.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	# 僵持看门狗（事件间隔型）：距上一次 battle 事件超阈值且 AFK 仍在跑 → 强判负跳关。
	# 不依赖 _cur_battle 完整性（telemetry 在快速重试路径有盲区，两代看门狗都漏过）。
	if _skip_pending == 0 and _resume_target == 0 and _afk != null:
		var running: bool = bool(_afk.get("is_running"))
		if running and _frame - _last_event_frame > _stalemate_frames + 900:
			_stalemate_skip()
	# 跳关重启落定期：等延迟收尾链静默再手术（曾因立即重启致重试战斗卡死不结算）
	if _resume_target > 0:
		_resume_wait -= 1
		if _resume_wait <= 0:
			var target: int = _resume_target
			_resume_target = 0
			var lp: Node = root.get_node_or_null("/root/LevelProgressManager")
			if lp != null and lp.has_method("complete_level"):
				lp.complete_level(target - 1, 3)
			_afk.set("push_level", target)
			_afk.set("push_retry_count", 0)
			_afk.start_afk()
			_afk.enter_next_battle()
	if Time.get_ticks_msec() - _t0 > _wall_limit_ms:
		_finish("WALL_LIMIT")
		return true
	return false


func _stalemate_skip() -> void:
	var bm: Node = root.get_node_or_null("/root/BattleManager")
	if bm == null or not bm.has_method("end_battle"):
		return
	var lvl: int = -1
	if not _cur_battle.is_empty():
		lvl = int(_cur_battle.get("level", -1))
	if lvl < 0 and _afk != null and _afk.get("_pending_level") != null:
		lvl = int(_afk.get("_pending_level"))
	if lvl < 0:
		lvl = 1
	print("[BATCH9] STALEMATE L%d 事件间隔超时强判负并跳过（%d 帧无 battle 事件）" % [lvl, _frame - _last_event_frame])
	_last_event_frame = _frame  # 防重入
	_stalemates.append(lvl)
	if not _cur_battle.is_empty():
		_cur_battle["frames"] = _frame
	_skip_pending = lvl + 1
	_ignore_next_end = true  # 强制结算的 battle_ended 与下一场 telemetry 错位，跳过记录
	# 让 loss 直接走 _afk_failed 停机（绕过 3 次重试），驱动在 FAILED 回调里跳关重启
	_afk.set("push_retry_count", 99)
	bm.end_battle(false)


func _on_battle_started() -> void:
	_last_event_frame = _frame
	var pm := false
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var lvl := -1
	if gm != null:
		lvl = int(gm.get("current_level"))
		if gm.has_method("is_phase_master_battle"):
			pm = gm.is_phase_master_battle()
	_cur_battle = {
		"level": lvl,
		"pm": pm,
		"frames": _frame,
	}


func _on_battle_ended(player_won: bool) -> void:
	_last_event_frame = _frame
	if _ignore_next_end:
		_ignore_next_end = false
		_cur_battle = {}
		return
	# 失败重试上限压到 1 次：第二次失败前把 retry 计数垫到上限，loss 直接停机走跳关
	if not player_won and _afk != null and _skip_pending == 0:
		var rc: int = int(_afk.get("push_retry_count")) if _afk.get("push_retry_count") != null else 0
		if rc >= 1:
			_afk.set("push_retry_count", 99)
	if not _cur_battle.is_empty():
		_cur_battle["won"] = player_won
		_cur_battle["frames"] = _frame - int(_cur_battle["frames"])
		_battles.append(_cur_battle)
		var tag := " [相位师]" if _cur_battle["pm"] else ""
		print("[BATCH9] BATTLE #%d L%d %s%s (%d帧)" % [
			_battles.size(), _cur_battle["level"], "WIN" if player_won else "LOSE", tag, _cur_battle["frames"]])
		_cur_battle = {}


func _on_level_completed(level: int, won: bool) -> void:
	if won:
		_max_won_level = maxi(_max_won_level, level)
	# meta-bot：每 N 关按战力重装 4 槽（模拟玩家养成换卡）
	if level - _last_reequip_level >= _reequip_every:
		_meta_requip("L%d" % level)
		_last_reequip_level = level


func _on_afk_state_changed(new_state: int) -> void:
	# State: 0=IDLE 1=RUNNING 2=FAILED。推图 _advance_to_next_level 在 >100 关时
	# stop_afk() → IDLE；失败 3 次走 _afk_failed() → FAILED。
	if new_state == 2:
		# 僵持跳关（_skip_pending）或连败墙跳关（AFK 三连败停机）：
		# 只登记目标关，重启交给 _monitor 的落定期（立即重启会撞战斗管线延迟收尾链）。
		var skip_to: int = _skip_pending
		_skip_pending = 0
		if skip_to <= 0:
			# _afk_failed 已把 push_level 回拨到（失败关-1）→ 失败关 = push_level+1，越过它
			var push_lv: int = int(_afk.get("push_level")) if _afk.get("push_level") != null else 1
			var failed_lvl: int = push_lv + 1
			skip_to = failed_lvl + 1
			_loss_skips.append(failed_lvl)
			if _loss_skips.size() > 100:  # 防失控（每跳至少进 1 关，100 封顶）
				_finish("SKIP_OVERFLOW")
				return
		_resume_target = skip_to
		_resume_wait = 180  # ~3 游戏秒落定期
		print("[BATCH9] skip: L%d → 落定后从 L%d 续推（连败墙 %d 次）" % [skip_to - 1, skip_to, _loss_skips.size()])
	elif new_state == 0 and _max_won_level >= _max_level:
		_finish("COMPLETE")


# ───────────────────────── meta-bot：战力换装 ─────────────────────────

## 注册表内战斗卡实例数（新档落定判据：starter ww1_ft17 到位）
func _combat_instance_count() -> int:
	var ir: Node = root.get_node_or_null("/root/InstanceRegistry")
	if ir == null or not ir.has_method("get_all_instance_ids"):
		return 0
	var GCc = load("res://resources/game_constants.gd")
	var n := 0
	for iid in ir.get_all_instance_ids():
		var c = ir.get_instance(String(iid))
		if c != null and int(c.card_type) == int(GCc.CardType.COMBAT_UNIT):
			n += 1
	return n


## bot 经济模拟：按时代经 InstanceRegistry 发顶战力战斗卡（与掉落/商店同款 API）。
## 稳定性 soak 不模拟经济成长（经济面批次7 已数值核），只保证卡池不卡关。
func _grant_era_cards(era: int, n: int) -> int:
	var ir: Node = root.get_node_or_null("/root/InstanceRegistry")
	if ir == null or not ir.has_method("create_instance"):
		return 0
	if _uct == null:
		_uct = load("res://data/unified_card_table.gd")
	if _uct == null:
		return 0
	var entries: Array = []
	for e in _uct.get_player_card_entries():
		if int(e.get("era", -1)) == era:
			entries.append(e)
	entries.sort_custom(func(a, b): return int(a.get("power", 0)) > int(b.get("power", 0)))
	var granted := 0
	for i in range(mini(n, entries.size())):
		var cid: String = String(entries[i].get("card_id", ""))
		if cid.is_empty():
			continue
		if ir.create_instance(cid) != null:
			granted += 1
	return granted


## 收集注册表内全部战斗卡实例并按 UCT 战力评分（去重：每实例一条）
func _collect_scored_combat_cards(ir: Node, GCc) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for iid in ir.get_all_instance_ids():
		var card = ir.get_instance(String(iid))
		if card == null or not (card is CardResource):
			continue
		if int(card.card_type) != int(GCc.CardType.COMBAT_UNIT):
			continue
		var key := String(card.instance_id) if not String(card.instance_id).is_empty() else String(card.card_id)
		if seen.has(key):
			continue
		seen[key] = true
		var p := 0
		if _uct != null:
			var e: Dictionary = _uct.get_entry(String(card.card_id))
			if not e.is_empty():
				p = int(e.get("power", 0))
		out.append([p, card])
	return out


func _meta_requip(tag: String) -> void:
	var pim: Node = root.get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("equip_card"):
		return
	if _uct == null:
		_uct = load("res://data/unified_card_table.gd")
	# 卡源 = InstanceRegistry（玩家军火库正主；BackpackData 只是 UI 侧额外卡缓存）
	var ir: Node = root.get_node_or_null("/root/InstanceRegistry")
	if ir == null or not ir.has_method("get_all_instance_ids"):
		return
	var GCc = load("res://resources/game_constants.gd")
	var scored: Array = _collect_scored_combat_cards(ir, GCc)
	# 时代缺口补卡（run2 教训：按池深发卡，掉落塞满旧时代卡后永不换代 → L11+ 全败）：
	# 池内无当前推图时代的卡，或池过浅 → 发当时代顶战力卡。
	if _afk != null and _uct != null:
		var lvl: int = int(_afk.get("push_level")) if _afk.get("push_level") != null else 1
		var era: int = clampi(int((lvl - 1) / 20), 0, 4)
		var has_era_card := false
		for s in scored:
			var e2: Dictionary = _uct.get_entry(String((s[1] as CardResource).card_id))
			if not e2.is_empty() and int(e2.get("era", -1)) == era:
				has_era_card = true
				break
		if scored.size() < 8 or not has_era_card:
			var granted := _grant_era_cards(era, 4)
			if granted > 0:
				print("[BATCH9] grant: era%d +%d 张（pool %d，era卡在池=%s）" % [era, granted, scored.size(), str(has_era_card)])
				scored = _collect_scored_combat_cards(ir, GCc)
	if scored.is_empty():
		print("[BATCH9] requip(%s): 注册表无战斗卡，跳过" % tag)
		return
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var equipped := 0
	for i in range(mini(4, scored.size())):
		var card = scored[i][1]
		if pim.equip_card(i, card):
			equipped += 1
	print("[BATCH9] requip(%s): 装备 %d 张（候选 %d，top_power=%d）" % [tag, equipped, scored.size(), scored[0][0] if scored.size() > 0 else 0])


# ───────────────────────── 收尾 ─────────────────────────

func _finish(reason: String) -> void:
	if _finished:
		return
	_finished = true
	_stop_reason = reason
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	var wins := 0
	var losses := 0
	var pm_count := 0
	var pm_wins := 0
	var max_level_reached := 0
	var era_levels: Dictionary = {}
	for b in _battles:
		if b.get("won", false):
			wins += 1
		else:
			losses += 1
		if b.get("pm", false):
			pm_count += 1
			if b.get("won", false):
				pm_wins += 1
		max_level_reached = maxi(max_level_reached, int(b.get("level", 0)))
	var orphan_first: int = int(_orphan_samples[0]) if not _orphan_samples.is_empty() else -1
	var orphan_last: int = int(_orphan_samples.back()) if not _orphan_samples.is_empty() else -1
	var orphan_max: int = -1
	for o in _orphan_samples:
		orphan_max = maxi(orphan_max, int(o))
	print("──────── [BATCH9] SUMMARY ────────")
	print("stop=%s  battles=%d (W%d/L%d)  max_level=%d" % [_stop_reason, _battles.size(), wins, losses, max_level_reached])
	print("phase_master_battles=%d (win %d)  wall=%.0fs  scale=%.1f" % [pm_count, pm_wins, float(Time.get_ticks_msec() - _t0) / 1000.0, _time_scale])
	print("obj_count: first=%d last=%d max=%d (samples=%d)" % [orphan_first, orphan_last, orphan_max, _orphan_samples.size()])
	print("node_count: first=%s last=%s" % [str(_mem_samples[0]) if not _mem_samples.is_empty() else "-", str(_mem_samples.back()) if not _mem_samples.is_empty() else "-"])
	# 相位师关分布（每 20 关一个时代尾）
	for b in _battles:
		if b.get("pm", false):
			era_levels[int(b.get("level", 0))] = b.get("won", false)
	print("pm_levels=" + str(era_levels))
	print("stalemate_skipped=" + str(_stalemates))
	print("losswall_skipped=" + str(_loss_skips))
	# 切回槽 1（不动真实存档）
	if sm != null and _slot_used > 0:
		sm.set_slot(1)
	var ok: bool = _stop_reason == "COMPLETE" or max_level_reached >= _max_level
	quit(0 if ok else 1)


func _fail(msg: String) -> void:
	print("[BATCH9] FAIL: " + msg)
	_errors += 1
	_finish("SETUP_FAIL")
