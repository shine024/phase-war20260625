# Phase War UI 设计规范

**版本**: v2.0（v7.x 面板统一改造重写）
**创建日期**: 2026-06-09 · **重写日期**: 2026-08-15
**基准分辨率**: 1280x720

> **单一真源原则**：颜色/字号/间距/尺寸常量一律以 `resources/design_tokens.gd`（下称 DT）为准，
> StyleBox 一律经 `scripts/ui/panel_styles.gd`（下称 PS）工厂生成，面板外壳一律用
> `scenes/ui/components/panel_chrome.gd`（下称 PanelChrome）。
> 本文不再罗列具体色值——罗列会过期，代码里的常量不会。
> 视觉方向详见 `docs/界面一致性/design_06_visual_direction.html`（军事科幻 · 霓虹光晕 · 几何切割 · 冷色调）。

---

## 一、面板尺寸三档（DT.PANEL_SIZE_*）

| 档位 | 常量 | 尺寸 | 适用 |
|------|------|------|------|
| LARGE | `DT.PANEL_SIZE_LARGE` | 1180x640 | 养成四面板（强化/改造/进化/成长）、reinforcement |
| MEDIUM | `DT.PANEL_SIZE_MEDIUM` | 960x600 | 商店/任务/势力/领地图/情报/图鉴/排行榜 |
| SMALL | `DT.PANEL_SIZE_SMALL` | 840x580 | 掉落背包/成就等次级弹窗 |

- 设置等特殊紧凑面板可保留自定义尺寸（当前 settings 480x560），但必须挂 PanelChrome + 框架。
- **新面板禁止自造第五种宽度**；尺寸在 `_ready` 里 `custom_minimum_size = DT.PANEL_SIZE_X` 赋值（tscn 里的字面量仅作编辑器预览镜像）。

## 二、字号七档（DT.FONT_SIZE_*）

| 常量 | 值 | 用途 |
|------|----|------|
| `FONT_SIZE_XSMALL` | 10 | 角标/极次要信息 |
| `FONT_SIZE_SMALL` | 12 | 辅助信息/标签/次级正文 |
| `FONT_SIZE_BODY` | 14 | 普通正文/列表行标题 |
| `FONT_SIZE_MEDIUM` | 16 | 面板小节标题 |
| `FONT_SIZE_LARGE` | 20 | 面板主标题（PanelChrome 默认） |
| `FONT_SIZE_TITLE` | 32 | 大数字/特大标题 |
| `FONT_SIZE_HUGE` | 48 | 稀有场景（结算等） |

迁移映射（旧代码 → 档位）：7-11→XS、12/13→S、14/15→BODY、16/17→M、18/20/22→L、24/32→TITLE。

## 三、颜色体系

全部经 `DT.*` 常量取值，禁止新代码写 `Color(0.x, ...)` 字面量（数据表 fallback 色除外）：

- **语义色**：`COLOR_TEXT_BRIGHT`（正文）/ `COLOR_TEXT_MID`（次要）/ `COLOR_TEXT_DIM`（暗文本）/ `COLOR_TEXT_FAINT`（角标）
- **面板中性色**：`COLOR_VOID`（深空黑底）/ `COLOR_PANEL_DEEP` / `COLOR_CARD` / `COLOR_CARD_HI` / `COLOR_SLOT_LOCKED`
- **状态色**：`COLOR_GOLD`（金·货币/荣誉）、`COLOR_GREEN_BRIGHT`（绿·提升）、`COLOR_GREEN_UP`/`COLOR_RED_DOWN`（数值升降）、`COLOR_DANGER`（红·危险）
- **面板签名色**：`DT.get_panel_accent(panel_id)` —— store=金 / quest=青 / faction=紫 / occupation=青 / intelligence=紫 / drops=橙 / achievement=金 / daily=绿 / settings=中性灰蓝 / collection=科技青 / reinforcement=绿 / leaderboard=金。未知 id 回退霓虹青。
- **稀有度/兵种色**：`COLOR_RARITY_*` 六档、`DT.get_kind_color(kind)`。

## 四、面板外壳接入规范（新面板 checklist）

```gdscript
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

signal closed

func _ready() -> void:
    custom_minimum_size = DT.PANEL_SIZE_MEDIUM                      # ① 尺寸归档
    var accent := DT.get_panel_accent("my_panel")                   # ② 签名色（DT 注册）
    add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(accent))  # ③ 深空框架+accent边+外发光
    var chrome = PanelChrome.attach_to($Margin/VBox, "面板名", accent, "ENGLISH SUBTITLE")
    chrome.closed.connect(_on_close)                                # ④ 右上 ✕ 关闭（唯一关闭模式）
```

