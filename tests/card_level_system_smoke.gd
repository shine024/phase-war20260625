# v18.c 统一等级系统 smoke test
# 验证：
#   1) 六个改动/新建文件全部可编译加载
#   2) CardGrowthConfig 数学（关卡→等级映射 / 步进档累计 / 词条节点）
#   3) BattleExperienceConfig 30 级阈值曲线（单调 / 端点 / 查询函数）
#   4) AffixManager.on_card_level_up_instance（6 节点词条复活，全落机体槽）
#   5) EnemyStatResolver.resolve_classic_enemy 等级 flat 注入（链尾加法 + breakdown 记录）
#
# 不依赖 GdUnit，直接 extends SceneTree。
# 注：--script 模式下 autoload 不初始化——battle_spawn_system/instance_registry 仅做编译加载验证，
#     其运行时链路（等级查询/缓存 key/flat 注入）由 4)/5) 的等价静态路径覆盖。
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/card_level_system_smoke.gd
extends SceneTree

const CardGrowthConfig = preload("res://data/card_growth_config.gd")
const BattleExperienceConfig = preload("res://data/battle_experience_config.gd")
const EnemyStatResolver = preload("res://data/enemy_stat_resolver.gd")
const EnemyStatContext = preload("res://data/enemy_stat_context.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const AffixManagerScript = preload("res://managers/affix_manager.gd")
const InstanceRegistryScript = preload("res://managers/instance_registry.gd")
const BattleSpawnSystemScript = preload("res://managers/battle/battle_spawn_system.gd")


func _initialize() -> void:
	var code := [0]
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code[0] = 1

	print("═══════════════════════════════════════════════════════════")
	print("  v18.c 统一等级系统（30级/flat/词条节点）验证")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. 编译加载 ══════════
	print("\n[1] 编译加载 6 个改动文件")
	for p in [
		"res://data/card_growth_config.gd",
		"res://data/battle_experience_config.gd",
		"res://managers/instance_registry.gd",
		"res://managers/affix_manager.gd",
		"res://data/enemy_stat_resolver.gd",
		"res://managers/battle/battle_spawn_system.gd",
	]:
		if load(p) == null:
			fail.call("无法加载 %s" % p)
	print("  加载全部 OK")

	# ══════════ 2. CardGrowthConfig 数学 ══════════
	print("\n[2] CardGrowthConfig 派生数学")
	var lv1: int = CardGrowthConfig.enemy_level_for_stage(1)
	var lv50: int = CardGrowthConfig.enemy_level_for_stage(50)
	var lv100: int = CardGrowthConfig.enemy_level_for_stage(100)
	if lv1 != 1: fail.call("关卡1 应映射 Lv1，实得 %d" % lv1)
	if lv50 != 15: fail.call("关卡50 应映射 Lv15，实得 %d" % lv50)
	if lv100 != 30: fail.call("关卡100 应映射 Lv30，实得 %d" % lv100)
	if CardGrowthConfig._weighted_levels(30) != 45.0:
		fail.call("Lv30 加权级数应为 45（10×1+10×1.5+10×2），实得 %f" % CardGrowthConfig._weighted_levels(30))
	if CardGrowthConfig._weighted_levels(10) != 10.0:
		fail.call("Lv10 加权级数应为 10，实得 %f" % CardGrowthConfig._weighted_levels(10))
	# 累计成长单调 + 满级量级（现代 atk 基准 2.5 × rare ×1.0 × 45 = 112.5）
	var g10: Dictionary = CardGrowthConfig.total_growth_raw(3, 0, "rare", 10)
	var g30: Dictionary = CardGrowthConfig.total_growth_raw(3, 0, "rare", 30)
	if float(g30.atk) <= float(g10.atk): fail.call("Lv30 flat 应大于 Lv10 flat")
	if absf(float(g30.atk) - 2.5 * 45.0) > 0.01:
		fail.call("现代 LIGHT rare Lv30 atk flat 应为 112.5，实得 %f" % float(g30.atk))
	# 词条节点：6 个
	var milestones: Array = []
	for lv in range(1, 31):
		if CardGrowthConfig.is_affix_milestone(lv):
			milestones.append(lv)
	if milestones != [5, 10, 15, 20, 25, 30]:
		fail.call("词条节点应为 [5,10,15,20,25,30]，实得 %s" % str(milestones))
	print("  映射/累计/节点 OK（Lv30 加权 45，现代 rare atk flat=%.1f）" % float(g30.atk))

	# ══════════ 3. 经验阈值曲线 ══════════
	print("\n[3] BattleExperienceConfig 30 级阈值曲线")
	var th: Array = BattleExperienceConfig.LEVEL_EXP_THRESHOLDS
	if th.size() != 31: fail.call("阈值表应为 31 项（Lv1-30 + 起点 0），实得 %d" % th.size())
	for i in range(1, th.size()):
		if int(th[i]) <= int(th[i - 1]):
			fail.call("阈值表在索引 %d 处非严格递增（%d → %d）" % [i, int(th[i - 1]), int(th[i])])
			break
	if BattleExperienceConfig.get_card_level_for_exp(0) != 1:
		fail.call("0 经验应为 Lv1")
	if BattleExperienceConfig.get_card_level_for_exp(int(th[30])) != 30:
		fail.call("满额经验 %d 应为 Lv30" % int(th[30]))
	if BattleExperienceConfig.get_card_level_for_exp(999999999) != 30:
		fail.call("超量经验应钳制 Lv30")
	# 中段抽查：恰好达到 Lv10 阈值 → Lv10；阈值-1 → Lv9
	var t10: int = int(th[10])
	if BattleExperienceConfig.get_card_level_for_exp(t10) != 10:
		fail.call("达到 Lv10 阈值应为 Lv10")
	if BattleExperienceConfig.get_card_level_for_exp(t10 - 1) != 9:
		fail.call("Lv10 阈值-1 应为 Lv9")
	print("  曲线 OK（31 项，总经验 %d，端点/中段/钳制全过）" % int(th[30]))

	# ══════════ 4. 词条节点复活（AffixManager） ══════════
	print("\n[4] AffixManager.on_card_level_up_instance 词条节点")
	var am: Node = AffixManagerScript.new()
	var iid: String = "smoke_lv_card#1"
	# 1→4：无节点，零词条
	am.on_card_level_up_instance(iid, 1, 4)
	if am.get_affix_count("%s_0" % iid) != 0 or am.get_affix_count("%s_1" % iid) != 0:
		fail.call("Lv1→4 不应产生词条（无节点）")
	# 1→30：6 节点，全落机体槽（6 < 9 槽位上限）
	am.on_card_level_up_instance(iid, 1, 30)
	var n_body: int = am.get_affix_count("%s_0" % iid)
	var n_weapon: int = am.get_affix_count("%s_1" % iid)
	if n_body != 6:
		fail.call("Lv1→30 应在机体槽产生 6 词条，实得 %d" % n_body)
	if n_weapon != 0:
		fail.call("机体槽未满时不应落武器槽，实得 %d" % n_weapon)
	# 重复调用同等级区间：不重复产生
	am.on_card_level_up_instance(iid, 1, 30)
	if am.get_affix_count("%s_0" % iid) != 6:
		fail.call("重复调用不应叠加词条")
	# 废弃别名不崩
	am.on_card_star_up(iid, 1, 2)
	am.free()
	print("  词条节点 OK（6 节点→机体槽 6 词条，武器槽 0，重复调用不叠加）")

	# ══════════ 5. 敌方 resolver flat 注入 ══════════
	print("\n[5] resolve_classic_enemy 等级 flat 注入（链尾加法）")
	var aid: String = ""
	for id in EnemyArchetypes.ARCHETYPES.keys():
		var cfg: Dictionary = EnemyArchetypes.get_config(String(id))
		if not cfg.is_empty() and int(cfg.get("era", -1)) == 3 and int(cfg.get("combat_kind", -1)) == 0:
			aid = String(id)
			break
	if aid.is_empty():
		for id in EnemyArchetypes.ARCHETYPES.keys():
			var cfg: Dictionary = EnemyArchetypes.get_config(String(id))
			if not cfg.is_empty() and int(cfg.get("era", -1)) == 3:
				aid = String(id)
				break
	if aid.is_empty():
		fail.call("找不到现代 era 的 archetype 用于测试")
	else:
		var ctx1: Object = EnemyStatContext.new(1, 1)
		var ctx100: Object = EnemyStatContext.new(100, 1)
		var r1: Dictionary = EnemyStatResolver.resolve_classic_enemy(aid, ctx1)
		var r100: Dictionary = EnemyStatResolver.resolve_classic_enemy(aid, ctx100)
		var b1: Dictionary = r1.get("bonus_breakdown", {})
		var b100: Dictionary = r100.get("bonus_breakdown", {})
		if int(b1.get("card_level", -1)) != 1:
			fail.call("关卡1 breakdown.card_level 应为 1，实得 %d" % int(b1.get("card_level", -1)))
		if int(b100.get("card_level", -1)) != 30:
			fail.call("关卡100 breakdown.card_level 应为 30，实得 %d" % int(b100.get("card_level", -1)))
		# flat 数值 = total_growth_raw(era, kind, rare, lv)——与注入公式一致
		var kind100: int = int(r100.get("combat_kind", 0))
		var era100: int = int(EnemyArchetypes.get_config(aid).get("era", 0))
		var expect: Dictionary = CardGrowthConfig.total_growth_raw(era100, kind100, "rare", 30)
		if absf(float(b100.get("flat_hp", -1.0)) - float(expect.hp)) > 0.01:
			fail.call("flat_hp 与派生公式不一致：%.2f vs %.2f" % [float(b100.get("flat_hp", -1.0)), float(expect.hp)])
		if float(b100.get("flat_hp", 0.0)) <= 0.0:
			fail.call("flat_hp 应为正")
		# flat 是加法：hp(Lv30) - hp(Lv1) 中含有 flat 差（hp 链同 wave/档位下随关卡几乎不变，
		# 差值应 ≈ flat差——档位可能同（关卡1 现代 era 不存在，取 era3 的关卡 61-80 映射同档差异小），
		# 仅验证 Lv30 hp > Lv1 hp）
		if float(r100.get("hp", 0.0)) <= float(r1.get("hp", 0.0)):
			fail.call("关卡100 敌兵 HP 应大于 关卡1（等级 flat 叠加）")
		print("  注入 OK（archetype=%s，Lv1 flat_hp=%.1f / Lv30 flat_hp=%.1f）" % [aid, float(b1.get("flat_hp", 0.0)), float(b100.get("flat_hp", 0.0))])

	print("\n═══════════════════════════════════════════════════════════")
	if code[0] == 0:
		print("  ✅ 全部通过")
	else:
		print("  ❌ 存在失败项")
	print("═══════════════════════════════════════════════════════════")
	quit(code[0])
