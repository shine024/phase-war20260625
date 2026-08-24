# v9.x 战斗卡武器配对审查 smoke test（A/B/C 修复回归锁）
# 验证：
#   A. 武器蓝图卡攻速语义 = 1/间隔（次/秒），不再是原样间隔值
#   B. steel_railcannon_expert 已入表（JSON 与 LEGACY 兜底同步）；master_014 引用之
#   C. flame_siege_expert 平台默认武器 = incendiary_mortar_expert（type 回归 mortar 线）
#   兜底. 全部 24 平台 default_weapon 可解析且阵营/等级一致；30 位 master 武器引用全有效
#
# 本测试不依赖 GdUnit，直接 extends SceneTree。
# 注意：装备/大师表 preload 链深处触达 unit_stats_table.gd（引用 ModificationRegistry autoload 名），
# --script 模式早期 const preload 会在 autoload 注册前编译而报 Identifier not found——
# 必须在 _initialize 内运行时 load()（与 deploy_alive_limit_smoke 同款规避，v20.11 踩坑）。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/weapon_pairing_audit_smoke.gd
extends SceneTree

var EnemyPhaseEquipment: Script
var EnemyPhaseMasters: Script
var EquipmentWeapons: Script

var _code := 0
var _pass := 0


func _fail(msg: String) -> void:
	push_error("[FAIL] " + msg)
	_code = 1


