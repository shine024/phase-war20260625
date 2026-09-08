# Phase War 风格宪法（STYLE_BIBLE）

> 唯一权威源。任何生图（agnes/Flow）与资产修改动笔前先查本文档。
> 挑定方向：〔B 末世工业·荒芜史诗 为主锚，缝合 D 的青色 rim-light 恒定规则〕
> 依据：`docs/统一化/风格方向候选.md`（复审定稿 75604e2）· `resources/design_tokens.gd`（UI 色板唯一权威）· `tools/_agnes_image_api.md`（生图行为三轮实测）。2026-09-08 制定。
> 适用资产域：卡图立绘 356 张（白底→透明管线，占 96%，最大战场）· 战场背景 · 序章漫画 11 格 · 相位仪徽章（1024×1024 深底纹章，6 阵营族）· 基地房间三图管线（5 时代 × 3 图）· 后续一切新增生图。
> 串即法规：凡标〔卡图/场景/徽章〕的 prompt 片段只在其标注域内拼装，跨域拼装即违规（天空句进卡图串=灰天空=泛洪报废，此类事故见禁则章）。
> 参考系：《Frostpunk》冷灰蓝雪原 × 暖橙炉火 ·《This War of Mine》炭笔渲染 ·《FTL》宏大叙事插画。

## 一、色板（主色/辅色/点缀/禁用色，含 hex 值）

**与 UI token 的关系**：下表凡标「UI 共用」的色，数值以 `resources/design_tokens.gd` 对应常量为唯一权威（括注常量名），token 改动时本表必须同步修订；标「资产专用」的色只存在于生图 prompt 与调色 LUT，不进 UI 代码。资产层复用 UI 共用色的目的：画面固有色沉入 UI 底色、点缀色与 UI 强调色同一色环——卡图与 UI 从"两张皮"变成同一张皮。

### 主色（基调层，画面面积 60%~75%）

| 色 | hex | 用途域 | 用法 |
|----|-----|--------|------|
| 深空黑 | #0A121F | UI 共用 `COLOR_BG` | 一切深底呈现层（UI 底 / 徽章底 / 漫画夜空）；透明底卡图叠在其上，"背景"即此色 |
| 深灰蓝 | #2B3A4A | 资产专用 | 主体固有色基调：装甲板、钢构、雪原暗部、徽章底纹；允许一档明度带浮动（暗端 ≈#22303E，亮端 ≈#33455A） |
| 冷灰 | #808CA6 | UI 共用 `COLOR_SLATE_A80` | 次级金属面、雪面亮部、中景过渡（更亮一档 #99A8C7 = `COLOR_TEXT_DIM`） |

### 辅色（明度阶梯层，20%~30%——只做主色族的深浅，不引入新色相）

| 色 | hex | 用途域 | 用法 |
|----|-----|--------|------|
| 深渊黑 | #060912 | UI 共用 `COLOR_VOID` | 场景最暗部、门体暗面（比 UI 底更深一档的景深色） |
| 面板灰蓝 | #262B40 | UI 共用 `COLOR_PANEL` | 场景中景钢构、室内墙面中间调 |
| 冰天青 | #99D9FF | UI 共用 `COLOR_ICE_TEXT` | 雪面反光、阴天天空亮部；兼历史写实系卡图 rim 色（见第二章条件树） |

### 点缀色（对撞层，总面积 ≤15%——一图恰好一种暖色，紫青按语义取用）

| 色 | hex | 用途域 | 用法 |
|----|-----|--------|------|
| 暖橙 | #E69919 | UI 共用 `COLOR_ENERGY` | 唯一暖叙事光源：炉火 / 车灯 / 油灯 / 枪口焰 |
| 琥珀 | #F59E0B | UI 共用 `COLOR_AMBER` | 暖光源近核提亮档（同一橙谱系，不另起新暖色相；再亮一档 #FBBF24 = `COLOR_AMBER_SOFT`） |
| 黑门紫 | #8C59F5 | UI 共用 `COLOR_ACCENT_PURPLE` | 专属黑门 / 相位异常 / 生灵语义；兼 xeno 系卡图 rim（见第二章）——禁做装饰紫 |
| 霓虹青 | #00F0FF | UI 共用 `COLOR_ACCENT_CYAN` | 科幻系卡图 rim 与能量要素发光；UI 层恒定强调色 |

### 饱和度与对撞公式

- 全图饱和度中低（25%~40%），唯暖光源近核与紫晕允许高饱和小面积。
- **一图一冷暖对撞**：冷灰蓝世界 × 一点暖橙（现状序章漫画 b6"暖橙火光 × 冷紫门光"即合规样板）；暖色总面积 ≤15%。
- 时代差不换色相：五个时代的卡图共用本色板，时代识别度全部由装备细节与剪形表达（era 词插槽见第四章）。

### 禁用色（封闭清单）

| 禁用 | 为什么禁 |
|------|---------|
| 大面积高饱和绿（#22C55E 级亮绿 >10% 面积） | 不在"冷灰蓝 × 暖橙 × 紫"色环内；绿在 UI 是血量/提升语义（`COLOR_HEALTH` / `COLOR_GREEN_BRIGHT`），资产大绿块与 UI 语义抢戏；末世冷调世界里亮绿=植被生机=氛围破功。低饱和军械橄榄（军绿 / 卡其压冷后）视为主色合规变体，不在此列（橄榄是异色相，作合规变体处理，非明度带延伸） |
| 高饱和正红大面积（血红 / 红旗主导画面） | 红是 UI `COLOR_DANGER` 语义专属；资产暖点缀只走橙琥珀谱系；大面积红还会把 agnes 拉向血腥 gore 场景暗示 |
| 暖黄 / 卡其黄作主调（>30% 面积） | 违反"暖点缀 ≤15%"对撞公式——现状 ww1 步兵卡其黄高饱和暖调即整改对象（压冷归队） |
| 粉 / 品红 / 荧光黄等无 token 色 | 无 UI 锚点、无叙事语义，进来就是杂色——拼凑感回潮 |
| 大面积纯黑 #000000 / 纯白 #FFFFFF 色块 | 黑必须黑得发蓝（沉向 #0A121F / #060912）才与 UI 底同环，纯黑死块还违反暗部保细节规则；纯白大面积与白底转透明管线相撞（泛洪误抠风险，另见第五章第 12 条） |

