# 敌人精灵图最终制作清单

适配当前实现：`scenes/units/enemy_unit.gd` 已支持生成敌人复用固定模板。  
结论：不需要做 171 套。

---

## A. 最低可用清单（20 套，先做这批）

这 20 套可覆盖 **全部 135 个生成敌人**，并覆盖一部分固定敌人。

### 一战
- `enemy_ww1_infantry_basic`（步兵模板）
- `elite_ww1_armored`（载具模板）
- `enemy_ww1_mg_nest`（阵地模板）
- `enemy_ww1_mortar`（支援模板）

### 二战
- `enemy_ww2_infantry`（步兵模板）
- `elite_ww2_panther`（载具模板）
- `enemy_ww2_mg42`（阵地模板）
- `enemy_ww2_panzerschreck`（支援模板）

### 冷战
- `enemy_cold_ak`（步兵模板）
- `enemy_cold_btr`（载具模板）
- `enemy_cold_m113`（阵地模板）
- `enemy_cold_m60`（支援模板）

### 现代
- `enemy_modern_marine`（步兵模板）
- `enemy_modern_stryker`（载具模板）
- `enemy_modern_mlrs`（阵地模板）
- `enemy_modern_technical`（支援模板）

### 近未来
- `enemy_future_cyborg`（步兵模板）
- `enemy_future_hovertank`（载具模板）
- `enemy_future_mech`（阵地模板）
- `enemy_future_drone`（支援模板）

---

## B. 完整目标清单（36 套，最终美术完成版）

如果你要“固定敌人全部有独立形象”，最终目标就是这 36 套。

### 一战（7）
- `enemy_ww1_infantry_basic`（步兵班·MP18）
- `enemy_ww1_infantry_rifle`（步兵班·步枪）
- `enemy_ww1_mg_nest`（机枪巢）
- `enemy_ww1_mortar`（迫击炮组）
- `elite_ww1_storm`（暴风突击队）
- `elite_ww1_armored`（装甲车）
- `boss_ww1_av7`（圣沙蒙坦克）

### 二战（7）
- `enemy_ww2_infantry`（步兵班·汤普森）
- `enemy_ww2_rifleman`（步枪班·加兰德）
- `enemy_ww2_mg42`（MG42机枪组）
- `enemy_ww2_panzerschreck`（反坦克组）
- `elite_ww2_paratrooper`（伞兵精英）
- `elite_ww2_panther`（黑豹坦克）
- `boss_ww2_kingtiger`（虎王坦克）

### 冷战（7）
- `enemy_cold_ak`（苏军步兵）
- `enemy_cold_m60`（美军步兵）
- `enemy_cold_btr`（BTR装甲车）
- `enemy_cold_m113`（M113装甲车）
- `elite_cold_spetsnaz`（特种部队）
- `elite_cold_t72`（T-72坦克）
- `boss_cold_mig`（米格-29）

### 现代（8）
- `enemy_modern_marine`（海军陆战队）
- `enemy_modern_technical`（皮卡武装）
- `enemy_modern_stryker`（斯特赖克装甲车）
- `enemy_modern_mlrs`（火箭炮车）
- `elite_modern_delta`（三角洲部队）
- `elite_modern_abrams`（M1A2坦克）
- `elite_modern_apache`（阿帕奇直升机）
- `boss_modern_command`（指挥中枢）

### 近未来（7）
- `enemy_future_drone`（无人机群）
- `enemy_future_cyborg`（机械步兵）
- `enemy_future_mech`（机甲步兵）
- `enemy_future_hovertank`（悬浮坦克）
- `elite_future_spectre`（幽灵特工）
- `elite_future_colossus`（巨神机甲）
- `boss_future_nexus`（风暴核心）

---

## 建议执行顺序

1. 先做 A（20 套）：马上覆盖全生成敌人 + 主干战斗可读性。  
2. 再补 B 中未覆盖项（剩余 16 套）：完成固定敌人全独立美术。  
3. Boss 与精英优先做动画帧；普通兵种可先静态贴图再逐步补动画。
