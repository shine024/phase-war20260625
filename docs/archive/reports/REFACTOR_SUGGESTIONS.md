# Phase War 大文件拆分建议

> 优先级基于：文件大小 + 运行时性能影响 + 维护复杂度
> 数据文件（纯 Dictionary/Array）优先级低于逻辑文件

## P1 建议拆分（运行时加载，影响启动/内存）

### 1. enemy_phase_masters.gd — 2176 行
**性质**: 纯数据字典，定义每个 Phase 的敌人 Master 配置
**建议**: 按相位区间拆分为 `enemy_phase_masters_1_10.gd`, `enemy_phase_masters_11_20.gd` 等
**收益**: 减少首屏脚本解析时间 ~2ms（移动端）
**风险**: 低 — 纯数据，拆分后用 `preload` 合并即可

### 2. enemy_phase_equipment.gd — 1428 行
**性质**: 纯数据字典，相位装备配置
**建议**: 同上，按相位区间拆分
**收益**: 减少首屏脚本解析 ~1.5ms
**风险**: 低

## P2 建议拆分（维护性为主）

### 3. leaderboard_panel.gd — 1209 行
**性质**: UI 逻辑，排行榜面板
**建议**: 提取 LeaderboardPresenter（已有 presenter 文件 776 行）、LeaderboardView 子组件
**收益**: 代码可维护性大幅提升
**风险**: 中 — 需仔细处理信号连接

### 4. tower_climb_manager.gd — 894 行
**性质**: 爬塔游戏逻辑
**建议**: 拆分为 TowerClimbState（数据）、TowerClimbRules（规则计算）、TowerClimbManager（协调）
**收益**: 单一职责，便于测试
**风险**: 中

### 5. save_manager.gd — 839 行
**性质**: 存档管理（含数据迁移）
**建议**: 数据迁移逻辑（v1→v2→v3 ~200行）提取为独立的 save_migrator.gd
**收益**: 迁移逻辑与日常存取分离
**风险**: 低 — 迁移是一次性代码

## P3 建议检查（可能可删）

### scripts/ui_beautifier.gd — 802 行
**建议**: 检查是否仍被引用，如为死代码可直接删除
（同目录的 ui_beautifier_enhanced.gd 802行 已确认无引用并删除）

### managers/_archive/save_manager_enhanced.gd — 738 行
**建议**: 已归档，如确认不再需要可删除
