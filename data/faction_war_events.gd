extends RefCounted
class_name FactionWarEvents

## 事件模板池
const EVENT_TEMPLATES: Array[Dictionary] = [
	# ─── 领土争夺 ───
	{
		"type": "territory",
		"name": "领土争夺：{faction_a} vs {faction_b}",
		"desc": "{faction_a}与{faction_b}在第{level}关发生激烈冲突。",
		"duration_minutes": 30,
		"weight": 30,
		"conditions": {},
		"rewards": {
			"support_a": {"reputation": 20, "skill_points": 1, "nano": 500},
			"support_b": {"reputation": 20, "skill_points": 1, "nano": 500},
			"neutral": {"nano": 100},
		},
	},
	# ─── 资源争夺 ───
	{
		"type": "resource",
		"name": "资源争夺：{faction_a}的补给线",
		"desc": "{faction_a}的补给线遭到{faction_b}的袭击。支持哪一方？",
		"duration_minutes": 20,
		"weight": 20,
		"conditions": {"min_level": 10},
		"rewards": {
			"support_a": {"reputation": 25, "research_points": 200},
			"support_b": {"reputation": 15, "nanomaterial": 300},
			"neutral": {"research_points": 50},
		},
	},
	# ─── 间谍事件 ───
	{
		"type": "spy",
		"name": "间谍暴露：{faction_a}的秘密行动",
		"desc": "{faction_a}被发现试图在{faction_b}内部安插间谍。",
		"duration_minutes": 15,
		"weight": 10,
		"conditions": {"min_faction_level": 3},
		"rewards": {
			"support_a": {"reputation": 10, "energy_block": 2},
			"support_b": {"reputation": 15, "intel": 2},
			"neutral": {"intel": 1},
		},
	},
	# ─── 联盟邀请 ───
	{
		"type": "alliance",
		"name": "联盟邀请：{faction_a}的邀请",
		"desc": "{faction_a}希望与你建立更紧密的合作关系。",
		"duration_minutes": 60,
		"weight": 15,
		"conditions": {"min_reputation": 3000, "target_faction": "any"},
		"rewards": {
			"support_a": {"reputation": 30, "skill_points": 2, "exclusive_card": "random"},
			"neutral": {"nano": 200},
		},
	},
	# ─── 内部危机 ───
	{
		"type": "crisis",
		"name": "内部危机：{faction_a}的困境",
		"desc": "{faction_a}遭遇内部问题，需要你的帮助。",
		"duration_minutes": 45,
		"weight": 10,
		"conditions": {"min_faction_level": 5},
		"rewards": {
			"support_a": {"reputation": 35, "skill_points": 2, "faction_bonus_duration": 3},
			"neutral": {},
		},
	},
	# ─── 对外扩张 ───
	{
		"type": "expansion",
		"name": "扩张行动：{faction_a}的进攻",
		"desc": "{faction_a}正发起大规模进攻，{faction_b}请求支援。",
		"duration_minutes": 40,
		"weight": 15,
		"conditions": {"min_level": 20},
		"rewards": {
			"support_a": {"reputation": 25, "exclusive_card": "random"},
			"support_b": {"reputation": 25, "nanomaterial": 500},
			"neutral": {"nanomaterial": 100},
		},
	},
]

## 势力临时加成事件
const BONUS_EVENTS: Array[Dictionary] = [
	{"name": "军工增产", "faction_bonus_mult": 1.10, "duration_battles": 3},
	{"name": "全民动员", "faction_bonus_mult": 1.15, "duration_battles": 5},
	{"name": "研究突破", "skill_point_reward": 1, "one_time": true},
	{"name": "资源富余", "energy_cost_reduce": 0.10, "duration_battles": 3},
	{"name": "士气高涨", "deploy_speed_bonus": 1, "duration_battles": 4},
]

## 获取所有事件模板
static func get_event_templates() -> Array:
	return EVENT_TEMPLATES.duplicate(true)

## 获取加成事件列表
static func get_bonus_events() -> Array:
	return BONUS_EVENTS.duplicate(true)
