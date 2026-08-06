# 组合技套路视觉优化实施方案

> 目标：让 6 套组合技在战斗中"看得见、感得到、想得起"
> 范围：纯视觉/反馈层，不动战斗数值逻辑
> 前提：ComboEngine / ComboFieldState / module_effect_handler 已完整实现，本方案在其之上叠加视觉层

---

## 架构总览

```
battlefield (Node2D)
├── ComboFieldOverlay (新增 Node2D)   ← 战场浓度区域可视化
│   ├── nano_field_vfx (GPUParticles2D)
│   └── chem_field_vfx (GPUParticles2D)
├── ComboEffectLayer (新增 Node2D)    ← 动态 VFX（光束/爆炸/扩散波纹）
├── PlayerUnits / EnemyUnits
│   └── 每个单位身上：
│       ├── WeakpointIndicator (Sprite2D)  ← 弱点暴露十字
│       ├── RadarLockIndicator (Polygon2D) ← 雷达锁定圈
│       └── ResonanceIndicator (Sprite2D)  ← 激光谐振环
└── Bullet

HudLayer (CanvasLayer)
├── ComboStatusStrip (新增 PanelContainer)  ← 底部套路状态条
└── ComboActivateBanner (新增 Label + Tween) ← 顶部激活横幅
```

---

## 改动文件清单

| # | 文件 | 类型 | 改动量 | 优先级 |
|---|------|------|--------|--------|
| 1 | `scripts/battle/vfx_impact_factory.gd` | 修改 | +250行 | P0 |
| 2 | `scripts/battle/combo_field_state.gd` | 修改 | +30行 | P0 |
| 3 | `scripts/battle/combo_engine.gd` | 修改 | +80行 | P0 |
| 4 | `scenes/battlefield/battlefield.tscn` | 修改 | +3节点 | P0 |
| 5 | `scenes/ui/combo_status_strip.gd` | 新建 | ~180行 | P1 |
| 6 | `scenes/ui/combo_status_strip.tscn` | 新建 | ~60行 | P1 |
| 7 | `scenes/main.tscn` | 修改 | +1节点 | P1 |
| 8 | `scenes/battlefield/Battlefield.gd` | 修改 | +40行 | P1 |
| 9 | `scenes/units/bullet.gd` | 修改 | +20行 | P1 |
| 10 | `scripts/battle/unit_status_collector.gd` | 修改 | +30行 | P2 |
| 11 | `data/combo_tactics.gd` | 修改 | +6图标引用 | P2 |
| 12 | `scenes/effects/combo_activate_banner.tscn` | 新建 | ~40行 | P2 |

---

## P0：战场浓度场可视化（nano + chem）

### 设计
纳米浓度（0-50）和化学污染（0-60）全战场累积，**当前完全不可见**，玩家无法感知"铺场"是否有效。
→ 在 battlefield 上添加两个半透明粒子区域，随浓度渐显渐隐。

### 改动 1：`scripts/battle/vfx_impact_factory.gd`

新增两个 static 方法，复用现有 beam 池和 particles 创建模式：

```gdscript
# ─────────────────────────────────────────────
#  组合技战场浓度场 VFX
# ─────────────────────────────────────────────

## 战场纳米浓度可视化（Cyan 粒子层）。
## amount: 当前浓度值（0~50）；parent 是 battlefield Node2D；world_pos 是战场中心。
## 浓度越高：粒子密度越大、范围越大、alpha 越高。
## 调用频率：每帧由 battlefield 驱动（浓度变化时重建/更新，非每帧 spawn）。
static func spawn_nano_field(parent: Node2D, world_pos: Vector2, amount: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	# 浓度→参数映射：amount 0~50 → density 0~1, radius 100~280, alpha 0~0.18
	var t: float = clampf(amount / 50.0, 0.0, 1.0)
	var particle_count := int(lerp(10.0, 80.0, t))
	var radius: float = lerp(100.0, 280.0, t)
	var alpha: float = lerp(0.0, 0.15, t)
	# 复用 create_particles_2d 模式（参考 spawn_ground_burn）
	var pts := PackedVector2Array()
	for i in range(32):
		var ang := TAU * float(i) / 32.0
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.position = world_pos
	poly.color = Color(0.2, 0.9, 1.0, alpha)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	poly.material = mat
	# 移除旧 nano field（先查 meta）
	_cleanup_field_vfx(parent, "combo_nano_field")
	poly.name = "combo_nano_field"
	parent.add_child(poly)

## 战场化学污染可视化（Green 粒子层）。
## amount: 当前浓度（0~60）；同 spawn_nano_field 参数约定。
static func spawn_chem_field(parent: Node2D, world_pos: Vector2, amount: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var t: float = clampf(amount / 60.0, 0.0, 1.0)
	var radius: float = lerp(80.0, 320.0, t)
	var alpha: float = lerp(0.0, 0.18, t)
	var pts := PackedVector2Array()
	for i in range(32):
		var ang := TAU * float(i) / 32.0
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.position = world_pos
	poly.color = Color(0.3, 1.0, 0.2, alpha)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	poly.material = mat
	_cleanup_field_vfx(parent, "combo_chem_field")
	poly.name = "combo_chem_field"
	parent.add_child(poly)

## 清理已存在的浓度场 VFX（防止重复创建）。
static func _cleanup_field_vfx(parent: Node2D, name: String) -> void:
	var old := parent.get_node_or_null(name)
	if old != null and is_instance_valid(old):
		old.queue_free()

## 化学爆炸扩散波纹（chem_burst 触发时）。
## 从 src 向外 radiate 一个绿色冲击波环，半径 80，0.6s 淡出。
static func spawn_chem_burst_wave(parent: Node2D, pos: Vector2) -> void:
	spawn_shockwave(parent, pos, 80.0, Color(0.3, 1.0, 0.2, 0.9), 0.6)

## 纳米传染波纹（nano_spread 触发时）。
## 青色冲击波，半径 60，0.5s 淡出。
static func spawn_nano_spread_wave(parent: Node2D, pos: Vector2) -> void:
	spawn_shockwave(parent, pos, 60.0, Color(0.2, 0.9, 1.0, 0.85), 0.5)
```

