extends SceneTree
## v6.17.2 技能体系全量审计（--script headless，只读诊断）：
## A 相位师技能树（base+v8ext 合并视图）：id 唯一 / requires 存在性与环 / 分支层级 /
##   unlock 类型白名单与专属字段 / card_skill 引用存在 / 前置层级倒挂 / 点数经济
## B 卡片定时技能：引擎权威 effect.type 表 / trigger / interval / min_source_count
## C 敌方相位师树：composition 可调 / element clamp 语义
## D 势力技能树（平铺数组）+ 敌方协同数值
## E unit_mechanism / unit_ability / tactic 解锁 id 全项目消费代理检查
## 输出 PROBLEM 清单 + 备注 + 统计。运行：--headless --rendering-driver opengl3 --path . --script tests/_tmp_skills_audit.gd

var problems: Array = []
var infos: Array = []
var stats: Dictionary = {}


func _p(code: String, msg: String) -> void:
	problems.append("[%s] %s" % [code, msg])


func _initialize() -> void:
	var PMST = load("res://data/phase_master_skill_tree.gd")
	var V8 = load("res://data/phase_master_skill_tree_v8_extension.gd")
	var CPS = load("res://data/card_periodic_skills.gd")
	var EMST = load("res://data/enemy_master_skill_tree.gd")
	var FST = load("res://data/faction_skill_tree.gd")
	var EFS = load("res://data/enemy_faction_skills.gd")

	# ── A. 相位师树（get_skills_for_branch 已内含 v8ext 合并）──
	var nodes: Dictionary = {}
	for br in PMST.get_all_branches():
		for n in PMST.get_skills_for_branch(br):
			if nodes.has(n["id"]):
				_p("PM_DUP_ID", "重复节点 id: %s" % n["id"])
			nodes[n["id"]] = n
	for n in V8.get_all_extension_nodes():
		if not nodes.has(n["id"]):
			_p("PM_EXT_ORPHAN", "扩展节点 %s 不在合并视图中" % n["id"])
	stats["pm_nodes"] = nodes.size()

	var known_types := ["unit_ability", "unit_mechanism", "evolution", "affix",
		"card_skill", "tactic", "power_cap"]
	var legacy_types := ["concept_weapon", "special_card", "phase_instrument"]
	var branches := ["command", "intelligence", "firepower"]
	var unlock_ids_by_type: Dictionary = {}
	var total_cost := 0
	for id in nodes:
		var n: Dictionary = nodes[id]
		var idd := String(id)
		if not branches.has(String(n.get("branch", ""))):
			_p("PM_BRANCH", "%s 非法分支 %s" % [idd, n.get("branch")])
		if int(n.get("tier", -1)) < 0:
			_p("PM_TIER", "%s tier 非法" % idd)
		if int(n.get("cost", -1)) < 0:
			_p("PM_COST", "%s cost 非法" % idd)
		else:
			total_cost += int(n.get("cost", 0))
		var req = n.get("requires", [])
		if req is Array:
			for r in req:
				var rid := String(r)
				if not nodes.has(rid):
					_p("PM_REQ_MISS", "%s 前置不存在: %s" % [idd, rid])
				elif rid == idd:
					_p("PM_REQ_SELF", "%s 前置指向自己" % idd)
				elif String(nodes[rid].get("branch")) == String(n.get("branch")):
					var rt := int(nodes[rid].get("tier", 0))
					var st := int(n.get("tier", 0))
					if rt > st:
						_p("PM_TIER_BACKWARDS", "%s(tier%d) 前置 %s(tier%d) 层级倒挂" % [idd, st, rid, rt])
					elif rt == st:
						infos.append("同层级并列前置: %s <- %s（分叉设计）" % [idd, rid])
		else:
			_p("PM_REQ_TYPE", "%s requires 不是数组" % idd)
		var unl = n.get("unlocks", [])
		var eff = n.get("effects", {})
		var has_eff: bool = (eff is Dictionary) and not eff.is_empty()
		if not (unl is Array) or unl.is_empty():
			if not has_eff:
				_p("PM_DEAD_NODE", "%s unlocks 与 effects 双空（死节点）" % idd)
			continue
		for u in unl:
			var t := String(u.get("type", ""))
			var uid_ := String(u.get("id", ""))
			if not known_types.has(t):
				if legacy_types.has(t):
					_p("PM_LEGACY_UNLOCK", "%s 使用废弃类型 %s" % [idd, t])
				else:
					_p("PM_UNLOCK_TYPE", "%s 未知 unlock.type: %s" % [idd, t])
				continue
			if t == "card_skill":
				if uid_.is_empty() or CPS.get_skill(uid_).is_empty():
					_p("PM_CARD_SKILL_MISS", "%s 解锁的定时技能不存在: %s" % [idd, uid_])
				continue
			if uid_.is_empty():
				var ok_field := false
				match t:
					"power_cap":
						ok_field = int(u.get("value", 0)) > 0
					"evolution":
						ok_field = u.has("era")
					"affix":
						var pool = u.get("pool", [])
						ok_field = (pool is Array) and not pool.is_empty()
					_:
						ok_field = false
				if not ok_field:
					_p("PM_UNLOCK_FIELD", "%s unlock(type=%s) 缺专属字段" % [idd, t])
				if t == "power_cap" and int(u.get("value", 0)) > 0:
					if not unlock_ids_by_type.has(t):
						unlock_ids_by_type[t] = {}
					unlock_ids_by_type[t]["value:%d" % int(u.get("value", 0))] = idd
				continue
			if not unlock_ids_by_type.has(t):
				unlock_ids_by_type[t] = {}
			unlock_ids_by_type[t][uid_] = idd
	# 环检测
	var color: Dictionary = {}
	for id0 in nodes:
		if _dfs_cycle(String(id0), nodes, color):
			_p("PM_CYCLE", "前置链存在环（含 %s）" % id0)
	var pts: Array = PMST.POINTS_BY_PHASE_FIELD_LEVEL
	if pts.size() != 31:
		_p("PM_POINTS_LEN", "点数表长度 %d ≠ 31" % pts.size())
	for i in range(1, pts.size()):
		if int(pts[i]) < int(pts[i - 1]):
			_p("PM_POINTS_MONO", "点数表在 Lv%d 回落" % i)
	stats["pm_total_cost"] = total_cost
	stats["pm_points_lv30"] = int(pts[pts.size() - 1]) if pts.size() >= 31 else -1

	# ── B. 卡片定时技能（引擎权威字段/类型表，未知类型引擎静默忽略）──
	var valid_effect := ["area_damage", "single_target_damage", "global_damage",
		"chain_damage", "debuff_target", "debuff_area", "debuff_global",
		"debuff_spread", "buff_allies", "execute"]
	var valid_family := ["steel", "flame", "thunder", "void", ""]
	var cps_ids: Array = CPS.get_all_skill_ids()
	stats["cps_count"] = cps_ids.size()
	for sid in cps_ids:
		var s: Dictionary = CPS.get_skill(sid)
		var et := String(s.get("effect", {}).get("type", ""))
		if not valid_effect.has(et):
			_p("CPS_EFFECT", "定时技能 %s effect.type 引擎不分发: %s" % [sid, et])
		var fam := String(s.get("family", ""))
		if not valid_family.has(fam):
			_p("CPS_FAMILY", "定时技能 %s family 非法: %s" % [sid, fam])
		var trig := String(s.get("trigger", ""))
		if trig != "periodic":
			_p("CPS_TRIGGER", "定时技能 %s trigger 非法: %s" % [sid, trig])
		elif float(s.get("interval", 0.0)) <= 0.0:
			_p("CPS_INTERVAL", "定时技能 %s periodic 但 interval ≤ 0" % sid)
		if int(s.get("min_source_count", 0)) < 0:
			_p("CPS_SRC", "定时技能 %s min_source_count < 0" % sid)

	# ── C. 敌方相位师树 ──
	var masters: Dictionary = EMST.MASTER_NODES
	stats["enemy_masters"] = masters.size()
	for mid in masters:
		var comp: Dictionary = EMST.get_composition(String(mid), 10)
		if comp.is_empty():
			_p("EM_COMP", "敌方相位师 %s composition 为空" % mid)

	# ── D. 势力树（平铺数组）+ 敌方协同 ──
	var ftree: Dictionary = FST.SKILL_TREE
	var fcount := 0
	for fid in ftree:
		var flat: Array = ftree[fid]
		if not (flat is Array):
			_p("F_SHAPE", "势力 %s 技能表不是数组" % fid)
			continue
		var fids: Dictionary = {}
		for s in flat:
			if not (s is Dictionary):
				_p("F_SHAPE", "势力 %s 技能表含非字典项" % fid)
				continue
			fcount += 1
			var sid2 := String(s.get("id", ""))
			if sid2.is_empty():
				_p("F_ID", "势力 %s 有空 id 技能" % fid)
			elif fids.has(sid2):
				_p("F_DUP", "势力 %s 重复技能 id %s" % [fid, sid2])
			fids[sid2] = true
		for s in flat:
			for r in s.get("requires", []):
				if not fids.has(String(r)):
					_p("F_REQ_MISS", "势力 %s 技能 %s 前置不存在: %s" % [fid, s.get("id"), r])
	stats["faction_skills"] = fcount
	stats["faction_count"] = ftree.size()
	var syn: Dictionary = EFS.MASTER_SYNERGY
	stats["enemy_synergy"] = syn.size()
	for mid2 in syn:
		# ⚠️ get_synergy_numeric 是恒返 0 的未实装桩（设计如此），真数值在表内 synergy_boost
		var row: Dictionary = syn[mid2]
		var v: float = float(row.get("synergy_boost", -1.0))
		if v <= 0.0 or v > 3.0:
			_p("EFS_VALUE", "敌方协同 %s synergy_boost 越界: %s" % [mid2, v])

	# ── E. 解锁 id 消费代理检查 ──
	for t in ["unit_mechanism", "unit_ability", "tactic"]:
		var ids: Array = unlock_ids_by_type.get(t, {}).keys()
		stats["unlock_%s" % t] = ids.size()
		for mid3 in ids:
			if _grep_count(String(mid3)) == 0:
				_p("UNLOCK_NO_CONSUMER", "%s 解锁 id 全项目零消费: %s" % [t, mid3])

	# ── 汇总 ──
	print("==== 技能审计统计 ====")
	for k in stats:
		print("  %s = %s" % [k, stats[k]])
	print("==== 问题清单（%d）====" % problems.size())
	for p in problems:
		print("  [P] ", p)
	print("==== 备注/设计确认（%d）====" % infos.size())
	for i2 in infos:
		print("  [i] ", i2)
	if problems.is_empty():
		print("SKILLS_AUDIT_OK")
	else:
		print("SKILLS_AUDIT_ISSUES %d" % problems.size())
	quit(0 if problems.is_empty() else 1)


func _dfs_cycle(id: String, nodes: Dictionary, color: Dictionary) -> bool:
	var c := int(color.get(id, 0))
	if c == 1:
		print("  [CYCLE PATH] ", id)
		return true
	if c == 2:
		return false
	color[id] = 1
	for r in nodes[id].get("requires", []):
		if nodes.has(String(r)) and _dfs_cycle(String(r), nodes, color):
			return true
	color[id] = 2
	return false


func _grep_count(needle: String) -> int:
	var out: Array = []
	OS.execute("grep", ["-r", "--include=*.gd", "-rl", needle,
		"scripts/", "scenes/", "data/", "managers/"], out, true)
	var files := 0
	for line in String(out[0] if out.size() > 0 else "").split("\n", false):
		files += 1
	return files
