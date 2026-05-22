# Phase War — 关卡 1–100 场景图 AI 提示词

本文档由 `tools/gen_level_bg_prompts.py` 生成；与 `data/level_information.gd` 关卡文案及 `_get_environment_for_era_level` 环境循环对齐。
每张图：**无角色、无怪物、无 UI、无文字**；**16:9 横版**；**固定三层构图**（上 65% 天空/远景、中 20% 过渡带、下 15% 唯一主战斗车道）。
**第 1 关**英文 Top 65% 在数据环境之上强化了「索姆河黎明 + 青蓝远山 + 雨后微湿」，以贴合已验证的 Stage 1 参考图；中文「场景说明」仍为数据表字段。

---

## 第 1 关（World War I）

**关卡介绍：** 晨曦中的索姆河，第一阶段突破作战

**场景说明：** 雨天、山地、白昼、强能量场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn sky with layered blue-cyan distant mountains, soft clouds, morning light; light post-rain cool gray-blue haze and wet atmosphere; layered mountain ranges fading into atmospheric perspective; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — WW1 Somme morning: shattered woods, river mist, distant craters, ruined farmhouse silhouettes, barbed wire lines, sandbag berms, low bunkers, trench traces. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 1 background — narrative cue: "晨曦中的索姆河，第一阶段突破作战" (no text in image). Thematically aligned with roster theme "Stage 1 — Infantry Squad · MP18" (no soldiers, no weapons depicted).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 2 关（World War I）

**关卡介绍：** 泥泞的堡垒区，持续的炮火覆盖

**场景说明：** 风暴、城市、黄昏、虚空裂隙；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); distant city skyline silhouettes, industrial roofs and chimneys; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — mud fortress berms, splintered stakes, shell-scarred rises, broken trench lines, wooden posts. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 2 background — narrative cue: "泥泞的堡垒区，持续的炮火覆盖" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 3 关（World War I）

**关卡介绍：** 被摧毁的村庄，废墟中的阵地防守

**场景说明：** 浓雾、森林、夜晚、纳米雾场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), foggy sky, low visibility mist, diffused light; dense forest canopy line, broken treelines; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — ruined village rooftops, collapsed walls, courtyard rubble piles, defensive tooth lines. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 3 background — narrative cue: "被摧毁的村庄，废墟中的阵地防守" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 4 关（World War I）

**关卡介绍：** 铁丝网阵地，手对手的肉搏战

**场景说明：** 晴朗、沙漠、黎明、常规能量场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, clear sky with soft layered clouds; dune silhouettes, heat shimmer suggestion (subtle, still image); subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — dense barbed wire entanglements, stake rows, shallow fighting pits silhouettes. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 4 background — narrative cue: "铁丝网阵地，手对手的肉搏战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 5 关（World War I）

**关卡介绍：** 山丘阵地，视野开阔的攻防战

**场景说明：** 雨天、平原、白昼、强能量场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, overcast rainy sky, cool gray-blue atmosphere, light rain haze; open plains horizon, distant low ridges; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — open hill crest lines, observation posts, zigzag trench cuts on slopes. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 5 background — narrative cue: "山丘阵地，视野开阔的攻防战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 6 关（World War I）

**关卡介绍：** 林地密林，丛林中的游击战

**场景说明：** 风暴、山地、黄昏、虚空裂隙；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); layered mountain ranges fading into atmospheric perspective; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — forest edge with splintered trunks, mossy stumps, hidden trench mouths. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 6 background — narrative cue: "林地密林，丛林中的游击战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 7 关（World War I）

**关卡介绍：** 河道要塞，水上运输线的争夺

**场景说明：** 浓雾、城市、夜晚、纳米雾场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), foggy sky, low visibility mist, diffused light; distant city skyline silhouettes, industrial roofs and chimneys; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — riverbank piers, broken bridge spans, mooring posts, water glint (background only). Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 7 background — narrative cue: "河道要塞，水上运输线的争夺" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 8 关（World War I）

**关卡介绍：** 工业区废墟，工厂遗骸中的激战

**场景说明：** 晴朗、森林、黎明、常规能量场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, clear sky with soft layered clouds; dense forest canopy line, broken treelines; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — factory skeleton frames, rusted gantries, broken chimneys, industrial rubble. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 8 background — narrative cue: "工业区废墟，工厂遗骸中的激战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 9 关（World War I）

**关卡介绍：** 平原冲锋，大规模骑兵冲锋战

**场景说明：** 雨天、沙漠、白昼、强能量场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, overcast rainy sky, cool gray-blue atmosphere, light rain haze; dune silhouettes, heat shimmer suggestion (subtle, still image); faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — wide plain horizon, distant fence lines, low earthworks, hoof-rutted ground suggestion (empty). Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 9 background — narrative cue: "平原冲锋，大规模骑兵冲锋战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 10 关（World War I）

**关卡介绍：** 山谷陷阱，敌方伏击的突围战

**场景说明：** 风暴、平原、黄昏、虚空裂隙；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); open plains horizon, distant low ridges; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — valley mouth choke point, steep ridge silhouettes, fallen logs as barriers. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 10 background — narrative cue: "山谷陷阱，敌方伏击的突围战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 11 关（World War I）

**关卡介绍：** 补给站争夺，后勤线的防守战

**场景说明：** 浓雾、山地、夜晚、纳米雾场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), foggy sky, low visibility mist, diffused light; layered mountain ranges fading into atmospheric perspective; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — supply dump crates stacks (no people), tarp covers, wheel ruts, barrel clusters. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 11 background — narrative cue: "补给站争夺，后勤线的防守战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 12 关（World War I）

