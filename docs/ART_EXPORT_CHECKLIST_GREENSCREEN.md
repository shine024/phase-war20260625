# 美术导出独立清单（绿底抠图版）

> 用途：供外包 / 自行导出时逐项核对。  
> **与主清单关系**：本文件只约束**像素画交付规格与命名**；路径对齐见 `docs/ART_ASSET_CHECKLIST.md` 与代码引用。  
> 更新：2026-05-02  
> **更新：2026-05-03** — **本仓库当前已入库 PNG**（`card_icons`、`cards/frames`、`ui/icons`、`ui/factions` 128、`ui/stars`、`ui/instruments` 除 `pi_r_free_deploy`、敌方序列帧等）均为 **抠绿后的透明底终稿**。下文「整幅 #00FF00 绿底」仍保留为 **对外再发包 / 新增条目** 时的导出与验收规范，不必理解为现有文件仍为绿底。

---

## 一、全局规范（所有条目通用）

| 项目 | 要求 |
|------|------|
| 背景 | 整幅画布铺 **纯色 #00FF00**（RGB `0,255,0`），**无渐变**。交付前勿压缩成带灰边的 JPEG。 |
| 抠图 | 后期用色键去除绿底；主体、描边、光效 **不得使用与背景相同的 #00FF00**；需要半透明边缘时，用深色描边避免绿边渗入主体。 |
| 格式 | **PNG**。 |
| 安全区 | 图标/卡图类：主体占画布约 **70～90%**，四周留 **8～12%** 边距，避免贴边裁切。 |
| 命名 | **`英文id_中文说明_后缀.png`**：仅用 **半角下划线** 连接段；**中文段用于你方核对**，导入引擎前可批量改名为纯 `id.png`。Windows 须启用 UTF-8 或保证编辑器存为 UTF-8。 |
| 例外 | **法则卡名、势力名**中含间隔号 `·` 时，文件名里可写成下划线 `_` 代替 `·`（例：`钢铁_相位装甲`）。 |

---

## 二、战场：我方映射的 12 个敌方原型（`assets/enemies/SpriteSheet/<id>/`）

**说明**：每原型需 **idle / run / attack** 三套序列帧（可再增 hurt 等）。每帧单独 PNG，绿底。导入 `SpriteFrames` 时由程序或你在 Godot 里拼。

**建议单帧画布**：**512×512** px（不超过工程内敌方帧上限 768 边长即可）；角色脚底大致对齐画布**水平中线偏下**，避免跑起来「飘」。

**每动画最低帧数（建议）**

| 动画英文名 | 中文用途 | 最少帧数 |
|------------|----------|----------|
| idle | 待机动 | 4 |
| run | 移动 | 6 |
| attack | 攻击 | 4 |

**命名示例**（第 1 帧；`帧号` 为两位或三位零填充）：

`{archetype_id}_{中文原型}_{动画}_{帧号}.png`

| 序号 | archetype_id（英文） | 中文（写入文件名） | 放置目录（相对 `assets/enemies/SpriteSheet/`） |
|------|----------------------|--------------------|--------------------------------------------------|
| B01 | `enemy_ww1_infantry_basic` | 一战步兵基础 | `enemy_ww1_infantry_basic/` |
| B02 | `enemy_ww2_infantry` | 二战步兵 | `enemy_ww2_infantry/` |
| B03 | `elite_ww1_armored` | 一战装甲精英 | `elite_ww1_armored/` |
| B04 | `enemy_ww1_mg_nest` | 一战机枪巢 | `enemy_ww1_mg_nest/` |
| B05 | `enemy_modern_stryker` | 现代斯特赖克 | `enemy_modern_stryker/` |
| B06 | `enemy_cold_btr` | 冷战BTR | `enemy_cold_btr/` |
| B07 | `enemy_future_hovertank` | 近未来悬浮坦克 | `enemy_future_hovertank/` |
| B08 | `enemy_ww1_mortar` | 一战迫击炮 | `enemy_ww1_mortar/` |
| B09 | `enemy_cold_m113` | 冷战M113 | `enemy_cold_m113/` |
| B10 | `enemy_modern_marine` | 现代陆战队步兵 | `enemy_modern_marine/` |
| B11 | `elite_future_spectre` | 近未来幽魂精英 | `elite_future_spectre/` |
| B12 | `enemy_future_mech` | 近未来机甲 | `enemy_future_mech/` |

**单帧文件名示例**（B01 待机第 1 帧）：

`enemy_ww1_infantry_basic_一战步兵基础_idle_001.png`

