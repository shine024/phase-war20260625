# 改造面板视觉与设计稿对齐修改计划

## 问题诊断（基于游戏截图 vs HTML设计稿 v1.4 对比）

### P0 关键问题（2个）

**1. "不适用"改造条目泛滥**
- 根因: `_refresh_mod_list()` 从 IntelItemBag 读所有已解锁改造，不做兵种过滤
- `_create_mod_item()` 检测到不适用只标灰写 ⊘，不隐藏
- 结果: 27+个改造全部列出，大量灰色噪音
- 修复: 在 `_refresh_mod_list()` 收集完 mod_ids 后，加一步按 `selected_card.combat_kind` 预过滤

**2. 底部操作台（ActionDeck）未生效**
- 代码逻辑: `_show_mod_details()` 正确设置 `action_deck.visible = true` / `deck_empty.visible = false`
- 疑点: tscn 中 `DeckEmpty` 没有 `visible = false` 显式标记（Godot 默认 true），但 `ActionDeck` 有 `visible = false`——切换逻辑应正确
- 验证步骤: 添加调试日志确认 `_on_mod_selected` → `_show_mod_details` 链路是否触发

### P1 重要问题（2个）

**3. 右栏属性6格中移速显示异常（150）**
- 疑因: `_build_stat_grid()` 读取 `stats.move_speed`，该值单位为移动格数/秒
- 移速150远超正常值(2-6)，可能是字段名错误或 read 了像素值而非整数
- 修复: 核对 UnitStats.move_speed 的定义来源

**4. 列宽分配不均**
- 当前: MiddlePanel 用 `size_flags_horizontal = 3 (EXPAND_FILL)` 但 LeftPanel/DetailPanel 有固定最小尺寸
- 实际渲染受 Godot 布局约束影响
- 修复: 确保 LeftPanel custom_min_size=290px, DetailPanel custom_min_size=280px, MiddlePanel expand_ratio优先

### P2 改进问题（2个）

**5. 筛选Chip样式验证**
- 代码已有 `_update_chip_styles()` 实现 active/inactive 差异化样式
- 需验证 tscn 中 chip 节点名是否与 @onready 引用一致

**6. 模块行战力门槛标识缺失**
- 在 `_create_mod_item()` 中检查 PowerTiers.get_tier_by_power(selected_card_power) >= mod需要的min_tier
- 不达标时在 status_text 显示"✗需CHAMPION（当前ELITE）"

## 实施顺序

1. **先修复 P0-1（改造过滤）** — 1个文件，~5行代码
2. **验证 P0-2（操作台链路）** — 加临时打印日志，运行后根据结果决定是否需要更多改动
3. **修复 P1-3（移速异常）** — 核对 stats 字段
4. **完善 P1-4/P2-5/P2-6** — 样式微调

预计改动文件: `modification_panel.gd`（主）+ `modification_panel.tscn`（布局微调）