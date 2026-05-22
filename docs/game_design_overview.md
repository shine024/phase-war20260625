## 游戏设定：相位战争·构装纪元

- **世界观**：一战〜近未来跨度的架空战争，玩家掌控“相位仪”，通过装备构装卡（平台、武器、能量与相位法则）来调整战场上的自动武器平台，对抗来自右侧不断推进的敌人。
- **核心循环**：战前准备（背包管理＋相位仪装配） → 开始战斗（自动对战＋资源管理） → 胜负结算（基础资源与蓝图成长） → 回到准备界面或大地图继续推进关卡。
- **关卡结构**：100 关，分为 5 个时代：一战 / 二战 / 冷战 / 现代 / 近未来。每个时代 20 关，时代越靠后，敌人波次数、单位数量与掉落倍数越高。

---

## 玩法与流程

- **战前准备阶段**
  - **背包**：展示已获得的卡牌：
    - 平台卡：决定单位底盘、血量与移速。
    - 武器卡：决定伤害、射程与攻速。
    - 能量卡：
      - 战前能量卡（`energy_start_*`）：决定战斗开始时的初始能量。
      - 能量收集卡（`energy_regen_*`）：决定战斗中每秒自然回复的能量。
      - 即时能量卡（`energy_s`）：在背包中点击即时恢复能量。
  - **相位仪面板**：
    - 有 4 个槽位，可拖拽平台卡、武器卡、部分能量卡进行准备。
    - 平台+武器可组成一对“载具配置”；也可以使用“合成卡”（平台+多武器占一个槽位）。
    - 装备卡会消耗准备阶段的能量（基于每张卡的 `energy_cost`）。
  - **能量系统（准备阶段）**：
    - 使用卡牌会扣除能量，玩家需要权衡开局能量、战时回复与已装备火力之间的取舍。

- **战斗阶段**
  - **单位刷新**：
    - 我方：
      - 每 10 秒从已装备的载具配置（平台+武器）中随机选择一个组合生成单位。
      - 同侧场上单位数量上限为 5。
    - 敌方：
      - 按关卡所属时代，从 `EnemyArchetypes` 中选取对应的敌人原型构成波次。
      - `LevelEras` 控制每关的总波次数、每波单位数与波次间隔。
  - **自动对战**：
    - 我方单位从左向右推进，敌方相反；进入射程后自动攻击。
    - 部分平台/武器/法则提供特殊效果：护盾、灼烧、群体控制等。
  - **能量系统（战斗阶段）**：
    - 基础：每秒 +1⚡ 自然回复，同时相位仪有 -0.5⚡/秒基础消耗。
    - 战前能量卡与收集卡会修改：
      - 初始能量 `_base_start`：所有 `energy_start_*` 卡的 `energy_grant` 叠加。
      - 每秒自然回复 `_base_regen`：所有 `energy_regen_*` 卡的 `energy_grant` 叠加。
    - 即时能量卡：在背包中点击立刻获得指定能量，并移除该卡。
  - **胜负判定**：
    - 有相位场驱动器时：当所有配置的敌方波次已经刷完且敌方单位全部被消灭，则判定胜利。
    - 相位场驱动器被摧毁则立即失败。

- **战后与成长**
  - **基础资源掉落**：
    - `BasicResources.get_drops_for_level(level)` 根据关卡与时代计算：
      - 基本纳米颗粒 `basic_nano`
      - 能量块 `energy_block`
  - **蓝图碎片与纳米材料**：
    - `BattleManager` 在敌人死亡时调用 `_roll_blueprint_drops`，根据敌人原型配置的 `drops` 掉落蓝图碎片。
    - `GameManager._grant_basic_resources_for_current_level` 在胜利后：
      - 发放基础资源。
      - 给 `BlueprintManager` 一定量纳米材料（用于解析蓝图）。
      - 有小概率根据当前时代额外掉落 1 个随机蓝图碎片。
  - **蓝图解析与解锁**：
    - `BlueprintManager` 记录碎片数与纳米材料：
      - 碎片达到需求后可消耗碎片解析蓝图并获得额外纳米材料。
      - 解锁蓝图会通过 `SignalBus.blueprint_unlocked` 通知 UI，并进入可制造/掉落池。

---

## 卡牌蓝图总览

### 1. 默认平台卡（`default_cards.gd`）

- 威克斯装甲侦察车（`hound`）
- 雷诺装甲护卫车（`guard`）
- 马克V型重型坦克（`titan`）
- 要塞固定炮（`fortress`）
- 轻型侦察车（`scout`）
- 雷诺FT突击坦克（`raider`）
- 攻城重炮（`siege`）
- 载机母舰（`carrier`）
- 野战维修车（`medic`）
- 渗透侦察型（`stealth`）
- 全装型机动舱（`omega_platform`）

> 这些平台都可作为蓝图（`get_all_blueprint_ids`），直接决定前线单位的移动、耐久与武器挂载数量。

### 2. 默认武器卡

- MP18冲锋枪（`smg`）
- 李-恩菲尔德步枪（`rifle`）
- 马克沁机枪（`mg`）
- 斯托克斯迫击炮（`rocket`）
- 鲁格 P08（`pistol`）
- 温彻斯特 M1897 堑壕枪（`shotgun`）
- 毛瑟 G98 狙击型（`sniper`）
- 76mm 高射炮（`flak`）
- 光束步枪（`laser`）
- 制导火箭（`missile`）
- 米加粒子炮（`omega_cannon`）

> 武器控制单位的输出风格，从近战扫射到远程重炮、光束与导弹。

