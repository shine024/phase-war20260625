# UI 英文文本修复计划

> 生成时间：2026-08-04
> 范围：改造面板、相位师技能树、战斗卡情报面板
> 原则：只修显示层，不改动战斗逻辑和数据定义

---

## 一、问题总览

| 面板 | 问题数 | 严重程度 |
|------|--------|----------|
| 改造面板 | 5 | HIGH（直接影响玩家阅读） |
| 相位师技能树 | 4 | MEDIUM（部分场景触发） |
| 战斗卡情报面板 | 1 | HIGH（效果key裸露英文） |
| **合计** | **10** | |

---

## 二、改造面板（5处）

### M1 — 副标题英文硬编码
**文件**：`scenes/ui/modification_panel.tscn:185`
**当前**：`text = "TACTICAL MODIFICATION BAY"`
**根因**：静态 scene 属性，设计时直接写英文装饰副标题，未做任何本地化
**修复**：改为 `"战术改造舱"`（与主标题"战术改造站"风格统一）
**风险**：零风险，纯文本改动

---

### M2 — "战力评分 · POWER" 英文硬编码
**文件**：`scenes/ui/modification_panel.gd:1065`
**当前**：`lbl1.text = "战力评分 · POWER"`
**根因**：硬编码字符串，中英混排风格不一致
**修复**：改为 `"战力评分"`（删除末尾 · POWER）
**风险**：零风险，纯文本改动

---

### M3 — 进度条档位列名英文缩写
**文件**：`scenes/ui/modification_panel.gd:1090`
**当前**：`var names := ["GRUNT", "VET", "ELITE", "CHAMP", "OVER"]`
**根因**：硬编码英文缩写数组，`PowerTiers.TIER_NAMES` 已存在中文映射但此处未引用
**修复**：
```gdscript
var names := [
    PowerTiers.TIER_NAMES[PowerTiers.Tier.GRUNT],
    PowerTiers.TIER_NAMES[PowerTiers.Tier.VETERAN],
    PowerTiers.TIER_NAMES[PowerTiers.Tier.ELITE],
    PowerTiers.TIER_NAMES[PowerTiers.Tier.CHAMPION],
    PowerTiers.TIER_NAMES[PowerTiers.Tier.OVERLORD],
]
```
**风险**：低，PowerTiers 是 autoload，无时序问题

---

### M4 — `_get_card_tier_str()` 返回英文档位名
**文件**：`scenes/ui/modification_panel.gd:1364-1374`
**当前**：维护自己的英文数组，且 L1070 处显示 `"ELITE · 精英"`（中英重复）
**根因**：函数注释写着"需英文显示"，但实际 UI 同时显示英文+中文，玩家阅读混乱
**修复**：
- `_get_card_tier_str()` 改调用 `PowerTiers.get_tier_name()` 直接返回中文名，防御性回退也用中文
- L1070 处 `"%s · %s" % [tier_str, tier_name_cn]` 改为只保留中文（tier_str 已是中文，tier_name_cn 重复）
**风险**：中——L950 的 `"当前战力档  %s" % tier_str` 从英文变为中文，属预期行为

---

### M5 — tooltip 泄露内部字段 `prototype`
**文件**：`scenes/ui/modification_panel.gd:856`
**当前**：`btn.tooltip_text = "%s\n%s\n稀有度：%s" % [prototype, description, rarity_cn]`
**根因**：`prototype` 是开发字段（武器设计代号如"M1艾布拉姆斯火控系统"），非玩家面向文案
**修复**：删除 prototype 行，只显示 description + 稀有度
**风险**：零风险，tooltip 信息更清爽

---

## 三、相位师技能树（4处）

### S1 — 技能节点解锁提示：相位仪显示原始ID
**文件**：`scenes/ui/phase_master_skill_panel.gd:303`
**当前**：`相位仪[pi_atlas_01]`
**根因**：`_format_unlocks` 只拼原始ID，未查 PhaseInstruments.get_by_id()
**修复**：查询 PhaseInstruments.get_by_id(u_id) 取 name 字段显示
**风险**：低，get_by_id 返回空时回退 u_id

---

### S2 — 总览Tab：相位仪显示原始ID
**文件**：`data/unlock_labels.gd:210-218`
**当前**：`相位仪：pi_atlas_01`
**根因**：同上
**修复**：查询 PhaseInstruments.get_by_id(u_id) 取 name 字段
**风险**：低

---

### S3 — 技能节点解锁提示：进化显示数字时代
**文件**：`scenes/ui/phase_master_skill_panel.gd:306-308`
**当前**：`进化解锁[时代0]` / `进化解锁[全时代]`
**根因**：`era` 是整数，未映射为时代名
**修复**：映射 era→["一战","二战","冷战","现代","近未来"]
**风险**：低

---

### S4 — 总览Tab：进化显示数字时代
**文件**：`data/unlock_labels.gd:229-238`
**当前**：`进化：时代0` / `进化：全时代`
**根因**：同上
**修复**：同 S3，映射 era→中文名
**风险**：低

