extends RefCounted
## v32.0 B1-3 每单位战斗记录（本场最佳战报数据管道）
##
## 挂账点：两单位 take_damage 咽喉（输出/承伤）+ battle_manager 击杀 handler（击杀），
## 按"单位显示名"聚合，供结算面板 MVP 摘要消费。
## 口径：金额 = take_damage 入参（减免前进账量）——跨单位口径一致，用于排名/占比足够；
## 与结算聚合数（BattleInfoDisplay，减免后）不必对齐，面板上两者分开展示。
## 生命周期：start_battle 重置；结算面板读取；极速推演照常累积（真实模拟，奖励一致
## 则战报也应一致）。名字聚合天然有界，_MAX_ENTRIES 仅防御极端场景。
## 静态函数命名避开 reset_state（Godot 4.5.1 静态同名静默失效坑）。

static var _dealt: Dictionary = {}   # label -> float
static var _taken: Dictionary = {}   # label -> float
static var _kills: Dictionary = {}   # label -> int
const _MAX_ENTRIES := 64

# 显示名解析链依赖（preload 纪律——错误监视上下文无编辑器扫描）
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyCardModMap = preload("res://data/enemy_card_mod_map.gd")
const DefaultCards = preload("res://data/default_cards.gd")


static func record_damage(attacker: Node, victim: Node, amount: float) -> void:
	if amount <= 0.0:
		return
	# 本场最佳只表彰我方单位（group 判侧，与 battle_manager 胜负检查同口径）——
	# 敌方攻击者/被击方不进榜（2026-09-20 全矩阵报告 P3"输出最佳出现敌方单位"核销）。
	if _is_player_side(attacker):
		var a := _unit_label(attacker)
		if not a.is_empty():
			_bump(_dealt, a, amount)
	if _is_player_side(victim):
		var v := _unit_label(victim)
		if not v.is_empty():
			_bump(_taken, v, amount)


static func record_kill(killer: Node, _victim: Node) -> void:
	if not _is_player_side(killer):
		return
	var k := _unit_label(killer)
	if not k.is_empty():
		_kills[k] = int(_kills.get(k, 0)) + 1


static func _is_player_side(u: Node) -> bool:
	if u == null or not is_instance_valid(u):
		return false
	return u.is_in_group("player_units")


static func reset_battle_record() -> void:
	_dealt.clear()
	_taken.clear()
	_kills.clear()


## 结算面板消费：{top_dealer:{label,value}, top_killer:{...}, top_tank:{...}, total_dealt}
## 无任何记录时返回空字典
static func get_top_entries() -> Dictionary:
	var out: Dictionary = {}
	var td := _top_of(_dealt)
	if not td.is_empty():
		out["top_dealer"] = td
	var tk := _top_of(_kills)
	if not tk.is_empty():
		out["top_killer"] = tk
	var tt := _top_of(_taken)
	if not tt.is_empty():
		out["top_tank"] = tt
	if not _dealt.is_empty():
		out["total_dealt"] = _sum(_dealt)
	return out


static func _top_of(d: Dictionary) -> Dictionary:
	var best_label := ""
	var best_val := 0.0
	for k in d:
		var v := float(d[k])
		if v > best_val:
			best_val = v
			best_label = String(k)
	if best_label.is_empty():
		return {}
	return {"label": best_label, "value": best_val}


static func _sum(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		s += float(d[k])
	return s


static func _bump(d: Dictionary, label: String, amount: float) -> void:
	if d.size() >= _MAX_ENTRIES and not d.has(label):
		return
	d[label] = float(d.get(label, 0.0)) + amount


## 单位显示名鸭子链：card(CardResource).display_name → unit.display_name →
## archetype 解析链（EnemyArchetypes 配置中文名 → foe_ 剥前缀再查 → 映射玩家卡中文名）
## → archetype_id 裸 id 兜底。取不到返回空串（调用方跳过，不做误归属）。
static func _unit_label(u: Node) -> String:
	if u == null or not is_instance_valid(u):
		return ""
	var v: Variant = u.get("card")
	if v is Resource and "display_name" in v:
		var s := String(v.get("display_name"))
		if not s.is_empty():
			return s
	if "display_name" in u:
		var s2 := String(u.get("display_name"))
		if not s2.is_empty():
			return s2
	# construct_unit 无 card/display_name 属性——卡名在 stats.card_id /
	# platform_card_id（UnitStats）。2026-09-21 实测：不过此链我方单位标签恒空，
	# 侧别过滤后 MVP 区块整块消失（旧版空标签被跳过、条目全被敌方占位）。
	var st: Variant = u.get("stats")
	if st is Object:
		if "card_id" in st:
			var from_card := _card_id_display_name(String(st.get("card_id")))
			if not from_card.is_empty():
				return from_card
		if "platform_card_id" in st:
			var from_platform := _card_id_display_name(String(st.get("platform_card_id")))
			if not from_platform.is_empty():
				return from_platform
	if "archetype_id" in u:
		var aid := String(u.get("archetype_id"))
		if not aid.is_empty():
			var resolved := _archetype_display_name(aid)
			if not resolved.is_empty():
				return resolved
			return aid
	return ""


## card_id（含实例 id 带 #N 后缀）→ 卡模板中文名。
static func _card_id_display_name(cid: String) -> String:
	if cid.is_empty():
		return ""
	var base := cid.split("#")[0]
	for id in [cid, base]:
		var c := DefaultCards.get_card_by_id(id)
		if c != null and not c.display_name.is_empty():
			return c.display_name
	return ""


## archetype_id → 中文显示名（2026-09-20 全矩阵报告 P3"本场最佳显示原始 archetype ID"核销）。
static func _archetype_display_name(aid: String) -> String:
	var cfg: Dictionary = EnemyArchetypes.get_config(aid)
	var dn := String(cfg.get("display_name", ""))
	if not dn.is_empty():
		return dn
	var stripped := aid.trim_prefix("foe_")
	if stripped != aid:
		cfg = EnemyArchetypes.get_config(stripped)
		dn = String(cfg.get("display_name", ""))
		if not dn.is_empty():
			return dn
	var mapped := EnemyCardModMap.get_player_card_id(aid)
	if mapped.is_empty() and stripped != aid:
		mapped = EnemyCardModMap.get_player_card_id(stripped)
	if not mapped.is_empty():
		var card := DefaultCards.get_card_by_id(mapped)
		if card != null and not card.display_name.is_empty():
			return card.display_name
	return ""