### 改动 2：`scripts/battle/combo_field_state.gd`

浓度变化时 emit 信号，让战场层能响应：

```gdscript
# 新增信号（顶部常量区下方）
signal field_changed(tag: String, amount: float)

# add_field 末尾追加：
emit_signal("field_changed", tag, f["amount"])
```

### 改动 3：`scenes/battlefield/Battlefield.gd`

在 `_ready` 中订阅浓度场信号，每 0.5s 重绘浓度场（避免每帧刷新）：

```gdscript
var _combo_field_state: RefCounted = null
var _field_refresh_acc: float = 0.0
const _FIELD_REFRESH_SEC: float = 0.5

func _ready() -> void:
	# ... 原有 _ready ...
	# 订阅 combo_field_state 浓度变化
	var bm := get_node_or_null("/root/BattleManager")
	if bm != null:
		_combo_field_state = bm.get_combo_field_state()
		if _combo_field_state != null:
			_combo_field_state.field_changed.connect(_on_field_changed)

func _process(delta: float) -> void:
	# ... 原有 _process ...
	if _combo_field_state != null:
		_field_refresh_acc += delta
		if _field_refresh_acc >= _FIELD_REFRESH_SEC:
			_field_refresh_acc = 0.0
			_redraw_field_vfx()

func _on_field_changed(tag: String, amount: float) -> void:
	# 浓度变化时立即刷新（不等 0.5s 周期）
	_redraw_field_vfx()

func _redraw_field_vfx() -> void:
	if _combo_field_state == null:
		return
	var center := Vector2(640, 200)  # 战场中心（BattleCamera position）
	var nano_amt := _combo_field_state.get_field(ComboFieldState.FIELD_NANO)
	var chem_amt := _combo_field_state.get_field(ComboFieldState.FIELD_CHEM)
	if nano_amt > 0.5:
		VfxImpactFactory.spawn_nano_field(self, center, nano_amt)
	if chem_amt > 0.5:
		VfxImpactFactory.spawn_chem_field(self, center, chem_amt)
```

**注意**：`_redraw_field_vfx` 每次先清理再重建（factory 的 `_cleanup_field_vfx` 已处理），所以重复调用安全。

---

## P0：套路激活横幅通知

### 设计
单卡激活/全队激活时，屏幕顶部出现短暂横幅，让"**组合技触发了**"立刻被感知。
- 单卡激活：小横幅，持续 1.5s
- 全队激活：大横幅 + 轻微震动，持续 2s

### 改动 4：`scripts/battle/vfx_impact_factory.gd`

新增横幅创建方法（CanvasLayer 层，不依赖特定 scene）：

