extends SceneTree
## 临时审计（只读）：武器命名 → 分类层全量对齐巡检（v38.3 后续）
## 动机：线膛炮/RPG 类"单发语义被兜底桶吞掉"的问题不该靠实机肉眼发现——
## 本探针把「武器名语义关键词 vs 实际弹道/亚类/贴图层」的错位全部扫出来。
##
## 规则分级：
##   R1 [应零容忍] 直射槽含重炮语义（主炮/滑膛炮/线膛炮/坦克炮/加农炮/反坦克炮/火炮，
##       排除 高炮/防空炮/高射炮/近防炮/迫击炮/榴弹炮/要塞炮/野战炮/舰炮）但亚类 != TANK_GUN
##   R2 [观感债] 直射槽含"炮"但落 GENERIC（被排除词表挡住——重炮名吃步枪级曳光配方）
##   R3 [弹道漏网] 名含硬光束语义（激光/光束/粒子/等离子/雷射/狙击/轨道炮/电磁炮）但槽弹道 ∉ {6,8,10,11}
##   R4 [待裁决] 名含 导弹/火箭 但槽弹道 = DIRECT(0)（炮射导弹/火箭筒平射合法，列出去留用户定）
##   R5 [命名债] 槽武器名是占位名（轻装武器/装甲武器/对空武器/空）——分类层全失效
##   R6 [贴图覆盖] 名不在 WeaponVfxMapping.WEAPON_ID_MAP → 无专属弹体/命中贴图（统计）
## 敌方侧同规则跑 weapon_label（单名三槽，模拟 enemy_unit._ensure_enemy_weapon_slots 分配）。