func _initialize() -> void:
	EnemyPhaseEquipment = load("res://data/enemy_phase_equipment.gd")
	EnemyPhaseMasters = load("res://data/enemy_phase_masters.gd")
	EquipmentWeapons = load("res://data/enemy_equipment_weapons.gd")
	if EnemyPhaseEquipment == null or EnemyPhaseMasters == null or EquipmentWeapons == null:
		_fail("数据表脚本加载失败")
		quit(1)
		return
	print("═══════════════════════════════════════════════════════════")
	print("  战斗卡武器配对审查（A/B/C 修复回归锁）")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ B/C: 新武器入表 + JSON↔LEGACY 同步 ══════════
	var weps: Dictionary = EnemyPhaseEquipment.WAR_WEAPONS
	var legacy_weps: Dictionary = EquipmentWeapons.LEGACY_WAR_WEAPONS
	print("武器数：JSON=%d  LEGACY=%d" % [weps.size(), legacy_weps.size()])
	if weps.size() != 26:
		_fail("武器表应 26 条（24+2 新增），实际 %d" % weps.size())
	if weps.size() != legacy_weps.size():
		_fail("JSON 与 LEGACY 兜底武器数不同步：%d vs %d" % [weps.size(), legacy_weps.size()])
	for wid in weps.keys():
		if not legacy_weps.has(wid):
			_fail("LEGACY 兜底缺武器：%s" % wid)

	var rc_e: Dictionary = weps.get("steel_railcannon_expert", {})
	if rc_e.is_empty():
		_fail("缺 steel_railcannon_expert")
	elif String(rc_e.get("faction", "")) != "steel" or int(rc_e.get("level", 0)) != 18 or String(rc_e.get("type", "")) != "railcannon":
		_fail("steel_railcannon_expert 元数据错：%s" % str(rc_e))
	else:
		_pass += 1
	var im_e: Dictionary = weps.get("incendiary_mortar_expert", {})
	if im_e.is_empty():
		_fail("缺 incendiary_mortar_expert")
	elif String(im_e.get("faction", "")) != "flame" or int(im_e.get("level", 0)) != 19 or String(im_e.get("type", "")) != "mortar":
		_fail("incendiary_mortar_expert 元数据错：%s" % str(im_e))
	else:
		_pass += 1

	# ══════════ C: flame_siege 平台武器类别归线 ══════════
	var siege_w_line: Array = []
	for pid in ["flame_siege_basic", "flame_siege_advanced", "flame_siege_expert"]:
		var wid: String = EnemyPhaseEquipment.get_default_weapon_id_for_platform(pid)
		var wd: Dictionary = EnemyPhaseEquipment.get_war_weapon(wid)
		if wd.is_empty():
			_fail("平台 %s 的默认武器 %s 解析失败" % [pid, wid])
			continue
		siege_w_line.append(String(wd.get("type", "")))
	print("flame_siege 武器类别线：%s" % str(siege_w_line))
	var line_ok := true
	if siege_w_line.size() != 3:
		line_ok = false
	else:
		for t in siege_w_line:
			if String(t) != "mortar":
				line_ok = false
	if line_ok:
		_pass += 1
	else:
		_fail("flame_siege 线应全为 mortar，实际 %s" % str(siege_w_line))

	# ══════════ 全平台引用闭合 + 阵营/等级一致 ══════════
	var plats: Dictionary = EnemyPhaseEquipment.WAR_PLATFORMS
	var plat_issues := 0
	for pid in plats.keys():
		var pd: Dictionary = plats[pid]
		var wid: String = EnemyPhaseEquipment.get_default_weapon_id_for_platform(pid)
		var wd: Dictionary = EnemyPhaseEquipment.get_war_weapon(wid)
		if wid.is_empty() or wd.is_empty():
			_fail("平台 %s 默认武器断链（wid=%s）" % [pid, wid])
			plat_issues += 1
			continue
		if String(wd.get("faction", "")) != String(pd.get("faction", "")) or int(wd.get("level", -1)) != int(pd.get("level", -2)):
			_fail("平台 %s ↔ 武器 %s 阵营/等级不配" % [pid, wid])
			plat_issues += 1
	if plat_issues == 0:
		_pass += 1
	print("平台配对：%d/%d 通过" % [plats.size() - plat_issues, plats.size()])

	# ══════════ B: master_014 + 30 位 master 引用闭合 ══════════
	var masters: Array = EnemyPhaseMasters.ENEMY_MASTERS
	var m14: Dictionary = {}
	var m_issues := 0
	for m in masters:
		var mm: Dictionary = m
		if String(mm.get("id", "")) == "enemy_master_014":
			m14 = mm
		var eq: Dictionary = mm.get("equipment", {})
		for wref in eq.get("weapons", []):
			if EnemyPhaseEquipment.get_war_weapon(String(wref)).is_empty():
				_fail("master %s 引用无效武器 %s" % [String(mm.get("id", "")), String(wref)])
				m_issues += 1
	if m_issues == 0:
		_pass += 1
	if m14.is_empty():
		_fail("找不到 enemy_master_014（JSON 加载数=%d）" % masters.size())
	else:
		var w14: Array = (m14.get("equipment", {}) as Dictionary).get("weapons", [])
		print("master_014 weapons：%s" % str(w14))
		if w14.size() == 2 and String(w14[0]) == "steel_railcannon_expert" and String(w14[1]) == "tesla_coil_expert":
			_pass += 1
		else:
			_fail("master_014 weapons 应为 [steel_railcannon_expert, tesla_coil_expert]，实际 %s" % str(w14))

	# ══════════ A: 蓝图卡攻速语义（=1/间隔） ══════════
	var bp_mg = EnemyPhaseEquipment.get_equipment_blueprint("steel_machinegun_basic")
	var bp_cannon = EnemyPhaseEquipment.get_equipment_blueprint("steel_cannon_basic")
	if bp_mg == null:
		_fail("steel_machinegun_basic 蓝图卡生成失败")
	else:
		# 重标定后间隔 0.30s → 攻速 3.33 次/秒（原 0.15 间隔超游戏口径 3 倍）
		if absf(bp_mg.attack_speed - 1.0 / 0.3) < 0.01:
			_pass += 1
		else:
			_fail("机枪蓝图攻速应为 %.2f（1/0.30），实际 %.2f" % [1.0 / 0.3, bp_mg.attack_speed])
		if not bp_mg.summary_line.contains("次/秒"):
			_fail("机枪蓝图 summary 应含「次/秒」单位：%s" % bp_mg.summary_line)
		print("蓝图摘要示例：机枪 %s" % bp_mg.summary_line)
	if bp_cannon == null:
		_fail("steel_cannon_basic 蓝图卡生成失败")
	elif bp_mg != null:
		# 火炮 1.5s → 0.67 次/秒，必须慢于机枪 6.67 —— 修复前两者语义颠倒
		if bp_cannon.attack_speed < bp_mg.attack_speed:
			_pass += 1
		else:
			_fail("火炮蓝图攻速（%.2f）应慢于机枪（%.2f）" % [bp_cannon.attack_speed, bp_mg.attack_speed])

	# ══════════ D: 全表射速口径锁（v9.x 重标定回归） ══════════
	# 游戏真实口径：敌方原型速射最快 0.2s 间隔（5次/s）、我方卡最快 2次/s。
	# 敌方武器装备表为展示数据，封顶放宽到 7次/s（专家档巅峰 0.15s）。
	# 超过即视为未来新条目破坏口径，锁死。
	var rate_cap := 7.0
	var rate_violators: Array = []
	for wid in weps.keys():
		var wd2: Dictionary = weps[wid]
		var ivl2: float = float(wd2.get("attack_speed", 1.0))
		if ivl2 <= 0.0:
			rate_violators.append("%s(间隔≤0)" % wid)
			continue
		var rate2: float = 1.0 / ivl2
		if rate2 > rate_cap:
			rate_violators.append("%s(%.1f次/s)" % [wid, rate2])
	if rate_violators.is_empty():
		_pass += 1
		print("全表射速 ≤ %.0f次/s：通过（%d 条武器）" % [rate_cap, weps.size()])
	else:
		_fail("超射速口径上限 %.0f次/s 的武器：%s" % [rate_cap, str(rate_violators)])

	print("═══════════════════════════════════════════════════════════")
	if _code == 0:
		print("✅ 全部 %d 组断言通过" % _pass)
	else:
		print("❌ 存在失败项，见上方 [FAIL]")
	quit(_code)
