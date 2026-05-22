# 🔧 背包到相位仪拖拽 - 最终修复方案

## 问题诊断

从背包（上方）无法拖拽卡牌到相位仪（下方）的格子中。

**根本原因**：
- `BackpackOverlay` 覆盖整个屏幕（`anchors_preset = 15`）
- 即使设置了 `mouse_filter`，拖拽事件仍可能被覆盖层拦截
- CanvasLayer(layer=10) 与主场景(layer=0) 之间的跨层级拖拽存在限制

## 最终解决方案

### 实施的修改

#### 1. backpack_card_item.gd
- 添加 `drag_started` 和 `drag_ended` 信号
- 在 `_get_drag_data()` 中发出 `drag_started` 信号
- 在 `_notification(NOTIFICATION_DRAG_END)` 中发出 `drag_ended` 信号

#### 2. backpack_panel.gd
- 在 `_add_card_item()` 中连接拖拽信号
- 实现拖拽穿透逻辑：
  ```gdscript
  func _on_card_drag_started(card: CardResource):
      # 设置 BackpackOverlay 不拦截鼠标
      overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

      # 隐藏 TopSpacer 和 BottomSpacer
      top_spacer.visible = false
      bottom_spacer.visible = false
  ```

#### 3. phase_slot.gd
- 添加槽位类型检查（绿色槽位 vs 黄色槽位）
- 添加视觉反馈（绿色=可装备，红色=不可装备）
- 添加调试输出

## 测试步骤

### 1. 启动游戏并打开背包
按 **B 键**打开背包面板

### 2. 查看控制台输出

拖拽开始时应该看到：
```
[BackpackCardItem] ========== 开始拖拽 ==========
[BackpackCardItem] 卡牌: [卡牌名称]
[BackpackPanel] ========== 拖拽开始 ==========
[BackpackPanel] TopSpacer 已隐藏
[BackpackPanel] BottomSpacer 已隐藏
[BackpackPanel] BackpackOverlay mouse_filter = IGNORE
```

拖拽到槽位时应该看到：
```
[PhaseSlot] _can_drop_data 被调用，槽位索引: [索引]
[PhaseSlot] 卡牌: [卡牌名称], 类型: [类型]
[PhaseSlot] 槽位颜色: [颜色], 可以装备: [true/false]
```

### 3. 测试不同类型的卡牌

#### 能量卡 → 黄色槽位（最后几个格子）
- ✅ 应该显示绿色边框
- ✅ 释放鼠标后成功装备

#### 能量卡 → 绿色槽位（前面的格子）
- ❌ 应该显示红色边框
- ❌ 不会装备

#### 平台卡 → 绿色槽位
- ✅ 应该显示绿色边框
- ✅ 成功装备

## 仍然无法拖拽？

如果上述方案仍然不工作，请按以下步骤诊断：

### 步骤1：确认拖拽事件触发

拖动卡牌时，控制台是否显示：
- ✅ `[BackpackCardItem] ========== 开始拖拽 ==========`

**如果否**：卡牌项的拖拽未初始化

### 步骤2：确认覆盖层设置

在控制台输入（F12）：
```gdscript
var overlay = get_node("/root/PopupLayer/BackpackOverlay")
print("Overlay visible: ", overlay.visible)
print("Overlay mouse_filter: ", overlay.mouse_filter)
```

### 步骤3：手动测试覆盖层

在控制台输入：
```gdscript
# 手动隐藏间隔
get_node("/root/PopupLayer/BackpackOverlay/BackpackVBox/TopSpacer").visible = false
get_node("/root/PopupLayer/BackpackOverlay/BackpackVBox/BottomSpacer").visible = false
get_node("/root/PopupLayer/BackpackOverlay").mouse_filter = 2
```

然后尝试拖拽。如果这样可以工作，说明信号连接有问题。

### 步骤4：检查 CanvasLayer 层级

在控制台输入：
```gdscript
# 检查 BottomInstrumentBar 是否可见
var bar = get_node("/root/BottomInstrumentBar")
print("BottomInstrumentBar visible: ", bar.visible if bar else "null")

# 检查槽位
var panel = get_node("/root/BottomInstrumentBar/PhaseInstrumentPanel")
print("PhaseInstrumentPanel 子节点数: ", panel.get_child_count() if panel else 0)
```

## 备选方案：自定义拖拽系统

如果 Godot 内置拖拽系统在跨 CanvasLayer 时确实有bug，我已创建了完全自定义的拖拽实现：

**文件**：`scenes/ui/custom_drag_card_item.gd`

使用方法：
1. 修改 `backpack_panel.gd` 中的 CardItemScene 引用
2. 将 `preload("res://scenes/ui/backpack_card_item.tscn")` 改为 `preload("res://scenes/ui/custom_drag_card_item.tscn")`

自定义拖拽的特点：
- 完全手动控制拖拽过程
- 直接隐藏 BackpackOverlay
- 手动检测槽位位置
- 不依赖 Godot 的内置拖拽系统

## 需要的反馈

请告诉我：

1. **控制台是否显示 `[PhaseSlot] _can_drop_data 被调用`？**
   - ✅ 是 → 拖拽系统工作，问题在槽位验证
   - ❌ 否 → 拖拽事件未到达槽位

2. **隐藏 TopSpacer/BottomSpacer 后是否可以拖拽？**
   - ✅ 是 → 说明是间隔区域的问题
   - ❌ 否 → 需要使用自定义拖拽系统

3. **控制台有什么错误信息吗？**

根据你的反馈，我会提供最终的解决方案！
