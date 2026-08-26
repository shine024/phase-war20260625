extends RefCounted
class_name CardMechanismDesc

## v20.15 高价值单位固定机制文案表（tag → 名称+描述）。
## 消费方：card_info_panel（查看模式/战场模式）、backpack_card_item tooltip、
## bottom_instrument_bar tooltip。数值与 CardAbilityManager 常量同源，
## 调参时同步更新此处文案。

## 机制 tag 的展示顺序（多机制卡按此顺序渲染）
const TAG_ORDER: Array[String] = [
	"radar", "command", "medic", "repair", "supply", "relay",
	"recon", "stealth_aircraft", "attack_drone", "repair_vehicle", "storm_core",
]

## tag → { name: 机制名, desc: 描述（含数值） }
const MECHANISM_DESC := {
	"radar": {
		"name": "雷达警戒",
		"desc": "全体友军暴击率 +15%（随星级提升）；本单位为侦测源，可反制敌方隐身单位",
	},
	"command": {
		"name": "指挥光环",
		"desc": "全体友军攻击 +8%、移速 +8%、暴击 +4%（随星级提升）",
	},
	"medic": {
		"name": "医疗光环",
		"desc": "每 3 秒治疗全体友军 8% 最大生命值（随星级提升）",
	},
	"repair": {
		"name": "维修光环",
		"desc": "每 3 秒修复全体机械类友军 12% 最大生命值（随星级提升）",
	},
	"supply": {
		"name": "弹药补给",
		"desc": "每 3 秒为全体友军补充弹药：攻速 +12%，持续 4 秒（随星级提升）",
	},
	"relay": {
		"name": "相位中继",
		"desc": "每 3 秒为指挥链路回充 3 点能量（随星级提升）",
	},
	"recon": {
		"name": "侦测标记",
		"desc": "每 10 秒标记敌方最高威胁目标 8 秒（远程单位优先集火）；本单位为侦测源，可反制敌方隐身单位",
	},
	"stealth_aircraft": {
		"name": "周期隐身",
		"desc": "每 8 秒进入隐身 4 秒：闪避 +40%、移速 +20%，隐身期间无法被敌方选中（无侦测源时）；现身首击必定暴击且伤害 ×1.5",
	},
	"attack_drone": {
		"name": "自动标记集火",
		"desc": "每 12 秒标记 400 内 2 个最高威胁敌人（易伤 +25%，8 秒）；远距离攻击伤害衰减",
	},
	"repair_vehicle": {
		"name": "修复脉冲",
		"desc": "每 3 秒修复友军受损最重单位 5% 最大生命值（随星级提升）；在场时装甲单位阵亡有 50% 概率返还部署次数",
	},
	"storm_core": {
		"name": "风暴脉冲",
		"desc": "每 6 秒对全体敌人造成 30% 对装甲攻击力的风暴伤害（可命中隐身单位）",
	},
}

## 同族别名 tag → 规范 tag（UCT 名字关键词自动注入"雷达/侦测/指挥"中文 tag，归并到规范行）
const TAG_ALIASES := {
	"雷达": "radar",
	"侦测": "radar",
	"指挥": "command",
	"hq": "command",
}


## 取卡 tags 的固定机制文案行（返回 ["机制名：描述", ...]；无机制返回空数组）
static func get_mechanism_lines(tags: Array) -> Array[String]:
	var lines: Array[String] = []
	if tags.is_empty():
		return lines
	# 归并别名后去重
	var normalized: Array = []
	for t in tags:
		var key: String = TAG_ALIASES.get(String(t), String(t))
		if not normalized.has(key):
			normalized.append(key)
	for tag in TAG_ORDER:
		if normalized.has(tag) and MECHANISM_DESC.has(tag):
			var info: Dictionary = MECHANISM_DESC[tag]
			lines.append("%s：%s" % [String(info.get("name", tag)), String(info.get("desc", ""))])
	return lines


## 按 card_id 取机制文案（查卡 tags；查不到返回空数组）
static func get_mechanism_lines_by_card_id(card_id: String) -> Array[String]:
	if card_id.is_empty():
		return []
	if _card_cache.has(card_id):
		return get_mechanism_lines(_card_cache[card_id])
	var tags: Array = []
	var dc: GDScript = load("res://data/default_cards.gd") as GDScript
	if dc != null:
		var card: CardResource = dc.new().get_card_by_id(card_id) as CardResource
		if card != null:
			tags = card.tags
	_card_cache[card_id] = tags
	return get_mechanism_lines(tags)


static var _card_cache: Dictionary = {}
