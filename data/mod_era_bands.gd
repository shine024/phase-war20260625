extends RefCounted
class_name ModEraBands
## v22 改造时代带（era_band）显示辅助——era 索引 ↔ 中文名 + 带描述格式化。
## 卡池时代：0 一战 / 1 二战 / 2 冷战 / 3 现代 / 4 近未来。
## 改造条目 era_band = [min, max] 缺省视为全时代 [0, 4]。

const ERA_NAMES: Array = ["一战", "二战", "冷战", "现代", "近未来"]

static func era_name(era: int) -> String:
	if era >= 0 and era < ERA_NAMES.size():
		return String(ERA_NAMES[era])
	return "未知时代"

## 改造时代带的显示文案：单一时代 → "冷战"；跨带 → "一战~冷战"；全带 → "全时代"
static func format_band(mod_data: Dictionary) -> String:
	var band = mod_data.get("era_band", null)
	if not (band is Array) or band.size() < 2:
		return "全时代"
	var lo: int = int(band[0])
	var hi: int = int(band[1])
	if lo <= 0 and hi >= 4:
		return "全时代"
	if lo == hi:
		return era_name(lo)
	return "%s~%s" % [era_name(lo), era_name(hi)]
