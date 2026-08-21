# v18.c 迁移比率重生成 —— 等级属性 % 曲线 → flat 统一后的回归锁基准
#
# 背景：v18 校准时等级通道是乘区（+10/10/15/20%），threat_ratio ≈1.03。
# v18.c 换 flat 统一（CardGrowthConfig 同表，按产兵时代/兵种派生固定值，加算），
# 等级通道的等效乘区 = 1 + flat / 时代敌方 archetype 中位基数，随等级/时代浮动。
# 本脚本重算 30 master 的 new_expected 与 threat_ratio，并以实际分布重设 bounds。
#
# old / seq_factor / element 沿用既有 JSON（旧侧基准不变：旧 traits 实际生效值 ×
# 序列移除补偿）。smoke（tests/enemy_master_power_migration_smoke.gd）用同一算法
# 复算 live 数据 vs 本 JSON 期望——数据/公式漂移即 drift 失败。
#
# 用法: godot --headless --rendering-driver opengl3 --path . --script tools/regen_migration_ratio_flat.gd
extends SceneTree

const EnemyPhaseMasters := preload("res://data/enemy_phase_masters.gd")
const EnemyMasterSkillTree := preload("res://data/enemy_master_skill_tree.gd")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")
const CardGrowthConfig := preload("res://data/card_growth_config.gd")

const JSON_PATH := "res://docs/migration_ratio_check.json"


func _era_str_to_int(s: String) -> int:
	match s.to_lower():
		"ww1": return 0
		"ww2": return 1
		"cold": return 2
		"modern": return 3
		"future", "near_future": return 4
		_: return -1


func _median(vals: Array) -> float:
	if vals.is_empty():
		return 1.0
	vals.sort()
	return float(vals[vals.size() / 2])


## 各时代敌方 archetype 中位基数（flat 等效乘区的分母）
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


## 与 smoke._comp_scalar 同口径：数值节点乘区 × 元素(仅atk) × 等级 flat 等效乘区
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
	# v18.c: 等级通道 = flat 等效乘区（1 + flat / 时代中位基数，LIGHT 代表兵种）
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
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("打不开 " + JSON_PATH)
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var med := _era_medians()
	print("时代中位基数（flat 等效分母）:")
	for era in range(5):
		print("  era%d: atk=%.0f hp=%.0f def=%.0f" % [era, float(med[era].atk), float(med[era].hp), float(med[era].def)])

	var out_masters: Array = []
	var ratios: Array = []
	for cm in data.get("masters", []) as Array:
		var mid: String = String(cm.get("id", ""))
		var lv: int = int(cm.get("level", 5))
		var m_cfg: Dictionary = EnemyPhaseMasters.get_master_by_id(mid)
		var m_era: int = _era_str_to_int(String(m_cfg.get("era", "")))
		if m_era < 0:
			m_era = clampi(floori(float(maxi(lv, 5) - 5) / 5.0), 0, 4)
		var comp: Dictionary = EnemyMasterSkillTree.get_composition(mid, lv)
		var na: float = _comp_scalar(comp, "atk", m_era, lv, med)
		var nd: float = _comp_scalar(comp, "def", m_era, lv, med)
		var nh: float = _comp_scalar(comp, "hp", m_era, lv, med)
		var seq_f: float = float(cm.get("seq_factor", 1.0))
		var old: Array = cm.get("old", [1.0, 1.0, 1.0]) as Array
		var ratio: float = (na * nh) / (float(old[0]) * float(old[2])) / seq_f
		ratios.append(ratio)
		out_masters.append({
			"id": mid,
			"level": lv,
			"era": m_era,
			"old": old,
			"new_expected": [na, nd, nh],
			"element": float(cm.get("element", 1.0)),
			"seq_factor": seq_f,
			"threat_ratio": ratio,
		})
		print("%-20s Lv%-2d era%d  atk %.3f def %.3f hp %.3f  ratio %.3f" % [mid, lv, m_era, na, nd, nh, ratio])

	ratios.sort()
	var lo: float = float(ratios[0])
	var hi: float = float(ratios[ratios.size() - 1])
	var mean: float = 0.0
	for r in ratios:
		mean += float(r)
	mean /= float(ratios.size())
	var out: Dictionary = {
		"masters": out_masters,
		"overall_min": lo,
		"overall_max": hi,
		"overall_mean": mean,
		"overall_median": float(ratios[ratios.size() / 2]),
		"bounds": {
			"per_master": [floorf(lo * 0.9 * 100.0) / 100.0, ceilf(hi * 1.1 * 100.0) / 100.0],
			"mean": [floorf(mean * 0.97 * 1000.0) / 1000.0, ceilf(mean * 1.03 * 1000.0) / 1000.0],
		},
	}
	var wf := FileAccess.open(JSON_PATH, FileAccess.WRITE)
	wf.store_string(JSON.stringify(out, "\t"))
	wf.close()
	print("\n重生成完成：mean=%.3f 中位=%.3f 界 per_master=[%.2f, %.2f] mean=[%.3f, %.3f]" % [
		mean, float(out.overall_median), lo * 0.9, hi * 1.1, mean * 0.97, mean * 1.03])
	quit(0)
