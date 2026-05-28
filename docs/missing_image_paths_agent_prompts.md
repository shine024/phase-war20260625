# 缺失图片 Agent 生图提示词（对齐 missing_image_paths.txt）

**版本：** 2026-05-22
**对齐：** `docs/missing_image_paths.txt`（当前仍缺项）
**主文档（势力 7 + 星 1–7 + 属性 26）：** `docs/prompts/ui_icon_prompts_74.md`

## 使用方式

1. 势力 Logo：用 §一 或下文 **neutral**；**512×512** 生成后缩放为 `*_128.png`、`*_32.png`。
2. 星级：用 `ui_icon_prompts_74.md` §二 或下文 **star_8**；保存为 `star_N.png`（非仅 128）。
3. 相位仪**型号**（`pi_generic_*` / `pi_aegis_*` 等）：用本文 §三；512 生成，文件名与路径一致。
4. 透明底：UI 图标可用深灰蓝底直接 PNG，或 `#00FF00` 绿幕抠图（见 `docs/ART_EXPORT_CHECKLIST_GREENSCREEN.md` §七–九）。

## 统一负面提示词

```text
Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items
```

共 **60** 条缺失项。

---

## 一、势力 Logo（16 文件 · 8 势力 × 2 尺寸）

> 7 势力英文 prompt 在 `ui_icon_prompts_74.md` §一；此处仅补 **neutral** 与路径对照。

### neutral_128.png（中立势力Logo128）

**输出：** `res://assets/ui/factions/neutral_128.png`

**说明：** 中立势力；512 生成后导出 128 与 32 两版

#### English prompt

```text

flat 2D faction logo icon, a balanced neutral compass rose combined with three interlocking hollow circles representing no single faction allegiance, soft silver-white and muted grey-blue palette, faint hyperspace void backdrop with dim flowing light streaks, symmetrical emblem for generic unaligned phase operators, flat clean vector style, centered on dark background, game UI faction icon, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### neutral_32.png（中立势力Logo32）

**输出：** `res://assets/ui/factions/neutral_32.png`

**说明：** 中立势力；512 生成后导出 128 与 32 两版

#### English prompt

```text

flat 2D faction logo icon, a balanced neutral compass rose combined with three interlocking hollow circles representing no single faction allegiance, soft silver-white and muted grey-blue palette, faint hyperspace void backdrop with dim flowing light streaks, symmetrical emblem for generic unaligned phase operators, flat clean vector style, centered on dark background, game UI faction icon, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### iron_wall_corp_128.png（钢壁防务公司Logo128）

**输出：** `res://assets/ui/factions/iron_wall_corp_128.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_iron_wall_corp（铁壁公司）**；512 生成后缩放为 128×128

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_iron_wall_corp（铁壁公司）** 一节。

### iron_wall_corp_32.png（钢壁防务公司Logo32）

**输出：** `res://assets/ui/factions/iron_wall_corp_32.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_iron_wall_corp（铁壁公司）**；512 生成后缩放为 32×32

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_iron_wall_corp（铁壁公司）** 一节。

### nova_arms_128.png（新星兵工制造Logo128）

**输出：** `res://assets/ui/factions/nova_arms_128.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_nova_arms（诺瓦军武）**；512 生成后缩放为 128×128

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_nova_arms（诺瓦军武）** 一节。

### nova_arms_32.png（新星兵工制造Logo32）

**输出：** `res://assets/ui/factions/nova_arms_32.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_nova_arms（诺瓦军武）**；512 生成后缩放为 32×32

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_nova_arms（诺瓦军武）** 一节。

### aether_dynamics_128.png（以太动力重工Logo128）

**输出：** `res://assets/ui/factions/aether_dynamics_128.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_aether_dynamics（以太动力）**；512 生成后缩放为 128×128

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_aether_dynamics（以太动力）** 一节。

### aether_dynamics_32.png（以太动力重工Logo32）

**输出：** `res://assets/ui/factions/aether_dynamics_32.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_aether_dynamics（以太动力）**；512 生成后缩放为 32×32

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_aether_dynamics（以太动力）** 一节。

### quantum_logistics_128.png（量子后勤集团Logo128）

**输出：** `res://assets/ui/factions/quantum_logistics_128.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_quantum_logistics（量子物流）**；512 生成后缩放为 128×128

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_quantum_logistics（量子物流）** 一节。

### quantum_logistics_32.png（量子后勤集团Logo32）

