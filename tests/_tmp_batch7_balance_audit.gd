extends SceneTree
## tests/_tmp_batch7_balance_audit.gd — 批次7（P1-3 平衡终审）数值审计
## ① 时代 DPS/HP 中位数与相邻比（复刻 test_unit_era_balance A/B 口径）
## ② era2→3 DPS 比超标归因：冷战/现代卡池 DPS 分布
## ③ siege/scout HP 比诊断（test_siege_enhance_growth_bias 1.0 vs 期望 >1.5）
## ④ 进化 HP 下限 ww1→ww2 诊断
## ⑤ 经济面：1-100 关累计产出 vs 势力商店价格面（科研点退役后）
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_batch7_balance_audit.gd

const UCT = preload("res://data/unified_card_table.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const LevelEras = preload("res://data/level_eras.gd")
const CompanyStore = preload("res://data/company_store.gd")
const BC = preload("res://data/battle_card_v3.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const BM_SCRIPT = preload("res://managers/blueprint_manager.gd")


func _main_dps(e: Dictionary) -> float:
	var best := 0.0
	for pair in [["atk_l", "atk_l_speed"], ["atk_a", "atk_a_speed"], ["atk_air", "atk_air_speed"]]:
		best = maxf(best, float(e.get(pair[0], 0.0)) * float(e.get(pair[1], 0.0)))
	return best


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	if n % 2 == 1:
		return float(sorted[n / 2])
	return (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) / 2.0


func _era_entries(era: int) -> Array:
	var out: Array = []
	for e in UCT.get_player_card_entries():
		if int(e.get("era", -1)) == era:
			out.append(e)
	return out


func _initialize() -> void:
	print("═══ ① 时代 DPS/HP 中位数与相邻比 ═══")
	var dps_medians: Array = []
	var hp_medians: Array = []
	for era in range(5):
		var dpss: Array = []
		var hps: Array = []
		for e in _era_entries(era):
			dpss.append(_main_dps(e))
			hps.append(float(e.get("base_hp", 0.0)))
		dps_medians.append(_median(dpss))
		hp_medians.append(_median(hps))
		print("era %d (%s): 卡数 %d | DPS中位 %.1f | HP中位 %.1f" % [
			era, LevelEras.get_era_name(era), _era_entries(era).size(),
			dps_medians[era], hp_medians[era]])
	for era in range(4):
		var d_ratio: float = dps_medians[era + 1] / dps_medians[era]
		var h_ratio: float = hp_medians[era + 1] / hp_medians[era]
		print("  era %d→%d: DPS比 %.3f | HP比 %.3f" % [era, era + 1, d_ratio, h_ratio])

	print("")
	print("═══ ② era2/era3 玩家卡 DPS 分布（归因 1.64 超标）═══")
	for era in [2, 3]:
		var rows: Array = []
		for e in _era_entries(era):
			rows.append([_main_dps(e), String(e.get("card_id", "?")), float(e.get("base_hp", 0.0))])
		rows.sort_custom(func(a, b): return a[0] < b[0])
		print("era %d DPS 升序（id, DPS, HP）：" % era)
		for r in rows:
			print("   %-28s DPS %7.1f  HP %6.0f" % [r[1], r[0], r[2]])

	print("")
	print("═══ ③ siege/scout HP 比诊断 ═══")
	DefaultCards._ensure_card_cache()
	var bm: Node = Node.new()
	bm.set_script(BM_SCRIPT)
	root.add_child(bm)
	var siege: CardResource = DefaultCards.get_card_by_id("platform_ww2_siege")
	var scout: CardResource = DefaultCards.get_card_by_id("platform_ww2_light")
	print("siege card null=%s | scout card null=%s" % [siege == null, scout == null])
	if siege != null and scout != null:
		siege.enhance_level = 9
		scout.enhance_level = 9
		var st_siege: UnitStats = UnitStatsTable.build_multi_stats(siege.platform_type, [siege.default_weapon_type], 0)
		var st_scout: UnitStats = UnitStatsTable.build_multi_stats(scout.platform_type, [scout.default_weapon_type], 0)
		print("成长前：siege HP %.1f / scout HP %.1f（比 %.2f）" % [
			st_siege.max_hp, st_scout.max_hp, st_siege.max_hp / maxf(st_scout.max_hp, 1.0)])
		bm.apply_growth_to_stats(st_siege, siege, [], false)
		bm.apply_growth_to_stats(st_scout, scout, [], false)
		print("成长后：siege HP %.1f / scout HP %.1f（比 %.2f）" % [
			st_siege.max_hp, st_scout.max_hp, st_siege.max_hp / maxf(st_scout.max_hp, 1.0)])
		print("siege platform_type=%d weapon=%d | scout platform_type=%d weapon=%d" % [
			siege.platform_type, siege.default_weapon_type, scout.platform_type, scout.default_weapon_type])
		# 实战路径核对：build_stats_from_card 读卡真身
		var live_siege: UnitStats = UnitStatsTable.build_stats_from_card(siege, 0)
		var live_scout: UnitStats = UnitStatsTable.build_stats_from_card(scout, 0)
		print("[实战路径 成长前] siege HP %.1f / scout HP %.1f（比 %.2f）" % [
			live_siege.max_hp, live_scout.max_hp, live_siege.max_hp / maxf(live_scout.max_hp, 1.0)])
		bm.apply_growth_to_stats(live_siege, siege, [], false)
		bm.apply_growth_to_stats(live_scout, scout, [], false)
		print("[实战路径 成长后] siege HP %.1f / scout HP %.1f（比 %.2f）" % [
			live_siege.max_hp, live_scout.max_hp, live_siege.max_hp / maxf(live_scout.max_hp, 1.0)])

	print("")
	print("═══ ④ 进化 HP 下限 ww1→ww2 诊断 ═══")
	var src_id: String = "platform_ww1_light"
	var dst_id: String = "platform_ww2_light"
	var old_hp: float = bm._compute_platform_preview_hp(src_id, 0)
	var dst_card: CardResource = DefaultCards.get_card_by_id(dst_id)
	var stats: UnitStats = UnitStatsTable.build_multi_stats(dst_card.platform_type, [dst_card.default_weapon_type], 0)
	bm.blueprint_evolution_hp_floor[dst_id] = old_hp * 1.10
	bm.apply_growth_to_stats(stats, dst_card, [], false)
	print("[测试旧路径 build_multi_stats] ww1_light 有效HP %.2f | 期望下限(×1.10) %.2f | ww2_light 成长后实际 %.2f | 差 %.2f" % [
		old_hp, old_hp * 1.10, stats.max_hp, stats.max_hp - old_hp * 1.10])
	# 实战路径核对：build_stats_from_card（读卡真身）+ 下限钳制是否生效
	var live_stats: UnitStats = UnitStatsTable.build_stats_from_card(dst_card, 0)
	print("[实战路径 build_stats_from_card] ww2_light 基础 HP %.2f" % live_stats.max_hp)
	bm.apply_growth_to_stats(live_stats, dst_card, [], false)
	print("[实战路径 成长后] ww2_light HP %.2f（下限 %.2f，%s）" % [
		live_stats.max_hp, old_hp * 1.10,
		"钳制生效" if live_stats.max_hp >= old_hp * 1.10 - 0.01 else "未钳到下限"])

	print("")
	print("═══ ⑤ 经济面：产出 vs 商店价格 ═══")
	var cum_nano := 0.0
	var cum_alloy := 0.0
	var era_nano: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
	for lv in range(1, 101):
		var d: Dictionary = BasicResources.get_drops_for_level(lv)
		var nano: float = float(d.get(BasicResources.ID_NANO_MATERIALS, 0))
		cum_nano += nano
		cum_alloy += float(d.get(BasicResources.ID_ALLOY, 0))
		era_nano[LevelEras.get_era(lv)] += nano
	print("100 关累计：纳米 %.0f | 合金 %.0f" % [cum_nano, cum_alloy])
	for era in range(5):
		print("  era %d (%s) 纳米累计 %.0f" % [era, LevelEras.get_era_name(era), era_nano[era]])
	var prices: Array = []
	for it in CompanyStore.ITEMS:
		var p: float = float(it.get("price_nano_materials", 0))
		if p > 0.0:
			prices.append(p)
	prices.sort()
	var sum_prices: float = 0.0
	for p in prices:
		sum_prices += p
	print("商店 %d 条在售（含纳米价 %d 条）：min %.0f / 中位 %.0f / max %.0f / 总和 %.0f" % [
		CompanyStore.ITEMS.size(), prices.size(),
		prices.front() if prices.size() > 0 else 0.0,
		_median(prices), prices.back() if prices.size() > 0 else 0.0, sum_prices])
	print("买断全部 = 100 关产出的 %.1f%%" % (100.0 * sum_prices / maxf(cum_nano, 1.0)))

	print("")
	print("═══ ⑥ 非 UCT 战斗卡（platform_* 等）vs 同代 UCT 中位 ═══")
	# UCT 卡 id 集
	var uct_ids: Dictionary = {}
	for e in UCT.get_all_entries():
		uct_ids[String(e.get("card_id", ""))] = true
	# DefaultCards 全部战斗卡中不在 UCT 的（= 漏标定旧卡）
	var outliers: Array = []
	var non_uct_count := 0
	for c0 in DefaultCards._all_cards_cache:
		var c: CardResource = c0 as CardResource
		if c == null or uct_ids.has(c.card_id) or c.card_type != 0:  # GC.CardType.COMBAT_UNIT
			continue
		non_uct_count += 1
		var dps: float = maxf(c.attack_light * c.attack_light_speed,
			maxf(c.attack_armor * c.attack_armor_speed, c.attack_air * c.attack_air_speed))
		var hp_med: float = hp_medians[clampi(c.era, 0, 4)]
		var dps_med: float = dps_medians[clampi(c.era, 0, 4)]
		var hp_dev: float = c.base_hp / maxf(hp_med, 1.0)
		var dps_dev: float = dps / maxf(dps_med, 1.0)
		var flag: String = ""
		if hp_dev < 0.5 or hp_dev > 2.0:
			flag = " ←HP离群"
		if dps_dev < 0.5 or dps_dev > 2.0:
			flag += " ←DPS离群"
		print("  %-26s era%d %-8s HP %6.0f(×%.2f) DPS %7.1f(×%.2f)%s" % [
			c.card_id, c.era, LevelEras.get_era_name(c.era), c.base_hp, hp_dev, dps, dps_dev, flag])
		if flag != "":
			outliers.append(c.card_id)
	print("非 UCT 战斗卡共 %d 张，其中 HP/DPS 离群 %d 张：%s" % [
		non_uct_count, outliers.size(), ", ".join(outliers)])

	print("")
	print("═══ ⑦ era×kind 标定带（fe_* 重标定锚点：p50/p75/max）═══")
	for era in range(5):
		for kind in range(5):
			var hps2: Array = []
			var dpss2: Array = []
			for e in UCT.get_player_card_entries():
				if int(e.get("era", -1)) == era and int(e.get("combat_kind", -1)) == kind:
					hps2.append(float(e.get("base_hp", 0.0)))
					dpss2.append(_main_dps(e))
			if hps2.size() < 2:
				continue
			hps2.sort()
			dpss2.sort()
			var n2: int = hps2.size()
			print("  era%d kind%d（n=%d）HP p50 %.0f / p75 %.0f / max %.0f ‖ DPS p50 %.0f / p75 %.0f / max %.0f" % [
				era, kind, n2, hps2[n2 / 2], hps2[int(n2 * 0.75)], hps2.back(),
				dpss2[n2 / 2], dpss2[int(n2 * 0.75)], dpss2.back()])

	print("")
	print("═══ 附：时代倍率定稿记录 ═══")
	print("伤害倍率表：", [BC.era_damage_multiplier(0), BC.era_damage_multiplier(1), BC.era_damage_multiplier(2), BC.era_damage_multiplier(3), BC.era_damage_multiplier(4)])
	print("HP 倍率表：", [BC.era_hp_multiplier(0), BC.era_hp_multiplier(1), BC.era_hp_multiplier(2), BC.era_hp_multiplier(3), BC.era_hp_multiplier(4)])

	if bm != null and is_instance_valid(bm):
		bm.queue_free()
	quit()
