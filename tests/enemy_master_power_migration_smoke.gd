# v18 敌方相位师四源重构 · 守恒验证 smoke test（永久）
# 用法: godot --headless --rendering-driver opengl3 --path . --script tests/enemy_master_power_migration_smoke.gd
#
# 覆盖：
#   1. 51 大招守恒（EnemyMasterInstruments vs docs/migration_baseline.json）
#   2. master 数据三字段（traits/active_spells/passive_spells）删净
#   3. 技能树组合关键断言（等级曲线/误路由修复/元素clamp/意外加成移除）
#   4. 逐 master 强度比率 vs docs/migration_ratio_check.json（回归锁：数据/曲线漂移即失败）
#   5. 访问器兜底（EnemyPhaseMasters 三访问器）
extends SceneTree

const EnemyMasterInstruments := preload("res://data/enemy_master_instruments.gd")
const EnemyMasterSkillTree := preload("res://data/enemy_master_skill_tree.gd")
const EnemyFactionSkills := preload("res://data/enemy_faction_skills.gd")
const EnemyPhaseMasters := preload("res://data/enemy_phase_masters.gd")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")
const CardGrowthConfig := preload("res://data/card_growth_config.gd")

var errors: int = 0
var checks: int = 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("OK: ", msg)
	else:
		push_error("FAIL: " + msg)
		errors += 1


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("打不开 " + path)
		errors += 1
		return {}
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	return d


## 与 tools/regen_migration_ratio_flat.gd 同口径：每数值节点取一次乘区（三维同值）
func _node_scalar(fx: Dictionary, prefix: String, solo: String) -> float:
	if fx.has(prefix + "light"):
		return 1.0 + float(fx[prefix + "light"])
	if fx.has(prefix + "armor"):
		return 1.0 + float(fx[prefix + "armor"])
	if fx.has(prefix + "air"):
		return 1.0 + float(fx[prefix + "air"])
	if fx.has(solo):
		return 1.0 + float(fx[solo])
	return 1.0


func _median(vals: Array) -> float:
	if vals.is_empty():
		return 1.0
	vals.sort()
	return float(vals[vals.size() / 2])


## 各时代敌方 archetype 中位基数（与 regen 脚本同算法——flat 等效乘区分母）
func _era_medians() -> Dictionary:
	var buckets: Dictionary = {}
	for era in range(5):
		buckets[era] = {"atk": [], "hp": [], "def": []}
	for id in EnemyArchetypes.ARCHETYPES.keys():
		var cfg: Dictionary = EnemyArchetypes.get_config(String(id))
		if cfg.is_empty():
			continue
		var era: int = int(cfg.get("era", -1))
		if era < 0 or era > 4:
			continue
		var b: Dictionary = buckets[era]
		var atk: float = 0.0
		if cfg.has("attack_light") or cfg.has("attack_armor") or cfg.has("attack_air"):
			atk = maxf(float(cfg.get("attack_light", 0.0)), maxf(float(cfg.get("attack_armor", 0.0)), float(cfg.get("attack_air", 0.0))))
		else:
			atk = float(cfg.get("attack_damage", 0.0))
		if atk > 0.0:
			b.atk.append(atk)
		var hp: float = float(cfg.get("hp", 0.0))
		if hp > 0.0:
			b.hp.append(hp)
		var df: float = float(cfg.get("defense", 0.0))
		if df > 0.0:
			b.def.append(df)
	var out: Dictionary = {}
	for era in range(5):
		var b: Dictionary = buckets[era]
		out[era] = {"atk": _median(b.atk), "hp": _median(b.hp), "def": _median(b.def)}
	return out


func _era_str_to_int(s: String) -> int:
	match s.to_lower():
		"ww1": return 0
		"ww2": return 1
		"cold": return 2
		"modern": return 3
		"future", "near_future": return 4
		_: return -1


