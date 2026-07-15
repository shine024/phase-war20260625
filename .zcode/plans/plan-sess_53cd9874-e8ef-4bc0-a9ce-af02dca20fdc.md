# 敌方单位加成来源明细显示

## 目标
敌方单位（血/攻/防加得很高时）在情报面板显示"为什么这么高"——基础值、各加成来源的倍率与标签、总倍率、最终值。覆盖全部敌方单位（经典敌人/蜂群/相位师产兵/相位师单位）。

## 核心问题
当前所有加成乘区系数都是函数局部 float 变量，乘进最终数值后即丢弃，**运行时完全无加成来源明细**。面板只显示扁平最终数字。

## 设计决策（已与用户确认）
1. **覆盖范围**：全部敌方单位
2. **显示粒度**：总倍率+标签（基础值 + 各来源倍率列表 + 总倍率 + 最终值，不展开每步中间值）
3. **明细存储**：单位节点 meta（`unit.set_meta("enemy_bonus_breakdown", {...})`），不侵入 UnitStats 资源/存档
4. **产兵 7 层**：全展开（master_stats/战场难度/符文/序列/相位仪/词缀/配档tier 各自列出）

## 数据结构

### 加成明细字典结构（挂在 unit meta）
```gdscript
{
    "base_hp": float,           # archetype 基础血量
    "base_atk": float,          # 基础攻击（取三维最大或 attack_damage）
    "base_def": float,          # 基础防御
    "final_hp": float,          # 最终血量（= 当前 max_hp）
    "final_atk": float,         # 最终攻击
    "final_def": float,         # 最终防御
    "sources": [                # 加成来源数组（按应用顺序）
        {"label": "波次×1.24", "hp_mul": 1.24, "atk_mul": 1.16},
        {"label": "关卡(第40关)×1.36", "hp_mul": 1.36, "atk_mul": 1.36},
        {"label": "势力(钢壁防务 Lv5)×1.18/1.05", "hp_mul": 1.18, "atk_mul": 1.05},
        {"label": "相位师属性×1.32", "hp_mul": 1.16, "atk_mul": 1.32},
        {"label": "难度(普通)×1.0", "hp_mul": 1.0, "atk_mul": 1.0},
        # 经典敌人到这就结束；产兵继续：
        {"label": "符文×1.10", "hp_mul": 1.10, "atk_mul": 1.10},
        {"label": "出兵序列(精英)×1.25", "hp_mul": 1.25, "atk_mul": 1.25},
        {"label": "相位仪×1.05", "hp_mul": 1.05, "atk_mul": 1.05},
        {"label": "配档(中配)×1.18/1.20", "hp_mul": 1.18, "atk_mul": 1.20},
    ],
    "ng_plus": 1.2,             # 二周目倍率（仅经典敌人/蜂群，产兵无）
    "total_hp_mul": float,      # 总血量倍率（含二周目）
    "total_atk_mul": float,     # 总攻击倍率
    "kind": "classic"|"spawn",  # 单位类型（经典敌人/产兵）
}
```

> 注：`hp_mul`/`atk_mul` 各 source 独立记录（波次 HP×1.24 vs 攻击×1.16 不同步）。`total_*_mul` = 所有 source 之积 × ng_plus，用于显示"总倍率"。

## 实现步骤

### 阶段 A：数据层 — 构建加成明细（核心）

**A1. `data/enemy_stat_resolver.gd` — `resolve_classic_enemy` 返回明细**
- 函数末尾返回字典新增 `"bonus_breakdown"` 键，包含上述结构（kind="classic"）
- 各局部乘区系数（w_hp/w_dmg/lvl/m_hp/m_atk/f_hp/f_atk/d_mul）在算完后立即写入 sources 数组
- `make_default_context` 顺带在 ctx 上记录 faction_id/faction_level/难度档名/是否相位师战（供 label 拼接用，避免 resolver 反查全局）
- 新增 `_build_breakdown_sources(ctx, ...)` 辅助函数收集 sources

**A2. `scenes/units/enemy_unit.gd` — 挂载明细到 meta**
- `_apply_archetype_stats` 末尾：从 `resolve_classic_enemy` 返回值取 `bonus_breakdown`，写入 `set_meta("enemy_bonus_breakdown", breakdown)`
- `_apply_ng_plus_scaling`：更新 breakdown 的 `ng_plus` 字段 + `total_*_mul`（若明细存在）
- `_apply_phase_law_passives`：律法减益是"我方施加的减益"非"敌方自身加成"，**不计入**（在面板文案注明"不含我方法则减益"）

**A3. `scenes/units/swarm_enemy_slot.gd` — 同 A2**
- 同款链路，从 `resolve_classic_enemy` 返回取明细挂 meta

