# 绿底美术导出任务单（给「另一台 AI / 外包」执行版）

> **用途**：下游只需读本文件即可生成/导出全部约定资源；**中文文件名**仅给你方临时核对，入库 Godot 前可删中文段。  
> **引擎事实**：背包卡格与相位仪槽位同尺寸，见 `scenes/ui/phase_slot.gd` → `PhaseSlot.SLOT_SIZE`；卡面条目见 `scenes/ui/backpack_card_item.tscn` + `backpack_card_item.gd`。  
> **修订**：2026-05-02 全文重写（比例、风格、势力、尺寸、提示词）。  
> **修订**：2026-05-03 — 仓库内已入库的静帧/UI 图 **已完成色键、透明底**；本文绿底条款面向 **新增外包批次** 的导出约定，与磁盘上现有 PNG 状态不矛盾。

---

## 0. 给执行 AI 的角色说明（复制块）

```
你是游戏《相位战争 Phase War》的像素/插画资产生成与导出专员。必须遵守：
1) 所有交付 PNG 的「画布背景」为纯绿 #00FF00（RGB 0,255,0），无渐变；主体与描边禁止使用该绿。
2) 卡面立绘与卡框的「宽高比」必须与背包格子一致：宽:高 = 50:80 = 5:8（竖长条），见本文 §2。
3) 卡面在 UI 中会被缩到极小图标区（约 28×28 像素）仍能辨认，构图必须大剪影、高对比、少细线。
4) 不出现任何可读文字、水印、Logo、现实国家敏感符号；单位/装备为架空科幻。
5) 每条提示词末尾追加负面提示词块（见 §11）。
```

---

## 1. 全局技术规范

| 项 | 硬性要求 |
|----|----------|
| 背景 | 铺满画布 **#00FF00**（`#00FF00` / RGB `0,255,0`）；导出 PNG；不要用 JPEG。 |
| 抠图 | 后期色键去背；主体外轮廓可加 **1～2px 深色描边**（#191919）防止绿边渗入。 |
| 禁止 | 主体、装备高光、爆炸内层使用 **#00FF00**；不要用「接近绿的黄绿」做高光。 |
| 命名 | `英文id_中文简写_用途.png`；中文仅核对用。 |

---

## 2. 与背包格子一致的比例（卡面 + 卡框，必读）

### 2.1 代码中的格子尺寸

| 常量 | 值 | 代码位置 |
|------|-----|----------|
| `PhaseSlot.SLOT_SIZE` | **宽 50 × 高 80**（UI 像素） | `scenes/ui/phase_slot.gd` |
| 背包单卡 `BackpackCardItem` | 与上相同 | `backpack_card_item.gd` 引用 `PhaseSlot.SLOT_SIZE` |
| 卡内 `Icon` TextureRect 最小边 | **28 × 28**（缩略图显示区） | `backpack_card_item.tscn` / `CARD_LIST_ICON_DISPLAY_MIN` |
| 顶部分类色条高度 | **4px**（相对 80 高） | `backpack_card_item.tscn` `TypeBar` |

**宽高比（你方必须遵守）**

- **整张「卡槽可视区域」比例**：**50 : 80 = 5 : 8**（竖向，宽小于高）。  
- **卡面立绘、传说框 PNG**：画布比例 **必须 = 5 : 8**，与背包格一致，避免导入后被压扁/裁切违和。

### 2.2 推荐导出像素（任选一档，保持 5:8）

| 档位 | 宽 × 高 | 说明 |
|------|---------|------|
| **推荐主档** | **500 × 800** | 5:8；细节足够，文件适中。 |
| 高清档 | 750 × 1200 | 仍 5:8；需控文件体积时用 WebP 另议。 |
| 性能档 | 400 × 640 | 仍 5:8；线条需更粗。 |

**构图安全区（在 5:8 画布内）**

- 外留 **6%～8%** 边距勿贴边（适配圆角裁切与 UI margin）。  
- 若画「全身载具/机甲」：**脚底落在画面下约 55%～65% 高度处**，头部勿顶满（给顶栏色条与 UI 留白心理空间）。  
- **中心视觉重量**放在画布水平中线附近，避免重要信息落在最下 12%（给费用/等级条心理预留）。

### 2.3 缩略图可读性（与 28×28 显示相关）

UI 内图标区最小约 **28×28**。生成后请在 **导出前** 将成品缩小到 32 或 48 像素自查：  
- 轮廓仍可辨认载具/符号类型；  
- 避免平行细线间距小于 3px（在源分辨率下按比例换算）；  
- 高对比：暗部 `#1a1f2e` ～亮部 `#e8eefc` 阶调为主，**中间灰慎用过厚**。

