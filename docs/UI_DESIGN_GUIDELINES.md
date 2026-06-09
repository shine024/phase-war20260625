# Phase War UI 设计规范

**版本**: v1.0
**创建日期**: 2026-06-09
**基准分辨率**: 1280x720

---

## 一、面板尺寸标准

### 1.1 大型面板（全屏或接近全屏）
用于复杂功能，如强化、进化等：

| 面板类型 | 推荐尺寸 | 最大尺寸 |
|---------|---------|---------|
| 强化面板 | 1000x580 | 1100x620 |
| 进化面板 | 全屏 | - |
| 改装面板 | 960x600 | 1000x640 |

### 1.2 中型面板（内容面板）
用于常规功能：

| 面板类型 | 推荐尺寸 | 最大尺寸 |
|---------|---------|---------|
| 背包面板 | 1000x520 | 1100x580 |
| 情报中心 | 840x580 | 900x620 |
| 掉落物品 | 800x520 | 880x580 |
| 阵营面板 | 720x480 | 800x540 |

### 1.3 小型面板（信息面板）
用于简单功能：

| 面板类型 | 推荐尺寸 | 最大尺寸 |
|---------|---------|---------|
| 词缀面板 | 520x420 | 580x480 |
| 成就面板 | 600x500 | 680x560 |
| 排行榜 | 560x500 | 620x560 |

---

## 二、字体大小标准

### 2.1 字体大小分级

| 级别 | 大小 | 用途 | 示例 |
|-----|------|------|------|
| 超大标题 | 28-32px | 主标题 | 进化系统主标题 |
| 大标题 | 20-24px | 区块标题 | 基础信息 |
| 标题 | 16-18px | 面板标题 | 背包、强化 |
| 正文大 | 14-15px | 重要内容 | 卡牌名称 |
| 正文 | 13px | 普通内容 | 描述文字 |
| 小字 | 11-12px | 辅助信息 | 提示文字 |
| 微小字 | 10px | 次要信息 | 时间显示 |

### 2.2 字体粗细

- 标题: 可加粗
- 正文: 常规
- 辅助文字: 细体或常规

---

## 三、颜色主题

### 3.1 主色调

```gdscript
# 主色调 - 青色
PRIMARY = Color(0, 0.941, 1, 1)

# 强调色 - 紫色
ACCENT = Color(0.545, 0.361, 0.965, 1)

# 成功色 - 绿色
SUCCESS = Color(0.2, 0.8, 0.4, 1)

# 警告色 - 金色
WARNING = Color(1, 0.843, 0, 1)

# 危险色 - 红色
DANGER = Color(1, 0.4, 0.4, 1)
```

### 3.2 背景色

```gdscript
# 深色背景
BG_DARK = Color(0.04, 0.06, 0.12, 0.97)

# 中等背景
BG_MEDIUM = Color(0.06, 0.10, 0.18, 0.8)

# 浅色背景
BG_LIGHT = Color(0.03, 0.05, 0.10, 0.6)
```

### 3.3 文本色

```gdscript
# 主文本
TEXT_PRIMARY = Color(0.8, 0.85, 1, 1)

# 次要文本
TEXT_SECONDARY = Color(0.6, 0.65, 0.8, 1)

# 禁用文本
TEXT_DISABLED = Color(0.4, 0.45, 0.55, 1)
```

---

## 四、间距标准

### 4.1 外边距

```gdscript
# 面板外边距
MARGIN_PANEL_LARGE = 20px
MARGIN_PANEL_MEDIUM = 16px
MARGIN_PANEL_SMALL = 12px

# 内容边距
MARGIN_CONTENT = 15px
MARGIN_CONTENT_TIGHT = 10px
```

### 4.2 内边距

```gdscript
# 容器间距
SPACING_CONTAINER = 8px
SPACING_CONTAINER_TIGHT = 6px

# 元素间距
SPACING_ELEMENT = 10px
SPACING_ELEMENT_LARGE = 12px
SPACING_ELEMENT_SMALL = 4px
```

---

## 五、圆角标准

```gdscript
# 大圆角 - 面板
CORNER_LARGE = 8px

# 中圆角 - 区块
CORNER_MEDIUM = 5px

# 小圆角 - 按钮/标签
CORNER_SMALL = 4px
```

---

## 六、边框标准

### 6.1 边框宽度

```gdscript
# 主边框
BORDER_MAIN = 2px

# 次要边框
BORDER_MINOR = 1px
```

### 6.2 阴影

```gdscript
# 轻阴影
SHADOW_LIGHT = 6px

# 标准阴影
SHADOW_NORMAL = 8px

# 重阴影
SHADOW_HEAVY = 10px
```

---

## 七、按钮样式

### 7.1 按钮尺寸

```gdscript
# 大按钮
BUTTON_LARGE = Vector2(100, 50)

# 标准按钮
BUTTON_NORMAL = Vector2(80, 36)

# 小按钮
BUTTON_SMALL = Vector2(60, 28)

# 图标按钮
BUTTON_ICON = Vector2(32, 32)
```

### 7.2 按钮状态

- **正常**: 背景透明度 0.12
- **悬停**: 背景透明度 0.25
- **按下**: 边框加粗到 2px
- **禁用**: 透明度降低到 0.5

---

## 八、Grid布局标准

### 8.1 列数标准

| 面板宽度 | 推荐列数 | 每列宽度 |
|---------|---------|---------|
| 800-900 | 6列 | ~120px |
| 900-1000 | 8列 | ~110px |
| 1000-1100 | 10列 | ~95px |
| 1100+ | 12列 | ~85px |

### 8.2 间距标准

```gdscript
# Grid间距
GRID_H_SPACING = 8px
GRID_V_SPACING = 8px

# 紧凑Grid
GRID_H_SPACING_TIGHT = 6px
GRID_V_SPACING_TIGHT = 6px
```

---

## 九、文本处理

### 9.1 自动换行

```gdscript
# 内容文本
autowrap_mode = 3  # Word Smart

# 简短文本
autowrap_mode = 2  # Word
```

### 9.2 文本裁剪

```gdscript
# 需要裁剪的标签
clip_text = true

# 多行显示
clip_text = false
autowrap_mode = 3
```

---

## 十、面板布局模式

### 10.1 居中面板（推荐）

```gdscript
[node name="Panel" type="PanelContainer"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -400.0  # 宽度的一半
offset_top = -250.0   # 高度的一半
offset_right = 400.0
offset_bottom = 250.0
grow_horizontal = 2
grow_vertical = 2
```

### 10.2 全屏面板

```gdscript
[node name="Panel" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
```

---

## 十一、命名规范

### 11.1 节点命名

- 面板: `XxxPanel`
- 容器: `XxxContainer` / `XxxVBox` / `XxxHBox`
- 标签: `XxxLabel`
- 按钮: `XxxButton`
- 滚动: `XxxScroll`

### 11.2 样式命名

- `StyleBoxFlat_bg` - 背景
- `StyleBoxFlat_panel` - 面板
- `StyleBoxFlat_btn_normal` - 按钮正常状态
- `StyleBoxFlat_btn_hover` - 按钮悬停状态

---

## 十二、可访问性

### 12.1 对比度

- 文本与背景对比度 ≥ 4.5:1
- 大文本与背景对比度 ≥ 3:1

### 12.2 交互区域

- 按钮最小点击区域: 44x44px
- 重要操作按钮建议 ≥ 60x36px

---

**文档结束**
