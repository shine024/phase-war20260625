# 成长面板（Growth Panel）审计报告与修复计划

> 审计日期：2026-06-11
> 审计范围：`scenes/ui/growth_panel.gd` + `growth_panel.tscn` + `mod_slot_item.tscn/.gd`
> 参考标准：`docs/成长面板_预览.html` v3

---

## 一、当前已知已修复问题（历史记录）

| # | 问题 | 状态 | 来源 |
|---|------|------|------|
| 1 | 打开即死机（@onready + preload 死锁） | ✅ 已修复 | CRASH_FIX.md |
| 2 | 无法关闭（缺 CloseBtn + ESC） | ✅ 已修复 | CRASH_FIX.md |
| 3 | 面板尺寸超出 1280x720 | ✅ 已修复 | FIX_HISTORY.md |
| 4 | 缺少 ScrollContainer | ✅ 已修复 | FIX_HISTORY.md |

---

## 二、现存问题清单

### 🔴 严重 / 功能性问题

#### P1: `currency_labels` 数组从未初始化 → Footer 资源永远不显示
- **文件**：`growth_panel.gd` L55、L447-L466
- **现象**：`_ready()` 中从未给 `currency_labels` 赋值（数组始终为空），`_refresh_footer()` 第 448 行 `if currency_labels.size() >= 4:` 永远为 false，Footer 的 4 个货币标签永远不更新
- **根因**：`.tscn` 中 Footer 下有 `F_C1`~`F_C4` 四个 Label 节点，但 `growth_panel.gd` 没有在 `_ready()` 中用 `get_node_or_null` 获取它们并加入 `currency_labels` 数组
- **修复**：在 `_ready()` 添加：
  ```gdscript
  currency_labels = [
      get_node_or_null("%F_C1"),
      get_node_or_null("%F_C2"),
      get_node_or_null("%F_C3"),
      get_node_or_null("%F_C4"),
  ]
  ```
  但 **tscn 中这 4 个节点没有 `unique_name_in_owner = true`**，所以 `%` 引用会失败。需同时修复 tscn 中 `F_C1`~`F_C4` 的 `unique_name_in_owner` 标记，或用绝对路径 `get_node_or_null("RootVBox/DetailHBox/DetailCol/DetailFooter/FooterHBox/CurrencyInfo/F_C1")` 引用。

#### P2: 星级区 `next_cost` 变量作用域错误 → 潜在崩溃
- **文件**：`growth_panel.gd` L333 + L337
- **现象**：`_refresh_star_section()` 中，`next_cost` 在 `if star_xp_text:` 块内声明（L333），但在 `if star_cost_text:` 块（L337）中使用。如果 `star_xp_text` 为 null，`next_cost` 不存在，L337 会报 `next_cost not declared` 错误
- **修复**：将 `var next_cost` 声明移到函数顶部或 `if star_cost_text:` 块内单独获取

#### P3: GridBody 用 `Container` + `HBoxContainer` + `VBoxContainer` 而非 2x2 GridContainer
- **文件**：`growth_panel.tscn` L209-L217
- **现象**：HTML 预览用的是 CSS `grid-template-columns: 1fr 1fr; grid-template-rows: 1fr 1fr`（真正 2x2 等分网格），但 Godot 实际用的是 `GridBody > GridHBox > GridVBox`（普通 VBox 垂直排列），**4 个区块不会自动排成 2 列**，而是全部纵向堆叠
- **影响**：星级强化、卡牌强化、MOD、进化 4 个区块全部竖排，无法实现 HTML 预览的 2x2 布局效果，内容超出 480px 高度
- **修复**：将 `GridBody` 改为 `GridContainer(columns=2)` 或使用两个 `HBoxContainer` 包裹，实现真正的 2x2 等分

#### P4: "保存"按钮功能占位，实际无保存逻辑
- **文件**：`growth_panel.gd` L120-L123
- **现象**：`_on_apply_pressed()` 仅打印日志和发信号，没有实际保存星级升级/强化/MOD变更的代码
- **修复**：需对接 BlueprintManager/BasicResourceManager 的实际保存逻辑

#### P5: 星级 XP 数据硬编码
- **文件**：`growth_panel.gd` L335
- **现象**：`star_xp_text.text = "1,200 / 2,000 晶体"` 是写死的假数据，标注了"待接入实际 XP 数据"
- **修复**：从 BasicResourceManager 或 BlueprintManager 获取真实 XP 进度

#### P6: 进化需求条件大部分硬编码/假数据
- **文件**：`growth_panel.gd` L395-L409
- **现象**：`素材情报 ≥ 2/2` 硬编码为 `✓`，`合金 500` 硬编码为 `✗`，没有查询实际条件
- **修复**：接入 `evolution_path_registry.gd` 的真实条件数据

---

### 🟡 中等 / 视觉问题

