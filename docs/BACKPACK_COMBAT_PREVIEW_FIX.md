# backpack_combat_preview.gd 语法错误修复

## 问题
文件中存在不可达代码导致语法错误：
- 第 71 行有 `return` 语句
- 第 72-88 行有代码在 return 之后（不可达）
- Godot 解析器报错

## 修复
移除了第 72-88 行的不可达代码。这些代码原本是用于处理武器卡的，但因为在 return 语句之后，永远无法执行。

修复后的代码结构：
```gdscript
static func build_line(card: CardResource) -> String:
	if card == null:
		return ""
	# ... 初始化代码 ...
	
	# 只处理战斗卡
	if card.card_type == GC.CardType.COMBAT_UNIT:
		var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, era)
		# ... 应用增益 ...
		return "战斗中：" + _format_combat_stats_summary(stats)
	
	return ""
```

## 日期
2026年6月2日