```gdscript
## 屏幕顶部组合技激活横幅。
## text: 横幅文字（如"⚡ 电磁脉冲链·全队激活"）；duration: 显示时长（秒）；is_team: 是否全队激活（影响样式）。
static func show_combo_activate_banner(text: String, duration: float = 2.0, is_team: bool = false) -> void:
	var root := Engine.get_main_loop().root
	if root == null:
		return
	var hud := root.get_node_or_null("/root/Main/HudLayer")
	if hud == null:
		return
	var banner := Label.new()
	banner.text = text
	banner.position = Vector2(640, 10)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.custom_minimum_size = Vector2(400, 36)
	banner.add_theme_font_size_override("font_size", 18 if is_team else 14)
	banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	banner.add_theme_constant_override("outline_size", 3)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	banner.material = mat
	hud.add_child(banner)
	# 入场动画（从上方滑入 + 淡入）
	var tw := banner.create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "position:y", 60.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 1.0, 0.3)
	# 停留后淡出 + 滑出
	var hold := duration - 0.4
	tw.tween_interval(hold)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_property(banner, "position:y", -40.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): banner.queue_free())
	# 全队激活：轻微震动
	if is_team:
		var shake := get_node_or_null("/root/Main/HudLayer/Battlefield/BattleCamera") as Node
		if shake != null and shake.has_method("shake"):
			shake.call("shake", 3.0, 0.15)
```

### 改动 5：`scripts/battle/combo_engine.gd`

在 `_refresh_team_mechanisms` 末尾触发横幅：

```gdscript
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")
const ComboTactics = preload("res://data/combo_tactics.gd")

func _refresh_team_mechanisms() -> void:
	# ... 原有逻辑 ...
	var prev_count: int = _active_mechanisms.size()
	# ... detect + set _active_mechanisms ...
	var new_count: int = _active_mechanisms.size()
	# 新机制从 0 变 >0 → 全队激活横幅
	if prev_count == 0 and new_count > 0:
		var names: Array = []
		for cid in _get_active_combo_ids():
			var def := ComboTactics.get_combo_def(cid)
			if not def.is_empty():
				names.append(def.get("name", cid))
		if not names.is_empty():
			VfxImpactFactory.show_combo_activate_banner(
				"「%s」全队激活！" % ",".join(names), 2.0, true
			)

## 获取当前全队激活的 combo_id 列表（供横幅用）
func _get_active_combo_ids() -> Array:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return []
	var allies := _get_player_units()
	if allies.is_empty():
		return []
	var team_combos := ComboTactics.detect_team_combos(allies)
	return team_combos
```

> 单卡激活横幅：在 `module_effect_handler.gd` 中，当某个单位首次满足 mod combo 条件时调用：
> ```gdscript
> VfxImpactFactory.show_combo_activate_banner(
>     "「%s」单卡激活" % def.get("name", combo_id), 1.5, false
> )
> ```
> 触发时机：在 `_apply_mod_stat_effects` 检测 combo 激活后追加。

---

## P0：光束谐振链分裂/反射特效

### 设计
当前 `bullet.gd` 已调用 `try_beam_resonance()` 并执行了伤害逻辑，**但完全没有 VFX**。
→ 分裂：从主目标射出 2 条次级激光到相邻敌人；反射：30% 概率从主目标反射到相邻敌方。

### 改动 6：`scripts/battle/vfx_impact_factory.gd`

新增光束分裂/反射方法（复用 beam 池）：

```gdscript
## 光束多重攻击次级射线（套路4 beam_split）。
## 从 target 位置射向各 secondary_pos，color 同主激光。
static func spawn_beam_split_arcs(parent: Node2D, target_pos: Vector2,
		secondary_positions: Array, color: Color = Color(0.9, 0.8, 1.0, 1.0)) -> void:
	for sp in secondary_positions:
		if sp == null:
			continue
		var pos := (sp as Vector2)
		spawn_laser_beam(parent, target_pos, pos, color)

## 光束反射射线（套路4 beam_reflect）。
## 从 target 位置反射到 reflect_pos，衰减 60% 后颜色变暗。
static func spawn_beam_reflect_arc(parent: Node2D, target_pos: Vector2,
		reflect_pos: Vector2) -> void:
	spawn_laser_beam(parent, target_pos, reflect_pos, Color(0.7, 0.6, 0.9, 0.7))
```

### 改动 7：`scenes/units/bullet.gd`

在 `_beam_res` 处理块末尾追加 VFX 调用：

