# 🔍 拖拽问题诊断指南

## 问题描述
从背包（上方）无法拖拽卡牌到相位仪（下方）的格子中。

## 已添加的调试信息

现在运行游戏时，控制台会显示以下调试信息：

### 1. 拖拽开始时（backpack_card_item.gd）
```
[BackpackCardItem] ========== 开始拖拽 ==========
[BackpackCardItem] 卡牌: [卡牌名称]
[BackpackCardItem] 全局位置: [位置]
[BackpackCardItem] 鼠标位置: [位置]
[BackpackCardItem] 拖拽预览已设置
```

### 2. 拖拽穿透设置（backpack_panel.gd）
```
[BackpackPanel] ========== 拖拽开始 ==========
[BackpackPanel] 拖拽卡牌: [卡牌名称]
[BackpackPanel] BackpackOverlay 设置为 PASS
[BackpackPanel] BackpackVBox 设置为 PASS
```

### 3. 拖拽到达槽位时（phase_slot.gd）
```
[PhaseSlot] _can_drop_data 被调用，槽位索引: [索引]
[PhaseSlot] 卡牌: [卡牌名称], 类型: [类型]
[PhaseSlot] 槽位颜色: [颜色], 可以装备: [true/false]
```

## 诊断步骤

### 步骤1：检查拖拽是否开始

1. 运行游戏
2. 打开背包（按 B 键）
3. 在卡牌上按下鼠标左键并开始拖动
4. 查看控制台

**预期输出**：
- ✅ 应该看到 `[BackpackCardItem] ========== 开始拖拽 ==========`
- ✅ 应该看到 `[BackpackPanel] ========== 拖拽开始 ==========`

**如果没有输出**：
- ❌ 说明拖拽没有正确初始化
- 检查：卡牌是否正确设置了 `_get_drag_data` 方法

### 步骤2：检查拖拽是否到达槽位

1. 继续拖动卡牌到下方的相位仪槽位
2. 查看控制台

**预期输出**：
- ✅ 应该看到 `[PhaseSlot] _can_drop_data 被调用`

**如果没有输出**：
- ❌ 说明拖拽事件没有到达相位仪槽位
- 可能原因：
  1. BackpackOverlay 仍然在拦截事件
  2. CanvasLayer 层级问题
  3. 其他控件覆盖了槽位

### 步骤3：手动检查控件层级

在游戏中按 F12 打开控制台，输入：

```gdscript
# 检查 BackpackOverlay
var overlay = get_node("/root/PopupLayer/BackpackOverlay")
print("BackpackOverlay 存在: ", overlay != null)
print("BackpackOverlay 可见: ", overlay.visible if overlay else "N/A")
print("BackpackOverlay mouse_filter: ", overlay.mouse_filter if overlay else "N/A")

# 检查 BottomInstrumentBar
var bar = get_node("/root/BottomInstrumentBar")
print("BottomInstrumentBar 存在: ", bar != null)
print("BottomInstrumentBar 可见: ", bar.visible if bar else "N/A")

# 检查相位仪面板
var phase_panel = get_node("/root/BottomInstrumentBar/PhaseInstrumentPanel")
print("PhaseInstrumentPanel 存在: ", phase_panel != null)
print("PhaseInstrumentPanel 子节点数: ", phase_panel.get_child_count() if phase_panel else 0)
```

## 可能的解决方案

### 方案1：检查是否有其他覆盖层

问题可能是其他 Overlay 控件也在拦截拖拽。在控制台输入：

```gdscript
# 列出所有可见的 Overlay
var popup_layer = get_node("/root/PopupLayer")
for child in popup_layer.get_children():
    if child is Control and child.visible:
        print("可见的 Overlay: ", child.name, " mouse_filter: ", child.mouse_filter)
```

### 方案2：使用 force_drag 替代系统拖拽

如果系统拖拽不工作，可以尝试使用 `force_drag`：

**文件**：`scenes/ui/backpack_card_item.gd`

```gdscript
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb = event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
            if card == null:
                return
            # 使用 force_drag
            var data = {"card": card}
            var preview = Label.new()
            preview.text = card.display_name
            force_drag(data, preview)
```

### 方案3：简化场景结构

最可靠的解决方案是调整 UI 结构：

1. 将 BackpackPanel 和 BottomInstrumentBar 放在同一个 CanvasLayer 中
2. 确保 BackpackPanel 不使用全屏覆盖
3. 使用适当的布局，让背包只占据需要的空间

### 方案4：使用全局拖拽管理器

创建一个全局的拖拽管理器来协调跨 CanvasLayer 的拖拽。

## 临时测试方案

为了快速测试，你可以：

1. **隐藏 BackpackOverlay**：
   在控制台输入：
   ```gdscript
   get_node("/root/PopupLayer/BackpackOverlay").visible = false
   ```
   然后尝试拖拽。如果这样可以工作，说明确实是层级问题。

2. **检查槽位是否接收输入**：
   在控制台输入：
   ```gdscript
   var slots = get_node("/root/BottomInstrumentBar/PhaseInstrumentPanel").get_children()
   for slot in slots:
       if slot.has_method("set_mouse_filter"):
           slot.set_mouse_filter(Control.MOUSE_FILTER_STOP)
           print("槽位 ", slot.name, " mouse_filter 设置为 STOP")
   ```

## 下一步

请运行游戏并尝试拖拽，然后将控制台的输出发给我。我会根据输出提供更具体的解决方案。

## 关键信息

如果你看到：
- ✅ `[PhaseSlot] _can_drop_data 被调用` → 拖拽系统工作正常，问题在于槽位验证
- ❌ 没有看到 `[PhaseSlot] _can_drop_data 被调用` → 拖拽事件没有到达槽位，需要修复层级或事件传递

请告诉我你看到了什么！
