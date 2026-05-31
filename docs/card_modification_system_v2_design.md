# 卡片改造系统 v2.0 设计方案

> 简化版：以情报书掉落 + 战力门槛为核心，移除升星/研究点/许可证系统

---

## 一、设计总览

### 保留（4个系统）
1. **强化 Lv1-10** — 纳米材料消耗，100%成功率（不变）
2. **20种MOD改造** — 同类型冲突规则不变，门槛改为情报书+战力
3. **7势力×10级** — 不变
4. **9种敌源改造D槽** — 不变，门槛改为情报书+战力

### 删除
- 升星系统(1-9★) 及其研究点消耗表
- 许可证系统（通用/分类/专属）
- blueprint_star_config.gd 大部分功能
- research_points 相关所有代码
- card_progression_settings.gd 中的研究点倍率

### 新增核心机制
- **改造情报书**： consumable（可重复获取），通过战斗掉落
- **战力门槛**：每MOD槽位有固定的战力要求，基于卡牌基础战力

---

## 二、改造情报书（Modification Intel Book）

### 2.1 情报书定义

共 **29种** 情报书，与MOD一一对应：

| 情报书ID | 名称 | 对应MOD | 品质 |
|---------|------|---------|------|
| BOOK_MOD_01 | 火力改造情报书 | MOD_01 | R |
| BOOK_MOD_02 | 装甲改造情报书 | MOD_02 | R |
| BOOK_MOD_03 | 机动改造情报书 | MOD_03 | R |
| BOOK_MOD_04 | 射程改造情报书 | MOD_04 | R |
| BOOK_MOD_05 | 穿甲专精情报书 | MOD_05 | SR |
| BOOK_MOD_06 | 高爆专精情报书 | MOD_06 | SR |
| BOOK_MOD_07 | 防空专精情报书 | MOD_07 | SR |
| BOOK_MOD_08 | 快速装填情报书 | MOD_08 | R |
| BOOK_MOD_09 | 精确瞄准情报书 | MOD_09 | R |
| BOOK_MOD_10 | 战场维修情报书 | MOD_10 | SR |
| BOOK_MOD_11 | 能量效率情报书 | MOD_11 | SR |
| BOOK_MOD_12 | 纳米装甲情报书 | MOD_12 | SR |
| BOOK_MOD_13 | 过载射击情报书 | MOD_13 | SR |
| BOOK_MOD_14 | 范围溅射情报书 | MOD_14 | SR |
| BOOK_MOD_15 | 护盾生成情报书 | MOD_15 | SR |
| BOOK_MOD_16 | 死亡自爆情报书 | MOD_16 | SSR |
| BOOK_MOD_17 | 回收利用情报书 | MOD_17 | R |
| BOOK_MOD_18 | 双倍供弹情报书 | MOD_18 | SR |
| BOOK_MOD_19 | 硬化装甲情报书 | MOD_19 | SR |
| BOOK_MOD_20 | 电磁脉冲情报书 | MOD_20 | SSR |
| BOOK_EOM_INFANTRY_01 | 步兵战术手册 | EOM_INFANTRY_01 | SR |
| BOOK_EOM_FLAME_01 | 热能抗性手册 | EOM_FLAME_01 | SR |
| BOOK_EOM_ARMOR_01 | 反应装甲手册 | EOM_ARMOR_01 | SR |
| BOOK_EOM_ARTILLERY_01 | 弹道校准手册 | EOM_ARTILLERY_01 | SR |
| BOOK_EOM_STEALTH_01 | 光学迷彩手册 | EOM_STEALTH_01 | SR |
| BOOK_EOM_AIR_01 | 精确打击手册 | EOM_AIR_01 | SR |
| BOOK_EOM_BOSS_NANO | 纳米再生手册 | EOM_BOSS_NANO | SSR |
| BOOK_EOM_SCOUT_01 | 战术侦察手册 | EOM_SCOUT_01 | R |
| BOOK_EOM_COMMAND_01 | 战术指挥手册 | EOM_COMMAND_01 | SR |

### 2.2 品质与掉率

