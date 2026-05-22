# Phase War 全面性能提升计划

日期: 2026-04-17 | 引擎: Godot 4.5 | 目标平台: Mobile + Desktop

---

## 一、现状评估

### 已完成的优化
- 对象池系统（子弹、伤害数字）
- 空间分区网格（索敌 O(1)）
- 光环管理器（Timer 驱动）
- UI 延迟加载框架
- Manager 延迟加载框架（仅框架，未全面实施）
- 预加载战斗资源

### 当前 Autoload 清单（共 16 个）

| #  | 名称                    | 路径                                | 可延迟 |
|----|--------------------------|--------------------------------------|---------|
| 1  | SignalBus               | scripts/signal_bus.gd               | 核心    |
| 2  | BattleInputState        | scripts/battle_input_state.gd       | 核心    |
| 3  | DebugLog                | managers/debug_log_manager.gd       | 可选    |
| 4  | EnergyManager           | managers/energy_manager.gd          | 核心    |
| 5  | PhaseInstrumentManager  | managers/phase_instrument_manager.gd| 核心    |
| 6  | BattleManager           | managers/battle/battle_manager.gd   | 核心    |
| 7  | GameManager             | managers/game_manager.gd            | 核心    |
| 8  | BlueprintManager        | managers/blueprint_manager.gd       | 核心    |
| 9  | SaveManager             | managers/save_manager.gd            | 核心    |
| 10 | PhaseLawManager         | managers/phase_law_manager.gd       | 可选    |
| 11 | BasicResourceManager    | managers/basic_resource_manager.gd  | 核心    |
| 12 | AudioManager            | managers/audio_manager.gd           | 可选    |
| 13 | DropManager             | managers/drop_manager.gd            | 可选    |
| 14 | ObjectPoolManager       | managers/object_pool.gd             | 核心    |
| 15 | UILazyLoader            | managers/ui_lazy_loader.gd          | 框架    |
| 16 | ManagerLazyLoader       | managers/manager_lazy_loader.gd     | 框架    |

### 当前性能瓶颈总览

| 级别 | 问题                                      | 预计影响                   | 位置                      |
|------|-------------------------------------------|----------------------------|---------------------------|
| P0   | 112张背景图未压缩（~156MB）               | 内存占用高，移动端可能OOM  | assets/backgrounds/       |
| P0   | 伤害数字每个创建9个Label节点              | 战斗时节点爆炸             | damage_number_display.gd  |
| P0   | 蜂群敌人死亡每次new CPUParticles2D+Timer  | 大量GC压力                 | swarm_enemy_controller.gd |
| P1   | construct_unit每帧字符串卡牌能力查找      | CPU浪费                    | construct_unit.gd L490-510|
| P1   | 光环系统match块与AuraManager双重处理      | 重复计算                   | construct_unit.gd L505-515|
| P1   | enemy_unit每次攻击查字典get_config()      | 字符串hash开销             | enemy_unit.gd             |
| P2   | visual_effects_manager无对象池            | VFX节点暴增                | visual_effects_manager.gd |
| P2   | project.godot缺少窗口拉伸/帧率配置        | 多设备适配差               | project.godot             |
| P2   | 8个重复背景文件                           | 资源浪费                   | assets/backgrounds/       |
| P2   | 静止单位仍每帧更新空间网格                | 不必要的C++调用            | construct_unit.gd         |
| P3   | 多处load()应改为preload()                 | 微小I/O开销                | 5个文件                   |
| P3   | 死代码未清理                              | 维护负担                   | 5个文件                   |
| P3   | save_utils.gd废弃但仍被3个管理器引用      | 运行时bug                  | scripts/save_utils.gd     |

---

## 二、阶段一：紧急修复（P0） 预计 +8-23% FPS

### 1.1 伤害数字系统重构

- **文件**: `scenes/effects/damage_number_display.gd`（222行）
- **问题**: 每个伤害数字创建 1主Label + 8轮廓Label = 9个节点。20+次命中/秒 = 180+ 节点/秒
- **方案**: 改用单一Label + LabelSettings.outline_size

