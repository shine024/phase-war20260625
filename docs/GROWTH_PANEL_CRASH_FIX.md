# 成长面板（GrowthPanel）问题修复总结

## 问题描述

### 问题1：打开即死机
- 用户报告每次打开成长面板就死机/卡死

### 问题2：面板无法关闭
- 打开后没有关闭按钮
- ESC 键也无法关闭

### 问题3：面板尺寸超出屏幕
- 面板最小尺寸 860x920，但屏幕只有 1280x720
- 面板高度超出屏幕，导致无法完整查看

## 问题根因分析

### 问题1 根因：节点查找失败 + 预加载依赖

**a) 节点查找方式不当**
- 旧代码使用 `@onready var xxx = null` 声明 UI 引用，然后在 `_ready()` 中手动赋值
- 当 `growth_panel.tscn` 作为延迟加载面板被实例化时，如果某些节点使用 `%Name` 快捷引用但节点未设置 `unique_name_in_owner = true`，Godot 会在编译阶段解析引用失败，返回 null，导致后续 `_refresh_*` 方法访问 null 引用而死机

**b) 前置加载依赖**
- `growth_panel.tscn` 顶部 `preload` 了 `mod_slot_item.tscn`（`load_steps=3`）
- 当 mod_slot_item.tscn 存在依赖问题或加载失败时，整个 growth_panel 实例化会卡死

### 问题2 根因：缺少关闭机制

- **无关闭按钮**：`.tscn` 中完全没有 CloseBtn 节点
- **ESC 遗漏**：`_close_all_overlays()` 的 overlays 列表中缺少 `growth_overlay`

### 问题3 根因：面板尺寸设计不当

- `custom_minimum_size = Vector2(860, 920)` 超出 1280x720 屏幕高度
- 没有 ScrollContainer 包裹内容，超出部分无法滚动查看

## 修复内容

### 修复1：growth_panel.tscn 场景文件

#### a) 尺寸优化
- `custom_minimum_size` 从 860x920 改为 **820x680**（适配 1280x720 屏幕）
- Margin 内边距微调：14/10/14/10 → **12/8/12/8**

#### b) 添加滚动支持
- 在 VBox 外层包裹 `ScrollContainer`（layout_mode=2, 全方向扩展）
- 设置 `horizontal_scroll_mode = 2`（自动启用）
- 所有 VBox 子节点的 `parent=` 路径更新为 `Margin/ScrollContainer/VBox/...`

#### c) 添加关闭按钮
- 在 HeaderHBox 中添加 `CloseBtn`（Button 节点）
- 文字 "✕"，尺寸 32x28
- hover 颜色为霓虹青色，与项目主题一致
- HeaderHBox 排列顺序：Portrait → InfoVBox → CloseBtn
- alignment=2（右对齐），确保 CloseBtn 在最右侧

#### d) 移除 mod_slot 预加载
- `load_steps=3` → `load_steps=2`
- 移除 `ExtResource` 指向 mod_slot_item.tscn

### 修复2：growth_panel.gd 脚本

#### a) 添加关闭按钮信号连接
- 新增 `var close_btn: Button` 字段
- `_ready()` 中 `get_node_or_null("%CloseBtn")`
- 连接 `close_btn.pressed` → `_on_close_pressed()`

#### b) 新增关闭处理方法
```gdscript
func _on_close_pressed() -> void:
    print("[GrowthPanel] 关闭按钮按下")
    hide_panel()
```

### 修复3：main.gd

#### a) ESC 键支持
- `_close_all_overlays()` 的 overlays 列表中添加 `growth_overlay`
- 现在按 ESC 可以关闭成长面板

### 修复4：场景结构验证

- Godot `--check-only` 测试通过
- 所有节点 parent 路径正确
- 语法检查无新增错误

## 涉及文件变更

| 文件 | 变更类型 | 关键修复 |
|------|---------|---------|
| `scenes/ui/growth_panel.tscn` | 重写 | 滚动支持、关闭按钮、尺寸优化、路径更新 |
| `scenes/ui/growth_panel.gd` | 修改 | 关闭按钮信号连接 |
| `scenes/main.gd` | 修改 | ESC 键支持 growth_overlay |
| `scenes/main.tscn` | 修改 | GrowthOverlay 添加 mouse_filter=0 |
| `managers/ui_lazy_loader.gd` | 修改 | 实例化 null 检查 |

## 修复效果

1. **打开正常**：面板以 820x680 尺寸居中显示在屏幕中央
2. **完整可见**：内容超出时可滚动查看，无需担心高度超出屏幕
3. **关闭按钮**：右上角显示 ✕ 按钮，点击即关闭
4. **ESC 关闭**：按 ESC 键可关闭所有面板包括成长面板
5. **无崩溃**：节点查找均使用 `get_node_or_null()` + null 检查
