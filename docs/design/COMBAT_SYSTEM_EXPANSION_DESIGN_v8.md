# Phase War v8.x — 技能/战法/兵种相克全面设计方案

> **设计目标**：现有战斗系统 90% 的变量是"数值"（攻击力×HP×防御），缺少"机制差异"。本方案通过新技能、兵种特性克制、特殊兵种机制、战法系统四大模块，让不同阵容+不同技能带来完全不同的战场行为。
>
> **设计基础**：所有新机制均从现有敌方系统（30 相位师 + 36 archetype + 65 符文之语）中迁移提炼，不是凭空造，保证战斗逻辑一致性。
>
> **来源参考**：孙子兵法、克劳塞维茨《战争论》、Total War 阵型系统、暗黑破坏神符文之语、星际争霸微操战术、二战军事史、 Hearts of Iron 系列。

---

## 目录

1. [敌方核心机制盘点（迁移来源）](#一敌方核心机制盘点迁移来源)
2. [新技能设计（4 家族 × 15 = 60 个技能）](#二新技能设计4-家族--15--60-个技能)
3. [兵种特性克制系统强化（3维→5维）](#三兵种特性克制系统强化3维5维)
4. [特殊兵种机制新增](#四特殊兵种机制新增)
5. [战法系统（18个战术）](#五战法系统18个战术)
6. [技能书与解锁体系](#六技能书与解锁体系)
7. [数据文件结构](#七数据文件结构)
8. [实施优先级](#八实施优先级)

---

## 一、敌方核心机制盘点（迁移来源）

从现有敌方系统中提取的 12 类核心机制，作为新技能设计的基础：

| 机制类别 | 敌方实例 | 玩家侧现状 | 迁移价值 |
|---|---|---|---|
| **召唤/产兵** | enemy_master_005 reinforcement_call（召唤4精英） | 仅有 phantom_clone 克隆 | ★★★★★ |
| **地形改造** | enemy_master_010 world_inferno（地形转化） | 完全缺失 | ★★★★★ |
| **能量剥夺** | enemy_master_008 void_embrace（每秒-能量） | 完全缺失 | ★★★★☆ |
| **伤害转移/护盾共享** | 相位师间伤害分摊 | 仅有 mega_shield 全体护盾 | ★★★★☆ |
| **连锁/弹跳** | enemy_master_007 chain_lightning（4次弹跳） | 仅有 rune chain_lightning | ★★★☆☆ |
| **时间操控** | void_time_ripple（全场减速50%） | 仅减速 | ★★★★★ |
| **执行/斩杀** | enemy_master_025 execute_damage（vs HP<30%×2伤害） | 完全缺失 | ★★★★☆ |
| **战场地形** | void_gravity_well（拉拽）/ static_domain（持续伤害区） | 完全缺失 | ★★★★★ |
| **隐身/伪装** | fut_inf_spectre_e stealth 标签（60%减伤4s） | 仅敌人有 | ★★★☆☆ |
| **自爆/殉爆** | enemy_master_002 explosive_charge | 完全缺失 | ★★★☆☆ |
| **增益光环** | recruit_commander 相邻友军+10%防御 | command_aura 不够丰富 | ★★★★☆ |
| **状态叠层** | heat_wave 每10s叠层 / modular_upgrade | 完全缺失 | ★★★★☆ |

---

## 二、新技能设计（4 家族 × 15 = 60 个技能）

每个技能包含以下字段定义：
- **ID**：唯一标识符（格式 `sk_<family>_<num>_<name>`）
- **类型**：active（主动施放）/ passive（被动光环）/ ultimate（终极技能）
- **触发**：on_cast（手动）/ on_battle_start（开局）/ periodic（周期）/ on_condition（条件触发）
- **CD/能耗**：冷却时间 + 能量消耗
- **效果**：具体数值和机制描述
- **来源**：从哪个敌方机制迁移或历史/奇幻参考

### 2.1 钢铁家族（STEEL）— 主题：阵地战 / 工程 / 持久消耗

> 灵感来源：马奇诺防线、刺猬防御、闪电战装甲集群、二战要塞战

#### S1 钢铁壁垒（Steel Bulwark）
```yaml
ID: sk_steel_01_bulwark
类型: active
触发: on_cast
CD: 25s
能耗: 80
效果:
  - 在目标区域生成临时掩体墙
  - 持续: 15s
  - 阻挡直射子弹（敌方子弹被墙拦截）
  - 可被火炮类武器摧毁（承受500伤害后破碎）
  - 墙后友军获得 -15% 伤害减免
来源: enemy_master_005 iron_dome（3000护盾基础8秒）
```

#### S2 装甲楔入（Armor Wedge）
```yaml
ID: sk_steel_02_wedge
类型: active
触发: on_cast
CD: 30s
能耗: 100
效果:
  - 选定3个ARMOR类友军
  - 形成楔形阵型冲锋
  - 移动速度×3，持续5s
  - 路径上敌方单位受到碰撞伤害（80%ATK）
  - 冲锋结束后5s内攻击+20%
来源: 二战德军闪电战（古德里安装甲集群）
```

#### S3 要塞化协议（Fortify Protocol）
```yaml
ID: sk_steel_03_fortify
类型: passive
效果:
  - 所有FORT类单位获得"不可击退"（免疫所有位移类debuff）
  - 相邻FORT单位间互相提供 +10% 减伤
  - FORT单位死亡时，5s内周围友军获得"堡垒余晖"（+10%防御）
来源: enemy_master_016 immortal_will
```

#### S4 机械维修站（Mech Repair Station）
```yaml
ID: sk_steel_04_repair_station
类型: active
触发: on_cast
CD: 35s
能耗: 120
效果:
  - 召唤一个维修站（HP 1500，无敌）
  - 半径150内友军机械单位每秒恢复2%最大HP
  - 持续: 20s
  - 维修站可被敌方优先攻击（被攻击时HP-100/s）
来源: enemy_master_022 mass_repair
```

#### S5 反坦克雷区（Anti-Tank Minefield）
```yaml
ID: sk_steel_05_minefield
类型: active
触发: on_cast
CD: 28s
能耗: 90
效果:
  - 在目标区域铺设6个地雷
  - 持续: 30s
  - 敌方ARMOR类单位进入触发：200%ATK伤害 + 减速40%（3s）
  - 敌方LIGHT类单位触发：100%ATK伤害 + 减速20%（2s）
  - 敌方AIR类单位不触发（空袭免疫）
来源: 一战堑壕战铁丝网 + 地雷
```

#### S6 纵深防御（Defense in Depth）
```yaml
ID: sk_steel_06_depth_defense
类型: passive
效果:
  - 判定"后方单位"：敌方无直接接触3格以内的友军
  - 后方单位攻击+15%，射程+10%
  - 前方单位（与敌方直接接触）防御+20%，受伤-10%
来源: 苏军纵深作战理论（库尔斯克会战）
```

#### S7 弹道计算所（Ballistic Calculator）
```yaml
ID: sk_steel_07_ballistic
类型: active
触发: on_cast
CD: 20s
能耗: 60
效果:
  - 标记一个目标区域（持续10s）
  - 10s内所有ARTILLERY类友军的炮弹在该区域爆炸时伤害×2
  - 该区域内敌方被"标记"：受到所有伤害+15%
来源: 炮兵火力协调（一战炮兵观察员）
```

#### S8 钢铁洪流（Steel Torrent）
```yaml
ID: sk_steel_08_torrent
类型: active
触发: on_cast
CD: 22s
能耗: 80
效果:
  - 选定最近3个ARMOR类友军
  - 每个单位获得临时装甲护盾（吸收300伤害）
  - 持续: 10s
  - 护盾存在时该单位攻击+15%
来源: 二战苏军机械化军（钢铁洪流）
```

#### S9 阵地加固（Position Reinforce）
```yaml
ID: sk_steel_09_reinforce
类型: passive
效果:
  - 所有FORT单位建造速度×2（部署时间-50%）
  - FORT单位死亡时留下废墟掩体（持续5s，半径80，区域内友军-20%受伤）
来源: 堡垒回血机制扩展
```

#### S10 交叉火力网（Crossfire Network）
```yaml
ID: sk_steel_10_crossfire
类型: active
触发: on_cast
CD: 25s
能耗: 100
效果:
  - 选定2个区域（相距200-500像素）
  - 之间形成交叉火力带（持续10s）
  - 经过火力带的敌方单位同时受到两侧友军攻击
  - 该区域敌方被"压制"：攻速-40%（3s）
来源: 机枪巢交叉火力战术
```

#### S11 装甲回收（Armor Salvage）
```yaml
ID: sk_steel_11_salvage
类型: active
触发: on_cast
CD: 30s
能耗: 90
效果:
  - 复活一个最近死亡的友军机械单位（非精英）
  - 复活后HP = 50%最大HP
  - 持续: 8s 后自动消失
  - 复活单位攻击+30%（复仇buff）
来源: 战场抢修（Dead Tank Revival）
```

#### S12 钢铁意志（Iron Will）
```yaml
ID: sk_steel_12_iron_will
类型: passive
效果:
  - 所有友军HP<25%时防御×2（不与减伤叠加，取高者）
  - 友军HP<25%时不再被击退/位移
  - 触发"钢铁意志"状态时清除所有debuff
来源: enemy_master_009 iron_will
```

#### S13 炮火准备（Artillery Preparation）
```yaml
ID: sk_steel_13_artillery_prep
类型: active
触发: on_cast
CD: 35s
能耗: 130
效果:
  - 3s后在目标线进行炮击（造成范围伤害，每弹150）
  - 炮击区域内敌方被"压制"：攻速-50%，移速-30%（5s）
  - 炮击时所有ARTILLERY类友军暂停射击（参与炮击准备）
来源: 一战"徐进弹幕"战术
```

#### S14 工程抢修（Engineering Repair）
```yaml
ID: sk_steel_14_eng_repair
类型: active
触发: on_cast
CD: 18s
能耗: 70
效果:
  - 清除目标区域内所有敌方debuff和陷阱（地雷/燃烧/干扰）
  - 区域内友军获得 +1000 护盾
  - 持续: 8s
来源: 工兵筑桥/排雷（Engineering Corps）
```

#### S15 钢铁风暴（Steel Storm）★ 终极技能
```yaml
ID: sk_steel_15_storm
类型: ultimate
触发: on_cast
CD: 120s
能耗: 300
效果:
  - 召唤4个临时钢铁傀儡（继承相位师20%属性）
  - 持续: 15s
  - 傀儡自动攻击最近敌人
  - 傀儡死亡时爆炸（范围100，200%ATK伤害）
  - 傀儡存在期间所有FORT友军攻击+30%
来源: enemy_master_009 legion_call
```

---

### 2.2 火焰家族（FLAME）— 主题：燃烧 / 范围压制 / 自爆

> 灵感来源：希腊火、凝固汽油弹、焦土政策、火龙阵

#### F1 焦土政策（Scorched Earth）
```yaml
ID: sk_flame_01_scorched
类型: active
触发: on_cast
CD: 20s
能耗: 80
效果:
  - 点燃目标区域（持续8s）
  - 区域内敌方每秒受到 5% 最大HP伤害
  - 消除区域内所有友军隐身/潜行debuff（火焰暴露一切）
  - 燃烧区域内的敌方被"暴露"：受到的所有伤害+10%
来源: 二战撤退焦土（俄军1812年战略）
```

#### F2 燃烧弹投射（Incendiary Bomb）
```yaml
ID: sk_flame_02_bomb
类型: active
触发: on_cast
CD: 15s
能耗: 60
效果:
  - 在目标区域投下燃烧弹
  - 着弹点造成 150 火伤
  - 留下火墙（持续5s，半径100）
  - 火墙内敌方移速-40%，每秒受 50 火伤
来源: 凝固汽油弹（Napalm）
```

#### F3 自爆突击队（Kamikaze Strike）
```yaml
ID: sk_flame_03_kamikaze
类型: active
触发: on_cast
CD: 25s
能耗: 100
效果:
  - 选定1个友军单位（非精英非Boss）
  - 该单位下一次攻击变为自爆（死亡）
  - 对3×3范围造成 300%ATK 火伤
  - 自爆后该区域留下火墙（3s）
来源: 二战日军万岁冲锋（Banzai charge）
```

#### F4 烈焰风暴（Firestorm）
```yaml
ID: sk_flame_04_firestorm
类型: active
触发: on_cast
CD: 40s
能耗: 150
效果:
  - 召唤移动火风暴（在战场上随机移动10s）
  - 接触到的敌方单位持续燃烧（5s内每秒30火伤）
  - 风暴经过的区域留下火墙（3s）
  - 风暴优先移动向密集敌方区域
来源: enemy_master_010 world_inferno
```

#### F5 热能感知（Thermal Vision）
```yaml
ID: sk_flame_05_thermal
类型: passive
效果:
  - 所有友军对"隐身"和"stealth"标签敌人伤害+50%
  - 对燃烧中的敌人暴击率+20%
  - 燃烧中的敌人无法隐身
来源: 热成像瞄准镜改造（thermal_scope）
```

#### F6 烽火信号（Signal Fire）
```yaml
ID: sk_flame_06_signal
类型: active
触发: on_cast
CD: 22s
能耗: 80
效果:
  - 点燃全图3个信标（随机位置）
  - 持续: 12s
  - 每个信标周围200范围内友军攻速+30%
  - 信标可被敌方摧毁（HP 300）
来源: 古代烽火台（Beacon System）
```

#### F7 熔毁（Meltdown）
```yaml
ID: sk_flame_07_meltdown
类型: active
触发: on_cast
CD: 30s
能耗: 120
效果:
  - 牺牲1个友军单位（非精英）
  - 对3×3范围造成 500 火伤
  - 区域内敌方"过热"：3s内无法恢复HP，受到的治疗转为伤害
来源: 反应堆熔毁概念（Reactor Meltdown）
```

#### F8 火焰庇护（Flame Aegis）
```yaml
ID: sk_flame_08_aegis
类型: active
触发: on_cast
CD: 18s
能耗: 70
效果:
  - 为全体友军施加火焰护盾
  - 持续: 6s
  - 吸收火属性伤害的50%转化为自身治疗
  - 免疫"燃烧"debuff
来源: 火焰适应被动（fire_adaptation）
```

#### F9 炼狱领域（Inferno Domain）
```yaml
ID: sk_flame_09_inferno
类型: passive
效果:
  - 所有火焰技能的范围扩大50%
  - 击杀单位触发小范围自爆（80%ATK火伤，半径60）
  - 火焰技能命中的敌方"易燃"：下次火焰伤害+20%（最多叠3层）
来源: enemy_master_017 ragnarok
```

#### F10 爆裂燃料（Explosive Fuel）
```yaml
ID: sk_flame_10_fuel
类型: active
触发: on_cast
CD: 16s
能耗: 70
效果:
  - 给3个友军单位涂覆燃料（持续10s）
  - 下次攻击命中时产生二次爆炸（范围100，60%ATK火伤）
  - 涂覆期间该单位免疫火焰伤害
来源: 燃烧弹 + 燃料混合（FAE武器）
```

#### F11 高温气浪（Heat Wave Blast）
```yaml
ID: sk_flame_11_heatwave
类型: active
触发: on_cast
CD: 14s
能耗: 60
效果:
  - 在目标点制造冲击波（半径200）
  - 对所有敌方单位造成 50%ATK 伤害
  - 击退150距离（ARMOR类单位减半）
  - 被"灼烧"：3s内受到伤害+15%
来源: 爆炸冲击波（Blast Wave）
```

#### F12 焚城（Burn the City）★ 终极技能
```yaml
ID: sk_flame_12_burn_city
类型: ultimate
触发: on_cast
CD: 100s
能耗: 280
效果:
  - 全图3个区域同时落下燃烧弹
  - 每弹 200 火伤 + 火墙8s
  - 中间区域额外造成眩晕2s
  - 全图敌方"恐慌"：5s内移速-30%，攻速-20%
来源: 二战战略轰炸（Strategic Bombing）
```

#### F13 余烬重生（Phoenix Rebirth）
```yaml
ID: sk_flame_13_phoenix
类型: passive
效果:
  - 火焰单位死亡时有20%概率化为余烬
  - 余烬3s后以30%HP重生
  - 重生后获得"凤凰之怒"：5s内攻击×2
  - 每场战斗每单位限触发1次
来源: 凤凰涅槃（Phoenix Rebirth）
```

#### F14 火焰传导（Flame Conduction）
```yaml
ID: sk_flame_14_conduction
类型: active
触发: on_cast
CD: 18s
能耗: 80
效果:
  - 将1个友军的燃烧效果"传染"给最多5个邻近敌方单位
  - 每个传染目标损失 3%HP/s（持续4s）
  - 传染路径上的敌方被"点燃"：5s内受到火焰伤害+30%
来源: 链式燃烧（Chain Combustion）
```

#### F15 太阳耀斑（Solar Flare）
```yaml
ID: sk_flame_15_solar
类型: active
触发: on_cast
CD: 35s
能耗: 130
效果:
  - 全图火焰爆发
  - 所有敌方单位获得"burning"标记：受到的所有伤害+25%（持续5s）
  - 所有隐身敌方单位显形（持续5s）
  - 命中时30%概率造成眩晕1s
来源: enemy_master_017 solar_flare
```

---

### 2.3 雷霆家族（THUNDER）— 主题：速度 / 连锁 / 电子战

> 灵感来源：闪电战、电子干扰、电磁炮、蜂群战术、无人机群

#### T1 电磁脉冲（EMP Strike）
```yaml
ID: sk_thunder_01_emp
类型: active
触发: on_cast
CD: 25s
能耗: 100
效果:
  - 在目标区域释放EMP（半径250，持续4s）
  - 敌方机械单位攻速-60%
  - 敌方能量回收-100%（4s内无法恢复能量）
  - 敌方所有"shield"属性归零（4s）
来源: thunder_emp_storm
```

#### T2 闪电链（Chain Lightning）
```yaml
ID: sk_thunder_02_chain
类型: active
触发: on_cast
CD: 12s
能耗: 50
效果:
  - 从最近单位释放闪电链
  - 弹跳6次（每次造成 80%ATK 雷伤）
  - 对ARMOR目标额外+50%伤害
  - 每次弹跳范围递减（首次200，末次100）
来源: thunder_chain_discharge
```

#### T3 电子战干扰（Electronic Warfare）
```yaml
ID: sk_thunder_03_ew
类型: active
触发: on_cast
CD: 20s
能耗: 80
效果:
  - 干扰敌方雷达（持续8s）
  - 敌方远程单位命中率-40%
  - 敌方隐身单位显形
  - 敌方光环/技能效果减半
来源: 现代电子战（ECM/EW）
```

#### T4 超视距打击（Beyond Visual Range）
```yaml
ID: sk_thunder_04_bvr
类型: active
触发: on_cast
CD: 18s
能耗: 70
效果:
  - 标记一个敌方单位（持续10s）
  - 全图所有友军优先攻击该目标
  - 友军射程+50%（仅对该目标）
  - 该目标受到的所有伤害+20%
来源: 现代远程精确打击（BVR Combat）
```

#### T5 风暴先锋（Storm Vanguard）
```yaml
ID: sk_thunder_05_vanguard
类型: active
触发: on_cast
CD: 22s
能耗: 90
效果:
  - 选定2个FAST类友军
  - 获得"冲锋"状态（移速×2.5，持续5s）
  - 穿过敌人时造成 30%ATK 碰撞伤害
  - 冲锋结束位置爆炸（范围80，50%ATK）
来源: 闪电战机动理论（Blitzkrieg）
```

#### T6 雷电过载（Lightning Overload）
```yaml
ID: sk_thunder_06_overload
类型: passive
效果:
  - 当场上友军数量>敌方时
  - 每个多出单位使全体攻速+5%（最多+25%）
  - 每个多出单位使全体移速+3%（最多+15%）
来源: enemy_master_003 overcharge
```

#### T7 感应雷暴（Proximity Storm）
```yaml
ID: sk_thunder_07_proximity
类型: active
触发: on_cast
CD: 20s
能耗: 80
效果:
  - 空投5个感应雷（悬浮空中）
  - 持续: 30s
  - 敌方靠近时自动爆炸（范围80，120%ATK雷伤）
  - 每个雷爆炸后产生连锁（弹跳2次，50%伤害）
来源: 空投雷区（Air-dropped Mines）
```

#### T8 电磁轨道炮（Railgun）
```yaml
ID: sk_thunder_08_railgun
类型: active
触发: on_cast
CD: 30s
能耗: 130
效果:
  - 凝聚能量1s（读条，可被打断）
  - 发射穿甲弹对单个目标造成 400%ATK 伤害
  - 无视50%防御
  - 穿透路径上所有敌方（直线范围500）
来源: 电磁炮武器概念（Railgun）
```

#### T9 蜂群无人机（Swarm Drones）
```yaml
ID: sk_thunder_09_swarm
类型: active
触发: on_cast
CD: 25s
能耗: 100
效果:
  - 释放8架微型无人机（持续12s）
  - 每架自动寻找最近敌人造成 15%ATK 伤害
  - 无人机被击落时掉落少量能量（+5）
  - 无人机存在期间敌方无法精准锁定（命中率-20%）
来源: 无人机群战术（Drone Swarm）
```

#### T10 静电护盾（Static Shield）
```yaml
ID: sk_thunder_10_static_shield
类型: active
触发: on_cast
CD: 18s
能耗: 80
效果:
  - 为全体友军施加静电场（持续6s）
  - 敌方近战攻击有30%概率被电击反伤 50%ATK
  - 静电场存在期间免疫"减速"debuff
来源: 电磁装甲概念（Electromagnetic Armor）
```

#### T11 瞬移突击（Blink Strike）
```yaml
ID: sk_thunder_11_blink
类型: active
触发: on_cast
CD: 20s
能耗: 80
效果:
  - 选定1个友军单位
  - 瞬间传送到敌方后排（场地另一侧）
  - 传送后获得"突进"：下次攻击伤害×2
  - 传送位置3×3范围内敌方被眩晕1s
来源: 虚空瞬移概念的"雷"版本
```

#### T12 天罚雷阵（Heaven's Thunder）★ 终极技能
```yaml
ID: sk_thunder_12_heaven
类型: ultimate
触发: on_cast
CD: 100s
能耗: 280
效果:
  - 全图降下20道闪电（随机分布，持续5s）
  - 每道 200 雷伤
  - 对机械单位额外×2伤害
  - 命中时10%概率造成眩晕2s
  - 全图敌方被"感电"：5s内受到的所有伤害+15%
来源: enemy_master_011 thunder_god_fury
```

#### T13 充能爆发（Charge Surge）
```yaml
ID: sk_thunder_13_charge
类型: passive
效果:
  - 每拥有10点额外能量，全体攻速+2%（最多+40%）
  - 能量消耗-10%
  - 满能量时（100%）触发"过充能"：全体攻击+20%（持续5s，CD 30s）
来源: 能量过载（Energy Overload）
```

#### T14 电网封锁（Power Grid Lockdown）
```yaml
ID: sk_thunder_14_grid
类型: active
触发: on_cast
CD: 22s
能耗: 90
效果:
  - 在一条线上建立电网（持续10s）
  - 穿越的敌方单位受到 100 雷伤 + 眩晕1s
  - 电网可被破坏（HP 800，受到集中攻击时破碎）
来源: 带电围栏（Electrified Barrier）
```

#### T15 量子纠缠打击（Quantum Strike）
```yaml
ID: sk_thunder_15_quantum
类型: active
触发: on_cast
CD: 28s
能耗: 110
效果:
  - 标记2个相距最远的敌方单位
  - 3s后同时被打击（每个 200 雷伤）
  - 如果两个都存活，总伤害×1.5
  - 如果只有一个存活，该目标受到额外100伤害
来源: 量子通信 + 远程打击（Quantum Entanglement）
```

---

### 2.4 虚空家族（VOID）— 主题：空间操控 / 时间扭曲 / 灵魂抽取

> 灵感来源：黑洞、维度裂缝、时间停止、幽灵部队、暗物质

#### V1 维度裂隙（Dimension Rift）
```yaml
ID: sk_void_01_rift
类型: active
触发: on_cast
CD: 25s
能耗: 100
效果:
  - 在目标区域打开维度裂隙（持续8s）
  - 每2s随机传送1个敌方单位到战场另一侧
  - 传送的单位被"混乱"：3s内攻击友军（25%概率）
来源: enemy_master_008 dimension_rift
```

#### V2 时间停滞（Time Stop）
```yaml
ID: sk_void_02_time_stop
类型: active
触发: on_cast
CD: 45s
能耗: 180
效果:
  - 暂停所有敌方单位3s
  - 不能移动/攻击/使用技能
  - 护盾不受影响（仍可吸收伤害）
  - 时间结束后敌方"时间错位"：5s内攻速-30%
来源: void_time_ripple 增强版（时间停止）
```

#### V3 暗影吞噬（Shadow Devour）
```yaml
ID: sk_void_03_devour
类型: active
触发: on_cast
CD: 30s
能耗: 120
效果:
  - 吞噬一个HP<40%的敌方单位（立即死亡）
  - 虚空相位师恢复 15%最大HP
  - 每场战斗限2次（精英/Boss单位改为降至15%HP）
来源: enemy_master_019 devour_all
```

#### V4 熵增领域（Entropy Field）
```yaml
ID: sk_void_04_entropy
类型: active
触发: on_cast
CD: 25s
能耗: 100
效果:
  - 在目标区域制造熵增场（半径250，持续10s）
  - 敌方每秒损失 1% 最大HP
  - 敌方每秒损失 1 能量
  - 友军免疫（熵增只作用于敌方）
来源: entropy_drain
```

#### V5 相位偏移（Phase Shift）
```yaml
ID: sk_void_05_phase_shift
类型: passive
效果:
  - 所有友军有15%概率"虚化"
  - 虚化时完全免疫下一次伤害
  - 虚化后5s内无法被选中（敌方AI不攻击）
  - 每场战斗每单位限触发3次
来源: phase_shift + phase_cloak
```

#### V6 引力井（Gravity Well）
```yaml
ID: sk_void_06_gravity
类型: active
触发: on_cast
CD: 20s
能耗: 80
效果:
  - 在目标点创建引力井（半径200，持续6s）
  - 周围敌方单位被拉向中心（移速-50%）
  - 远程攻击精度-30%
  - 引力井中心每秒造成 30 虚空伤
来源: void_gravity_well
```

#### V7 灵魂抽取（Soul Drain）
```yaml
ID: sk_void_07_soul_drain
类型: active
触发: on_cast
CD: 18s
能耗: 70
效果:
  - 对单个敌方造成 200 虚空伤
  - 每抽取 100HP 转化为护盾给随机友军（护盾持续8s）
  - 目标被"灵魂抽取"：3s内受到治疗-50%
来源: dimension_siphon 增强
```

#### V8 暗物质装甲（Dark Matter Armor）
```yaml
ID: sk_void_08_dark_matter
类型: passive
效果:
  - 全体友军获得暗物质护甲
  - 受到的致命伤害降低50%
  - 每场战斗每单位限触发1次
  - 触发后5s内攻击+15%（暗物质反噬）
来源: 暗物质概念（Dark Matter）
```

#### V9 镜像分身（Mirror Image）
```yaml
ID: sk_void_09_mirror
类型: active
触发: on_cast
CD: 35s
能耗: 130
效果:
  - 复制战场上HP最高的敌方单位
  - 持续: 10s
  - 复制体属性为50%
  - 复制体攻击原主人（强制攻击源目标）
  - 复制体死亡时爆炸（100%源单位ATK）
来源: shadow_clones
```

#### V10 虚空传送门（Void Portal）
```yaml
ID: sk_void_10_portal
类型: active
触发: on_cast
CD: 30s
能耗: 110
效果:
  - 创建一对传送门（持续15s）
  - 可将任意友军从一个门传送到另一个门
  - 用于快速部署/撤退
  - 传送门可被敌方摧毁（HP 500）
来源: 双向传送门（Two-way Portal）
```

#### V11 现实崩溃（Reality Collapse）
```yaml
ID: sk_void_11_collapse
类型: active
触发: on_cast
CD: 60s
能耗: 200
效果:
  - 检测所有敌方单位
  - HP<15%的直接删除（瞬间死亡）
  - 精英/Boss单位改为降至15%HP
  - 被"崩溃"影响的单位5s内无法恢复HP
来源: enemy_master_012 reality_collapse
```

#### V12 湮灭之光（Annihilation Light）★ 终极技能
```yaml
ID: sk_void_12_annihilate
类型: ultimate
触发: on_cast
CD: 120s
能耗: 300
效果:
  - 凝聚纯湮灭能量（3s读条）
  - 对全图造成 300%ATK 虚空伤
  - 对HP<30%的敌方单位直接斩杀
  - 全图敌方"湮灭"：10s内受到的所有治疗效果转为伤害
来源: 反物质武器概念（Antimatter Weapon）
```

#### V13 时间回溯（Time Rewind）
```yaml
ID: sk_void_13_rewind
类型: active
触发: on_cast
CD: 90s
能耗: 250
效果:
  - 回溯战场状态
  - 所有友军恢复到6s前的HP和位置
  - 所有友方debuff清除
  - 每场战斗限1次
来源: 时间操控终极（Time Manipulation）
```

#### V14 虚空侵蚀（Void Corrosion）
```yaml
ID: sk_void_14_corrosion
类型: passive
效果:
  - 敌方单位每受到一次虚空伤害，获得"侵蚀"层数
  - 每层-2%最大HP（最多5层）
  - 死亡时爆炸（层数×30 虚空伤）
来源: void_corruption
```

#### V15 维度叠加（Dimension Overlay）★ 终极技能
```yaml
ID: sk_void_15_overlay
类型: ultimate
触发: on_cast
CD: 150s
能耗: 350
效果:
  - 战场进入叠加态（持续12s）
  - 所有友军同时存在于2个位置
  - 受到的伤害×0.5
  - 敌方无法锁定隐身单位
  - 友军攻击有25%概率"分裂"（同时命中2个目标）
来源: 量子叠加态（Quantum Superposition）
```

---

## 三、兵种特性克制系统强化（3维→5维）

### 3.1 Combat Kind 枚举扩展

现有 `GameConstants.CombatKind` 从 5 个扩展到 7 个：

```gdscript
# resources/game_constants.gd
enum CombatKind {
    LIGHT = 0,      # 步兵类
    ARMOR = 1,      # 装甲类
    SUPPORT = 2,    # 支援类（保留，向后兼容）
    AIR = 3,        # 空中类
    FORT = 4,       # 堡垒类
    ENGINEER = 5,   # ★新增：工程/支援类（克技能施法）
    SNIPER = 6      # ★新增：精确/狙击类（克高价值目标）
}
```

### 3.2 5维攻击矩阵（进攻端伤害倍率）

```
攻击方 → 防守方     vs LIGHT   vs ARMOR   vs AIR    vs ENG    vs SNIPER
LIGHT (步兵)          100%      60%       20%       80%       40%
ARMOR (装甲)           70%     100%       30%       90%       50%
AIR (空中)             60%      60%      100%      120%       80%
ENGINEER (工程)        80%      90%       50%      100%       60%
SNIPER (狙击)          50%      40%       70%       60%      100%
```

**关键变化**：
- AIR 强化对 ENGINEER（120%）—— 空袭是工程部队的天敌
- SNIPER 对所有维度都中等伤害，但对 Boss/相位师有特殊加成（见下文）
- ENGINEER 对 ARMOR 弱（90%），但对 LIGHT 强（80%）

### 3.3 5维防御矩阵（防守端受伤倍率）

```
防守方 → 攻击方     来自 LIGHT 来自 ARMOR 来自 AIR  来自 ENG  来自 SNIPER
LIGHT (步兵)          100%      50%       30%       70%       20%
ARMOR (装甲)           70%     100%       60%       80%       40%
AIR (空中)             60%      40%      100%       50%       80%
ENGINEER (工程)        50%      60%       80%      100%       60%
SNIPER (狙击)          30%      40%       60%       70%      100%
```

**关键变化**：
- SNIPER 极度怕 LIGHT（受伤20% → 实际是 SNIPER 防御 vs LIGHT 攻击 = 30%，意思是 LIGHT 攻击 SNIPER 时伤害×30%？这里需要澄清）

**澄清说明**：
- "攻击矩阵"= 攻击方造成的伤害百分比
- "防御矩阵"= 防守方受到的伤害百分比
- 两者叠加后的实际伤害 = 攻击矩阵 × 防御矩阵 / 100%

### 3.4 兵种标签硬克制（特性级）

除数字矩阵外，增加**标签间硬性克制**（无条件触发）：

| 攻击方标签 | 目标标签 | 效果 | 说明 |
|-----------|---------|------|------|
| `ENGINEER` | 任何"施法前摇"中的单位 | 攻击时打断施法，使技能进入50%冷却 | 工程师是技能克星 |
| `SNIPER` | `boss` / `master` / `command` | 伤害+50%，必命中（无视闪避/隐身） | 狙击手专杀高价值目标 |
| `STEALTH` | `command` / `support` | 优先攻击该类目标，对其伤害+30% | 渗透者专杀指挥单位 |
| `FORT` | `air` | 对空攻击+40%，免疫空中单位的击退 | 堡垒是防空专家 |
| `FAST` | `fort` | 绕过正面，从后方出现（不受正面减伤影响） | 快速单位绕后 |
| `ARTILLERY` | `fort` / `armor` | 范围伤害+20%，无视堡垒掩护 | 火炮克堡垒 |
| `AIR` | `engineer` / `artillery` | 伤害+30%（空袭后勤单位） | 空军克后勤 |

### 3.5 数据文件结构

```gdscript
# resources/game_constants.gd 新增

const COMBAT_KIND_ATTACK_MATRIX = {
    # [attacker_kind][defender_kind] = damage_multiplier
    CombatKind.LIGHT:     {LIGHT:1.0, ARMOR:0.6, AIR:0.2,  ENGINEER:0.8, SNIPER:0.4},
    CombatKind.ARMOR:     {LIGHT:0.7, ARMOR:1.0, AIR:0.3,  ENGINEER:0.9, SNIPER:0.5},
    CombatKind.AIR:       {LIGHT:0.6, ARMOR:0.6, AIR:1.0,  ENGINEER:1.2, SNIPER:0.8},
    CombatKind.ENGINEER:  {LIGHT:0.8, ARMOR:0.9, AIR:0.5,  ENGINEER:1.0, SNIPER:0.6},
    CombatKind.SNIPER:    {LIGHT:0.5, ARMOR:0.4, AIR:0.7,  ENGINEER:0.6, SNIPER:1.0},
}

const COMBAT_KIND_DEFENSE_MATRIX = {
    # [defender_kind][attacker_kind] = damage_taken_multiplier
    CombatKind.LIGHT:     {LIGHT:1.0, ARMOR:0.5, AIR:0.3,  ENGINEER:0.7, SNIPER:0.2},
    CombatKind.ARMOR:     {LIGHT:0.7, ARMOR:1.0, AIR:0.6,  ENGINEER:0.8, SNIPER:0.4},
    CombatKind.AIR:       {LIGHT:0.6, ARMOR:0.4, AIR:1.0,  ENGINEER:0.5, SNIPER:0.8},
    CombatKind.ENGINEER:  {LIGHT:0.5, ARMOR:0.6, AIR:0.8,  ENGINEER:1.0, SNIPER:0.6},
    CombatKind.SNIPER:    {LIGHT:0.3, ARMOR:0.4, AIR:0.6,  ENGINEER:0.7, SNIPER:1.0},
}

const TAG_COUNTER_RULES = {
    "engineer_vs_casting": {
        "attacker_tag": "engineer",
        "target_condition": "is_casting",
        "effect": "interrupt_cast",
        "value": 0.5  # 技能进入50%冷却
    },
    "sniper_vs_high_value": {
        "attacker_tag": "sniper",
        "target_tags": ["boss", "master", "command"],
        "effect": "damage_bonus",
        "value": 0.5,  # +50%伤害
        "extra": ["never_miss", "ignore_stealth"]
    },
    # ... 7条规则
}
```

---

## 四、特殊兵种机制新增

### 4.1 渗透者（STALKER）

> 灵感来源：特种部队纵深突袭、幽灵特工、敌后渗透

```yaml
兵种标签: stalker
机制说明:
  部署行为:
    - 部署时无视敌方前排
    - 直接出现在敌方防线后方（场地另一侧）
    - 前4秒处于"隐身"状态（受到伤害-60%）
  攻击行为:
    - 优先攻击 command/support 类目标
    - 对 command/support 伤害+30%
  克制关系:
    被 ENGINEER 克制（电子侦测可显形）
    被 AIR 克制（范围扫荡）
  代表卡牌:
    - fut_inf_spectre_e（幽灵特工）
    - cold_inf_spetsnaz_e（特种部队）
```

**实现位置**：`scenes/units/construct_unit.gd` 部署逻辑 + `scripts/battle/target_selection.gd`

### 4.2 工程师（ENGINEER）

> 灵感来源：工兵筑桥/排雷、战场抢修、临时堡垒建设

```yaml
兵种标签: engineer
机制说明:
  建造能力:
    可以在战场上建造临时设施（持续一定时间，可被敌方摧毁）
  建造选项:
    临时掩体:
      HP: 800
      效果: 为后方友军提供 -15% 伤害减免
      持续: 20s
    地雷:
      数量: 3个
      效果: 敌方经过时爆炸（150伤害+减速30%）
      持续: 30s
    维修站:
      HP: 1500
      效果: 每秒修复周围友军机械单位2%HP
      半径: 150
      持续: 20s
  攻击行为:
    攻击正在蓄力的敌方单位时打断施法
  克制关系:
    被 AIR 克制（轰炸）
    被 ARTILLERY 克制（范围炮击）
  代表卡牌:
    - eng_01~eng_10 改造关联兵种
```

**实现位置**：新建 `scenes/units/engineer_deployable.gd`（建筑实体）

### 4.3 电子战（ECM）

> 灵感来源：现代电子干扰、GPS欺骗、雷达致盲

```yaml
兵种标签: ecm
机制说明:
  干扰光环:
    不直接造成伤害，而是施加"干扰"debuff
  干扰效果:
    雷达干扰:
      效果: 敌方远程单位命中率-30%
      半径: 200
    通信干扰:
      效果: 敌方光环/技能效果减半
      半径: 200
    导航干扰:
      效果: 敌方快速单位移速-40%
      半径: 200
  攻击行为:
    自身很脆弱（HP较低）
    不主动攻击，专注于干扰
  克制关系:
    被 SNIPER 克制（快速定点清除）
  代表卡牌:
    - fut_air_drone（无人机群-电子战型）
    - mod_arty_mlrs_e（火箭炮车-配合电子战引导）
```

**实现位置**：扩展 `scripts/battle/module_effect_handler.gd` 增加 ecm_aura 效果

### 4.4 狙击手（SNIPER）

> 现有 sniper weapon type 缺乏独立的"狙击手兵种机制"

```yaml
兵种标签: sniper
机制说明:
  射程特性:
    超远射程（range_value≥8）
  目标选择:
    优先锁定"最高威胁值"目标（Boss/高输出单位）
    对 Boss/master/command 类目标伤害+50%
    必命中（无视闪避/隐身）
  首击加成:
    第一击伤害×2（必定暴击）
  克制关系:
    被 AIR 克制（超视距打击）
    被 ENGINEER 克制（EMP打断）
    自身惧怕 FAST（快速接近）
  代表卡牌:
    - ww1_inf_rifle（步枪班）
    - cold_inf_spetsnaz_e（特种部队-狙击配置）
```

**实现位置**：扩展 `scripts/battle/target_selection.gd` 增加 sniper 优先级

---

## 五、战法系统（18个战术）

> 灵感来源：《孙子兵法》、《战争论》、Total War 阵型系统、星际争霸微操战术

### 5.1 核心概念

**战法** = 需要**特定兵种组合 + 相位仪技能配合**才能发动的高级战术。

不是单个技能，而是"阵容 + 时机"的产物。系统实时检测战场上的兵种组合，满足条件时自动激活战法buff。

### 5.2 基础战法（12个）

#### 经典阵型类（5个）

##### 钳形攻势（Pincer Movement）
```yaml
ID: tactic_pincer
历史来源: 二战德军闪击波兰
所需组合:
  - 至少2个 ARMOR 类友军
  - 至少1个 FAST 类友军
  - ARMOR单位分布在战场左右两侧
激活条件: 战场上同时存在以上组合
效果:
  - 中央敌人受到三面夹击
  - 左右ARMOR单位对其造成 +100%ATK 伤害
  - 中央FAST单位对其造成 +50%ATK 伤害
  - 被夹击的敌方移速-30%（无法逃脱）
```

##### 刺猬防御（Hedgehog Defense）
```yaml
ID: tactic_hedgehog
历史来源: 苏军1941年冬莫斯科保卫战
所需组合:
  - 至少3个 FORT 类友军
  - 至少1个 ENGINEER 类友军
激活条件: FORT单位环形分布（互相相邻）
效果:
  - 全体友军 -30% 受伤
  - 相邻FORT单位间互相 +15% 防御
  - ENGINEER单位修复速度+50%
  - 无法移动（阵型维持期间移速-50%）
```

##### 新月阵（Crescent Formation）
```yaml
ID: tactic_crescent
历史来源: 汉尼拔坎尼会战（公元前216年）
所需组合:
  - 2个 FAST 类友军（左翼）
  - 2个 FAST 类友军（右翼）
  - 任意CENTER单位（中央）
激活条件: 两翼FAST单位位于中央单位两侧
效果:
  - 两翼包抄，两翼FAST伤害×1.5
  - 中央单位吸引火力，防御×1.5
  - 被包围的敌方无法撤退（移速-50%）
```

##### 箭矢阵（Arrow Formation）
```yaml
ID: tactic_arrow
历史来源: 罗马军团箭矢阵
所需组合:
  - 3个 SNIPER 类友军
  - 任意CENTER单位
激活条件: SNIPER单位在后方形成火力线
效果:
  - 全体SNIPER射程+50%
  - 全体SNIPER伤害+30%
  - SNIPER攻击必命中（无视闪避）
  - 中央单位防御+20%（受保护）
```

##### 龟甲阵（Testudo Formation）
```yaml
ID: tactic_testudo
历史来源: 罗马军团龟甲阵
所需组合:
  - 4个 FORT 类友军
  - 任意其他友军
激活条件: FORT单位紧密排列（互相相邻）
效果:
  - 全体 -40% 受伤
  - 免疫所有远程攻击（龟甲保护）
  - 移速-30%（阵型维持代价）
  - 无法使用冲锋类技能
```

#### 战术操作类（7个）

##### 诱敌深入（Draw Deep）
```yaml
ID: tactic_draw_deep
历史来源: 苏军巴巴罗萨反攻（诱敌深入战略）
所需组合:
  - 1个 FAST 类友军（先锋）
  - 3个非FAST类友军（伏兵）
激活条件: FAST单位位于最前方，其他单位在后方
效果:
  - FAST单位前3s受到伤害-50%且不可被秒杀
  - 引诱后敌方进入伏击圈（FAST后方200范围内）时全体攻击+50%
  - 持续10s
```

##### 焦土防线（Scorched Earth Line）
```yaml
ID: tactic_scorched_line
历史来源: 俄军1812年对抗拿破仑
所需组合:
  - 至少2个 FLAME 技能
  - 至少1个 FORT 类友军
激活条件: FORT单位位于战场中央
效果:
  - FORT单位后方留下火墙（持续8s）
  - 追击敌人持续受伤（每秒50火伤）
  - 撤退方（友军）防御+20%
  - 火墙消除敌方隐身
```

##### 饱和打击（Saturation Bombardment）
```yaml
ID: tactic_saturation
历史来源: 一战"徐进弹幕"战术
所需组合:
  - 至少2个 ARTILLERY 类友军
  - 1个 ENGINEER(电子战) 类友军
激活条件: 电子战单位引导（存在≥3s）
效果:
  - 所有火炮伤害×2
  - 射程+30%
  - 持续8s
  - 火炮攻击必命中（电子引导）
```

##### 斩首行动（Decapitation Strike）
```yaml
ID: tactic_decapitation
历史来源: 现代特种作战
所需组合:
  - 1个 SNIPER 类友军
  - 1个 STALKER 类友军（渗透者）
  - 1个 VOID 技能（标记/传送）
激活条件: 目标为敌方Boss/相位师
效果:
  - SNIPER + STALKER组合对Boss伤害×3
  - 持续5s
  - 目标被"斩首标记"：受到所有伤害+50%
  - VOID技能使其无法逃跑
```

##### 声东击西（Feint & Flank）
```yaml
ID: tactic_feint
历史来源: 孙子兵法
所需组合:
  - 1个 ECM 类友军（佯攻源）
  - 2个 FAST 类友军（侧翼）
激活条件: ECM单位位于一侧，FAST位于另一侧
效果:
  - ECM吸引敌方注意（50%敌方单位转向ECM源）
  - FAST从另一侧造成 ×2 伤害
  - 持续5s
  - ECM单位获得"诱饵"：受伤-30%
```

##### 围点打援（Siege and Intercept）
```yaml
ID: tactic_siege_intercept
历史来源: 春秋战国战术
所需组合:
  - 2个 FORT 类友军（包围）
  - 1个 ARMOR 类友军（拦截）
激活条件: 包围一个区域（FORT单位环绕敌方）
效果:
  - 被围堡垒-30%受伤
  - 拦截单位对进入范围的敌方×2伤害
  - 被围单位无法恢复HP
  - 来援的敌方单位被ARMOR拦截
```

##### 闪电穿插（Blitzkrieg Penetration）
```yaml
ID: tactic_blitz
历史来源: 古德里安装甲理论
所需组合:
  - 3个 FAST 类友军
  - THUNDER 相位仪技能
激活条件: 所有FAST单位同时冲锋
效果:
  - 所有FAST单位同时瞬移到敌方最后方
  - 持续5s伤害×2
  - 穿插路径上敌方被眩晕1s
  - 敌方后排混乱（5s内攻击友军25%概率）
```

### 5.3 高级战法（6个，需技能书解锁）

##### 天罗地网（Heaven and Earth Net）
```yaml
ID: tactic_sky_net
解锁条件: T4技能书《天罗地网》+ STEEL + THUNDER 双家族
所需组合:
  - 1个 STEEL 终极技能
  - 1个 THUNDER 终极技能
  - 至少4个友军
效果:
  - 电磁封锁全图
  - 持续8s内敌方所有技能CD×2
  - 敌方无法使用传送/瞬移类技能
  - 全图敌方被"禁锢"：移速-50%
```

##### 虚空降临（Void Descent）
```yaml
ID: tactic_void_descent
解锁条件: T4技能书《虚空降临》+ VOID×2技能
所需组合:
  - 2个 VOID 主动技能
  - 至少3个友军
效果:
  - 维度崩塌（全图引力井）
  - 持续10s，敌方全体被拉向中心
  - 敌方伤害-30%
  - 中心点造成每秒100虚空伤
```

##### 凤凰涅槃（Phoenix Nirvana）
```yaml
ID: tactic_phoenix
解锁条件: T4技能书《凤凰涅槃》+ FLAME×2技能
所需组合:
  - 2个 FLAME 主动技能
  - 至少1个 FORT 类友军（凤凰巢）
效果:
  - 全员清除所有debuff
  - 死亡单位以50%HP重生（限本场每单位1次）
  - 持续10s内全体攻击+30%
  - 重生单位获得"凤凰之火"：攻击附带燃烧
```

##### 四维打击（Four-Dimensional Strike）
```yaml
ID: tactic_4d_strike
解锁条件: T5技能书《四维打击》+ 4家族各1技能
所需组合:
  - STEEL 技能
  - FLAME 技能
  - THUNDER 技能
  - VOID 技能
效果:
  - 终极协同（4种家族技能同时生效）
  - 所有技能效果×1.5
  - 持续15s
  - 全图敌方受到"四维冲击"：所有属性-20%
```

##### 时间闭环（Time Loop）
```yaml
ID: tactic_time_loop
解锁条件: T5技能书《时间闭环》+ VOID 终极技能
所需组合:
  - VOID 终极技能（湮灭之光/维度叠加）
  - 至少3个友军
效果:
  - 重置战场到10s前的状态
  - 但保留所有已获得的增益效果
  - 每场战斗限1次
  - 敌方被"时间错乱"：5s内随机攻击友军
```

##### 诸神黄昏（Ragnarok）
```yaml
ID: tactic_ragnarok
解锁条件: T5技能书《诸神黄昏》（Omni Phase Master掉落）
所需组合:
  - 4个终极技能（每家族1个）
效果:
  - 全图毁灭性打击
  - 全图敌方受到 1000 + 200%相位师ATK 伤害
  - 全图敌方被"诸神黄昏"：10s内每秒损失5%最大HP
  - 全图友军获得"神之祝福"：15s内全属性+50%
  - 每场战斗限1次
```

---

## 六、技能书与解锁体系

### 6.1 技能书稀有度

| 稀有度 | 颜色 | 掉落来源 | 解锁能力 |
|--------|------|---------|---------|
| T1 普通 | 白色 | 精英敌人（10%掉落） | 1个基础技能/被动 |
| T2 稀有 | 蓝色 | Boss敌人（20%掉落）/ 剧情任务 | 1个进阶技能 + 战法解锁 |
| T3 史诗 | 紫色 | 高阶相位师（30%掉落）/ 势力声望Lv5 | 1个高级技能 + 战法 |
| T4 传说 | 橙色 | 时代Boss（40%掉落）/ 势力声望Lv7 | 1个终极技能 + 高级战法 |
| T5 神话 | 红色 | Omni Phase Master / 最终关卡 | 顶级战法/特殊机制 |

### 6.2 技能书列表（共60+本）

#### T1 普通技能书（12本）
| ID | 名称 | 解锁能力 |
|----|------|---------|
| sk_book_infantry_basics | 《基础步兵战术》 | S6 纵深防御（被动） |
| sk_book_engineering_basics | 《简易工程术》 | 工程师可建造1个建筑 |
| sk_book_flame_basics | 《火焰入门》 | F2 燃烧弹投射 |
| sk_book_thunder_basics | 《电学基础》 | T2 闪电链 |
| sk_book_void_basics | 《维度感知》 | V5 相位偏移（被动） |
| sk_book_thermal_scope | 《热成像瞄准》 | F5 热能感知（被动） |
| sk_book_armor_mastery | 《装甲精通》 | S8 钢铁洪流 |
| sk_book_scout_training | 《侦察训练》 | STALKER 兵种解锁 |
| sk_book_repair_manual | 《维修手册》 | S4 机械维修站 |
| sk_book_combat_engineer | 《战斗工兵》 | ENGINEER 兵种解锁 |
| sk_book_ecm_basics | 《电子战入门》 | ECM 兵种解锁 |
| sk_book_sniper_training | 《神射手训练》 | SNIPER 兵种解锁 + 首击必爆 |

#### T2 稀有技能书（15本）
| ID | 名称 | 解锁能力 |
|----|------|---------|
| sk_book_stalker_ops | 《幽灵行动》 | STALKER 隐身+2s + 首击×1.5 |
| sk_book_field_engineering | 《野战工程》 | ENGINEER 可同时2建筑 + 维修范围+50% |
| sk_book_electronic_warfare | 《电子战》 | ECM 干扰时间+50% + 技能CD+20% |
| sk_book_marksman | 《神射手》 | SNIPER 射程+20% + 首击必爆 |
| sk_book_steel_bulwark | 《钢铁壁垒》 | S1 钢铁壁垒（主动） |
| sk_book_mine_warfare | 《地雷战》 | S5 反坦克雷区 |
| sk_book_crossfire | 《交叉火力》 | S10 交叉火力网 + 战法解锁 |
| sk_book_scorched_earth | 《焦土政策》 | F1 焦土政策 + 战法焦土防线 |
| sk_book_kamikaze | 《决死突击》 | F3 自爆突击队 |
| sk_book_emp_doctrine | 《EMP战术》 | T1 电磁脉冲 |
| sk_book_bvr_combat | 《超视距作战》 | T4 超视距打击 |
| sk_book_dimension_rift | 《维度裂缝》 | V1 维度裂隙 |
| sk_book_gravity_well | 《引力井》 | V6 引力井 |
| sk_book_tactic_pincer | 《钳形攻势战法》 | 战法：钳形攻势 |
| sk_book_tactic_hedgehog | 《刺猬防御战法》 | 战法：刺猬防御 |

#### T3 史诗技能书（15本）
| ID | 名称 | 解锁能力 |
|----|------|---------|
| sk_book_armor_wedge | 《装甲楔入》 | S2 装甲楔入 |
| sk_book_fortify_protocol | 《要塞化协议》 | S3 要塞化协议（被动） |
| sk_book_ballistic_calc | 《弹道计算》 | S7 弹道计算所 |
| sk_book_iron_will | 《钢铁意志》 | S12 钢铁意志（被动） |
| sk_book_firestorm | 《烈焰风暴》 | F4 烈焰风暴 |
| sk_book_inferno_domain | 《炼狱领域》 | F9 炼狱领域（被动） |
| sk_book_solar_flare | 《太阳耀斑》 | F15 太阳耀斑 |
| sk_book_railgun | 《电磁轨道炮》 | T8 电磁轨道炮 |
| sk_book_swarm_drones | 《蜂群无人机》 | T9 蜂群无人机 |
| sk_book_blink_strike | 《瞬移突击》 | T11 瞬移突击 |
| sk_book_time_stop | 《时间停滞》 | V2 时间停滞 |
| sk_book_soul_drain | 《灵魂抽取》 | V7 灵魂抽取 |
| sk_book_mirror_image | 《镜像分身》 | V9 镜像分身 |
| sk_book_tactic_blitz | 《闪电穿插战法》 | 战法：闪电穿插 |
| sk_book_tactic_decapitation | 《斩首行动战法》 | 战法：斩首行动 |

#### T4 传说技能书（12本）
| ID | 名称 | 解锁能力 |
|----|------|---------|
| sk_book_steel_storm | 《钢铁风暴》 | S15 钢铁风暴（终极） |
| sk_book_burn_city | 《焚城》 | F12 焚城（终极） |
| sk_book_heaven_thunder | 《天罚雷阵》 | T12 天罚雷阵（终极） |
| sk_book_reality_collapse | 《现实崩溃》 | V11 现实崩溃 |
| sk_book_phoenix_rebirth | 《余烬重生》 | F13 余烬重生（被动） |
| sk_book_dark_matter | 《暗物质装甲》 | V8 暗物质装甲（被动） |
| sk_book_void_corrosion | 《虚空侵蚀》 | V14 虚空侵蚀（被动） |
| sk_book_tactic_sky_net | 《天罗地网战法》 | 战法：天罗地网 |
| sk_book_tactic_void_descent | 《虚空降临战法》 | 战法：虚空降临 |
| sk_book_tactic_phoenix | 《凤凰涅槃战法》 | 战法：凤凰涅槃 |
| sk_book_tactic_saturation | 《饱和打击战法》 | 战法：饱和打击 |
| sk_book_tactic_crescent | 《新月阵战法》 | 战法：新月阵 |

#### T5 神话技能书（6本）
| ID | 名称 | 解锁能力 |
|----|------|---------|
| sk_book_annihilation | 《湮灭之光》 | V12 湮灭之光（终极） |
| sk_book_dimension_overlay | 《维度叠加》 | V15 维度叠加（终极） |
| sk_book_time_rewind | 《时间回溯》 | V13 时间回溯 |
| sk_book_tactic_4d_strike | 《四维打击战法》 | 战法：四维打击 |
| sk_book_tactic_time_loop | 《时间闭环战法》 | 战法：时间闭环 |
| sk_book_ragnarok | 《诸神黄昏》 | 战法：诸神黄昏 |

### 6.3 技能书数据结构

```gdscript
# data/skill_books.gd 新建

class_name SkillBooks
extends RefCounted

var SKILL_BOOKS = {
    "sk_book_infantry_basics": {
        "id": "sk_book_infantry_basics",
        "name": "基础步兵战术",
        "tier": 1,
        "family": "",  # 通用
        "description": "掌握基础步兵战术，解锁纵深防御被动技能",
        "unlocks": {
            "type": "skill",
            "skill_id": "sk_steel_06_depth_defense"
        },
        "drop_sources": ["elite"],  # 精英敌人掉落
        "drop_rate": 0.10,
        "unlock_requirement": null
    },
    "sk_book_stalker_ops": {
        "id": "sk_book_stalker_ops",
        "name": "幽灵行动",
        "tier": 2,
        "family": "",
        "description": "渗透者单位隐身时间+2s，首次攻击伤害×1.5",
        "unlocks": {
            "type": "unit_enhancement",
            "tag": "stalker",
            "effects": {
                "stalker_stealth_duration_bonus": 2.0,
                "stalker_first_hit_mult": 1.5
            }
        },
        "drop_sources": ["boss", "quest"],
        "drop_rate": 0.20,
        "unlock_requirement": "sk_book_scout_training"  # 需先解锁STALKER兵种
    },
    # ... 60+ 本技能书
}

static func get_book(id: String) -> Dictionary:
    return SKILL_BOOKS.get(id, {})

static func get_books_by_tier(tier: int) -> Array:
    var result = []
    for book_id in SKILL_BOOKS:
        if SKILL_BOOKS[book_id].get("tier") == tier:
            result.append(SKILL_BOOKS[book_id])
    return result

static func get_drop_pool(source: String) -> Array:
    """获取某个掉落来源的所有技能书"""
    var result = []
    for book_id in SKILL_BOOKS:
        if source in SKILL_BOOKS[book_id].get("drop_sources", []):
            result.append(SKILL_BOOKS[book_id])
    return result
```

### 6.4 势力声望技能解锁（21个）

7大势力各解锁3个专属战术技能：

| 势力 | Lv3解锁 | Lv5解锁 | Lv7解锁 |
|------|---------|---------|---------|
| **铁幕**(Iron Wall) | S3 要塞化协议 | S1 钢铁壁垒 | S15 钢铁风暴 |
| **新星**(Nova) | F10 爆裂燃料 | F15 太阳耀斑 | F12 焚城 |
| **以太**(Aether) | T10 静电护盾 | T8 电磁轨道炮 | T12 天罚雷阵 |
| **量子**(Quantum) | T3 电子战干扰 | T9 蜂群无人机 | T15 量子纠缠打击 |
| **螺旋**(Helix) | T5 风暴先锋 | T11 瞬移突击 | 战法:闪电穿插 |
| **虚空**(Void) | V1 维度裂隙 | V3 暗影吞噬 | V12 湮灭之光 |
| **边境**(Frontier) | S6 纵深防御 | S10 交叉火力网 | 战法:围点打援 |

### 6.5 相位仪战法槽扩展

在现有相位仪的 slot 系统中，新增 **"Tactic Slot"（战法槽）**：

```gdscript
# data/phase_instruments.gd 新增字段

# 各星级相位仪的战法槽数量
const STAR_TACTIC_SLOTS = {
    1: 0,
    2: 0,
    3: 0,
    4: 0,
    5: 1,  # 5星相位仪解锁1个战法槽
    6: 1,
    7: 2   # 7星相位仪解锁2个战法槽
}

# 战法槽作用：
# - 装备已学习的技能书
# - 每个战法槽只能装1本书
# - 部分高级战法需要2个槽位同时装备特定组合
# - 战法槽不占用标准槽位和符文槽位
```

---

## 七、数据文件结构

### 7.1 需要新建的文件

```
data/
├── skill_books.gd              # 60+本技能书定义
├── skill_definitions.gd        # 60个技能的详细定义（id/类型/效果/CD/能耗）
├── special_unit_types.gd       # 4种特殊兵种机制定义
├── tactics.gd                  # 18个战法定义（组合检测+效果）
└── faction_tactic_unlocks.gd   # 7势力声望技能解锁表

scripts/battle/
├── skill_engine.gd             # 技能战斗实现引擎
├── tactic_detector.gd          # 战法组合检测器
└── special_unit_behavior.gd    # 特殊兵种行为实现

managers/
└── skill_book_manager.gd       # 技能书管理（学习/装备/存档）

scenes/units/
└── engineer_deployable.gd      # 工程师建造的临时建筑
```

### 7.2 需要扩展的文件

```
resources/game_constants.gd     # 新增 CombatKind.ENGINEER/SNIPER + 5维矩阵
resources/drop_tables.gd        # 新增 DropType.SKILL_BOOK
data/phase_instruments.gd       # 新增 tactic_slot 字段
managers/drop_manager.gd        # 新增技能书掉落分支
managers/faction_system_manager.gd  # 势力声望技能解锁
managers/save_manager.gd        # 技能书学习记录存档
scripts/battle/target_selection.gd  # 特殊兵种目标选择
scenes/units/construct_unit.gd  # 特殊兵种部署逻辑
```

---

## 八、实施优先级

按"开发成本 vs 体验提升"排序：

| 优先级 | 模块 | 工作量 | 体验提升 | 依赖 |
|--------|------|--------|---------|------|
| **P0** | 新技能60个的数据定义（skill_definitions.gd） | 小（纯数据） | 高 | 无 |
| **P0** | 技能战斗实现引擎（skill_engine.gd） | 中 | 极高 | phase_instrument_abilities.gd |
| **P0** | 技能书掉落系统 | 中 | 高 | drop_manager.gd |
| **P1** | 兵种特性克制5维矩阵 | 小 | 中 | attack_calculator.gd |
| **P1** | 特殊兵种机制（渗透者/工程师） | 中 | 高 | 新兵种标签 |
| **P1** | 战法系统（12基础） | 大 | 极高 | 技能系统 + 兵种组合检测 |
| **P2** | 势力声望技能解锁 | 小 | 中 | faction_system_manager.gd |
| **P2** | 相位仪战法槽扩展 | 小 | 中 | phase_instruments.gd |
| **P2** | 6个高级战法 | 中 | 高 | T4/T5技能书解锁 |
| **P3** | 电子战/狙击手兵种完善 | 中 | 中 | 标签系统扩展 |

---

## 附录A：技能效果字段说明

每个技能的 `effect` 字段支持以下 key：

```gdscript
# 伤害类
"damage_flat"           # 固定伤害值
"damage_pct_atk"        # 攻击力百分比伤害
"damage_pct_max_hp"     # 目标最大HP百分比伤害
"damage_type"           # 伤害类型（physical/fire/thunder/void/true）

# 范围类
"radius"                # 影响半径
"area_type"             # 区域类型（circle/line/cross/grid_3x3）
"duration"              # 持续时间（秒）

# Buff/Debuff类
"buff_type"             # buff类型（atk/def/spd/crit/dodge...）
"buff_value"            # buff数值
"buff_duration"         # buff持续时间
"debuff_type"           # debuff类型
"debuff_stacks"         # debuff层数

# 特殊机制类
"summon_unit_id"        # 召唤的单位ID
"summon_count"          # 召唤数量
"teleport_target"       # 传送目标位置
"interrupt_chance"      # 打断概率
"execute_threshold"     # 斩杀HP阈值
"stealth_duration"      # 隐身持续时间

# 触发条件类
"condition_hp_below"    # HP低于X%时触发
"condition_unit_count"  # 单位数量条件
"condition_tag_present" # 标签存在条件
```

## 附录B：标签系统完整列表

```gdscript
# 现有标签（保留）
const EXISTING_TAGS = [
    "infantry", "vehicle", "turret", "support", "frontline",
    "backline", "sustained", "artillery", "antitank", "armored",
    "fast", "stealth", "aircraft", "tank", "ultimate",
    "elite", "boss", "immobile"
]

# 新增标签
const NEW_TAGS = [
    "stalker",      # 渗透者：部署到敌方后排
    "engineer",     # 工程师：可建造临时设施
    "ecm",          # 电子战：干扰敌方
    "sniper",       # 狙击手：超远射程+首击必爆
    "command",      # 指挥：提供光环（已有但需强化）
    "mechanical",   # 机械：可被EMP影响+可被维修
    "biological"    # 生物：可被燃烧/毒素影响
]
```

## 附录C：战法组合检测伪代码

```gdscript
# scripts/battle/tactic_detector.gd

class_name TacticDetector
extends RefCounted

# 每0.5s检测一次战场上的兵种组合
static func detect_active_tactics(allies: Array, enemies: Array) -> Array:
    var active_tactics = []
    
    # 检测钳形攻势
    if _check_pincer(allies):
        active_tactics.append("tactic_pincer")
    
    # 检测刺猬防御
    if _check_hedgehog(allies):
        active_tactics.append("tactic_hedgehog")
    
    # ... 检测其他战法
    
    return active_tactics

static func _check_pincer(allies: Array) -> bool:
    var armors = allies.filter(func(u): return u.combat_kind == CombatKind.ARMOR)
    var fasts = allies.filter(func(u): return "fast" in u.tags)
    
    if armors.size() < 2 or fasts.size() < 1:
        return false
    
    # 检查ARMOR单位是否分布在左右两侧
    var left_armors = armors.filter(func(u): return u.global_position.x < BATTLEFIELD_CENTER_X)
    var right_armors = armors.filter(func(u): return u.global_position.x > BATTLEFIELD_CENTER_X)
    
    return left_armors.size() >= 1 and right_armors.size() >= 1
```

---

## 总结

本方案设计总量：
- **60 个新技能**（4家族×15）
- **5 维兵种克制矩阵** + **7 条标签硬克制**
- **4 种特殊兵种机制**（渗透者/工程师/电子战/狙击手）
- **18 个战法**（12基础+6高级）
- **21 个势力专属技能**
- **60+ 本技能书**
- **2 个新 CombatKind 枚举值**（ENGINEER/SNIPER）

**设计原则**：
1. 所有技能都从现有敌方机制迁移而来，保证战斗逻辑一致性
2. 战法需要兵种组合+技能配合，鼓励阵容构建而非单纯堆数值
3. 技能书+势力声望+相位仪槽位三通道解锁，层次丰富
4. 每个技能都有明确的历史/敌方来源，方便后续平衡性调整

**预期效果**：
- 玩家面对同样的敌人，可以有多种完全不同的打法
- 阵容构建（卡牌选择）和技能搭配（技能书装备）成为核心策略
- 100 关不再只是"数值更高的同一场战斗"
