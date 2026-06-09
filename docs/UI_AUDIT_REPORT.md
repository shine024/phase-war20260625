# Phase War UI 检查报告

**检查日期**: 2026-06-09
**分辨率**: 1280x720
**检查范围**: 所有UI面板和界面元素

---

## 一、严重问题（需立即修复）

### 1. 面板尺寸超出屏幕

#### 1.1 卡牌强化面板 (card_enhancement_panel.tscn)
**问题**: custom_minimum_size = Vector2(1200, 640)
- 对于1280x720屏幕来说太大，几乎占满整个屏幕
- 可能导致内容被裁剪或难以操作
- 建议改为 Vector2(1000, 580) 或使用百分比布局

**优先级**: 🔴 高

#### 1.2 成就面板 (achievement_panel.tscn)
**问题**: 硬编码偏移量
```gdscript
offset_left = 100.0
offset_top = 50.0
offset_right = 700.0
offset_bottom = 650.0
```
- 固定位置和尺寸，可能导致在不同分辨率下出现问题
- 建议改为居中布局或使用 anchors

**优先级**: 🔴 高

#### 1.3 关卡选择面板 (level_select_panel.tscn)
**问题**: 固定尺寸 900x700
```gdscript
offset_left = -450.0
offset_top = -350.0
offset_right = 450.0
offset_bottom = 350.0
```
- 对于1280x720屏幕来说太大
- 建议改为 Vector2(800, 600) 或更小

**优先级**: 🔴 高

---

## 二、中等问题（影响用户体验）

### 2.1 字体大小不一致

**问题**: 各面板使用不同的字体大小标准，缺乏统一性

| 面板 | 标题字体 | 正文字体 | 小字体 |
|------|---------|---------|--------|
| backpack_panel | 15px | - | - |
| card_enhancement_panel | 22px | 14-18px | - |
| evolution_panel | 32px | 18-24px | - |
| faction_panel | 17px | - | 13px |
| affix_panel | 17px | 12-14px | 10px |
| achievement_panel | 16px | - | 12px |
| leaderboard_panel | 17px | - | 11px |
| battle_hud | - | 12-14px | 10px |

**建议标准**:
- 大标题: 24-28px
- 标题: 16-18px
- 正文: 13-14px
- 小字: 10-12px

**优先级**: 🟡 中

### 2.2 背包面板Grid列数过多

**问题**: backpack_panel.tscn 中 GridContainer columns = 17
- 对于1000px宽的面板，每列只有约50px
- 卡牌格子太小，可能影响视觉效果和交互
- 建议改为 columns = 10-12

**优先级**: 🟡 中

### 2.3 改造面板缺乏样式

**问题**: modification_panel.tscn
- 布局非常简单，缺乏样式定义
- 没有背景、边框等视觉元素
- 与其他面板风格不统一
- 建议添加 StyleBoxFlat 样式

**优先级**: 🟡 中

---

## 三、轻微问题（可优化）

### 3.1 文本换行处理

**问题**: affix_panel.tscn 中 EmptyHint 文本
```gdscript
text = "该卡暂无词条
蓝图升星可获得新词条"
```
- 使用硬编码换行符，可能在不同屏幕尺寸下显示异常
- 建议使用 autowrap_mode

**优先级**: 🟢 低

### 3.2 掉落物品面板缺少尺寸

**问题**: drops_inventory_panel.tscn
- 没有定义 custom_minimum_size
- 可能导致显示异常或布局不稳定
- 建议添加合适的尺寸定义

**优先级**: 🟢 低

### 3.3 情报中心面板尺寸

**问题**: intelligence_hub_panel.tscn
- custom_minimum_size = Vector2(920, 620)
- 相对较大但可接受
- 建议考虑缩小到 Vector2(840, 580)

**优先级**: 🟢 低

---

## 四、设计一致性建议

### 4.1 统一命名规范
- 关闭按钮: 统一使用 "关闭" 或 "✕"
- 标题格式: 统一使用 "图标 + 标题" 格式

### 4.2 统一颜色主题
建议使用以下颜色方案：
- 主色调: Color(0, 0.941, 1) - 青色
- 强调色: Color(0.545, 0.361, 0.965) - 紫色
- 成功色: Color(0.2, 0.8, 0.4) - 绿色
- 警告色: Color(1, 0.843, 0) - 金色
- 危险色: Color(1, 0.4, 0.4) - 红色

### 4.3 统一间距标准
- 面板边距: 12-20px
- 元素间距: 6-10px
- 小间距: 4-6px

---

## 五、修复状态

### 第一批（紧急）- ✅ 已完成
1. ✅ card_enhancement_panel.tscn - 缩小尺寸: 1200x640 → 1000x580
2. ✅ achievement_panel.tscn - 修复偏移量: 改用居中布局，600x500
3. ✅ level_select_panel.tscn - 缩小尺寸: 900x700 → 760x580

### 第二批（重要）- ✅ 已完成
4. ✅ backpack_panel.tscn - 减少Grid列数: 17 → 12
5. ✅ modification_panel.tscn - 添加样式: 添加完整样式定义和主题
6. ✅ 创建UI设计规范文档

### 第三批（优化）- ✅ 已完成
7. ✅ affix_panel.tscn - 修复文本换行: 移除硬编码换行符
8. ✅ drops_inventory_panel.tscn - 添加尺寸: 800x520，居中布局
9. ✅ intelligence_hub_panel.tscn - 缩小尺寸: 920x620 → 840x580

---

## 六、测试建议

### 测试分辨率
- 1280x720 (基准)
- 1920x1080
- 1366x768

### 测试场景
- 打开所有UI面板，检查是否有超出屏幕的内容
- 检查文字是否清晰可读
- 检查按钮是否易于点击
- 检查滚动是否流畅
- 检查面板切换是否正常

---

**报告结束**
