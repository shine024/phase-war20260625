# 敌方单位卡图 Agent 生图提示词（100）

**版本：** v1.0 | 2026-05-20  
**对齐：** `docs/card_icon_manifest_100_zh.md`（100 敌人，`visual_id` 一行一提示词）  
**规格：** 与已成功落地的 #1–5 相同 — 半写实硬表面、**严格正侧视**、**朝左**、**#00FF00 绿幕** → 抠图后 512×512 透明 PNG。

## 使用方式

1. 在 Cursor Agent 对话中复制对应条目的 **English prompt**（含 Negative prompt 约束）。  
2. 生图输出保存后，用 `tools/deploy_agent_unit_icons_1_5.py` 的逻辑批量抠绿（或扩展脚本按 `visual_id` 部署）。  
3. 每条提示词的 **主体描述互不重复**；仅末尾技术约束（侧视/朝左/绿幕）统一。

## 统一技术约束（已写入每条 prompt 正文）

- 正侧视 `true profile side view`，正交投影  
- **朝左**（车头/炮口/正面在画面左侧）  
- 半写实军事硬表面，铆钉/磨损/分件  
- 纯色绿幕 `#00FF00`，无地面无场景  
- 512×512，无文字无水印  

---

### 1) vis_player_001（威克斯侦察车）

**区块：** A | **era：** 0（一战） | **兵种：** 猎犬  
**archetype_id：** `foe_platform_ww1_light` | **输出：** `assets/card_icons/units/vis_player_001.png`

**说明：** 一战轻型装甲侦察车，四轮。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 British Vickers-Wickes pattern armored scout car, riveted khaki steel hull, canvas roof over rear cabin, twin machine gun pintle, four spoked wheels with mud-splashed rubber, dented front radiator grille and round headlamp, oil stains and paint chips. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 2) vis_player_002（马克V型坦克）

**区块：** A | **era：** 0（一战） | **兵种：** 泰坦  
**archetype_id：** `foe_platform_ww1_medium` | **输出：** `assets/card_icons/units/vis_player_002.png`

**说明：** 菱形一战重型坦克。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 British Mark V male rhomboid heavy tank, continuous caterpillar tracks wrapping diamond hull, long naval gun barrel in side sponson pointing left, riveted olive plates, command cabin slot, heavy mud on lower track skirts. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 3) vis_player_003（150mm岸防火炮阵地）

**区块：** A | **era：** 0（一战） | **兵种：** 要塞  
**archetype_id：** `foe_platform_ww1_fort` | **输出：** `assets/card_icons/units/vis_player_003.png`

**说明：** 混凝土炮堡与岸防火炮。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 coastal fortress emplacement, 150mm naval gun on curved shield mount, concrete casemate with firing slit, stacked burlap sandbags, rusted traverse wheel and spent shell rack silhouette. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 4) vis_player_004（系留气球观测队）

**区块：** A | **era：** 0（一战） | **兵种：** 雷达  
**archetype_id：** `foe_platform_ww1_radar` | **输出：** `assets/card_icons/units/vis_player_004.png`

**说明：** 系留观测气球。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 tethered observation barrage balloon, fabric envelope with panel seams and rigging net, wicker gondola basket with map case, steel winch frame on truck chassis optional minimal base. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 5) vis_player_005（福特T型救护改装车）

**区块：** A | **era：** 0（一战） | **兵种：** 医疗  
**archetype_id：** `foe_platform_ww1_medic` | **输出：** `assets/card_icons/units/vis_player_005.png`

**说明：** T型车救护改装。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 Ford Model T ambulance conversion, white-over-khaki box body, large red cross on side panel, open cab, wooden spoke wheels, stretcher rack visible through rear door gap. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 6) vis_player_006（M8灰狗装甲车）

**区块：** A | **era：** 1（二战） | **兵种：** 侦察  
**archetype_id：** `foe_platform_ww2_light` | **输出：** `assets/card_icons/units/vis_player_006.png`

**说明：** 六轮装甲侦察。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 US M8 Greyhound six-wheeled armored car, sloped welded hull olive drab, open-topped turret with 37mm gun pointing left, antenna whip, canvas equipment bins, worn white star faded on glacis. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 7) vis_player_007（谢尔曼坦克）

**区块：** A | **era：** 1（二战） | **兵种：** 哨兵  
**archetype_id：** `foe_platform_ww2_medium` | **输出：** `assets/card_icons/units/vis_player_007.png`

**说明：** M4谢尔曼侧视。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 US M4 Sherman medium tank, vertical volute suspension bogies, three-piece welded hull, medium turret with 75mm gun left, applique armor patches, tool clamps on hull side. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 8) vis_player_008（虎式坦克）

**区块：** A | **era：** 1（二战） | **兵种：** 泰坦  
**archetype_id：** `foe_platform_ww2_heavy` | **输出：** `assets/card_icons/units/vis_player_008.png`

**说明：** 虎I重型坦克。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 German Tiger I heavy tank, interleaved road wheels, long 88mm L/56 barrel with muzzle brake left, zimmerit texture patches, commander's cupola, dark yellow-olive camo chips. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 9) vis_player_009（BA-64轻型突击车）

**区块：** A | **era：** 1（二战） | **兵种：** 突袭  
**archetype_id：** `foe_platform_ww2_raider` | **输出：** `assets/card_icons/units/vis_player_009.png`

**说明：** 苏制轻型装甲车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 Soviet BA-64 light armored car, compact angled armor, turret machine gun left, four wheels with bullet strikes on fenders, dark green with white tactical number stencil. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 10) vis_player_010（SCR-584雷达指挥车）

**区块：** A | **era：** 1（二战） | **兵种：** 雷达  
**archetype_id：** `foe_platform_ww2_radar` | **输出：** `assets/card_icons/units/vis_player_010.png`