---

## 3. 全游戏卡面风格圣经（执行 AI 必须统一）

### 3.1 世界观调性

- **架空**相位战争：从一战堑壕科技一路拉到近未来机甲与相位武器；**不要**真实国徽、真实型号涂装文字、现实军旗。  
- 视觉：**硬表面科幻 + 军事载具**；材质以装甲板、铆钉、反应装甲块、散热格栅、相位发光线条为主。  
- 色调：**略去饱和**的背景环境 + **一张卡 1～2 个高饱和点缀色**（能量口、相位灯、炮口热晕）。

### 3.2 与 UI 顶栏色条语义对齐（卡面点缀可参考）

代码里类型色条（`TYPE_BAR_COLORS`，`backpack_card_item.gd`）：

| 卡类型 | RGB（约） | 卡面点缀建议 |
|--------|-----------|--------------|
| 平台 PLATFORM | `0.1,0.5,0.9` | 冷蓝高光、装甲反射 |
| 能量 ENERGY | `0.15,0.75,0.35` | 青绿能量导管、充能环 |
| 法则 LAW | `0.85,0.2,0.5` | 品红相位符文、裂隙光 |

### 3.3 稀有度与卡框颜色（与 `game_constants.gd` → `get_rarity_color` 对齐）

| 稀有度 | RGB（0–1） | Hex（约） | 框/光效提示 |
|--------|------------|-----------|--------------|
| common | 0.75,0.75,0.75 | #BFBFBF | 银灰细框，少光晕 |
| uncommon | 0.40,0.90,0.50 | #66E680 | 青绿内发光细边 |
| rare | 0.40,0.65,1.00 | #66A6FF | 冰蓝双边线 |
| epic | 0.75,0.40,1.00 | #BF66FF | 紫晶切角高光 |
| legendary | 1.00,0.70,0.30 | #FFB34D | **金橙**粗框 + 微弱星屑颗粒 |

**卡框 PNG 要求（含 `legendary`）**

- 画布 **5:8** 与卡面同；**仅边框与角饰**，中央 **#00FF00** 填满便于抠除；边框线宽在 500 宽基准上约 **10～18px**（传说最粗）。  
- 圆角视觉与 UI 面板一致比例：槽宽 50 时圆角约 5 → 500 宽画布圆角约 **50px**（可 ±10px）。  
- **legendary** 额外：角上可加小对称「翼」形装饰，仍保持可色键去背。

---

## 4. 七势力视觉指导（Logo + 可选卡面点缀）

> 文案来源：`data/company_definitions.gd`。Logo 画布：**32×32** 与 **128×128** 各一版，**仍绿底**；主体占 **70～85%**。

| id | 中文名 | 风格关键词（写入英文 prompt 时可直译） | 负面补充 |
|----|--------|----------------------------------------|----------|
| iron_wall_corp | 钢壁防务公司 | 盾形徽章、叠层钢板、铆钉、冷灰蓝、稳重对称 | 避免火焰主色 |
| nova_arms | 新星兵工制造 | 斜向枪管抽象、橙红高热、速度线、进攻性三角 | 避免过多蓝色冷调 |
| aether_dynamics | 以太动力重工 | 涡轮环形、青色推进光、机械剖面、精密感 | 避免有机生物感 |
| quantum_logistics | 量子后勤集团 | 等距箱子阵列、数据粒子流、紫青配色 | 避免单一大块留白 |
| helix_recon | 螺旋侦察系统 | 螺旋雷达波瓣、浅绿荧光、侦察透镜 | 避免厚重坦克剪影 |
| void_research | 虚空相位研究所 | 裂隙眼睛、暗紫黑、细白相位线、神秘几何 | 避免高饱和暖黄 |
| frontier_union | 边境联合公司 | 交叉飘带、多边形拼贴、土黄+铁锈点缀 | 避免过于干净企业风 |

**势力 Logo 通用英文 prompt 模板**

```
Emblem logo for fictional sci-fi military contractor "{COMPANY_ID}", {STYLE_KEYWORDS from table},
flat vector-like icon, centered, bold readable silhouette at 32px, thick shapes, no text,
solid chroma key green background #00FF00 only, no other greens in subject, PNG, transparent-friendly edges with dark outline.
```

将 `{COMPANY_ID}`、`{STYLE_KEYWORDS}` 替换为表中行。

---

## 5. 战场序列帧（`assets/enemies/SpriteSheet/<id>/`）

### 5.1 画布与比例