**修改前:**
```gdscript
func _create_damage_label() -> void:
    _label = Label.new()
    _label.add_theme_font_size_override("font_size", _damage_styles[damage_type]["font_size"])
    _label.add_theme_color_override("font_color", _damage_styles[damage_type]["color"])
    _label.position = Vector2(-30, -20)
    _label.z_index = 10
    add_child(_label)
    _outline = []
    var outline_offsets = [
        Vector2(-1,-1), Vector2(0,-1), Vector2(1,-1),
        Vector2(-1, 0),              Vector2(1, 0),
        Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)
    ]
    for offset in outline_offsets:
        var outline = Label.new()
        outline.add_theme_color_override("font_color", _damage_styles[damage_type]["outline_color"])
        outline.position = Vector2(-30, -20) + offset
        outline.z_index = 9
        add_child(outline)
        _outline.append(outline)
```

**修改后:**
```gdscript
func _create_damage_label() -> void:
    var style: Dictionary = _damage_styles.get(damage_type, _damage_styles["normal"])
    var settings = LabelSettings.new()
    settings.font_size = style["font_size"]
    settings.font_color = style["color"]
    settings.outline_size = 3
    settings.outline_color = style["outline_color"]
    _label = Label.new()
    _label.label_settings = settings
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.position = Vector2(-30, -20)
    _label.z_index = 10
    add_child(_label)
```

**同步修改:** `_setup_animation()` 和 `_process()` 中对 `_outline` 的操作全部移除；`damage_number_pool_manager.gd` 的 `reset_pool_object()` 简化

> **收益**: 节点 91%（-88%），FPS +5-10% | **工作量**: 2h

### 1.2 蜂群死亡特效对象池化

- **文件**: `scenes/units/swarm_enemy_controller.gd` L58-82
- **问题**: 每死亡 = CPUParticles2D.new() + get_tree().create_timer() = 2个新节点
- **方案**: 预分配20个CPUParticles2D对象池 + 1个共享Timer回收

**关键改动:**
```gdscript
var _death_fx_pool: Array[CPUParticles2D] = []
var _death_fx_active: Array[CPUParticles2D] = []
const MAX_DEATH_FX_POOL: int = 20
var _death_fx_timer: Timer = null

func _ready() -> void:
    # ... 现有代码 ...
    _init_death_fx_pool()  # 预分配20个CPUParticles2D

func _spawn_death_fx(at: Vector2) -> void:
    var p: CPUParticles2D
    if _death_fx_pool.size() > 0:
        p = _death_fx_pool.pop_back()
    else:
        return  # 池耗尽时跳过（或回收最旧的）
    p.global_position = at
    p.visible = true
    p.emitting = true
    p.restart()
    _death_fx_active.append(p)

# 用共享Timer回收，不再每个死亡创建Timer
func _回收死亡特效() -> void:
    for p in _death_fx_active:
        if not is_instance_valid(p) or not p.emitting:
            _death_fx_active.erase(p)
            p.emitting = false
            p.visible = false
            _death_fx_pool.append(p)
```

> **收益**: 节点创建 100%（-100%），GC压力 -95%，FPS +3-8% | **工作量**: 1.5h

### 1.3 背景纹理批量压缩

- **目录**: `assets/backgrounds/`（112 PNG，~156MB）
- **问题**: 所有 compress/mode=0（未压缩），mipmap未启用
- **操作**: Godot编辑器 → 全选PNG → Import面板 → Compress Mode=VRAM Compressed → Mipmap勾选 → Reimport
- **清理重复**: bg_level_1~8.png（与bg_level_01~08重复），bg_01~03.png、bg_default.png

> **收益**: VRAM 156MB→30-50MB（-70%） | **工作量**: 0.5h

---

## 三、阶段二：战斗核心优化（P1） 预计 +6-12% FPS

### 2.1 construct_unit 卡牌能力缓存

