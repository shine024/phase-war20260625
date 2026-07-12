extends RefCounted
class_name FormatUtil
## 共享数字格式化工具
##
## 统一项目中所有大数字的显示格式（K/M 缩写 + 千分位），
## 替代散落在 resource_bar.gd / resource_info_panel.gd / growth_panel.gd 的重复 _format_number。

## 格式化大数字为 K/M 缩写（≥1000 显示 K，≥100万显示 M）
static func format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	else:
		return str(num)

## 格式化数字为千分位（如 1234567 → "1,234,567"），不缩写
static func format_thousands(num: int) -> String:
	var negative: bool = num < 0
	var n: int = abs(num)
	var s: String = str(n)
	var parts: Array[String] = []
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			parts.push_front(",")
		parts.push_front(s.substr(i, 1))
		count += 1
	var out: String = "".join(parts)
	if negative:
		out = "-" + out
	return out