### 色板章 prompt 片段（按域取用，可直接粘贴）

〔场景〕

```
muted cold palette of deep blue-grey steel and cold grey, one small warm
ember-orange accent, flat overcast sky
```

〔卡图〕基色句

```
muted cold palette of deep blue-grey steel and cold grey
```

〔卡图〕暖缀条件句——**仅当单位自带暖源时**写入对应载体词；无自然暖源则整句省略（空写暖缀=模型自造光源，白底上必出杂物）

```
plus one small warm amber glow from (muzzle flash / headlights / exhaust embers)
```

**hex 使用口径**：hex 未在 agnes 实测中验证过解析能力——串内一律以色名为准，hex 只作人读注释（deep blue-grey steel=#2B3A4A · cold grey=#808CA6 · ember-orange=#E69919）；批次④首跑做带/不带 hex 的 A/B 小样再定（附录一标定清单①）。

## 二、光线规则（主光源方向/对比度基调/氛围光）

### 基调（全资产通用）

- **环境主光：阴天漫射顶光**（overcast diffused light from above）——无硬直射阴影、无方向性投影；唯一的方向性光来自"叙事光源"。
- **叙事光源：一图恰好一个**——炉火 / 车灯 / 黑门晕 / 屏幕辉光，自带体积光晕（场景串内词，见下），它就是那一笔暖橙或紫晕的来源。
- 对比度中低：明暗层次投资在"主体 vs 灰蓝环境"，不做伦勃朗 chiaroscuro；**暗部近黑但不糊，保留 10%~15% 亮度细节**。
- 大气透视（仅场景）：远景沉入灰蓝雾（串词见下）。

### rim-light 缝合规则（D 规则收编为 B 的卡图细则，逐条可判定）

```
若 资产 = 卡图立绘（透明底精灵）：
    rim 恒定开——背光侧轮廓一道极窄冷 rim。
    这道 rim 是内容层与 UI 层的缝合线，不因单位时代而省略。

    单位族三档判定（自上而下，命中即停）：
    ① 外观写实度——外观为历史写实装备/载具者，无论前缀，一律归历史写实系。
       口径与候选文档 D 节对齐：vis 前缀中的写实系（写实坦克/步兵/载具，
       约 125 张 ×2 阵营）归历史写实系，不因 vis 前缀划入科幻系——
       写实坦克挂霓虹青 rim 与禁则 11 自怼。
       → rim 用冰天青 #99D9FF 档：极窄、无辉光，读作"阴天天光"而非能量。
    ② 前缀族——ww1/ww2/cold/mod 归历史写实系（同①档）；fe/fut/drop 及
       科幻外观单位（能量武器 / 装甲管线 / 舰体）归科幻系。
       → 科幻系 rim 用霓虹青 #00F0FF 档：允许轻微辉光，读作"相位辉光"，
         与 UI 青同语言；辉光只落在能量要素上，不做整圈 halo。
    ③ 发光要素——单位本体带黑门 / 生灵 / 相位异常语义（vis_xeno 异形系）。
       → rim 用黑门紫 #8C59F5 档：读作"黑门侵蚀"。
    兜底：三条都无法判定时，默认历史写实系冰天青档，并把该单位登记进
    人工复核清单——宁可 rim 保守，不可档位错挂。

    附则：rim 只勾背光侧一道，不整圈描光；装甲本体不发光——
    单位发光只出现在能量/相位/信息要素上（炮口、能量管线、屏幕），
    全发光 = 全一样 = 识别度归零。

    批次④动笔前，先按此优先级跑单位族全量标注/分档脚本，产出三档名单
    + 人工复核清单，名单定稿后才开始生图/调色（流程见附录一）。

若 资产 = 场景图（战场背景/雪原演出/基地房间/漫画格）：
    rim 不开——冷由阴天漫射与灰蓝雾表达，暖由唯一叙事光源表达；
    场景里画青 rim 会把实景变成"贴在 UI 上的一张图"。

若 资产 = 相位仪徽章：
    无光效 rim——青色以发光勾线形式出现（现状纹章风全量保留，新徽章照此）。
    徽章域特例注（2026-09-08 质量审查裁决）：本条"无光效 rim"指徽章不吃卡图
    rim 三档——rim 三档只辖卡图域；徽章是 UI 发光体域，自身辉光
    合法且是域语言，现图实况即霓虹辉光勾线（存量 189 张族图全为霓虹系），
    新徽章听现图、域级特例维持系列统一（锚段与发光判据见第六章 6.4）。
```

（历史写实系分支即现状 ww1 步兵青蓝轮廓光的"雏形收编"；三档 rim 色见第一章点缀色表。）

### 光线章 prompt 片段

〔卡图〕主光句（全族通用）

```
overcast diffused lighting
```

〔卡图〕rim 句——按单位族三档换词（判定见上方条件树）：

```
历史写实系：one narrow cool sky-blue rim light along the back edge
科幻系：    one narrow cyan rim light along the back edge, faint glow
            limited to emissive parts
xeno 系：   one narrow faint violet rim light along the back edge
```

〔场景〕

```
single warm ember light source in a cold blue-grey world, volumetric glow
around the light source, aerial perspective, distant objects fade into
blue-grey haze
```

（`volumetric glow` 为**场景专用**——白底卡图上的软辉光会糊掉剪影边缘，与禁则 6 同理自怼。）

## 三、笔触与媒介（写实度/颗粒感/描边规则）

### 写实度标尺（1~5，目标档 = 4）

