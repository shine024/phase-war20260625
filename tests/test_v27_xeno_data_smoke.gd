extends SceneTree
## v27 黑门无限模式 — 数据层冒烟测试（星冥 20 单位/manifest F 段/era5 池/缴获卡构建）

func _initialize() -> void:
	var errors: PackedStringArray = []

	# 1) XenoUnits 数据完整性
	const XenoUnits = preload("res://data/xeno_units.gd")
	if XenoUnits.ID_ORDER.size() != 20:
		errors.append("ID_ORDER 数量 %d != 20" % XenoUnits.ID_ORDER.size())
	var roles := {"basic": 0, "elite": 0, "ace": 0, "boss": 0}
	for xid in XenoUnits.ID_ORDER:
		var x: Dictionary = XenoUnits.get_config(String(xid))
		if x.is_empty():
			errors.append("缺配置: %s" % xid)
			continue
		for k in ["hp", "speed", "attack_light", "attack_interval", "weapon_type", "tags", "drop_chance"]:
			if not x.has(k):
				errors.append("%s 缺键 %s" % [xid, k])
		if String(x.get("visual_fallback", "")).is_empty():
			errors.append("%s 缺 visual_fallback" % xid)
		var r: String = String(x.get("role", "basic"))
		if roles.has(r):
			roles[r] += 1
	print("[v27] 角色分布: ", roles)

	# 2) Manifest F 段合并 + era5 池
	const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
	var era5: Array = EnemyArchetypes.get_ids_for_era(5)
	var xeno_in_pool: int = 0
	for aid in era5:
		if String(aid).begins_with("xeno_"):
			xeno_in_pool += 1
	if xeno_in_pool != 20:
		errors.append("era5 池 xeno 数 %d != 20（池大小 %d）" % [xeno_in_pool, era5.size()])
	print("[v27] era5 池: ", era5.size(), "（含 xeno ", xeno_in_pool, "）")

	# 3) 全 archetype 配置可解析（含 drops/机制键）
	const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
	var entries: Array = EnemyUnitManifest.get_entries()
	var xeno_rows: int = 0
	for row in entries:
		if String(row.get("archetype_id", "")).begins_with("xeno_"):
			xeno_rows += 1
			var cfg: Dictionary = EnemyArchetypes.get_config(String(row["archetype_id"]))
			if cfg.is_empty():
				errors.append("archetype 合并失败: %s" % row["archetype_id"])
				continue
			var drops: Array = cfg.get("drops", [])
			if drops.is_empty() or String(drops[0]["card_id"]) != "captured_" + String(row["archetype_id"]):
				errors.append("%s drops 异常: %s" % [row["archetype_id"], drops])
			if not cfg.has("hp") or float(cfg["hp"]) <= 0.0:
				errors.append("%s hp 异常" % row["archetype_id"])
	if xeno_rows != 20:
		errors.append("manifest xeno 行 %d != 20" % xeno_rows)
	print("[v27] manifest 总条目: ", entries.size(), "（xeno ", xeno_rows, "）")

	# 4) 缴获卡可构建（era=5 标签链不越界）——经 DefaultCards 注册缓存读取
	const CapturedUnitCards = preload("res://data/captured_unit_cards.gd")
	const DefaultCards = preload("res://data/default_cards.gd")
	CapturedUnitCards.register_into_default_cards_cache()
	var card = DefaultCards.get_card_by_id("captured_" + String(XenoUnits.ID_ORDER[0]))
	if card == null:
		errors.append("缴获卡构建失败: %s" % XenoUnits.ID_ORDER[0])
	else:
		print("[v27] 缴获卡样例: ", card.display_name, " / era=", card.era, " / ", card.type_line)
		if card.era != 5:
			errors.append("缴获卡 era %d != 5" % card.era)
		if card.base_hp <= 0.0 or card.attack_light + card.attack_armor + card.attack_air <= 0.0:
			errors.append("缴获卡数值异常: hp=%s atk=%s" % [card.base_hp, card.attack_light + card.attack_armor + card.attack_air])
	# 全 20 张逐一验证
	for xid in XenoUnits.ID_ORDER:
		var c2 = DefaultCards.get_card_by_id("captured_" + String(xid))
		if c2 == null:
			errors.append("缴获卡缺失: captured_%s" % xid)

	# 5) 星髓资源定义
	const BasicResources = preload("res://data/basic_resources.gd")
	if not BasicResources.DEFINITIONS.has(BasicResources.ID_STAR_MARROW):
		errors.append("星髓未入 DEFINITIONS")
	else:
		print("[v27] 星髓定义: ", BasicResources.DEFINITIONS[BasicResources.ID_STAR_MARROW]["name"])

	# 6) 裂隙环境表 + override 链
	const BattleEnvEffects = preload("res://data/battle_env_effects.gd")
	BattleEnvEffects.set_rift_override("psi_storm")
	var m: Dictionary = BattleEnvEffects.get_level_env_mults(100)
	if absf(float(m.get("indirect_dmg", 1.0)) - 1.15) > 0.001:
		errors.append("psi_storm override 未生效: %s" % m)
	BattleEnvEffects.set_rift_override("crystal_vein")
	if BattleEnvEffects.rift_flat_bonus("kill_energy_bonus") != 2.0:
		errors.append("crystal_vein 平键读取失败")
	BattleEnvEffects.clear_rift_override()
	if BattleEnvEffects.get_rift_override() != "":
		errors.append("clear 失败")
	print("[v27] 裂隙环境 override 链 OK")

	# 7) 结算数学（星髓里程碑/周封顶由管理器实例测，纯函数先验）
	if EndlessBlackgateManagerScript.marrow_for_waves(30) != 90:
		errors.append("里程碑累计 30 波应 90，得 %d" % EndlessBlackgateManagerScript.marrow_for_waves(30))
	if EndlessBlackgateManagerScript.marrow_for_waves(9) != 0:
		errors.append("9 波应 0 星髓")
	if EndlessBlackgateManagerScript.depth_for_waves(45) != 4:
		errors.append("45 波渗度应 4")
	print("[v27] 里程碑/渗度数学 OK")

	# 8) 配装覆盖（era5 全量 + 表容量 137 + 条目结构合法）
	const EnemyFixedLoadouts = preload("res://data/enemy_fixed_loadouts.gd")
	if EnemyFixedLoadouts.LOADOUTS.size() != 137:
		errors.append("配装表 %d != 137" % EnemyFixedLoadouts.LOADOUTS.size())
	for xid in XenoUnits.ID_ORDER:
		var lo: Dictionary = EnemyFixedLoadouts.get_loadout(String(xid))
		if lo.is_empty():
			errors.append("星冥缺配装: %s" % xid)
			continue
		var lo_mods: Array = lo.get("mods", [])
		if lo_mods.size() < 9:
			errors.append("%s 配装 %d 条 < 9" % [xid, lo_mods.size()])
	print("[v27] 配装表 ", EnemyFixedLoadouts.LOADOUTS.size(), " 条（星冥全量覆盖）")

	# 9) 视觉占位资源存在性（vis_player_* 敌方原图 + 卡面直引两条解析路径）
	const EnemyUnitManifestIcons = preload("res://data/enemy_unit_manifest.gd")
	var miss_vis: Array = []
	for xid in XenoUnits.ID_ORDER:
		var p_player: String = EnemyUnitManifestIcons.get_unit_icon_path_for_archetype(String(xid), true)
		var p_enemy: String = EnemyUnitManifestIcons.get_unit_icon_path_for_archetype(String(xid), false)
		if p_player.is_empty() and p_enemy.is_empty():
			miss_vis.append(String(xid))
	if not miss_vis.is_empty():
		errors.append("视觉占位双路径全 miss: %s" % str(miss_vis))
	print("[v27] 视觉占位解析 OK（miss=", miss_vis.size(), "）")

	if errors.is_empty():
		print("[v27] DATA-SMOKE PASS")
	else:
		for e in errors:
			printerr("[v27] FAIL: ", e)
		quit(1)
		return
	quit(0)

const EndlessBlackgateManagerScript = preload("res://managers/endless_blackgate_manager.gd")
