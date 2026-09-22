extends SceneTree
## tests/level_design_audit_smoke.gd — 关卡设计审查（2026-08-16）回归验证
##
## 覆盖分类（对应审查报告 A–M 编号）：
##   A1  100 关字段完备
##   A2  引用可解析（驻守相位师 id / 势力 id / 法则家族 / restrict 枚举值）
##   A3  死键清零（environment / difficulty_modifier / 死描述条目）
##   B5  驻守关禁挂 win_type（_set_rules 守卫生效）
##   G1  关卡名非空 / 无重名
##   H1  win_type 不存在于任何关卡
##   H2  restrict 白名单内各 combat_kind 在对应时代卡池 ≥2 张（可玩性下限）
##   L3  边界关号（0/101）clamp 行为
##
## 运行：
##   Godot --headless --rendering-driver opengl3 --path . --script tests/level_design_audit_smoke.gd

const LevelInfoScript = preload("res://data/level_information.gd")
const LevelEras = preload("res://data/level_eras.gd")
const Garrison = preload("res://data/phase_master_garrison.gd")
const Tiers = preload("res://data/enemy_loadout_tiers.gd")

var fails: int = 0
var passes: int = 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		print("  [FAIL] ", msg)

func _init() -> void:
	print("=== 关卡设计审查回归 smoke ===")
	var li = LevelInfoScript.get_shared()

	# ── A1/A3: 字段完备 + 死键清零 ──────────────────────────────
	var db: Dictionary = li._level_db
	_ok(db.size() == 100, "关卡总数应为 100，实际 %d" % db.size())
	var allowed_keys: Array = ["display_name", "description", "faction_id", "available_law_families", "special_rules"]
	for lv in range(1, 101):
		var entry: Dictionary = db.get(lv, {})
		if entry.is_empty():
			_ok(false, "关卡 %d 缺记录" % lv)
			continue
		for k in entry.keys():
			_ok(k in allowed_keys, "关卡 %d 含非法键 %s" % [lv, k])
		_ok(not entry.get("display_name", "").is_empty(), "关卡 %d 名称空" % lv)
		_ok(not entry.get("description", "").is_empty(), "关卡 %d 描述空" % lv)
		_ok(String(entry.get("display_name", "")).length() <= 16, "关卡 %d 名称超长: %s" % [lv, entry.get("display_name")])

	# ── A3: environment / difficulty_modifier 全量清零 ──────────
	for lv in range(1, 101):
		var e2: Dictionary = db.get(lv, {})
		_ok(not e2.has("environment"), "关卡 %d 残留 environment 死键" % lv)
		_ok(not e2.has("difficulty_modifier"), "关卡 %d 残留 difficulty_modifier 死键" % lv)

	# ── H1/H2: 特殊规则挂载点 + 值域 ────────────────────────────
	# 2026-09-21 勘误：v26~v32 特殊规则扩到全战线（首批 11 关 → 53 关），
	# 快照等值断言改为结构断言——挂载集非空 + 机制锚点关在位 + 每条规则值域合法。
	var actual_rule_levels: Array = []
	for lv in range(1, 101):
		if not li.get_special_rules(lv).is_empty():
			actual_rule_levels.append(lv)
	_ok(not actual_rule_levels.is_empty(), "特殊规则挂载关为空（数据异常）")
	_ok(actual_rule_levels.has(5) and actual_rule_levels.has(85) and actual_rule_levels.has(100),
		"机制锚点关（5/85/100）应挂特殊规则，实际挂载 %d 关" % actual_rule_levels.size())
	for lv in actual_rule_levels:
		var r: Dictionary = li.get_special_rules(lv)
		_ok(not r.has("win_type"), "关卡 %d 仍挂 win_type（驻守关死规则）" % lv)
		var restrict: Array = r.get("restrict_platforms", [])
		for pt in restrict:
			_ok(int(pt) >= 0 and int(pt) <= 4, "关卡 %d restrict 值 %s 超出 CombatKind(0-4)" % [lv, str(pt)])
	_ok(li.get_special_rules(85).get("restrict_platforms", []) == [2], "第85关 restrict 应为 [2]（SUPPORT）")

	# ── B5: _set_rules 守卫——驻守关拒绝 win_type，合法规则不受影响 ──
	# 2026-09-21 勘误：驻守关现已合法挂载非 win_type 规则（如 L20 boss_enrage_half），
	# 守卫断言改为"win_type 被拒 + 既有合法规则原样保留"（旧断言 rules 应为空已过期）。
	var garrison_probe: int = int(Garrison.get_all_garrison_levels()[0])
	var rules_before: Dictionary = li.get_special_rules(garrison_probe).duplicate()
	li._set_rules(garrison_probe, {"win_type": "survive_waves", "win_param": 5})
	var rules_after: Dictionary = li.get_special_rules(garrison_probe)
	_ok(not rules_after.has("win_type"), "守卫失效：第%d关（驻守）挂上了 win_type" % garrison_probe)
	_ok(rules_after == rules_before, "守卫误伤：第%d关既有合法规则被改动" % garrison_probe)
	li._set_rules(garrison_probe, {"energy_mult": 0.5})
	_ok(absf(float(li.get_special_rules(garrison_probe).get("energy_mult", 1.0)) - 0.5) < 0.001,
		"守卫过严：第%d关合法规则（能量惩罚）应可挂载" % garrison_probe)

	# ── A2: 驻守相位师 id 全部存在于 masters JSON ────────────────
	var json_text: String = FileAccess.get_file_as_string("res://data/json/enemy_phase_masters.json")
	_ok(not json_text.is_empty(), "enemy_phase_masters.json 读取失败")
	var parsed = JSON.parse_string(json_text)
	_ok(parsed is Dictionary or parsed is Array, "enemy_phase_masters.json 解析失败")
	var master_ids: Array = []
	if parsed is Dictionary and parsed.has("data") and parsed["data"] is Array:
		for m in parsed["data"]:
			master_ids.append(String(m.get("id", "")))
	elif parsed is Array:
		for m in parsed:
			master_ids.append(String(m.get("id", "")))
	var garrison_levels: Array = Garrison.get_all_garrison_levels()
	_ok(garrison_levels.size() == 20, "驻守关应 20 个，实际 %d" % garrison_levels.size())
	for glv in garrison_levels:
		var mid: String = Garrison.get_garrison_master_id(int(glv))
		_ok(master_ids.has(mid), "驻守关 %d 的相位师 %s 不在 masters JSON" % [int(glv), mid])

	# ── A2: 势力 id / 法则家族值域 ──────────────────────────────
	# 2026-09-21 勘误：法则系统已随 P2-7 退役，available_law_families 全 100 关清空——
	# "每关至少1个"断言过期删除；保留"若字段存在则值必须合法"的防御性校验。
	var legal_factions: Array = ["", "nova_arms", "aether_dynamics", "quantum_logistics", "helix_recon", "void_research"]
	var legal_families: Array = ["STEEL", "FLAME", "THUNDER", "VOID"]
	for lv in range(1, 101):
		_ok(String(db[lv].get("faction_id", "?")) in legal_factions, "关卡 %d 势力 id 非法: %s" % [lv, db[lv].get("faction_id")])
		var fams: Array = db[lv].get("available_law_families", [])
		for f in fams:
			_ok(String(f) in legal_families, "关卡 %d 法则家族非法: %s" % [lv, str(f)])

	# ── G1: 无重名 ─────────────────────────────────────────────
	var seen_names: Dictionary = {}
	for lv in range(1, 101):
		var nm: String = String(db[lv].get("display_name", ""))
		if seen_names.has(nm):
			_ok(false, "关卡重名: %s（%d 与 %d）" % [nm, int(seen_names[nm]), lv])
		else:
			seen_names[nm] = lv

	# ── H2: restrict 关 × 对应时代卡池可玩性（每 kind ≥2 张）─────
	var restrict_map: Dictionary = {15: [0], 30: [1], 55: [2, 3], 85: [2]}
	var table = load("res://data/unified_card_table.gd")
	for lv in restrict_map.keys():
		var era: int = LevelEras.get_era(int(lv))
		var entries: Array = table.get_entries_by_era(era)
		for kind in restrict_map[lv]:
			var count: int = 0
			for ent in entries:
				if int(ent.get("combat_kind", -1)) == int(kind):
					count += 1
			_ok(count >= 2, "关卡 %d 限定 kind=%d 在时代 %d 卡池仅 %d 张（<2 不可玩）" % [int(lv), int(kind), era, count])

	# ── K1: 时代首关档位回撤（敌配置档位低档）──────────────────
	for e in range(0, 5):
		var first_lv: int = e * 20 + 1
		var last_lv: int = e * 20 + 20
		var tier_first: int = Tiers.get_tier_for_level_progress(0.0)
		var tier_last: int = Tiers.get_tier_for_level_progress(1.0)
		_ok(tier_first == Tiers.TIER_LOW, "时代 %d 首关应低配档" % e)
		_ok(tier_last == Tiers.TIER_HIGH, "时代 %d 末关应高配档" % e)

	# ── L3: 边界关号 ───────────────────────────────────────────
	_ok(li.get_special_rules(0).is_empty() and li.get_special_rules(101).is_empty(), "边界关号 0/101 应返回空规则")
	_ok(li.get_level_info(0).is_empty() and li.get_level_info(101).is_empty(), "边界关号 0/101 应返回空信息")

	# ── 编译验证：本轮改动的文件可加载 ──────────────────────────
	for p in [
		"res://data/level_information.gd",
		"res://data/level_eras.gd",
		"res://data/enemy_stat_resolver.gd",
		"res://data/phase_master_garrison.gd",
		"res://managers/ui_lazy_loader.gd",
		"res://managers/battle/battle_damage_system.gd",
		"res://scenes/world_map.gd",
	]:
		var scr = load(p)
		_ok(scr != null, "文件加载/编译失败: %s" % p)

	print("=== 结果: %d PASS / %d FAIL ===" % [passes, fails])
	quit(1 if fails > 0 else 0)
