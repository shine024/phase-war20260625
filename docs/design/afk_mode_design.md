# 挂机模式 - 功能设计文档

> 版本: 1.0
> 创建日期: 2025-01-XX
> 状态: 已确认

---

## 一、功能概述

在游戏主界面底部功能栏（存档按钮旁）新增"挂机"按钮，点击后打开挂机面板。挂机模式下，系统会自动按照玩家预设的关卡序列进行战斗，无需人工干预。

**核心特性：**
- 自动重复战斗（循环模式 / 推图模式）
- 自动从相位仪读取已装备卡牌进行部署
- 战场缩略图实时预览
- 奖励累计结算
- 挂机期间锁定其他操作

---

## 二、UI设计

### 2.1 挂机面板布局

```
┌──────────────────────────────────────────────┐
│                                              │
│  ┌────────────────────────────────────────┐  │  ← 30%高度
│  │                                        │  │
│  │         战场缩略图 (SubViewport)        │  │
│  │         只显示中间一行战场画面           │  │
│  │                                        │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────┐  ┌────┐  ┌────┐  ┌────┐            │
│  │ ①  │  │ ②  │  │ ③  │  │ ④  │  ← 4个圆圈节点
│  │关 2│  │关 5│  │关 8│  │ 空 │  ← 显示关联关卡号
│  └────┘  └────┘  └────┘  └────┘            │
│                                              │
│  ─────────────────────────────────           │
│                                              │
│  [●循环]  [○推图]  ← 模式选择（互斥）        │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │           ▶ 开始挂机                    │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  状态: 待机中 | 已关联: 0/4关                 │
│                                              │
└──────────────────────────────────────────────┘
```

### 2.2 关卡选择器弹窗

```
┌────────────────────┐
│ 选择关卡           │
│                    │
│ [搜索框]           │
│                    │
│ ┌────────────────┐ │
│ │ 第1关          │ │
│ │ 第2关          │ │
│ │ ...            │ │
│ │ 第50关 ★       │ │ ← 当前关卡标记
│ │ ...            │ │
│ │ 第100关        │ │
│ └────────────────┘ │
│                    │
│  [取消]  [确定]    │
└────────────────────┘
```

---

## 三、核心数据结构

### 3.1 AFKModeManager - 挂机管理器

```gdscript
class_name AFKModeManager
extends RefCounted

## 挂机模式
enum Mode {
    CYCLE,    ## 循环模式：按4个slot关联的关卡顺序循环
    PUSH      ## 推图模式：从第1关开始逐关推进，直到失败
}

## 挂机状态
enum State {
    IDLE,     ## 待机
    RUNNING,  ## 运行中
    FAILED    ## 失败停止
}

## 配置
var mode: Mode = Mode.CYCLE
var slots: Array[int] = [0, 0, 0, 0]  # 4个slot关联的关卡号，0=未关联
var current_slot_index: int = 0       # 当前打到第几个slot
var current_level: int = 1            # 推图模式下的当前关卡

## 状态
var state: State = State.IDLE
var is_running: bool = false

## 统计
var total_wins: int = 0
var total_losses: int = 0
var accumulated_rewards: Dictionary = {}

## 信号
signal afk_started
signal afk_stopped
signal afk_paused
signal level_completed(level: int, rewards: Dictionary)
signal level_failed(level: int)
signal state_changed(new_state: State)
```

### 3.2 AFKPanel - 面板UI脚本

```gdscript
class_name AFKPanel
extends Control

## 引用
@onready var sub_viewport_container: SubViewportContainer
@onready var slot_buttons: Array[Button]  # 4个关卡选择按钮
@onready var mode_cycle_btn: Button       # 循环模式按钮
@onready var mode_push_btn: Button        # 推图模式按钮
@onready var start_btn: Button            # 开始挂机
@onready var stop_btn: Button             # 停止挂机
@onready var status_label: Label          # 状态显示
@onready var mini_battlefield: Node2D     # 缩略图战场

## 方法
func on_slot_button_clicked(slot_index: int) -> void
func on_mode_selected(mode: AFKModeManager.Mode) -> void
func on_start_afk() -> void
func on_stop_afk() -> void
func update_status(text: String) -> void
func update_slot_highlight(slot_index: int, level: int) -> void
```

