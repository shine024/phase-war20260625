# 成长面板(Growth Panel)修复记录 - v6.1

## 问题描述
每次打开成长面板就死机，且布局混乱、内容超出屏幕。

## 修复阶段

### 阶段一：崩溃修复
**根因**：
1. `@onready` 初始化时机问题 — 节点引用为 null
2. `preload` 依赖死锁 — `mod_slot_item.tscn` 加载阻塞
3. 无法关闭面板 — 缺少 CloseBtn 信号连接和 ESC 处理

**修复**：
- 移除 `@onready`，改用 `_ready()` 中 `get_node_or_null()` 安全查找
- 保留 `preload`（ModSlotScene），所有引用都空值检查
- 添加 CloseBtn 和 main.gd ESC 支持

### 阶段二：布局修复
**问题**：面板高度超出 1280x720 屏幕，底部内容被截断

**修复**：
- 添加 ScrollContainer
- FlowContainer → HBoxContainer
- 面板尺寸缩小

### 阶段三：2x2 网格布局重构（最终版）
**参考**：`docs/成长面板_预览.html` v3

**布局结构**：

```
GrowthPanel (1080x480)
├── RootVBox
│   ├── DetailHBox (左右分栏)
│   │   ├── CardListPanel (200px 宽)
│   │   │   └── CardListVBox
│   │   │       ├── CardListTitle ("已解锁卡牌")
│   │   │       ├── CardListScroll → CardListContainer (可滚动)
│   │   │       └── CardListFooter (资源标签)
│   │   ├── VSeparator
│   │   └── DetailCol (flex)
│   │       ├── DetailHeader (flex row)
│   │       │   ├── Portrait (48x48)
│   │       │   ├── HeaderInfo
│   │       │   │   ├── UnitName (CARD_ID)
│   │       │   │   ├── SubtitleHBox (名称 + EraBadge)
│   │       │   │   └── TagsContainer (标签)
│   │       │   ├── StarDisplay (竖向)
│   │       │   │   ├── StarsRow (5星)
│   │       │   │   └── StarCountLabel (X/5)
│   │       │   └── CloseBtn
│   │       ├── GridBody (2x2 网格)
│   │       │   ├── StarSection (星级强化)
│   │       │   │   └── StarHead (图标★ + 标题 + 等级)
│   │       │   │       → StarStars (迷你星)
│   │       │   │       → StarProgress (进度条)
│   │       │   │       → StarXpText
│   │       │   │       → StarCostText
│   │       │   ├── EnhanceSection (卡牌强化)
│   │       │   │   └── EnhanceHead (图标⬆ + 标题 + 等级)
│   │       │   │       → EnhanceProgress (进度条)
│   │       │   │       → StatsGrid (2x2 属性卡)
│   │       │   │           ├── AtkValues (攻击力)
│   │       │   │           ├── DefValues (防御力)
│   │       │   │           ├── HpValues (生命值)
│   │       │   │           └── MiscValues (战斗参数)
│   │       │   ├── ModSection (MOD模块)
│   │       │   │   └── ModHead (图标⚙ + 标题 + 计数)
│   │       │   │       → ModGrid (3x3)
│   │       │   └── SectionEvo (进化路线)
│   │       │       └── EvoHead (图标⟐ + 标题 + 状态)
│   │       │           → EvoPath (当前 --> 目标)
│   │       │               ├── EvoCurrentIcon/Name/Lv
│   │       │               ├── EvoArrow
│   │       │               └── EvoTargetIcon/Name/Lv
│   │       │           → EvoRequirements
│   │       └── DetailFooter
│   │           └── FooterHBox
│   │               ├── CurrencyInfo (4个资源)
│   │               └── ApplyBtn ("保存")
```

**关键设计决策**：
1. 面板尺寸 1080x480（更宽更矮），适配 1280x720 屏幕
2. 左侧 200px 卡牌列表 + 右侧详情（flex 1）
3. 右侧用 GridContainer 2x2 网格（4区块各占 1/4）
4. 每个区块头部：图标 + 标题 + 等级(右对齐)
5. 属性格采用 2x2 网格（攻击力/防御力/生命值/战斗参数）
6. MOD 采用 3x3 网格
7. 进化路线采用横向布局（当前 → 目标）

## 文件变更

| 文件 | 状态 | 变更 |
|------|------|------|
| `scenes/ui/growth_panel.tscn` | 重写 | 2x2 网格布局，1080x480 |
| `scenes/ui/growth_panel.gd` | 重写 | 匹配新节点结构，新增 refresh_card_list |
| `docs/成长面板_预览.html` | 已有 | HTML 预览 v3（参考标准） |
| `docs/GROWTH_PANEL_FIX_HISTORY.md` | 更新 | 本文件 |

## 验证
- load_steps=2, ext_resource=1, 节点 98 个
- 51/51 关键节点全部存在
- 无新增 GDScript 语法错误
