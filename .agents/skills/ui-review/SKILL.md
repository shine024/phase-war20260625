---
name: ui-review
description: UI 审查与调整工作流——按"便捷性>易用性>包容性>美观性"四要素优先级审查面板与反馈链，含 Toast/Tips/Modal 分层原则、新面板检查单、项目已落地接入点地图。新增/修改任何 UI、排查"看不懂/点了没反应/找不到"类问题前必读。
---

# UI 审查与调整工作流（ui-review）

> 来源：2026-08-22 对照知乎《独立游戏不重视UI设计的后果有多灾难？》（kaveil饼 回答）对 Phase War 全 UI 层的系统性审查与 16 项落地批次。
> 本文件是活文档：四要素标准 + 项目接入点地图 + 新面板检查单三合一。

## 一、原回答关键要点（审查时的判断标准）

**后果定级**：UI 做不好轻则 Steam 吃差评，重则游戏无法进行、玩家申请退款。

### 1. 四要素优先级（从高到低，冲突时砍低的保高的）

**便捷性 > 易用性 > 包容性 > 美观性**——美观永远最后考虑，全部满足后才轮到它。

- **便捷性**：以用户为中心，贴合用户习惯、认知、使用场景。预判用户每一次操作，把核心需求放第一优先；用户遇到困境时在显眼位置给引导。核心手法是"点读机"——哪里不会点哪里，鼠标悬停就地解释（《朝露：境界旅程》为正面典型，机制多到灾难但引导极强）。**能一次操作完成的，绝不让玩家分两次**。
- **易用性**：从操作方式、辨识度、交互反馈入手，降低理解成本。可交互处必须有多个状态（悬停变色、选中框、连滚动条都有状态），不可点击处零反馈——让玩家能分辨"哪里能点/哪里不能/是不是卡了"（《吸血鬼幸存者》UI 简陋但设计好）。辨识度：物品黑描边、拿起时格子虚影（俄罗斯方块式）优于偷懒的外发光（对比《背包乱斗》vs《背包闯江湖》）；文字为主的游戏不能让精美底图干扰文字，该砍画面就砍（《苏丹的游戏》反例）。
- **包容性**：适配 16:10 笔记本/21:9/32:9 带鱼屏、留刘海出血边；不默认用户有耐心、熟悉类型、聪明——不能默认玩家知道爆炸图标=暴击、会按 ESC（《大江湖之苍龙与白鸟》ESC 反例）。**把用户当傻子看待，耐心地为他们设计好一切指引**。
- **美观性**：第一要务是**一致**（风格/控件/反馈/字体/动效统一），不是华丽。字号参考（1080p/96dpi）：小字 13~14px、中号 16px、大号 20/24px，除小字外字号取双数（缩放与定位方便）；字体优先中黑体（思源黑体类）或中圆体，百搭；宋/隶选笔画粗细一致的，放弃行书草书。水墨风天生易脏（边界模糊层次不清）。驾驭不了浮夸风格就老实扁平化——像高考作文"没把握就写议论文"，下限高不翻车。配色别拉高饱和，PS 拾色器用红线四等分，**左上角区域是 UI 主色安全取色区**。UI 是绿叶衬托红花，学会做减法。

### 2. 提示分层术语（选型顺序：能低不高）

| 层 | 名称 | 触发 | 项目对应 |
|----|------|------|---------|
| 最轻 | **Toast** | 被动触发，不打断游戏 | ToastManager（`SignalBus.show_toast` / `show_success` / `show_error`） |
| 中 | **Tips** | 玩家主动悬停，就地解释 | 原生 `tooltip_text`（全项目主流做法） |
| 重 | **Modal** | 阻断式，必要确认/首解锁说明 | ConfirmationDialog / FeatureUnlockPopup |
| 最重 | **Overlay/Page** | 整页/暂停菜单 | PopupLayer 各 overlay |

**能用 Toast 不用 Tips，能用 Tips 不用 Modal。** 阻断有阻断的价值（动作游戏看说明时怕被偷袭），具体条件具体分析。

### 3. 两个提前预见的设计点

- **多物品同时获得**：挨个弹 toast 影响体验、合并一条又容易漏信息——要么短窗口聚合计数（本项目 Toast 同文案合并"×N" + 资源 +N 飘字 0.35s 聚合），要么一次性结算列表（MvpPanel）。
- **新功能首次解锁**：学黑猴解锁变身时的说明弹窗——首次触发配一个带一句话说明的 Modal（`FeatureUnlockPopup.show_once`），防流失关键一笔。