- **文件**: `scenes/units/construct_unit.gd` L488-518
- **问题**: 每帧 `CardAbilityManager.has_platform_card(stats.platform_card_id, "xxx")` 4-8次字符串hash

**修改方案:**
```gdscript
# 新增缓存变量
var _has_regen_frame: bool = false
var _has_abrams_mk2: bool = false
var _has_storm_rider: bool = false
var _has_repair_fortress: bool = false

# setup() 末尾初始化
_has_regen_frame = CardAbilityManager.has_platform_card(stats.platform_card_id, "regen_frame")
_has_abrams_mk2 = CardAbilityManager.has_platform_card(stats.platform_card_id, "abrams_mk2")
_has_storm_rider = CardAbilityManager.has_platform_card(stats.platform_card_id, "storm_rider")
_has_repair_fortress = CardAbilityManager.has_platform_card(stats.platform_card_id, "drop_repair_fortress")

# _physics_process() 中直接判断布尔值
if target == null:
    if _has_regen_frame:
        if CardAbilityManager.apply_regen_frame_regen(self, delta) > 0.0:
            _update_hp_bar()
```

> **收益**: 10单位60fps = 2400-4800次/秒→0，FPS +3-5% | **工作量**: 1h

### 2.2 光环系统去重

- **文件**: `scenes/units/construct_unit.gd` L505-515
- **问题**: `_physics_process()` 中 match 块与 AuraManager Timer 双重处理
- **方案**: 注释掉 match 块，完全委托给 AuraManager（需先确认覆盖所有4种光环类型）

> **收益**: FPS +1-3% | **工作量**: 0.5h

### 2.3 enemy_unit 配置缓存

- **文件**: `scenes/units/enemy_unit.gd` `_do_attack()`
- **方案**: `setup()` 中 `_cached_archetype_config = EnemyArchetypes.get_config(archetype_id)`

> **收益**: FPS +1-2% | **工作量**: 0.5h

### 2.4 静止单位跳过空间网格更新

- **文件**: `scenes/units/construct_unit.gd`
- **方案**: `if velocity != Vector2.ZERO: _update_in_spatial_grid()`

> **收益**: FPS +1-2% | **工作量**: 0.3h

---

## 四、阶段三：视觉与资源优化（P2） 预计 +2-8% FPS

### 3.1 VFX 对象池化

- **文件**: `scenes/effects/visual_effects_manager.gd`（457行）
- **方案**: ColorRect粒子→CPUParticles2D（-95%节点），预构建场景+对象池

> **收益**: FPS +2-5% | **工作量**: 3h

### 3.2 project.godot 性能配置

```ini
[display]
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
textures/vram_compression/import_etc2_astc=true

[application]
run/max_fps=60
```

> **工作量**: 0.2h

### 3.3 load() → preload() 批量修复

| 文件                            | 行号     | 修改                      |
|---------------------------------|----------|---------------------------|
| managers/law_shard_manager.gd   | 33,65,79 | load() → 顶部 const preload() |
| managers/game_manager.gd        | 554,578  | load() → 使用已有GC常量     |
| managers/blueprint_manager.gd   | 618      | load() → preload()          |
| managers/affix_manager.gd       | 130      | load() → preload()          |
| managers/card_ability_manager.gd| 340      | load() → 顶部 const preload()|

> **工作量**: 0.5h

### 3.4 EnergyManager 优化

- `start_battle()` 加 `set_process(true)`，`end_battle()` 加 `set_process(false)`

> **工作量**: 0.1h

---

## 五、阶段四：架构清理（P3）

### 4.1 死代码删除（~2200行）

| 文件                                      | 行数 | 引用 |
|-------------------------------------------|------|------|
| managers/synthesis_manager.gd             | ~300 | 0    |
| managers/blueprint_analysis_manager.gd    | ~400 | 0    |
| managers/_archive/save_manager_enhanced.gd| 738  | 0    |
| scripts/_archive/ui_beautifier_enhanced.gd| 802  | 0    |
| scenes/units/bullet.gd.bak                | -    | 0    |

