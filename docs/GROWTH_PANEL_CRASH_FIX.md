# 成长面板（GrowthPanel）死机问题修复总结

## 问题描述

用户报告：每次打开成长面板（Progression 按钮）就死机/卡死。

## 问题根因分析

成长面板存在 **多个层面的问题** 共同导致了打开时死机：

### 1. 节点查找失败（最关键）

**旧代码**使用 `@onready var xxx = null` 声明 UI 引用，然后在 `_ready()` 中手动赋值。但 `@onready` 在 `PanelContainer` 作为延迟加载的面板被实例化时，如果 `.tscn` 场景中某些节点使用 `%Name` 快捷引用但节点未设置 `unique_name_in_owner = true`，Godot 会在编译阶段尝试解析这些引用，如果找不到就会报错或返回 null，导致后续 `_refresh_*` 方法访问 null 引用而死机。

**修复**：改用 `get_node_or_null("%NodeName")` 在 `_ready()` 中显式查找所有节点，并增加了 null 检查。

### 2. `.tscn` 场景中的前置加载依赖

**旧代码**在 `growth_panel.tscn` 顶部 `preload` 了 `mod_slot_item.tscn`（`load_steps=3`，含 `ExtResource` 指向 `mod_slot_item.tscn`）。当 `mod_slot_item.tscn` 存在依赖问题或加载失败时，整个 `growth_panel` 实例化会卡死。

**修复**：
- 移除 `ExtResource` 预加载，改为 `load_steps=2`
- 在脚本中通过 `preload("res://scenes/ui/mod_slot_item.tscn")` 在运行时动态实例化
- `_refresh_mod_section()` 改用 `ModSlotScene.instantiate()` 而非 `duplicate()` 已有节点

### 3. 节点类型变更

**旧代码** `TagsContainer` 使用 `FlowContainer`，但 `growth_panel.gd` 中代码期望 `Control` 类型。Godot 4.x 中 `FlowContainer` 的子类操作可能导致布局异常。

**修复**：改为 `HBoxContainer`，类型与代码一致。

### 4. 缺少 null 保护

**旧代码** 的 `_refresh_star_section()` 和 `_refresh_evolution_section()` 没有对 `_selected_card` 进行 null 检查。当 `show_panel(null)` 被调用（从 `main.gd:319`）时，会直接访问 `null.enhance_level` 等属性而死机。

**修复**：在所有 `_refresh_*` 方法开头添加 `if not _selected_card: return`。

### 5. `Color` 缺少 Alpha 通道

**旧代码** 中部分 `theme_override_colors/font_color` 使用 3 色 `Color(1.0, 0.596, 0.0)`，Godot 4.x 期望 4 色 `Color(1.0, 0.596, 0.0, 1)`。

**修复**：补全所有 Color 的 alpha 通道。

### 6. main.gd 缺少 Growth 面板打开逻辑

**旧代码** `_open_overlay()` 中没有对 `panel_key == "growth"` 的特殊处理，导致打开成长面板时不会调用 `show_panel()`，面板虽然可见但不会刷新数据，可能触发其他问题。

**修复**：在 `_open_overlay()` 中添加 `elif panel_key == "growth"` 分支，调用 `gp.show_panel(null)`。

### 7. SubViewport 冻结冲突

**旧代码** `_freeze_subviewport_if_not_in_battle()` 对所有非战斗面板都冻结战场渲染。成长面板打开时如果战场 SubViewport 被冻结，可能导致渲染管线卡死。

**修复**：在 `_open_overlay()` 中排除 growth 面板，不冻结 SubViewport。

## 修复涉及的文件

| 文件 | 变更类型 | 关键修复内容 |
|------|---------|------------|
| `scenes/ui/growth_panel.tscn` | 重写 | 移除 mod_slot 预加载、更改 FlowContainer→HBoxContainer、添加 unique_name_in_owner、补全 Color alpha |
| `scenes/ui/growth_panel.gd` | 重写 | @onready→get_node_or_null、添加 null 检查、动态实例化 ModSlot、新增 mod_open_btn 处理 |
| `scenes/main.gd` | 修改 | 添加 growth 面板打开分支、添加 debug 日志、排除 growth 从 SubViewport 冻结 |
| `scenes/main.tscn` | 修改 | GrowthOverlay 添加 mouse_filter=0 |
| `managers/ui_lazy_loader.gd` | 修改 | 添加实例化 null 检查和调试日志 |

## Git 提交记录

| Commit | 文件 | 说明 |
|--------|------|------|
| `b91f244` | tscn + gd 多处 | 初步修复：移除 mod_slot 预加载、类型变更 |
| `bda3559` | .uid 文件 | UID 重生成 |
| `bec2d36` | tscn + gd + lazy_loader + main.tscn | 大规模重构：节点查找方式变更、null 检查 |
| `b9d8c31` | growth_panel.gd + main.gd | 最终修复：growth 面板打开逻辑、SubViewport 排除 |

## 验证建议

1. 在 Godot 编辑器中运行项目，点击 Progression/成长按钮确认面板正常打开
2. 反复打开/关闭面板确认无内存泄漏或卡死
3. 确认面板内星级、MOD、进化路线等数据正确显示