- 单帧推荐 **512 × 512** 正方形（与工程敌方帧上限 768 兼容）；**整幅底 #00FF00**。  
- 角色脚底约在画面 **下 58%～65%** 水平线；保留头顶安全区。

### 5.2 每原型三套动画

| 动画 id | 最少帧数 | 说明 |
|---------|----------|------|
| idle | 4 | 微动呼吸感，循环 |
| run | 6 | 循环跑；左右镜像由程序处理，默认画**朝右** |
| attack | 4 | 可非循环，末帧回 idle |

**命名**：`<id>_中文简写_<anim>_帧号两位.png`  
例：`enemy_ww1_infantry_basic_一战步兵_idle_01.png`

### 5.3 十二原型（我方映射用）

| id | 中文简写 |
|----|----------|
| enemy_ww1_infantry_basic | 一战步兵 |
| enemy_ww2_infantry | 二战步兵 |
| elite_ww1_armored | 一战装甲精英 |
| enemy_ww1_mg_nest | 一战机枪巢 |
| enemy_modern_stryker | 现代斯特赖克 |
| enemy_cold_btr | 冷战BTR |
| enemy_future_hovertank | 近未来悬浮坦 |
| enemy_ww1_mortar | 一战迫击炮 |
| enemy_cold_m113 | 冷战M113 |
| enemy_modern_marine | 现代陆战步兵 |
| elite_future_spectre | 近未来幽魂 |
| enemy_future_mech | 近未来机甲 |

### 5.4 Boss 入场 / 死亡（各 ≥6 帧）

| id | 中文 |
|----|------|
| boss_ww1_av7 | 一战Boss |
| boss_ww2_kingtiger | 二战Boss |
| boss_cold_mig | 冷战Boss |
| boss_modern_command | 现代Boss |
| boss_future_nexus | 近未来Boss |

**战场通用英文 prompt 后缀（接在主体描述后）**

```
, single game sprite character, orthographic or slight 3/4 view, hardsurface sci-fi military,
full body fits in frame, strong silhouette, limited fine detail, dark metal with small accent lights,
chroma key green screen background #00FF00 ONLY flat, no ground plane texture, no shadow on fake floor,
PNG pixel-friendly edges, no text.
```

---

## 6. 卡面立绘 `assets/card_icons/`（全部 5:8 竖版）

### 6.1 统一英文 prompt 骨架（卡面）

```
Vertical card illustration {5:8 aspect EXACTLY width:height = 500:800 or 400:640}, fictional sci-fi unit "{CARD_ID}",
{ERA_OR_ROLE_FLAVOR}, hardsurface military vehicle or emblematic object for law/energy,
bold silhouette readable at 28px thumbnail, high contrast, limited micro-detail,
accent colors aligned with card type (blue platform / green energy / magenta law),
full canvas chroma key green #00FF00 background only, no text, no watermark, no real-world insignia.
```

- **平台卡**：`ERA_OR_ROLE_FLAVOR` 用「WW1 trench tech / WW2 industrial armor / Cold War IFV / Modern composite armor / Near-future hover mech」等与 `card_id` 时代匹配短语。  
- **能量卡**：强调 **电池格、导管、环形充能、读数灯** 等抽象能源符号，避免具体现实品牌。  
- **法则卡**：强调 **符文环、裂隙几何、家族色系**（钢铁银、烈焰橙红、雷霆电蓝白、虚空暗紫）。

### 6.2 表：平台卡（29）— `card_id`、中文临时名、时代提示（写入 prompt）

（文件名建议：`{card_id}_中文_500x800.png`）