**说明：** 雷达天线指挥车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 US SCR-584 microwave radar truck, GMC 6x6 cargo bed, parabolic dish antenna folded for travel profile, generator crate, olive drab with signal corps markings. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 11) vis_player_011（203毫米迫击炮）

**区块：** A | **era：** 1（二战） | **兵种：** 攻城  
**archetype_id：** `foe_platform_ww2_siege` | **输出：** `assets/card_icons/units/vis_player_011.png`

**说明：** 重型迫击炮阵地。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 203mm heavy mortar battery, enormous smoothbore tube on twin-leg base plate, elevating screw and spade, stacked ammo crates and ramrod crew steps implied by hardware only. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 12) vis_player_012（海岸混凝土炮堡）

**区块：** A | **era：** 1（二战） | **兵种：** 要塞  
**archetype_id：** `foe_platform_ww2_fortress` | **输出：** `assets/card_icons/units/vis_player_012.png`

**说明：** 永备混凝土碉堡。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 Atlantic Wall concrete casemate, embrasure with coastal gun barrel left, rebar stains, camouflage net drape, anti-landing obstacles cast into roof edge. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 13) vis_player_013（悍马侦察车）

**区块：** A | **era：** 2（冷战） | **兵种：** 猎犬  
**archetype_id：** `foe_platform_cold_light` | **输出：** `assets/card_icons/units/vis_player_013.png`

**说明：** 悍马武装侦察。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War era HMMWV armed scout, armored doors, roof ring mount with M2 machine gun left, antenna cluster, sand tan paint, IR driving light and jerry cans on tailgate. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 14) vis_player_014（T-72主战坦克）

**区块：** A | **era：** 2（冷战） | **兵种：** 泰坦  
**archetype_id：** `foe_platform_cold_medium` | **输出：** `assets/card_icons/units/vis_player_014.png`

**说明：** T-72侧视。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War Soviet T-72 MBT, low silhouette cast turret, autoloader bustle, rubber side skirts, 125mm smoothbore gun left, reactive armor blocks on cheeks, Russian green with mud splatter. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 15) vis_player_015（布雷德利步战车）

**区块：** A | **era：** 2（冷战） | **兵种：** 运输  
**archetype_id：** `foe_platform_cold_ifv` | **输出：** `assets/card_icons/units/vis_player_015.png`

**说明：** M2布雷德利IFV。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War US M2 Bradley IFV, aluminum hull angular, TOW launcher box on turret left, six road wheels, infantry firing ports along flank, MERDC woodland faded camo. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 16) vis_player_016（BRDM-2侦察车）

**区块：** A | **era：** 2（冷战） | **兵种：** 侦察  
**archetype_id：** `foe_platform_cold_scout` | **输出：** `assets/card_icons/units/vis_player_016.png`

**说明：** BRDM两栖侦察。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War BRDM-2 scout car, boat hull belly, four wheels with central tire inflation lines, turret KPVT gun left, periscope fairings, white recognition stripe on bow. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 17) vis_player_017（R-330电子干扰车）

**区块：** A | **era：** 2（冷战） | **兵种：** 雷达  
**archetype_id：** `foe_platform_cold_radar` | **输出：** `assets/card_icons/units/vis_player_017.png`

**说明：** 电子战卡车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War R-330Zh EW truck on ZIL chassis, tall mast telescoped, jammer dish arrays on sides, cable reels, matte green with lightning bolt stencil. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 18) vis_player_018（BMP步战车）

**区块：** A | **era：** 2（冷战） | **兵种：** 运输  
**archetype_id：** `foe_platform_cold_carrier` | **输出：** `assets/card_icons/units/vis_player_018.png`

**说明：** BMP-1步兵战车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War BMP-1 infantry fighting vehicle, low angled glacis, 73mm low-pressure gun and ATGM rail left, rear troop door outline, spaced armor texture. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 19) vis_player_019（L-ATV全地形侦察车）

**区块：** A | **era：** 3（现代） | **兵种：** 猎犬  
**archetype_id：** `foe_platform_modern_light` | **输出：** `assets/card_icons/units/vis_player_019.png`

**说明：** 联合轻型战术车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern US Oshkosh L-ATV MRAP scout, modular armor panels, CROWS remote weapon station pointing left, blast-resistant windows, digital tan-gray camo. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 20) vis_player_020（艾布拉姆斯坦克）

**区块：** A | **era：** 3（现代） | **兵种：** 哨兵  
**archetype_id：** `foe_platform_modern_medium` | **输出：** `assets/card_icons/units/vis_player_020.png`

**说明：** M1A2艾布拉姆斯。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern US M1A2 Abrams MBT, depleted uranium skirt tiles, large bustle rack, 120mm gun with thermal sleeve left, commander CITV, desert tan with unit chalk marks. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 21) vis_player_021（相控阵雷达车）

**区块：** A | **era：** 3（现代） | **兵种：** 雷达  
**archetype_id：** `foe_platform_modern_radar` | **输出：** `assets/card_icons/units/vis_player_021.png`

**说明：** 机动相控阵雷达。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern phased-array air-defense radar truck, folding AESA panel lattice on hydraulic mast, support outriggers stowed, FMTV cab, slate gray with IFF transponder blister. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 22) vis_player_022（帕拉丁自行火炮）

**区块：** A | **era：** 3（现代） | **兵种：** 攻城  
**archetype_id：** `foe_platform_modern_spg` | **输出：** `assets/card_icons/units/vis_player_022.png`

**说明：** M109帕拉丁。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern M109 Paladin self-propelled howitzer, closed turret with long 155mm barrel left, spade deployed at rear, automated fire control boxes on hull. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 23) vis_player_023（Fennek侦察车）

**区块：** A | **era：** 3（现代） | **兵种：** 隐匿  
**archetype_id：** `foe_platform_modern_stealth` | **输出：** `assets/card_icons/units/vis_player_023.png`

