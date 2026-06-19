extends RefCounted
class_name LoreTagsSupplement
## 情报标签补充配置
## 为LORE_DATABASE中的情报条目添加tags字段

## 情报标签补充字典
const LORE_TAGS: Dictionary = {
	# 一战情报
	"lore_ww1_trench": ["战术", "一战", "步兵", "防御"],
	"lore_ww1_gas": ["技术", "一战", "化学武器", "危险"],
	"lore_ww1_tank": ["技术", "一战", "装甲", "创新"],

	# 二战情报
	"lore_ww2_blitzkrieg": ["战术", "二战", "装甲", "进攻"],
	"lore_ww2_enigma": ["技术", "二战", "密码", "情报"],
	"lore_ww2_manhattan": ["技术", "二战", "核能", "历史"],

	# 冷战情报
	"lore_cold_berlin": ["历史", "冷战", "政治", "分裂"],
	"lore_cold_cuban": ["历史", "冷战", "核威慑", "危机"],
	"lore_cold_kgb": ["战术", "冷战", "情报", "谍战"],

	# 现代情报
	"lore_modern_drone": ["战术", "现代", "无人机", "技术"],
	"lore_modern_cyber": ["技术", "现代", "网络", "信息战"],

	# 未来情报（如果有）
	"lore_future_ai": ["技术", "未来", "AI", "人工智能"],
	"lore_future_space": ["技术", "未来", "太空", "探索"],
}

## 为情报条目获取标签
static func get_lore_tags(lore_id: String) -> Array[String]:
	if LORE_TAGS.has(lore_id):
		var arr: Array[String] = []
		arr.assign(LORE_TAGS[lore_id].duplicate())
		return arr
	var empty: Array[String] = []
	return empty

## 为情报数据库添加标签（合并方法）
static func apply_tags_to_lore_database(lore_db: Dictionary) -> Dictionary:
	var result = lore_db.duplicate(true)
	for lore_id in result.keys():
		var tags = get_lore_tags(lore_id)
		if not tags.is_empty():
			result[lore_id]["tags"] = tags
		else:
			# 如果没有预定义标签，根据category生成默认标签
			var category = result[lore_id].get("category", "")
			var era = result[lore_id].get("era", 0)
			var auto_tags = [_get_era_name(era), _get_category_name(category)]
			result[lore_id]["tags"] = auto_tags
	return result

## 获取时代名称
static func _get_era_name(era: int) -> String:
	match era:
		0: return "一战"
		1: return "二战"
		2: return "冷战"
		3: return "现代"
		4: return "未来"
		_: return "未知"

## 获取分类名称
static func _get_category_name(category: String) -> String:
	match category:
		"tactics": return "战术"
		"technology": return "技术"
		"history": return "历史"
		"intelligence": return "情报"
		_: return "其他"