| 品质 | 掉落权重 | 说明 |
|------|---------|------|
| R（常规） | 50 | 常见MOD的情报书 |
| SR（稀有） | 35 | 进阶MOD的情报书 |
| SSR（超稀有） | 15 | 顶级MOD的情报书 |

> 具体每本书的掉落权重在品质权重基础上二次分配，详见 §2.4

### 2.3 掉落来源

| 来源 | 情报书品质范围 | 掉率倍率 | 备注 |
|------|--------------|---------|------|
| 普通关卡胜利 | R ~ SR | ×1.0 | 基础掉率约 15% |
| 精英关卡胜利 | R ~ SSR | ×1.5 | 基础掉率约 22% |
| BOSS关卡胜利 | SR ~ SSR | ×2.0 | 基础掉率约 30% |
| 指定敌人首次击破 | 对应类型 | 保证1本 | 首次必掉（如首次击破重装甲敌人必掉BOOK_MOD_02或BOOK_EOM_ARMOR_01） |

**掉落类型关联**：

| 敌人类型 | 优先掉落的情报书 |
|---------|-----------------|
| 步兵 | BOOK_MOD_01, BOOK_MOD_02, BOOK_MOD_10, BOOK_MOD_17, BOOK_EOM_INFANTRY_01 |
| 火焰兵 | BOOK_MOD_08, BOOK_MOD_13, BOOK_EOM_FLAME_01 |
| 重装甲 | BOOK_MOD_02, BOOK_MOD_05, BOOK_MOD_12, BOOK_MOD_19, BOOK_EOM_ARMOR_01 |
| 火炮 | BOOK_MOD_04, BOOK_MOD_09, BOOK_MOD_14, BOOK_EOM_ARTILLERY_01 |
| 隐匿 | BOOK_MOD_03, BOOK_MOD_09, BOOK_EOM_STEALTH_01 |
| 空中 | BOOK_MOD_06, BOOK_MOD_07, BOOK_EOM_AIR_01 |
| 纳米BOSS | BOOK_MOD_10, BOOK_MOD_15, BOOK_EOM_BOSS_NANO |
| 侦察 | BOOK_MOD_03, BOOK_MOD_09, BOOK_EOM_SCOUT_01 |
| 指挥 | BOOK_MOD_17, BOOK_MOD_20, BOOK_EOM_COMMAND_01 |

> 掉落在关联池内随机，非关联池也有小概率掉（20%概率跨池）。

### 2.4 每本书的掉落权重

**R品质（权重合计占R池）**：

| 情报书ID | 权重 |
|---------|------|
| BOOK_MOD_01 | 15 |
| BOOK_MOD_02 | 12 |
| BOOK_MOD_03 | 12 |
| BOOK_MOD_04 | 10 |
| BOOK_MOD_08 | 10 |
| BOOK_MOD_09 | 10 |
| BOOK_MOD_17 | 11 |
| BOOK_EOM_SCOUT_01 | 10 |
| BOOK_EOM_INFANTRY_01 | 10 |

**SR品质（权重合计占SR池）**：

| 情报书ID | 权重 |
|---------|------|
| BOOK_MOD_05 | 8 |
| BOOK_MOD_06 | 8 |
| BOOK_MOD_07 | 8 |
| BOOK_MOD_10 | 6 |
| BOOK_MOD_11 | 6 |
| BOOK_MOD_12 | 6 |
| BOOK_MOD_13 | 6 |
| BOOK_MOD_14 | 6 |
| BOOK_MOD_15 | 6 |
| BOOK_MOD_18 | 6 |
| BOOK_MOD_19 | 6 |
| BOOK_EOM_FLAME_01 | 6 |
| BOOK_EOM_ARMOR_01 | 5 |
| BOOK_EOM_ARTILLERY_01 | 5 |
| BOOK_EOM_STEALTH_01 | 5 |
| BOOK_EOM_AIR_01 | 5 |
| BOOK_EOM_COMMAND_01 | 5 |

**SSR品质（权重合计占SSR池）**：

