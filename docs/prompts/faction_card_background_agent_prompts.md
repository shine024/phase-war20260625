# 势力卡面底图 Agent 生图提示词（8 张）

**版本：** v1.0 | 2026-05-21  
**规格：** **500×800 像素，严格 5:8 竖图**（与背包槽 `50×80`、卡框一致），不透明 RGB  
**生图画布：** 必须竖版 — 推荐 **500×800** 或 **640×1024**；**禁止** 横图（如 1536×1024）再拉伸  
**风格：** 科幻企业纹章 / 军旗 — **插画级细节**，非扁平程序化几何  
**路径：** `assets/cards/backgrounds/bg_<faction_id>.png`

## 统一约束（每条 prompt 已内嵌）

- 竖版卡牌底图，**exact portrait 500×800 pixels, aspect ratio 5:8 vertical, NOT landscape**
- 上半中央 35% 略留白、纹理更柔（给立绘叠层）
- 下半为华丽盾徽 / 绶带 / 旗面主体
- 纳米印制电路纹理 + 超空间深灰蓝氛围 + 相位微光
- 高细节金属镶边、浮雕、织纹，**禁止**简笔画/纯 flat vector

## 负面提示词（通用）

```text
text, letters, words, watermark, logo text, unit, tank, mech, character, face, photorealistic photo, 3D render, low detail, flat vector, simple geometric, clip art, emoji, blurry, jpeg artifacts, white background, transparent, empty center hole
```

---

### 1) bg_neutral — 中立

**势力：** 无归属 / 缴获默认  
**输出：** `assets/cards/backgrounds/bg_neutral.png`

```text
Portrait vertical game card background panel 5:8 ratio, sci-fi neutral faction crest illustration, highly detailed painted 2D game art NOT flat vector. Slate blue-grey metallic field with subtle hex nano-circuit diaper pattern and faint hyperspace void depth. Large embossed neutral heater shield in lower half with simple hex lattice charge, silver fimbriation and holographic rim light. Top ornate blank banner ribbon with metal trim (NO text). Bottom decorative scroll with phase glow edge. Soft laurel filigree, muted steel and pale blue accents, upper center third kept softer and less busy for unit sprite overlay. Luxurious TCG corporate sigil style, semi-realistic metallic rendering, rich texture, no characters no vehicles no text.
```

---

### 2) bg_iron_wall_corp — 钢壁防务

**输出：** `assets/cards/backgrounds/bg_iron_wall_corp.png`

```text
Portrait vertical game card background 5:8, sci-fi Iron Wall defense corporation heraldic panel, richly illustrated NOT simple shapes. Gunmetal silver and steel blue palette. Large embossed heater shield with horizontal plate armor divisions, steel cross charge, riveted border, battle-worn nano-print seams glowing faint cyan. Top military banner with blank scroll (NO text), side pennant flags silver-grey. Bottom ornate ribbon with phase barrier glow. Background: armored plate texture and hyperspace dim light streaks. Upper center softer for unit overlay. Heavy metallic filigree, defense megacorp crest, high detail illustration.
```

---

### 3) bg_nova_arms — 新星兵工

**输出：** `assets/cards/backgrounds/bg_nova_arms.png`

```text
Portrait vertical game card background 5:8, sci-fi Nova Arms weapons corporation heraldic panel, ornate illustrated style. Burnt orange, ember red, dark steel palette. Large shield with orange chief division, rising angular flame charge over crossed sci-fi rifle silhouettes embossed in metal, aggressive saltire accents. Top war banner with blank metallic trim NO text. Sparks and phase fire glow at edges. Background diagonal strike texture and nano-weapon blueprint ghost lines. Upper center kept cleaner for unit sprite. Fiery arms megacorp crest, rich painted detail, NOT flat icon.
```

---

### 4) bg_aether_dynamics — 以太动力

**输出：** `assets/cards/backgrounds/bg_aether_dynamics.png`

```text
Portrait vertical game card background 5:8, sci-fi Aether Dynamics scholar-industrial heraldic panel. Teal cyan and charcoal palette with bright phase turbine glow. Large round-tech shield with five-blade engine turbine rose charge, orbiting energy ring nodes, knowledge-to-power symbolism. Top sleek banner NO text, circuit filigree borders. Background: precise nano-print grid and soft hyperspace depth. Bottom ribbon with cyan holographic edge. Upper center softer for unit overlay. Elegant technical crest, high detail metallic illustration.
```

---

### 5) bg_quantum_logistics — 量子后勤

**输出：** `assets/cards/backgrounds/bg_quantum_logistics.png`

```text
Portrait vertical game card background 5:8, sci-fi Quantum Logistics merchant corporation heraldic panel. Deep purple, teal cyan, navy palette. Quarterly divided shield with cargo chevron, glowing circuit-edged crate charge, data stream lines to corner nodes representing hyperspace logistics network. Top trade banner blank NO text, side flags purple-teal. Background woven data mesh texture. Bottom scroll with spatial-fold glow accents. Upper center less busy for unit sprite. Opulent logistics megacorp crest, rich illustrated detail.
```

---

### 6) bg_helix_recon — 螺旋侦察

**输出：** `assets/cards/backgrounds/bg_helix_recon.png`

```text
Portrait vertical game card background 5:8, sci-fi Helix Recon intelligence corporation heraldic panel. Vibrant recon green and dark slate palette. Shield with bend division, double-helix charge intertwined with radar sweep arcs and scanning ring filigree, sharp information eye motif at center. Top recon banner NO text, side pennants green. Background subtle scan-line and spiral dot texture. Bottom ribbon with green phase pulse edge. Upper center softer for unit overlay. Sleek spy-tech crest, detailed illustration NOT flat.
```

---

### 7) bg_void_research — 虚空相位

**输出：** `assets/cards/backgrounds/bg_void_research.png`

```text
Portrait vertical game card background 5:8, sci-fi Void Research forbidden science heraldic panel. Dark violet, black, magenta palette with purple phase leak glow. Shield with void saltire cracks, central vertical slit eye charge, dimensional fracture filigree radiating outward. Top mysterious banner NO text, jagged holographic trim. Background deep void texture with faint abyss light. Bottom scroll with forbidden energy edge glow. Upper center calmer for unit overlay. Occult research institute crest, ornate dark illustration, high detail.
```

---

### 8) bg_frontier_union — 边境联合

**输出：** `assets/cards/backgrounds/bg_frontier_union.png`

```text
Portrait vertical game card background 5:8, sci-fi Frontier Union coalition heraldic panel. Gold, olive drab, warm bronze palette. Multi-point union star charge on shield with overlapping diverse geometric cantons, flowing banner flag draped below star, patchwork alliance symbolism. Top coalition banner NO text, side mixed-color pennants. Background warm fabric-weave and hyperspace light. Bottom ornate scroll gold trim. Upper center softer for unit overlay. Idealist alliance crest, rich heraldic illustration with sci-fi materials.
```

---

## 部署

生图后保存至 `assets/cards/backgrounds_choice/agent_heraldic/`，确认满意再：

```powershell
Copy-Item assets\cards\backgrounds_choice\agent_heraldic\*.png assets\cards\backgrounds\ -Force
```

Godot 中对 `assets/cards/backgrounds/` Reimport。
