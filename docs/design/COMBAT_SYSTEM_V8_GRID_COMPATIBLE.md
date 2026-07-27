# Phase War v8.x — 格子战斗兼容版技能体系重写方案

> **⚠️ 架构修正（v8.x 重构后）**：三维攻防系统（LIGHT/ARMOR/AIR + weapon_slots）**保持封闭**，不新增 CombatKind 枚举值。新兵种（渗透者/工程师/电子战/狙击手）完全走**纯标签层**（tags + meta + TAG_COUNTER_RULES + 兵种机制），归入现有主类（多为 LIGHT），不侵入 `get_attack_vs` 的三维数值路径。本文档原"5维克制系统"章节已过时，请以"标签层兵种机制"为准。
>
> **本方案是对 v8 初版设计的重写**。基于引擎能力审计，把所有不可实现的技能（涉及移动/传送/暂停/命中率）替换为格子战斗兼容版本，并新增"卡片定时触发技能"机制承载复杂战术效果。
>
> **设计原则**：
> 1. **零移动**——所有技能不依赖单位移动（格子战单位锁槽位，velocity=ZERO）
> 2. **被动+光环+定时触发为主**——不增加主动操作负担
> 3. **复杂机制改为"卡片技能"**——特定平台卡部署后按周期自动施放（复用 `PhaseInstrumentAbilities` periodic 引擎）
> 4. **战法系统=阵容检测+自动Buff**——入场时检测兵种组合，满足条件自动生效
>
> **引擎审计结论**：
> - ✅ 已支持：周期触发、定时 Buff、护盾、标记（4 种）、易伤、暴击加成、伤害反射、护阵光环、慢速光环、矿场 DoT、复活（限 1 次/场）、条件型 stat_bonus、堆叠加成
> - ⚠️ 需扩展：标签层兵种机制（TAG_COUNTER_RULES + meta）、新标记类型、斩杀阈值、召唤临时单位
> - ❌ 架构冲突：移动/传送/暂停/减命中率/减能量（已全部替换）

---

## 目录

