extends RefCounted
## 首通奖励数据真身（2026-10-08 收益感批重做，取代 v32.0 B3 线性占位公式）
##
## 三层收入模型不变：挂机流水=基线；推图首通=一次性大额主动回报；日常=节奏感。
## 旧线性公式（纳米 200+30×lv）的问题：L100 首通≈5500 当量 ≈ 2 分钟后期挂机流水，
## 相邻关增量 ~2% 完全不可感知（实机主诉"推到 100 多关没有收益感"）。
##
## 新公式 = BASE × 深度 × 时代乘区 × 相位师驻守加成：
##   深度 depth  = 0.7 + 1.3×lv/100            （全程 1.0→2.0 倍）
##   时代乘区    = [3, 5, 8.5, 14, 24]          （黑门之前越深单笔越厚，5 档跳变）
##   相位师加成  = 20 的倍数关 ×2.5             （时代末关=阶段高潮，L99→L100 有 2.5 倍跳变）
## 锚点：L100 首通 纳米 48000/晶体 4200/合金 4800/能量 1440 ≈ 8 场 L100 常规收入
## （≈10 分钟后期流水）；全图 100 关首通总计 ≈ 后期 4-5 小时流水当量，一次性注入不毁流水经济。
## ⚠️ 调数值同步 tests/unit/economy/test_first_clear_rewards.gd（锚点值断言）。
## 发放管线在 GameManager._grant_first_clear_if_eligible（stars==0 判首通，complete_level
## 之前记账），本文件只做纯数据，无副作用。
## 里程碑大奖（成品卡/蓝图/星髓）见 get_milestone_bonus——选件逻辑在 GameManager 侧
## （需要 DefaultCards/拥有状态等 autoload，本文件保持纯数据）。

const ID_CRYSTAL := "crystal"
const ID_NANO := "nano_materials"
const ID_ALLOY := "alloy"
const ID_ENERGY_BLOCK := "energy_block"

const ID_STAR_MARROW := "star_marrow"
const ID_BONUS_CARD := "bonus_card_id"
const ID_BONUS_BLUEPRINT := "bonus_blueprint_min_rarity"

## 时代乘区（era 0-4）。数值即"该时代首通相对开局的厚度"，24=近未来。
const ERA_FIRST_CLEAR_MULT: Array[float] = [3.0, 5.0, 8.5, 14.0, 24.0]

## 时代里程碑关（20 的倍数）额外大奖：一张该时代成品卡 + 一张 epic+ 改造蓝图。
## L100（黑门前最后一关）额外垫 150 星髓（走 EndlessBlackgateManager 周封顶唯一口）。
const MILESTONE_CARD_ERA_STEP := 20
const MILESTONE_BLUEPRINT_MIN_RARITY := "epic"
const MILESTONE_L100_STAR_MARROW := 150


static func _depth_mult(level: int) -> float:
	return 0.7 + 1.3 * float(level) / 100.0


static func _era_index(level: int) -> int:
	return clampi((level - 1) / MILESTONE_CARD_ERA_STEP, 0, ERA_FIRST_CLEAR_MULT.size() - 1)


static func get_first_clear_reward(level: int) -> Dictionary:
	if level < 1:
		return {}
	var era_mult: float = float(ERA_FIRST_CLEAR_MULT[_era_index(level)])
	var phase_mult: float = 2.5 if level % MILESTONE_CARD_ERA_STEP == 0 else 1.0
	var m: float = _depth_mult(level) * era_mult * phase_mult
	return {
		ID_CRYSTAL: int(35.0 * m),
		ID_NANO: int(400.0 * m),
		ID_ALLOY: int(40.0 * m),
		ID_ENERGY_BLOCK: int(12.0 * m),
	}


## 时代里程碑关（20/40/60/80/100）的额外大奖声明。
## card_era: 成品卡从该时代玩家卡池选（优先未拥有，选件在 GameManager）；
## blueprint_min_rarity: 保底稀有度以上的改造蓝图；
## star_marrow: 仅 L100（黑门铺底，受周封顶约束）。
static func get_milestone_bonus(level: int) -> Dictionary:
	if level < 1 or level % MILESTONE_CARD_ERA_STEP != 0:
		return {}
	var bonus: Dictionary = {
		ID_BONUS_CARD: _era_index(level),
		ID_BONUS_BLUEPRINT: MILESTONE_BLUEPRINT_MIN_RARITY,
	}
	if level >= 100:
		bonus[ID_STAR_MARROW] = MILESTONE_L100_STAR_MARROW
	return bonus


## 结算面板/Toast 用一行摘要（四资源；结构性大奖由结算面板单独渲染）
static func format_reward_text(reward: Dictionary) -> String:
	if reward.is_empty():
		return ""
	return "晶体 %d · 纳米 %d · 合金 %d · 能量块 %d" % [
		int(reward.get(ID_CRYSTAL, 0)),
		int(reward.get(ID_NANO, 0)),
		int(reward.get(ID_ALLOY, 0)),
		int(reward.get(ID_ENERGY_BLOCK, 0)),
	]