```gdscript
# 原有逻辑（L933-949）不变，末尾追加：
if _beam_res.get("split", false) and is_instance_valid(shooter) and primary != null:
	var _tpos := (primary.global_position if primary is Node2D else global_position)
	# 次级光束射向主目标（视觉）+ 找 2 个相邻目标（复用已有逻辑的 neighbors 范围）
	var _sg := "enemy_units" if shooter_is_player else "player_units"
	var _secondds := []
	for _n in (get_tree().get_nodes_in_group(_sg) if get_tree() != null else []):
		if _n == null or not is_instance_valid(_n) or _n == primary:
			continue
		if _tpos.distance_to((_n as Node2D).global_position) <= 120.0:
			_secondds.append((_n as Node2D).global_position)
			if _secondds.size() >= 2:
				break
	VfxImpactFactory.spawn_beam_split_arcs(
		get_parent() as Node2D, _tpos, _secondds, Color(0.9, 0.8, 1.0)
	)
if _beam_res.get("reflect", false) and is_instance_valid(shooter) and primary != null:
	var _rpos := global_position
	# 反射目标在 for 循环里 break 了，这里从组里重新找一个（或从 meta 取）
	# 简单方案：反射到主目标同方向 120px 外
	var _dir := (_tpos - global_position).normalized() * 120.0
	_rpos = _tpos + _dir
	VfxImpactFactory.spawn_beam_reflect_arc(
		get_parent() as Node2D, _tpos, _rpos
	)
```

> **备选方案（更精确）**：在 `combo_engine.gd::try_beam_resonance` 返回结果中加 `"reflect_pos": Vector2` 字段，bullet.gd 直接用。但需要改动 engine 接口，优先级 P1。

---

## P1：侦察链式弱点暴露 + 雷达锁定视觉

### 设计
弱点暴露（+50% 暴击伤害）是狙击手核心爽点，**当前目标身上没有任何"脆弱"标志**。
雷达锁定每 12s 触发，**也没有视觉**。

### 改动 8：`scripts/battle/vfx_impact_factory.gd`

```gdscript
## 弱点暴露指示器（套路5 weakpoint_expose）。
## 目标头顶红色 X 十字，持续 duration 秒，脉动放大。
static func spawn_weakpoint_indicator(parent: Node2D, pos: Vector2, duration: float = 3.0) -> void:
	var x := Line2D.new()
	x.width = 3.0
	x.default_color = Color(1.0, 0.3, 0.2, 1.0)
	x.joint_mode = Line2D.LINE_JOINT_ROUND
	x.end_cap_mode = Line2D.LINE_CAP_ROUND
	x.add_point(Vector2(-12, -12))
	x.add_point(Vector2(12, 12))
	x.add_point(Vector2(-12, 12))
	x.add_point(Vector2(12, -12))
	x.position = pos
	parent.add_child(x)
	var tw := x.create_tween()
	tw.set_loops()
	tw.tween_property(x, "scale", Vector2(1.15, 1.15), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(x, "scale", Vector2(0.85, 0.85), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# duration 后淡出并移除
	tw.tween_interval(duration)
	tw.tween_property(x, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): x.queue_free())

## 雷达锁定圈（套路5 radar_lock）。
## 目标脚下蓝色旋转扫描圈，持续期间保持，每帧微旋转。
static func spawn_radar_lock_ring(parent: Node2D, pos: Vector2, duration: float = 6.0) -> void:
	var poly := Polygon2D.new()
	var segments := 24
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := TAU * float(i) / segments
		pts.append(Vector2(cos(ang), sin(ang)) * 28.0)
	poly.polygon = pts
	poly.position = pos
	poly.position.y += 15  # 脚下
	poly.color = Color(0.35, 0.88, 1.0, 0.4)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	poly.material = mat
	parent.add_child(poly)
	# 缓慢旋转
	var rot_tw := poly.create_tween()
	rot_tw.set_loops()
	rot_tw.tween_property(poly, "rotation", TAU, 4.0).set_trans(Tween.TRANS_LINEAR)
	# duration 后淡出
	var fade_tw := poly.create_tween()
	fade_tw.tween_interval(duration)
	fade_tw.tween_property(poly, "modulate:a", 0.0, 0.5)
	fade_tw.tween_callback(func(): poly.queue_free())
```

### 改动 9：`scripts/battle/module_effect_handler.gd`

在雷达锁定和弱点暴露触发处追加 VFX：

```gdscript
# 在 _apply_radar_lock_on_hit 末尾（设置雷达锁定 meta 后）：
if target != null and is_instance_valid(target):
	VfxImpactFactory.spawn_radar_lock_ring(target, target.global_position, dur)  # dur 是锁定持续时间

# 在 try_weakpoint_expose 调用后（bullet.gd 中）：
# 弱点暴露成功后，在目标身上生成 X 标记
if exposed and primary != null and is_instance_valid(primary):
	VfxImpactFactory.spawn_weakpoint_indicator(primary.get_parent(), primary.global_position, 3.0)
```

---

## P1：化学爆发/纳米传染扩散波纹

### 改动 10：`scripts/battle/combo_engine.gd`

在各扩散函数末尾调用 VFX：