### 3. 能量卡

- **战前能量卡（`energy_start_1` ~ `energy_start_7`）**  
  - 名称示例：战前能量 I ~ VII  
  - 效果：装入相位仪时，按等级给开局初始能量 +0 / +10 / +20 / +30 / +40 / +55 / +70。

- **能量收集卡（`energy_regen_1` ~ `energy_regen_7`）**  
  - 名称示例：能量收集 I ~ VII  
  - 效果：装入相位仪时，每秒自然回复 +0.0 / +0.1 / +0.2 / +0.3 / +0.4 / +0.5 / +0.7 能量，可叠加。

- **即时能量卡**  
  - 即时能量（`energy_s`）：背包中点击一次性获得 15⚡，并略微降低战中自然回复。

> 战前/收集能量卡本身也作为蓝图，可通过掉落、任务或商店加入进度系统。

### 4. 敌人掉落蓝图（`enemy_blueprints.gd` — 精选）

- 武器类：
  - MP18 冲锋枪·改（`smg_mk2`）
  - 干扰手枪（`emp_pulse`）
  - 轻型斯托克斯迫击炮（`mini_rocket`）
  - 突击冲锋枪（`phase_lance`）
  - 长程反坦克步枪（`railgun`）
  - 高爆榴霰弹（`thunder_field`）
  - 光束步枪·续航型（`energy_leech`）
  - 米加光束炮（`void_beam`）
  - 重型迫击炮（`syn_colossus_cannon`）
  - 超频模块（`overclock_matrix`，一次性增益型模块）

- 平台类：
  - 盾卫装甲车（`bulwark`）
  - 无线电干扰车（`jammer_platform`）
  - 重型载机母舰（`drone_carrier`）
  - 野战维修车·改（`regen_frame`）
  - 马克V型·改（`titan_mk2`）
  - 突击坦克·风暴型（`storm_rider`）

- **生成蓝图池**：
  - 每个时代自动生成大量武器/平台蓝图：
    - id 形如 `bp_ww1_001` … `bp_near_056`。
    - 名称示例：“一战·蓝图001”、“冷战·蓝图120”。

---

## 敌人原型（`enemy_archetypes.gd`）

### 一战敌人

- 步兵班·MP18冲锋枪（`basic_infantry`）
- 盾卫车·鲁格P08（`shield_guard`）
- 侦察摩托·鲁格P08（`scout_drone`）
- 步兵班·斯托克斯迫击炮（`rocket_infantry`）
- 干扰车·鲁格P08（`jammer_unit`）

### 二战敌人与精英

- 突击坦克·MP18冲锋枪（`phase_raider`）
- 狙击阵地·毛瑟G98狙击型（`sniper_tower`）
- 载机母舰·李-恩菲尔德步枪（`drone_carrier_enemy`）
- 维修车·李-恩菲尔德步枪（`regen_armor`）
- 高射炮阵地·76mm高射炮（`storm_suppressor`）
- 机枪巢·马克沁机枪（`heavy_mg_nest`）
- 突击班·李-恩菲尔德步枪（`assault_rifle_squad`）

### 冷战/现代敌人

- 补给节点·—（`energy_node`）
- 导弹车·制导火箭（`cold_war_missile_truck`）

### 头目单位

- 超重型坦克·斯托克斯迫击炮（`phase_colossus`）
- 光束炮舰·光束步枪（`void_cruiser`）
- 风暴核心·—（`storm_core`）
- 指挥中枢·马克沁机枪（`ai_nexus`）

> 此外还有自动生成的普通敌人（id 如 `enemy_ww1_01` 等），按时代和单位类型组合不同武器与属性，用于填充各关卡波次。

---

## 相位法则（`phase_laws.gd`）

按家族与类型（被动/主动）区分，以下为主要示例：

- **钢铁（STEEL）**
  - 被动：钢铁·相位装甲（`steel_phase_armor`）—— 友方载具装甲加成。
  - 主动：钢铁·堡垒之墙（`steel_bastion_wall`）—— 在区域生成护盾墙。
  - 被动：钢铁·快速维修（`steel_quick_repair`）—— 友军载具脱战回复。

- **烈焰（FLAME）**
  - 被动：烈焰·热能过载（`flame_heat_overload`）—— 攻击附带灼烧。
  - 主动：烈焰·前线火力压制（`flame_front_bombard`）—— 前线区域炮击。
  - 主动：烈焰·灼烧印记（`flame_mark`）—— 对指定区域施加持续灼烧印记。

- **雷霆（THUNDER）**
  - 主动：雷霆·电磁风暴（`thunder_emp_storm`）—— 大范围 EMP 干扰敌方载具。
  - 主动：雷霆·链式放电（`thunder_chain_discharge`）—— 链式闪电攻击多目标。

- **虚空（VOID）**
  - 主动：虚空·时空涟漪（`void_time_ripple`）—— 全图时间减速场。
  - 主动：虚空·护盾转移（`void_barrier_shift`）—— 调整护盾/生命分配。

> 所有法则都有研究需求（知识值）与环境要求（天气、地形、能量场、昼夜），需要在战前界面满足条件才能激活。

---

## 文件位置

- 玩法与流程：`README.md`、`scenes/main.gd`、`managers/game_manager.gd`、`managers/battle_manager.gd`
- 卡牌与蓝图：`data/default_cards.gd`、`data/enemy_blueprints.gd`
- 敌人原型：`data/enemy_archetypes.gd`
- 相位法则：`data/phase_laws.gd`
- 关卡与时代：`data/level_eras.gd`