### 4. 终极验收法

站在用户角度思考。**蠢办法：设计完成后拿给一个不玩游戏的人看，连他都看懂就是成功。**

## 二、项目已落地接入点地图（2026-08-22 批次后现状）

| 需求 | 接入点 | 说明 |
|------|--------|------|
| 悬停就地解释 | 原生 `tooltip_text` | 底栏槽位/资源栏/背包卡牌/世界地图等已覆盖；新图标必挂 |
| 词条效果文本 | `AffixDisplayFormat.fmt_player_affix_tags`（带 tooltip 字段）+ `tags_tooltip()` | 数据源 `AffixResource.get_detailed_description()` |
| 战场 buff 说明 | `unit_hover_info.gd`（悬停窗状态行）+ `UnitStatusCollector.collect/describe` | 点击详情面板同一数据源 |
| Toast | `ToastManager`（lazy）：上限 5 条 + 同文案合并 ×N | `SignalBus.show_toast` 单参走默认绿色；要红/橙直调 `show_error/show_warning` |
| 资源获得反馈 | `BasicResourceManager.resource_delta(id, applied)` 信号 → `resource_bar.gd` 聚合飘字 | 别再读无参 `resources_changed` 做增量判断 |
| 成就解锁提示 | ToastManager 已连 `SignalBus.achievement_unlocked` | 自动 toast，无需接线 |
| 手型光标 | `main.gd _on_node_added`（全局 BaseButton 自动）+ 非 Button 控件手动设 | 新非 Button 可点击控件记得手动设 |
| 按钮四态 | `PanelStyles.make_button_styles(accent, kind)` | 新按钮一律走工厂，别手写单态 |
| ESC 面板栈 | `main.gd _close_top_overlay`（关最上层→战斗中切暂停） | 新 overlay 记得加进 `_all_overlays()` 注册表 |
| 中文字体 | `DesignTokens.ensure_cjk_fallback()`（main/title_screen 已调用） | 新增打包字体要加进该函数的列表 |
| 字号下限 | 10px（纯数字/英文），中文建议 ≥12 | token 走 `DT.FONT_SIZE_*` 七档 |
| 首次解锁引导 | `FeatureUnlockPopup.show_once(key, title, desc)` | key 一次性持久化于 user://feature_unlock_seen.json |
| 战斗快捷键 | 1-9 部署（`bottom_instrument_bar.begin_deploy_from_slot_index`） | 与点击槽位同链路（instance_id 精确匹配） |
| 宽高比 | project.godot `stretch/aspect="expand"` | 16:10/带鱼屏不黑边 |
| 敌方情报浏览 | 情报中心第 4 页"敌方情报"（`intelligence_hub_panel._setup_intel_tab`） | IntelManual 条目唯一浏览入口 |

## 三、工作流步骤

1. **定位层级**：把问题归到四要素之一（从便捷性往下找）。"找不到/看不懂"→便捷性；"点了没反应/步骤繁琐"→易用性；"某屏幕/某人群出问题"→包容性；"不一致/太花"→美观性。
2. **查接入点地图**选实现方式；反馈类改动按 Toast/Tips/Modal 分层选型（能低不高）。
3. **新代码铁律**：颜色/字号走 `DesignTokens`；按钮样式走 `PanelStyles` 工厂；禁止 10px 以下字号与写死颜色。
4. **跑验证**：`godot --headless --path . --script tests/ui_p1_validation.gd`（改了地图里的接入点时，把新文件加进该脚本的 CHANGED_SCRIPTS）。
5. **肉眼验收**（headless 验不了视觉）：悬停有说明？点击有反馈？失败路径有提示？ESC 逐层退？新分辨率不破版？

## 四、新面板/新功能 UI 检查单

- [ ] 每个图标/词条/数值 → 就地 tooltip（悬停即解释）
- [ ] 每个可点击 → 手型光标 + hover 态（Button 自动；PanelContainer/Label 手动）
- [ ] 每个操作 → 成功与失败各有反馈（toast + 音效；失败要给**具体原因**）
- [ ] 每个新术语 → 不查手册就能在界面内看到解释
- [ ] 新 overlay → 注册进 `main._all_overlays()`，ESC 能关
- [ ] 首次出现 → `FeatureUnlockPopup.show_once` 一句话说明
- [ ] 高频操作 → 有快捷键或批量途径
- [ ] 字号 ≥10、颜色走 token、样式走工厂