| 档 | 描述 | 判定 |
|----|------|------|
| 1 | 卡通平涂 / 矢量 | 禁 |
| 2 | 半写实 + 勾边（现状 ww1 步兵、fut_swarm 球舰） | 禁——重生对象 |
| 3 | 半写实厚涂无勾边 | 合格下限 |
| **4** | **厚重数字厚涂 + 全图颗粒**（thick painterly digital illustration + film grain） | **本宪法目标档** |
| 5 | 照片级写实 | 禁用于新生成（存量处置见附录一） |

### 颗粒感（具体到可执行）

- 场景：生图串内写 `film grain texture`——密度近似 ISO 800 胶片、粗细一档、覆盖全部画面内容。
- 卡图：**grain 词不进卡图串**——一律后处理叠加（flood_white_to_alpha 裁出主体后加噪，透明区不存噪点）；白底上生成颗粒会先污染泛洪边缘。泛洪容差 × 颗粒密度在批次④首跑标定（附录一标定清单②）。
- 颗粒家族三成员：胶片噪点（卡图后处理 / 场景串词）、版画排线刻线（漫画格；现状 vis_player_001 坦克的"刻线+点状肌理"同族可留）、硬边金属刮擦（机械表面）。

### 软硬对撞

烟雾 = 柔边喷枪（`soft airbrush smoke`，**场景串专用**——白底上喷烟雾=毛边+阻断泛洪），金属 = 硬边刮擦（`hard-edge scuffed steel`，措辞批次④首跑小样验证）——软硬笔触对撞是"工业温度感"的来源，只在有背景的场景里成立，卡图串不带烟雾词。

### 描边规则（透明底立绘）

- **无轮廓描边**：剪影由色块明度差 + rim 光定义，不由线条定义。
- 剪影边缘必须干净利落——透明底管线（flood_white_to_alpha 泛洪 + 脚锚连通域扫描）依赖干净边缘，毛边 / 雾边都不行。
- 本条只以规范条文存在：**`no outlines / no cel shading` 是概念否定词，严禁进 prompt 串**（反激活效应，见禁则 2）——串内用正面表述"以明度对比与 rim 光定义剪影"（见下方卡图串）。

### 媒介分资产

- 卡图：厚涂 + 后处理颗粒，无描边。
- 场景 / 漫画：厚涂 + 版画排线 + 颗粒（序章漫画 11 格已合规，零换血样板）。
- 相位仪徽章：扁平矢量纹章风（深灰蓝底 + 青勾线 + 放射底纹）——**不套厚涂**，徽章是纹章语言不是插画语言。（2026-09-08 质量审查裁决修订：辉光载体听现图霓虹系——域级媒介特例见章二徽章注与 6.4；"放射底纹"描述与现图不符，自此以 6.4 锚段为准。）
- 基地房间：厚涂 + 颗粒（三图管线 v3 prompt 骨架不变，换本章场景串风格词重跑）。

### 措辞红线

写 `oil-stained steel` 可以；写 `dusty / grimy / gritty / battle-worn` 会被 agnes 激活成垃圾满地（机制见第五章第 5 条）——质感词要落在"材质"上，不落在"破败"上。

### 笔触章 prompt 片段

〔卡图〕

```
thick painterly illustration, clean painterly silhouettes defined by value
contrast and a narrow rim light, smooth blended brushwork, hard-edge steel
surfaces
```

〔场景〕

```
thick painterly illustration, film grain texture, soft airbrush smoke against
hard-edge scuffed steel, clean painterly silhouettes defined by value contrast
```

（`scuffed` 首跑小样验证——若带出垃圾满地，降级为 `brushed steel / matte steel`，见附录一标定清单③。）

## 四、构图规则（卡图视平线/主体占比/背景虚化层级）

### 卡图立绘（356 张主战场；白底生成 → flood_white_to_alpha → 镜像配对 → 脚锚 → grain 后处理）

- **视平线**：卡图无画面内视平线——无地面无天空（`clean pure white background with NO ground`，结构性白名单词），视角取**平视全身侧面**（eye-level full body side view）；`perspective view` 是结构性排除词。超大型单位（巨舰 / 球舰）允许微仰视——串内写 `slight low angle`，幅度以不触发 perspective view 排除为限（微仰是机位倾斜，不是透视变形）。
- **朝向**：生图串一律写 `facing right`，**生成即朝右**；enemy 侧由 FLIP_LEFT_RIGHT 镜像产出，player 侧直出——同 ID 配对 player 朝右 / enemy 朝左。构图必须**翻转安全**（画面内禁文字 / 字母 / 带字旗帜徽标 / 单侧不对称符号）。
- **主体占比**：约 65%~80%；四周留 8%~15% 白边安全距（泛洪 + 裁切适配需要）；脚部完整落在画面内不裁切（白色椭圆脚锚是 `generate_card_foot_anchors.py` 后处理产物，不进生图）。
- **生成尺寸**：agnes 实测 1152x768（≈3:2）可用；卡图管线终态 512×512 透明底——1152x768 出图 → flood_white_to_alpha → 裁切适配 → 脚部锚 → grain 后处理叠加。
- **构图自由度**（透明底约束下投在哪）：全部投资在**姿态与装备细节**——待发 / 缓行静姿为主、装备完整可见；战斗动感由游戏内 VFX 承担，卡图是识别层不是动作帧。
- **背景虚化层级**：不存在——无背景即无层级，空间感由主体自身的明度阶梯（第一章辅色层）表达。

### 卡图构图片段——按单位族三档变体（era 词插槽置于句首，例 `WWII` / `near-future`）

〔卡图·历史写实系〕

```
WWII single military unit or vehicle, full body, eye-level side view, facing
right, historically accurate equipment detail, unit fills about three
quarters of the frame with even white margins, clean pure white background
with NO ground
```

〔卡图·科幻系〕

```
single hard-surface sci-fi unit or vehicle, full body, eye-level side view,
facing right, sleek angular panel lines, unit fills about three quarters of
the frame with even white margins, clean pure white background with NO ground
```

〔卡图·xeno 系〕

```
single alien creature, full body, eye-level side view, facing right, unit
fills about three quarters of the frame with even white margins, clean pure
white background with NO ground
```

（三档变体拼装时，rim 句按第二章条件树取对应档词。）