> **工作量**: 0.5h

### 4.2 save_utils.gd Bug修复

- 被 character_manager / leaderboard_manager / story_manager preload，函数可能不存在

> **工作量**: 1h

### 4.3 Autoload 精简

- 当前16个→目标核心10个，延迟加载: DebugLog / PhaseLawManager / AudioManager / DropManager
- 收益: 启动 -500ms，内存 -10MB

> **工作量**: 4h

### 4.4 大文件拆分建议

| 文件                                    | 行数 | 建议         |
|-----------------------------------------|------|-------------|
| data/enemy_phase_masters.gd             | 2176 | 按相位拆分   |
| data/enemy_phase_equipment.gd           | 1428 | 按类型拆分   |
| data/achievement_definitions_extended.gd| 916  | 数据→JSON    |
| data/default_cards.gd                   | 889  | 数据→JSON    |
| data/quest_definitions.gd               | 750  | 数据→JSON    |

---

## 六、收益汇总

| 阶段   | 优化项          | FPS提升      | 工作量   |
|--------|----------------|-------------|----------|
| 一     | 伤害数字重构    | +5-10%      | 2h       |
| 一     | 蜂群死亡对象池  | +3-8%       | 1.5h     |
| 一     | 背景纹理压缩    | +0-5%       | 0.5h     |
| 二     | 卡牌能力缓存    | +3-5%       | 1h       |
| 二     | 光环去重        | +1-3%       | 0.5h     |
| 二     | 敌人配置缓存    | +1-2%       | 0.5h     |
| 二     | 静止单位优化    | +1-2%       | 0.3h     |
| 三     | VFX对象池       | +2-5%       | 3h       |
| 三     | project配置     | +0-3%       | 0.2h     |
| 三     | load→preload    | 微小        | 0.5h     |
| 四     | 架构清理        | -500ms启动  | 5.5h     |
| **总计**|                | **+16-43% FPS** | **~15.6h** |

| 指标             | 优化前  | 优化后    | 提升     |
|------------------|---------|-----------|----------|
| FPS（50单位）    | 30-40   | 45-60     | +50%     |
| FPS（蜂群波次）  | 20-30   | 35-50     | +75%     |
| 背景内存         | ~156MB  | ~30-50MB  | -70%     |
| 节点创建/秒      | ~2000+  | ~600      | -70%     |
| 启动时间         | ~3s+    | ~2.5s     | -17%     |

---

## 七、实施路线图

### Week 1: 阶段一
- Day 1 (2h): 伤害数字重构 + 测试
- Day 2 (1.5h): 蜂群死亡对象池 + 测试
- Day 3 (0.5h): 背景纹理压缩 + 清理重复

### Week 2: 阶段二
- Day 1 (1.5h): construct_unit缓存 + 光环去重
- Day 2 (1h): enemy_unit缓存 + 静止单位 + 基准测试

### Week 3: 阶段三+四
- Day 1-2 (3.5h): VFX + 配置 + preload修复
- Day 3-4 (5h): 死代码 + Autoload精简
- Day 5: 全面验收

---

## 八、验收标准

- [ ] 50单位战斗稳定 50+ FPS
- [ ] 蜂群波次 FPS > 40
- [ ] 内存峰值 < 200MB（移动端 < 150MB）
- [ ] 30分钟连续运行无内存泄漏
- [ ] 无新增崩溃或回归bug
- [ ] 所有关卡背景正常显示

---

## 九、风险与回滚

| 风险                         | 回滚方案                       |
|------------------------------|-------------------------------|
| LabelSettings不支持动态字号   | 恢复9 Label方案               |
| 光环移除后效果消失           | 恢复match块                   |
| 背景压缩后画质下降           | 重新导入原始纹理              |
| 蜂群对象池特效重叠           | 恢复即时创建                  |
| Autoload延迟加载空引用       | 恢复即时加载                  |

---

*文档版本: 1.0 | 创建者: DeepV Code AI | 最后更新: 2026-04-17*
