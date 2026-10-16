class_name SaveMigrationV10
extends RefCounted
## v9 → v10 存档迁移（v6.71 动态补给网）：
##
## 1. 补 supply_network 段默认值（十区域威胁/陷落降级回溯态/逐关最近评分/
##    兑换 pity/迷失池/游猎状态——全空=系统休眠前默认态，威胁由日结自然建立）。
## 2. 评分旧档折算：level_progress.level_stars 3★→S / 2★→A / 1★→B 写入
##    level_grades（覆盖式口径的初始评分，已有评分的关不覆盖）。
##
## 本迁移只补缺不清洗；威胁扰动 seed 置 0，SupplyNetworkManager 首次日结时生成。

## 旧档星级 → 评分折算（与 BattleEvaluation.STARS_TO_GRADE 同口径；迁移期
## BattleEvaluation 未就绪，静态复制一份避免迁移链依赖运行时类）
const STARS_TO_GRADE := {3: "S", 2: "A", 1: "B"}

const SK_SUPPLY_NETWORK := "supply_network"
const KEY_GRADES := "level_grades"

static func migrate_v9_to_v10(data: Dictionary, debug_log: bool = false) -> void:
	if not data.has(SK_SUPPLY_NETWORK) or not (data[SK_SUPPLY_NETWORK] is Dictionary):
		data[SK_SUPPLY_NETWORK] = {}
	var seg: Dictionary = data[SK_SUPPLY_NETWORK]
	# 评分折算：读旧档 level_progress.level_stars
	if not seg.has(KEY_GRADES):
		var grades: Dictionary = {}
		var lp: Variant = data.get("level_progress", {})
		if lp is Dictionary:
			var stars: Variant = (lp as Dictionary).get("level_stars", {})
			if stars is Dictionary:
				for lv in stars:
					var grade: String = String(STARS_TO_GRADE.get(clampi(int(stars[lv]), 0, 3), ""))
					if not grade.is_empty():
						grades[int(lv)] = grade
		seg[KEY_GRADES] = grades
		if debug_log and not grades.is_empty():
			push_warning("[SaveMigrationV10] v9→v10: 折算 %d 关的初始评分" % grades.size())