| 情报书ID | 权重 |
|---------|------|
| BOOK_MOD_16 | 35 |
| BOOK_MOD_20 | 30 |
| BOOK_EOM_BOSS_NANO | 35 |

### 2.5 情报书使用规则

- **消耗型**：每安装1次MOD消耗1本对应情报书（可重复安装/替换）
- **拥有后即可安装**：背包中有对应情报书 + 卡牌战力达标 → 可安装
- **安装消耗情报书**：从背包扣除1本
- **替换消耗情报书**：同类型冲突替换也需要消耗新MOD的情报书（旧MOD的情报书不返还）

---

## 三、战力门槛

### 3.1 战力定义

使用 **卡牌基础战力（base_power）**，即 `card.power` 字段。
> 不使用强化后战力，避免"强化→装改造→战力更高→装更多改造"的循环。

### 3.2 槽位战力门槛

每张卡的改造槽位（0-based）有固定的战力门槛要求：

| 改造槽位(0-based) | 战力门槛 | 设计意图 |
|-------------------|---------|---------|
| 0                 | 0       | 任何卡都能装第一个MOD |
| 1                 | 250     | 2★级别卡才够 |
| 2                 | 600     | 3★级别卡 |
| 3                 | 1200    | 4★级别卡 |
| 4                 | 2200    | 5★级别卡 |
| 5                 | 3800    | 6★级别卡 |
| 6                 | 6000    | 7★级别卡（高稀有度卡） |
| 7                 | 8500    | 顶级卡专属 |
| 8                 | 12000   | 传说级专属 |

> 门槛与现有星级分界对齐：1★(0-250), 2★(250-600), 3★(600-1200), 4★(1200-2200), 5★(2200-3800), 6★(3800-6000), 7★(6000+)

### 3.3 敌源改造D槽门槛

| D槽 | 战力门槛 | 说明 |
|-----|---------|------|
| 0   | 600     | 3★以上卡可用 |
| 1   | 2200    | 5★以上卡可用 |
| 2   | 6000    | 7★以上卡可用 |

### 3.4 敌源改造等级门槛

D槽的敌源改造等级不再由素材情报进度决定，改为由 **情报书品质** 决定：

| 情报书品质 | 解锁敌源改造等级 |
|-----------|----------------|
| R         | T1（基础）       |
| SR        | T2（进阶）       |
| SSR       | T3（顶级）       |

> 玩家获得更高品质的情报书后，可升级已有的敌源改造。
> 升级消耗：1本新品质的情报书。

---

## 四、改造流程（新）

### 4.1 通用MOD安装流程

```
前置检查：
  1. 卡牌 base_power >= 槽位战力门槛？
  2. 背包中有目标MOD的情报书？
  3. 目标MOD与已装MOD不冲突？(同类型则替换)
  4. 已装MOD数量 < 9？

执行：
  1. 从背包扣除1本情报书
  2. 安装MOD到对应槽位（或替换同类型旧MOD）
  3. 更新卡牌属性
```

### 4.2 敌源改造安装流程

```
前置检查：
  1. 卡牌 base_power >= D槽战力门槛？
  2. 背包中有目标敌源MOD的情报书？
  3. 卡牌combat_kind与敌源MOD兼容？
  4. D槽未满？

执行：
  1. 从背包扣除1本情报书
  2. 安装敌源改造到D槽
  3. 效果等级由情报书品质决定（R→T1, SR→T2, SSR→T3）
```

### 4.3 改造不再消耗的资源

- ~~研究点~~ — 删除
- ~~许可证~~ — 删除
- ~~纳米材料~~ — 仅强化消耗，改造不消耗

### 4.4 改造槽位上限

- **通用MOD槽**：最大 9 个（不变）
- **敌源改造D槽**：最大 3 个（不变）
- **势力改造**：不属于槽位系统，是独立变体卡（不变）

---

## 五、势力改造门槛（不变）

势力改造门槛保持原设计不变：
- 加入势力 + 势力声望等级解锁对应等级的势力变体
- 不涉及情报书或战力门槛
- 势力改造生成独立的变体卡（如"钢壁·虎式坦克 III型"），不占用原卡MOD槽

