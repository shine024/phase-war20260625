# 黑门三档底图生图 Prompt 草稿（v27 Phase B，2026-09-06）

> 待用户过目后执行。生成目标：`assets/backgrounds/bg_endless_gate_t0/t1/t2.png`
> 管线：`tools/level_bg_workflow/generate_level_bg.py`（agnes-image-2.0-flash，key 轮换
> `tools/_api_keys_level1.txt`，size 1792x1024，negative_prompt 走独立字段）。
> 部署：出图后底边对齐裁切到 1280:648 比例再缩放（天空顶部多余部分裁掉，浮陆地面带必须保住
> 下部 ~28%），`--headless --editor --quit` 导入（禁 `--import`），入库后重打包美术备份 zip。
>
> 规则依据：tools/_agnes_image_api.md（负面词只留结构性排除；正面意象锁死；
> 避开 gritty/somber/dusty 类暗示词）+ docs/ART_PIPELINE_LEVEL_BG_GENERATION.md（负面词独立字段）。
> 设计依据：docs/无限模式_异族设定（草案）.md §5.1（深空 #0A0E1C + 青紫星云 + 黑门残环 +
> 舰队剪影 + 晶脉浮陆 + 破碎悬空缘）。
> 注意：不画部署格线（程序化层负责对齐真实槽位），prompt 里做结构性排除。

---

## 公共骨架（三档共用，档位差异见末尾替换段）

```
16:9 horizontal 2D mobile game scene, side-scrolling battlefield background.
ABSOLUTELY NO PEOPLE, NO HUMANS, NO FIGURES, NO CREATURES — empty scenery background only.

LAYOUT (strict): the upper three quarters is DEEP SPACE sky. The bottom quarter is one broken
floating rock platform seen from the side; its flat top surface forms ONE single continuous
combat lane running straight left-to-right, near side-view, unbroken. The platform underside is
jagged and shattered, hanging over open void, with a few small floating rock shards drifting
below its broken edges.

SKY (dominant): <档位天空段>

COMBAT LANE PLATFORM: grey-blue alien rock; organic irregular cracks across its surface with
<c档位晶脉段> Both LEFT and RIGHT edges of the lane completely clear and open.

NO text, no letters, no logo, no UI, no frame, no border, no regular grid pattern.
Style: stylized, clean, polished 2D side-scrolling mobile game background; muted low-key palette
of near-black indigo, deep violet, dim cyan and pale gold.
```

独立 negative_prompt（结构性排除，全档共用）：
```
any person, people, human, humanoid, soldier, creature, monster, animal,
text, letters, words, logo, watermark, user interface, frame, border,
regular grid lines, straight grid pattern, graph paper,
perspective view, first person view, top down view, isometric,
bright daylight, sun, blue sky, green grass, trees, clouds
```

---

## T0 初期 · 渗入（渗度 0-1）——"门后很安静"

天空段：
```
deep space of near-black indigo, mostly dark, silent and dormant; a sparse scattering of tiny
dim stars (small faint dots, never bright, never dense); one very faint thin wisp of dim violet
nebula near the top corner; far on the horizon a barely-visible thin dark arc — the dormant
silhouette of a colossal broken ring gate, almost fading into darkness.
```
晶脉段：
```
thin dim cyan crystal light seeping through, barely glowing, calm and weak.
```

## T1 中期 · 侵蚀（渗度 2-3）——"门在看着你"

天空段：
```
deep space of near-black indigo and dark violet; a scattered field of small dim stars; broad
soft veils of dim violet and teal nebula drifting across the upper sky; on the horizon the dark
silhouette of the colossal broken ring gate is now clearly visible, faintly edged with thin
cyan-gold light; a few tiny dark angular alien ship silhouettes drifting motionless high in the
distance.
```
晶脉段：
```
clearly glowing cyan crystal veins, steady and bright in the larger cracks, a few pale gold
veins among them.
```

## T2 深渊 · 渡暮（渗度 4-5）——"彼岸全貌"

天空段：
```
deep space of near-black indigo drowned in rich violet; a dense field of stars, layers of deep
violet and dim magenta nebula banks glowing softly across the whole sky; the colossal broken
ring gate dominates the horizon, large and close, its rim traced with glowing cyan-gold crystal
light, the space inside the ring a slowly swirling dim violet vortex; several small dark alien
ship silhouettes drifting near it.
```
晶脉段：
```
a full network of glowing cyan and pale gold crystal veins blazing through every crack, bright
and alive, the broken edges of the platform rimmed with crystal light, larger shattered rock
chunks floating below.
```

---

## 验收要点（出图后人工/judge 过滤）

1. 浮陆地面带必须占画面下部 ~25-30% 且顶面平直连续（车道约定）
2. 无人物/生物/文字/UI；无规则网格（程序化格线要叠上去，底图不能自带格线）
3. 三档星点密度/星云浓度/晶脉亮度/门环存在感必须单调递增
4. 色板不越界：近黑蓝靛底 + 青紫 + 淡金，无绿色地形/亮蓝天/暖阳