**说明：** 芬内克侦察。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern Dutch-German Fennek recon vehicle, low radar signature hull, surveillance mast folded, MG3 remote mount left, matte sand with IR suppressing paint. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 24) vis_player_024（豹2A7主战坦克）

**区块：** A | **era：** 3（现代） | **兵种：** 哨兵  
**archetype_id：** `foe_platform_modern_guard_heavy` | **输出：** `assets/card_icons/units/vis_player_024.png`

**说明：** 豹2A7。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern Leopard 2A7 MBT, wedge turret cheeks, 120mm L55 gun left, auxiliary power unit grilles, urban gray-green camo with rubber chain grousers. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 25) vis_player_025（RQ-45无人侦察车）

**区块：** A | **era：** 4（近未来） | **兵种：** 隐匿  
**archetype_id：** `foe_platform_future_light` | **输出：** `assets/card_icons/units/vis_player_025.png`

**说明：** 无人侦察平台。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future RQ-45 unmanned ground recon sled, flat carbon chassis, gimbal EO pod on articulated arm left, LIDAR puck, subtle enemy blue phase sensor glow on lens ring. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 26) vis_player_026（L-220悬浮突击车）

**区块：** A | **era：** 4（近未来） | **兵种：** 突袭  
**archetype_id：** `foe_platform_future_medium` | **输出：** `assets/card_icons/units/vis_player_026.png`

**说明：** 悬浮突击平台。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future L-220 hover assault skimmer, magneto-plasma lift skirts under angular hull, dual plasma cannons on chin turret left, heat discoloration on cowlings. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 27) vis_player_027（AEW-12感知阵列车）

**区块：** A | **era：** 4（近未来） | **兵种：** 雷达  
**archetype_id：** `foe_platform_future_radar` | **输出：** `assets/card_icons/units/vis_player_027.png`

**说明：** 感知阵列指挥车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future AEW-12 sensor array carrier, articulated phased-sensor wings stowed along hull, quantum dome radome, matte gunmetal with blue phase lattice seams. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 28) vis_player_028（HK-09重型机兵）

**区块：** A | **era：** 4（近未来） | **兵种：** 泰坦  
**archetype_id：** `foe_platform_future_heavy` | **输出：** `assets/card_icons/units/vis_player_028.png`

**说明：** 双足重型机兵。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future HK-09 heavy bipedal war-walker, thick leg actuators, shoulder missile pods, rotary cannon arm pointing left, battle-scarred armor plates with blue energy core slit. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 29) vis_player_029（全装型机动舱）

**区块：** A | **era：** 4（近未来） | **兵种：** 终极  
**archetype_id：** `foe_omega_platform` | **输出：** `assets/card_icons/units/vis_player_029.png`

**说明：** Ω级全装机动舱。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future omega-class mobile combat capsule, modular weapon spines, spherical phase reactor visible through armored viewport, golden-trim black hull, intimidating oversized silhouette. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 30) vis_player_030（兰开夏 FV603 装甲车）

**区块：** B | **era：** 0（一战） | **兵种：** 哨兵  
**archetype_id：** `foe_bulwark` | **输出：** `assets/card_icons/units/vis_player_030.png`

**说明：** 一战末装甲输送。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Interwar Lancashire FV603 pattern armored personnel carrier stylized WW1-era, riveted box hull, side firing loopholes, roof hatches, sandbag rack on glacis. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 31) vis_player_031（马克V型·改）

**区块：** B | **era：** 0（一战） | **兵种：** 泰坦  
**archetype_id：** `foe_titan_mk2` | **输出：** `assets/card_icons/units/vis_player_031.png`

**说明：** 强化菱形坦克。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Up-armored WW1 Mark V variant mk2, extra boilerplate on sponsons, twin searchlights, reinforced track links, additional trench crossing tail skid, heavier camouflage nets bundled. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 32) vis_player_032（M10狼獾歼击车）

**区块：** B | **era：** 1（二战） | **兵种：** 突袭  
**archetype_id：** `foe_storm_rider` | **输出：** `assets/card_icons/units/vis_player_032.png`

**说明：** 敞篷坦克歼击车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 US M10 Wolverine tank destroyer, open-top turret with 3-inch gun left, counterweight on turret rear, tall side fenders, white invasion star. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 33) vis_player_033（LST-1两栖指挥舰）

**区块：** B | **era：** 1（二战） | **兵种：** 运输  
**archetype_id：** `foe_heavy_carrier` | **输出：** `assets/card_icons/units/vis_player_033.png`

**说明：** 坦克登陆舰侧视。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 LST-1 tank landing ship side silhouette, bow ramp door seams, bridge superstructure aft, deck tie-down cleats, camouflage gray with wake paint stripe only on hull waterline hint minimal. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull, aircraft wings
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 34) vis_player_034（M88A1抢救牵引车）

**区块：** B | **era：** 2（冷战） | **兵种：** 医疗  
**archetype_id：** `foe_regen_frame` | **输出：** `assets/card_icons/units/vis_player_034.png`

**说明：** 装甲抢救车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War M88A1 recovery vehicle, crane boom stowed along hull, winch cable drum, dozer blade on glacis, lifting A-frame, olive drab with recovery triangle. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 35) vis_player_035（艾布拉姆斯坦克·改）

**区块：** B | **era：** 3（现代） | **兵种：** 哨兵  
**archetype_id：** `foe_abrams_mk2` | **输出：** `assets/card_icons/units/vis_player_035.png`

**说明：** 升级型艾布拉姆斯。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern Abrams mk2 upgrade package, trophy APS sensor clusters on turret cheeks, heavier side skirts, commander's low-profile cupola, urban kit storage boxes. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 36) vis_enemy_036（步兵班·MP18）