### 场景图（战场背景 / 雪原演出 / 基地房间 / 漫画格）

- **空旷公式**：荒芜与史诗感 = 空旷构图 + 比例差 + 单一暖光源，三者缺一不可；画面有机械 / 建筑时至少安排一处"小人物 vs 巨构"对比（视觉尺寸比 ≥1:10）。
- **视平线**：地平线压低（下 1/3 附近），天空占 40%~60%，天空必须是平坦阴天（禁戏剧云）。
- **背景虚化层级**：景深用**大气雾三段**表达——前景实（主体 / 结构）、中景灰蓝雾、远景沉入雾中；禁摄影镜头虚化（painterly 语言里没有 bokeh）。
- **漫画格**：一格一个视觉焦点（b6"火光焦点"即样板）。
- **徽章**：1024×1024 对称纹章构图（以 6.4 锚段为准）。

〔场景〕构图串

```
vast empty composition, low horizon, flat overcast sky, monumental lone
industrial structure, one tiny human silhouette against huge machinery
```

〔场景·雪原专用〕锁意象（正面意象锁死，不写 no trash）

```
wind-carved snow fields, flat overcast sky, distant colossal black monolith
with faint violet halo
```

## 五、禁则（与挑定方向冲突的常见 AI 生图癖好清单）

封闭清单，共 12 条；每条附一句"为什么"。前 3 条为全 prompt 串共用的管线铁律（源自风格方向候选 §0）。

**共用管线三铁律**

1. 卡图串 backdrop 只写 `clean pure white background with NO ground`；黑底 / 深底 / studio backdrop 字样不进立绘串——管线是白底生成 + flood_white_to_alpha 转透明，深底字样让泛洪失效、抠图报废。
2. 负面词栏只写结构性排除 `text / perspective view / frame / ground / ceiling`——agnes 实测负面概念词反激活（"不要大象"效应），写"不要 X"反而把 X 画进画面；铁律 1 的 `NO ground` 与室内图的 `ceiling` 同属结构性白名单，其余概念词（含 `no outlines` 这类风格否定）一律不得入负面栏。
3. enemy 侧由 FLIP_LEFT_RIGHT 镜像产出（生成一律朝右）——画面内禁一切文字 / 字母 / 带字旗帜徽标 / 单侧不对称符号，因为翻转即穿帮（`text` 结构性排除同时服务于此）。

**风格词陷阱（agnes 三轮实测）**

4. 禁 `wasteland / desolate / bleak / ruined / post-apocalyptic` 废墟字面词——风格词自带场景暗示，会把瓦砾垃圾画进画面；荒芜改由空旷构图 + 比例差 + 单一暖光源表达（第四章公式）。
5. 禁 `gritty / dusty / grimy / somber / battle-worn` 破败质感词（含 `dusty olive` 这类色板词前缀）——同上，连色板词里的 dusty 都有垃圾暗示；要质感写 `oil-stained steel`、`stylized, muted palette of dark grey-brown and olive green`。
6. 卡图立绘禁 `heavy atmospheric haze / volumetric fog / mist`——体积雾毁透明底剪影边缘（泛洪 + 脚锚扫描都依赖干净边缘）；氛围雾只进场景串。

**画面内容**

7. 卡图禁地面 / 投影 / 场景元素进入生图——脚锚是后处理产物，生图画了地面就毁抠图。
8. 竖起的屏幕 / 挂画内容必须显式限定：`screens showing ONLY simple abstract glowing patterns, plain color readouts and flat graphic symbols (never detailed pictures or scenes)`——不限定时模型会在屏幕里画乱七八糟的具象画。
9. 卡图禁赛璐璐勾边 / 卡通粗描边 / 矢量平涂——三档质感漂移正是拼凑感主源（现状 ww1 步兵、fut_swarm 即重生对象）；此判定只写在规范与分档脚本里，不写进串。
10. 禁每图多于一个叙事光源——"一图一冷暖对撞"是 B 方向的构图公式本体，多光源 = 情绪稀释 + 拼凑感回潮。
11. 历史写实系单位（ww1/ww2/cold/mod 及 vis 写实系，判定见第二章优先级①）禁内容科幻化改型（加能量管线 / 发光装甲 / 全息 HUD）——时代识别度是卡牌系统的核心信息量，统一感不能以抹平时代差为代价；历史写实系的"相位感"只允许来自冰天青 rim 档。
12. 卡图主体内禁贴剪影边缘的大片纯白色块——泛洪从边缘起抠，贴边白块有被误抠成透明的风险（白只做高光点，不做面）。

---

## 六、资产类别 prompt 锚模板（拿来即用）

> 本章职责：把一~五章片段按资产类别组装成固定模板，**不发明新风格**——描述词优先原文取自既有章节片段；确需新增的词句（6.1 兵种主体句、6.2 时代基础段与环境修饰词表、6.4 徽章族写法）一律带〔域〕标注，并已逐条对照第五章禁则 12 条自检。与一~五章冲突时以一~五章为准。每类模板结构固定：基础锚段 → 变体段 → 行为适配 → 生成后流程 → 合规自检 5 问。

### 6.1 卡图（agnes 管线，512×512 透明底，356 张主战场）

**拼装顺序**（附录二口径固化，10 段串接、顺序不可换）：

| # | 段 | 取法 |
|---|----|------|
| 1 | era 插槽（句首） | 五时代词全表：`WWI` / `WWII` / `cold war era` / `modern` / `near-future`（记号与 6.2 时代基础段统一；第四章词插槽） |
| 2 | 单位族构图串头 | 第四章三档构图串选一（历史写实系/科幻系/xeno 系），档位按第二章判定链；**取至 even white margins 止**——串尾白底句不随取，白底句仅第 9 步收尾出现一次 |
| 3 | 兵种变体句 | 6.1.2 十三选一，拼在构图串头之后细化主体 |
| 4 | 主光句 | `overcast diffused lighting`（固定） |
| 5 | rim 句 | 第二章三档词，与第 2 步同档（判定链：写实度①→前缀族②→发光要素③→兜底冰天青+人工复核） |
| 6 | 基色句 | 第一章〔卡图〕基色句（固定） |
| 7 | 笔触串 | 第三章〔卡图〕串（固定） |
| 8 | 暖缀条件句 | 仅单位自带自然暖源时写入对应载体词，无源整句删除（第一章条件句） |
| 9 | 白底句 | `clean pure white background with NO ground`（固定收尾） |
| 10 | 负面栏 | `text, perspective view, frame, ground, ceiling`（固定，结构性白名单） |