对 **run**、**attack** 同理替换动画段与帧号。

---

## 三、战场：Boss 入场 / 死亡（可选增强，`data/enemy_archetypes.gd` 中带 `boss` 标签）

**画布与绿底**：同第二节。Boss 体积可增至 **768×768** 以内（勿超工程单帧上限）。

| 序号 | archetype_id | 中文（文件名用） | 动画名（建议） | 最少帧数 | 文件名示例 |
|------|----------------|------------------|----------------|----------|------------|
| BB1 | `boss_ww1_av7` | 一战Boss_AV7 | intro（入场） | 6 | `boss_ww1_av7_一战Boss_AV7_intro_001.png` |
| BB1b | 同上 | 同上 | death（死亡） | 6 | `boss_ww1_av7_一战Boss_AV7_death_001.png` |
| BB2 | `boss_ww2_kingtiger` | 二战Boss_虎王 | intro | 6 | `boss_ww2_kingtiger_二战Boss_虎王_intro_001.png` |
| BB2b | 同上 | 同上 | death | 6 | `boss_ww2_kingtiger_二战Boss_虎王_death_001.png` |
| BB3 | `boss_cold_mig` | 冷战Boss_米格 | intro | 6 | `boss_cold_mig_冷战Boss_米格_intro_001.png` |
| BB3b | 同上 | 同上 | death | 6 | `boss_cold_mig_冷战Boss_米格_death_001.png` |
| BB4 | `boss_modern_command` | 现代Boss_指挥节点 | intro | 6 | `boss_modern_command_现代Boss_指挥节点_intro_001.png` |
| BB4b | 同上 | 同上 | death | 6 | `boss_modern_command_现代Boss_指挥节点_death_001.png` |
| BB5 | `boss_future_nexus` | 近未来Boss_中枢 | intro | 6 | `boss_future_nexus_近未来Boss_中枢_intro_001.png` |
| BB5b | 同上 | 同上 | death | 6 | `boss_future_nexus_近未来Boss_中枢_death_001.png` |

---

## 四、卡框（`assets/cards/frames/`）

| 目标文件名（建议直接采用，已含中文） | 尺寸 | 内容要求 |
|----------------------------------------|------|----------|
| `legendary_传说边框_512.png` | 512×512 | 仅边框与角饰；**中央开窗区可保留 #00FF00** 便于整格抠除；线条勿用纯绿。 |

> 已有 common / uncommon / rare / epic 若重导出，统一加 `_普通边框_512.png` 等后缀亦可，以你流水线为准。

---

## 五、卡面小图 `assets/card_icons/`（按 `card_id`，512×512，绿底）

**命名**：`{card_id}_{中文卡名}_512.png`

### 5.1 平台卡（`default_cards.gd` 载具段，共 29 张：各时代 `platform_*` + `omega_platform`）

| card_id | 中文卡名（写入文件名） |
|---------|------------------------|
| platform_ww1_light | 威克斯侦察车 |
| platform_ww1_medium | 马克V型坦克 |
| platform_ww1_fort | 要塞固定炮 |
| platform_ww1_radar | 野战观测站 |
| platform_ww1_medic | 野战救护车 |
| platform_ww2_light | M8灰狗装甲车 |
| platform_ww2_medium | 谢尔曼坦克 |
| platform_ww2_heavy | 虎式坦克 |
| platform_ww2_raider | BA64轻型突击车 |
| platform_ww2_radar | 雷达指挥车 |
| platform_ww2_siege | 203毫米迫击炮 |
| platform_ww2_fortress | 混凝土碉堡 |
| platform_cold_light | 悍马侦察车 |
| platform_cold_medium | T72主战坦克 |
| platform_cold_ifv | 布雷德利步战车 |
| platform_cold_scout | BRDM2侦察车 |
| platform_cold_radar | 电子对抗站 |
| platform_cold_carrier | BMP步战车 |
| platform_modern_light | 北极星全地形车 |
| platform_modern_medium | 艾布拉姆斯坦克 |
| platform_modern_radar | 相控阵雷达车 |
| platform_modern_spg | 帕拉丁自行火炮 |
| platform_modern_stealth | 光学隐匿侦察车 |
| platform_modern_guard_heavy | 豹2A7主战坦克 |
| platform_future_light | 光学侦察车 |
| platform_future_medium | 悬浮坦克 |
| platform_future_radar | 量子感知平台 |
| platform_future_heavy | 机甲步行者 |
| omega_platform | 全装型机动舱 |