**输出：** `res://assets/ui/factions/quantum_logistics_32.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_quantum_logistics（量子物流）**；512 生成后缩放为 32×32

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_quantum_logistics（量子物流）** 一节。

### helix_recon_128.png（螺旋侦察系统Logo128）

**输出：** `res://assets/ui/factions/helix_recon_128.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_helix_recon（螺旋侦察）**；512 生成后缩放为 128×128

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_helix_recon（螺旋侦察）** 一节。

### helix_recon_32.png（螺旋侦察系统Logo32）

**输出：** `res://assets/ui/factions/helix_recon_32.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_helix_recon（螺旋侦察）**；512 生成后缩放为 32×32

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_helix_recon（螺旋侦察）** 一节。

### void_research_128.png（虚空相位研究所Logo128）

**输出：** `res://assets/ui/factions/void_research_128.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_void_research（虚空研究所）**；512 生成后缩放为 128×128

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_void_research（虚空研究所）** 一节。

### void_research_32.png（虚空相位研究所Logo32）

**输出：** `res://assets/ui/factions/void_research_32.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_void_research（虚空研究所）**；512 生成后缩放为 32×32

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_void_research（虚空研究所）** 一节。

### frontier_union_128.png（边境联合公司Logo128）

**输出：** `res://assets/ui/factions/frontier_union_128.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_frontier_union（边境联盟）**；512 生成后缩放为 128×128

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_frontier_union（边境联盟）** 一节。

### frontier_union_32.png（边境联合公司Logo32）

**输出：** `res://assets/ui/factions/frontier_union_32.png`

**说明：** 完整英文 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **faction_frontier_union（边境联盟）**；512 生成后缩放为 32×32

#### 引用
`docs/prompts/ui_icon_prompts_74.md` 中 **faction_frontier_union（边境联盟）** 一节。


---

## 二、星级图标（8）

### star_1.png（1星）

**输出：** `res://assets/ui/stars/star_1.png`

**说明：** 见 `docs/prompts/ui_icon_prompts_74.md` → **star_1（1星·铜——相位感知初现）**

#### 引用
`docs/prompts/ui_icon_prompts_74.md` → **star_1（1星·铜——相位感知初现）**。

### star_2.png（2星）

**输出：** `res://assets/ui/stars/star_2.png`

**说明：** 见 `docs/prompts/ui_icon_prompts_74.md` → **star_2（2星·铜——相位感知强化）**

#### 引用
`docs/prompts/ui_icon_prompts_74.md` → **star_2（2星·铜——相位感知强化）**。

### star_3.png（3星）

**输出：** `res://assets/ui/stars/star_3.png`

**说明：** 见 `docs/prompts/ui_icon_prompts_74.md` → **star_3（3星·银——相位感知成熟）**

#### 引用
`docs/prompts/ui_icon_prompts_74.md` → **star_3（3星·银——相位感知成熟）**。

### star_4.png（4星）

**输出：** `res://assets/ui/stars/star_4.png`

**说明：** 见 `docs/prompts/ui_icon_prompts_74.md` → **star_4（4星·金——意志具象化）**

#### 引用
`docs/prompts/ui_icon_prompts_74.md` → **star_4（4星·金——意志具象化）**。

### star_5.png（5星）

**输出：** `res://assets/ui/stars/star_5.png`

**说明：** 见 `docs/prompts/ui_icon_prompts_74.md` → **star_5（5星·金——意志共振）**

#### 引用
`docs/prompts/ui_icon_prompts_74.md` → **star_5（5星·金——意志共振）**。

### star_6.png（6星）

**输出：** `res://assets/ui/stars/star_6.png`

**说明：** 见 `docs/prompts/ui_icon_prompts_74.md` → **star_6（6星·白金——现实改写者）**

#### 引用
`docs/prompts/ui_icon_prompts_74.md` → **star_6（6星·白金——现实改写者）**。

### star_7.png（7星）

**输出：** `res://assets/ui/stars/star_7.png`

**说明：** 见 `docs/prompts/ui_icon_prompts_74.md` → **star_7（7星·钻石——超空间主宰）**

#### 引用
`docs/prompts/ui_icon_prompts_74.md` → **star_7（7星·钻石——超空间主宰）**。

### star_8.png（8星）

**输出：** `res://assets/ui/stars/star_8.png`

**说明：** 8 星扩展；7 星样式见 ui_icon_prompts §star_7

#### English prompt

```text

flat 2D eight-star rating icon, eight classic five-pointed stars in a gentle arc or double-row layout, brilliant platinum-silver fill with subtle prismatic edge highlights suggesting beyond-seven-star extension tier, faint hyperspace light band behind the row, centered on dark grey-blue background, game UI rarity rating icon, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品


---

## 三、相位仪型号图标（36）

### pi_aegis_01.png（神盾-前哨）

**输出：** `res://assets/ui/instruments/pi_aegis_01.png`

