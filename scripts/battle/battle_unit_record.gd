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


static func record_damage(attacker: Node, victim: Node, amount: float) -> void:
	if amount <= 0.0:
		return
	var a := _unit_label(attacker)
	if not a.is_empty():
		_bump(_dealt, a, amount)
	var v := _unit_label(victim)
	if not v.is_empty():
		_bump(_taken, v, amount)


static func record_kill(killer: Node, _victim: Node) -> void:
	var k := _unit_label(killer)
	if not k.is_empty():
		_kills[k] = int(_kills.get(k, 0)) + 1


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
## archetype_id（敌方原型 id）。取不到返回空串（调用方跳过，不做误归属）。
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
	if "archetype_id" in u:
		return String(u.get("archetype_id"))
	return ""
