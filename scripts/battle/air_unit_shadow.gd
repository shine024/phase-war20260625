extends Node2D
## v23.5 空中单位地面投影——三层同心椭圆软阴影，锚定槽位地面线（host 原点下方）。
##
## 侧视战场的高度感一半来自投影：影子钉在地面槽位上，单位才是"悬在战场上方"，
## 而不是浮在界面里。由 CardGridUnitVisuals 在单位呈现时创建/定位，
## 随待机浮动呼吸（set_bob：升起→缩小变淡），死亡坠落开始时隐藏。
##
## 性能：纯 _draw 矢量（无贴图/粒子），每空中单位 1 个节点，全场 ≤18 个。

const _BASE_ALPHA: float = 0.30

var _rx: float = 24.0  # 椭圆长半轴（px），按实体高度标定


## 按实体视觉高度标定影子大小（空中单位越高大投影越大）
func setup(entity_h: float) -> void:
	_rx = clampf(entity_h * 0.30, 16.0, 34.0)
	queue_redraw()


## 待机浮动联动：frac 0=浮动最低点（满影）→ 1=最高点（缩小变淡）
func set_bob(frac: float) -> void:
	var k: float = 1.0 - 0.16 * frac
	scale = Vector2(k, k)
	modulate.a = 1.0 - 0.35 * frac


func _draw() -> void:
	# 压扁成椭圆（y 比例 0.32），三层同心圆叠出软边
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	for i in 3:
		var k: float = 1.0 - float(i) * 0.30
		var a: float = _BASE_ALPHA * (1.0 - float(i) * 0.34)
		draw_circle(Vector2.ZERO, _rx * k, Color(0.04, 0.06, 0.10, a))
