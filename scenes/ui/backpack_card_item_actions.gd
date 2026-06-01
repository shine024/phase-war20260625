## BackpackCardItem Action Button / Info Panel / Hover logic
## 提取自 backpack_card_item.gd，class_name 用于跨文件引用
class_name BackpackCardItemActions
extends RefCounted

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
