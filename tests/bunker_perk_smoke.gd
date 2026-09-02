extends Node
## 批次4 补齐冒烟：兵棋室沙盘演武 / 荣誉室出征仪式 / 气象站天气预报 / 相位实验室洗点费
## 运行：godot --headless --rendering-driver opengl3 --path . res://tests/bunker_perk_smoke.tscn

var _fail_count := 0

func _ready() -> void:
	print("═════════════════════════════════════════════════")
	print("  批次4 补齐冒烟（SANDBOX / SALUTE / WEATHER / RESPEC）")
	print("═════════════════════════════════════════════════")
	ManagerLazyLoader.ensure_loaded("bunker")
	await get_tree().process_frame
	await _phase_a_sandbox()
	await _phase_b_salute()
	await _phase_c_weather()
	await _phase_d_respec()
	await _phase_e_save_roundtrip()
	_finish()

func _fail(msg: String) -> void:
	_fail_count += 1
	push_error("[FAIL] " + msg)
	print("[FAIL] " + msg)

func _ok(msg: String) -> void:
	print("[ OK ] " + msg)

func _finish() -> void:
	if _fail_count == 0:
		print("═══════════ 全部通过（ALL PASS）═══════════")
		get_tree().quit(0)
	else:
		print("═══════════ 失败 %d 项 ═══════════" % _fail_count)
		get_tree().quit(1)

func _bunker() -> Node:
	return ManagerLazyLoader.get_manager("bunker")

func _reset() -> void:
	var b: Node = _bunker()
	b.reset_to_defaults()

# ════════════ A. 兵棋室 Lv3 沙盘演武 ════════════

func _phase_a_sandbox() -> void:
	var b: Node = _bunker()
	_reset()
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var inst: CardResource = ir.create_instance("ww1_mp18")
	var iid := String(inst.instance_id)
	# Lv 门
	if b.is_sandbox_online():
		_fail("兵棋室 Lv1 不应解锁沙盘")
	var r0: Dictionary = b.set_sandbox_card(iid)
	if r0.get("ok", true):
		_fail("未解锁时设置沙盘应被拒")
	# 升到 Lv3
	b._rooms["war_room"]["level"] = 3
	# 不存在的实例拒
	var r1: Dictionary = b.set_sandbox_card("no_such#999")
	if r1.get("ok", true):
		_fail("不存在的实例应被拒")
	# 正常设置
	var r2: Dictionary = b.set_sandbox_card(iid)
	if not r2.get("ok", false):
		_fail("正常沙盘设置失败: %s" % str(r2.get("reason", "")))
	# 重复设置拒
	var r3: Dictionary = b.set_sandbox_card(iid)
	if r3.get("ok", true):
		_fail("重复设置同一张应被拒")
	# 50% 经验发放
	var got: int = b.grant_sandbox_exp(100)
	if got != 50:
		_fail("沙盘经验应为 50%%：传 100 实得 %d" % got)
	# 销毁后清槽
	ir.dispose_instance(iid)
	var got2: int = b.grant_sandbox_exp(100)
	if got2 != 0:
		_fail("沙盘卡销毁后应返回 0，实际 %d" % got2)
	if not String(b.get_sandbox_instance_id()).is_empty():
		_fail("沙盘卡销毁后应自动清槽")
	# 未设置时返回 0
	var got3: int = b.grant_sandbox_exp(100)
	if got3 != 0:
		_fail("未设置沙盘卡时应返回 0")
	_ok("沙盘演武：Lv 门/设置校验/50%% 经验/销毁清槽 正确")

# ════════════ B. 荣誉室 Lv3 出征仪式 ════════════

func _phase_b_salute() -> void:
	var b: Node = _bunker()
	_reset()
	# Lv 门 + 未修复拒
	if b.is_salute_online():
		_fail("荣誉室 Lv1 不应解锁出征仪式")
	var r0: Dictionary = b.do_salute()
	if r0.get("ok", true):
		_fail("未解锁时敬礼应被拒")
	b._rooms["honor_hall"]["level"] = 3
	var r1: Dictionary = b.do_salute()
	if r1.get("ok", true):
		_fail("荣誉室未修复（LOCKED）时敬礼应被拒")
	# 修复后正常敬礼
	b._rooms["honor_hall"]["state"] = 2  # ACTIVE
	var r2: Dictionary = b.do_salute()
	if not r2.get("ok", false):
		_fail("正常敬礼失败: %s" % str(r2.get("reason", "")))
	if not b.is_salute_armed():
		_fail("敬礼后应处于武装状态")
	# 日 1 次
	var r3: Dictionary = b.do_salute()
	if r3.get("ok", true):
		_fail("同一天第二次敬礼应被拒")
	# 武装消耗 → 1.1；再消耗 → 1.0
	var m1: float = b.consume_salute()
	if absf(m1 - 1.10) > 0.001:
		_fail("武装消耗应返回 1.1，实际 %.3f" % m1)
	if b.is_salute_armed():
		_fail("消耗后应解除武装")
	var m2: float = b.consume_salute()
	if absf(m2 - 1.0) > 0.001:
		_fail("未武装消耗应返回 1.0，实际 %.3f" % m2)
	# 武装状态当日重复敬礼拒（日 1 次与武装互斥均可）
	_ok("出征仪式：Lv 门/日 1 次/武装消耗 1.1→1.0 正确")