**关卡介绍：** 机关枪阵地，死神镰刀的扫射

**场景说明：** 晴朗、城市、黎明、常规能量场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, clear sky with soft layered clouds; distant city skyline silhouettes, industrial roofs and chimneys; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — MG nest concrete lips, sandbag walls, embrasure shapes, spent brass piles (static props). Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 12 background — narrative cue: "机关枪阵地，死神镰刀的扫射" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 13 关（World War I）

**关卡介绍：** 堑壕防线，步步为营的攻坚

**场景说明：** 雨天、森林、白昼、强能量场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, overcast rainy sky, cool gray-blue atmosphere, light rain haze; dense forest canopy line, broken treelines; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — deep zigzag trenches, duckboards suggestion, parapet sandbags, communication trenches. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 13 background — narrative cue: "堑壕防线，步步为营的攻坚" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 14 关（World War I）

**关卡介绍：** 炮火覆盖区，地狱之火的轰炸

**场景说明：** 风暴、沙漠、黄昏、虚空裂隙；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); dune silhouettes, heat shimmer suggestion (subtle, still image); thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — charred tree spikes, smoke-stained ground, crater lips, scattered shell casings. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 14 background — narrative cue: "炮火覆盖区，地狱之火的轰炸" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 15 关（World War I）

**关卡介绍：** 城市街道，巷战中的血战

**场景说明：** 浓雾、平原、夜晚、纳米雾场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), foggy sky, low visibility mist, diffused light; open plains horizon, distant low ridges; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — narrow street ruins, barricade debris, shattered windows, cobble patches. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 15 background — narrative cue: "城市街道，巷战中的血战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 16 关（World War I）

**关卡介绍：** 沙地要塞，沙漠中的防御

**场景说明：** 晴朗、山地、黎明、常规能量场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, clear sky with soft layered clouds; layered mountain ranges fading into atmospheric perspective; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — desert redoubt silhouettes, stone sangars, wind fences, distant watchtower. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 16 background — narrative cue: "沙地要塞，沙漠中的防御" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 17 关（World War I）

**关卡介绍：** 森林伏击，林间突袭战

**场景说明：** 雨天、城市、白昼、强能量场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, overcast rainy sky, cool gray-blue atmosphere, light rain haze; distant city skyline silhouettes, industrial roofs and chimneys; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — forest ambush corridor: ferns, fallen timber, low earth berms. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 17 background — narrative cue: "森林伏击，林间突袭战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 18 关（World War I）

**关卡介绍：** 鼓动全线，最后的总攻

**场景说明：** 风暴、森林、黄昏、虚空裂隙；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); dense forest canopy line, broken treelines; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — multiple parallel trench lines, flagless poles, distant signal masts. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 18 background — narrative cue: "鼓动全线，最后的总攻" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 19 关（World War I）

**关卡介绍：** 指挥中枢，敌方司令部争夺战

**场景说明：** 浓雾、沙漠、夜晚、纳米雾场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), foggy sky, low visibility mist, diffused light; dune silhouettes, heat shimmer suggestion (subtle, still image); soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — command bunker bulkhead shapes, antenna masts, sandbag revetments, map table NOT visible (no interior story). Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 19 background — narrative cue: "指挥中枢，敌方司令部争夺战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 20 关（World War I）

**关卡介绍：** 胜利时刻，一战结束前夜的最后一战

**场景说明：** 晴朗、平原、黎明、常规能量场；钢壁防务（Iron Wall Corp）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, clear sky with soft layered clouds; open plains horizon, distant low ridges; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — WW1 armistice dawn: quiet battlefield, lowered barriers, distant crosses silhouette-free of figures. Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 20 background — narrative cue: "胜利时刻，一战结束前夜的最后一战" (no text in image). BOSS STAGE finale mood — extra epic sky, still no characters.
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 21 关（World War II）

**关卡介绍：** 不列颠空战，欧洲战场开启

**场景说明：** 风暴、城市、白昼、常规能量场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); distant city skyline silhouettes, industrial roofs and chimneys; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Battle of Britain mood: distant airfield strips, radar tower lattice, empty radar bunkers, reinforced perimeter fences. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 21 background — narrative cue: "不列颠空战，欧洲战场开启" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 22 关（World War II）

**关卡介绍：** 北非沙漠，隆美尔的雄狮之师

**场景说明：** 浓雾、森林、黄昏、强能量场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, foggy sky, low visibility mist, diffused light; dense forest canopy line, broken treelines; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — North Africa: rolling dunes, escarpment lines, oasis palms sparse, vehicle track patterns. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 22 background — narrative cue: "北非沙漠，隆美尔的雄狮之师" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 23 关（World War II）

**关卡介绍：** 苏联前线，莫斯科保卫战

**场景说明：** 晴朗、沙漠、夜晚、虚空裂隙；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), clear sky with soft layered clouds; dune silhouettes, heat shimmer suggestion (subtle, still image); thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Eastern Front winter: snow fields, birch trunks, ruined brick blocks, ice river crack. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 23 background — narrative cue: "苏联前线，莫斯科保卫战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 24 关（World War II）

**关卡介绍：** 太平洋岛屿，日军防线

**场景说明：** 雨天、平原、黎明、纳米雾场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, overcast rainy sky, cool gray-blue atmosphere, light rain haze; open plains horizon, distant low ridges; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Pacific atoll: palm clusters, coral rock, bunker pours, beach obstacles. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 24 background — narrative cue: "太平洋岛屿，日军防线" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 25 关（World War II）

