# 缺失卡牌图标 AI 生图需求清单（8 张）

**版本：** v1.0 | 2026-06-17
**对齐：** `docs/card_icon_manifest_100_agent_prompts.md` 统一技术约束
**规格：** 半写实硬表面、**严格正侧视**、**朝左**、**#00FF00 绿幕** → 抠图后 512×512 透明 PNG
**输出目录：** `assets/card_icons/`

## 统一技术约束（每条 prompt 均需包含）

- 正侧视 `true profile side view`，正交投影
- **朝左**（车头/炮口/正面在画面左侧）
- 半写实军事硬表面，铆钉/磨损/分件
- 纯色绿幕 `#00FF00`，无地面无场景
- 512×512，无文字无水印

---

## 1) ww1_rolls — 罗尔斯装甲车

**时代：** 一战(era=0) | **兵种：** 装甲车(combat_kind=1, ARMOR)
**武器：** 57mm/75mm坦克炮 + 14.5mm车载机枪
**战力：** 45 | **HP：** 180

**说明：** 一战时期英国罗尔斯·罗伊斯装甲车，轮式底盘，车顶旋转机枪塔，铆接装甲车身。

**English prompt:**
```
WWI Rolls-Royce armored car, true profile side view, orthographic projection, facing left, riveted steel armor body, four spoked wheels, rotating machine gun turret on top with mounted heavy machine gun, dull khaki and olive drab military paint, weathered metal with rust spots and rivets, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark
```
**Negative:** `text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right`

---

## 2) ww1_77mm — 77mm野战炮

**时代：** 一战(era=0) | **兵种：** 支援/火炮(combat_kind=2, SUPPORT)
**武器：** 81mm/105mm火炮（曲射）
**战力：** 23 | **HP：** 60

**说明：** 一战德制 77mm FK 96 野战炮，带炮盾的牵引式火炮，木质炮轮，分叉炮架。

**English prompt:**
```
WWI German 77mm FK 96 field gun artillery piece, true profile side view, orthographic projection, facing left (barrel pointing left), long thin artillery barrel with muzzle brake, angled steel gun shield, wooden spoked wheels, split trail carriage, dull gray-green military paint, weathered metal, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark
```
**Negative:** `text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, crew, soldiers`

---

## 3) ww1_cavalry — 骑兵斥候

**时代：** 一战(era=0) | **兵种：** 轻装/步兵(combat_kind=0, LIGHT)
**武器：** 骑兵卡宾枪/马刀
**战力：** 15 | **HP：** 85

**说明：** 一战骑兵斥候，骑马，手持卡宾枪和马刀，穿着军装。注意：这是唯一的人员+坐骑单位。

**English prompt:**
```
WWI cavalry scout on horseback, true profile side view, orthographic projection, facing left, rider in khaki military tunic and peaked cap holding cavalry carbine rifle and sheathed saber, brown war horse in full gallop pose, leather saddle and equipment, semi-realistic military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark
```
**Negative:** `text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right`

---

## 4) ww1_engineer — 工兵班

**时代：** 一战(era=0) | **兵种：** 支援(combat_kind=2, SUPPORT)
**武器：** 迫击炮/野战炮
**战力：** 20 | **HP：** 90

**说明：** 一战工兵班组，含小型迫击炮和工程工具，以装备为主体展示（避免画多个人物）。

**English prompt:**
```
WWI combat engineer squad equipment, true profile side view, orthographic projection, facing left, small Stokes mortar on ground mount with ammo boxes, engineering tools (shovel, pickaxe, barbed wire roll), sandbags, steel helmets stacked, dull khaki and olive equipment, weathered metal and wood, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark
```
**Negative:** `text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, individual soldiers`

---

## 5) ww2_tiger — 虎式坦克

**时代：** 二战(era=1) | **兵种：** 装甲(combat_kind=1, ARMOR)
**武器：** 88mm主炮（游戏中用"57mm/75mm坦克炮"+"122mm主炮"表示多档火力）
**战力：** 180 | **HP：** 480

**说明：** 二战德国虎I重型坦克（Tiger I），标志性的箱式装甲车身，88mm KwK 36 L/56 主炮，交错负重轮。注意不要画成虎王(King Tiger)。

