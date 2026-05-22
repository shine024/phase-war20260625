extends PanelContainer
## 强化面板：使用蓝图碎片提升蓝图等级，或进行突破
## 强化 = 消耗碎片将蓝图提升 1 级
## 突破 = 卡达到 Lv.10 后，消耗大量纳米材料提升稀有度/攻防倍率

const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")
const AffixDefs = preload("res://data/affix_definitions.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")

signal closed()

## 蓝图升级改为消耗对应蓝图碎片

var _selected_card_id: String = ""
var _selected_xp_type: int = -1
