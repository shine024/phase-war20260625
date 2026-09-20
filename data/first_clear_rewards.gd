extends RefCounted
## v32.0 B3-S1 首通奖励数据真身（结构层，数值占位）
##
## 三层收入模型（定位转向计划 B3）：挂机流水=基线（v29.1 口径不动）；推图首通=一次性
## 大额、主动游玩的核心回报；日常=节奏感（缩量数值另行轮）。
## ⚠️ 数值全部占位——TODO(B3数值轮)：等试玩 playtest_metrics 回传后按"首通 ≈ 2-3 天
## 该阶段挂机流水"口径统一校准；Phase Master 关（每 20 关）系数同理。
## 发放管线在 GameManager._grant_first_clear_if_eligible（stars==0 判首通，complete_level
## 之前记账），本文件只做纯数据，无副作用。
## 2026-09-19 补合金（经济体检 P2）：合金是唯一无首通/主动大额收入的主资源
## （升级 {40,100}/引擎 80-500 全靠流水），补一次性推图回报收窄收入缺口。

const ID_CRYSTAL := "crystal"
const ID_NANO := "nano_materials"
const ID_ALLOY := "alloy"
const ID_ENERGY_BLOCK := "energy_block"


## 占位公式：晶体 20+2×level / 纳米 200+30×level / 合金 15+2×level / 能量块 5+level/2；
## 驻守相位师关（20/40/60/80/100）晶体 ×2.5
static func get_first_clear_reward(level: int) -> Dictionary:
	if level < 1:
		return {}
	var crystal: int = 20 + level * 2
	var nano: int = 200 + level * 30
	var alloy: int = 15 + level * 2
	var energy: int = 5 + int(level / 2.0)
	if level % 20 == 0:
		crystal = int(crystal * 2.5)
	return {ID_CRYSTAL: crystal, ID_NANO: nano, ID_ALLOY: alloy, ID_ENERGY_BLOCK: energy}


## 结算面板/Toast 用一行摘要
static func format_reward_text(reward: Dictionary) -> String:
	if reward.is_empty():
		return ""
	return "晶体 %d · 纳米 %d · 合金 %d · 能量块 %d" % [
		int(reward.get(ID_CRYSTAL, 0)),
		int(reward.get(ID_NANO, 0)),
		int(reward.get(ID_ALLOY, 0)),
		int(reward.get(ID_ENERGY_BLOCK, 0)),
	]
