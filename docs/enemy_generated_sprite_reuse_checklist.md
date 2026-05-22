# 生成敌人美术复用清单

适用代码：`scenes/units/enemy_unit.gd`  
复用规则：`enemy_<era>_<nn>` 使用 `(nn - 1) % 4` 选择模板（0=步兵、1=载具、2=阵地、3=支援）。

---

## 一战（`enemy_ww1_01` ~ `enemy_ww1_27`）

- 槽位0（步兵）：复用 `enemy_ww1_infantry_basic`
  - ID：01, 05, 09, 13, 17, 21, 25
- 槽位1（载具）：复用 `elite_ww1_armored`
  - ID：02, 06, 10, 14, 18, 22, 26
- 槽位2（阵地）：复用 `enemy_ww1_mg_nest`
  - ID：03, 07, 11, 15, 19, 23, 27
- 槽位3（支援）：复用 `enemy_ww1_mortar`
  - ID：04, 08, 12, 16, 20, 24

## 二战（`enemy_ww2_01` ~ `enemy_ww2_27`）

- 槽位0（步兵）：复用 `enemy_ww2_infantry`
  - ID：01, 05, 09, 13, 17, 21, 25
- 槽位1（载具）：复用 `elite_ww2_panther`
  - ID：02, 06, 10, 14, 18, 22, 26
- 槽位2（阵地）：复用 `enemy_ww2_mg42`
  - ID：03, 07, 11, 15, 19, 23, 27
- 槽位3（支援）：复用 `enemy_ww2_panzerschreck`
  - ID：04, 08, 12, 16, 20, 24

## 冷战（`enemy_cold_01` ~ `enemy_cold_27`）

- 槽位0（步兵）：复用 `enemy_cold_ak`
  - ID：01, 05, 09, 13, 17, 21, 25
- 槽位1（载具）：复用 `enemy_cold_btr`
  - ID：02, 06, 10, 14, 18, 22, 26
- 槽位2（阵地）：复用 `enemy_cold_m113`
  - ID：03, 07, 11, 15, 19, 23, 27
- 槽位3（支援）：复用 `enemy_cold_m60`
  - ID：04, 08, 12, 16, 20, 24

## 现代（`enemy_modern_01` ~ `enemy_modern_27`）

- 槽位0（步兵）：复用 `enemy_modern_marine`
  - ID：01, 05, 09, 13, 17, 21, 25
- 槽位1（载具）：复用 `enemy_modern_stryker`
  - ID：02, 06, 10, 14, 18, 22, 26
- 槽位2（阵地）：复用 `enemy_modern_mlrs`
  - ID：03, 07, 11, 15, 19, 23, 27
- 槽位3（支援）：复用 `enemy_modern_technical`
  - ID：04, 08, 12, 16, 20, 24

## 近未来（`enemy_near_01` ~ `enemy_near_27`）

- 槽位0（步兵）：复用 `enemy_future_cyborg`
  - ID：01, 05, 09, 13, 17, 21, 25
- 槽位1（载具）：复用 `enemy_future_hovertank`
  - ID：02, 06, 10, 14, 18, 22, 26
- 槽位2（阵地）：复用 `enemy_future_mech`
  - ID：03, 07, 11, 15, 19, 23, 27
- 槽位3（支援）：复用 `enemy_future_drone`
  - ID：04, 08, 12, 16, 20, 24

---

## 美术交付最小集合（建议）

- [ ] 一战模板图可用（4个）
- [ ] 二战模板图可用（4个）
- [ ] 冷战模板图可用（4个）
- [ ] 现代模板图可用（4个）
- [ ] 近未来模板图可用（4个）

共 20 套模板图可覆盖 135 个生成敌人。

## 联调验收清单

- [ ] 随机刷 `enemy_ww1_01` 与 `enemy_ww1_02`，确认显示不同模板
- [ ] 任意 `enemy_<era>_27` 能正确显示（末尾ID边界）
- [ ] 缺失模板资源时仍会回退占位图（不崩溃）
- [ ] 精英/Boss 颜色与缩放逻辑仍正常生效
