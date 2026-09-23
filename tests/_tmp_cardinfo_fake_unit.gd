extends Node2D
## 临时视觉探针用最小假单位（v6.14.8 情报卡改版截图探针配套，验证完可删）
## archetype_id/hp/max_hp 供 _show_generic_enemy_unit 与立绘兜底路径读取；
## target 供目标对比条入口读取。
var stats: UnitStats = null
var is_player := true
var archetype_id := ""
var hp := -1.0
var max_hp := -1.0
var target: Node2D = null