- **关闭按钮统一为 PanelChrome 右上 ✕**（44x44 点击区、hover 红色发光警示）。不再新增底部"关闭 CLOSE"大按钮。
- tscn 中删除旧 TitleRow/TitleLabel/CloseButton 节点与对应 StyleBoxFlat sub_resource。
- 面板必须声明 `signal closed` 并在 ✕ 触发时 emit——main.gd `_on_panel_closed` 据此收起 Overlay。

## 五、按钮样式（PanelStyles.make_button_styles）

```gdscript
var styles := PanelStyles.make_button_styles(accent)   # kind: "ghost"(默认)/"solid"(主按钮)/"danger"(红)
btn.add_theme_stylebox_override("normal", styles["normal"])   # hover/pressed/disabled/focus 同理
```

- 四态齐全：normal（淡描边）/ hover（accent 外发光）/ pressed（加深）/ disabled（中性暗）。
- solid 主按钮文字用深色（`DT.COLOR_VOID`），ghost 按钮文字用 `DT.COLOR_TEXT_BRIGHT`。
- 关闭按钮用 `PanelStyles.make_close_button_styles()`（PanelChrome 已内置）。

## 六、卡片/列表项样式

- 卡片容器：`PanelStyles.make_card_style(bg, border, bw, corner, padding)` 或 `make_panel_style(...)`。
- 标签 chip：`PanelStyles.make_chip_style(accent)`。
- 属性对比格：`PanelStyles.make_stat_cell_style(accent)`。
- 列表项选中包：`PanelStyles.make_roster_item_style(selected, accent)`。

## 七、打开/关闭契约（main.gd）

- Overlay 结构统一：`PopupLayer/XxxOverlay(Control) + Backdrop + CenterContainer + 面板实例`。
- 打开走 `_open_overlay(overlay, panel_key)`；常规面板只需实现 `on_overlay_opened()`（推荐，拆帧刷新）或 `refresh()` / `show_panel(null)` / `_refresh_all()` 之一，由 `_notify_panel_opened` 通用分发——**新面板不再往 _open_overlay 加 if 分支**。
- 特例仅存四类：map（refresh）/ backpack（性能打点）/ growth（show_panel+日志）/ afk（显式 _open）。
- 全局广播：`SignalBus.panel_opened(panel_id)` / `panel_closed(panel_id)`。
- 排行榜已从 PopupPanel 迁移为常驻 Overlay（v7.x），**禁止再新建 PopupPanel 弹窗面板**。

## 八、间距/圆角/边框

- 间距：`DT.PADDING_SMALL/MEDIUM/LARGE`（8/16/24）；容器 separation 6-10。
- 圆角：面板框架 12（PS.make_panel_frame 内置）、按钮 6、卡片 4-8。
- 边框：主边框 2px、次边框 1px；选中/强调态用**外发光**（shadow_color=accent）而非加粗边框。

## 九、Grid 布局

| 面板宽度 | 推荐列数 |
|---------|---------|
| ~840 (SMALL) | 6 列 |
| ~960 (MEDIUM) | 6-8 列 |
| ~1180 (LARGE) | 8-12 列 |

间距 8px（紧凑 6px）。

## 十、文本处理

- 描述文本 `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`。
- 列表行标题可 `clip_text = true`。
- 空列表必须有 EmptyHint（居中 + `DT.COLOR_TEXT_DIM`）。

## 十一、命名规范

- 面板: `XxxPanel`；容器: `XxxContainer/XxxVBox/XxxHBox`；标签: `XxxLabel`；按钮: `XxxButton`；滚动: `XxxScroll`。
- tscn 内 sub_resource（如还有）：`StyleBoxFlat_bg` / `StyleBoxFlat_btn_normal` 等按状态命名。

## 十二、可访问性

- 文本对比度 ≥ 4.5:1；大文本 ≥ 3:1。
- 按钮最小点击区 44x44（PanelChrome ✕ 已达标）；重要操作 ≥ 60x36。
- 高对比度/大字号/减少动效经 `DT.set_accessibility()` 全局切换，监听 `SignalBus.accessibility_changed`。

---

## 附：防回潮检查（提交前自查）

```bash
# 新改动文件中不应再出现裸颜色字面量（数据表 fallback 除外）：
grep -n "Color(0\." scenes/ui/<改动文件>.gd
# 面板应引用 DT/PanelStyles/PanelChrome：
grep -c "DesignTokens\|design_tokens\|panel_styles\|panel_chrome" scenes/ui/<改动文件>.gd
```

**文档结束**