**English prompt:**
```
WWII German Tiger I heavy tank, true profile side view, orthographic projection, facing left (turret and gun barrel pointing left), box-like welded steel hull armor, long 88mm KwK 36 gun barrel with muzzle brake, interleaved road wheels with track, angular turret with cupola, dunkelgelb dark yellow base with brown and green camouflage stripes, Zimmerit anti-magnetic coating texture, weathered metal with chips, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark
```
**Negative:** `text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, King Tiger, Tiger II, Porsche turret, Schmalturm`

---

## 6) mod_technical — 武装皮卡

**时代：** 现代(era=3) | **兵种：** 轻装(combat_kind=0, LIGHT)
**武器：** AK-47突击步枪 + RPG-7火箭筒 + 便携式防空导弹
**战力：** 280 | **HP：** 250

**说明：** 现代非正规武装的武装皮卡（Technical），车斗上架设重机枪/火箭筒，民用皮卡底盘。

**English prompt:**
```
modern technical armed pickup truck, true profile side view, orthographic projection, facing left, civilian Toyota Hilux pickup truck chassis, mounted heavy machine gun (DShK) on pedestal in truck bed, RPG launcher rack, rugged off-road tires, sun-bleached white and beige paint with rust, irregular militia aesthetic with welded makeshift gun mount, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark
```
**Negative:** `text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, military APC, armored vehicle`

---

## 7) mod_m1a2sep — M1A2 SEP

**时代：** 现代(era=3) | **兵种：** 装甲(combat_kind=1, ARMOR)
**武器：** 120mm M256滑膛炮（游戏中标注"105mm主炮"+"双联装电磁炮"）+ CROWS武器站
**战力：** 960 | **HP：** 1250

**说明：** 现代美国 M1A2 SEP Abrams 主战坦克，带 TUSK 城市战套件、CROWS 遥控武器站、反应装甲块。注意与基础型 mod_m1a2 的区别——SEP 有更明显的附加电子设备和反应装甲。

**English prompt:**
```
modern US M1A2 SEP Abrams main battle tank, true profile side view, orthographic projection, facing left (turret and gun barrel pointing left), 120mm M256 smoothbore gun barrel with bore evacuator, CROWS II remote weapon station on turret roof, explosive reactive armor blocks on hull sides, TUSK urban survival kit panels, commander independent thermal viewer, desert tan CARC paint, weathered metal with dust, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark
```
**Negative:** `text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, basic M1A2 without SEP upgrades, Leopard tank`

---

## 8) fut_nexus — 虚空领主

**时代：** 近未来(era=4) | **兵种：** 装甲(combat_kind=1, ARMOR)
**武器：** 重型等离子加农炮 + 40mm榴弹 + 防空武器
**战力：** 1590 | **HP：** 2200

**说明：** 近未来科幻超级坦克，Boss 级单位。悬浮底盘或多足结构，等离子主炮，能量护盾发生器，深色金属+蓝紫色能量辉光。

**English prompt:**
```
futuristic sci-fi super heavy hover tank boss unit, true profile side view, orthographic projection, facing left (main cannon pointing left), massive dual heavy plasma cannon barrels with blue-purple energy glow, hovering chassis with no wheels, energy shield emitters emitting translucent hexagonal barrier, 40mm grenade auto-cannon, glowing cyan reactor core vents, dark gunmetal armor plates with luminous energy lines, imposing scale, semi-realistic hard-surface sci-fi military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark
```
**Negative:** `text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, conventional tank treads, wheels, medieval, organic alien biomass`

---

## 部署说明

1. 用上述 English prompt 在 AI 生图工具（Cursor Agent / Nano Banana / 其他）中生成图片
2. 每张生图后用绿幕抠图（#00FF00 → 透明），输出 512×512 PNG
3. 文件名严格按 card_id 命名，放入 `assets/card_icons/`：
   - `ww1_rolls.png`
   - `ww1_77mm.png`
   - `ww1_cavalry.png`
   - `ww1_engineer.png`
   - `ww2_tiger.png`
   - `mod_technical.png`
   - `mod_m1a2sep.png`
   - `fut_nexus.png`
4. 放入后无需改代码——`UiAssetLoader` 会自动按 `card_id + ".png"` 匹配
5. 若暂时无法生图，可先用 `mod_m1a2.png` 复制为 `mod_m1a2sep.png` 作为临时占位
