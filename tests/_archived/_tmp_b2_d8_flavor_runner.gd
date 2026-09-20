extends Node
## 批次② Task 8 runner：flavor 全量注入冒烟（计划书 Step 4②）
## ① create_all 全量构造；② UCT card_id 集 == FLAVOR 键集（运行时对账）；
## ③ 逐卡 flavor_text 非空（UCT 卡走表 / 势力卡自带）；④ 法则卡模板 flavor 已清空；
## ⑤ 全表无甲类禁用词「法则／星级」；⑥ 随机 20 卡抽查打印。

const FLAVOR := preload("res://data/card_flavor_texts.gd")
const DefaultCards := preload("res://data/default_cards.gd")

func _ready() -> void:
	var failures: Array[String] = []

	# ① 全量构造
	var cards: Array = DefaultCards.create_all()
	if cards.is_empty():
		failures.append("create_all() 返回空")
	var uct_ids: Array = []
	for entry in UnifiedCardTable.get_player_card_entries():
		uct_ids.append(String(entry.get("card_id", "")))

	# ② 运行时对账：FLAVOR 键集 == 全 UCT card_id 集（玩家+敌方）
	var all_entries: Array = UnifiedCardTable._TABLE
	var uct_all_ids: Dictionary = {}
	for e in all_entries:
		uct_all_ids[String(e.get("card_id", ""))] = true
	var flavor_ids: Dictionary = {}
	for k in FLAVOR.FLAVOR:
		flavor_ids[k] = true
	for k in uct_all_ids:
		if not flavor_ids.has(k):
			failures.append("FLAVOR 缺 UCT 卡：%s" % k)
	for k in flavor_ids:
		if not uct_all_ids.has(k):
			failures.append("FLAVOR 多出非 UCT 键：%s" % k)

	# ③ 逐卡 flavor 非空
	var n_empty := 0
	for c in cards:
		if c is CardResource:
			if String(c.flavor_text).is_empty():
				n_empty += 1
				if failures.size() < 12:
					failures.append("flavor 为空：%s（%s）" % [c.card_id, c.display_name])
	if n_empty > 0:
		failures.append("flavor 空卡合计 %d 张" % n_empty)

	# ④ 法则卡模板 flavor 已清（甲类 #7）
	for law in PhaseLaws.get_all():
		var law_id: String = String(law.get("id", ""))
		if law_id.is_empty():
			continue
		var law_card: CardResource = DefaultCards.create_law_card_resource(law_id)
		if law_card != null and not String(law_card.flavor_text).is_empty():
			failures.append("法则卡 %s flavor 未清空：%s" % [law_id, law_card.flavor_text])

	# ⑤ 全表禁用词
	for k in FLAVOR.FLAVOR:
		var v: String = String(FLAVOR.FLAVOR[k])
		if "法则" in v or "星级" in v:
			failures.append("FLAVOR[%s] 含甲类禁用词" % k)
	for k in FLAVOR.MANUAL:
		var v2: String = String(FLAVOR.MANUAL[k])
		if "法则" in v2 or "星级" in v2:
			failures.append("MANUAL[%s] 含甲类禁用词" % k)

	# ⑥ 随机 20 卡抽查（确定性种子）
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260909
	var pool: Array = cards.duplicate()
	for i in range(20):
		if pool.is_empty():
			break
		var idx := rng.randi_range(0, pool.size() - 1)
		var c2: CardResource = pool[idx] as CardResource
		pool.remove_at(idx)
		if c2 != null:
			print("  [%d] %s（%s）→ %s" % [i + 1, c2.card_id, c2.display_name, c2.flavor_text])

	print("── create_all %d 卡｜FLAVOR %d 条｜MANUAL %d 条 ──" % [
		cards.size(), FLAVOR.FLAVOR.size(), FLAVOR.MANUAL.size()])
	if failures.is_empty():
		print("B2-D8 flavor boot: PASS")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("  [FAIL] " + f)
		printerr("B2-D8 flavor boot: FAIL（%d 项）" % failures.size())
		get_tree().quit(1)