```gdscript
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")

static func try_chem_burst(...) -> void:
	# ... 原有逻辑 ...
	if infected > 0 and target != null and is_instance_valid(target):
		VfxImpactFactory.spawn_chem_burst_wave(target.get_parent() as Node2D,
			(target as Node2D).global_position)

static func try_nano_spread(...) -> void:
	# ... 原有逻辑 ...
	if n != null and is_instance_valid(n):
		VfxImpactFactory.spawn_nano_spread_wave(n.get_parent() as Node2D,
			(n as Node2D).global_position)
		break
```

---

## P1：组合技状态条（底部 HUD）

### 设计
在 `HudLayer` 底部添加一个横向条，显示 6 套套路的当前状态：
- 灰色 = 未激活
- 黄色 = 单卡激活（装了 ≥2 配套改造）
- 绿色发光 = 全队激活（兵种组合满足）

让玩家可以**一眼看到当前哪些套路可用**。

### 改动 11：新建 `scenes/ui/combo_status_strip.gd`

```gdscript
extends PanelContainer
## v9.1 组合技状态条：底部 HUD，显示 6 套套路激活状态
## 样式：6 个方形图标横排，颜色 = 灰色(未激活) / 黄(单卡) / 绿(全队)

const ComboTactics = preload("res://data/combo_tactics.gd")
const ComboEngine = preload("res://scripts/battle/combo_engine.gd")

var _icon_buttons: Array[Button] = []
var _battle_manager: Node = null
var _refresh_acc: float = 0.0
const REFRESH_SEC: float = 0.5

func _ready() -> void:
	custom_minimum_size = Vector2(600, 44)
	# 标题
	var title := Label.new()
	title.text = "⚔ 组合技"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.8))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	# 6 个套路图标（HBox 横排）
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)
	for combo_id in [
		ComboTactics.COMBO_INCENDIARY,
		ComboTactics.COMBO_EMP,
		ComboTactics.COMBO_NANO,
		ComboTactics.COMBO_LASER,
		ComboTactics.COMBO_RECON,
		ComboTactics.COMBO_CHEM,
	]:
		var def := ComboTactics.get_combo_def(combo_id)
		if def.is_empty():
			continue
		var btn := _make_combo_icon_button(def)
		hbox.add_child(btn)
		_icon_buttons.append(btn)
	# 订阅战斗管理器（懒加载）
	_refresh_accum = 0.0

func _make_combo_icon_button(def: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(44, 36)
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.tooltip_text = def.get("name", "") + "\n" + def.get("desc", "")
	# 图标：用背景色块 + 文字（emoji 作为图标）
	btn.text = def.get("icon", "❓")
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	# 样式：未激活 = 灰色，单卡 = 橙色，全队 = 绿色
	_set_combo_style(btn, 0)  # 0 = 未激活
	return btn

func _set_combo_style(btn: Button, level: int) -> void:
	# level: 0=未激活, 1=单卡激活, 2=全队激活
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	var focused := StyleBoxFlat.new()
	match level:
		0:  # 未激活
			normal.bg_color = Color(0.12, 0.12, 0.15, 0.7)
			hover.bg_color = Color(0.18, 0.18, 0.22, 0.8)
			focused.bg_color = normal.bg_color
		1:  # 单卡激活（橙）
			normal.bg_color = Color(0.9, 0.55, 0.1, 0.85)
			hover.bg_color = Color(1.0, 0.65, 0.15, 0.9)
			focused.bg_color = hover.bg_color
		2:  # 全队激活（绿 + 发光）
			normal.bg_color = Color(0.2, 0.85, 0.35, 0.9)
			hover.bg_color = Color(0.3, 1.0, 0.45, 0.95)
			focused.bg_color = hover.bg_color
			normal.border_width_left = 2
			normal.border_color = Color(0.6, 1.0, 0.5, 1)
		_set_style(btn, normal, hover, focused)

func _set_style(btn: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, focused: StyleBoxFlat) -> void:
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", focused)

func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_SEC:
		_refresh_accum = 0.0
		_refresh()

func _refresh() -> void:
	var bm := get_node_or_null("/root/BattleManager")
	if bm == null:
		return
	var eng: RefCounted = null
	if bm.has_method("get_combo_engine"):
		eng = bm.get_combo_engine()
	if eng == null:
		return
	# 全队激活机制
	var team_mechs := eng.get_active_mechanisms()
	var team_combos := _get_team_combo_ids(eng)
	# 遍历 6 个按钮更新样式
	for i in range(min(_icon_buttons.size(), 6)):
		var btn := _icon_buttons[i]
		var combo_id := _get_combo_id_at_index(i)
		if combo_id == null:
			continue
		var level: int = 0
		if team_combos.has(combo_id):
			level = 2  # 全队激活
		elif _has_card_combo_activated(combo_id, eng):
			level = 1  # 单卡激活
		_set_combo_style(btn, level)

func _get_team_combo_ids(eng: RefCounted) -> Array:
	# 从 active_mechanisms 反推 combo_id
	# 简化：直接读 combo_engine 的 team combo 检测
	var bf := eng.get_node_or_null(".")  # 取 battlefield
	# 最佳方案：combo_engine 暴露 get_active_combo_ids() 方法（需新增）
	# 临时方案：通过 mechanisms 名称反查
	var result := []
	var mechs := eng.get_active_mechanisms()
	for combo_id in [
		ComboTactics.COMBO_INCENDIARY, ComboTactics.COMBO_EMP,
		ComboTactics.COMBO_NANO, ComboTactics.COMBO_LASER,
		ComboTactics.COMBO_RECON, ComboTactics.COMBO_CHEM,
	]:
		var def := ComboTactics.get_combo_def(combo_id)
		var combo_mechs := def.get("mechanisms", [])
		for m in combo_mechs:
			if mechs.has(String(m)):
				result.append(combo_id)
				break
	return result

func _has_card_combo_activated(combo_id: String, eng: RefCounted) -> bool:
	# 单卡激活判定：遍历场上所有玩家单位，检查 mods
	var allies := []
	var bf := (eng as Node) if eng is Node else null
	if bf != null:
		allies = bf.get_tree().get_nodes_in_group("player_units")
	for u in allies:
		if u == null or not is_instance_valid(u):
			continue
		var mods := []
		if "stats" in u and u.stats != null:
			if u.stats.has_meta("mod_ids"):
				mods = u.stats.get_meta("mod_ids", [])
		var card_combos := ComboTactics.detect_card_combos(mods)
		if card_combos.has(combo_id):
			return true
	return false

func _get_combo_id_at_index(i: int) -> String:
	var ids := [
		ComboTactics.COMBO_INCENDIARY,
		ComboTactics.COMBO_EMP,
		ComboTactics.COMBO_NANO,
		ComboTactics.COMBO_LASER,
		ComboTactics.COMBO_RECON,
		ComboTactics.COMBO_CHEM,
	]
	if i >= ids.size():
		return ""
	return ids[i]
```

