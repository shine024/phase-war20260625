extends SceneTree
## 关卡敌兵 + 敌方相位师"好玩度"审计（headless --script 运行）
## 输出：主题分布 / 敌池 tag 覆盖 / bias 实际命中率 / 驻守相位师概览
## 用法：godot --headless --path . --script tools/audit_level_enemy_fun.gd

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const LevelEras = preload("res://data/level_eras.gd")
const TacticalThemes = preload("res://data/level_tactical_themes.gd")
const LevelSpawnSequences = preload("res://data/level_spawn_sequences.gd")
const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")
const PhaseMasterGarrison = preload("res://data/phase_master_garrison.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")
const Patterns = preload("res://data/enemy_phase_master_patterns.gd")

func _init() -> void:
	var out: Array[String] = []

	# ═══ 1. 每时代敌池：tier 分池 + tag 覆盖 ═══
	out.append("═══ 1. 每时代敌池（tier 分池 + tag 覆盖）═══")
	for era in range(5):
		var ids: Array = EnemyArchetypes.get_ids_for_era(era)
		var basic: Array = []
		var elite: Array = []
		var boss: Array = []
		var tag_count: Dictionary = {}
		for aid in ids:
			var cfg: Dictionary = EnemyArchetypes.get_config(String(aid))
			var tags: Array = cfg.get("tags", [])
			if tags.has("boss"):
				boss.append(aid)
			elif tags.has("elite"):
				elite.append(aid)
			else:
				basic.append(aid)
			for t in tags:
				tag_count[t] = int(tag_count.get(t, 0)) + 1
		out.append("── era %d (%s)：总 %d｜basic %d｜elite %d｜boss %d" % [
			era, LevelEras.get_era_name(era), ids.size(), basic.size(), elite.size(), boss.size()])
		var tsum: String = ""
		var tk: Array = tag_count.keys()
		tk.sort()
		for k in tk:
			tsum += "%s×%d " % [k, tag_count[k]]
		out.append("   tags: " + tsum)

	# ═══ 2. 主题 bias tag 在各时代池的命中率 ═══
	out.append("")
	out.append("═══ 2. 主题 bias tag 匹配数（0 = 主题在该时代失效退化为随机）═══")
	var bias_tags_all: Array = ["infantry", "vehicle", "armored", "tank", "aircraft",
		"artillery", "turret", "sustained", "support", "fast", "stealth"]
	var header: String = "tag         "
	for e in range(5):
		header += "│ era%d" % e
	out.append(header)
	for bt in bias_tags_all:
		var row: String = "%-11s" % bt
		for era in range(5):
			var n: int = 0
			for aid in EnemyArchetypes.get_ids_for_era(era):
				if EnemyArchetypes.get_config(String(aid)).get("tags", []).has(bt):
					n += 1
			row += "│  %2d " % n
		out.append(row)

	# ═══ 3. 100 关主题分布 ═══
	out.append("")
	out.append("═══ 3. 100 关主题分布（数量 + 关卡号）═══")
	var theme_levels: Dictionary = {}
	for lv in range(1, 101):
		var tid: String = TacticalThemes.get_theme_id_for_level(lv)
		if not theme_levels.has(tid):
			theme_levels[tid] = []
		theme_levels[tid].append(lv)
	var tks: Array = theme_levels.keys()
	tks.sort()
	for tid in tks:
		var lvls: Array = theme_levels[tid]
		var s: String = ""
		for l in lvls:
			s += str(l) + " "
		out.append("%-18s ×%2d: %s" % [tid, lvls.size(), s])

	# ═══ 4. 逐关：主题 + 波次 + 档位 + bias 有效波占比 ═══
	out.append("")
	out.append("═══ 4. 逐关概览（bias 失配波占比 >50% 标 ⚠）═══")
	var mismatch_total: int = 0
	for lv in range(1, 101):
		var era: int = LevelEras.get_era(lv)
		var in_era: int = ((lv - 1) % 20) + 1
		var tid: String = TacticalThemes.get_theme_id_for_level(lv)
		var waves: int = LevelEras.get_wave_total_for_level(lv)
		var era_ids: Array = EnemyArchetypes.get_ids_for_era(era)
		var tier: int = EnemyLoadoutTiers.get_tier_for_level_progress((in_era - 1) / 19.0)
		# 本关所有波的 bias tags，统计匹配不到任何 archetype 的波数
		var dead_waves: int = 0
		var seq: Array = LevelSpawnSequences.get_sequence_for_level(lv)
		for spec in seq:
			var bt: Array = spec.get("archetype_bias_tags", [])
			if bt.is_empty():
				continue
			var matched: bool = false
			for aid in era_ids:
				var tags: Array = EnemyArchetypes.get_config(String(aid)).get("tags", [])
				for t in bt:
					if tags.has(t):
						matched = true
						break
				if matched:
					break
			if not matched:
				dead_waves += 1
		mismatch_total += dead_waves
		var flag: String = "  ⚠" if dead_waves * 2 > seq.size() else ""
		out.append("Lv%-3d era%d in%-2d %-18s 波%d tier%d 死bias波%d/%d%s" % [
			lv, era, in_era, tid, waves, tier, dead_waves, seq.size(), flag])
	out.append(">>> 全 100 关死 bias 波合计: %d" % mismatch_total)

	# ═══ 5. 驻守相位师概览 ═══
	out.append("")
	out.append("═══ 5. 驻守相位师（20 关）═══")
	for lv in PhaseMasterGarrison.get_all_garrison_levels():
		var mid: String = PhaseMasterGarrison.get_garrison_master_id(lv)
		var m: Dictionary = EnemyPhaseMasters.get_master_by_id(mid)
		if m.is_empty():
			out.append("Lv%-3d %s → ⚠ master 不存在！" % [lv, mid])
			continue
		var stats: Dictionary = m.get("stats", {})
		var eq: Dictionary = EnemyPhaseMasters.get_enriched_equipment(mid)
		var platforms: Array = eq.get("platforms", [])
		var pat: String = String(Patterns.get_pattern(m))
		out.append("Lv%-3d %s %s｜Lv%s｜hp%s｜platforms %d｜pattern %s" % [
			lv, mid, String(m.get("name", "?")), str(m.get("level", "?")),
			str(stats.get("max_hp", "?")), platforms.size(), pat])

	# ═══ 6. 非驻守关 15% 随机遇敌的池子（按关卡段位会遭遇谁）═══
	out.append("")
	out.append("═══ 6. 30 位相位师 level 分布 ═══")
	var lv_hist: Dictionary = {}
	for m in EnemyPhaseMasters.ENEMY_MASTERS:
		var ml: int = int(m.get("level", 0))
		if not lv_hist.has(ml):
			lv_hist[ml] = []
		lv_hist[ml].append(String(m.get("id", "?")))
	var lk: Array = lv_hist.keys()
	lk.sort()
	for k in lk:
		out.append("masterLv%-3d ×%d: %s" % [k, lv_hist[k].size(), " ".join(PackedStringArray(lv_hist[k]))])

	# ═══ 7. 各时代空中单位（combat_kind==3，v23.3 兵种直通修复的复验段）═══
	out.append("")
	out.append("═══ 7. 各时代空中单位（combat_kind==3 + tier tag）═══")
	for era in range(5):
		var air_line: String = ""
		for aid in EnemyArchetypes.get_ids_for_era(era):
			var cfg: Dictionary = EnemyArchetypes.get_config(String(aid))
			if int(cfg.get("combat_kind", -1)) == 3:
				var t: Array = cfg.get("tags", [])
				var tier_s: String = "boss" if t.has("boss") else ("elite" if t.has("elite") else "basic")
				air_line += "%s(%s) " % [String(aid).replace("foe_", ""), tier_s]
		out.append("── era %d: %s" % [era, air_line if not air_line.is_empty() else "(无)"])

	var f := FileAccess.open("user://audit_level_enemy_fun.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(out))
		f.close()
		print("REPORT → ", ProjectSettings.globalize_path("user://audit_level_enemy_fun.txt"))
	print("\n".join(out))
	quit(0)