**型号 ID：** `pi_aegis_01` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dial on small shield outpost mount, aether dynamics silver-blue, sentry turret silhouette on bezel, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_aegis_02.png（神盾-方阵）

**输出：** `res://assets/ui/instruments/pi_aegis_02.png`

**型号 ID：** `pi_aegis_02` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, square phalanx shield array framing dial, formation grid lines, defensive corporation emblem hint, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_aegis_03.png（神盾-穹顶）

**输出：** `res://assets/ui/instruments/pi_aegis_03.png`

**型号 ID：** `pi_aegis_03` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, domed shield canopy over dial, layered energy panels, fortress dome silhouette, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_aegis_04.png（神盾-壁垒核）

**输出：** `res://assets/ui/instruments/pi_aegis_04.png`

**型号 ID：** `pi_aegis_04` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, massive citadel core shield with radiant barrier nodes, ultimate aether dynamics fortress instrument, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_atlas_01.png（擎天-工蜂）

**输出：** `res://assets/ui/instruments/pi_atlas_01.png`

**型号 ID：** `pi_atlas_01` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, quantum logistics cargo drone silhouette, worker bee logistics glyph, teal supply lines, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_atlas_02.png（擎天-梁柱）

**输出：** `res://assets/ui/instruments/pi_atlas_02.png`

**型号 ID：** `pi_atlas_02` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, structural support beam frame, bridge pillar icons, logistics backbone dial, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_atlas_03.png（擎天-桥核）

**输出：** `res://assets/ui/instruments/pi_atlas_03.png`

**型号 ID：** `pi_atlas_03` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, bridge core hub with radiating supply routes, heavy teal energy trunk lines, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_eon_01.png（永纪-秒针）

**输出：** `res://assets/ui/instruments/pi_eon_01.png`

**型号 ID：** `pi_eon_01` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, frontier union gold clock hand second needle, minimal time dial ticks, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_eon_02.png（永纪-时阶）

**输出：** `res://assets/ui/instruments/pi_eon_02.png`

**型号 ID：** `pi_eon_02` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, layered time-step rings, olive and gold chronometer stages, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_eon_03.png（永纪-终式）

**输出：** `res://assets/ui/instruments/pi_eon_03.png`

**型号 ID：** `pi_eon_03` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, ultimate chronology crown, multi-hand temporal dial, frontier union flagship time instrument, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_01.png（巡航I型）

**输出：** `res://assets/ui/instruments/pi_generic_01.png`

**型号 ID：** `pi_generic_01` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, compact entry phase instrument dial, bronze trim, one slow star point on deep space blue face, rookie pilot starter kit aesthetic, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_02.png（巡航II型）

**输出：** `res://assets/ui/instruments/pi_generic_02.png`

**型号 ID：** `pi_generic_02` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, slightly larger dial with dual faint star orbits and soft cyan recovery glow ring suggesting energy recycle, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_03.png（巡航III型）

**输出：** `res://assets/ui/instruments/pi_generic_03.png`

**型号 ID：** `pi_generic_03` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dial with expanded outer deployment range tick marks and three star points, agile scout styling, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_04.png（锋线III型）

**输出：** `res://assets/ui/instruments/pi_generic_04.png`

**型号 ID：** `pi_generic_04` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dial with forward-pointing phase blade motif on bezel, warm amber accent for attack tuning, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_05.png（锋线IV型）

**输出：** `res://assets/ui/instruments/pi_generic_05.png`

**型号 ID：** `pi_generic_05` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dual-layer dial rings, crossed phase strike glyphs, balanced assault module look, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_06.png（壁垒IV型）

**输出：** `res://assets/ui/instruments/pi_generic_06.png`

**型号 ID：** `pi_generic_06` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, heavy shield-shaped bezel around dial, reinforced rivet frame, defensive steel gray accents, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_07.png（壁垒V型）

**输出：** `res://assets/ui/instruments/pi_generic_07.png`

**型号 ID：** `pi_generic_07` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, fortified dial with thick armored collar and steady gold stability glow, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_08.png（脉冲V型）

**输出：** `res://assets/ui/instruments/pi_generic_08.png`

**型号 ID：** `pi_generic_08` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dial surrounded by pulsing lightning arcs, high energy output capacitor nodes, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_09.png（脉冲VI型）

**输出：** `res://assets/ui/instruments/pi_generic_09.png`

