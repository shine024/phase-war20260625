# -*- coding: utf-8 -*-
"""Section: 关卡详细参数 + 环境系统"""

SECTION = """
### 2.2 关卡参数详表

#### 2.2.1 各时代详细参数

| 时代 | 关卡 | 控制势力 | 法则家族开放规则 | 难度范围 |
|------|------|---------|-----------------|---------|
| 一战 | 1-5 | iron_wall_corp | 仅 STEEL | 0.80~0.88 |
| 一战 | 6-14 | iron_wall_corp | STEEL + FLAME | 0.90~1.06 |
| 一战 | 15-19 | iron_wall_corp | STEEL + FLAME + THUNDER | 1.08~1.16 |
| 一战 | 20(Boss) | iron_wall_corp | 全部4家族 | 1.18 |
| 二战 | 21-25 | nova_arms | 仅 FLAME | 1.00~1.10 |
| 二战 | 26-34 | nova_arms | FLAME + STEEL | 1.125~1.325 |
| 二战 | 35-39 | nova_arms | FLAME + STEEL + THUNDER | 1.35~1.45 |
| 二战 | 40(Boss) | nova_arms | 全部4家族 | 1.475 |
| 冷战 | 41-45 | aether_dynamics | THUNDER + STEEL | 1.15~1.27 |
| 冷战 | 46-54 | aether_dynamics | THUNDER + STEEL + FLAME | 1.30~1.52 |
| 冷战 | 55-59 | aether_dynamics | 全部4家族 | 1.55~1.67 |
| 冷战 | 60(Boss) | aether_dynamics | 全部4家族 | 1.70 |
| 现代 | 61-65 | quantum_logistics | STEEL + FLAME | 1.25~1.39 |
| 现代 | 66-80 | quantum_logistics | 全部4家族 | 1.425~1.875 |
| 现代 | 80(Boss) | quantum_logistics | 全部4家族 | 1.875 |
| 近未来 | 81-85 | helix_recon | THUNDER + VOID + FLAME | 1.40~1.56 |
| 近未来 | 86-90 | helix_recon | 全部4家族 | 1.60~1.76 |
| 近未来 | 91-100 | void_research | VOID + FLAME + STEEL + THUNDER | 1.80~2.36 |
| 近未来 | 100(最终Boss) | void_research | 全部4家族 | 2.36 |

**法则限制设计理念：**
- 每关至少允许1个家族（玩家总有选择）
- Boss关卡（20/40/60/80/100）允许全部4个家族
- 早期关卡限制严格（1-2个），后期逐渐放宽（3-4个）
- 与关卡所属势力的主家族关系密切
- 近未来时代大部分关卡即开放全部家族

#### 2.2.2 相位仪经验

每关通关后获得相位仪经验，时代内线性插值：

| 时代 | 首关(1) | 中关(10) | 末关(20) |
|------|---------|----------|----------|
| 一战 | 132 | 330 | 550 |
| 二战 | 198 | 495 | 825 |
| 冷战 | 264 | 660 | 1100 |
| 现代 | 330 | 825 | 1375 |
| 近未来 | 396 | 990 | 1650 |

#### 2.2.3 关卡背景故事示例

每关都有独特背景故事，以下为各时代首关/末关示例：

| 关卡 | 名称 | 背景故事 |
|------|------|---------|
| 1 | 一战·晨曦中的 | 晨曦中的索姆河，第一阶段突破作战 |
| 20 | 一战·胜利时刻 | 胜利时刻，一战结束前夜的最后一战 |
| 21 | 二战·不列颠空战 | 不列颠空战，欧洲战场开启 |
| 40 | 二战·世界重生 | 世界重生，新时代的开端 |
| 41 | 冷战·铁幕降临 | 铁幕降临，两极对峙开始 |
| 60 | 冷战·新世界秩序 | 新世界秩序，冷战的落幕 |
| 61 | 现代·海湾战争 | 海湾战争，精准制导的革命 |
| 80 | 现代·和平的曙光 | 和平的曙光，战争的可能性 |
| 81 | 近未来·人工智能觉醒 | 人工智能觉醒，机器的反抗 |
| 100 | 近未来·新纪元黎明 | 新纪元黎明，超越一切的存在 |

### 2.3 环境循环系统

每关环境由算法循环生成（特殊关卡10/25/45/68/90有手工配置覆盖）：

| 维度 | 循环池 | 生成算法 |
|------|--------|---------|
| 天气 weather | clear / rain / storm / fog | (era×5 + level_in_era) % 4 |
| 地形 terrain | plain / mountain / city / forest / desert | (era + level_in_era) % 5 |
| 能量场 energy_field | normal / high_field / void_rift / nano_fog | (era×3 + level_in_era) % 4 |
| 时间 time_of_day | dawn / day / dusk / night | level_in_era % 4 |

**时代默认环境：**

| 时代 | 默认天气 | 默认地形 | 默认能量场 | 默认时间 |
|------|---------|---------|-----------|---------|
| WW1 | clear | plain | normal | day |
| WW2 | rain | plain | normal | dusk |
| Cold War | snow | city | normal | day |
| Modern | storm | city | high_field | night |
| Near Future | sandstorm | plain | nano_fog | dusk |

环境标签是相位法则激活条件（env_req）的核心维度，玩家需要根据关卡环境选择合适的法则组合。

**特殊关卡环境配置（手工覆盖）：**

| 关卡 | 天气 | 地形 | 能量场 | 时间 |
|------|------|------|--------|------|
| 10 | rain | city | normal | dusk |
| 25 | clear | plain | low_field | day |
| 45 | snow | city | normal | day |
| 68 | storm | city | high_field | night |
| 90 | sandstorm | plain | nano_fog | dusk |
"""
