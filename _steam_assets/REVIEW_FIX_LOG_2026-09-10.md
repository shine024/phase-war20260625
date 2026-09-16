# Steam 商店页审核被拒 · 修复记录（2026-09）

> 用途：商店页审核问题的完整档案。**再次被拒或出问题时先读这份**，里面有问题定位、
> 每张图的版本指纹（sha256 前缀）、修复方案与兜底方案。
> 生成器：`tools/make_steam_capsules_v28.py`（当前权威版本）

---

## 一、审核记录

| 轮次 | 日期 | 提交内容 | 结果 |
|---|---|---|---|
| 1 | 2026-09 上旬 | v2 图（带 CONSTRUCT ERA 标语） | ❌ 被拒（Failure×2，见下） |
| 2 | 2026-09-10 起 | v28 图（待上传） | 待定 |

### 第 1 轮拒信原文要点（两处 Failure，模板原话）

**Failure 1 — 商店胶囊（Header / Small / Main / Vertical 四张全点名）**：
> "capsule images contain additional text... Capsules on Steam can only include
> game artwork, **the game name, and any official subtitle**."

**Failure 2 — 库资产（Library Capsule / Header / Logo 三张点名；Hero 未点名）**：
> "library assets contain some additional text or logos. The Library Capsule,
> Header, and Logo should only include **the game's title**, and the Library Hero
> shouldn't have any extra text or logo overlays."

规则页：<https://partner.steamgames.com/doc/store/assets/rules#1>（胶囊）、#2（库资产）

---

## 二、根因诊断（视觉比对结论）

旧图（v2，备份在 `_steam_assets/_backup_20260903/`）上的文字逐项判定：

| 文字 | 性质 | 判定 |
|---|---|---|
| 相位战争 | 游戏中文名 | ✅ 规则允许（the game name） |
| PHASE WAR | 游戏英文名（Steamworks 注册名） | ✅ 允许（双语名=同一名） |
| **· CONSTRUCT ERA** | **自造标语，非官方副标题** | ❌ **被拒根因①**（4 张胶囊+3 张库资产全带它） |
| **百关战术卡牌战役** | **营销文案**（旧库胶囊底部） | ❌ **被拒根因②**（库资产只许游戏标题） |
| 青色分隔线（旧 library logo） | 装饰图形，非文字 | 低风险，v28 保留 |
| 左侧压暗渐变（library hero） | logo 安全区亮度处理，非 overlay | ✅ 合规（Hero 未被点名） |

**排除项**：Library Hero、Page Background、截图×7、预告片、两个图标——均未被点名，
不需要重传。

---

## 三、修复版本演进（防止以后拿错版本）

| 版本 | 说明 | 状态 |
|---|---|---|
| v2（09-03） | 艺术图 + 相位战争 + PHASE WAR · CONSTRUCT ERA；库胶囊另有营销语 | ❌ 被拒，已隔离 |
| v27（会话中） | 过度矫正：全部图删光文字；且库资产标题因脚本 bug 没画上 | ❌ 废弃（bug：`draw_title_only` 把合成图赋给局部变量，paste 丢失；图标圆环越界 `(size-10)*k`） |
| **v28（09-10，当前）** | 保留双语游戏名（规则允许），删 CONSTRUCT ERA + 营销语；修绘图 bug 与图标圆环数学 | ✅ 当前权威版 |

**v28 生成器**：`python tools/make_steam_capsules_v28.py`
（自动重生成全部图 + 同步到 `upload/` 各子目录，成功后输出清单）

---

## 四、当前上传文件夹指纹（2026-09-10 终验，sha256 前 12 位）

### `upload/1a_商店胶囊_拖拽区/`（对应 Steamworks「图像资产 → 商店资产」）

| 文件 | sha256 前缀 | 图上内容 |
|---|---|---|
| header_capsule_920x430.png | `3703094B018D` | 相位战争 + PHASE WAR |
| small_capsule_462x174.png | `250830FAF267` | 同上（左对齐排版） |
| main_capsule_1232x706.png | `6BA18EF00B1A` | 同上（⚠️ 认准此文件名，旧 `main_capsule_2x_1232x706.png` 已隔离） |
| vertical_capsule_748x896.png | `1FF39B89ECAF` | 同上（底部居中） |
| page_background_1438x810.png | `CC1A379CC0F3` | 零文字（未被拒，可顺手换） |

### `upload/2_库资产/`（对应「图像资产 → 库资产」）

| 文件 | sha256 前缀 | 图上内容 |
|---|---|---|
| library_capsule_600x900.png | `88B01813A913` | 底部色带仅双语游戏名（营销语已删） |
| library_header.png | `3703094B018D` | = header（复用） |
| library_logo_1280x720.png | `FDDE9EBE0431` | 透明底仅双语游戏名 + 分隔线 |
| library_hero_3840x1240.png | `90FEB30A248D` | 零文字（**未被拒，无需重传**） |

### `upload/1b_图标_专用字段/`（可选，不阻塞审核）

| 文件 | sha256 前缀 | 说明 |
|---|---|---|
| app_icon_184x184.jpg | `B0089996110C` | 青环+「相」，v28 修圆环越界后版本 |
| shortcut_icon_256x256.png | `424BD0D8B86E` | 同上 |

上传入口：App Icon → 图像资产页最底部「社区图标」小字段；
Shortcut Icon → 应用管理 → 安装(Installation) → 客户端图片(Client Images)。
（上轮没找到入口，过审后再补，不阻塞。）

### 已隔离的旧文件（`_steam_assets/_stale_20260910/`，勿再使用）

- `header_capsule_920x430.png`（BA60BE0EEC1F，09-03 旧版含 CONSTRUCT ERA，曾混在 2_库资产 里）
- `main_capsule_2x_1232x706.png`（D1E550F84522，旧版含文字）
- `main_capsule_616x353.png`（B4D36D780C4E，停用规格）

---

## 五、如果再被拒（第 2 轮兜底方案）

1. **先核对 Steamworks 上每个槽位实际显示的图**（缩略图点开看）——确认 v28 真的传上去了，
   而不是旧图残留（本轮第 1 次拒信就是旧图状态的产物）。
2. 若审核连**双语游戏名**都不放行（与规则条文不符，但审核员主观判断可能更严）：
   - 切纯无字方案：所有胶囊/库资产只留艺术图零文字（v27 思路，无 bug 版），
     游戏名完全依赖 Steam 页面自带的标题显示。
   - 执行：把 `make_steam_capsules_v28.py` 里 `draw_title(...)` 各调用注释掉后重跑，
     或让 agent 出一版 `v29_textfree`。
3. 若只拒个别图：只换被点名的，其余不动。
4. 必要时用 Steamworks 工单/邮件（回信人 Luna）直接问「双语游戏名是否允许」，
   引用规则原文 "the game name" 字样。

---

## 六、上传操作卡（照抄即可）

1. 打开 `upload/1a_商店胶囊_拖拽区/` → Steamworks「图像资产 → 商店资产」
   → 五个槽位逐个「替换」上传（别拖顶部大拖拽区）
2. 打开 `upload/2_库资产/` → 「库资产」子页 → 三个槽位替换
   （Library Hero 不动）
3. 保存 → 重新提交审核 → 等待 1-2 个工作日
4. 截图资产、宣传片：完全不动

---

*记录人：agent（glm-5.3-flash），2026-09-10。有疑问先读本文第二节（根因）与第五节（兜底）。*