---

## 四、战斗卡情报面板（1处）

### C1 — `mod_effect_labels.gd` 缺失 ~40 个 effect key 翻译
**文件**：`scripts/ui/mod_effect_labels.gd:147`
**当前**：未命中的 key 走 `_: return key`，裸露原始英文（如 `emp_chance`、`burn_dps`、`nano_pct`、`chem_corrosion` 等）
**根因**：v8.x 新增了 EMP/纳米/化学/燃烧/束能/无人机标记/雷达锁定/石墨弹等大量 effect key，翻译表未同步
**修复**：在 translate() match 分支中补齐 40 个 key（全部已在 data/modification_modules/*.gd 实际使用），完整列表见附录

**风险**：低——纯翻译表扩展，不影响战斗逻辑

---

## 五、执行顺序

| 步骤 | 改动文件 | 预估时间 | 验证方式 |
|------|----------|----------|----------|
| 1 | `modification_panel.gd`（M2,M3,M4,M5）| 10min | headless --check-only |
| 2 | `modification_panel.tscn`（M1）| 2min | 编辑器确认 |
| 3 | `phase_master_skill_panel.gd`（S1,S3）| 10min | headless --check-only |
| 4 | `unlock_labels.gd`（S2,S4）| 5min | headless --check-only |
| 5 | `mod_effect_labels.gd`（C1）| 10min | headless --check-only + 实机查看 |
| **合计** | **5个文件** | **~37min** | Godot --check-only 全部通过 |

---

## 六、不做的事（范围外）

| 项 | 原因 |
|----|------|
| 删除 `name_en` 字段（181个） | 死数据但不影响显示，删除需改所有 mod 数据文件，收益低 |
| 改 `prototype` 字段语义 | 内部字段，改动涉及面广，本次只修显示 |
| 补充 skill tree 节点描述 | 节点 name/desc 已是中文，无问题 |
| 改 card_info_panel 其他英文 | 主显示路径已通过 ModEffectLabels 翻译，无遗漏 |

---

## 七、验证清单

- [ ] `--check-only` 无语法错误（133卡构建）
- [ ] 改造面板进度条显示：杂兵/老兵/精英/勇士/霸主
- [ ] 改造面板战力块显示：`精英`（不重复，无 POWER）
- [ ] 改造面板 tooltip 不再显示 prototype 行
- [ ] 技能树节点解锁提示：`相位仪：擎天-战术核心`（非原始ID）
- [ ] 技能树总览Tab：`相位仪：擎天-战术核心`
- [ ] 技能树进化提示：`进化解锁[二战]`（非`时代1`）
- [ ] 情报面板改造效果：`emp_chance+30%` → `EMP概率+30%`
- [ ] 游戏内实机：改造面板、技能树、情报面板各打开确认

---

## 附：C1 完整翻译表（40个新增 key）

```gdscript
"emp_chance": return "EMP概率"
"emp_true_damage": return "EMP真伤"
"emp_true_damage_bonus": return "EMP增伤"
"emp_reflect_trigger": return "EMP反射触发"
"burn_chance": return "燃烧概率"
"burn_dps": return "燃烧DPS"
"burn_dps_mult": return "燃烧倍率"
"burn_duration": return "燃烧持续"
"chem_chance": return "化毒概率"
"chem_dps": return "化毒DPS"
"chem_duration": return "化毒持续"
"chem_corrosion": return "腐蚀"
"chem_pollute": return "污染"
"nano_chance": return "纳米概率"
"nano_pct": return "纳米占比"
"nano_duration": return "纳米持续"
"nano_spread_trigger": return "纳米扩散触发"
"nano_concentration_amp": return "纳米浓缩"
"nano_seeder_amount": return "纳米播撒量"
"incendiary_chance": return "燃烧弹概率"
"incendiary_stacks": return "燃烧弹层数"
"incendiary_synergy": return "燃烧协同"
"graphite_chance": return "石墨弹概率"
"graphite_stacks": return "石墨弹层数"
"graphite_execute": return "石墨执行"
"graphite_amp": return "石墨增幅"
"laser_resonance_chance": return "激光共振概率"
"laser_resonance_stacks": return "激光共振层数"
"beam_damage_bonus": return "束能伤害"
"beam_split_trigger": return "束能分裂触发"
"beam_reflect_trigger": return "束能反射触发"
"weakpoint_trigger": return "弱点触发"
"weakpoint_bonus": return "弱点伤害"
"true_damage": return "真伤"
"radar_lock_interval": return "雷达锁定间隔"
"radar_lock_radius": return "雷达锁定半径"
"radar_lock_vuln": return "雷达锁定易伤"
"radar_lock_duration": return "雷达锁定持续"
"drone_mark_amp": return "无人机增幅"
"drone_mark_vuln_bonus": return "无人机易伤"
"drone_mark_radius_bonus": return "无人机半径"
"chem_burst_trigger": return "化毒burst触发"
"vfx_variant": return "特效变体"
```