## 与 regen 脚本同口径：数值节点乘区 × 等级 flat 等效乘区（1 + flat/时代中位）× 元素(仅atk)
func _comp_scalar(comp: Dictionary, dim: String, m_era: int, lv: int, med: Dictionary) -> float:
	var m: float = 1.0
	for n in comp.get("num", []) as Array:
		var fx: Dictionary = n.get("effects", {}) as Dictionary
		if dim == "atk":
			m *= _node_scalar(fx, "atk_", "")
		elif dim == "def":
			m *= _node_scalar(fx, "def_", "")
		elif dim == "hp":
			m *= _node_scalar(fx, "", "hp")
	# v18.c: 等级通道 = flat 等效乘区（原 % 曲线已移除，换 CardGrowthConfig 同表）
	var growth: Dictionary = CardGrowthConfig.total_growth_raw(clampi(m_era, 0, 4), 0, "rare", lv)
	var med_e: Dictionary = med.get(clampi(m_era, 0, 4), {"atk": 1.0, "hp": 1.0, "def": 1.0})
	var denom: float = maxf(1.0, float(med_e.get(dim, 1.0)))
	m *= 1.0 + float(growth.get(dim, 0.0)) / denom
	if dim == "atk":
		var elem: Dictionary = comp.get("element", {}) as Dictionary
		if not elem.is_empty():
			m *= float(elem.get("mult", 1.0))
	return m