1. [引擎能力映射表](#一引擎能力映射表)
2. [卡片定时技能系统（核心新机制）](#二卡片定时技能系统核心新机制)
3. [4 家族 × 15 技能（重写版，60 个）](#三4-家族--15-技能重写版60-个)
4. [标签层兵种机制](#四标签层兵种机制v8x-重构后架构)
5. [特殊兵种机制（格子兼容版）](#五特殊兵种机制格子兼容版)
6. [战法系统（18 个）](#六战法系统18-个)
7. [技能树节点扩展（40 节点）](#七技能树节点扩展40-节点)
8. [实施优先级](#八实施优先级)
9. [与原方案差异对照](#附录-a与原方案的差异对照表)

---

## 一、引擎能力映射表

每个新技能都映射到**已存在的引擎能力**或**最小增量扩展**：

| 引擎能力 | 现有实现位置 | 承载的新技能类型 |
|---------|------------|---------------|
| `periodic` 周期触发 | `phase_instrument_abilities._tick_periodic` | 卡片定时技能（火炮连发/核轰/酸雨/狂暴/全图伤害/区域 DoT） |
| `on_battle_start` 开局触发 | `_fire_start_abilities` | 开局护盾/全图标记/初始 Buff |
| `add_shield()` 护盾 | `mega_shield` / module_effect_handler | 临时护盾、伤害吸收 |
| `_apply_mark` 易伤标记 | module_effect_handler L502 | "暴露"、"燃烧"、"标记"类效果 |
| `_apply_crit_mark` 暴击标记 | L519 | "感电"、"易暴"类效果 |
| `_apply_armor_break` 破甲标记 | L483 | "装甲腐蚀"、"熔毁" |
| `_check_dodge` 闪避 | L234 | "虚化"、"相位偏移" |
| `damage_reduction` 减伤 | L229 | "要塞化"、"暗物质装甲" |
| `_revive_unit` 复活 | L583 | "余烬重生"、"凤凰涅槃" |
| `command_aura` 指挥光环 | L708 | 各种增益光环（要塞/指挥/电子） |
| `slow_aura` 慢速光环 | L695 | "引力井"、"电网封锁"、"酸雨减速" |
| `minefield_damage` 区域 DoT | L741 | "焦土"、"火墙"、"熵增领域" |
| `death_heal_allies` 死亡触发 | L644 | 死亡自爆、死亡护盾 |
| `conditional` 条件 Buff | phase_master_skill_tree | "HP<X% 触发"、"存活>X 秒触发" |
| `stacking_bonus` 堆叠加成 | faction_skill_tree | "数量增益"、"层数叠加" |
| **新增**：标签硬克制（TAG_COUNTER_RULES） | 扩展 `bullet.gd` 调用 `compute_tag_counter_multiplier` | 标签层兵种差异化伤害 |
| **新增**：斩杀阈值检测 | 扩展 `take_damage` | 斩杀类技能 |
| **新增**：召唤临时单位 | 扩展 `battle_spawn_system` | "钢铁风暴"召唤傀儡 |
| **新增**：标签 filter | 扩展 `_get_counter_priority` | SNIPER 锁 Boss、STEALTH 优先指挥 |

---

## 二、卡片定时技能系统（核心新机制）

### 2.1 设计理念

> **复杂战术效果不再依赖"单位移动/传送"，而是某些特定平台卡部署后，按固定周期自动施放技能。**

例：
- "火炮指挥车"卡片部署后，每 15s 自动对敌方密集区发动火炮齐射
- "电子战平台"卡片部署后，每 8s 对敌方最高威胁单位施加 EMP（攻速-60%）
- "虚空相位仪"卡片部署后，每 30s 标记一个 HP<30% 敌方单位直接斩杀

**为什么这样做？**
- 单位不能移动（槽位锁定），但"卡片定时技能"等于把"单位技能"抽象成"周期性全局效果"
- 玩家只需把特定卡片放进阵容，不需要手动操作
- 复用现有 `PhaseInstrumentAbilities` 的 periodic 引擎，零架构改动

### 2.2 技术实现

**完全复用现有 `PhaseInstrumentAbilities` 引擎模式**，新增 `card_periodic_skills.gd` 作为数据层：

```gdscript
# data/card_periodic_skills.gd（新建）
class_name CardPeriodicSkills
extends RefCounted

## 卡片定时技能定义
## skill_id → { trigger, interval, source_tag, effect, vfx, ... }
## 由 CardPeriodicSkillEngine（新引擎，复用 PhaseInstrumentAbilities 模式）驱动

const SKILLS: Dictionary = {
    "cps_artillery_coord": {
        "id": "cps_artillery_coord",
        "name": "炮兵协调射击",
        "trigger": "periodic",
        "interval": 15.0,
        "source_tag": "artillery",       # 需要场上存在此标签的单位才触发
        "min_source_count": 1,
        "effect": {
            "type": "area_damage",
            "target": "enemy_densest_cluster",  # 锁定敌方最密集区域
            "radius": 120,
            "damage_pct_atk": 1.5,        # 平均友军 ATK × 1.5
            "vfx": "artillery_barrage"
        }
    },
    "cps_emp_strike": {
        "id": "cps_emp_strike",
        "name": "EMP 打击",
        "trigger": "periodic",
        "interval": 12.0,
        "source_tag": "ecm",
        "min_source_count": 1,
        "effect": {
            "type": "debuff_target_highest_threat",
            "debuff": "attack_speed_penalty",
            "value": -0.60,
            "duration": 4.0,
            "vfx": "emp_blast"
        }
    },
    # ... 共 20+ 个卡片定时技能
}
```

### 2.3 引擎接入

```gdscript
# managers/battle/card_periodic_skill_engine.gd（新建，RefCounted）
# 由 battle_manager._process(delta) 每帧调用 update(delta)
# 每个技能维护独立计时器，到时检测 source_tag 单位是否在场，触发 effect

func update(delta: float) -> void:
    for skill_id in _active_skills:
        var skill = CardPeriodicSkills.SKILLS[skill_id]
        if skill.trigger != "periodic": continue
        _timers[skill_id] += delta
        if _timers[skill_id] >= skill.interval:
            _timers[skill_id] = 0.0
            if _has_source_units(skill.source_tag, skill.min_source_count):
                _execute_effect(skill)
```

**接入点**：`battle_manager._process()` 在 `PhaseInstrumentAbilities.update(delta)` 后调用 `CardPeriodicSkillEngine.update(delta)`。

---

## 三、4 家族 × 15 技能（重写版，60 个）

### 3.1 钢铁家族（STEEL）— 主题：阵地战 / 工程 / 持久消耗

| # | 技能 | 类型 | 实现 | 效果 |
|---|------|------|------|------|
| S1 | **钢铁壁垒** | 卡片定时 | source=fort，每 20s | 为全体 FORT 单位附加 2000 护盾（持续 10s），护阵范围内友军+10% 减伤 |
| S2 | **装甲集火** | 战法（自动） | 阵容检测 | 场上≥2 ARMOR 时激活：所有 ARMOR 单位对当前最高威胁敌方+25% 伤害（替代原"冲锋"） |
| S3 | **要塞化协议** | 被动光环 | fort_aura | FORT 单位相邻友军+10% 减伤、+15% 防御；FORT 单位免疫击退 |
| S4 | **机械维修站** | 卡片定时 | source=engineer，每 10s | 全体机械单位恢复 3% 最大 HP（替代原"召唤维修站实体"） |
| S5 | **反坦克雷区** | 卡片定时 | source=engineer，每 18s | 在敌方最密集区施加 minefield_damage（半径 100，每秒 80 伤害，持续 8s），对 ARMOR 额外+50% |
| S6 | **纵深防御** | 条件被动 | conditional | 后排单位（无敌方邻接 3 格）攻击+15%；前排单位防御+20% |
| S7 | **弹道计算所** | 卡片定时 | source=artillery，每 25s | 标记敌方最密集区（半径 150），10s 内所有 ARTILLERY 攻击该区域+100% 伤害 |
| S8 | **钢铁洪流** | 卡片定时 | source=armor，每 22s | 为最近 3 个 ARMOR 单位附加 1500 护盾（持续 8s），护盾存在期间攻击+15% |
| S9 | **阵地加固** | 被动 | stat_bonus | FORT 单位部署速度+50%（部署时间减半）；FORT 死亡时 5s 内周围友军+15% 防御（death_buff） |
| S10 | **交叉火力网** | 卡片定时 | source=mg/fort，每 20s | 标记 2 个敌方单位（持续 6s），被标记单位受到所有伤害+30%，攻速-30%（压制） |
| S11 | **装甲回收** | 卡片定时 | source=engineer，每 30s | 复活最近死亡的友军机械单位（50% HP，持续 8s 后消失），复活单位攻击+30% |
| S12 | **钢铁意志** | 条件被动 | conditional | 全体友军 HP<25% 时防御×1.8（不与减伤叠加），并清除所有 debuff |
| S13 | **炮火准备** | 卡片定时 | source=artillery，每 35s | 3s 后对敌方前排（最近 3 个 slot）造成范围伤害（每单位 200 伤害）+ 攻速-50%（5s 压制） |
| S14 | **工程抢修** | 卡片定时 | source=engineer，每 18s | 清除全体友军所有 debuff + 全体+800 护盾（持续 6s） |
| S15 | **钢铁风暴** ★ | 卡片定时（终极） | source=任意，每 90s | 召唤 3 个临时钢铁傀儡（继承相位师 25% 属性，部署在空槽位，持续 12s，死亡爆炸 200% ATK） |

### 3.2 火焰家族（FLAME）— 主题：燃烧 / 范围压制 / 死亡触发

| # | 技能 | 类型 | 实现 | 效果 |
|---|------|------|------|------|
| F1 | **焦土政策** | 卡片定时 | source=flame，每 16s | 在敌方最密集区施加 minefield_damage（半径 130，每秒 60 火伤，持续 8s），区域内敌方"暴露"：受到伤害+15% |
| F2 | **燃烧弹投射** | 卡片定时 | source=flame，每 12s | 对单个最高威胁敌方造成 200 火伤 +施加 burn_mark（5s 内每秒 40 火伤 + 移速-30%） |
| F3 | **自爆突击** | 卡片定时 | source=flame，每 25s | 选择我方最低星单位，使其下次攻击伤害×3，攻击后该单位立即死亡（自爆，范围 100，60% ATK 火伤） |
| F4 | **烈焰风暴** ★ | 卡片定时（终极） | source=flame，每 80s | 全图每秒施加 burn_mark（持续 10s，每秒 50 火伤），全图敌方"恐慌"：攻速-20%（10s） |
| F5 | **热能感知** | 被动光环 | flame_aura | 全体友军对燃烧/标记状态敌方+30% 伤害、+15% 暴击率；燃烧敌方无法触发闪避 |
| F6 | **烽火信号** | 卡片定时 | source=flame，每 22s | 全体友军攻速+25%（持续 8s）+ 暴击+10%（替代原"全图信标"） |
| F7 | **熔毁** | 卡片定时 | source=flame，每 30s | 牺牲我方最低 HP 单位，对敌方最高威胁单位造成 500 火伤 + 3s 内无法恢复 HP（heal_block 标记） |
| F8 | **火焰庇护** | 卡片定时 | source=flame，每 18s | 全体友军获得火焰护盾（持续 6s，吸收 800 伤害，存在期间免疫燃烧 debuff） |
| F9 | **炼狱领域** | 被动 | death_trigger | 友军击杀单位时触发小范围自爆（80% ATK 火伤，半径 60）；火焰技能范围+30% |
| F10 | **爆裂燃料** | 卡片定时 | source=flame，每 16s | 为 3 个随机友军涂覆燃料（持续 10s），下次攻击命中产生二次爆炸（范围 80，50% ATK 火伤） |
| F11 | **高温气浪** | 卡片定时 | source=flame，每 14s | 对全体敌方造成 50% ATK 伤害 + 施加 armor_break（5s，防御-25%） |
| F12 | **焚城** ★ | 卡片定时（终极） | source=flame，每 100s | 全图轰炸（复用 nuclear_bombardment VFX），每敌方 250 火伤 + burn_mark（8s）+ 30% 概率眩晕 1s |
| F13 | **余烬重生** | 被动 | death_revive | 火焰单位死亡时 25% 概率以 30% HP 复活（每场每单位限 1 次），复活后 5s 内攻击×1.8 |
| F14 | **火焰传导** | 卡片定时 | source=flame，每 18s | 将 1 个燃烧状态"传染"给最多 5 个邻近敌方（每个 burn_mark 4s，每秒 35 火伤） |
| F15 | **太阳耀斑** | 卡片定时 | source=flame，每 35s | 全体敌方获得 mark（5s 内受到伤害+25%），全图燃烧敌方显形（清除 stealth 标记） |

### 3.3 雷霆家族（THUNDER）— 主题：速度 / 连锁 / 电子战

| # | 技能 | 类型 | 实现 | 效果 |
|---|------|------|------|------|
| T1 | **EMP 瘫痪** | 卡片定时 | source=ecm，每 12s | 对最高威胁敌方施加 attack_speed_penalty（-60%，4s）+ 该单位能量恢复归零（4s，仅敌方相位师） |
| T2 | **闪电链** | 卡片定时 | source=thunder，每 10s | 从最高 ATK 友军释放闪电链（弹跳 5 次，每次 70% ATK 雷伤，对 ARMOR+50%） |
| T3 | **电子战干扰** | 被动光环 | ecm_aura | 半径 250 内敌方攻速-25%、暴击-15%、闪避-20%（替代原"减命中率"，改用现有 stat） |
| T4 | **超视距打击** | 卡片定时 | source=sniper，每 18s | 标记最高威胁敌方（持续 10s），全体友军对其+30% 伤害 + 该单位受到暴击+20% |
| T5 | **风暴突击** | 战法（自动） | 阵容检测 | 场上≥2 FAST 单位时激活：FAST 单位攻速+30%、暴击+15%（替代原"冲锋移动"） |
| T6 | **雷电过载** | 条件被动 | conditional | 场上友军数>敌方数时，每多 1 个全体攻速+5%（上限+25%）+ 移速+3%（上限+15%） |
| T7 | **感应雷暴** | 卡片定时 | source=thunder，每 20s | 在敌方前排 3 个 slot 施加 minefield_damage（每秒 60 雷伤，8s），触发时连锁 2 次（50% 伤害） |
| T8 | **电磁轨道炮** | 卡片定时 | source=sniper，每 30s | 对最高 HP 敌方造成 350% ATK 伤害（无视 50% 防御，走 penetration） |
| T9 | **蜂群无人机** | 卡片定时 | source=air，每 25s | 8s 内全体友军攻击附带额外 15% ATK 雷伤（模拟无人机辅助攻击，替代原"召唤实体无人机"） |
| T10 | **静电护盾** | 卡片定时 | source=thunder，每 18s | 全体友军获得静电护盾（持续 6s，吸收 600 伤害，存在期间近战攻击其的敌方有 30% 概率被反伤 50% ATK） |
| T11 | **精准突击** | 卡片定时 | source=sniper，每 20s | 选择我方最高 ATK 单位，5s 内其攻击伤害×2 + 射程+50%（替代原"瞬移突击"） |
| T12 | **天罚雷阵** ★ | 卡片定时（终极） | source=thunder，每 100s | 全图随机 15 道闪电（每道 180 雷伤，对机械×2），全图敌方"感电"：5s 内受到伤害+15% |
| T13 | **充能爆发** | 条件被动 | conditional | 每拥有 10 点能量，全体攻速+2%（上限+30%）；满能量时触发"过充能"：全体攻击+20%（5s，CD 30s） |
| T14 | **电网封锁** | 卡片定时 | source=thunder，每 22s | 在敌方中排施加 slow_aura（半径 200，移速-50%，攻速-30%，持续 8s） |
| T15 | **量子纠缠打击** | 卡片定时 | source=thunder，每 28s | 标记 2 个敌方（HP 最高 + 威胁最高），3s 后同时受到 200 雷伤；若都存活则额外各受 100 伤害 |

### 3.4 虚空家族（VOID）— 主题：空间标记 / 时间迟缓 / 斩杀

| # | 技能 | 类型 | 实现 | 效果 |
|---|------|------|------|------|
| V1 | **维度干扰** | 卡片定时 | source=void，每 20s | 对随机 3 个敌方施加"混乱"标记（持续 6s，攻速-40%，移速-30%；模拟维度错位，替代原"传送敌方"） |
| V2 | **时间迟缓** | 卡片定时 | source=void，每 30s | 全体敌方施加 slow_aura（持续 4s，移速-50%、攻速-50%；替代原"暂停"） |
| V3 | **暗影吞噬** | 卡片定时 | source=void，每 25s | 对 HP<40% 的最低 HP 敌方立即造成 500 虚空伤（斩杀意图）；若击杀，施放者+10% 最大 HP |
| V4 | **熵增领域** | 卡片定时 | source=void，每 25s | 在敌方最密集区施加 minefield_damage（半径 200，每秒 1% 最大 HP，持续 10s）+ 该区域敌方能量恢复-50% |
| V5 | **相位偏移** | 被动光环 | void_aura | 全体友军 dodge_chance+15%；每 8s 有 30% 概率完全免疫下一次伤害（虚化） |
| V6 | **引力井** | 卡片定时 | source=void，每 20s | 在敌方最密集区施加 slow_aura（半径 200，移速-50%，攻速-25%，持续 6s）+ 每秒 30 虚空伤 |
| V7 | **灵魂抽取** | 卡片定时 | source=void，每 18s | 对最高 HP 敌方造成 200 虚空伤，伤害的 50% 转化为护盾分配给随机友军 |
| V8 | **暗物质装甲** | 被动 | conditional | 全体友军受到致命伤时减伤 50%（每场每单位限触发 1 次）；触发后 5s 内攻击+15% |
| V9 | **镜像标记** | 卡片定时 | source=void，每 35s | 标记最高 HP 敌方（持续 8s），期间该单位受到的伤害 50% 反弹给其自身（伤害反弹，替代原"复制单位"） |
| V10 | **相位锚点** | 卡片定时 | source=void，每 30s | 标记我方最高 HP 单位为"锚点"（持续 10s），期间全体友军每秒恢复 2% HP + 8% 护盾（替代原"传送门"） |
| V11 | **现实崩溃** | 卡片定时 | source=void，每 60s | 检测所有 HP<15% 敌方：普通单位直接斩杀，精英/Boss 降至 15% HP + 5s 内无法恢复 |
| V12 | **湮灭之光** ★ | 卡片定时（终极） | source=void，每 120s | 3s 蓄力后全图 300% ATK 虚空伤；HP<30% 的普通敌方直接斩杀 |
| V13 | **时间回溯** ★ | 卡片定时（终极） | source=void，每 90s | 全体友军恢复 30% 最大 HP + 清除所有 debuff + 重置所有技能 CD（替代原"位置回溯"） |
| V14 | **虚空侵蚀** | 被动 | stacking_debuff | 敌方每次受虚空伤害+1 层"侵蚀"（每层-2% HP，上限 5 层，10s）；死亡时爆炸（层数×30 虚空伤） |
| V15 | **维度叠加** ★ | 卡片定时（终极） | source=void，每 150s | 全体友军 12s 内 dodge_chance+40%、受到伤害-30%、攻击有 25% 概率溅射（替代原"分身"） |

---

## 四、标签层兵种机制（v8.x 重构后架构）

> **⚠️ 架构修正**：原"5维兵种克制系统"已废弃。三维攻防系统（LIGHT/ARMOR/AIR + weapon_slots）**保持封闭**，不新增 CombatKind 枚举值。新兵种的差异化完全靠**标签层**实现。

### 4.1 架构分层（v8.x 重构后）

```
┌─────────────────────────────────────────────────────┐
│ 三维攻防系统（封闭，不扩展）                          │
│ CombatKind: LIGHT/ARMOR/SUPPORT/AIR/FORT（5值）      │
│ attack_light/armor/air + defense_light/armor/air     │
│ weapon_slots[0=light/1=armor/2=air]                  │
│ 弹道: light→DIRECT, armor→SNIPER, air→MISSILE       │
└───────────────────────┬─────────────────────────────┘
                        │ 新兵种归入现有主类（多为 LIGHT）
                        ▼
┌─────────────────────────────────────────────────────┐
│ 标签层（v8.x 新增，独立于三维系统）                   │
│ card.tags → stats.card_tags meta → _apply_v8_unit_type_meta │
│   → is_stalker/is_sniper/is_ecm/is_engineer meta     │
│ TAG_COUNTER_RULES（8条标签硬克制，bullet.gd 调用）    │
│   sniper→boss+50%, stealth→command+30%, fort→air+40% │
│ 兵种机制（construct_unit._init_unit_mechanisms）      │
│   STALKER隐身/SNIPER首击/ECM光环/ENGINEER触发源       │
└─────────────────────────────────────────────────────┘
```

### 4.2 CombatKind 保持 5 值（v8.x 重构后）

```gdscript
enum CombatKind {
    LIGHT = 0, ARMOR = 1, SUPPORT = 2, AIR = 3, FORT = 4
}
```

三维攻防系统（数值+武器槽+弹道）保持封闭，不扩展。新兵种归入现有主类。

### 4.3 标签硬克制（8 条，独立于三维系统）

| 攻击标签 | 目标条件 | 效果 |
|---------|---------|------|
| `engineer` | 目标正在"施法"（有 casting meta） | 打断施法，目标技能进入 50% CD |
| `sniper` | 目标有 `boss`/`master`/`command` 标签 | 伤害+50%，必命中（无视闪避/隐身） |
| `stealth` | 目标有 `command`/`support` 标签 | 伤害+30% |
| `fort` | 目标有 `aircraft` 标签 | 伤害+40% |
| `artillery` | 目标有 `fort`/`armored` 标签 | 范围伤害+20% |
| `aircraft` | 目标有 `engineer`/`artillery` 标签 | 伤害+30% |
| `fast` | 目标有 `fort` 标签 | 无视目标正面减伤（格子战中=无视 damage_reduction） |

---

## 五、特殊兵种机制（格子兼容版）

### 5.1 渗透者（STALKER）— 格子版

> 原"部署到敌后"不可行（槽位锁定）。改为：

```yaml
兵种标签: stalker
机制:
  部署时:
    - 占用我方 slot（正常部署位置）
    - 前 4 秒"潜行"：受伤害-60%（复用 stealth_grace 机制）
    - 首次攻击伤害×1.5（first_hit_bonus）
  攻击行为:
    - 优先攻击 command/support 标签目标（扩展 _get_counter_priority）
    - 对 command/support 伤害+30%
  克制:
    被 ENGINEER（电子侦测显形）和 ECM 光环（攻速-25%）克制
代表卡牌: recon_platform / stealth_platform
```

### 5.2 工程师（ENGINEER）— 格子版

> 原"建造实体"复杂。改为：

```yaml
兵种标签: engineer
机制:
  定时技能触发源:
    - 场上存在 engineer 标签单位时，触发对应的卡片定时技能
    - 如 cps_repair_aura（每 10s 全体机械+3% HP）
    - 如 cps_minefield（每 18s 敌方密集区布雷）
    - 如 cps_cleanse（每 18s 清除全体 debuff）
  攻击行为:
    - 攻击正在"施法"的敌方时打断（casting meta 检测）
  克制:
    被 AIR 和 ARTILLERY 克制（标签层 TAG_COUNTER_RULES 已设定）
代表卡牌: engineer_platform / support_platform
```

### 5.3 电子战（ECM）— 格子版

> 原"减命中率"不可行（无 accuracy stat）。改为：

```yaml
兵种标签: ecm
机制:
  被动光环（ecm_aura，半径 250）:
    - 敌方攻速-25%
    - 敌方暴击-15%
    - 敌方闪避-20%
  定时技能触发源:
    - cps_emp_strike（每 12s 对最高威胁敌方 EMP：攻速-60%，4s）
  攻击行为:
    - 自身 HP 较低，不主动攻击
  克制:
    被 SNIPER 克制（快速定点清除）
代表卡牌: ecm_platform / drone_platform
```

### 5.4 狙击手（SNIPER）— 格子版

```yaml
兵种标签: sniper
机制:
  射程特性:
    - 超远射程（range_value≥8）
  目标选择:
    - 优先锁定 boss/master/command 标签（扩展 _get_counter_priority）
    - 对该类目标伤害+50%，必命中
  首击加成:
    - 每次切换目标后的第一击伤害×2（first_hit_crit）
  定时技能触发源:
    - cps_railgun（每 30s 对最高 HP 敌方 350% 穿甲伤害）
    - cps_bvr_mark（每 18s 标记最高威胁敌方）
  克制:
    被 AIR 和 ENGINEER（EMP）克制
代表卡牌: sniper_platform / long_range_platform
```

---

## 六、战法系统（18 个）

> **核心**：战法 = 阵容检测 + 自动 Buff。入场时和战斗中持续检测兵种组合，满足条件自动激活全局 stat_bonus。

### 6.1 实现机制

```gdscript
# scripts/battle/tactic_detector.gd（新建）
class_name TacticDetector
extends RefCounted

# 每 1s 检测一次，结果写入 battle_manager 的全局 stat_bonus
func update(delta: float) -> void:
    _timer += delta
    if _timer < 1.0: return
    _timer = 0.0
    var active_tactics = _detect_active_tactics()
    _apply_tactic_buffs(active_tactics)  # 差异更新，移除失效的，添加新激活的

func _detect_active_tactics() -> Array:
    var allies = _get_player_units()
    var counts = _count_by_combat_kind_and_tag(allies)
    var active = []
    for tactic_id in Tactics.DEFINITIONS:
        var def = Tactics.DEFINITIONS[tactic_id]
        if _check_conditions(def.requires, counts, allies):
            active.append(tactic_id)
    return active
```

### 6.2 12 个基础战法

| 战法 | 所需组合 | 效果 |
|------|---------|------|
| **钳形攻势** | ≥2 ARMOR + ≥1 FAST | ARMOR 对最高威胁敌方+25% 伤害 |
| **刺猬防御** | ≥3 FORT + ≥1 ENGINEER | 全体-25% 受伤；FORT 间互相+15% 防御 |
| **新月阵** | ≥2 FAST（左/右分布） | FAST 伤害+30%；中央单位防御+30% |
| **箭矢阵** | ≥3 SNIPER | SNIPER 射程+30%、伤害+25%、必命中 |
| **龟甲阵** | ≥4 FORT | 全体-35% 受伤；部署速度-20% |
| **诱敌深入** | ≥1 FAST（前排）+ ≥3 后排 | FAST 受伤-30%；后排攻击+25% |
| **焦土防线** | ≥2 FLAME 技能 + ≥1 FORT | 全体友军免疫燃烧；火焰伤害+30% |
| **饱和打击** | ≥2 ARTILLERY + ≥1 ECM | ARTILLERY 伤害+50%、射程+20% |
| **斩首行动** | ≥1 SNIPER + ≥1 STALKER + VOID 技能 | 对 boss/master 伤害×2 |
| **声东击西** | ≥1 ECM + ≥2 FAST | FAST 暴击+25%；ECM 受伤-25% |
| **围点打援** | ≥2 FORT + ≥1 ARMOR | FORT 受伤-20%；ARMOR 对新进入范围敌方+50% 伤害 |
| **纵深作战** | ≥3 不同 CombatKind | 全体全属性+10% |

### 6.3 6 个高级战法（需技能树解锁）

| 战法 | 解锁条件 | 效果 |
|------|---------|------|
| **闪电穿插** | 技能树解锁 + ≥3 FAST | FAST 攻速+40%、伤害+30% |
| **天罗地网** | 技能树解锁 + ≥1 STEEL + ≥1 THUNDER 技能 | 全体敌方攻速-30%、移速-30% |
| **虚空降临** | 技能树解锁 + ≥2 VOID 技能 | 全体敌方受到伤害+20% |
| **凤凰涅槃** | 技能树解锁 + ≥2 FLAME 技能 | 全体友军 HP+20%；死亡时 20% 复活 |
| **四维打击** | 技能树解锁 + 4 家族各 1 技能 | 全体友军全属性+25% |
| **诸神黄昏** | 技能树解锁 + 4 终极技能 | 全体友军全属性+40%；敌方每秒-1% HP |

---

## 七、技能树节点扩展（40 节点）

在现有 4 分支各新增 tier 5-12 节点：

### 7.1 指挥分支新增（10 节点）

| ID | Tier | 名称 | 解锁 | 效果 |
|----|------|------|------|------|
| `pms_cmd_5` | 5 | 渗透战术 | unit_mechanism: stalker_stealth | 解锁 STALKER 兵种：前 4s 受伤-60%，首击×1.5 |
| `pms_cmd_6` | 6 | 工兵部队 | unit_mechanism: engineer_build | 解锁 ENGINEER 兵种：定时触发维修/布雷/净化 |
| `pms_cmd_7a` | 7 | 钳形攻势 | tactic: pincer | 解锁战法"钳形攻势" |
| `pms_cmd_7b` | 7 | 刺猬防御 | tactic: hedgehog | 解锁战法"刺猬防御" |
| `pms_cmd_8` | 8 | 军团方阵 | tactic: testudo | 解锁战法"龟甲阵"；全体 FORT+15% HP |
| `pms_cmd_9a` | 9 | 围点打援 | tactic: siege_intercept | 解锁战法"围点打援" |
| `pms_cmd_9b` | 9 | 纵深作战 | tactic: depth_operation | 解锁战法"纵深作战"；单位上限+2 |
| `pms_cmd_10` | 10 | 战术大师 | - | 全部已解锁战法效果+20% |
| `pms_cmd_11` | 11 | 闪电穿插 | tactic: blitz | 解锁高级战法"闪电穿插" |
| `pms_cmd_12` | 12 | 天罗地网 | tactic: sky_net | 解锁高级战法"天罗地网" |

### 7.2 火力分支新增（10 节点）

| ID | Tier | 名称 | 解锁 | 效果 |
|----|------|------|------|------|
| `pms_fp_5` | 5 | 狙击手培养 | unit_mechanism: sniper_training | 解锁 SNIPER 兵种：射程+30%，首击必爆 |
| `pms_fp_6` | 6 | 火炮协调 | card_skill: cps_artillery_coord | 解锁卡片技能：炮兵协调射击 |
| `pms_fp_7a` | 7 | 箭矢阵 | tactic: arrow | 解锁战法"箭矢阵" |
| `pms_fp_7b` | 7 | 饱和打击 | tactic: saturation | 解锁战法"饱和打击" |
| `pms_fp_8` | 8 | 斩首行动 | tactic: decapitation | 解锁战法"斩首行动" |
| `pms_fp_9a` | 9 | 电磁轨道炮 | card_skill: cps_railgun | 解锁卡片技能：电磁轨道炮 |
| `pms_fp_9b` | 9 | 超视距打击 | card_skill: cps_bvr_mark | 解锁卡片技能：超视距标记 |
| `pms_fp_10` | 10 | 火力精通 | - | 全体三维攻击+10%；SNIPER 伤害+25% |
| `pms_fp_11` | 11 | 凤凰涅槃 | tactic: phoenix | 解锁高级战法"凤凰涅槃" |
| `pms_fp_12` | 12 | 四维打击 | tactic: 4d_strike | 解锁高级战法"四维打击" |

### 7.3 智能化分支新增（10 节点）

| ID | Tier | 名称 | 解锁 | 效果 |
|----|------|------|------|------|
| `pms_int_5` | 5 | 电子战 | unit_mechanism: ecm_aura | 解锁 ECM 兵种：光环减敌方攻速/暴击/闪避 |
| `pms_int_6` | 6 | EMP 战术 | card_skill: cps_emp_strike | 解锁卡片技能：EMP 打击 |
| `pms_int_7a` | 7 | 声东击西 | tactic: feint | 解锁战法"声东击西" |
| `pms_int_7b` | 7 | 新月阵 | tactic: crescent | 解锁战法"新月阵" |
| `pms_int_8` | 8 | 自适应护盾 | card_skill: cps_adaptive_shield | 解锁卡片技能：自适应护盾（HP<30% 时自动+2000 护盾） |
| `pms_int_9a` | 9 | 智能维修 | card_skill: cps_repair_aura | 解锁卡片技能：定时维修全体机械 |
| `pms_int_9b` | 9 | 智能净化 | card_skill: cps_cleanse | 解锁卡片技能：定时清除全体 debuff |
| `pms_int_10` | 10 | AI 指挥 | - | 全体友军攻速+15%、暴击+10% |
| `pms_int_11` | 11 | 虚空降临 | tactic: void_descent | 解锁高级战法"虚空降临" |
| `pms_int_12` | 12 | 诸神黄昏 | tactic: ragnarok | 解锁高级战法"诸神黄昏" |

### 7.4 概念武器分支新增（10 节点）

| ID | Tier | 名称 | 解锁 | 效果 |
|----|------|------|------|------|
| `pms_cw_5` | 5 | 钢铁风暴 | card_skill: cps_steel_storm | 解锁卡片技能：召唤钢铁傀儡 |
| `pms_cw_6` | 6 | 焚城 | card_skill: cps_burn_city | 解锁卡片技能：全图火焰轰炸 |
| `pms_cw_7a` | 7 | 天罚雷阵 | card_skill: cps_heaven_thunder | 解锁卡片技能：全图雷击 |
| `pms_cw_7b` | 7 | 湮灭之光 | card_skill: cps_annihilate | 解锁卡片技能：全图虚空伤害+斩杀 |
| `pms_cw_8` | 8 | 时间迟缓 | card_skill: cps_time_slow | 解锁卡片技能：全场减速 |
| `pms_cw_9` | 9 | 现实崩溃 | card_skill: cps_reality_collapse | 解锁卡片技能：斩杀低 HP 敌方 |
| `pms_cw_10` | 10 | 维度叠加 | card_skill: cps_dimension_overlay | 解锁卡片技能：全体虚化 |
| `pms_cw_11` | 11 | 时间回溯 | card_skill: cps_time_rewind | 解锁卡片技能：全体回血+清 debuff |
| `pms_cw_12a` | 12 | 焦土政策 | card_skill: cps_scorched_earth | 解锁卡片技能：区域燃烧 |
| `pms_cw_12b` | 12 | 烈焰风暴 | card_skill: cps_firestorm | 解锁卡片技能：全图燃烧 |

---

## 八、实施优先级

### P0（第一期，纯数据扩展，零引擎改动）

| 模块 | 工作量 | 说明 |
|------|--------|------|
| 标签层兵种机制（TAG_COUNTER_RULES + meta） | ~80 行 | 扩展 `game_constants.gd` + `bullet.gd` 调用 `compute_tag_counter_multiplier` |
| 7 条标签硬克制 | ~80 行 | 扩展 `_get_counter_priority` |
| 技能树 40 节点（纯 stat_bonus/conditional 类） | ~400 行 | 扩展 `phase_master_skill_tree.gd` |
| 战法系统 12 基础 | ~200 行 | 新建 `tactic_detector.gd` + `data/tactics.gd` |

### P1（第二期，新引擎，复用 periodic 模式）

| 模块 | 工作量 | 说明 |
|------|--------|------|
| 卡片定时技能引擎 | ~300 行 | 新建 `card_periodic_skill_engine.gd`（复用 `PhaseInstrumentAbilities` 模式） |
| 卡片定时技能数据 | ~400 行 | 新建 `data/card_periodic_skills.gd`（20 个技能） |
| 斩杀机制扩展 | ~30 行 | 扩展 `take_damage` 增加 HP 阈值检测 |
| 召唤临时单位 | ~100 行 | 扩展 `battle_spawn_system` 支持临时傀儡 |
| 新标记类型 | ~60 行 | 扩展 `module_effect_handler` 增加 heal_block / heal_revert / casting 标记 |

### P2（第三期，特殊兵种接入）

| 模块 | 工作量 | 说明 |
|------|--------|------|
| STALKER 兵种 | ~50 行 | 部署时 stealth_grace + first_hit_bonus |
| ENGINEER 兵种 | ~30 行 | 作为卡片技能触发源 |
| ECM 兵种 | ~40 行 | ecm_aura 被动光环 |
| SNIPER 兵种 | ~40 行 | 目标优先级扩展 + first_hit_crit |

---

## 附录 A：与原方案的差异对照表

| 原方案技能 | 原机制 | 新机制 | 原因 |
|-----------|--------|--------|------|
| S1 钢铁壁垒 | 阻挡子弹的墙 | FORT 定时护盾 | 格子战无子弹物理碰撞 |
| S2 装甲楔入 | 冲锋移动 | 战法：ARMOR 集火 | 单位锁槽位不能移动 |
| S4 机械维修站 | 召唤维修站实体 | 卡片定时全体治疗 | 简化为周期 Buff |
| T5 风暴先锋 | 冲锋移动 | 战法：FAST 攻速暴击 | 单位锁槽位不能移动 |
| T11 瞬移突击 | 传送到敌后 | 卡片定时：单单位 5s 强化 | 槽位锁定会立即拉回 |
| V1 维度裂隙 | 传送敌方 | 卡片定时：混乱 debuff | 敌方也锁槽位 |
| V2 时间停滞 | 暂停单位 | 卡片定时：全场减速 | 无"暂停攻击"API |
| V10 虚空传送门 | 双向传送 | 卡片定时：锚点回血 | 槽位锁定 |
| V13 时间回溯 | 位置回溯 | 卡片定时：HP+debble 清除 | 位置由 slot 决定 |
| STALKER 部署敌后 | 部署到敌方 slot | 潜行+首击强化 | 玩家只能部署 player slot |

---

## 总结

**60 个技能全部格子战斗兼容**：
- 35 个使用现有引擎能力（数据扩展）
- 20 个通过"卡片定时技能"承载（复用 periodic 引擎）
- 5 个通过战法系统承载（阵容检测+Buff）

**核心创新**：
1. **卡片定时技能**——特定平台卡部署后自动按周期施放，无需玩家操作
2. **战法系统**——阵容组合自动激活全局 Buff
3. **标签层兵种机制**——三维攻防系统保持封闭，新兵种靠 tags+meta+TAG_COUNTER_RULES 实现差异化（v8.x 重构后架构）

**实施路径**：P0（纯数据）→ P1（新引擎）→ P2（兵种接入），渐进式，每期可独立验证。

> **⚠️ v8.x 重构修正**：原方案的"5 维克制系统"（CombatKind.ENGINEER/SNIPER + 5×5 矩阵）已废弃。三维攻防系统（LIGHT/ARMOR/AIR + weapon_slots）保持封闭，新兵种完全走纯标签层。详见第四章"标签层兵种机制"。
