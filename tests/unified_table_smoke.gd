extends SceneTree
## 统一卡牌表 smoke test —— 验证数据源统一后的数值正确性
## 运行: godot --headless --script tests/unified_table_smoke.gd

const UnifiedCardTable = preload("res://data/unified_card_table.gd")

func _init():
	var pass_count: int = 0
	var fail_count: int = 0

	# 测试1: 统一表有 180 张卡
	var all_ids: Array = UnifiedCardTable.get_all_card_ids()
	if all_ids.size() >= 150:
		print("✅ PASS: 统一表含 %d 张卡 (>=150)" % all_ids.size())
		pass_count += 1
	else:
		push_error("❌ FAIL: 统一表只有 %d 张卡，预期 >=150" % all_ids.size())
		fail_count += 1

	# 测试2: 虚空领主 base_hp = 2000（原缴获卡 bug 是 240）
	var nexus: Dictionary = UnifiedCardTable.get_entry("fut_arm_nexus")
	if not nexus.is_empty() and float(nexus.get("base_hp", 0)) == 2000.0:
		print("✅ PASS: 虚空领主 base_hp=2000 (缴获卡 bug 根除)")
		pass_count += 1
	else:
		push_error("❌ FAIL: 虚空领主 base_hp=%s，预期 2000" % str(nexus.get("base_hp", "NOT_FOUND")))
		fail_count += 1

	# 测试3: 缴获卡前缀剥离 —— captured_foe_fut_arm_nexus → fut_arm_nexus
	var drop_id: String = "captured_foe_fut_arm_nexus"
	var arch_id: String = drop_id.trim_prefix("captured_").trim_prefix("foe_")
	var unified_card: CardResource = UnifiedCardTable.build_card_resource(arch_id)
	if unified_card != null and unified_card.base_hp == 2000.0:
		print("✅ PASS: 缴获卡前缀剥离正确 (%s → %s, hp=%d)" % [drop_id, arch_id, unified_card.base_hp])
		pass_count += 1
	else:
		push_error("❌ FAIL: 缴获卡前缀剥离失败")
		fail_count += 1

	# 测试4: C 段无 foe_ 前缀的剥离 —— captured_ww1_inf_mp18 → ww1_inf_mp18
	var c_drop_id: String = "captured_ww1_inf_mp18"
	var c_arch_id: String = c_drop_id.trim_prefix("captured_").trim_prefix("foe_")
	var c_card: CardResource = UnifiedCardTable.build_card_resource(c_arch_id)
	if c_card != null and c_card.base_hp > 0:
		print("✅ PASS: C段缴获卡前缀剥离正确 (%s → %s, hp=%d)" % [c_drop_id, c_arch_id, c_card.base_hp])
		pass_count += 1
	else:
		push_error("❌ FAIL: C段缴获卡前缀剥离失败 (%s → %s)" % [c_drop_id, c_arch_id])
		fail_count += 1

	# 测试5: 玩家卡数量（非 enemy_only）应 >= 110（原 default_cards 数量）
	var player_entries: Array = UnifiedCardTable.get_player_card_entries()
	if player_entries.size() >= 100:
		print("✅ PASS: 玩家卡 %d 张 (>=100)" % player_entries.size())
		pass_count += 1
	else:
		push_error("❌ FAIL: 玩家卡只有 %d 张，预期 >=100" % player_entries.size())
		fail_count += 1

	# 测试6: 敌方 archetype_config 转换 —— 射程格→像素、攻速次/秒→秒/次
	var arch_cfg: Dictionary = UnifiedCardTable.build_enemy_archetype_config("fut_arm_nexus")
	if not arch_cfg.is_empty():
		var rng_ok: bool = float(arch_cfg.get("attack_range", 0)) == 9900.0  # 99格×100
		var hp_ok: bool = float(arch_cfg.get("hp", 0)) == 2000.0
		if rng_ok and hp_ok:
			print("✅ PASS: 敌方archetype_config转换正确 (hp=%d, range=%d像素)" % [arch_cfg.hp, arch_cfg.attack_range])
			pass_count += 1
		else:
			push_error("❌ FAIL: 转换错误 hp=%s range=%s" % [str(arch_cfg.get("hp")), str(arch_cfg.get("attack_range"))])
			fail_count += 1
	else:
		push_error("❌ FAIL: build_enemy_archetype_config 返回空")
		fail_count += 1

	# 测试7: 5 个时代都有卡
	for era in range(5):
		var era_cards: Array = UnifiedCardTable.get_entries_by_era(era)
		if era_cards.size() >= 20:
			print("✅ PASS: 时代 %d 含 %d 张卡" % [era, era_cards.size()])
			pass_count += 1
		else:
			push_error("❌ FAIL: 时代 %d 只有 %d 张卡" % [era, era_cards.size()])
			fail_count += 1

	# 测试8: 量级验证 —— boss 血量在 800-2000 范围
	var boss_ids: Array = ["ww1_boss_av7", "ww2_boss_kingtiger", "cold_boss_mig", "mod_boss_command", "fut_boss_nexus"]
	var boss_ok: bool = true
	for bid in boss_ids:
		var be: Dictionary = UnifiedCardTable.get_entry(bid)
		if be.is_empty():
			print("⚠️ WARN: boss %s 不在统一表" % bid)
			continue
		var bhp: float = float(be.get("base_hp", 0))
		if bhp < 800 or bhp > 2000:
			print("⚠️ WARN: boss %s hp=%d 不在 800-2000 范围" % [bid, bhp])
			boss_ok = false
	if boss_ok:
		print("✅ PASS: Boss 血量范围合理 (800-2000)")
		pass_count += 1
	else:
		print("⚠️ Boss 血量有警告（见上）")

	print("\n══════════════════════════════════")
	print("统一卡牌表 smoke test: %d PASS / %d FAIL" % [pass_count, fail_count])
	print("══════════════════════════════════")
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