#### V1: 左侧卡牌列表项样式与 HTML 预览差距大
- **文件**：`growth_panel.gd` L155-L181 (`refresh_card_list`)
- **现象**：
  - HTML 预览：每个列表项有两行（名称 + 星星/等级 meta 行），选中项有蓝色边框高亮
  - 实际代码：只有单个 `Button`（单行文本），没有星星行，没有选中高亮效果
  - 卡牌 ID 截取逻辑 `card.card_id.to_upper().substr(0, mini(10, card.card_id.length()))` 显示的是 ID 而非友好名称（HTML 预览显示的是中文名）
- **修复**：改为双行布局（VBox），增加选中状态样式

#### V2: 头像区域只显示 `?` 文本
- **文件**：`growth_panel.tscn` L123（PortraitIcon text="?"）
- **现象**：`growth_panel.gd` 没有任何代码更新 Portrait 区域（图标、边框等）。HTML 预览中显示 `⚔️` 图标
- **修复**：`_refresh_header()` 中应设置 PortraitIcon 的文本和样式

#### V3: 区块图标（★、⬆、⚙、⟐）没有样式包裹
- **文件**：`growth_panel.tscn` + 对比 HTML 预览
- **现象**：HTML 预览中每个 section-icon 有圆角背景色块（gold/green/cyan/orange 色系），Godot 中只是纯文本 Label
- **修复**：给每个图标添加 StyleBoxFlat 背景或改用 TextureRect

#### V4: MOD 空槽位缺少占位符
- **文件**：`growth_panel.gd` L370-L387
- **现象**：只生成已填充的 MOD 槽位（最多 filled 个），不生成空槽位。HTML 预览中有 6 个空槽（`+` 占位）。代码中虽然有 `child.name != "PlaceholderSlot"` 的保留逻辑，但 tscn 中没有名为 `PlaceholderSlot` 的子节点
- **修复**：循环 9 次生成全部 9 个槽位，空位用 `set_mod({})` 或显示 `+` 占位

#### V5: 属性卡缺少左侧彩色边框
- **文件**：`growth_panel.tscn` AtkCard/DefCard/HpCard/MiscCard
- **现象**：HTML 预览中 4 个属性卡有 `border-left: 2px solid red/blue/green/cyan`，但 tscn 中 PanelContainer 没有设置对应的 StyleBoxFlat
- **修复**：给每个 PanelContainer 添加带 `border_width_left = 2` 的 StyleBoxFlat

#### V6: 属性卡缺少强化增量显示（▲+N）
- **文件**：`growth_panel.gd` L355-L362
- **现象**：HTML 预览中每行有绿色 `▲+8` 增量标注，当前代码只显示最终数值
- **修复**：`_get_enhanced_stats()` 同时返回 base 值和增量，显示时追加 `▲+N`

#### V7: 进化区块 Arrow 用纯文本 `-->` 而非箭头符号
- **文件**：`growth_panel.tscn`（EvoArrow text=`"-->"`)
- **现象**：HTML 预览用 `→` Unicode 箭头，tscn 用 `-->`
- **修复**：改为 `→` (`\u2192`)

#### V8: 进化条件格式与 HTML 预览不一致
- **文件**：`growth_panel.gd` L395-L409
- **现象**：HTML 预览用 `·` 分隔单行格式，代码用 `\n` 换行多行格式
- **修复**：改为单行格式 `"✓ 素材情报 ≥ 2/2 · ✗ 战力 ≥ 800 (420) · ..."`

#### V9: `CardListTitle` 使用 margin 常量做 padding（错误用法）
- **文件**：`growth_panel.tscn` L49-52
- **现象**：`theme_override_constants/margin_left = 12` 等是 PanelContainer 的内边距属性，但 `CardListTitle` 是 `Label` 类型，这些属性对 Label 无效
- **修复**：将 `CardListTitle` 包裹在 MarginContainer 中，或改用 `theme_override_constants/spacing` 等适用于 Label 的属性

---

### 🟢 轻微 / 改进建议

#### M1: `_get_tag_stylebox()` 每次调用都 `new StyleBoxFlat`
- **文件**：`growth_panel.gd` L490-L499
- **现象**：每刷新一次 Header 就创建多个 StyleBoxFlat 对象，增加 GC 压力
- **修复**：缓存为成员变量或预创建

#### M2: `refresh_card_list()` 每次清空重建所有按钮
- **文件**：`growth_panel.gd` L140-L141
- **现象**：`queue_free()` 所有子节点再重建，频繁调用时性能差
- **修复**：用对象池或仅更新差异项

#### M3: 保存按钮文本应为"应用保存"而非"保存"
- **文件**：`growth_panel.tscn` 最后一行
- **现象**：HTML 预览为"应用保存"，tscn 为"保存"
- **修复**：改按钮文字

#### M4: Footer "保存"按钮缺少样式
- **文件**：`growth_panel.tscn`（ApplyBtn）
- **现象**：HTML 预览中是蓝色渐变背景按钮，tscn 中是默认灰色按钮
- **修复**：添加 StyleBoxFlat 渐变背景

