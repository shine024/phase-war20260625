extends SceneTree
## v26 A4：敌方四档总强度校准审计——实测"标量 × 配装改造"的总强度曲线，
## 对照目标 新兵1.40 / 老兵1.65 / 精英1.95 / 传奇2.25（±15% 容差，超差给调参提示）。
## 口径：resolve_classic_enemy（标量+波次+等级flat）为分母基准的倍率，再乘
## 配装改造对 HP/三维攻击的乘区贡献（apply_with_level 数值对比）。
## Usage: godot --headless --path . --script tools/enemy_tier_strength_audit.gd

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyStatResolver = preload("res://data/enemy_stat_resolver.gd")
const EnemyStatContext = preload("res://data/enemy_stat_context.gd")
const EnemyFixedLoadouts = preload("res://data/enemy_fixed_loadouts.gd")
const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")
const Registry = preload("res://scripts/systems/modification_registry.gd")

const TARGETS := {1: 1.40, 2: 1.65, 3: 1.95, 4: 2.25}
const TOLERANCE := 0.15

func _initialize() -> void:
	print("═══ v26 敌方四档强度审计（档位归因口径：标量×配装 ÷ 无档位基线；目标 1.40/1.65/1.95/2.25 ±15%）═══")
	# 每时代抽 3 张代表卡（跳过堡垒——堡垒 hp 特殊档）
	var reps: Array = []
	for era in range(5):
		var ids: Array = EnemyArchetypes.get_ids_for_era(era)
		var picked: Array = []
		for aid in ids:
			var cfg: Dictionary = EnemyArchetypes.get_config(String(aid))
			if int(cfg.get("combat_kind", 0)) != 4 and not (cfg.get("tags", []) as Array).has("boss"):
				picked.append(String(aid))
			if picked.size() >= 3:
				break
		reps.append(picked)

	var tier_ratio: Dictionary = {}
	var _baseline_index: Dictionary = {}
	var violations: Array = []
	for era in range(5):
		# 时代中位关（era_local 10 → 全局 level = era*20+10）
		var level: int = era * 20 + 10
		for aid in reps[era]:
			var cfg: Dictionary = EnemyArchetypes.get_config(aid)
			var base_hp: float = float(cfg.get("hp", 100.0))
			var base_atk: float = maxf(1.0, maxf(float(cfg.get("attack_light", 0.0)),
				maxf(float(cfg.get("attack_armor", 0.0)), float(cfg.get("attack_air", 0.0)))))
			for tier in range(1, 5):
				var ctx := EnemyStatContext.new(level, 1)
				ctx.level = level
				ctx.tier = tier
				var r: Dictionary = EnemyStatResolver.resolve_classic_enemy(aid, ctx)
				# 基线 = 无档位强度（tier1 输出 ÷ 新兵标量 1.20——剥掉档位标量，
				# 剩 base×波次×等级flat，即 v25 之前就存在的非档位部分）
				if tier == 1:
					var hp0: float = float(r.get("hp", base_hp)) / maxf(0.01, float(base_hp)) / 1.20
					var atk0: float = maxf(1.0, maxf(float(r.get("attack_light", 0.0)),
						maxf(float(r.get("attack_armor", 0.0)), float(r.get("attack_air", 0.0))))) / base_atk / 1.20
					_baseline_index[aid] = sqrt(maxf(0.01, hp0 * atk0))
				var scalar_hp: float = float(r.get("hp", base_hp)) / maxf(1.0, base_hp)
				var scalar_atk: float = maxf(1.0, maxf(float(r.get("attack_light", 0.0)),
					maxf(float(r.get("attack_armor", 0.0)), float(r.get("attack_air", 0.0))))) / base_atk
				# 配装改造贡献（四通道 + era 缩放）
				var mod_ids: Array = EnemyFixedLoadouts.get_mods_for_tier(aid, tier)
				var mod_lv: int = clampi(tier, 1, 3)
				var mods: Array = []
				for mid in mod_ids:
					mods.append({"id": String(mid), "level": mod_lv, "enabled": true})
				var era_i: int = int(cfg.get("era", era))
				var base_dict: Dictionary = {
					"max_hp": float(r.get("hp", base_hp)),
					"attack_light": float(r.get("attack_light", 0.0)),
					"attack_armor": float(r.get("attack_armor", 0.0)),
					"attack_air": float(r.get("attack_air", 0.0)),
				}
				var after: Dictionary = Registry.apply_with_level(base_dict, mods, {"era": era_i})
				var mod_hp_f: float = float(after.get("max_hp", base_dict["max_hp"])) / maxf(1.0, float(base_dict["max_hp"]))
				var mod_atk_f: float = maxf(0.05, maxf(float(after.get("attack_light", 0.0)),
					maxf(float(after.get("attack_armor", 0.0)), float(after.get("attack_air", 0.0))))) \
					/ maxf(1.0, maxf(float(base_dict["attack_light"]), maxf(float(base_dict["attack_armor"]), float(base_dict["attack_air"]))))
				# 总强度 = 标量 × 改造贡献（HP/ATK 几何均值做综合指数）
				var total_hp: float = scalar_hp * mod_hp_f
				var total_atk: float = scalar_atk * mod_atk_f
				# 档位归因总强度 =（标量×改造贡献）相对无档位基线的倍率（目标口径）
				var total_raw: float = sqrt(maxf(0.01, total_hp * total_atk))
				var total: float = total_raw / float(_baseline_index.get(aid, 1.0))
				if not tier_ratio.has(tier):
					tier_ratio[tier] = []
				(tier_ratio[tier] as Array).append(total)
				var dev: float = total / float(TARGETS[tier]) - 1.0
				if absf(dev) > TOLERANCE:
					violations.append("era%d %s tier%d 档位归因强度 %.2f 偏离目标 %.2f（%+.0f%%）" % [
						era, aid, tier, total, float(TARGETS[tier]), dev * 100.0])
	print("\n── 分档汇总（各代表卡几何均值）──")
	for tier in range(1, 5):
		var arr: Array = tier_ratio.get(tier, [])
		var sum: float = 0.0
		for v in arr:
			sum += float(v)
		var avg: float = sum / maxf(1.0, float(arr.size()))
		var dev: float = avg / float(TARGETS[tier]) - 1.0
		print("  tier%d（%s）：均值 %.2f vs 目标 %.2f（%+.0f%%）%s" % [
			tier, EnemyLoadoutTiers.get_tier_name(tier), avg, float(TARGETS[tier]), dev * 100.0,
			"⚠" if absf(dev) > TOLERANCE else "✓"])
	print("\n── 超差明细（%d 项）──" % violations.size())
	for v in violations.slice(0, 12):
		print("  " + v)
	if violations.is_empty():
		print("  （无——全部落在 ±15% 容差内）")
	print("\n调参旋钮：TIER_BONUS 标量（enemy_loadout_tiers.gd）——整体上调/下调单变量即可。")
	quit(0 if violations.is_empty() else 2)