**示例**：`platform_ww1_light_威克斯侦察车_512.png`

### 5.2 能量卡（10）

| card_id | 中文卡名 |
|---------|----------|
| energy_start_1 | 战前能量一 |
| energy_start_2 | 战前能量二 |
| energy_start_3 | 战前能量三 |
| energy_regen_1 | 能量收集一 |
| energy_regen_2 | 能量收集二 |
| energy_regen_3 | 能量收集三 |
| energy_instant_s | 小型能量包 |
| energy_instant_m | 中型能量包 |
| energy_instant_l | 大型能量包 |
| energy_hybrid | 混合能量核心 |

### 5.3 法则卡（`data/phase_laws.gd`，25）

| card_id（= law_id） | 中文卡名 |
|----------------------|----------|
| steel_phase_armor | 钢铁相位装甲 |
| flame_heat_overload | 烈焰热能过载 |
| thunder_emp_storm | 雷霆电磁风暴 |
| void_time_ripple | 虚空时空涟漪 |
| steel_bastion_wall | 钢铁堡垒之墙 |
| flame_front_bombard | 烈焰前线火力压制 |
| thunder_chain_discharge | 雷霆链式放电 |
| void_barrier_shift | 虚空护盾转移 |
| steel_quick_repair | 钢铁快速维修 |
| flame_mark | 烈焰灼烧印记 |
| steel_aegis_link | 钢铁护阵联结 |
| steel_anchor_field | 钢铁锚定力场 |
| steel_fortify_protocol | 钢铁固壁协议 |
| flame_scorch_wave | 烈焰灼浪推进 |
| flame_ember_screen | 烈焰灰烬幕障 |
| flame_core_rupture | 烈焰核心破裂 |
| flame_afterburn | 烈焰余烬加燃 |
| thunder_ion_net | 雷霆离子网 |
| thunder_arc_beacon | 雷霆弧光信标 |
| thunder_surge_drive | 雷霆激涌驱动 |
| thunder_static_domain | 雷霆静电域 |
| void_phase_cloak | 虚空相位披幕 |
| void_entropy_lens | 虚空熵镜 |
| void_gravity_well | 虚空引力井 |
| steel_resonant_plate | 钢铁共振装甲 |

---

## 六、功能 UI 图标（`assets/ui/icons/`，256×256，绿底）

**命名**：`{英文文件名主体}_{中文用途}_256.png`

| 建议完整文件名 | 中文用途 |
|----------------|----------|
| `icon_shop_商店_256.png` | 商店 |
| `icon_quest_任务_256.png` | 任务 |
| `icon_leaderboard_排行榜_256.png` | 排行榜 |
| `icon_settings_设置_256.png` | 设置 |
| `icon_help_帮助_256.png` | 帮助 |
| `icon_close_关闭_256.png` | 关闭 |
| `icon_arrow_left_左箭头_256.png` | 左箭头（若重导出） |
| `icon_arrow_right_右箭头_256.png` | 右箭头 |
| `icon_filter_筛选_256.png` | 筛选 |
| `icon_sort_排序_256.png` | 排序 |
| `icon_backpack_背包_256.png` | 背包 |
| `icon_blueprint_蓝图_256.png` | 蓝图 |
| `icon_phase_instrument_相位仪_256.png` | 相位仪 |
| `icon_law_法则_256.png` | 法则 |
| `icon_save_保存_256.png` | 保存 |
| `icon_lock_锁定_256.png` | 锁定 |
| `icon_upgrade_升级_256.png` | 升级 |
| `icon_equip_装备_256.png` | 装备 |
| `icon_remove_卸下_256.png` | 卸下 |
| `icon_coin_货币_256.png` | 货币 |

---

## 七、势力 Logo（`assets/ui/factions/`，绿底）

**命名**：`{company_id}_{中文公司名}_{边长}.png`

| company_id | 中文公司名 | 32px 文件名示例 | 128px 文件名示例 |
|------------|------------|-----------------|------------------|
| iron_wall_corp | 钢壁防务公司 | `iron_wall_corp_钢壁防务公司_32.png` | `iron_wall_corp_钢壁防务公司_128.png` |
| nova_arms | 新星兵工制造 | `nova_arms_新星兵工制造_32.png` | `nova_arms_新星兵工制造_128.png` |
| aether_dynamics | 以太动力重工 | `aether_dynamics_以太动力重工_32.png` | `aether_dynamics_以太动力重工_128.png` |
| quantum_logistics | 量子后勤集团 | `quantum_logistics_量子后勤集团_32.png` | `quantum_logistics_量子后勤集团_128.png` |
| helix_recon | 螺旋侦察系统 | `helix_recon_螺旋侦察系统_32.png` | `helix_recon_螺旋侦察系统_128.png` |
| void_research | 虚空相位研究所 | `void_research_虚空相位研究所_32.png` | `void_research_虚空相位研究所_128.png` |
| frontier_union | 边境联合公司 | `frontier_union_边境联合公司_32.png` | `frontier_union_边境联合公司_128.png` |

