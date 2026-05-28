# 烟测：card_id → archetype_id 反向索引（玩家方战斗单位视觉同形）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/player_archetype_visual_smoke.gd
extends SceneTree

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")


func _initialize() -> void:
	var code := 0

	# 1) bp_ww1_001 必须能反查到 archetype（drops 表里有显式条目）
	var arch_001: String = EnemyArchetypes.get_visual_archetype_id_for_card("bp_ww1_001")
	if arch_001.is_empty():
		push_error("[smoke] bp_ww1_001 -> archetype 反查失败，得到空串")
		code = 1
	else:
		print("[smoke] bp_ww1_001 -> ", arch_001)
		var cfg: Dictionary = EnemyArchetypes.get_config(arch_001)
		if cfg.is_empty():
			push_error("[smoke] archetype id %s 在 EnemyArchetypes 不存在" % arch_001)
			code = 1

	# 2) 默认起手卡 platform_ww1_light 应该查不到 archetype（走 platform_type 镜像兜底）
	var arch_default: String = EnemyArchetypes.get_visual_archetype_id_for_card("platform_ww1_light")
	if not arch_default.is_empty():
		# 数据上若被人为放进 drops 表也算合法，仅打印警告而非失败
		print("[smoke] WARN platform_ww1_light 命中 archetype: ", arch_default)
	else:
		print("[smoke] platform_ww1_light -> 兜底（PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM）")

	# 3) 验证「同卡多 archetype 命中取 chance 最高」逻辑
	var lookup_count: int = 0
	var arch_ids: Array = EnemyArchetypes.get_all_ids()
	var card_chance: Dictionary = {}
	var card_best: Dictionary = {}
	for arch_id in arch_ids:
		var cfg: Dictionary = EnemyArchetypes.get_config(arch_id)
		for d in cfg.get("drops", []):
			if not (d is Dictionary):
				continue
			if not d.has("card_id"):
				continue
			var cid: String = String(d["card_id"])
			if cid.is_empty():
				continue
			var ch: float = float(d.get("chance", 0.0))
			if not card_chance.has(cid) or ch > float(card_chance[cid]):
				card_chance[cid] = ch
				card_best[cid] = arch_id
	for cid in card_chance.keys():
		var resolved: String = EnemyArchetypes.get_visual_archetype_id_for_card(cid)
		if resolved != String(card_best[cid]):
			push_error("[smoke] %s 反查结果 %s 与期望 %s 不一致" % [cid, resolved, card_best[cid]])
			code = 1
		lookup_count += 1
	print("[smoke] 反查表覆盖 ", lookup_count, " 张卡，全部命中 chance 最高 archetype")

	# 4) 同 platform_type 不同 card_id：抽两张同 PlatformType 的 bp 卡，确认 archetype 不同（若 drops 数据允许）
	var titan_cards: Array = []
	for cid in card_chance.keys():
		var card = DefaultCards.get_card_by_id(cid)
		if card != null and card.card_type == GC.CardType.COMBAT_UNIT and int(card.platform_type) == 2:  # TITAN
			titan_cards.append(cid)
	if titan_cards.size() >= 2:
		var a: String = EnemyArchetypes.get_visual_archetype_id_for_card(titan_cards[0])
		var b: String = EnemyArchetypes.get_visual_archetype_id_for_card(titan_cards[1])
		print("[smoke] TITAN 同 platform_type 取样: %s -> %s, %s -> %s" % [titan_cards[0], a, titan_cards[1], b])
		if a == b:
			print("[smoke] WARN 两张 TITAN 卡命中相同 archetype（drops 数据所致，非逻辑问题）: ", a)
	else:
		print("[smoke] 未找到 ≥2 张 TITAN 平台 bp 卡，跳过该子项")

	if code == 0:
		print("[smoke] OK: card_id → archetype 反向索引工作正常")
	quit(code)