**区块：** C | **era：** 0（一战） | **兵种：** 步兵  
**archetype_id：** `enemy_ww1_infantry_basic` | **输出：** `assets/card_icons/units/vis_enemy_036.png`

**说明：** MP18冲锋枪班。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 German stormtrooper squad represented as single soldier profile, MP18 submachine gun with drum magazine, Stahlhelm, gas mask canister on belt, puttee leggings, mud-spattered greatcoat. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 37) vis_enemy_037（李-恩菲尔德步枪班）

**区块：** C | **era：** 0（一战） | **兵种：** 步兵  
**archetype_id：** `enemy_ww1_infantry_rifle` | **输出：** `assets/card_icons/units/vis_enemy_037.png`

**说明：** 英军步枪手。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 British rifleman profile, Lee-Enfield SMLE with bayonet, Brodie helmet, khaki wool tunic, bandolier across chest, trench mud on boots. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 38) vis_enemy_038（马克沁机枪阵地）

**区块：** C | **era：** 0（一战） | **兵种：** 阵地  
**archetype_id：** `enemy_ww1_mg_nest` | **输出：** `assets/card_icons/units/vis_enemy_038.png`

**说明：** 水冷重机枪阵地。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 Vickers-Maxim machine gun nest emplacement, water-jacketed heavy machine gun on tripod with brass feed block, sandbag parapet two layers high, ammo belt box. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 39) vis_enemy_039（81mm斯托克斯迫击炮组）

**区块：** C | **era：** 0（一战） | **兵种：** 阵地  
**archetype_id：** `enemy_ww1_mortar` | **输出：** `assets/card_icons/units/vis_enemy_039.png`

**说明：** 斯托克斯迫击炮。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 Stokes 81mm trench mortar on base plate, short smoothbore tube elevated, bipod legs, stacked mortar bombs in wicker cage, range dial plate on tube. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 40) vis_enemy_040（暴风突击队）

**区块：** C | **era：** 0（一战） | **兵种：** 精英步兵  
**archetype_id：** `elite_ww1_storm` | **输出：** `assets/card_icons/units/vis_enemy_040.png`

**说明：** 德军暴风兵。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 elite stormtrooper profile, reinforced brow plate on helmet, MP18 plus stick grenades on belt, flame-resistant cloak, aggressive forward-leaning stance, extra ammo pouches. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 41) vis_enemy_041（劳斯莱斯 Mk.I 装甲车）

**区块：** C | **era：** 0（一战） | **兵种：** 载具  
**archetype_id：** `elite_ww1_armored` | **输出：** `assets/card_icons/units/vis_enemy_041.png`

**说明：** 精英装甲车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 Rolls-Royce Armoured Car Mk I, turret with Vickers gun left, spoked wheels, polished rivet lines, royal navy gray-green with unit pennant stub only no readable text. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 42) vis_enemy_042（圣沙蒙坦克）

**区块：** C | **era：** 0（一战） | **兵种：** Boss  
**archetype_id：** `boss_ww1_av7` | **输出：** `assets/card_icons/units/vis_enemy_042.png`

**说明：** 超重型一战坦克。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 French Saint-Chamond heavy assault tank boss scale, long hull overhang front, multiple casemate guns, tall rear cabin, extreme rivet count, battle damage gashes, oversized presence filling frame. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 43) vis_enemy_043（步兵班·汤普森）

**区块：** C | **era：** 1（二战） | **兵种：** 步兵  
**archetype_id：** `enemy_ww2_infantry` | **输出：** `assets/card_icons/units/vis_enemy_043.png`

**说明：** 汤普森冲锋枪班。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 US infantry soldier profile, Thompson M1928A1 with drum, M1 helmet netted, suspenders, grenade pouches, oil on cheek of wooden stock. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 44) vis_enemy_044（步枪班·加兰德）

**区块：** C | **era：** 1（二战） | **兵种：** 步兵  
**archetype_id：** `enemy_ww2_rifleman` | **输出：** `assets/card_icons/units/vis_enemy_044.png`

**说明：** 加兰德步枪手。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 US rifleman profile, M1 Garand rifle at high port, canvas gaiters, ammo clips on belt, helmet chin strap, subdued olive uniform. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 45) vis_enemy_045（MG42机枪组）

**区块：** C | **era：** 1（二战） | **兵种：** 阵地  
**archetype_id：** `enemy_ww2_mg42` | **输出：** `assets/card_icons/units/vis_enemy_045.png`

**说明：** MG42机枪阵地。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 MG42 machine gun on Lafette tripod, perforated barrel shroud, belt drum feed, low sandbag wall, spare barrel case beside mount. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 46) vis_enemy_046（铁拳88mm反坦克组）

**区块：** C | **era：** 1（二战） | **兵种：** 阵地  
**archetype_id：** `enemy_ww2_panzerschreck` | **输出：** `assets/card_icons/units/vis_enemy_046.png`

**说明：** 铁拳反坦克组。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 Panzerschreck 88mm recoilless anti-tank team gear still life profile: launcher tube on shoulder rest stand, shield plate, rocket warhead crate, no visible face. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 47) vis_enemy_047（FG42伞兵班）

**区块：** C | **era：** 1（二战） | **兵种：** 精英步兵  
**archetype_id：** `elite_ww2_paratrooper` | **输出：** `assets/card_icons/units/vis_enemy_047.png`

**说明：** 德军伞兵。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 German Fallschirmjäger profile, FG42 rifle with bipod folded, jump smock, side-holster, helmet with chin pad, elite eagle insignia shape only no readable insignia text. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 48) vis_enemy_048（黑豹坦克）

**区块：** C | **era：** 1（二战） | **兵种：** 精英载具  
**archetype_id：** `elite_ww2_panther` | **输出：** `assets/card_icons/units/vis_enemy_048.png`