**要求**：Logo 主体勿用纯绿；小尺寸需可读剪影。

---

## 八、星级图标（`assets/ui/stars/`，128×128，绿底）

**命名**：`star_{n}_{中文星级}_128.png`

| n | 中文星级 | 文件名示例 |
|---|----------|------------|
| 1 | 一星 | `star_1_一星_128.png` |
| 2 | 二星 | `star_2_二星_128.png` |
| 3 | 三星 | `star_3_三星_128.png` |
| 4 | 四星 | `star_4_四星_128.png` |
| 5 | 五星 | `star_5_五星_128.png` |
| 6 | 六星 | `star_6_六星_128.png` |
| 7 | 七星 | `star_7_七星_128.png` |

风格：金色主色可保留，**星体轮廓外发光勿用 #00FF00**。

---

## 九、相位仪属性图标（`assets/ui/instruments/`，128×128，绿底）

**命名**：`{property_id}_{中文名无百分号}_128.png`  
（`data/phase_instruments.gd`）

### 9.1 标准池（13）

| property_id | 中文名（写入文件名） |
|-------------|----------------------|
| pi_atk | 卡牌伤害加成 |
| pi_def | 防御加成 |
| pi_hp | 生命加成 |
| pi_xp | 经验加成 |
| pi_drop | 掉落加成 |
| pi_energy_out | 能量输出加成 |
| pi_energy_rec | 能量恢复加成 |
| pi_energy_cost | 能量消耗减免 |
| pi_deploy_range | 部署范围加成 |
| pi_crit | 暴击率加成 |
| pi_crit_dmg | 暴击伤害加成 |
| pi_move_speed | 移速加成 |
| pi_attack_speed | 攻速加成 |

### 9.2 稀有池（13）

| property_id | 中文名 |
|-------------|--------|
| pi_r_first_deploy | 初次部署 |
| pi_r_kill_energy | 战斗续能 |
| pi_r_law_boost | 法则共鸣 |
| pi_r_energy_fountain | 能量涌泉 |
| pi_r_dmg_reflect | 伤害反射 |
| pi_r_respawn | 相位重生 |
| pi_r_shield | 初始护盾 |
| pi_r_cascade | 连锁反应 |
| pi_r_overload | 过载强化 |
| pi_r_last_stand | 最后意志 |
| pi_r_energy_burst | 能量爆发 |
| pi_r_scale | 越战越强 |
| pi_r_free_deploy | 零成本部署 |

**示例**：`pi_atk_卡牌伤害加成_128.png`

---

## 十、全装型静态战场图（可选重导出，`assets/unit_sprites/`）

| 文件名建议 | 尺寸 | 说明 |
|------------|------|------|
| `omega_platform_全装型机动舱_战场静帧.png` | 与现工程一致或 ≤768 边长 | 绿底；用于非 SpriteFrames 路径时的单张贴图。 |

---

## 十一、条目数量汇总（便于拆包）

| 分类 | 约计 PNG 张数（按最低帧数粗算） |
|------|--------------------------------|
| 十二原型 × (idle4+run6+attack4) | 12×14 = **168** |
| Boss intro+death ×5 ×12 | **120** |
| legendary 框 | **1** |
| 卡面 platform+energy+law | 29+10+25 = **64** |
| UI 图标 §六 | **20** |
| 势力 7×2 | **14** |
| 星级 7 | **7** |
| 相位仪 26 | **26** |
| omega 静帧（可选） | **1** |
| **合计（约）** | **420+**（随 Boss/动画帧数增加） |

---

## 十二、导入 Godot 前改名提示

若引擎资源路径要求**纯英文**，可批量规则：

- 卡图：`{card_id}_512.png` → 放入 `assets/card_icons/`  
- 相位仪：`{property_id}.png`  
- 敌方序列帧：保持目录为 `archetype_id`，帧文件可改为 `idle_001.png` 等纯英文。

本清单以**交付与核对**为主，**改名规则由你方流水线统一**即可。