---

## 四、功能流程

### 4.1 循环模式流程

```
玩家点击"▶开始挂机"
        │
        ▼
检查：至少关联1个关卡？
        │
   ┌────┴────┐
   │         │
  否        是
   │         │
   │         ▼
   │   从slot[0]开始
   │         │
   │         ▼
   │   加载关联关卡
   │         │
   │         ▼
   │   自动部署卡牌（从左到右）
   │         │
   │         ▼
   │   开始战斗
   │         │
   │         ▼
   │   战斗胜利？
   │     ┌───┴───┐
   │    是       否
   │     │       │
   │     ▼       ▼
   │ 累计奖励  total_losses++
   │  slot_index++  │
   │     │       │
   │     ▼       │
   │ 还有剩余slot？│
   │  ┌──┴──┐    │
   │  是    否    │
   │   │     │    │
   │   ▼     ▼    │
   │ 加载    循环  │
   │ 下一关  回slot[0]│
   │   │     │    │
   │   └─────┘    │
   │         │    │
   │         └────┘
   │         │
   ▼         ▼
 继续循环...  等待下次挂机
```

### 4.2 推图模式流程

```
玩家点击"▶开始挂机"
        │
        ▼
从第1关开始
        │
        ▼
加载关卡
        │
        ▼
自动部署卡牌（从左到右）
        │
        ▼
开始战斗
        │
        ▼
战斗胜利？
      ┌─┴─┐
     是   否
      │   │
      ▼   ▼
  current_level++  停止挂机
      │     │      回到第1关
      ▼     │
  继续下一关│
      │     │
      └─────┘
```

### 4.3 失败处理

| 模式 | 失败后行为 |
|------|-----------|
| 循环模式 | 停止挂机，弹窗提示"第X关失败"，显示累计奖励 |
| 推图模式 | 停止挂机，弹窗提示"第X关失败"，显示累计奖励 |

---

## 五、自动部署逻辑

### 5.1 卡牌来源

挂机时自动从**相位仪中已装备的卡牌**读取部署列表，不使用手动部署。

```gdscript
# 从 PhaseInstrumentManager 读取已装备卡牌
var pim = get_node_or_null("/root/PhaseInstrumentManager")
if not pim:
    return

# 获取已装备的平台卡（战斗卡）
var loadouts = pim.get_loadouts()

# 遍历部署
for loadout in loadouts:
    var platform = loadout.get("platform")
    if platform:
        _deploy_card_to_slot(platform)
```

### 5.2 部署方式

- 卡牌从左到右依次部署到战场格子
- 部署速度：每0.5秒部署一张（可配置）
- 部署完成后自动开始战斗

---

## 六、战场缩略图实现

### 6.1 技术方案

复用主场景的战场渲染管线，但创建独立的 SubViewport 并裁剪显示范围。

```
挂机面板
└── SubViewportContainer (高度占面板30%)
    └── SubViewport (尺寸 1280×180)
        └── Battlefield
            ├── PlayerUnits (显示)
            ├── EnemyUnits (显示)
            ├── BattleSlotGrid (显示)
            └── 顶部UI (隐藏)
                ├── PlayerSpawnHUD (隐藏)
                ├── EnemySpawnHUD (隐藏)
                └── BattleTopStatusBar (隐藏)
```

### 6.2 实现要点

1. 创建独立的 SubViewport，尺寸设为 `Vector2i(1280, 180)`
2. 将战场中的顶部UI（PlayerSpawnHUD、EnemySpawnHUD、BattleTopStatusBar）隐藏
3. 只保留战场中间一行的单位战斗画面
4. 缩略图实时更新，与主战场同步