# ════════════ C. 气象站 Lv2 天气预报 ════════════

func _phase_c_weather() -> void:
	var b: Node = _bunker()
	_reset()
	# Lv1 无预报
	if not b.get_today_weather().is_empty():
		_fail("气象站 Lv1 不应有预报")
	var r0: Dictionary = b.lock_weather()
	if r0.get("ok", true):
		_fail("未解锁时锁定应被拒")
	b._rooms["weather_station"]["level"] = 2
	b._rooms["weather_station"]["state"] = 2  # ACTIVE
	var w: Dictionary = b.get_today_weather()
	if w.is_empty():
		_fail("Lv2 应有今日预报")
	if not w.has("name") or not w.has("atk_pct"):
		_fail("预报条目缺字段: %s" % str(w.keys()))
	# 锁定 → 生效一次 → 消耗
	var r1: Dictionary = b.lock_weather()
	if not r1.get("ok", false):
		_fail("锁定预报失败: %s" % str(r1.get("reason", "")))
	var r2: Dictionary = b.lock_weather()
	if r2.get("ok", true):
		_fail("重复锁定应被拒")
	var eff: Dictionary = b.get_active_weather_bonus()
	for k in ["hp_pct", "atk_pct", "def_pct"]:
		if not eff.has(k):
			_fail("天气效果缺 %s" % k)
	if absf(float(eff.get("atk_pct", 99.0)) - float(w.get("atk_pct", 98.0))) > 0.0001:
		_fail("天气 atk 效果与预报不一致")
	if not b.get_active_weather_bonus().is_empty():
		var eff2: Dictionary = b.get_active_weather_bonus()
		if absf(float(eff2.get("atk_pct", 1.0))) > 0.0001:
			_fail("消耗后效果应归零，实际 %s" % str(eff2))
	# 日切换（模拟跨天）→ armed 失效、预报重掷
	b._weather_armed = true
	b._day += 1
	var w2: Dictionary = b.get_today_weather()
	if b.is_weather_armed():
		_fail("跨天后锁定应失效")
	if w2.is_empty():
		_fail("跨天后应有新预报")
	_ok("天气预报：Lv 门/锁定消耗/跨天重掷 正确")

# ════════════ D. 相位实验室洗点费 ════════════

func _phase_d_respec() -> void:
	var b: Node = _bunker()
	_reset()
	if b.get_respec_cost() != 100:
		_fail("Lv1 洗点费应为 100，实际 %d" % int(b.get_respec_cost()))
	b._rooms["phase_lab"]["level"] = 2
	if b.get_respec_cost() != 50:
		_fail("Lv2 洗点费应为 50（半价），实际 %d" % int(b.get_respec_cost()))
	b._rooms["phase_lab"]["level"] = 3
	if b.get_respec_cost() != 0:
		_fail("Lv3 当日免费额度应为 0，实际 %d" % int(b.get_respec_cost()))
	# 用掉免费额度 → 半价
	b.notify_respec_done(0)
	if b.get_respec_cost() != 50:
		_fail("免费额度用完应为半价 50，实际 %d" % int(b.get_respec_cost()))
	# 付费洗点不消耗免费额度
	b.notify_respec_done(50)
	if b.get_respec_cost() != 50:
		_fail("付费洗点不应影响免费额度判断")
	_ok("洗点费：100 / 半价 50 / Lv3 每日首免 正确")

# ════════════ E. 存档回环 ════════════

func _phase_e_save_roundtrip() -> void:
	var b: Node = _bunker()
	_reset()
	b._rooms["war_room"]["level"] = 3
	b._rooms["weather_station"]["level"] = 2
	b._rooms["weather_station"]["state"] = 2  # ACTIVE
	b._rooms["phase_lab"]["level"] = 3
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var inst: CardResource = ir.create_instance("ww1_mp18")
	b.set_sandbox_card(String(inst.instance_id))
	b._rooms["honor_hall"]["level"] = 3
	b._rooms["honor_hall"]["state"] = 2
	b.do_salute()
	b.lock_weather()
	b._respec_free_day = 0
	var saved: Dictionary = b.save_state()
	var fresh: Node = load("res://managers/bunker_manager.gd").new()
	fresh._init()
	fresh.load_state(saved)
	if String(fresh.get_sandbox_instance_id()) != String(inst.instance_id):
		_fail("读档后沙盘卡应保留")
	if not fresh.is_salute_armed():
		_fail("读档后敬礼武装应保留")
	if not fresh.is_weather_armed():
		_fail("读档后预报锁定应保留")
	if int(fresh.get_respec_cost()) != 0:
		_fail("读档后 Lv3 免费额度应保留")
	ir.dispose_instance(String(inst.instance_id))
	fresh.free()
	_ok("沙盘/敬礼/预报/洗点 存档回环 正确")