#### M5: 左栏底部资源（FooterRes1-3）只获取不显示
- **文件**：`growth_panel.gd` L189-L198
- **现象**：`refresh_card_list()` 中有获取资源数值的代码，但获取后立即 `break` 只处理了第一个卡牌，且没有实际更新 `footer_res_labels` 的文本
- **修复**：补充实际更新逻辑或改为汇总显示

#### M6: `GridBody` 内缺少区块间的分隔线
- **文件**：`growth_panel.tscn`
- **现象**：HTML 预览中 4 个区块间有 `1px solid rgba(74,144,217,0.06)` 分隔线，tscn 中没有
- **修复**：给各 PanelContainer 添加分隔线样式

---

## 三、修复优先级排序

| 优先级 | 编号 | 问题 | 影响 |
|--------|------|------|------|
| 🔴 P0 | P1 | Footer 货币永远不显示 | 功能缺失 |
| 🔴 P0 | P2 | `next_cost` 变量作用域崩溃 | 潜在崩溃 |
| 🔴 P0 | P3 | 2x2 网格布局失败，全部竖排 | 核心布局错位 |
| 🔴 P1 | P5 | 星级 XP 硬编码假数据 | 显示虚假信息 |
| 🔴 P1 | P6 | 进化条件硬编码 | 显示虚假信息 |
| 🔴 P1 | P4 | 保存按钮无功能 | 核心功能缺失 |
| 🟡 P2 | V1 | 卡牌列表项样式差距大 | 视觉不完整 |
| 🟡 P2 | V4 | MOD 空槽位缺失 | 布局不完整 |
| 🟡 P2 | V5 | 属性卡缺少彩色边框 | 视觉与设计不符 |
| 🟡 P2 | V6 | 属性卡缺少增量显示 | 信息展示不足 |
| 🟡 P2 | V2 | 头像区域未更新 | 视觉不完整 |
| 🟡 P3 | V3 | 区块图标无背景色 | 视觉细节 |
| 🟡 P3 | V7 | 箭头符号不一致 | 视觉细节 |
| 🟡 P3 | V8 | 进化条件格式不一致 | 视觉细节 |
| 🟡 P3 | V9 | Label margin 无效 | 无实际影响 |
| 🟢 P4 | M1 | StyleBox 重复创建 | 性能 |
| 🟢 P4 | M2 | 卡牌列表重建性能 | 性能 |
| 🟢 P4 | M3 | 按钮文本不一致 | 视觉细节 |
| 🟢 P4 | M4 | 保存按钮缺样式 | 视觉 |
| 🟢 P4 | M5 | 底部资源不显示 | 功能不完整 |
| 🟢 P4 | M6 | 缺少区块分隔线 | 视觉细节 |

---

## 四、修复计划（按执行顺序）

### 第一批：关键崩溃与布局修复（必须先做）
1. **[P2]** 修复 `next_cost` 变量作用域 → 移到函数顶部
2. **[P1]** 修复 `currency_labels` 初始化 + tscn 中 `F_C1`~`F_C4` 添加 `unique_name_in_owner`
3. **[P3]** 重构 `GridBody` 为真正的 2x2 布局（GridContainer columns=2 或双 HBoxContainer）

### 第二批：数据显示修复
4. **[P5]** 接入真实 XP 数据，替换硬编码 `"1,200 / 2,000 晶体"`
5. **[P6]** 接入 `evolution_path_registry` 真实条件，替换硬编码进化需求
6. **[P4]** 实现保存按钮的实际保存逻辑（星级/强化变更写入 BlueprintManager）

### 第三批：视觉对齐 HTML 预览
7. **[V1]** 卡牌列表项改为双行布局（名称 + 星星/等级），添加选中高亮
8. **[V4]** MOD 网格始终生成 9 个槽位，空位显示 `+` 占位
9. **[V5]** 属性卡 PanelContainer 添加 `border_width_left = 2` 的 StyleBoxFlat（红/蓝/绿/青）
10. **[V6]** 属性值追加 `▲+N` 增量显示
11. **[V2]** `_refresh_header()` 中更新 PortraitIcon 文本和边框颜色

### 第四批：视觉细节打磨
12. **[V3]** 区块图标添加圆角背景色块
13. **[V7]** EvoArrow 文本 `-->` → `→`
14. **[V8]** 进化条件改为单行 `·` 分隔格式
15. **[M3]** 保存按钮文本 → "应用保存"
16. **[M4]** 保存按钮添加蓝色渐变背景
17. **[M5]** 左栏底部资源标签实际更新
18. **[M6]** 区块间添加细分隔线

### 第五批：性能优化（可选）
19. **[M1]** `_get_tag_stylebox()` 改为缓存成员变量
20. **[M2]** 卡牌列表改为差异更新而非全量重建

---

## 五、涉及文件清单

| 文件 | 修改类型 |
|------|----------|
| `scenes/ui/growth_panel.gd` | 重点修改（所有逻辑修复） |
| `scenes/ui/growth_panel.tscn` | 重点修改（布局重构 + 节点标记） |
| `scenes/ui/mod_slot_item.gd` | 可能微调（空槽位显示逻辑） |
| `scenes/ui/mod_slot_item.tscn` | 可能无需改动 |