---

## 七、文件清单

### 7.1 新建文件

| 文件路径 | 说明 |
|---------|------|
| `scenes/ui/afk_panel.tscn` | 挂机面板场景 |
| `scenes/ui/afk_panel.gd` | 挂机面板UI脚本 |
| `scenes/ui/afk_level_selector.tscn` | 关卡选择器弹窗场景 |
| `scenes/ui/afk_level_selector.gd` | 关卡选择器脚本 |
| `scripts/systems/afk_mode_manager.gd` | 挂机逻辑管理器 |

### 7.2 修改文件

| 文件路径 | 修改内容 |
|---------|---------|
| `scenes/ui/bottom_function_bar.tscn` | 在RightSection末尾添加"挂机"按钮 |
| `scenes/ui/bottom_function_bar.gd` | 添加 `btn_afk_pressed` 信号和按钮构建 |
| `scenes/main.tscn` | 添加 `afk_overlay` 弹窗结构 |
| `scenes/main.gd` | 添加 `afk_overlay` 引用、`_on_afk_pressed()`、开关面板逻辑 |

---

## 八、与现有系统集成点

| 集成点 | 使用方式 |
|--------|---------|
| `PhaseInstrumentManager` | 读取 `get_loadouts()` 获取已装备卡牌用于自动部署 |
| `GameManager` | 设置关卡号 (`current_level`)、获取战斗结果 |
| `BattleManager` | 启动/停止战斗，复用战斗流程 |
| `MainReward` | 复用奖励结算逻辑 (`show_battle_result`) |
| `SignalBus` | 监听 `battle_started`、`battle_ended` 信号 |
| `SaveManager` | 挂机状态不存档（仅运行时） |

---

## 九、实施计划

### 阶段一：基础框架（预估 1-2 小时）

- [ ] 创建 `afk_panel.tscn` 和 `afk_panel.gd`
- [ ] 在 `bottom_function_bar` 添加挂机按钮
- [ ] 在 `main.gd` 添加面板开关逻辑
- [ ] 在 `main.tscn` 添加 afk_overlay 结构

### 阶段二：核心逻辑（预估 2-3 小时）

- [ ] 创建 `afk_mode_manager.gd`
- [ ] 实现关卡选择器 (`afk_level_selector.tscn/gd`)
- [ ] 实现循环模式基本流程
- [ ] 实现推图模式基本流程
- [ ] 实现失败处理和奖励结算

### 阶段三：自动部署与缩略图（预估 2-3 小时）

- [ ] 实现从相位仪读取卡牌并自动部署
- [ ] 实现战场缩略图（裁剪显示）
- [ ] 联调测试
- [ ] 修复bug

---

## 十、注意事项

1. **挂机期间锁定操作**：开启挂机后，禁止打开背包、商店等其他面板
2. **ESC键处理**：挂机期间ESC键应停止挂机而非关闭面板
3. **战斗暂停**：挂机期间 `tree.paused` 应保持 false
4. **网络/离线**：挂机模式为纯本地运行，不涉及网络同步
5. **性能考虑**：缩略图 SubViewport 渲染频率可适当降低（如每秒5帧）
6. **存档安全**：挂机过程中不自动存档，避免存档冲突

---

## 附录：UI配色建议

| 元素 | 颜色 |
|------|------|
| 面板背景 | `Color(0.03, 0.05, 0.10, 0.98)` |
| 边框 | `Color(0, 0.65, 1, 0.2)` |
| 未选中节点 | `Color(0.5, 0.5, 0.6, 0.8)` |
| 选中节点 | `Color(0, 0.94, 0.7, 1.0)` |
| 开始按钮 | `Color(0, 0.94, 0.7, 1.0)` |
| 停止按钮 | `Color(1, 0.3, 0.3, 1.0)` |
| 状态文字 | `Color(0.75, 0.85, 1.0, 0.9)` |
