extends RefCounted
class_name CardProgressionSettings

## 卡牌成长总配置（研究点升星 + 改装）

const STAR_MAX: int = 9
const MOD_MAX: int = 3

## 每场战斗基础研究点（可由关卡倍率二次放大）
const BATTLE_RESEARCH_BASE: int = 60
const BATTLE_RESEARCH_WIN_MULTIPLIER: float = 1.0
const BATTLE_RESEARCH_STAR_MULTIPLIER: Dictionary = {
	1: 1.0,
	2: 1.2,
	3: 1.5,
}

## 改装分支模板（默认所有卡可用，可按 card_id 覆盖）
const DEFAULT_MOD_BRANCHES: Array[Dictionary] = [
	{
		"id": "offense",
		"name": "火力改装",
		"desc": "提高攻击与压制能力",
	},
	{
		"id": "defense",
		"name": "防护改装",
		"desc": "提高生存与抗压能力",
	},
	{
		"id": "utility",
		"name": "功能改装",
		"desc": "提高机动与战术功能",
	},
]