| card_id | 中文临时 | prompt 时代/角色片段（英文插入骨架） |
|---------|----------|----------------------------------------|
| platform_ww1_light | 威克斯侦察 | WW1 light recon armored car, mud splashes, tall silhouette |
| platform_ww1_medium | 马克V坦克 | WW1 rhomboid tank, rivets, slow heavy silhouette |
| platform_ww1_fort | 要塞炮 | WW1 fixed fortress gun emplacement, low wide profile |
| platform_ww1_radar | 野战观测 | WW1 optical trench periscope tower, thin vertical |
| platform_ww1_medic | 野战救护 | WW1 ambulance cross stylized sci-fi, soft edges |
| platform_ww2_light | M8灰狗 | WW2 light AFV, sloped armor |
| platform_ww2_medium | 谢尔曼 | WW2 medium tank, rounded cast hull vibe |
| platform_ww2_heavy | 虎式 | WW2 heavy tank, interleaved roadwheel hint abstract |
| platform_ww2_raider | BA64 | WW2 compact raider AFV, angular |
| platform_ww2_radar | 雷达指挥 | WW2 radar mast vehicle |
| platform_ww2_siege | 203迫击 | WW2 siege mortar heavy stub barrel |
| platform_ww2_fortress | 混凝土碉堡 | WW2 bunker blockhouse sci-fi |
| platform_cold_light | 悍马 | Cold War light utility MRAP vibe |
| platform_cold_medium | T72 | Cold War MBT low profile turret |
| platform_cold_ifv | 布雷德利 | Cold War IFV troop door hint |
| platform_cold_scout | BRDM2 | Cold War scout wedge hull |
| platform_cold_radar | 电子对抗 | Cold War EW van arrays |
| platform_cold_carrier | BMP | Cold War tracked IFV |
| platform_modern_light | 北极星 | Modern light ATV military |
| platform_modern_medium | 艾布拉姆斯 | Modern MBT sharp angles |
| platform_modern_radar | 相控阵雷达 | Modern AESA flat panel arrays |
| platform_modern_spg | 帕拉丁 | Modern self-propelled howitzer long barrel |
| platform_modern_stealth | 光学隐匿 | Modern low-observable scout, faceted |
| platform_modern_guard_heavy | 豹2A7 | Modern heavy MBT sleek turret |
| platform_future_light | 光学侦察 | Near-future light recon drone-car hybrid |
| platform_future_medium | 悬浮坦 | Near-future hover tank, glow under hull |
| platform_future_radar | 量子感知 | Near-future sensor mast quantum glow |
| platform_future_heavy | 机甲步行 | Near-future walking mech heavy |
| omega_platform | 全装机动舱 | Ultimate omni-platform mech, dense hardpoints |

### 6.3 能量卡（10）

| card_id | 中文临时 | prompt 片段 |
|---------|----------|---------------|
| energy_start_1 | 战前能量一 | pre-battle energy cell tier 1, compact battery glyph |
| energy_start_2 | 战前能量二 | tier 2 larger stack |
| energy_start_3 | 战前能量三 | tier 3 stacked cores |
| energy_regen_1 | 能量收集一 | regen ring flow subtle green |
| energy_regen_2 | 能量收集二 | dual regen coils |
| energy_regen_3 | 能量收集三 | triple helix energy |
| energy_instant_s | 小能量包 | small burst pack crystal |
| energy_instant_m | 中能量包 | medium burst |
| energy_instant_l | 大能量包 | large burst pillar |
| energy_hybrid | 混合能量核 | hybrid core half battery half coil |

### 6.4 法则卡（25）— 带家族色系关键词

| card_id | 中文临时 | 家族色 prompt 片段 |
|---------|----------|-------------------|
| steel_phase_armor | 钢铁相位装甲 | steel family silver-gray plates, shield lattice |
| steel_bastion_wall | 钢铁堡垒墙 | steel rising wall slabs |
| steel_quick_repair | 钢铁快速维修 | steel repair sparks cool white |
| steel_aegis_link | 钢铁护阵联结 | steel linking chains light |
| steel_anchor_field | 钢铁锚定力场 | steel anchor pins ground glow |
| steel_fortify_protocol | 钢铁固壁协议 | steel protocol hex stamps |
| steel_resonant_plate | 钢铁共振装甲 | steel resonance ripples |
| flame_heat_overload | 烈焰热能过载 | flame family orange-red heat haze |
| flame_front_bombard | 烈焰前线压制 | flame forward cone |
| flame_mark | 烈焰灼印 | flame mark sigil |
| flame_scorch_wave | 烈焰灼浪 | flame ground wave |
| flame_ember_screen | 烈焰灰烬幕 | flame ash particles curtain |
| flame_core_rupture | 烈焰核心裂 | flame core crack sphere |
| flame_afterburn | 烈焰余烬 | flame trailing embers |
| thunder_emp_storm | 雷霆电磁风暴 | thunder family blue-white lightning area |
| thunder_chain_discharge | 雷霆链式放电 | thunder chaining bolts |
| thunder_ion_net | 雷霆离子网 | thunder ion mesh grid |
| thunder_arc_beacon | 雷霆弧光信标 | thunder beacon column |
| thunder_surge_drive | 雷霆激涌 | thunder surge chevrons |
| thunder_static_domain | 雷霆静电域 | thunder static crackle field |
| void_time_ripple | 虚空时空涟漪 | void family dark violet warp rings |
| void_barrier_shift | 虚空护盾转移 | void barrier panels sliding |
| void_phase_cloak | 虚空相位披幕 | void cloak shards transparency illusion |
| void_entropy_lens | 虚空熵镜 | void lens crystal dark purple |
| void_gravity_well | 虚空引力井 | void spiral inward |