**说明：** 黑豹中型坦克。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 Panther Ausf G medium tank, sloped glacis, long 75mm KwK42 L/70 left, wide tracks, zimmerit bands, commander's periscope guard. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 49) vis_enemy_049（虎王坦克）

**区块：** C | **era：** 1（二战） | **兵种：** Boss  
**archetype_id：** `boss_ww2_kingtiger` | **输出：** `assets/card_icons/units/vis_enemy_049.png`

**说明：** 虎王重型坦克。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 King Tiger boss silhouette, massive Königstiger hull, long 88mm L/71, thick frontal armor slab, double road wheel interleave, imposing scale with chipped ambush camo. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 50) vis_enemy_050（AKM摩托化步兵班）

**区块：** C | **era：** 2（冷战） | **兵种：** 步兵  
**archetype_id：** `enemy_cold_ak` | **输出：** `assets/card_icons/units/vis_enemy_050.png`

**说明：** AKM步兵。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War motor rifle soldier profile, AKM rifle with slab magazine, load-bearing harness, SSH68 helmet, wool greatcoat, NBC cape rolled on back. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 51) vis_enemy_051（M60机枪步兵班）

**区块：** C | **era：** 2（冷战） | **兵种：** 步兵  
**archetype_id：** `enemy_cold_m60` | **输出：** `assets/card_icons/units/vis_enemy_051.png`

**说明：** M60通用机枪手。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War US machine gunner profile, M60 GPMG with bipod folded, ammo belt over shoulder, PASGT helmet, flak vest, woodland ERDL pattern. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 52) vis_enemy_052（BTR-60PB装甲输送车）

**区块：** C | **era：** 2（冷战） | **兵种：** 载具  
**archetype_id：** `enemy_cold_btr` | **输出：** `assets/card_icons/units/vis_enemy_052.png`

**说明：** BTR-60八轮。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War BTR-60PB eight-wheeled APC, boat hull, turret KPVT left, troop vision blocks row, white Russian naval stripe optional. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 53) vis_enemy_053（M113A1装甲输送车）

**区块：** C | **era：** 2（冷战） | **兵种：** 载具  
**archetype_id：** `enemy_cold_m113` | **输出：** `assets/card_icons/units/vis_enemy_053.png`

**说明：** M113履带输送。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War M113A1 APC, aluminum angled hull, cupola M2 mount left, trim vane on bow, rubber track, MERDC camo scuffs. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 54) vis_enemy_054（Spetsnaz侦察小组）

**区块：** C | **era：** 2（冷战） | **兵种：** 精英步兵  
**archetype_id：** `elite_cold_spetsnaz` | **输出：** `assets/card_icons/units/vis_enemy_054.png`

**说明：** 苏军特种部队。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War Spetsnaz recon operator profile, AS Val suppressed rifle, night vision goggle mount on helmet, suppressor wrap cloth, black coveralls with subdued patches no text. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 55) vis_enemy_055（T-72A主战坦克）

**区块：** C | **era：** 2（冷战） | **兵种：** 精英载具  
**archetype_id：** `elite_cold_t72` | **输出：** `assets/card_icons/units/vis_enemy_055.png`

**说明：** T-72A精英涂装。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War T-72A elite variant, IR searchlight box, smoke grenade launchers on turret, extended fuel drums on rear fender, aggressive angular turret cheeks. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 56) vis_enemy_056（米格-29）

**区块：** C | **era：** 2（冷战） | **兵种：** Boss  
**archetype_id：** `boss_cold_mig` | **输出：** `assets/card_icons/units/vis_enemy_056.png`

**说明：** 米格-29战斗机侧视。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War MiG-29 Fulcrum fighter aircraft strict side profile, swept wings, twin vertical tails, intake under fuselage, boss scale fills height, bare metal and green camo, no runway. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: front view, top-down, three-quarter, facing right, runway scenery, clouds background, text, watermark, logo, blurry, deformed rotor
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 57) vis_enemy_057（M27海军陆战队班）

**区块：** C | **era：** 3（现代） | **兵种：** 步兵  
**archetype_id：** `enemy_modern_marine` | **输出：** `assets/card_icons/units/vis_enemy_057.png`

**说明：** M27步枪海军陆战队。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern USMC rifleman profile, M27 IAR rifle with optic, ILBE pack straps, MARPAT desert, knee pads, bayonet frog empty. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 58) vis_enemy_058（丰田Hilux重机枪车）

**区块：** C | **era：** 3（现代） | **兵种：** 步兵  
**archetype_id：** `enemy_modern_technical` | **输出：** `assets/card_icons/units/vis_enemy_058.png`

**说明：** 技术皮卡机枪车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern Toyota Hilux technical truck profile, DShK heavy machine gun on bed mount pointing left, welded armor plates on doors, dust-coated white paint, spare tire on tailgate. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 59) vis_enemy_059（M1126斯特赖克ICV）

**区块：** C | **era：** 3（现代） | **兵种：** 载具  
**archetype_id：** `enemy_modern_stryker` | **输出：** `assets/card_icons/units/vis_enemy_059.png`

**说明：** 斯特赖克八轮。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern Stryker ICV M1126, eight-wheel configuration, remote CROWS on roof left, slat armor cage panels, digital camo, antenna farm. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 60) vis_enemy_060（M270 MLRS火箭炮）

**区块：** C | **era：** 3（现代） | **兵种：** 阵地  
**archetype_id：** `enemy_modern_mlrs` | **输出：** `assets/card_icons/units/vis_enemy_060.png`

**说明：** MLRS多管火箭。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern M270 MLRS launcher vehicle, two six-pack rocket pods elevated slightly, armored cab forward, hydraulic outriggers down, desert tan. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 61) vis_enemy_061（CAG三角洲小队）

**区块：** C | **era：** 3（现代） | **兵种：** 精英步兵  
**archetype_id：** `elite_modern_delta` | **输出：** `assets/card_icons/units/vis_enemy_061.png`