### 改动 12：新建 `scenes/ui/combo_status_strip.tscn`

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/combo_status_strip.gd" id="1"]

[node name="ComboStatusStrip" type="PanelContainer"]
script = ExtResource("1")
```

### 改动 13：`scenes/main.tscn`

在 HudLayer 末尾追加：
```
[node name="ComboStatusStrip" parent="HudLayer" instance=ExtResource("xx_combo_strip")]
anchor_right = 1.0
anchor_bottom = 1.0
offset_bottom = -10.0
```

---

## P2：DOT 图标升级为动态

### 设计
当前 burn/chem/nano/emp 的 DOT 贴图是静态 PNG，加脉动只改变缩放，**看不出"类型差异"**。
→ 给每种 DOT 增加第二层"动态特征"：
- **burn**：脉动频率加快（火焰跳动感）+ 橙色粒子向上飘
- **chem**：脉动更慢（毒液滴落感）+ 绿色粒子下沉
- **nano**：六边形脉冲（纳米蜂群）
- **emp**：电弧闪烁（闪电随机出现）

### 改动 14：`scripts/battle/dot_vfx_manager.gd`

在 `attach_dot_vfx` 中，除了 Sprite2D 外，额外附加一个小型粒子系统（或旋转环）：

```gdscript
## 为 burn 附加向上飘的橙色粒子环（火焰感）
static func _attach_burn_aura(unit: Node2D, dot_node: Node2D) -> void:
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var ang := TAU * float(i) / 12.0
		pts.append(Vector2(cos(ang), sin(ang)) * 18.0)
	ring.polygon = pts
	ring.position = Vector2(0, -5)
	ring.color = Color(1.0, 0.5, 0.15, 0.5)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = mat
	dot_node.add_child(ring)
	# 旋转脉动
	var tw := ring.create_tween()
	tw.set_loops()
	tw.tween_property(ring, "rotation", TAU, 2.0).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(ring, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ring, "scale", Vector2(0.8, 0.8), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## 为 chem 附加下沉的绿色粒子环（毒液感）
static func _attach_chem_aura(unit: Node2D, dot_node: Node2D) -> void:
	var ring := Polygon2D.new()
	# 类似 burn，但颜色偏绿，旋转方向相反
	# ... 结构与 _attach_burn_aura 对称 ...

## 为 nano 附加六边形脉冲（纳米蜂群）
static func _attach_nano_aura(unit: Node2D, dot_node: Node2D) -> void:
	var hex := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := TAU * float(i) / 6.0 + PI / 6.0
		pts.append(Vector2(cos(ang), sin(ang)) * 20.0)
	hex.polygon = pts
	hex.position = Vector2(0, 5)
	hex.color = Color(0.2, 0.9, 1.0, 0.5)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	hex.material = mat
	dot_node.add_child(hex)
	# 脉冲呼吸（快）
	var tw := hex.create_tween()
	tw.set_loops()
	tw.tween_property(hex, "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(hex, "scale", Vector2(0.7, 0.7), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## 为 emp 附加电弧闪烁
static func _attach_emp_aura(unit: Node2D, dot_node: Node2D) -> void:
	# EMP 用随机闪烁的亮白短线模拟电弧
	var arc := Line2D.new()
	arc.width = 2.0
	arc.default_color = Color(0.8, 0.6, 1.0, 1.0)
	arc.joint_mode = Line2D.LINE_JOINT_ROUND
	arc.add_point(Vector2(-10, -8))
	arc.add_point(Vector2(-3, 2))
	arc.add_point(Vector2(5, -4))
	arc.add_point(Vector2(10, 8))
	arc.position = Vector2(0, -8)
	dot_node.add_child(arc)
	# 随机闪烁
	var tw := arc.create_tween()
	tw.set_loops()
	tw.tween_property(arc, "modulate:a", 0.1, 0.05)
	tw.tween_property(arc, "modulate:a", 1.0, 0.05)
	tw.tween_property(arc, "modulate:a", 0.2, 0.05)
	tw.tween_property(arc, "modulate:a", 1.0, 0.05)
```

在 `attach_dot_vfx` 的 `else` 分支（贴图存在时）末尾追加对应 aura：
```gdscript
# 贴图存在：创建 Sprite2D + 类型特定 aura
vfx = Sprite2D.new()
# ... 原有 Sprite2D 设置 ...
dot_node.add_child(vfx)
# 附加动态 aura
match dot_type:
	"burn": _attach_burn_aura(unit, vfx)
	"chem": _attach_chem_aura(unit, vfx)
	"nano": _attach_nano_aura(unit, vfx)
	"emp": _attach_emp_aura(unit, vfx)
```

---

## P2：雷达锁定持续扫描 VFX

### 设计
相控阵雷达每 12s 扫描一次，**锁定期间没有任何视觉标志**。
→ 被锁定的目标脚下出现**蓝色旋转扫描圈**（已在上文 P1 中定义 `spawn_radar_lock_ring`）。

### 改动 15：`scripts/battle/module_effect_handler.gd`

在 `_tick_radar_lock` 中，锁定目标后调用 VFX：

```gdscript
# 在 best.set_meta(ComboFieldState.META_RADAR_LOCKED, ...) 后追加：
if best != null and is_instance_valid(best):
	VfxImpactFactory.spawn_radar_lock_ring(
		best.get_parent() as Node2D,
		best.global_position,
		dur  # 锁定持续时间
	)
```

---

## P2：组合技图标用纹理替代 emoji

### 设计
`combo_tactics.gd` 的 `"icon"` 字段当前是 emoji 字符串（`"🔥"`, `"⚡"` 等），仅用于 HUD 文本展示。
→ 新增 `"icon_tex"` 字段，引用实际纹理（后续补充资源）。

### 改动 16：`data/combo_tactics.gd`

```gdscript
const COMBOS: Dictionary = {
	COMBO_INCENDIARY: {
		# ... 原有字段 ...
		"icon": "🔥",
		"icon_tex": "res://assets/ui/combo_icons/incendiary.png",  # 新增
		# ...
	},
	COMBO_EMP: {
		"icon": "⚡",
		"icon_tex": "res://assets/ui/combo_icons/emp.png",
	},
	COMBO_NANO: {
		"icon": "🧬",
		"icon_tex": "res://assets/ui/combo_icons/nano.png",
	},
	COMBO_LASER: {
		"icon": "✨",
		"icon_tex": "res://assets/ui/combo_icons/laser.png",
	},
	COMBO_RECON: {
		"icon": "🎯",
		"icon_tex": "res://assets/ui/combo_icons/recon.png",
	},
	COMBO_CHEM: {
		"icon": "☠",
		"icon_tex": "res://assets/ui/combo_icons/chem.png",
	},
}

## 获取套路图标纹理（不存在则返回 null）
static func get_combo_icon_texture(combo_id: String) -> Texture2D:
	var def := COMBOS.get(combo_id, {})
	var path := String(def.get("icon_tex", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)
```

`combo_status_strip.gd` 的 `_make_combo_icon_button` 中改为用 TextureButton 显示图标（有纹理时用图，无纹理时回退 emoji 文字）：

```gdscript
func _make_combo_icon_button(def: Dictionary) -> Button:
	var btn := Button.new()
	# ...
	var tex := ComboTactics.get_combo_icon_texture(combo_id)
	if tex != null:
		var tex_btn := TextureButton.new()
		tex_btn.texture_normal = tex
		tex_btn.texture_hover = tex
		tex_btn.custom_minimum_size = Vector2(44, 36)
		btn.add_child(tex_btn)
		btn.text = ""  # 清除文字，用纹理
	else:
		btn.text = def.get("icon", "❓")
	# ...
```

---

## 资源需求清单

以下资源**不在代码实现范围内**，需美术/程序配合生成：

| 资源路径 | 尺寸 | 说明 |
|---------|------|------|
| `assets/ui/combo_icons/incendiary.png` | 44×36 | 燃烧链图标（火焰） |
| `assets/ui/combo_icons/emp.png` | 44×36 | 电磁链图标（闪电） |
| `assets/ui/combo_icons/nano.png` | 44×36 | 纳米场图标（六边形） |
| `assets/ui/combo_icons/laser.png` | 44×36 | 光束链图标（十字光） |
| `assets/ui/combo_icons/recon.png` | 44×36 | 侦察链图标（靶心） |
| `assets/ui/combo_icons/chem.png` | 44×36 | 化学场图标（骷髅） |

> 如无美术资源，代码已做回退（emoji 文字），不影响功能。

---

## 实现顺序（推荐）

```
第1步  P0: vfx_impact_factory 新增浓度场/横幅方法
第2步  P0: combo_field_state 加 field_changed 信号
第3步  P0: Battlefield.gd 订阅信号 + 绘制浓度场
第4步  P0: combo_engine 加横幅触发
第5步  P1: vfx_impact_factory 加光束/弱点/雷达 VFX
第6步  P1: bullet.gd 加光束分裂/反射 VFX 调用
第7步  P1: module_effect_handler 加弱点/雷达 VFX 调用
第8步  P1: combo_engine 加扩散波纹 VFX 调用
第9步  P1: 新建 combo_status_strip + 注册到 main.tscn
第10步 P2: dot_vfx_manager 加动态 aura
第11步 P2: combo_tactics 加 icon_tex 字段
```

---

## 性能注意

1. **浓度场 Polygon2D**：每 0.5s 重建 1 次（非每帧），2 个 polygon，开销可忽略
2. **横幅 Tween**：生命周期短（~2s），自动 queue_free，不常驻
3. **弱点/雷达 VFX**：每个单位最多 1 个 Line2D + 1 个 Polygon2D，战斗单位数 ≤ 20，总开销 < 50 个额外节点
4. **DOT aura**：4 个 DOT × 1 个附加节点 = 4 个额外 Polygon2D/Line2D，原有脉动已存在
5. **状态条**：每 0.5s 轮询一次 combo_engine，非每帧

---

## 预期效果

| 套路 | 优化前 | 优化后 |
|------|--------|--------|
| 🔥 助燃燃烧链 | 橙色 shockwave + 静态 DOT | +火焰旋转环 + 化学爆炸波纹 + 单卡/全队横幅 |
| ⚡ 电磁脉冲链 | 紫色电弧 + 静态 DOT | +EMP 电弧闪烁 + 反射波纹 + 横幅 |
| 🧬 纳米浓度场 | 青色 shockwave + 静态 DOT | **+战场青色光晕区域** + 六边形脉冲 DOT + 传染波纹 |
| ✨ 光束谐振链 | 粉色 shockwave（无分裂/反射视觉） | **+次级激光射线 + 反射弧线** + 谐振环（目标头顶） |
| 🎯 侦察链式 | 无雷达/弱点视觉 | **+蓝色旋转扫描圈 + 红色 X 十字** + 横幅 |
| ☠ 化学污染场 | 绿色 shockwave + 静态 DOT | **+战场绿色毒雾区域** + 毒液下沉环 + 爆炸扩散波纹 |

**核心提升**：
1. **浓度场可视化** → 玩家能"看到铺场效果"，策略正反馈即时
2. **激活横幅** → 组合技触发的"哇"时刻，成就感明确
3. **光束分裂/反射 VFX** → 解决最大的逻辑-视觉断层
4. **弱点 X 十字 + 雷达圈** → 狙击手"就是现在！"的时机感
5. **状态条** → 战前/战中策略规划工具
