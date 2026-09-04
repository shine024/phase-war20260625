extends Node2D
## 单位地面投影——三层同心椭圆软阴影，锚定槽位地面线（host 原点下方）。
##
## 侧视战场的高度感一半来自投影：影子钉在地面槽位上，单位才是"悬在战场上方"，
## 而不是浮在界面里。由 CardGridUnitVisuals 在单位呈现时创建/定位，
## 随待机浮动呼吸（set_bob：升起→缩小变淡），死亡坠落开始时隐藏。
##
## v26.9: 推广为全单位投影——ground=true 为地面单位贴地接触影（更淡、相对更宽），
## 悬空影（空中单位）保持原参数。修复：地面单位零投影，亮底背景上没有落地分离感。
##
## 性能：纯 _draw 矢量（无贴图/粒子），每单位 1 个节点，全场 ≤40 个。

const _BASE_ALPHA: float = 0.30
const _GROUND_ALPHA_MUL: float = 0.72  # 贴地接触影比悬空影淡——落地感而非悬浮感

var _rx: float = 24.0  # 椭圆长半轴（px），按实体高度标定
var _ground: bool = false


## 按实体视觉高度标定影子大小。ground=true（地面单位接触影）比悬空影更宽更淡。
func setup(entity_h: float, ground: bool = false) -> void:
	_ground = ground
	_rx = clampf(entity_h * (0.42 if ground else 0.30), 14.0 if ground else 16.0, 40.0 if ground else 34.0)
	if ground:
		# 换形态从空中落回：清 set_bob 残留的缩放/减淡（贴地影静止满影）
		scale = Vector2.ONE
		modulate.a = 1.0
	queue_redraw()


## 待机浮动联动（仅空中单位调用）：frac 0=浮动最低点（满影）→ 1=最高点（缩小变淡）
func set_bob(frac: float) -> void:
	var k: float = 1.0 - 0.16 * frac
	scale = Vector2(k, k)
	modulate.a = 1.0 - 0.35 * frac


func _draw() -> void:
	var a_mul: float = _GROUND_ALPHA_MUL if _ground else 1.0
	# 压扁成椭圆（y 比例 0.32），三层同心圆叠出软边
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	for i in 3:
		var k: float = 1.0 - float(i) * 0.30
		var a: float = _BASE_ALPHA * a_mul * (1.0 - float(i) * 0.34)
		draw_circle(Vector2.ZERO, _rx * k, Color(0.04, 0.06, 0.10, a))