**A4. `scenes/units/enemy_phase_field_driver.gd` — 产兵 7 层明细**
- `_produce_unit_with_equipment` 在各加成步骤（master_stats/apply_field_multipliers/rune/sequence/instrument/affix/tier）后，把该步倍率追加到 breakdown sources
- 构建 stats 前记录 base（`_build_stats_from_archetype` 后的值）；产兵末尾记录 final（乘完所有加成后的 stats 值）
- 产兵无 NG+（核实：enemy_phase_field_driver.gd 无 ng_plus 调用），kind="spawn"
- 挂到 ConstructUnit 的 meta（产兵走 `unit.setup_with_enemy_visual(false, stats, ...)`）

### 阶段 B：面板层 — 显示加成来源

**B1. `scenes/ui/card_info_panel.tscn` — 新增 BonusSection**
- 在 InfoVBox 中 NurtureSection 后新增 `BonusSection`（PanelContainer + VBox + Title"加成来源" + Label），复用 `StyleBoxFlat_section` 样式
- 标题色用浅金（区分于星级强化金黄/养成摘要粉）

**B2. `scenes/ui/card_info_panel.gd` — 读取并渲染明细**
- `@onready` 取 `BonusSection` / `BonusLabel` 节点引用
- 新增 `_build_bonus_breakdown_text(unit) -> String`：从 `unit.get_meta("enemy_bonus_breakdown", {})` 读取，按"总倍率+标签"粒度格式化：
  ```
  基础: 生命80｜攻10｜防5
  加成: 波次×1.24 关卡(第40关)×1.36 势力(钢壁Lv5)×1.18 相位师×1.32 难度(普通)×1.0 二周目×1.2
  总倍率: 生命×4.0 攻击×4.0
  最终: 生命320｜攻40｜防5
  ```
- `_show_generic_enemy_unit` / `_show_enemy_construct_unit` / `_show_enemy_phase_master_unit` 三处接入：设置 `bonus_label.text` + `_set_section_visible_by_content(_bonus_section, text)`
- `_clear_other_unit_sections` 增加清空 BonusSection（敌方切换到无明细单位时隐藏）
- 玩家单位路径（`_show_player_unit`）隐藏 BonusSection（我方加成走养成摘要，不在此显示）

### 阶段 C：验证

- Godot headless `--check-only`（项目体量大可能 5min 超时，属既有现象）
- Grep 静态核对：`enemy_bonus_breakdown` meta 键在 4 个写入点 + 1 个读取点拼写一致；`_build_bonus_breakdown_text` 被三处敌方显示函数调用；BonusSection 节点路径与 tscn 匹配

## 关键设计决策
1. **meta 而非 UnitStats 字段**——不侵入 Resource 序列化/存档，单位销毁即释放，零副作用
2. **总倍率+标签粒度**——用户选择，比逐乘区展开紧凑，但保留基础/各来源/总倍率/最终值四要素可追溯
3. **hp_mul/atk_mul 分开记**——波次/势力等 HP 与攻击倍率不同步（波次 HP×1.24 vs 攻击×1.16），必须分开否则显示失真
4. **律法减益不计入**——_apply_phase_law_passives 是我方施加的战斗中减益（burn_on_hit/anchor_field 等），非敌方"自身强"，面板文案注明边界
5. **产兵全展开 7 层**——用户选择，信息完整；经典敌人 5 层（波次/关卡/势力/相位师/难度）+ 二周目
6. **base 从 archetype cfg 取**——`resolve_classic_enemy` 内 `base_hp = cfg.hp`，产兵从 `_build_stats_from_archetype` 后的 stats 取（已含 enhance_level 但未乘战场加成）

## 不做的事
- 不改任何战斗数值计算逻辑（纯追加记录+显示）
- 不改 UnitStats 资源结构
- 不改存档 schema
- 不动我方单位显示（我方加成走养成摘要 section）
- 律法减益/我方光环对敌的削减不计入明细（属"我方施加"非"敌方自身加成"）

## 涉及文件
| 文件 | 改动 |
|------|------|
| `data/enemy_stat_resolver.gd` | resolve_classic_enemy 返回 +bonus_breakdown；make_default_context 记录标签信息 |
| `scenes/units/enemy_unit.gd` | _apply_archetype_stats 挂 meta；_apply_ng_plus_scaling 更新明细 |
| `scenes/units/swarm_enemy_slot.gd` | 同 enemy_unit |
| `scenes/units/enemy_phase_field_driver.gd` | _produce_unit_with_equipment 7 层明细收集 + 挂产兵 meta |
| `scenes/ui/card_info_panel.tscn` | 新增 BonusSection 节点 |
| `scenes/ui/card_info_panel.gd` | @onready + _build_bonus_breakdown_text + 三处敌方显示接入 + _clear_other_unit_sections |