**基础锚段**（第 4~7、9 步固定原文，逐字粘贴；rim 句按三档插入主光句之后）：

```
overcast diffused lighting, 〔rim 三档选一〕, muted cold palette of deep
blue-grey steel and cold grey, thick painterly illustration, clean painterly
silhouettes defined by value contrast and a narrow rim light, smooth blended
brushwork, hard-edge steel surfaces, clean pure white background with NO ground
```

rim 三档插入词（判定见第二章条件树）：

```
历史写实系：one narrow cool sky-blue rim light along the back edge
科幻系：    one narrow cyan rim light along the back edge, faint glow
            limited to emissive parts
xeno 系：   one narrow faint violet rim light along the back edge
```

负面栏（固定）：

```
text, perspective view, frame, ground, ceiling
```

**三个独立轴**：era（时代装备细节）× 兵种（6.1.2 主体句）× 单位族档（rim 词 + 构图串头）——默认独立、逐轴独立选词（两处显式例外见 6.1.2 表后注：科幻系装备词替换、隐身兵种 era 取值）；族档拿不准走第二章兜底（冰天青 + 登记人工复核清单）。

#### 6.1.2 按兵种变体段（〔卡图〕域新增，13 兵种语义——CombatKind+子类+模组系汇总，era 无关）

主体句拼在第 2 步构图串头之后；装备词只锁兵种剪形与姿态，时代敏感词一律让位给 era 插槽。

| 兵种 | 主体句（prompt-ready） | 注 |
|------|----------------------|-----|
| 步兵 | a single foot soldier with shouldered rifle, full field pack and helmet, calm ready stance | 姿态静不战斗（第四章：卡图是识别层不是动作帧） |
| 装甲 | a single tank with rotating turret and long main gun barrel, layered hull armor, wide track runs | |
| 空军 | a single aircraft with full wingspan and tail assembly visible, level flight attitude | 禁俯冲/翻滚/大坡度倾斜（会拉向 perspective view） |
| 支援 | a single support vehicle or field station with mast antennas and equipment racks | 车载屏幕必加第二章屏幕限定句（禁则 8） |
| 侦察 | a single light wheeled scout vehicle with slim low silhouette and raised optics mast, plain unmarked hull | 正面锁定 plain unmarked hull——旗帜/徽标类符号翻转穿帮（禁则 3），只禁不锁模型会自造徽标 |
| 炮兵 | a single artillery piece with long barrel at moderate elevation, recoil spades and ammunition racks | |
| 防空 | a single anti-air gun mount with barrels angled steeply upward | 火控雷达等时代件由 era 插槽给 |
| 工兵 | a single engineering vehicle with articulated crane arm and front dozer blade | |
| 航母 | a single aircraft carrier with flat flight deck and parked deck aircraft | 超大型单位允许 `slight low angle`（第四章） |
| 医疗 | a single field ambulance truck with stretcher loading hatch and roof vents, body painted in the same muted cold tones | 禁白车漆——贴边大片白撞禁则 12（泛洪误抠）且撞禁色白 |
| 隐身 | a single stealth aircraft with faceted angular panels and dark matte coating | 天然 mod/近未来，era 插槽相应取 |
| 堡垒 | a single massive fortified emplacement with embedded gun casemates and layered armor plates | 超大型单位允许 `slight low angle`（第四章） |
| 指挥 | a single command vehicle with clustered communication masts and open map-table hatch | 带数字屏时同加屏幕限定句 |

（科幻系拼装时，变体句里的时代敏感装备词替换为能量系等价物——rifle→energy rifle 一类——兵种剪形不变；历史写实系禁科幻化改型（禁则 11），判定按第二章优先级①。）

**agnes 行为适配**（源 `tools/_agnes_image_api.md` 三轮实测）：

- **正面意象锁死**：全部描述写"该画什么"（上表主体句均正面表述）；要干净背景就靠白底句本身，绝不写 no trash 类概念否定。
- **负面词只留结构性白名单**（第 10 步 5 词）。存量脚本 `tools/generate_missing_card_icons_11.py` 的 NO 词前缀 + 中文负面词堆叠为宪法前写法——复用脚本只保留 API 管线（key/轮换/输出到待生成审核目录），prompt 段一律按本章重拼。
- **质感词落材质不落破败**：`oil-stained steel` 可，dusty/gritty/grimy/battle-worn 禁（禁则 5）。
- **屏幕限定句**：装备带屏幕（雷达/指挥车）时加第二章禁则 8 原文整句。
- **hex 不进串**（第一章口径）；**grain 不进串**（第三章——白底上生成颗粒污染泛洪边缘，一律后处理）。

**生成后流程**（每张必走全链）：