**关卡介绍：** 诺曼底滩头，D日登陆作战

**场景说明：** 风暴、山地、白昼、常规能量场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); layered mountain ranges fading into atmospheric perspective; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Normandy beach: sea wall blocks, hedgehog obstacles, shattered bunkers, tidal flats. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 25 background — narrative cue: "诺曼底滩头，D日登陆作战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 26 关（World War II）

**关卡介绍：** 莱茵河防线，德军最后堡垒

**场景说明：** 浓雾、城市、黄昏、强能量场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, foggy sky, low visibility mist, diffused light; distant city skyline silhouettes, industrial roofs and chimneys; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Rhine riverbank: pontoon remnants, bunker teeth, vineyard terraces. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 26 background — narrative cue: "莱茵河防线，德军最后堡垒" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 27 关（World War II）

**关卡介绍：** 太平洋反攻，岛屿争夺战

**场景说明：** 晴朗、森林、夜晚、虚空裂隙；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), clear sky with soft layered clouds; dense forest canopy line, broken treelines; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Pacific island ridgeline: coconut logs, coconut bunker, rope nets. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 27 background — narrative cue: "太平洋反攻，岛屿争夺战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 28 关（World War II）

**关卡介绍：** 柏林前夜，欧洲战场最后冲刺

**场景说明：** 雨天、沙漠、黎明、纳米雾场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, overcast rainy sky, cool gray-blue atmosphere, light rain haze; dune silhouettes, heat shimmer suggestion (subtle, still image); soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Berlin suburb ruins: apartment shells, tram wires hanging, rubble mountains. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 28 background — narrative cue: "柏林前夜，欧洲战场最后冲刺" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 29 关（World War II）

**关卡介绍：** 硫黄岛，血肉磨坊的战场

**场景说明：** 风暴、平原、白昼、常规能量场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); open plains horizon, distant low ridges; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Iwo Jima ash slopes: sharp volcanic grit, cave mouths dark, cable reels. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 29 background — narrative cue: "硫黄岛，血肉磨坊的战场" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 30 关（World War II）

**关卡介绍：** 荷兰冻土，冬季防线突破

**场景说明：** 浓雾、山地、黄昏、强能量场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text