const DefaultCards = preload("res://data/default_cards.gd")
const DWF = preload("res://data/direct_weapon_flavor.gd")
const CardRes = preload("res://resources/card_resource.gd")
const WeaponVfxMapping = preload("res://data/weapon_vfx_mapping.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const GC = preload("res://resources/game_constants.gd")

const _GUN_KW := ["主炮", "滑膛炮", "线膛炮", "坦克炮", "加农炮", "反坦克炮", "火炮"]
const _GUN_EXCLUDE := ["高炮", "防空炮", "高射炮", "近防炮", "迫击炮", "榴弹炮", "要塞炮", "野战炮", "舰炮"]
const _BEAM_STRICT := ["激光", "光束", "粒子", "等离子", "雷射", "狙击", "轨道炮", "电磁炮"]
const _BEAM_FUZZY := ["离子", "电磁", "磁轨", "光棱"]
const _MISSILE_KW := ["导弹", "火箭"]
const _PLACEHOLDER := ["轻装武器", "装甲武器", "对空武器", ""]

var _findings: Array[String] = []

func _is_gun_semantic(nm: String) -> bool:
	if nm.find("炮") < 0 and nm.find("主炮") < 0:
		return false
	for ex in _GUN_EXCLUDE:
		if nm.find(ex) >= 0:
			return false
	for kw in _GUN_KW:
		if nm.find(kw) >= 0:
			return true
	return false

func _audit_slot(side: String, owner_id: String, owner_name: String, slot_tag: String,
		nm: String, wt: int, unit_wt: int) -> void:
	if nm == "" or wt < 0:
		return
	var flv: int = DWF.classify(nm, wt)
	var where := "%s %s(%s) %s槽[%s] wt=%d" % [side, owner_name, owner_id, slot_tag, nm, wt]
	# R1 重炮语义但亚类漏网
	if wt == 0 and _is_gun_semantic(nm) and flv != DWF.Flavor.TANK_GUN:
		_findings.append("R1 %s -> 亚类=%d（应为 TANK_GUN=4）" % [where, flv])
	# R2 排除词挡住的重炮名落 GENERIC
	if wt == 0 and flv == DWF.Flavor.GENERIC and nm.find("炮") >= 0:
		_findings.append("R2 %s -> GENERIC 重炮名吃步枪级配方" % where)
	# R3 硬光束语义未进光束弹道
	for kw in _BEAM_STRICT:
		if nm.find(kw) >= 0 and not (wt in [6, 8, 10, 11]):
			_findings.append("R3 %s -> 含'%s'但弹道=%d 非光束族" % [where, kw, wt])
			break
	# R3b 软光束语义（仅记录）
	for kw in _BEAM_FUZZY:
		if nm.find(kw) >= 0 and not (wt in [6, 8, 10, 11]) and nm.find("电磁步枪") < 0:
			_findings.append("R3b %s -> 含'%s'弹道=%d（软语义，仅记录）" % [where, kw, wt])
			break
	# R4 导弹/火箭语义在直射槽
	for kw in _MISSILE_KW:
		if nm.find(kw) >= 0 and wt == 0:
			_findings.append("R4 %s -> 含'%s'走直射（平射合法与否待裁决）" % [where, kw])
			break
	# R5 占位名
	if nm in _PLACEHOLDER:
		_findings.append("R5 %s -> 占位武器名，分类层全失效" % where)
	# R6 无专属贴图
	if wt != 1 and wt != 2 and String(WeaponVfxMapping.get_weapon_safe_id(nm)) == "" and nm != "":
		_findings.append("R6 %s -> 无专属弹体/命中贴图（降级 wt 通用层）" % where)

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	# ── 玩家侧：131 卡 × 3 槽（真实槽位构建含 trajectory override）──
	var cards: Array = DefaultCards.create_all()
	var slot_names: Array[String] = ["轻装", "装甲", "对空"]
	var n_p := 0
	for c in cards:
		if not (c is CardResource):
			continue
		n_p += 1
		c._ensure_weapon_slots_initialized()
		for i in 3:
			var w = c.weapon_slots[i]
			if w == null or not w.enabled:
				continue
			_audit_slot("玩家", c.card_id, c.display_name, slot_names[i],
				String(w.display_name), int(w.weapon_type), int(c.weapon_type))
	print("[progress] 玩家侧完成 %d 卡，用时 %d ms" % [n_p, Time.get_ticks_msec() - t0])
	# ── 敌方侧：原型表 weapon_label 单名三槽 ──
	var t1 := Time.get_ticks_msec()
	var ids: Array = EnemyArchetypes.get_all_ids()
	print("[progress] get_all_ids=%d，用时 %d ms" % [ids.size(), Time.get_ticks_msec() - t1])
	var n_e := 0
	var t2 := Time.get_ticks_msec()
	for id_v in ids:
		var aid := String(id_v)
		var cfg: Dictionary = EnemyArchetypes.get_config(aid)
		if cfg.is_empty():
			continue
		var label := String(cfg.get("weapon_label", ""))
		if label.is_empty():
			continue
		n_e += 1
		var uwt := int(cfg.get("weapon_type", 0))
		var ck := int(cfg.get("combat_kind", 0))
		# 模拟 _default_enemy_slot_weapon_type（航空全 AERIAL / 曲射 legacy 全 INDIRECT / 其余 0,0,9）
		var slot_wts: Array = []
		if ck == 2:  # AIR
			slot_wts = [2, 2, 2]
		elif uwt in [3, 7, 9, 11] or (uwt == 1 and ck == 3):
			slot_wts = [1, 1, 1]
		else:
			slot_wts = [0, 0, 9]
		for i in 3:
			var swt: int = slot_wts[i]
			# v38.3: 覆盖门放宽到全部槽（与 enemy_unit._ensure_enemy_weapon_slots 同口径）
			var trj: int = CardRes.trajectory_override_for_weapon_name(label, uwt)
			if trj >= 0:
				swt = trj
			_audit_slot("敌方", aid, String(cfg.get("display_name", aid)), ["轻装", "装甲", "对空"][i],
				label, swt, uwt)
		if n_e % 30 == 0:
			print("[progress] 敌方已扫 %d/%d，用时 %d ms" % [n_e, ids.size(), Time.get_ticks_msec() - t2])
	print("=== 语义审计完成：玩家 %d 卡 / 敌方 %d 原型，共 %d 条发现 ===" % [n_p, n_e, _findings.size()])
	var by_rule: Dictionary = {}
	for f in _findings:
		var rule := String(f).split(" ", false, 2)[0]  # "R3b x" → "R3b"，"R2 x" → "R2"
		if not by_rule.has(rule):
			by_rule[rule] = []
		(by_rule[rule] as Array).append(f)
	for rule in ["R1", "R2", "R3", "R3b", "R4", "R5", "R6"]:
		var arr: Array = by_rule.get(rule, [])
		print("\n---- %s：%d 条 ----" % [rule, arr.size()])
		for f in arr:
			print(f)
	# ── 基线数据：GENERIC/占位名去重清单（供 WeaponSemantics 哨兵 known 名单收编）──
	var generic_names := {}
	for c in cards:
		if not (c is CardResource):
			continue
		c._ensure_weapon_slots_initialized()
		for i in 3:
			var w = c.weapon_slots[i]
			if w == null or not w.enabled:
				continue
			var nm := String(w.display_name)
			if nm != "" and DWF.classify(nm, int(w.weapon_type)) == DWF.Flavor.GENERIC:
				generic_names[nm] = true
	for id_v in ids:
		var cfg3: Dictionary = EnemyArchetypes.get_config(String(id_v))
		if cfg3.is_empty():
			continue
		var label3 := String(cfg3.get("weapon_label", ""))
		if label3 != "":
			for swt3 in [0, 1, 2, 9]:
				if DWF.classify(label3, swt3) == DWF.Flavor.GENERIC:
					generic_names[label3] = true
					break
	print("\n---- GENERIC 兜底在册名单（去重 %d 个）----" % generic_names.size())
	for nm in generic_names:
		print("GENERIC_NAME %s" % nm)
	# ── 基线数据：按名贴图层死链计数（proj/impact）──
	var vmap = preload("res://data/weapon_vfx_mapping.gd")
	var dead_proj := 0
	var dead_impact := 0
	var total := 0
	for pair in vmap.WEAPON_ID_MAP:
		total += 1
		var sid := String(vmap.WEAPON_ID_MAP[pair])
		if not ResourceLoader.exists("res://assets/effects/projectiles/weapons_realistic/%s_proj.png" % sid):
			dead_proj += 1
		if not ResourceLoader.exists("res://assets/effects/projectiles/weapons_realistic/%s_impact.png" % sid):
			dead_impact += 1
	print("\n---- 按名贴图层健康度：映射 %d 条 / proj 死链 %d / impact 死链 %d ----" % [total, dead_proj, dead_impact])
	quit()