func _initialize() -> void:
	# ── 1. 大招守恒 ──
	var baseline: Dictionary = _load_json("res://docs/migration_baseline.json")
	var bl_masters: Array = baseline.get("masters", [])
	var total: int = 0
	var mismatch: int = 0
	for bl in bl_masters:
		var mid: String = String(bl.get("id", ""))
		var now_arr: Array = EnemyMasterInstruments.get_master_ultimate_spells(mid)
		var bl_arr: Array = bl.get("active_spells", [])
		if now_arr.size() != bl_arr.size():
			mismatch += 1
			continue
		for i in range(bl_arr.size()):
			var b: Dictionary = bl_arr[i]
			var n: Dictionary = now_arr[i]
			if String(b.get("id")) != String(n.get("id")) \
					or absf(float(b.get("cooldown", 0)) - float(n.get("cooldown", 0))) > 0.001 \
					or String(b.get("effect")) != String(n.get("effect")):
				mismatch += 1
			total += 1
	check(mismatch == 0 and total == 51, "51 大招守恒（id/cooldown/effect 全一致，mismatch=%d）" % mismatch)

	# ── 2. 三字段删净 ──
	var masters: Array = EnemyPhaseMasters.ENEMY_MASTERS
	var leftover: int = 0
	for m in masters:
		if m is Dictionary:
			for fld in ["traits", "active_spells", "passive_spells"]:
				if (m as Dictionary).has(fld):
					leftover += 1
	check(leftover == 0 and masters.size() == 30, "30 master 三字段删净（leftover=%d）" % leftover)

	# ── 3. 组合关键断言 ──
	# v18.c: 等级属性 % 曲线已移除（derive_level_stat_bonus 删除），换 flat 统一表锁：
	var g30: Dictionary = CardGrowthConfig.total_growth_raw(2, 0, "rare", 30)
	check(absf(float(g30.atk) - 1.3 * 45.0) < 0.01 and absf(float(g30.hp) - 7.0 * 45.0) < 0.01,
		"等级flat锁：冷战 LIGHT rare Lv30 = atk+%.1f hp+%.1f" % [float(g30.atk), float(g30.hp)])
	var comp001: Dictionary = EnemyMasterSkillTree.get_composition("enemy_master_001", 5)
	check(not comp001.has("level"), "组合不再携带 level % 曲线通道（flat 由 driver 注入）")
	var c26: Dictionary = EnemyMasterSkillTree.get_composition("enemy_master_026", 28)
	var heal26: int = 0
	for n in c26.get("mech", []) as Array:
		if String(n.get("kind", "")) == "aura_heal":
			heal26 += 1
	check(heal26 >= 1, "m026 治疗光环 kind=aura_heal（误路由修复）")
	var c29: Dictionary = EnemyMasterSkillTree.get_composition("enemy_master_029", 30)
	var e29: Dictionary = c29.get("element", {}) as Dictionary
	check(int(e29.get("affinity", 0)) == 3 and absf(float(e29.get("mult", 0)) - 2.0) < 0.001,
		"m029 元素 void clamp 2.0")
	var syn13: Dictionary = EnemyFactionSkills.get_synergy("enemy_master_013")
	check(absf(float(syn13.get("synergy_boost", 0)) - 0.25) < 0.001, "m013 协同 0.25 钢焰")
	check(absf(EnemyFactionSkills.get_synergy_numeric("enemy_master_013")) < 0.001, "协同数值恒 0")

	# ── 4. 逐 master 强度比率回归锁（v18.c flat 版基准，regen: tools/regen_migration_ratio_flat.gd） ──
	var chk: Dictionary = _load_json("res://docs/migration_ratio_check.json")
	var chk_masters: Array = chk.get("masters", [])
	var bounds: Dictionary = chk.get("bounds", {})
	var lo: float = float((bounds.get("per_master", [0.55, 2.6]) as Array)[0])
	var hi: float = float((bounds.get("per_master", [0.55, 2.6]) as Array)[1])
	var med := _era_medians()
	var ratio_bad: int = 0
	var drift_bad: int = 0
	var ratios: Array = []
	for cm in chk_masters:
		var mid: String = String(cm.get("id", ""))
		var lv: int = int(cm.get("level", 5))
		var m_cfg: Dictionary = EnemyPhaseMasters.get_master_by_id(mid)
		var m_era: int = _era_str_to_int(String(m_cfg.get("era", "")))
		if m_era < 0:
			m_era = clampi(floori(float(maxi(lv, 5) - 5) / 5.0), 0, 4)
		var comp: Dictionary = EnemyMasterSkillTree.get_composition(mid, lv)
		var na: float = _comp_scalar(comp, "atk", m_era, lv, med)
		var nh: float = _comp_scalar(comp, "hp", m_era, lv, med)
		var exp: Array = cm.get("new_expected", [1.0, 1.0, 1.0]) as Array
		if absf(na - float(exp[0])) > 0.02 or absf(nh - float(exp[2])) > 0.02:
			drift_bad += 1
			push_error("数据漂移 %s: atk %.3f vs %.3f / hp %.3f vs %.3f" % [mid, na, float(exp[0]), nh, float(exp[2])])
		var seq_f: float = float(cm.get("seq_factor", 1.0))
		var old_a: float = float((cm.get("old", [1, 1, 1]) as Array)[0])
		var old_h: float = float((cm.get("old", [1, 1, 1]) as Array)[2])
		var ratio: float = (na * nh) / (old_a * old_h) / seq_f
		ratios.append(ratio)
		if ratio < lo or ratio > hi:
			ratio_bad += 1
			push_error("比率越界 %s: %.3f（界 [%.2f, %.2f]）" % [mid, ratio, lo, hi])
	check(drift_bad == 0, "30 master 组合数值 vs 分析期望零漂移（drift=%d）" % drift_bad)
	check(ratio_bad == 0, "逐师威胁比全部在界内 [%.2f, %.2f]（bad=%d）" % [lo, hi, ratio_bad])
	var mean_r: float = 0.0
	for r in ratios:
		mean_r += float(r)
	mean_r /= maxf(1.0, float(ratios.size()))
	var mb: Array = bounds.get("mean", [0.95, 1.15]) as Array
	check(mean_r >= float(mb[0]) and mean_r <= float(mb[1]),
		"总体威胁比均值 %.3f 在 [%.2f, %.2f]（v18.c flat 统一基准）" % [mean_r, float(mb[0]), float(mb[1])])

	# ── 5. 访问器兜底 ──
	var act: Array = EnemyPhaseMasters.get_master_active_spells("enemy_master_001")
	var pas: Array = EnemyPhaseMasters.get_master_passive_spells("enemy_master_001")
	var tr: Array = EnemyPhaseMasters.get_master_traits("enemy_master_001")
	check(act.size() == 1 and String(act[0].get("id")) == "iron_bulwark", "actives 访问器兜底")
	check(pas.size() == 1 and String(pas[0].get("kind")) == "death_shield", "passives 访问器兜底")
	check(tr.size() >= 1, "traits 访问器兜底")

	if errors == 0:
		print("=== ALL %d PASS ===" % checks)
		print("总体威胁比均值 %.3f（v18.c flat 统一基准，regen 见 tools/regen_migration_ratio_flat.gd）" % mean_r)
	quit(1 if errors > 0 else 0)