**说明：** 三角洲特战。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern CAG operator profile, suppressed HK416, NVG shroud up, plate carrier with pouches no readable patches, fast helmet and comms wires. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 62) vis_enemy_062（M1A2 SEP v3）

**区块：** C | **era：** 3（现代） | **兵种：** 精英载具  
**archetype_id：** `elite_modern_abrams` | **输出：** `assets/card_icons/units/vis_enemy_062.png`

**说明：** SEP v3艾布拉姆斯。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern M1A2 SEP v3 with TUSK kit, depleted uranium skirts, CROWS-LP, commander's independent thermal viewer, urban gray. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 63) vis_enemy_063（AH-64D阿帕奇）

**区块：** C | **era：** 3（现代） | **兵种：** 精英航空  
**archetype_id：** `elite_modern_apache` | **输出：** `assets/card_icons/units/vis_enemy_063.png`

**说明：** 阿帕奇武装直升机。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern AH-64D Apache helicopter side profile, tandem cockpit, nose sensor ball, stub wings with rocket pods, tail rotor guard, gun turret left. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: front view, top-down, three-quarter, facing right, runway scenery, clouds background, text, watermark, logo, blurry, deformed rotor
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 64) vis_enemy_064（联合星区指挥所）

**区块：** C | **era：** 3（现代） | **兵种：** Boss  
**archetype_id：** `boss_modern_command` | **输出：** `assets/card_icons/units/vis_enemy_064.png`

**说明：** 机动指挥所。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern joint sector command post boss vehicle, expanded TOC truck with satellite dishes, ECM domes, generator trailers, camouflage net draped massive silhouette. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 65) vis_enemy_065（蜂群微型无人机）

**区块：** C | **era：** 4（近未来） | **兵种：** 步兵  
**archetype_id：** `enemy_future_drone` | **输出：** `assets/card_icons/units/vis_enemy_065.png`

**说明：** 蜂群无人机。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future micro drone swarm carrier rack on tripod mast, dozens of insect-scale quadrotors clipped in hex cells, blue phase glow on charging ports, no human figures. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 66) vis_enemy_066（外骨骼突击兵）

**区块：** C | **era：** 4（近未来） | **兵种：** 步兵  
**archetype_id：** `enemy_future_cyborg` | **输出：** `assets/card_icons/units/vis_enemy_066.png`

**说明：** 动力外骨骼步兵。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future powered exoskeleton assault soldier profile, hydraulic leg frames, sealed helmet visor, coil rifle left, blue enemy phase nodes on joints. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 67) vis_enemy_067（XM-3机步突击车）

**区块：** C | **era：** 4（近未来） | **兵种：** 载具  
**archetype_id：** `enemy_future_mech` | **输出：** `assets/card_icons/units/vis_enemy_067.png`

**说明：** 六轮机步突击车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future XM-3 mechanized assault vehicle six-wheel, angular ceramic armor, railgun turret left, drone launch tubes on roof. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 68) vis_enemy_068（L-220悬浮主战平台）

**区块：** C | **era：** 4（近未来） | **兵种：** 载具  
**archetype_id：** `enemy_future_hovertank` | **输出：** `assets/card_icons/units/vis_enemy_068.png`

**说明：** 悬浮主战平台另一构型。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future L-220 hover main battle platform alternate configuration, wider skirt, dual phase thrusters, heavy chin railgun, heat haze on cowling unlike assault car variant. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 69) vis_enemy_069（光学迷彩渗透组）

**区块：** C | **era：** 4（近未来） | **兵种：** 精英步兵  
**archetype_id：** `elite_future_spectre` | **输出：** `assets/card_icons/units/vis_enemy_069.png`

**说明：** 光学迷彩特战。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future spectre infiltrator profile, active camouflage cloak with pixel shimmer, suppressed bullpup rifle, faint blue outline glitch on edges. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 70) vis_enemy_070（GK-1重型步行机）

**区块：** C | **era：** 4（近未来） | **兵种：** 精英载具  
**archetype_id：** `elite_future_colossus` | **输出：** `assets/card_icons/units/vis_enemy_070.png`

**说明：** 重型双足机甲。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future GK-1 heavy walker elite, thicker legs than HK-09, missile racks on shoulders, blue reactor core, battle damage exposing wiring. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 71) vis_enemy_071（风暴核心指挥塔）

**区块：** C | **era：** 4（近未来） | **兵种：** Boss  
**archetype_id：** `boss_future_nexus` | **输出：** `assets/card_icons/units/vis_enemy_071.png`

**说明：** 近未来Boss指挥塔。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future Storm Nexus command spire boss structure, vertical phased array tower on armored crawler base, lightning-blue phase arcs along spine, dominating height. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 72) vis_pool_001（李-恩菲尔德志愿兵排）

**区块：** D | **era：** 0（一战） | **兵种：** 步兵  
**archetype_id：** `foe_pool_001` | **输出：** `assets/card_icons/units/vis_pool_001.png`

**说明：** 志愿步枪排。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 British volunteer rifleman profile alternate kit, SMLE with cloth wrap on stock, scarf, enamel mug on belt, lighter mud tone than standard rifleman. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 73) vis_pool_002（劳斯莱斯 Mk.II 装甲车）

**区块：** D | **era：** 0（一战） | **兵种：** 载具  
**archetype_id：** `foe_pool_002` | **输出：** `assets/card_icons/units/vis_pool_002.png`

**说明：** Mk.II装甲车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 Rolls-Royce Armoured Car Mk II evolution, revised turret bustle, additional headlight guard, heavier sand shields on wheel arches, darker olive drab. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 74) vis_pool_003（维克斯.303机枪阵地）

**区块：** D | **era：** 0（一战） | **兵种：** 阵地  
**archetype_id：** `foe_pool_003` | **输出：** `assets/card_icons/units/vis_pool_003.png`

