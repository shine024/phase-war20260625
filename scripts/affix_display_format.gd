extends RefCounted
class_name AffixDisplayFormat
## v19: 词条/词缀显示格式化（敌我统一）——card_info_panel 与 headless 测试共用
##
## 独立小工具的约束：不引用任何 autoload（AffixManager 走参数传入），
## 保证 --script 模式（autoload 未注册）下可编译可测试——
## card_info_panel 的依赖链裸引用 ModificationRegistry 等 autoload，headless 无法整链加载。

const GC = preload("res://resources/game_constants.gd")

## 玩家真词条 → [{text,color}]（如 "◆ 精准打击 Lv2 +10%[变]"，色=稀有度色）
## identity 为实例身份（instance_id，空回退 card_id）；am 传 AffixManager（测试可传自建实例）。
## 符号体系沿用 card_affix_tooltip：◇common/◆rare/★epic/✦legendary。
## v6.51 批：标签内联当前数值（主诉"词条加什么应该有更详细的情报"）——
## 数值此前只在悬停 tooltip 里，现在一眼可见。
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
			# P0-4: 悬停效果文本——AffixResource.get_detailed_description 此前在 UI 全程零调用
			var tip: String = String(a.get_detailed_description()) if a.has_method("get_detailed_description") else ""
			var val: String = fmt_affix_value(a)
			tags.append({
				text = "%s %s Lv%d%s%s" % [sym, String(a.affix_name), int(a.level), mut,
					(" " + val) if not val.is_empty() else ""],
				color = GC.get_rarity_color(String(a.rarity)),
				tooltip = tip,
			})
	return tags

## 词条当前数值短串（"+10%" / "-40%" / "攻击间隔 ×0.85"）——标签内联与工坊详情共用。
## a 为 AffixResource（鸭子类型，零依赖约束不破坏）。⚠️ Object.get() 只收 1 参
## （Dictionary.get 才有默认值）——缺属性时 get 返回 null，需自兜底。
static func fmt_affix_value(a) -> String:
	if a == null or not (a is Object):
		return ""
	var obj: Object = a
	var v_var: Variant = obj.get("current_value")
	if v_var == null:
		return ""
	var v: float = float(v_var)
	var ek_var: Variant = obj.get("effect_key")
	var effect_key: String = String(ek_var) if ek_var != null else ""
	if effect_key == "attack_interval":
		return "攻击间隔 ×%.2f" % maxf(0.0, 1.0 - v)
	if absf(v) < 1.0:
		return "%+.0f%%" % (v * 100.0)
	return "%+.1f" % v

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

## 合并各词条 tooltip 为整行悬停文本（单 Label 回退模式用；空返回 ""）
static func tags_tooltip(tags: Array) -> String:
	var parts: Array = []
	for t in tags:
		var tip: String = String(t.get("tooltip", ""))
		if not tip.is_empty():
			parts.append(tip)
	return "\n".join(parts)
