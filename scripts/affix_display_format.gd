extends RefCounted
class_name AffixDisplayFormat
## v19: 词条/词缀显示格式化（敌我统一）——card_info_panel 与 headless 测试共用
##
## 独立小工具的约束：不引用任何 autoload（AffixManager 走参数传入），
## 保证 --script 模式（autoload 未注册）下可编译可测试——
## card_info_panel 的依赖链裸引用 ModificationRegistry 等 autoload，headless 无法整链加载。

const GC = preload("res://resources/game_constants.gd")

## 玩家真词条 → [{text,color}]（如 "◆ 精准打击 Lv2[变]"，色=稀有度色）
## identity 为实例身份（instance_id，空回退 card_id）；am 传 AffixManager（测试可传自建实例）。
## 符号体系沿用 card_affix_tooltip：◇common/◆rare/★epic/✦legendary。
static func fmt_player_affix_tags(identity: String, am: Node) -> Array:
	var tags: Array = []
	if identity.is_empty() or am == null or not am.has_method("get_card_affixes"):
		return tags
	for type in [0, 1]:
		for a in am.get_card_affixes("%s_%d" % [identity, type]):
			if a == null:
				continue
			var sym: String = "◇"
			match String(a.rarity):
				"legendary":
					sym = "✦"
				"epic":
					sym = "★"
				"rare":
					sym = "◆"
			var mut: String = "[变]" if bool(a.is_mutated) else ""
			tags.append({
				text = "%s %s Lv%d%s" % [sym, String(a.affix_name), int(a.level), mut],
				color = GC.get_rarity_color(String(a.rarity)),
			})
	return tags

## 敌方词缀 → [{text,color}]（如 "◆ 幽灵步伐｜闪避率+25%"）
## affixes 为词缀字典列表（{name, description, rarity}，rarity 是 EnemyAffixes.AffixRarity int）。
## 档位色对齐 EnemyAffixes.get_border_color_for_rarity 语义：COMMON 白/RARE 紫/ELITE_ONLY 橙。
static func fmt_enemy_affix_tags(affixes: Array) -> Array:
	var tags: Array = []
	for a in affixes:
		if not (a is Dictionary):
			continue
		var sym: String = "◇"
		var col: Color = Color(0.85, 0.85, 0.92, 1)
		match int(a.get("rarity", 0)):
			1:
				sym = "◆"
				col = Color(0.6, 0.3, 0.85, 1)
			2:
				sym = "★"
				col = Color(1.0, 0.55, 0.0, 1)
		var text: String = "%s %s" % [sym, String(a.get("name", ""))]
		var desc: String = String(a.get("description", ""))
		if not desc.is_empty():
			text += "｜%s" % desc
		tags.append({text = text, color = col})
	return tags

## 标签列表 → 纯文本行（affix_label 回退模式用），header 为段前缀（"词条"/"词缀"）
static func affix_tags_to_text(tags: Array, header: String) -> String:
	if tags.is_empty():
		return ""
	var parts: Array = []
	for t in tags:
		parts.append(String(t.get("text", "")))
	var body: String = " · ".join(parts)
	if header.is_empty():
		return body
	return "%s：%s" % [header, body]

## 词条标签行 + stats 数值摘要行合并（词条行=是谁，摘要行=效果数值）
static func merge_affix_text(tags: Array, summary: String, header: String) -> String:
	var head: String = affix_tags_to_text(tags, header)
	if head.is_empty():
		return summary
	if summary.is_empty():
		return head
	return head + "\n" + summary