1152×768 出图 → 人工审核（对照本节自检 5 问）→ flood_white_to_alpha 白底转透明 → 裁切适配 512×512（deploy 脚本 `fit_square` 现成实现——getbbox 依赖已透明才裁得准内容边界，顺序不可倒；内容 88% 占比为脚本终值，与第四章 65%~80% 主体占比分立：后者是生图构图要求、前者是部署缩放终态）→ 配对翻转 → `python tools/generate_card_foot_anchors.py`（铁律：新增卡图后必须重跑）→ grain 后处理叠加（附录一标定清单②）→ 新 png 导入用 `godot --headless --editor --quit`（`--import` 直跑崩）→ 备份铁律（重打包至 `F:\godot fair duet\_art_backup\`）→ 敌方卡复查页 `tools/enemy_card_review（敌方卡）.html` 浏览器打开复查。

> ⚠️ **翻转口径**：宪法第四章规定**生成一律朝右、player=直出、enemy=FLIP_LEFT_RIGHT 翻转版**；存量部署脚本模板 `deploy_card_icons_11.py` 翻转的是 player 版（旧口径：enemy 原图朝左，AGENTS.md 美术节）。两口径落点画面等价（player 朝右 / enemy 朝左），新批次一律按宪法口径执行——复用脚本模板时把翻转目标对调到 enemy 副本。

**合规自检 5 问**：

1. 朝向右？（`facing right` 在构图串头；enemy 由翻转产出，画面无单侧不对称符号）
2. 透明底合规？（白底句固定收尾；串内无雾/软烟雾词污染剪影、无泛辉光词——科幻系 rim 句的 emissive 限定辉光除外；主体无贴剪影边缘的大白块）
3. 色板内？（冷灰蓝基调 + 至多一处自然暖缀（无源删句）；无禁用色；无 hex 进串）
4. 笔触合规？（厚涂档 4 串原文逐字在位；grain 未进串、只走后处理；无勾边/卡通词）
5. 无文字水印？（负面栏 text 在位；画面内无文字/字母/带字旗帜徽标——翻转安全）

### 6.2 战场背景（agnes，时代×环境矩阵）

**组装法**：不穷举 5×全环境组合——「时代基础段 + 环境修饰词表四维各查一行 + 场景域固定段」三块拼装。

**时代基础段**（〔场景〕域新增，5 时代各一句；识别度全部由结构剪形表达、色相不换——第一章）：

| 时代 | 基础段 |
|------|--------|
| WW1 | great war era landscape, long trench lines and timber revetments, early steel gantries, distant biplane silhouette |
| WW2 | WWII era landscape, fortified blockhouse silhouettes, steel truss bridge, an armored column on a raised road |
| COLD | cold war era landscape, brutalist concrete structures, radar arrays on the horizon, wide frozen plain |
| MODERN | modern era landscape, container yards and highway viaducts, distant glass-and-steel towers |
| NEAR_FUTURE | near-future landscape, sleek monolithic towers, elevated transit lines, one colossal dark monolith on the horizon |

**环境修饰词表**（〔场景〕域新增，四维源 `data/battle_environments.gd`；逐维查表取句）：

| 维度 | 取值 | 修饰句 |
|------|------|--------|
| 天气 weather | rain | fine rain across the whole scene |
| | storm | heavy storm with driving rain, sky one low unbroken grey |
| | snow | 直接用第四章〔场景·雪原专用〕锁意象串整段 |
| | sandstorm | dense pale sand haze swallowing the midground |
| | clear | flat pale overcast sky, diffuse daylight |
| 地形 terrain | city | low dense skyline of cold grey buildings on the horizon |
| | plain | wide open flatland stretching to the horizon |
| 能量场 energy_field | normal | （无修饰句，整维省略） |
| | low_field | faint violet shimmer in the air |
| | high_field | violet aurora bands rippling high over the horizon |
| | nano_fog | low-lying luminous blue-grey nano fog drifting through the midground |
| 时段 time_of_day | day | diffuse daylight |
| | dusk | dim grey-blue dusk |
| | night | deep blue-grey night |

（时段修饰不得引入第二光源——夜城灯海=多光源，违反禁则 10；夜色的暖只来自那一个叙事光源。）

**组合与去重规则**：

- **city×night**（实卡 13/47/68/97 皆此组合）不得只禁不锁——加正面锁定句 `the skyline stays fully dark, unlit building silhouettes`，否则模型自造灯海（正面意象锁死，第一章/agnes 实测口径）。
- **snow×high_field**（实卡 level 93）＝双紫晕 + 双巨碑，违反自检 Q3——删雪原串的 halo 词，monolith 只保留一座（优先雪原串版本）。
- 雪原串与场景固定段同含 `flat overcast sky` 等天空词——同词第三次出现可省（重复堆叠无增益）。

**场景域固定段**（一~四章〔场景〕片段在背景类全部解禁，拼装顺序）：

时代基础段 → 环境修饰句（最多四句）→ 第四章场景构图串（vast empty composition… one tiny human silhouette against huge machinery）→ 第一章场景色板串（… flat overcast sky）→ 第二章场景光源句（single warm ember light source… fade into blue-grey haze）→ 第三章场景笔触串（film grain / soft airbrush smoke / hard-edge scuffed steel）。

负面栏〔场景〕：`text, frame`（ground 是画面本体必须存在，不得入负面栏；perspective view 是卡图平拍专属排除；ceiling 只用于室内图）。

**agnes 行为适配**（场景域）：正面意象锁死——要干净地面写实测句式"the floor/ground is one smooth continuous surface of …"；废墟字面词全禁（wasteland/ruined/bleak，禁则 4），荒芜只由第四章空旷公式表达（空旷构图 + 比例差 ≥1:10 一处 + 单一暖光源）；`scuffed` 首跑小样验证（附录一③）。

**生成后流程**：1152×768 出图 → 审核 → aspect-fill 裁 16:9（战场视口 1280×720 口径）→ 落 `assets/backgrounds/bg_level_NN.png`（命名沿用 battlefield.gd 的 `LEVEL_BG_PATH_FMT`，加载回退链自动接图、零代码改动）→ `--headless --editor --quit` 导入 → 备份。存量照片感背景按附录一处置（压冷+加雾保留、不再新增）；运行期另有 BG_DIM 压暗 + 时代 tint 叠乘（battlefield.gd v26.9），生图不必预压暗。

**合规自检 5 问**：

1. 地平线压低下 1/3、天空占 40%~60% 且平坦阴天（无戏剧云）？
2. 恰好一个叙事光源（一冷暖对撞，无灯海/双光源）？
3. 色板内（冷灰蓝世界 + 至多一处暖橙或紫晕点缀）？
4. 雾/grain/软烟只以〔场景〕串词出现（未混入任何〔卡图〕串）？
5. 无废墟字面词（荒芜由空旷公式表达）且无文字水印？

### 6.3 序章漫画（FLOW 主路，1280×720，prompt ≤900 字）

**待生成清单**（源 `docs/开场文本.md`；缺图自动退化程序化画格）：`b6_black_gates` / `b7_deep_voyage` / `b8_sacrifice`（⚠️ 格 id 为 b8_departure、贴图文件名为 b8_sacrifice.png，落盘以数据文件为准）/ `b10_rift_stream`，落 `assets/intro/comic/`，1280×720；另有雪原醒来大图 `assets/intro/wakeup_snowfield.png`。旁白内容真源：`data/intro_comic_panels.gd`。**五图已于 2026-09-07 批次生成在位（文件已核实）——本节降格为重生成/复核模板：任何重生前先按本节自检 5 问复核现状图，合格即不重生**（与"现状 11 格已合规零换血"口径一致）。

**FLOW 特殊约束**（与 agnes 是两套行为模型，本节注记不适用于 agnes、反之亦然——源 AGENTS.md FLOW 节）：

- **prompt ≤900 字**（超 ~950 触发"错误卡片"限流；报错等 60s 重试即好）。
- **`--ref` 是强内容锚**：参考图里画什么就出什么，prompt 只能微调；要换内容级元素必须换参考图或走纯文生图（不传 --ref）。
- **纯文生图语言理解强**（方向/朝向/谁在动都能听懂）——首次生成走纯文生图，微调迭代再上 --ref。
- 原生 1376×768 → PIL aspect-fill 裁 1280×720。
- flow-mcp（labs.google 直调）已死（2026-09-05 站点迁移后），只走 `docs/基地重设计/flow_edit_tool.py` 网页自动化。

**模板拼装**（每格）：一格一个视觉焦点（第四章漫画格条款）｜媒介=厚涂+版画排线+颗粒（第三章；现状 11 格已合规零换血）｜rim 不开（漫画格属场景族，第二章）｜一图一冷暖对撞（第一章；b6"暖橙火光×冷紫门光"即合规样板）｜内容锚以旁白为真源——四格场景句可参考 agnes 备路 `tools/generate_intro_shenhua.py` 已写好的 Scene 段直接移植（那是 agnes 管线产物，移植到 FLOW 只保留内容描述，行为约束换用本节）。

负面栏（沿用 shenhua 先例的域结构性扩展）：`text, watermark, signature, frame, border, comic panel grid, split panels`（防整图退化成多格漫画网格——结构性排除，非概念否定）。FLOW 无独立负面栏字段——负面词以 `Avoid: …` 尾缀并入 prompt 正文（`generate_intro_shenhua.py` L190 先例同法：`风格串 + 场景句 + "Avoid: " + 负面串`）。

**生成后流程**：出图 → 审核 → 裁 1280×720 → 落 `assets/intro/comic/<贴图文件名>.png`（以 `data/intro_comic_panels.gd` texture 字段为准）→ 缺图退化逻辑自动接真图 → `--headless --editor --quit` 导入 → 备份（序章专项包惯例）。

**合规自检 5 问**：

1. prompt ≤900 字？
2. 一格一个视觉焦点？
3. 恰好一冷暖对撞、单一叙事光源？
4. rim/辉光未开（漫画格=场景族）？
5. 无文字水印、未退化成多格网格（负面栏在位）？

### 6.4 相位仪徽章（agnes，1024×1024 深底徽章风，6 阵营族）

**基础锚段**（〔徽章〕域新增，章二徽章域特例注 + 族先例脚本语言拼装；中文串）：

```
科幻策略游戏装备徽章图标，单一主体居中，对称纹章构图，
深空黑到深灰蓝的深底径向渐变，
霓虹发光勾线与能量光晕，正方形徽章构图，主体完整居中，无文字无水印无logo
```

（串内「霓虹发光勾线与能量光晕」为族先例措辞。）

**媒介特例裁决（2026-09-08 质量审查）**：徽章域媒介**听现图**——存量 189 张族图全为霓虹辉光系（pi_aegis_01 等实看 + umbra / gen_missing_instruments_32 先例脚本皆写"霓虹发光轮廓与能量光晕"），域级特例维持系列统一；章二"无光效 rim"指徽章不吃卡图 rim 三档（rim 三档只辖卡图/场景写实体域），非禁徽章自身发光——徽章是 UI 发光体域。末句"无文字无水印无logo"为徽章域实测先例措辞（2026-08-23 影幕系列未触发反激活），其余域不得效仿——概念否定仍按禁则 2 只走结构性负面栏；厚涂/照片写实仍为规范判定语，不写进串。

**按族变体段**（6 族，既有图源 `assets/ui/instruments/pi_*.png`）：aegis / helix / nova / iron / umbra / eon 各有既系列——**生成前先开同族 3~5 张现有图对照，勾线主色与氛围句以族内既有系列为准**（umbra=黑门紫系粉紫勾线，先例 `tools/generate_umbra_instruments_4.py`；其余族以现有 pi_* 图实测取色，不凭记忆写）。umbra 族变体句（替换锚段默认深底渐变句，对齐先例原文）：`深紫黑色径向渐变背景`。主体意象句先例写法：单一主体 + 一句功能意象 + 族氛围句（如"一柄悬浮的虚空匕首……体现『一击薄刃』的隐秘锋锐感"）。传奇 r_ 系列为 128×128 小图——同管线生成后缩放部署。

**agnes 行为适配**（徽章域）：正面意象（主体物象 + 功能意象正面描述，不给场景不给人物）；先例脚本的 NEGATIVE「不要：…」段**弃用**（概念否定堆叠撞禁则 2）——负面栏只留结构性 `text, frame`；1024×1024 不透明深底——**不做透明化处理**（与卡图白底管线相反，勿混用）。

**生成后流程**：出图到 `docs/待生成徽章_<批次>/`（命名对齐 `docs/待生成卡图_11张`、`docs/待生成相位仪图标_32张` 惯例）→ 审核 → 复制 `assets/ui/instruments/`（不透明底直接可用）→ `godot --headless --editor --quit` 生成 .import 元数据（`--import` 直跑崩 0xC0000005，AGENTS.md 铁律）→ 备份。

**合规自检 5 问**：

1. 纹章语言非插画（无厚涂/无照片写实——判定不写进串），且辉光为族先例同款霓虹勾线（非泛光滥用、非整圈 halo）？
2. 对称居中 + 单一主体 + 同心/放射刻度类族内既有元素（如 aegis 表盘刻度；无多主体/无场景/无人物）？
3. 勾线主色与族内既有系列一致（生成前对照过 pi_* 现图）？
4. 深底不透明（未误走白底转透明管线）？
5. 无文字水印（先例句 + 负面栏 text 双保险在位）？

### 6.5 UI 底纹/图标（对齐 DesignTokens——冲突时以 DT 为准并回写本节）

**判断规则——多数 UI 元素不该用 AI 生图**：

- **默认程序化**：按钮/面板/槽位/进度条/分隔线/边框/功能图标符号，一律走 `resources/design_tokens.gd` + StyleBox/shader 绘制（COLOR_* 色板、CORNER_RADIUS、BORDER_WIDTH、PADDING_*、字号七档、PANEL_SIZE 三档）。**精确色只有代码能给**——agnes 无 hex 解析证据（第一章口径），生图只产出"近似的氛围"；UI 信息语义色（血量绿/危险红/能量橙）必须代码着色。
- **生图仅限两类**：①叙事插画资产（标题页大图/成就章/漫画格——走 6.2/6.3 管线）；②程序化无法表达的有机质感底纹（材质图章类）。胶片噪点/网格/扫描线等规则纹理优先程序化或后处理生成（第三章颗粒家族——噪点本就该程序化叠加）。
- **底纹类若确需生图**：底色沉入深底色环（深空黑 #0A121F / 面板灰蓝 #262B40 族）、低对比不抢前景、平铺无缝、无方向性强光影。
- **权威优先**：任何生图 UI 资产与 DesignTokens 冲突，以 DT 为准，并回写登记下方登记区（用途/色板映射/落盘路径）。
- **回写登记区**：已登记生图 UI 资产 = 相位仪徽章族（6.4 管线管辖，`assets/ui/instruments/`）；除此之外当前为空，新增即填。

**合规自检 5 问**：

1. 该资产程序化可替代吗？（可替代即不生图）
2. 信息语义色是否全部来自 DT 代码而非生图近似？
3. 若生图：底色在深底色环内、低对比不抢前景？
4. 平铺/缩放安全（无缝、无强方向光影）？
5. 已回写登记本节？

---

## 附录一、存量适配与批次④复核流程

- **总量口径**（抽样外推，批次④前以分档脚本全量复核）：卡图 356 张——调色归队约 55%~60%（压冷 LUT + rim 后处理补齐 + grain 后处理叠加），重生成约 40%~45%（勾边 / 卡通 / 构图姿态不合格，含现状 ww1 步兵、fut_swarm）。
- **流程顺序**：①先按第二章判定优先级跑单位族全量标注/分档脚本（rim 三档 × 写实度档 × 朝向/翻转合规扫描），产出三档名单 + 人工复核清单；②名单定稿后才动生图/调色——禁止边判边画。
- **调色归队卡的 rim 口径（写死，无豁免）**：一律后处理补齐/改色——脚本批量 LUT 压冷 + 边缘检测按单位族档位叠对应 rim（冰天青 / 霓虹青 / 黑门紫）。理由：rim 是内容层与 UI 层的缝合线，新生图有 rim 而调色归队图没有 = 缝合线断一半，拼凑感回潮。
- **写实度档 3 存量**：已达合格下限，调色归队即可，不强制升档 4。
- **写实度档 5 存量（照片感）**：仅战场背景类存在——压冷 + 加雾调色保留，不再新增；卡图中发现照片感存量一律重生成。
- **批次④首跑标定清单**（小样先行，标定后才放量）：
  1. hex 带 / 不带 A/B 小样——agnes 无 hex 解析实测证据（第一章 hex 口径）。
  2. 泛洪容差 × 颗粒密度标定——grain 后处理叠加参数（第三章颗粒感）。
  3. `scuffed` 类做旧措辞小样——若带出垃圾满地，降级 `brushed steel / matte steel`（第三章场景串注）。

## 附录二、端到端拼装示例（批次④第一张卡照此拼，免现场发明）

〔例〕二战我方坦克卡——单位族 = 历史写实系（外观写实命中优先级①）→ 冰天青 rim 档

正面串：

```
WWII single military vehicle, full body, eye-level side view, facing right,
historically accurate equipment detail, unit fills about three quarters of
the frame with even white margins, a single tank with rotating turret and
long main gun barrel, layered hull armor, wide track runs, overcast diffused
lighting, one narrow
cool sky-blue rim light along the back edge, muted cold palette of deep
blue-grey steel and cold grey, thick painterly illustration, clean painterly
silhouettes defined by value contrast and a narrow rim light, smooth blended
brushwork, hard-edge steel surfaces, plus one small warm amber glow from the
headlights, clean pure white background with NO ground
```

负面栏（结构性排除白名单）：

```
text, perspective view, frame, ground, ceiling
```

拼装决策记录：era 插槽 = WWII（句首）｜单位族 = 历史写实系 → rim 句取冰天青档（第二章条件树①）｜兵种句 = 装甲系（6.1.2 表，era 无关——即串中 a single tank… 一句原文）｜暖缀 = headlights（坦克待发姿态自带车灯暖源，成立写入；若单位无自然暖源——如纯步枪步兵——暖缀句整句删除）｜朝向 = facing right（player 直出，enemy 由 FLIP 产出）｜出图 1152x768 → flood_white_to_alpha → 裁切 512×512（透明先行才裁得准内容边界，见 6.1 生成后流程）→ 脚部锚 → grain 后处理叠加。

---

*本文档为批次④资产重生成的强制依据与后续一切生图 prompt 的拼装基础；与 `docs/统一化/风格方向候选.md`（已归档留查）冲突时，以本文档为准。*
