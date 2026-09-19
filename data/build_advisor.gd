extends RefCounted
## v32.0 B2-2 战前构筑建议（克制提示）
##
## 数据源：LevelInformation.get_special_rules（规则键，最高优先级——直接改变通关条件）
## + BattleEnvEffects.get_level_env_mults（环境乘区，敌我同源的战前公开题面）。
## 主题侧 threat/advice 已由 world_map 战前简报消费（R3-lite），本文件不重复。
## 定位：把环境/规则从"被动接受 debuff"升级为"构筑决策输入"（战术构筑放置 Pillar 1）。
## 纯函数无副作用；输出 ≤3 条、第二人称；情报门槛留待后续（v1 全量可见——
## 规则与环境本就是战前公开信息，不构成情报泄露）。

const LevelInformation = preload("res://data/level_information.gd")
const BattleEnvEffects = preload("res://data/battle_env_effects.gd")


static func get_build_tips(level: int) -> Array[String]:
	var tips: Array[String] = []

	# ── 特殊规则（最高优先级）──
	var rules: Dictionary = LevelInformation.get_shared().get_special_rules(level)
	if rules.has("no_heal"):
		tips.append("本场禁疗：高血量前排优先，别把胜算押在回复上")
	if rules.has("no_mods"):
		tips.append("本场改造失效：练度与克制比改造更重要")
	if rules.has("first_strike"):
		tips.append("敌方先手：开局别裸铺脆皮，留能量应对第一波集火")
	if String(rules.get("win_type", "")) == "survive_waves":
		tips.append("坚守波次：生存即胜利，回复与控制优先于爆发")
	# v6.16 反制配波：敌方构成偏向某兵种——给出针对性构筑提示（规则条最高优先级）
	var cbt: Array = rules.get("counter_bias_tags", [])
	if not cbt.is_empty():
		if cbt.has("aircraft"):
			tips.append("敌方以飞行单位为主：备足对空火力再出击")
		elif cbt.has("armored") or cbt.has("tank"):
			tips.append("敌方装甲洪流：对甲火力不足会被硬推平")
		elif cbt.has("artillery") or cbt.has("backline"):
			tips.append("敌方远程炮兵为主：速攻突脸或曲射反制")
		elif cbt.has("infantry") or cbt.has("fast"):
			tips.append("敌方步兵海冲锋：溅射与范围武器高效")

	# ── 环境乘区（敌我同源，阈值 0.9/1.1 之外才提示）──
	var m: Dictionary = BattleEnvEffects.get_level_env_mults(level)
	var indirect: float = float(m.get("indirect_dmg", 1.0))
	var direct: float = float(m.get("direct_dmg", 1.0))
	if indirect < 0.9:
		tips.append("曲射受限：迫击炮/火箭收益低，直射火力求胜")
	elif indirect > 1.1:
		tips.append("曲射增伤：迫击炮/火箭炮单位收益放大")
	if direct < 0.9:
		tips.append("直射受限：步枪/坦克输出打折，配曲射或速射体系")
	elif direct > 1.1:
		tips.append("直射增伤：枪炮体系正当时，主力输出放心铺")
	if float(m.get("atk_speed", 1.0)) > 1.1:
		tips.append("攻速提升：机枪/速射炮等高频武器收益放大")
	elif float(m.get("atk_speed", 1.0)) < 0.9:
		tips.append("攻速下降：高频体系乏力，单发高伤更稳")
	if float(m.get("regen", 1.0)) < 0.9:
		tips.append("回能放缓：压低平均能耗，先铺低成本单位")
	if float(m.get("direct_range", 1.0)) > 1.1:
		tips.append("射程扩展：长射程单位可以更安全地输出")

	# 控量：规则优先级天然在前，超出截尾
	while tips.size() > 3:
		tips.pop_back()
	return tips