---

## 7. 传说框单文件

| 输出 | 画布 | 文件名（临时） |
|------|------|----------------|
| legendary 边框 | **500×800** 5:8 | `legendary_传说框_500x800.png` |

提示词骨架：

```
Legendary tier trading card frame only, 5:8 vertical, thick gold-orange border #FFB34D,
subtle star dust glitter, inner window filled solid chroma key green #00FF00,
rounded corners ~50px at 500px width scale, no text, sci-fi military HUD style.
```

---

## 8. 系统 UI 资产

### 8.1 功能图标 `assets/ui/icons/` — **256×256**，绿底

**风格**：极简 **扁平符号**、粗笔画（≥6px@256）、少渐变；与游戏 HUD 冷蓝灰底 `#101a2b` 上对比度足够。

| 建议文件名 | 用途 |
|------------|------|
| `icon_shop_商店_256.png` | 商店 |
| `icon_quest_任务_256.png` | 任务 |
| `icon_leaderboard_排行榜_256.png` | 排行榜 |
| `icon_settings_设置_256.png` | 设置 |
| `icon_help_帮助_256.png` | 帮助 |
| `icon_close_关闭_256.png` | 关闭 |
| `icon_arrow_left_左箭头_256.png` | 左箭头 |
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

**通用 prompt 后缀**

```
, minimal flat game UI icon, bold strokes, centered, high contrast on dark HUD,
solid chroma key green #00FF00 background only, no text, 256x256 PNG.
```

### 8.2 星级 `assets/ui/stars/` — **128×128**

- **五角星**为主形，金 `#FFD700` 为主，可加浅黄高光；**禁止**星体使用 #00FF00。  
- 文件名：`star_{1..7}_星数中文_128.png`

### 8.3 相位仪属性 `assets/ui/instruments/` — **128×128**

- **象形符号**（加减号、闪电、盾、箭头等几何组合），粗线（≥4px@128），**无文字**。  
- 文件名：`{pi_id}_中文_128.png`（`pi_*` 与 `phase_instruments.gd` 一致，中文见下表简写）

| pi_id | 中文简写 |
|-------|----------|
| pi_atk | 伤害 |
| pi_def | 防御 |
| pi_hp | 生命 |
| pi_xp | 经验 |
| pi_drop | 掉落 |
| pi_energy_out | 能量出 |
| pi_energy_rec | 能量回 |
| pi_energy_cost | 能量减耗 |
| pi_deploy_range | 部署距 |
| pi_crit | 暴击率 |
| pi_crit_dmg | 暴伤 |
| pi_move_speed | 移速 |
| pi_attack_speed | 攻速 |
| pi_r_first_deploy | 初部署 |
| pi_r_kill_energy | 续能 |
| pi_r_law_boost | 法则共鸣 |
| pi_r_energy_fountain | 涌泉 |
| pi_r_dmg_reflect | 反伤 |
| pi_r_respawn | 重生 |
| pi_r_shield | 初盾 |
| pi_r_cascade | 连锁 |
| pi_r_overload | 过载 |
| pi_r_last_stand | 最后意志 |
| pi_r_energy_burst | 能量爆 |
| pi_r_scale | 越战越强 |
| pi_r_free_deploy | 零费部署 |

---

## 9. 负面提示词（全文通用，接每条英文 prompt 末尾）

```
, NO text, NO letters, NO watermark, NO logos, NO real-world national flags,
NO chroma green #00FF00 on subject or equipment, NO gradient green background,
NO gore, NO photoreal human faces, NO stock photo UI.
```

---

## 10. 交付目录速查

| 资产 | 目标路径 |
|------|-----------|
| 战场序列 | `assets/enemies/SpriteSheet/<id>/` |
| 卡面 | `assets/card_icons/` |
| 传说框 | `assets/cards/frames/` |
| UI 图标 | `assets/ui/icons/` |
| 势力 | `assets/ui/factions/` |
| 星级 | `assets/ui/stars/` |
| 相位仪 | `assets/ui/instruments/` |

---

## 11. 自检清单（导出前）

- [ ] 卡面/卡框宽高 **严格 5:8**（与 `50×80` 槽位一致）。  
- [ ] 卡面在 **28×28** 缩小预览仍可辨类型。  
- [ ] 背景纯 **#00FF00**，主体无同色。  
- [ ] 无文字、无水印。  
- [ ] 文件名含中文段是否已按你方规范可删。  

---

**文件结束。将本 Markdown 整份投喂另一 AI 即可执行。**