**型号 ID：** `pi_generic_09` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, overcharged dial with red overload sector and crackling phase sparks at rim, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_10.png（星链VI型）

**输出：** `res://assets/ui/instruments/pi_generic_10.png`

**型号 ID：** `pi_generic_10` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, constellation-linked dial with six tiny node stars chained by light threads, resource focus, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_11.png（星链VII型）

**输出：** `res://assets/ui/instruments/pi_generic_11.png`

**型号 ID：** `pi_generic_11` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, seven-node star chain halo, balanced multi-stat enhancement look, silver-gold trim, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_generic_12.png（天穹VII型）

**输出：** `res://assets/ui/instruments/pi_generic_12.png`

**型号 ID：** `pi_generic_12` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, celestial crown bezel above dial, radiant sky-gold aura, ultimate generic flagship instrument, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_helix_01.png（螺旋-猎线）

**输出：** `res://assets/ui/instruments/pi_helix_01.png`

**型号 ID：** `pi_helix_01` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, helix recon green spiral spine across dial, hunter sight reticle, recon line motif, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_helix_02.png（螺旋-织网）

**输出：** `res://assets/ui/instruments/pi_helix_02.png`

**型号 ID：** `pi_helix_02` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, interwoven helix mesh net around dial, data web nodes, scout network aesthetic, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_helix_03.png（螺旋-神经束）

**输出：** `res://assets/ui/instruments/pi_helix_03.png`

**型号 ID：** `pi_helix_03` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dense neural helix bundle core, bright synapse flashes, advanced recon instrument, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_iron_01.png（铁幕-重锚）

**输出：** `res://assets/ui/instruments/pi_iron_01.png`

**型号 ID：** `pi_iron_01` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, iron wall corp anchor bolt frame, heavy steel chains, anchored tanker dial, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_iron_02.png（铁幕-铸链）

**输出：** `res://assets/ui/instruments/pi_iron_02.png`

**型号 ID：** `pi_iron_02` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, forged chain links encircling dial, molten steel seam highlights, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_iron_03.png（铁幕-王座）

**输出：** `res://assets/ui/instruments/pi_iron_03.png`

**型号 ID：** `pi_iron_03` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, throne-backplate iron fortress mount, regal gunmetal and gold rivets, ultimate iron wall instrument, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_nova_01.png（新星-回路）

**输出：** `res://assets/ui/instruments/pi_nova_01.png`

**型号 ID：** `pi_nova_01` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, nova arms orange circuit loop around dial, weapon circuit board traces, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_nova_02.png（新星-灼流）

**输出：** `res://assets/ui/instruments/pi_nova_02.png`

**型号 ID：** `pi_nova_02` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, flame-wreathed dial bezel, heat distortion waves, assault firepower styling, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_nova_03.png（新星-超弦）

**输出：** `res://assets/ui/instruments/pi_nova_03.png`

**型号 ID：** `pi_nova_03` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, hyperstring vibration lines and intense flame crown, legendary nova arms superweapon dial, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_nova_04.png（新星-裂变庭）

**输出：** `res://assets/ui/instruments/pi_nova_04.png`

**型号 ID：** `pi_nova_04` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, fission chamber ring with particle burst spokes, kill-energy feedback glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_r_free_deploy.png（零成本部署）

**输出：** `res://assets/ui/instruments/pi_r_free_deploy.png`

**说明：** 稀有属性图标；完整 prompt 见 `docs/prompts/ui_icon_prompts_74.md` → **pi_r_free_deploy（自由部署）**。

#### 引用
同上（属性图标构图，非表盘型号）。

### pi_umbra_01.png（影幕-薄刃）

**输出：** `res://assets/ui/instruments/pi_umbra_01.png`

**型号 ID：** `pi_umbra_01` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, void research violet thin blade slash across dial, stealth edge highlight, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_umbra_02.png（影幕-折光）

**输出：** `res://assets/ui/instruments/pi_umbra_02.png`

**型号 ID：** `pi_umbra_02` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, refracted light prism shards, crit eye slit motif, shadow recon styling, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品

### pi_umbra_03.png（影幕-寂静域）

**输出：** `res://assets/ui/instruments/pi_umbra_03.png`

**型号 ID：** `pi_umbra_03` | **势力/系列：** 见 `data/phase_instruments.gd`

#### English prompt

```text

flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, silent void dome suppressing light, dark purple haze, assassination field instrument, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512



Negative prompt: text, watermark, logo, 3D render, photorealistic, gradient background, cluttered, multiple items

```

#### 负面提示词（中文备忘）
文字、水印、logo标记、3D渲染、写实风格、渐变背景、杂乱、多物品
