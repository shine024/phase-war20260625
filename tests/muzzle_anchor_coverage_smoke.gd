# 无 GdUnit 依赖的快速校验：敌方开火位置锚点覆盖率（muzzle_anchors.gd）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/muzzle_anchor_coverage_smoke.gd
#
# 验证内容：
# 1. 运行时全量覆盖——敌方名册六段（A/B 段带 foe_ 前缀 + C/D/E 段原始 id）构造
#    实际查询键，get_anchor() 必须全部命中（直查 / foe_ 剥离 / 平台映射三级回退）。
# 2. 11 条派生条目（fut_arm_omega + 10 堡垒）与我方标注表满足水平镜像关系
#    enemy fireX = 1 - player fireX，fireY_pct 相等。
# 3. 回退链行为正确性——foe_ 剥离命中、平台映射命中、未知 id 仍返回空字典。
extends SceneTree

const MuzzleAnchors = preload("res://data/muzzle_anchors.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const PlayerMuzzleAnchors = preload("res://data/player_muzzle_anchors.gd")

# 11 条从我方表镜像派生的条目
const MIRRORED_IDS: Array[String] = [
	"fut_arm_omega",
	"ww1_fort_pillbox", "ww1_fort_artillery",
	"ww2_fort_bunker", "ww2_fort_flak",
	"cold_fort_missile", "cold_fort_radar",
	"mod_fort_citadel", "mod_fort_phalanx",
	"fut_fort_ion", "fut_fort_shield",
]


func _initialize() -> void:
	var code := 0

	# ── 1. 运行时全量覆盖（109 个查询键）────────────────────────
	var runtime_keys: Array[String] = []
	for pid in EnemyUnitManifest.FOE_PLATFORM_CARD_IDS:
		runtime_keys.append("foe_" + pid)
	for sid in EnemyUnitManifest.FOE_SPECIAL_CARD_IDS:
		runtime_keys.append("foe_" + sid)
	runtime_keys.append_array(EnemyUnitManifest.FIXED_ENEMY_IDS)
	runtime_keys.append_array(EnemyUnitManifest.POOL_ENEMY_IDS)
	runtime_keys.append_array(EnemyUnitManifest.FORT_ENEMY_IDS)

	var missed: Array[String] = []
	for key in runtime_keys:
		if MuzzleAnchors.get_anchor(key).is_empty():
			missed.append(key)
	if not missed.is_empty():
		push_error("get_anchor 未覆盖 %d 个运行时键: %s" % [missed.size(), ", ".join(missed)])
		code = 1
	else:
		print("coverage: %d/%d runtime keys hit" % [runtime_keys.size(), runtime_keys.size()])

	# ── 2. 派生条目与我方表的镜像关系 ────────────────────────────
	for mid in MIRRORED_IDS:
		var enemy_anchor: Dictionary = MuzzleAnchors.get_anchor(mid)
		if enemy_anchor.is_empty():
			push_error("mirrored id '%s' missing from MUZZLE" % mid)
			code = 1
			continue
		var player_anchor: Dictionary = PlayerMuzzleAnchors.PLAYER_MUZZLE.get(mid, {})
		if player_anchor.is_empty():
			push_error("mirrored id '%s' has no player-side source annotation" % mid)
			code = 1
			continue
		var enemy_x: float = float(enemy_anchor.get("fireX", -1.0))
		var player_x: float = float(player_anchor.get("fireX", -1.0))
		if not is_equal_approx(enemy_x + player_x, 1.0):
			push_error("'%s' mirror broken: enemy fireX %s + player fireX %s != 1.0" % [mid, str(enemy_x), str(player_x)])
			code = 1
		if not is_equal_approx(float(enemy_anchor.get("fireY_pct", -1.0)), float(player_anchor.get("fireY_pct", -1.0))):
			push_error("'%s' fireY_pct mismatch between enemy/player tables" % mid)
			code = 1

	# ── 3. 回退链行为 ────────────────────────────────────────────
	# foe_ 剥离：B 段精英卡本体在表
	if MuzzleAnchors.get_anchor("foe_fut_sup_bulwark") != MuzzleAnchors.MUZZLE.get("fut_sup_bulwark", {}):
		push_error("foe_ prefix strip fallback broken (foe_fut_sup_bulwark)")
		code = 1
	# 平台映射：A 段共用 platform 卡图
	if MuzzleAnchors.get_anchor("foe_ww2_arm_tiger") != MuzzleAnchors.MUZZLE.get("platform_ww2_heavy", {}):
		push_error("platform mapping fallback broken (foe_ww2_arm_tiger -> platform_ww2_heavy)")
		code = 1
	# nexus → omega（映射目标已补数据，直查映射键即命中）
	if MuzzleAnchors.get_anchor("foe_fut_arm_nexus").is_empty():
		push_error("foe_fut_arm_nexus should resolve via fut_arm_omega entry")
		code = 1
	# 直查不受影响 + 未知 id 仍返回空字典
	if MuzzleAnchors.get_anchor("ww1_inf_mp18").is_empty():
		push_error("direct lookup broken (ww1_inf_mp18)")
		code = 1
	if not MuzzleAnchors.get_anchor("nonexistent_unit_xyz").is_empty():
		push_error("unknown id should return empty dict")
		code = 1

	if code == 0:
		print("muzzle_anchor_coverage_smoke: OK")
	quit(code)