```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, foggy sky, low visibility mist, diffused light; layered mountain ranges fading into atmospheric perspective; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Netherlands winter: frozen canals, windmill silhouette, dike roads. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 30 background — narrative cue: "荷兰冻土，冬季防线突破" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes

---

## 第 31 关（World War II）

**关卡介绍：** 法国解放，巴黎光复在即

**场景说明：** 晴朗、城市、夜晚、虚空裂隙；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), clear sky with soft layered clouds; distant city skyline silhouettes, industrial roofs and chimneys; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Paris liberation mood: barricade furniture piles, tricolor faded on wall (no text), cafe awning ruins. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 31 background — narrative cue: "法国解放，巴黎光复在即" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 32 关（World War II）

**关卡介绍：** 德国心脏，柏林之战

**场景说明：** 雨天、森林、黎明、纳米雾场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, overcast rainy sky, cool gray-blue atmosphere, light rain haze; dense forest canopy line, broken treelines; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Berlin center: shattered colonnade, statue plinth empty, tram wreck. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 32 background — narrative cue: "德国心脏，柏林之战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 33 关（World War II）

**关卡介绍：** 中国战场，日军在亚洲的最后据点

**场景说明：** 风暴、沙漠、白昼、常规能量场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); dune silhouettes, heat shimmer suggestion (subtle, still image); subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Chinese river town ruins: tile roofs collapsed, stone bridge arch. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 33 background — narrative cue: "中国战场，日军在亚洲的最后据点" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 34 关（World War II）

**关卡介绍：** 东南亚，丛林中的绞肉机

**场景说明：** 浓雾、平原、黄昏、强能量场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, foggy sky, low visibility mist, diffused light; open plains horizon, distant low ridges; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — SE Asia jungle: bamboo thickets, laterite red soil berms, river glint. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 34 background — narrative cue: "东南亚，丛林中的绞肉机" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 35 关（World War II）

**关卡介绍：** 缅甸阵地，丛林战的极端

**场景说明：** 晴朗、山地、夜晚、虚空裂隙；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), clear sky with soft layered clouds; layered mountain ranges fading into atmospheric perspective; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Burma trail: rope bridge silhouette, monsoon mud shine, elephant grass (no animals). Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 35 background — narrative cue: "缅甸阵地，丛林战的极端" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 36 关（World War II）

**关卡介绍：** 日本本土，最终决战前的岛屿战

**场景说明：** 雨天、城市、黎明、纳米雾场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, overcast rainy sky, cool gray-blue atmosphere, light rain haze; distant city skyline silhouettes, industrial roofs and chimneys; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Japanese home island coast: sheer cliffs, tunnel mouths, shore batteries. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 36 background — narrative cue: "日本本土，最终决战前的岛屿战" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 37 关（World War II）

**关卡介绍：** 冲绳血战，太平洋战争最后的岛屿

**场景说明：** 风暴、森林、白昼、常规能量场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); dense forest canopy line, broken treelines; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Okinawa ridge: tombs stone walls, mud slides, cave vents. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 37 background — narrative cue: "冲绳血战，太平洋战争最后的岛屿" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 38 关（World War II）

**关卡介绍：** 原子弹之影，核武的威胁

**场景说明：** 浓雾、沙漠、黄昏、强能量场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, foggy sky, low visibility mist, diffused light; dune silhouettes, heat shimmer suggestion (subtle, still image); faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — atomic dread sky: tall cumulus, subtle lens flare, silent city silhouette. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 38 background — narrative cue: "原子弹之影，核武的威胁" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 39 关（World War II）

**关卡介绍：** 战争机器，二战巅峰之作

**场景说明：** 晴朗、平原、夜晚、虚空裂隙；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), clear sky with soft layered clouds; open plains horizon, distant low ridges; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — factory assembly hall skeleton, crane rails, tank hull shapes covered (no crew). Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 39 background — narrative cue: "战争机器，二战巅峰之作" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 40 关（World War II）

**关卡介绍：** 世界重生，新时代的开端

**场景说明：** 雨天、山地、黎明、纳米雾场；新星兵工（Nova Arms）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, overcast rainy sky, cool gray-blue atmosphere, light rain haze; layered mountain ranges fading into atmospheric perspective; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — VE-day dawn: confetti-like paper on ground, quiet street, bunting shapes without letters. Era: World War II. Nova Arms style: olive drab + rust orange + steel gray, industrial war economy.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 40 background — narrative cue: "世界重生，新时代的开端" (no text in image). BOSS STAGE finale mood — extra epic sky, still no characters.
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 41 关（Cold War）

**关卡介绍：** 铁幕降临，两极对峙开始

**场景说明：** 浓雾、森林、白昼、纳米雾场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, foggy sky, low visibility mist, diffused light; dense forest canopy line, broken treelines; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — iron curtain fence double lines, watchtower cones, snow patrol road. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 41 background — narrative cue: "铁幕降临，两极对峙开始" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 42 关（Cold War）

**关卡介绍：** 朝鲜半岛，意识形态的冲突

**场景说明：** 晴朗、沙漠、黄昏、常规能量场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, clear sky with soft layered clouds; dune silhouettes, heat shimmer suggestion (subtle, still image); subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Korean ridge war: rice paddies terraces, snow caps, bunker huts. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 42 background — narrative cue: "朝鲜半岛，意识形态的冲突" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 43 关（Cold War）

**关卡介绍：** 古巴导弹危机，核战争边缘

**场景说明：** 雨天、平原、夜晚、强能量场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), overcast rainy sky, cool gray-blue atmosphere, light rain haze; open plains horizon, distant low ridges; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Caribbean missile launch pad silhouettes, palm ridges, blockhouse. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 43 background — narrative cue: "古巴导弹危机，核战争边缘" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 44 关（Cold War）

**关卡介绍：** 越南丛林，非传统战争

**场景说明：** 风暴、山地、黎明、虚空裂隙；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); layered mountain ranges fading into atmospheric perspective; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Vietnam triple canopy line, bamboo thickets, punji stake fields (props only). Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 44 background — narrative cue: "越南丛林，非传统战争" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 45 关（Cold War）

**关卡介绍：** 中东危机，石油与权力的争夺

**场景说明：** 浓雾、城市、白昼、纳米雾场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, foggy sky, low visibility mist, diffused light; distant city skyline silhouettes, industrial roofs and chimneys; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Middle East oil derricks, pipeline on sand ridge, flare stack. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 45 background — narrative cue: "中东危机，石油与权力的争夺" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 46 关（Cold War）

**关卡介绍：** 柏林危机，东西方的对峙

**场景说明：** 晴朗、森林、黄昏、常规能量场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, clear sky with soft layered clouds; dense forest canopy line, broken treelines; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Berlin Wall concrete segments, death strip gravel, tower lights. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 46 background — narrative cue: "柏林危机，东西方的对峙" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 47 关（Cold War）

**关卡介绍：** 中苏边界，社会主义阵营的裂隙

**场景说明：** 雨天、沙漠、夜晚、强能量场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), overcast rainy sky, cool gray-blue atmosphere, light rain haze; dune silhouettes, heat shimmer suggestion (subtle, still image); faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Sino-Soviet border posts, birch forest, snow drifts. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 47 background — narrative cue: "中苏边界，社会主义阵营的裂隙" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 48 关（Cold War）

**关卡介绍：** 中东战争，反复的冲突

**场景说明：** 风暴、平原、黎明、虚空裂隙；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); open plains horizon, distant low ridges; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Golan-like ridges: terraced fields, bunker teeth, dust. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 48 background — narrative cue: "中东战争，反复的冲突" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 49 关（Cold War）

**关卡介绍：** 南美战火，冷战在美洲

**场景说明：** 浓雾、山地、白昼、纳米雾场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, foggy sky, low visibility mist, diffused light; layered mountain ranges fading into atmospheric perspective; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — South American jungle favela silhouettes on hill, river brown. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 49 background — narrative cue: "南美战火，冷战在美洲" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 50 关（Cold War）

**关卡介绍：** 阿富汗苏联，帝国的陷阱

**场景说明：** 晴朗、城市、黄昏、常规能量场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, clear sky with soft layered clouds; distant city skyline silhouettes, industrial roofs and chimneys; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Afghan mountain pass switchbacks, cave mouths, stone sangars. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 50 background — narrative cue: "阿富汗苏联，帝国的陷阱" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 51 关（Cold War）

**关卡介绍：** 东欧剧变，铁幕背后的咆哮

**场景说明：** 雨天、森林、夜晚、强能量场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), overcast rainy sky, cool gray-blue atmosphere, light rain haze; dense forest canopy line, broken treelines; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Eastern Europe square: toppled statue pedestal, cobble churned. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 51 background — narrative cue: "东欧剧变，铁幕背后的咆哮" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 52 关（Cold War）

**关卡介绍：** 印支战争，美苏代理人

**场景说明：** 风暴、沙漠、黎明、虚空裂隙；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); dune silhouettes, heat shimmer suggestion (subtle, still image); thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Indochina river delta: mangrove fingers, sampan wrecks, dike roads. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 52 background — narrative cue: "印支战争，美苏代理人" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 53 关（Cold War）

**关卡介绍：** 中越战争，同志的兵戈相见

**场景说明：** 浓雾、平原、白昼、纳米雾场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, foggy sky, low visibility mist, diffused light; open plains horizon, distant low ridges; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Karst hills China-Vietnam: sharp peaks, rice wet mirrors. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 53 background — narrative cue: "中越战争，同志的兵戈相见" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 54 关（Cold War）

**关卡介绍：** 马岛争端，岛屿的血泪

**场景说明：** 晴朗、山地、黄昏、常规能量场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, clear sky with soft layered clouds; layered mountain ranges fading into atmospheric perspective; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Falklands rocky grass, stone walls, peat trenches. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 54 background — narrative cue: "马岛争端，岛屿的血泪" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 55 关（Cold War）

**关卡介绍：** 伊朗变革，伊斯兰的觉醒

**场景说明：** 雨天、城市、夜晚、强能量场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), overcast rainy sky, cool gray-blue atmosphere, light rain haze; distant city skyline silhouettes, industrial roofs and chimneys; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Iranian city minaret silhouettes, burning oil drum props (no people). Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 55 background — narrative cue: "伊朗变革，伊斯兰的觉醒" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 56 关（Cold War）

**关卡介绍：** 苏联衰落，帝国的黄昏

**场景说明：** 风暴、森林、黎明、虚空裂隙；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); dense forest canopy line, broken treelines; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Soviet industrial taiga: radar domes, missile train garage mouths. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 56 background — narrative cue: "苏联衰落，帝国的黄昏" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 57 关（Cold War）

**关卡介绍：** 古巴导弹，危险的边缘游走

**场景说明：** 浓雾、沙漠、白昼、纳米雾场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, foggy sky, low visibility mist, diffused light; dune silhouettes, heat shimmer suggestion (subtle, still image); soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Caribbean bay: radar dome, pier fences, storm sky. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 57 background — narrative cue: "古巴导弹，危险的边缘游走" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 58 关（Cold War）

**关卡介绍：** 冷战峰值，对立的最高点

**场景说明：** 晴朗、平原、黄昏、常规能量场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, clear sky with soft layered clouds; open plains horizon, distant low ridges; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — nuclear test observation towers distant, desert flats, caution tapes. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 58 background — narrative cue: "冷战峰值，对立的最高点" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 59 关（Cold War）

**关卡介绍：** 苏联解体，帝国的终结

**场景说明：** 雨天、山地、夜晚、强能量场；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), overcast rainy sky, cool gray-blue atmosphere, light rain haze; layered mountain ranges fading into atmospheric perspective; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Moscow winter skyline faint, red stars removed, generic spires. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 59 background — narrative cue: "苏联解体，帝国的终结" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 60 关（Cold War）

**关卡介绍：** 新世界秩序，冷战的落幕

**场景说明：** 风暴、城市、黎明、虚空裂隙；以太动力（Aether Dynamics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); distant city skyline silhouettes, industrial roofs and chimneys; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — UN-blue mood open plaza: modern glass, peace dove statue without text. Era: Cold War. Aether Dynamics style: teal-gray + concrete + warning yellow accents, radar-age tension.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 60 background — narrative cue: "新世界秩序，冷战的落幕" (no text in image). BOSS STAGE finale mood — extra epic sky, still no characters.
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 61 关（Modern）

**关卡介绍：** 海湾战争，精准制导的革命

**场景说明：** 晴朗、沙漠、白昼、虚空裂隙；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, clear sky with soft layered clouds; dune silhouettes, heat shimmer suggestion (subtle, still image); thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Desert Storm highway of death mood WITHOUT vehicles with crews: abandoned hull silhouettes far, oil smoke, desert heat. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 61 background — narrative cue: "海湾战争，精准制导的革命" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 62 关（Modern）

**关卡介绍：** 科威特收复，沙漠风暴来临

**场景说明：** 雨天、平原、黄昏、纳米雾场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, overcast rainy sky, cool gray-blue atmosphere, light rain haze; open plains horizon, distant low ridges; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Kuwait oil fires distant orange glow, sand berms, highway cut. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 62 background — narrative cue: "科威特收复，沙漠风暴来临" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 63 关（Modern）

**关卡介绍：** 巴尔干战争，欧洲的创伤

**场景说明：** 风暴、山地、夜晚、常规能量场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); layered mountain ranges fading into atmospheric perspective; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Balkan ruined brutalist atrium, sniper pockmarks, snow slush. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 63 background — narrative cue: "巴尔干战争，欧洲的创伤" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 64 关（Modern）

**关卡介绍：** 科索沃空袭，网络战争的开端

**场景说明：** 浓雾、城市、黎明、强能量场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, foggy sky, low visibility mist, diffused light; distant city skyline silhouettes, industrial roofs and chimneys; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Kosovo command center exterior: satellite dishes, sandbag wall modern. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 64 background — narrative cue: "科索沃空袭，网络战争的开端" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 65 关（Modern）

**关卡介绍：** 阿富汗反恐，新型战争

**场景说明：** 晴朗、森林、白昼、虚空裂隙；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, clear sky with soft layered clouds; dense forest canopy line, broken treelines; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Afghan mountain firebase: HESCO walls, comms poles, gravel. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 65 background — narrative cue: "阿富汗反恐，新型战争" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 66 关（Modern）

**关卡介绍：** 伊拉克战争，大规模杀伤武器之谎

**场景说明：** 雨天、沙漠、黄昏、纳米雾场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, overcast rainy sky, cool gray-blue atmosphere, light rain haze; dune silhouettes, heat shimmer suggestion (subtle, still image); soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Iraq palm boulevard ruins: checkpoint concrete, rust barrels. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 66 background — narrative cue: "伊拉克战争，大规模杀伤武器之谎" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 67 关（Modern）

**关卡介绍：** 中东乱局，恐怖主义与反恐

**场景说明：** 风暴、平原、夜晚、常规能量场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); open plains horizon, distant low ridges; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Middle East souk alley ruined, hanging wires, tarp roofs. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 67 background — narrative cue: "中东乱局，恐怖主义与反恐" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 68 关（Modern）

**关卡介绍：** 格鲁吉亚冲突，大国博弈

**场景说明：** 浓雾、山地、黎明、强能量场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, foggy sky, low visibility mist, diffused light; layered mountain ranges fading into atmospheric perspective; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Caucasus mountain road blast cuts, concrete dragon teeth. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 68 background — narrative cue: "格鲁吉亚冲突，大国博弈" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 69 关（Modern）

**关卡介绍：** 南海争端，21世纪的新战场

**场景说明：** 晴朗、城市、白昼、虚空裂隙；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, clear sky with soft layered clouds; distant city skyline silhouettes, industrial roofs and chimneys; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — South China Sea island runway: reef ring, radar dome, sea cyan. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 69 background — narrative cue: "南海争端，21世纪的新战场" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 70 关（Modern）

**关卡介绍：** 叙利亚内战，国际介入的复杂

**场景说明：** 雨天、森林、黄昏、纳米雾场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, overcast rainy sky, cool gray-blue atmosphere, light rain haze; dense forest canopy line, broken treelines; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — Syria aleppo-like rubble canyon, bent rebar, dust. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 70 background — narrative cue: "叙利亚内战，国际介入的复杂" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 71 关（Modern）

**关卡介绍：** 恐怖活动，看不见的敌人

**场景说明：** 风暴、沙漠、夜晚、常规能量场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); dune silhouettes, heat shimmer suggestion (subtle, still image); subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — urban terror scene props: abandoned bus, caution tape abstract, no victims. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 71 background — narrative cue: "恐怖活动，看不见的敌人" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 72 关（Modern）

**关卡介绍：** 网络战争，虚拟空间的较量

**场景说明：** 浓雾、平原、黎明、强能量场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, foggy sky, low visibility mist, diffused light; open plains horizon, distant low ridges; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — cyberwar server stacks outdoor camouflage, fiber trunks, LED hum. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 72 background — narrative cue: "网络战争，虚拟空间的较量" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 73 关（Modern）

**关卡介绍：** 无人机时代，天空中的死神

**场景说明：** 晴朗、山地、白昼、虚空裂隙；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, clear sky with soft layered clouds; layered mountain ranges fading into atmospheric perspective; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — drone ground control shelter: antenna farm, gravel, distant runway. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 73 background — narrative cue: "无人机时代，天空中的死神" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 74 关（Modern）

**关卡介绍：** 精准打击，高科技战争

**场景说明：** 雨天、城市、黄昏、纳米雾场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, overcast rainy sky, cool gray-blue atmosphere, light rain haze; distant city skyline silhouettes, industrial roofs and chimneys; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — JDAM scorch marks on hangar, precision holes, foam panels. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 74 background — narrative cue: "精准打击，高科技战争" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 75 关（Modern）

**关卡介绍：** 联合作战，多国部队协同

**场景说明：** 风暴、森林、夜晚、常规能量场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); dense forest canopy line, broken treelines; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — joint ops camp: multinational tent colors abstract, helipad H mark minimal. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 75 background — narrative cue: "联合作战，多国部队协同" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 76 关（Modern）

**关卡介绍：** 中东重塑，大国游戏的棋盘

**场景说明：** 浓雾、沙漠、黎明、强能量场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, foggy sky, low visibility mist, diffused light; dune silhouettes, heat shimmer suggestion (subtle, still image); faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — desert FOB expansion: container stacks, T-wall lines, dust devils. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 76 background — narrative cue: "中东重塑，大国游戏的棋盘" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 77 关（Modern）

**关卡介绍：** 核武危机，威慑的平衡

**场景说明：** 晴朗、平原、白昼、虚空裂隙；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, clear sky with soft layered clouds; open plains horizon, distant low ridges; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — nuclear silo hatch landscape: fence coils, warning stripes no text. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 77 background — narrative cue: "核武危机，威慑的平衡" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 78 关（Modern）

**关卡介绍：** 现代战争，终极的高科技对抗

**场景说明：** 雨天、山地、黄昏、纳米雾场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, overcast rainy sky, cool gray-blue atmosphere, light rain haze; layered mountain ranges fading into atmospheric perspective; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — stealth hangar black wedge, heat tiles, rain. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 78 background — narrative cue: "现代战争，终极的高科技对抗" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 79 关（Modern）

**关卡介绍：** 多线作战，全球化的冲突

**场景说明：** 风暴、城市、夜晚、常规能量场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); distant city skyline silhouettes, industrial roofs and chimneys; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — global map room exterior generic: glass HQ, flagpoles without flags. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 79 background — narrative cue: "多线作战，全球化的冲突" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 80 关（Modern）

**关卡介绍：** 和平的曙光，战争的可能性

**场景说明：** 浓雾、森林、黎明、强能量场；量子后勤（Quantum Logistics）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, foggy sky, low visibility mist, diffused light; dense forest canopy line, broken treelines; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — peace memorial plaza: water pool, dove sculpture abstract, sunrise. Era: Modern. Quantum Logistics style: desert tan + tactical gray + glass-blue reflections, high-tech FOB.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 80 background — narrative cue: "和平的曙光，战争的可能性" (no text in image). BOSS STAGE finale mood — extra epic sky, still no characters.
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 81 关（Near Future）

**关卡介绍：** 人工智能觉醒，机器的反抗

**场景说明：** 雨天、平原、白昼、强能量场；螺旋侦察（Helix Recon）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, overcast rainy sky, cool gray-blue atmosphere, light rain haze; open plains horizon, distant low ridges; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — awakened AI server citadel: glowing server cliffs, red eye LEDs in architecture (not faces). Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 81 background — narrative cue: "人工智能觉醒，机器的反抗" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 82 关（Near Future）

**关卡介绍：** 相位折叠，空间战争的开端

**场景说明：** 风暴、山地、黄昏、虚空裂隙；螺旋侦察（Helix Recon）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); layered mountain ranges fading into atmospheric perspective; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — folded space: duplicated cliff slices, parallax glitch, mirrored peaks. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 82 background — narrative cue: "相位折叠，空间战争的开端" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 83 关（Near Future）

**关卡介绍：** 量子纠缠战，微观层面的对决

**场景说明：** 浓雾、城市、夜晚、纳米雾场；螺旋侦察（Helix Recon）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), foggy sky, low visibility mist, diffused light; distant city skyline silhouettes, industrial roofs and chimneys; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — quantum lab battleground: interference fringes in air, lattice glow. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 83 background — narrative cue: "量子纠缠战，微观层面的对决" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 84 关（Near Future）

**关卡介绍：** 反重力坦克，重力的解放

**场景说明：** 晴朗、森林、黎明、常规能量场；螺旋侦察（Helix Recon）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, clear sky with soft layered clouds; dense forest canopy line, broken treelines; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — anti-grav test track: floating rocks, blue glow under hull shapes (empty). Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 84 background — narrative cue: "反重力坦克，重力的解放" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 85 关（Near Future）

**关卡介绍：** 虚空之门，异界的入侵

**场景说明：** 雨天、沙漠、白昼、强能量场；螺旋侦察（Helix Recon）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, overcast rainy sky, cool gray-blue atmosphere, light rain haze; dune silhouettes, heat shimmer suggestion (subtle, still image); faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — void gate arch: black ellipse, purple rim, alien desert. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 85 background — narrative cue: "虚空之门，异界的入侵" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 86 关（Near Future）

**关卡介绍：** 电磁脉冲风暴，技术的崩溃

**场景说明：** 风暴、平原、黄昏、虚空裂隙；螺旋侦察（Helix Recon）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); open plains horizon, distant low ridges; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — EMP storm city: dark towers, lightning crawls on metal. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 86 background — narrative cue: "电磁脉冲风暴，技术的崩溃" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 87 关（Near Future）

**关卡介绍：** 时空扭曲，时间的战争

**场景说明：** 浓雾、山地、夜晚、纳米雾场；螺旋侦察（Helix Recon）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), foggy sky, low visibility mist, diffused light; layered mountain ranges fading into atmospheric perspective; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — time warp battlefield: clock melt on tower, split sky colors. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 87 background — narrative cue: "时空扭曲，时间的战争" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 88 关（Near Future）

**关卡介绍：** 纳米虫群，微观世界的杀戮

**场景说明：** 晴朗、城市、黎明、常规能量场；螺旋侦察（Helix Recon）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, clear sky with soft layered clouds; distant city skyline silhouettes, industrial roofs and chimneys; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — nano swarm haze: metallic mist band, eaten metal edges. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 88 background — narrative cue: "纳米虫群，微观世界的杀戮" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 89 关（Near Future）

**关卡介绍：** 幽灵协议，谍报战的极限

**场景说明：** 雨天、森林、白昼、强能量场；螺旋侦察（Helix Recon）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, overcast rainy sky, cool gray-blue atmosphere, light rain haze; dense forest canopy line, broken treelines; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — ghost protocol plaza: holo statues blank-faced (no faces), glass shards. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 89 background — narrative cue: "幽灵协议，谍报战的极限" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 90 关（Near Future）

**关卡介绍：** 机械生命，生与非生的界限

**场景说明：** 风暴、沙漠、黄昏、虚空裂隙；螺旋侦察（Helix Recon）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); dune silhouettes, heat shimmer suggestion (subtle, still image); thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — bio-mechanical ridge: cable vines, rib arches, no creatures. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 90 background — narrative cue: "机械生命，生与非生的界限" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 91 关（Near Future）

**关卡介绍：** 虚拟现实战争，两个世界的碰撞

**场景说明：** 浓雾、平原、夜晚、纳米雾场；虚空相位（Void Research）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), foggy sky, low visibility mist, diffused light; open plains horizon, distant low ridges; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — VR glitch forest: pixel leaves, neon seams, real mud mix. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 91 background — narrative cue: "虚拟现实战争，两个世界的碰撞" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 92 关（Near Future）

**关卡介绍：** 相位跳跃，维度的切割

**场景说明：** 晴朗、山地、黎明、常规能量场；虚空相位（Void Research）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, clear sky with soft layered clouds; layered mountain ranges fading into atmospheric perspective; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — phase jump cliffs: sliced terrain cubes floating slightly. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 92 background — narrative cue: "相位跳跃，维度的切割" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 93 关（Near Future）

**关卡介绍：** 能量场对撞，物理法则的突破

**场景说明：** 雨天、城市、白昼、强能量场；虚空相位（Void Research）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, overcast rainy sky, cool gray-blue atmosphere, light rain haze; distant city skyline silhouettes, industrial roofs and chimneys; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — colliding energy domes: two color fields meeting, ground crack. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 93 background — narrative cue: "能量场对撞，物理法则的突破" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 94 关（Near Future）

**关卡介绍：** 思想控制，精神层面的战争

**场景说明：** 风暴、森林、黄昏、虚空裂隙；虚空相位（Void Research）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); dense forest canopy line, broken treelines; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — mind control tower: obelisk with halo rings, empty streets. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 94 background — narrative cue: "思想控制，精神层面的战争" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 95 关（Near Future）

**关卡介绍：** 集群智能，群体的力量

**场景说明：** 浓雾、沙漠、夜晚、纳米雾场；虚空相位（Void Research）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), foggy sky, low visibility mist, diffused light; dune silhouettes, heat shimmer suggestion (subtle, still image); soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — swarm drone dock: hex pads, charging lights, no drones flying. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 95 background — narrative cue: "集群智能，群体的力量" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 96 关（Near Future）

**关卡介绍：** 终极武器，构装纪元的巅峰

**场景说明：** 晴朗、平原、黎明、常规能量场；虚空相位（Void Research）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, clear sky with soft layered clouds; open plains horizon, distant low ridges; subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — ultimate weapon silo: massive circular door, warning bands no text. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 96 background — narrative cue: "终极武器，构装纪元的巅峰" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 97 关（Near Future）

**关卡介绍：** 多维战场，高维世界的战斗

**场景说明：** 雨天、山地、白昼、强能量场；虚空相位（Void Research）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: daylight, balanced exposure, clear readability, overcast rainy sky, cool gray-blue atmosphere, light rain haze; layered mountain ranges fading into atmospheric perspective; faint cyan electric haze along horizon, tasteful sci-fi undertone integrated subtly into sky and horizon readability.
Middle 20%: transition zone — hypercube shadow on ground: 4D hint, impossible geometry far. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 97 background — narrative cue: "多维战场，高维世界的战斗" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 98 关（Near Future）

**关卡介绍：** 相位临界，构装纪元的终章

**场景说明：** 风暴、城市、黄昏、虚空裂隙；虚空相位（Void Research）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: golden hour, long shadows, amber rim light, stormy sky, dramatic cloud stacks, wind-swept cloud motion feel (static image); distant city skyline silhouettes, industrial roofs and chimneys; thin purple-void aurora streaks in sky, subtle dimensional shimmer integrated subtly into sky and horizon readability.
Middle 20%: transition zone — phase critical sky: aurora cracks, ground glassified. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 98 background — narrative cue: "相位临界，构装纪元的终章" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 99 关（Near Future）

**关卡介绍：** 永恒战争，循环的宿命

**场景说明：** 浓雾、森林、夜晚、纳米雾场；虚空相位（Void Research）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: night scene, cool moonlight or distant searchlights (no figures operating them), foggy sky, low visibility mist, diffused light; dense forest canopy line, broken treelines; soft silver nano-fog band above midground, tech-mist readability integrated subtly into sky and horizon readability.
Middle 20%: transition zone — eternal war loop: same trench copied in circle, subtle. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 99 background — narrative cue: "永恒战争，循环的宿命" (no text in image).
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---

## 第 100 关（Near Future）

**关卡介绍：** 新纪元黎明，超越一切的存在

**场景说明：** 晴朗、沙漠、黎明、常规能量场；虚空相位（Void Research）战区。与《Phase War》关卡数据（LevelInformation）环境循环一致。

### English prompt（复制到生图工具）

```text
16:9 horizontal 2D mobile game scene with fixed 3-layer composition (top 65% sky / middle 20% midground transition / bottom 15% single battle lane).
Top 65%: dawn light, warm-cool gradient, soft morning glow, clear sky with soft layered clouds; dune silhouettes, heat shimmer suggestion (subtle, still image); subtle normal battlefield atmosphere, no flashy magic integrated subtly into sky and horizon readability.
Middle 20%: transition zone — new dawn obelisk light beam: clean desert, old rust tanks tiny far. Era: Near Future. Helix / Void Research style: cyan-violet void accents + clean alloys + holographic hints.
Bottom 15%: one single main battle lane running straight from left to right across the entire frame; lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; lane occupies about 22% of total frame height (visibly broader than a thin strip), centered in the lower area. near side-view perspective, sharp edges, unbroken, not curved, not occluded. Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, short communication trench openings — must NOT intrude into the lane silhouette.
Theme must match Phase War Stage 100 background — narrative cue: "新纪元黎明，超越一切的存在" (no text in image). BOSS STAGE finale mood — extra epic sky, still no characters.
Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable composition, no characters, no combat VFX, no text, 16:9 horizontal.

Negative prompt: characters, people, soldiers, infantry, human silhouettes, enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes
```

### 负面提示词（中文备忘，与 English 中 Negative 一致）

角色、人物、士兵、步兵、人影、敌人、怪物、手持武器、枪械、MP18、战斗特效、血腥尸体、技能光效、带尸块的爆炸、UI、HUD、文字、水印、Logo、弯曲道路、S 形路、断裂主路、车道被挡、顶视、强透视畸变、3D 写实截图、黑暗恐怖、模糊、低分辨率、构图杂乱、重复多条车道。

---