**说明：** 维克斯机枪。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 Vickers .303 water-cooled gun on high tripod, ammunition cloth belt feed, sandbagged firing step, condenser can hose loop. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 75) vis_pool_004（福特T型战地救护车）

**区块：** D | **era：** 0（一战） | **兵种：** 支援  
**archetype_id：** `foe_pool_004` | **输出：** `assets/card_icons/units/vis_pool_004.png`

**说明：** 战地救护T型车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 field ambulance Ford T variant with stretcher rack on running boards, additional canvas awning poles stowed, dual red cross panels, lantern on fender. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 76) vis_pool_005（MP18突击队）

**区块：** D | **era：** 0（一战） | **兵种：** 步兵  
**archetype_id：** `foe_pool_005` | **输出：** `assets/card_icons/units/vis_pool_005.png`

**说明：** 突击队MP18。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW1 assault detachment soldier profile, MP18 with snail drum, trench club on belt, blackened helmet, stick grenade bandolier. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 77) vis_pool_006（M1加兰德伞兵班）

**区块：** D | **era：** 1（二战） | **兵种：** 步兵  
**archetype_id：** `foe_pool_006` | **输出：** `assets/card_icons/units/vis_pool_006.png`

**说明：** 加兰德伞兵。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 US paratrooper profile, M1 Garand with folding stock variant, M1942 jump uniform, leg bag straps, Corcoran boots. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 78) vis_pool_007（黄蜂Hummel自行火炮）

**区块：** D | **era：** 1（二战） | **兵种：** 载具  
**archetype_id：** `foe_pool_007` | **输出：** `assets/card_icons/units/vis_pool_007.png`

**说明：** 胡蜂自行火炮。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 Hummel 150mm self-propelled gun on Panzer IV chassis, open fighting compartment, long howitzer left, spare track links on hull. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 79) vis_pool_008（PaK 40反坦克炮组）

**区块：** D | **era：** 1（二战） | **兵种：** 阵地  
**archetype_id：** `foe_pool_008` | **输出：** `assets/card_icons/units/vis_pool_008.png`

**说明：** PaK40反坦克炮。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 PaK 40 75mm anti-tank gun on cruciform mount, splinter shield, wheels raised for firing, stacked AP rounds in crates. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 80) vis_pool_009（GMC 2.5t补给卡车）

**区块：** D | **era：** 1（二战） | **兵种：** 支援  
**archetype_id：** `foe_pool_009` | **输出：** `assets/card_icons/units/vis_pool_009.png`

**说明：** 补给卡车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 GMC CCKW 2.5 ton cargo truck profile, canvas canopy over bed, fuel drums strapped, winch bumper, olive drab star hood. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 81) vis_pool_010（毛瑟Kar98k狙击组）

**区块：** D | **era：** 1（二战） | **兵种：** 步兵  
**archetype_id：** `foe_pool_010` | **输出：** `assets/card_icons/units/vis_pool_010.png`

**说明：** Kar98k狙击。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, WW2 German sniper profile, Kar98k with ZF39 scope, ghillie strips on shoulders, fingerless gloves, bolt handle polished. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 82) vis_pool_011（BMD-1空降战车）

**区块：** D | **era：** 2（冷战） | **兵种：** 步兵  
**archetype_id：** `foe_pool_011` | **输出：** `assets/card_icons/units/vis_pool_011.png`

**说明：** BMD空降战车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War BMD-1 airborne IFV, very low hull, 73mm gun left, hydropneumatic suspension pods, paratrooper door outline on flank. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 83) vis_pool_012（BMP-1步兵战车）

**区块：** D | **era：** 2（冷战） | **兵种：** 载具  
**archetype_id：** `foe_pool_012` | **输出：** `assets/card_icons/units/vis_pool_012.png`

**说明：** BMP-1池化。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War BMP-1 alternate camo, rubber side skirts torn, AT-3 Sagger rail empty, infantry periscope row, fuel barrel on rear. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 84) vis_pool_013（9K111法特导弹组）

**区块：** D | **era：** 2（冷战） | **兵种：** 阵地  
**archetype_id：** `foe_pool_013` | **输出：** `assets/card_icons/units/vis_pool_013.png`

**说明：** 法特反坦克导弹。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War 9K111 Fagot ATGM team equipment profile: launcher tube on tripod, thermal sight box, missile canister upright, no soldier face. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 85) vis_pool_014（P-18雷达警戒车）

**区块：** D | **era：** 2（冷战） | **兵种：** 支援  
**archetype_id：** `foe_pool_014` | **输出：** `assets/card_icons/units/vis_pool_014.png`

**说明：** P-18雷达车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War P-18 Spoon Rest radar on Ural truck, folding parabolic mesh antenna, cabin map light glow implied off, green camouflage nets folded on roof. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 86) vis_pool_015（BREM-1装甲抢修车）

**区块：** D | **era：** 2（冷战） | **兵种：** 支援  
**archetype_id：** `foe_pool_015` | **输出：** `assets/card_icons/units/vis_pool_015.png`

**说明：** BREM抢修车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Cold War BREM-1 armored recovery on T-72 hull, crane jib, welding cables, spare track sections on deck. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 87) vis_pool_016（M4卡宾特遣班）

**区块：** D | **era：** 3（现代） | **兵种：** 步兵  
**archetype_id：** `foe_pool_016` | **输出：** `assets/card_icons/units/vis_pool_016.png`

**说明：** M4卡宾特遣。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern special forces operator profile, M4 carbine with PEQ and holographic sight, plate carrier slick, IR flag patch shape only. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 88) vis_pool_017（爱国者PAC-3发射车）

**区块：** D | **era：** 3（现代） | **兵种：** 载具  
**archetype_id：** `foe_pool_017` | **输出：** `assets/card_icons/units/vis_pool_017.png`