---

## 六、数据结构变更

### 6.1 情报书物品定义（新增）

```gdscript
# data/mod_intel_books.gd
class_name ModIntelBooks

const BOOK_DATA: Dictionary = {
    "BOOK_MOD_01": {"name": "火力改造情报书", "mod_id": "MOD_01", "rarity": "R", "weight": 15},
    # ... (完整29条见上方表格)
}

const DROP_TABLE: Dictionary = {
    "r": {  # R品质池
        "base_rate": 0.10,  # 10%基础概率
        "books": ["BOOK_MOD_01", "BOOK_MOD_02", ...],
    },
    "sr": {
        "base_rate": 0.05,
        "books": ["BOOK_MOD_05", "BOOK_MOD_06", ...],
    },
    "ssr": {
        "base_rate": 0.02,
        "books": ["BOOK_MOD_16", "BOOK_MOD_20", "BOOK_EOM_BOSS_NANO"],
    },
}

const ENEMY_TYPE_BOOK_POOLS: Dictionary = {
    "infantry": ["BOOK_MOD_01", "BOOK_MOD_02", "BOOK_MOD_10", "BOOK_MOD_17", "BOOK_EOM_INFANTRY_01"],
    "flame": ["BOOK_MOD_08", "BOOK_MOD_13", "BOOK_EOM_FLAME_01"],
    # ... (完整对应关系见 §2.3)
}
```

### 6.2 战力门槛定义（新增）

```gdscript
# data/mod_power_gates.gd
class_name ModPowerGates

const SLOT_POWER_REQUIREMENTS: Array[int] = [0, 250, 600, 1200, 2200, 3800, 6000, 8500, 12000]

const EOM_SLOT_POWER_REQUIREMENTS: Array[int] = [600, 2200, 6000]

const MAX_MOD_SLOTS: int = 9
const MAX_EOM_SLOTS: int = 3
```

### 6.3 BlueprintManager 需删除/修改的代码

| 操作 | 函数/字段 | 说明 |
|------|----------|------|
| 删除 | `get_research_points()` / `add_research_points()` | 研究点系统 |
| 删除 | `get_blueprint_star()` / 升星相关函数 | 升星系统 |
| 删除 | `blueprint_star_data` / `blueprint_copies` | 星级数据 |
| 删除 | 许可证相关所有代码 | 许可证系统 |
| 重写 | `can_apply_modification()` | 改为情报书+战力检查 |
| 重写 | `apply_modification()` | 改为消耗情报书 |
| 新增 | `has_intel_book(book_id)` | 检查背包情报书 |
| 新增 | `consume_intel_book(book_id)` | 消耗情报书 |

### 6.4 DropManager 修改

| 操作 | 说明 |
|------|------|
| 新增 | 战斗胜利时按敌人类型 + 关卡类型从情报书掉落池中抽取 |
| 新增 | 首次击破特定敌人类型保证掉落关联情报书 |
| 新增 | 情报书加入背包系统 |

---

## 七、迁移计划

### Phase 1：新增文件
1. `data/mod_intel_books.gd` — 情报书定义 + 掉落池
2. `data/mod_power_gates.gd` — 战力门槛定义

### Phase 2：修改文件
3. `managers/evolution/mod_manager.gd` — 重写门槛检查逻辑
4. `managers/drop_manager.gd` — 新增情报书掉落
5. `managers/blueprint_manager.gd` — 删除升星/研究点/许可证代码
6. `scenes/ui/upgrade_panel.gd` — UI适配新门槛显示

### Phase 3：删除/清理
7. `data/blueprint_star_config.gd` — 大部分删除，仅保留词缀池部分（如仍需要）
8. `data/card_progression_settings.gd` — 删除研究点倍率相关
9. 存档迁移代码 — 旧存档中的星级/研究点/许可证转换为等效情报书

### Phase 4：存档兼容
10. 旧存档已有改造的卡 → 保留改造，不回收
11. 旧存档的研究点 → 按 1:100 转换为纳米材料
12. 旧存档的许可证 → 按持有数量随机转换为对应类型情报书
