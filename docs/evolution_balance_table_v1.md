# 首批进化链数值平衡表（V1）

适用规则：
- 进化前置：星级门槛 + 改造次数门槛 + 研究点 + 许可函
- 进化结果：改造重置，属性传承 30%
- 阶段定义：
  - `E1`：基础单位 -> 同体系高阶单位
  - `E2`：高阶单位 -> 势力特化单位

## 通用阈值

- E1：`星级 >= 4` 且 `改造 >= 3/3`
- E2：`星级 >= 7` 且 `改造 >= 3/3`

## 消耗模板

- E1：研究点 `320` + 通用许可函 `1` + 类型许可函 `1`
- E2：研究点 `680` + 通用许可函 `1` + 类型许可函 `1` + 专属许可函 `1`

## 首批进化链（建议）

1. `platform_ww1_light` -> `platform_ww2_light` -> `platform_cold_light`
2. `platform_ww2_light` -> `platform_cold_light` -> `platform_modern_light`
3. `platform_cold_medium` -> `platform_modern_medium` -> `platform_modern_guard_heavy`
4. `platform_modern_medium` -> `platform_future_heavy` -> `omega_platform`
5. `void_time_ripple` -> `void_barrier_shift` -> `void_phase_cloak`

## 分链修正（稀有度与定位）

- 轻型侦察/突击链（1/2）：研究点乘数 `0.90`
- 中型主战链（3）：研究点乘数 `1.00`
- 重装终局链（4）：研究点乘数 `1.20`
- 法则链（5）：研究点乘数 `1.10`，类型许可函使用 `permit_type_law`

## 实际推荐值（含乘数）

- 轻型链 E1：`288`，E2：`612`
- 中型链 E1：`320`，E2：`680`
- 重装链 E1：`384`，E2：`816`
- 法则链 E1：`352`，E2：`748`

## 许可函建议

- 通用：所有进化阶段都消耗 1
- 类型：按卡牌类别消耗 1（突击/重装/支援/法则）
- 专属：仅 E2 消耗 1（`permit_card_<target_card_id>`）

## 军衔阈值建议（配合视觉）

- 下士：`power >= 0`
- 中士：`power >= 120`
- 中尉：`power >= 220`
- 上尉：`power >= 360`
- 少校：`power >= 540`
- 上校：`power >= 780`

## 体验提示文案（用于确认框）

- 你将获得：新单位成长上限、军衔重评、属性传承 30%
- 你将失去：当前 A/B/C 改造效果（改造进度重置）
- 建议：先在当前阶段完成关键改造，再执行进化