**说明：** 爱国者发射车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern Patriot PAC-3 launcher erector on semi-trailer, four canister cells angled, radar cable drum, desert tan with dust. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 89) vis_pool_018（HIMARS火箭炮组）

**区块：** D | **era：** 3（现代） | **兵种：** 阵地  
**archetype_id：** `foe_pool_018` | **输出：** `assets/card_icons/units/vis_pool_018.png`

**说明：** HIMARS。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern HIMARS truck launcher, single six-pack pod, FMTV cab, hydraulic stabilizers, chalk serial blocks illegible. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 90) vis_pool_019（RQ-7影子无人机班）

**区块：** D | **era：** 3（现代） | **兵种：** 支援  
**archetype_id：** `foe_pool_019` | **输出：** `assets/card_icons/units/vis_pool_019.png`

**说明：** 影子无人机。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern RQ-7 Shadow UAV on rail launcher trailer, high aspect ratio wing, pusher propeller, ground control antenna mast folded. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 91) vis_pool_020（EA-18G电子战小组）

**区块：** D | **era：** 3（现代） | **兵种：** 支援  
**archetype_id：** `foe_pool_020` | **输出：** `assets/card_icons/units/vis_pool_020.png`

**说明：** 咆哮者电子战机。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Modern EA-18G Growler aircraft side profile on deck trolley silhouette simplified, ALQ wing pods, jamming pods under wings, no carrier background. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: front view, top-down, three-quarter, facing right, runway scenery, clouds background, text, watermark, logo, blurry, deformed rotor
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 92) vis_pool_021（神经接口突击兵）

**区块：** D | **era：** 4（近未来） | **兵种：** 步兵  
**archetype_id：** `foe_pool_021` | **输出：** `assets/card_icons/units/vis_pool_021.png`

**说明：** 神经接口步兵。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future neural-interface assault trooper profile, skull port cable, reflex booster braces on calves, bullpup coil carbine left. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 93) vis_pool_022（HK-07量产机兵）

**区块：** D | **era：** 4（近未来） | **兵种：** 载具  
**archetype_id：** `foe_pool_022` | **输出：** `assets/card_icons/units/vis_pool_022.png`

**说明：** HK-07机兵。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future HK-07 mass-production bipedal mech soldier chassis, lighter than HK-09, stamped serial plates blank, production line weld marks. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 94) vis_pool_023（HEL-30激光炮阵列）

**区块：** D | **era：** 4（近未来） | **兵种：** 阵地  
**archetype_id：** `foe_pool_023` | **输出：** `assets/card_icons/units/vis_pool_023.png`

**说明：** 激光防空阵列。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future HEL-30 laser defense array on trailer, gimbal turret with sapphire lens barrel, capacitor boxes, warning hazard stripes no readable text. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 95) vis_pool_024（N-Repair纳米工程车）

**区块：** D | **era：** 4（近未来） | **兵种：** 支援  
**archetype_id：** `foe_pool_024` | **输出：** `assets/card_icons/units/vis_pool_024.png`

**说明：** 纳米工程车。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future N-Repair nano-fabrication repair truck, articulated printer arm, material hopper silo, blue phase feed lines along hull. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 96) vis_pool_025（X-9猎杀者渗透组）

**区块：** D | **era：** 4（近未来） | **兵种：** 步兵  
**archetype_id：** `foe_pool_025` | **输出：** `assets/card_icons/units/vis_pool_025.png`

**说明：** X-9渗透者。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future X-9 hunter infiltrator profile, monoblade carbine, cloak with adaptive pixels, visor slits glowing dim blue. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 97) vis_pool_026（毛瑟C96征召兵排）

**区块：** D | **era：** 4（近未来） | **兵种：** 步兵  
**archetype_id：** `foe_pool_026` | **输出：** `assets/card_icons/units/vis_pool_026.png`

**说明：** C96征召兵（近未来混搭）。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future conscript soldier profile anachronistic Mauser C96 holster shape as ceremonial sidearm plus modern phase armor vest, satirical hybrid kit, weary stance. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, facing right, group photo, gradient background, battlefield scenery, ground shadow, text, watermark, logo, blurry, extra limbs, deformed rifle
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 98) vis_pool_027（Sd.Kfz.251/1半履带车）

**区块：** D | **era：** 4（近未来） | **兵种：** 载具  
**archetype_id：** `foe_pool_027` | **输出：** `assets/card_icons/units/vis_pool_027.png`

**说明：** 251半履带（近未来改装）。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future retro-fitted Sd.Kfz 251 half-track with phase-coated armor plates over classic hull, MG42 shield left, hybrid diesel-electric exhaust shroud. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 99) vis_pool_028（SS-C-1岸防导弹组）

**区块：** D | **era：** 4（近未来） | **兵种：** 阵地  
**archetype_id：** `foe_pool_028` | **输出：** `assets/card_icons/units/vis_pool_028.png`

**说明：** 岸防导弹。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future SS-C-1 coastal missile launcher truck, twin vertical launch tubes, acquisition radar dish folded, naval gray with blue phase trim. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---

### 100) vis_pool_029（PS-9相位中继站）

**区块：** D | **era：** 4（近未来） | **兵种：** 支援  
**archetype_id：** `foe_pool_029` | **输出：** `assets/card_icons/units/vis_pool_029.png`

**说明：** 相位中继站。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。

#### English prompt（Cursor Agent / 绿幕 #00FF00）

```text
Game enemy unit card icon art, Near-future PS-9 phase relay station on tracked carrier, tall resonator coil, capacitor ring, blue energy arc between twin masts, support guy wires. Strict true profile side view, orthographic projection, entire unit facing LEFT (nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. No text, no watermark, no logo.

Negative prompt: three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull
```

#### 负面提示词（中文备忘）

三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。

---
