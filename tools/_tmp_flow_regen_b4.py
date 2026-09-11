#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批4 资产 Flow 重生成批量驱动（2026-09-10）。

范围（用户裁定）：
  - 背景图 10 张：批4 重生成过的 bg_level_12/22/38/42/55/58/68/92 + bg_endless_gate_t0/t1
  - 战斗卡 4 张：批4 重生成过的 vis_player_001 / vis_player_075 / ww2_arm_garand_para / fut_inf_c96

提示词配方（用户裁定=参考其合格档案，逐字骨架）：
  - 背景：docs/统一化/合格提示词.txt（第 91-95 关合格配方）四段式骨架，
    逐关换时代/主体/天气/地面材质；环境四维以 data/battle_environments.gd 为准
    （58=沙暴/平原/黄昏，非雪城）。负面尾栏不上（Flow 无独立负面通道 + 批4 §4-2 教训）。
  - 卡图：docs/统一化/…/精灵图nano_banana2_enemy_prompts_36.md 合格骨架
    （严格2D正侧视+正交投影+纯白棚拍底+禁 3/4 视角清单），朝向=右（卡图宪法）。

变体降级（AGENTS.md：prompt>~950 字触发错误卡片）：a=完整四段 → b=去中景段 →
c=再去边缘细节句。每变体最多重试 2 次，错误卡片后等 60s。

用法：
  python -u tools/_tmp_flow_regen_b4.py            # 全量（断点续跑：已出图自动跳过）
  python -u tools/_tmp_flow_regen_b4.py --only bg_level_12 vis_player_001
产物：docs/flow重生成_审查/{战斗卡_批4,背景_批4}/<name>.png（原始 jpg 存 _raw/）
"""
import argparse
import asyncio
import base64
import json
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT / "docs" / "基地重设计"))
import flow_edit_tool as fet  # noqa: E402

OUT_ROOT = ROOT / "docs" / "flow重生成_审查"
RAW_DIR = OUT_ROOT / "_raw"

# 运行期共享态（run() 内赋值/复位）
page_captured = {}
attempt_base = [set()]
batch_bodies = []
seen_fife = set()

# ── 卡图公共骨架（合格配方逐字） ──────────────────────────────────────────
CARD_HEAD = ("严格2D正侧视（true profile side view），正交投影（orthographic projection），"
             "游戏单位立绘/精灵图姿态，面向画面右侧，")
CARD_BG = ("干净棚拍纯白背景（white background），无地面无场景无杂物，高清。"
           "不要：三分之四视角、斜侧视、透视 perspective、广角、仰视、俯视、等距 isometric、"
           "鸟瞰 top-down、看到顶部、背景场景、地面、投影底板、文字、水印、logo")
CARD_TAIL_PERSON = "、人物。"
CARD_TAIL_NOP = "。"


def card(name, tag, subject, style, body, palette, extra="", person_in_neg=True):
    tail = CARD_TAIL_PERSON if person_in_neg else CARD_TAIL_NOP
    return (f"{name}（{tag}） {CARD_HEAD}{style}，以“{subject}”为主体，完整单位居中入镜，"
            f"{body}，{extra}金属磨损旧化（scratches, weathering），{palette}主色，"
            f"{CARD_BG}{tail}")


# ── 背景配方骨架（合格提示词.txt 四段式，逐字句式） ────────────────────────
BG_P1 = ("16:9 horizontal 2D side-scrolling mobile game background, bright, clean, "
         "polished art style, high detail, readable composition, no characters, "
         "no combat VFX, no text, no split layers, no segmented composition, no grid, "
         "no tile pattern, no checkerboard, no square markings.")

VIEW = ("viewed from a low forward perspective with the horizon placed high in the frame, "
        "leaving the entire lower portion as open ground.")
UNIFY = "The sky and horizon are unified as a single atmospheric backdrop."
MID_OPEN = "All midground elements remain low and non-obstructive."
FG_TMPL = ("The foreground and entire lower portion of the frame is open, flat {ground}, "
           "extending continuously across the full width. The ground surface has {surface}. "
           "{edges} The center of the ground remains completely clear and unobstructed.")
EDGES = "Only subtle ground-level details are present near the edges: {list}."


def bg(scene, sky, mid, ground, surface, edge_list):
    p2 = f"{scene}, {VIEW} {sky} {UNIFY}"
    p3 = f"In the middle distance, the landscape shows {mid}. {MID_OPEN}"
    p4 = FG_TMPL.format(ground=ground, surface=surface,
                        edges=EDGES.format(list=edge_list))
    return {"a": f"{BG_P1}\n\n{p2}\n\n{p3}\n\n{p4}",
            "b": f"{BG_P1}\n\n{p2}\n\n{p4}",
            "c": f"{BG_P1}\n\n{p2}\n\n"
                 f"{FG_TMPL.format(ground=ground, surface=surface, edges='')}"}


# ── JOBS：唯一真源（批4 §4-7 教训） ───────────────────────────────────────
JOBS = []

# ═══ 战斗卡 4 张 ═══
JOBS.append(("战斗卡_批4", "vis_player_001", {
    "a": card("vis_player_001", "【一战·玩家】重型坦克",
              "一战重型坦克", "写实历史装备设定图（historical concept art）",
              "旋转炮塔与长身管主炮朝右，层叠铆接装甲与宽履带负重轮轮廓清晰，"
              "素体无涂装无字样，结构分件与铆钉细节丰富",
              "低饱和钢蓝灰", person_in_neg=True)}))

JOBS.append(("战斗卡_批4", "vis_player_075", {
    "a": card("vis_player_075", "【二战·玩家】88毫米防空炮",
              "二战88毫米高射炮", "写实历史装备设定图（historical concept art）",
              "长身管炮身保持大仰角斜指右上方，十字形炮座与千斤顶支腿，"
              "炮手护盾与弹药架清晰，火炮结构写实不得画成加特林或科幻武器，"
              "结构分件细节丰富",
              "低饱和深灰", person_in_neg=True)}))

JOBS.append(("战斗卡_批4", "ww2_arm_garand_para", {
    "a": card("ww2_arm_garand_para", "【二战·玩家】伞兵步兵",
              "二战伞兵步兵", "写实历史装备设定图（historical concept art）",
              "头戴网罩钢盔，半自动步枪持于身前枪口朝右，伞兵背具腿包与弹药包轮廓清晰，"
              "军装绑带与装备分件细节丰富，布料与金属磨损旧化",
              "低饱和军绿", extra="士兵完整可见，", person_in_neg=False)}))

JOBS.append(("战斗卡_批4", "fut_inf_c96", {
    "a": card("fut_inf_c96", "【近未来·玩家】单兵士兵",
              "近未来单兵士兵", "科幻硬表面近未来单兵设定图（hard-surface sci-fi infantry concept art）",
              "肩扛紧凑型能量冲锋枪枪口朝右，全负载具与头盔，平静戒备站姿，"
              "素面无标记野战装甲，装甲分件与能量管线细节丰富",
              "低饱和冷灰", extra="局部青色微光仅限发光部件，", person_in_neg=False)}))

# ═══ 背景 10 张（环境四维=data/battle_environments.gd） ═══
JOBS.append(("背景_批4", "bg_level_12", bg(
    # 12: WW1 clear/plain/day（时代默认）
    "A World War I open frontline battlefield at midday under a clear pale sky",
    "A hazy pale daylight sky with thin high clouds fills the upper distance, with "
    "broken trench lines, timber revetments, an early steel observation gantry, and a "
    "distant biplane silhouette fading into atmospheric perspective.",
    "low trench parapet lines, timber revetment walls, a lone steel gantry, and distant "
    "barbed-wire lines",
    "dry trampled ground with worn grass-and-mud texture",
    "a pale earthy brown tone with subtle worn patches",
    "a few low dried grass tufts, faint shallow weathered craters, and scattered small pebbles")))

JOBS.append(("背景_批4", "bg_level_22", bg(
    # 22: WW2 rain/plain/dusk（时代默认）——变体A：街垒据点+桁架桥
    "A World War II fortified road junction at dusk under fine rain",
    "A dim grey-blue dusk sky with low rain clouds fills the upper distance, with "
    "concrete blockhouse silhouettes, a steel truss bridge, and an armored column on a "
    "raised road fading into rainy haze. Fine rain streaks across the whole scene.",
    "low blockhouse outlines, bridge truss lines, and parked armored silhouettes on the "
    "raised road",
    "wet muddy ground with a glossy rain-soaked texture",
    "a dark blue-grey brown tone with shallow puddles reflecting the dim sky",
    "faint vehicle ruts, sparse wet gravel, and small shallow puddles")))

JOBS.append(("背景_批4", "bg_level_38", bg(
    # 38: WW2 rain/plain/dusk（时代默认）——变体B：渡河+浮桥（与22差异化，批4 §4-1）
    "A World War II river-crossing battlefield at dusk under steady rain",
    "A deep blue-grey rainy dusk sky with drifting showers fills the upper distance, with "
    "a distant pontoon bridge line, flooded flat fields, faint smoke columns, and a far "
    "artillery emplacement silhouette fading into rainy haze. Fine rain streaks across "
    "the whole scene.",
    "pontoon bridge outlines, flooded field strips, and distant thin smoke columns",
    "rain-soaked grey-brown mud ground with sheet-water sheen",
    "a cool grey-brown tone with wet reflective patches",
    "sparse reed tufts, shallow standing water, and faint cart ruts")))

JOBS.append(("背景_批4", "bg_level_42", bg(
    # 42: COLD snow/city/day（时代默认）——变体A：雷达哨（无黑门意象，批4 §4-3）
    "A Cold War snowfield checkpoint at midday under a flat overcast sky",
    "A pale grey overcast daylight sky fills the upper distance, with brutalist concrete "
    "structures, radar arrays on the horizon, and a low dense skyline of cold grey "
    "buildings fading into cold haze. Faint pale daylight glare rests on the snow.",
    "low concrete bunker outlines, snow-covered radar lattice frames, and distant "
    "apartment blocks",
    "wind-carved snow field",
    "a pale blue-white tone with soft drifts and faint wind ripples",
    "sparse snow ridges, small soft drifts, and faint tyre tracks in snow")))

JOBS.append(("背景_批4", "bg_level_55", bg(
    # 55: COLD snow/city/day（时代默认）——变体B：工业边缘（与42差异化）
    "A Cold War industrial outskirts at midday in light snowfall",
    "A flat grey overcast sky with slow falling snow fills the upper distance, with "
    "factory halls and chimneys, frozen gantry cranes, and a low grey city skyline fading "
    "into snowy haze.",
    "low factory hall outlines, frozen crane gantries, and snow-covered industrial heaps",
    "compacted snow over cracked concrete ground",
    "a pale grey-white tone with frost patches showing faint concrete cracks",
    "sparse snow patches, small frost heaps, and a faint buried rail line")))

JOBS.append(("背景_批4", "bg_level_58", bg(
    # 58: COLD sandstorm/plain/low_field/dusk（ENV_BY_LEVEL 显式，非雪城！）
    "A Cold War dust-storm plain at dusk under a low ochre-grey sky",
    "A dim amber-grey dusk sky choked with airborne dust fills the upper distance, with "
    "deserted radar outposts, concrete pylons, and buried bunker mounds half-lost in "
    "drifting dust fading into the haze. Dim dusk light filters through the dust.",
    "low pylon lines, half-buried bunker mounds, and long dust drifts",
    "gritty dust-covered ground",
    "a dull tan-grey tone with rippled sand patterns",
    "sparse dry shrubs, small dust ridges, and faint scattered debris")))

JOBS.append(("背景_批4", "bg_level_68", bg(
    # 68: MODERN storm/city/high_field/night（ENV_BY_LEVEL 显式）+锁灯+单暖光+紫极光
    "A modern highway interchange at night under a heavy storm",
    "One low unbroken grey-black storm sky with driving rain fills the upper distance, "
    "with dark glass-and-steel towers, highway viaducts, and container yards fading into "
    "rainy night haze, while faint violet aurora bands ripple high over the horizon. "
    "The skyline stays fully dark with unlit building silhouettes, and a single warm "
    "street-lamp glow marks the horizon.",
    "low viaduct pillar lines, container stack silhouettes, and dark guard rails",
    "rain-flooded dark asphalt ground",
    "a deep blue-grey tone with cold reflections of the storm sky",
    "sparse puddle shimmer, faint worn road markings, and small wet debris")))

JOBS.append(("背景_批4", "bg_level_92", bg(
    # 92: NEAR_FUTURE sandstorm/plain/nano_fog/dusk（时代默认）
    "A near-future city fringe at dusk under dense sand haze",
    "A dim grey-blue dusk sky swallowed by pale sand haze fills the upper distance, with "
    "sleek monolithic towers, elevated transit lines, and one colossal dark tower "
    "silhouette (a building, not a figure) fading into the sand haze. Low-lying luminous "
    "blue-grey nano fog drifts through the midground.",
    "low transit pillar lines, half-buried structures, and a thin glowing nano-fog band",
    "fine pale sand ground",
    "a dull grey-tan tone with gentle wind ripples",
    "sparse sand ripples, small half-buried metal plates, and faint nano-fog wisps")))

JOBS.append(("背景_批4", "bg_endless_gate_t0", bg(
    # 无尽门 T0：远景门（门=紫晕唯一光源，monolith 只属门图配方）
    "A distant colossal black monolith gate standing on a frozen snow plain at midday",
    "A flat pale overcast sky fills the upper distance, with wind-carved snow fields and "
    "the tiny distant black gate silhouette fading into cold haze. A single faint violet "
    "halo surrounds the distant gate.",
    "low snow ridges, faint ice-crack lines, and the small distant gate silhouette",
    "wind-carved snow field",
    "a pale blue-white tone with soft drifts",
    "sparse snow tufts, small ice fragments, and faint wind ridges")))

JOBS.append(("背景_批4", "bg_endless_gate_t1", bg(
    # 无尽门 T1：中景门+重霾
    "A colossal black monolith gate looming in the midground over a frozen snow plain at dusk",
    "A heavier blue-grey dusk haze swallowing the horizon fills the upper distance, with "
    "the black gate silhouette and its faint violet halo rising above the snow fields. "
    "A faint violet halo surrounds the gate.",
    "the gate base structures, low broken ice walls, and heavy haze bands",
    "trampled snow field",
    "a cold grey-white tone with frost patches and faint violet reflections on the gate side",
    "sparse frost shards, small snow mounds, and faint wind-scoured lines")))

# ═══ 徽章 5 张（批3 真废重生成；STYLE_BIBLE §6.4 锚段+主体句逐字，去「text, frame」尾） ═══
BADGE_ANCHOR = ("科幻策略游戏装备徽章图标，单一主体居中，对称纹章构图，"
                "深空黑到深灰蓝的深底径向渐变，"
                "霓虹发光勾线与能量光晕，正方形徽章构图，主体完整居中，无文字无水印无logo")

JOBS.append(("徽章_批3", "pi_helix_04", {
    "a": BADGE_ANCHOR + "主体是一颗悬浮的半透明青绿色晶体神经核心，两条螺旋神经束对称环绕核心旋转，"
                        "外围一圈青绿色发光圆形徽章框，体现『幻影分身』的侦察科技感。"}))
JOBS.append(("徽章_批3", "pi_generic_07", {
    "a": BADGE_ANCHOR + "主体是一座精密的六边形合金能量核心，中心一颗冰蓝色冷光芯，"
                        "外围两圈金属精密刻度环，外环泛暖金金属光泽、内圈冰蓝冷光，与系列表盘徽章同语言。"}))
JOBS.append(("徽章_批3", "pi_r_overload", {
    "a": BADGE_ANCHOR + "主体是一颗过载的反应堆能量核心，橙红色电弧沿环形导轨迸发，核心白炽过载光。"}))
JOBS.append(("徽章_批3", "pi_r_shield", {
    "a": BADGE_ANCHOR + "主体是一面层叠的能量护盾，冰蓝色六边形力场纹发光，盾面双层投影前后错叠。"}))
JOBS.append(("徽章_批3", "pi_hp", {
    "a": BADGE_ANCHOR + "主体是一枚医疗十字与生命体征波纹融合的能量徽记，青绿色生命光晕。"}))

# ── 生成流程 ───────────────────────────────────────────────────────────
SUBMIT_RETRIES_PER_VARIANT = 2
ERRCARD_COOLDOWN_S = 60
GEN_WAIT_S = 660          # 单次生成等待上限（实测首跑 >300s 仍未出）
BUSY_WAIT_S = 420         # 按钮禁用=上一发仍在生成 → 纯等待截获


async def wait_btn_enabled(page, log, timeout_s=90) -> bool:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        try:
            btn = page.get_by_role("button", name="开始生成").first
            if await btn.count() and not await btn.is_disabled():
                return True
        except Exception:
            pass
        await page.wait_for_timeout(4000)
    log("[gen] 按钮持续禁用（>90s）")
    return False


async def gen_one(page, prompt, out_png: Path, log) -> bool:
    """在当前项目页提交一条 prompt，成功落盘返回 True。任何异常不外抛。"""
    try:
        return await _gen_one_inner(page, prompt, out_png, log)
    except Exception as exc:
        log(f"[gen] ⚠ {out_png.stem} 异常: {type(exc).__name__}: {str(exc)[:160]}")
        return False


async def _gen_one_inner(page, prompt, out_png: Path, log) -> bool:
    pm = page.locator("div.ProseMirror").first
    try:
        await pm.click(timeout=8000)
    except Exception:
        await page.evaluate("() => document.querySelector('div.ProseMirror').focus()")
    await page.wait_for_timeout(300)
    await page.keyboard.press("Control+A")
    await page.keyboard.press("Delete")
    await page.wait_for_timeout(300)
    await page.keyboard.insert_text(prompt)
    await page.wait_for_timeout(600)
    n = len(await pm.inner_text())
    log(f"[prompt] 已输入 {n} 字 → {out_png.stem}")

    for attempt in range(1, SUBMIT_RETRIES_PER_VARIANT + 1):
        await close_overlays_wrapped(page)
        baseline_tiles = await page.evaluate(fet.TILES_JS)
        imgs_before = set(await page.evaluate(fet.THUMBS_JS))

        # 竞态修复（2026-09-10 错位事故教训）：必须等到没有任何生成在途
        # （按钮恢复可用）再做基线快照并提交——否则上一发的结果会在
        # 快照之后到达，被错记成本次产物（曾致 42~t1 整体错位一档）。
        if not await wait_btn_enabled(page, log, timeout_s=300):
            log(f"[gen] {out_png.stem} 等待在途生成结束超时（300s）")
            continue
        attempt_base[0] = set(page_captured)
        baseline_tiles = await page.evaluate(fet.TILES_JS)
        imgs_before = set(await page.evaluate(fet.THUMBS_JS))

        gen_btn = page.get_by_role("button", name="开始生成").first
        try:
            await gen_btn.click(timeout=15000)
        except Exception as exc:
            log(f"[gen] 点击超时: {str(exc)[:80]} → 下轮重试")
            await page.wait_for_timeout(8000)
            continue
        log(f"[gen] 已提交 {out_png.stem} (attempt {attempt})")

        res = await wait_capture(page, baseline_tiles, imgs_before, log, GEN_WAIT_S)
        if res:
            ok = await save_result(page, res, out_png, log)
            if ok:
                # 等本次生成彻底收尾（按钮恢复可用），下一任务从干净状态起步
                await wait_btn_enabled(page, log, timeout_s=120)
            return ok

        if attempt < SUBMIT_RETRIES_PER_VARIANT:
            log(f"[gen] {ERRCARD_COOLDOWN_S}s 冷却后重试")
            await page.wait_for_timeout(ERRCARD_COOLDOWN_S * 1000)
    return False


async def save_result(page, res, out_png: Path, log) -> bool:
    kind, val = res
    if kind == "cap":
        ok = await save_capture(val, out_png, log)
    else:
        data = await fetch_via_page(page, val, log)
        ok = await save_bytes(data, out_png, log)
    # 同批多张备选（Flow 有时一次出 2 张）→ <name>_altN.png 一并落盘供审查
    alt = 2
    for u in [u for u in page_captured if u not in attempt_base[0]]:
        alt_path = out_png.parent / f"{out_png.stem}_alt{alt}.png"
        if not alt_path.exists() and u != (val if kind == "cap" else None):
            await save_capture(u, alt_path, log)
            alt += 1
    return ok


async def wait_capture(page, baseline_tiles, imgs_before, log, timeout_s):
    """等待新结果：返回 ("cap",uuid) / ("url",url) / None。含 fifeUrl 与 DOM 兜底。"""
    deadline = time.monotonic() + timeout_s
    last_log = time.monotonic()
    while time.monotonic() < deadline:
        fresh = [u for u in page_captured if u not in attempt_base[0]]
        if fresh:
            return ("cap", fresh[0])
        try:
            if await page.evaluate(fet.TILES_JS) > baseline_tiles:
                log("[gen] 新错误卡片 → 本轮失败")
                return None
        except Exception:
            pass
        # 兜底 1：DOM 新缩略图
        try:
            cur = set(await page.evaluate(fet.THUMBS_JS))
            fresh_dom = [u for u in cur - imgs_before if len(u) > 70]
            if fresh_dom:
                log(f"[gen] DOM 新图兜底: {fresh_dom[:1]}")
                return ("url", fresh_dom[0])
        except Exception:
            pass
        # 兜底 2：batchexecute 里的 fifeUrl
        try:
            for body in batch_bodies:
                for u in re.findall(r'"fifeUrl"\s*:\s*"([^"]+)"', body):
                    u = u.replace("\\u0026", "&")
                    if u not in seen_fife:
                        seen_fife.add(u)
                        log("[gen] fifeUrl 兜底命中")
                        return ("url", u)
        except Exception:
            pass
        if time.monotonic() - last_log > 60:
            try:
                btn = page.get_by_role("button", name="开始生成").first
                busy = await btn.count() and await btn.is_disabled()
            except Exception:
                busy = "?"
            log(f"[gen] …等待中 captured={len(page_captured)} 生成中={busy}")
            last_log = time.monotonic()
        await page.wait_for_timeout(5000)
    log(f"[gen] 等待超时（{timeout_s}s）")
    return None


async def fetch_via_page(page, url, log):
    """在页面上下文 fetch 图片字节（原工具降级通道）。"""
    try:
        data_url = await page.evaluate(
            """async (u) => { try {
                const r = await fetch(u);
                if (!r.ok) return null;
                const b = await r.blob();
                return await new Promise(res => { const d = new FileReader();
                    d.onload = () => res(d.result); d.readAsDataURL(b); });
            } catch (e) { return null; } }""",
            url,
        )
        if data_url and data_url.startswith("data:"):
            return base64.b64decode(data_url.split(",", 1)[1])
    except Exception as exc:
        log(f"[fetch] 失败: {type(exc).__name__}: {str(exc)[:100]}")
    return None


async def save_bytes(data, out_png: Path, log) -> bool:
    if not data or len(data) < 30_000:
        return False
    out_png.parent.mkdir(parents=True, exist_ok=True)
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    raw = RAW_DIR / f"{out_png.stem}_{int(time.time())}.{fet.ext_of(data[:12])}"
    raw.write_bytes(data)
    # Flow 返回 JPEG 字节 → 统一转真 PNG，避免扩展名与内容不符
    if fet.ext_of(data[:12]) != "png":
        from PIL import Image
        import io
        im = Image.open(io.BytesIO(data)).convert("RGB")
        im.save(out_png, "PNG")
        log(f"[save] ✅ {out_png} ({im.size[0]}×{im.size[1]}, 转自 {raw.name})")
        return True
    out_png.write_bytes(data)
    log(f"[save] ✅ {out_png} ({len(data)//1024} KB, {fet.jpeg_size(data)})")
    return True


async def save_capture(uuid, out_png: Path, log) -> bool:
    for _ in range(6):
        if uuid in page_captured:
            break
        await asyncio.sleep(3)
    return await save_bytes(page_captured.get(uuid), out_png, log)


async def close_overlays_wrapped(page):
    try:
        await fet.close_overlays(page)
    except Exception:
        pass


async def run(jobs, log, headless=True) -> int:
    from playwright.async_api import async_playwright
    manifest_path = OUT_ROOT / "_manifest.json"
    manifest = json.loads(manifest_path.read_text("utf-8")) if manifest_path.exists() else {}
    ok, fail = 0, 0
    async with async_playwright() as pw:
        profile_dir = fet.copy_profile(log)
        ctx = await fet.launch_context(pw, profile_dir, headless=headless)
        page = ctx.pages[0] if ctx.pages else await ctx.new_page()
        global page_captured, attempt_base, batch_bodies
        page_captured = {}
        batch_bodies = []

        async def on_response(resp):
            try:
                u = resp.url
                if "batchexecute" in u and resp.status == 200:
                    batch_bodies.append(await resp.text())
                if "flow-content.google/image/" in u and resp.status == 200:
                    data = await resp.body()
                    if len(data) > 30_000:
                        uuid = u.split("/image/")[1][:36]
                        if uuid not in page_captured:
                            page_captured[uuid] = data
                            log(f"[net] 截获 {uuid[:8]} ({len(data)//1024} KB)")
            except Exception:
                pass

        page.on("response", on_response)
        try:
            pid = await fet.discover_project(page, log) or fet.DEFAULT_PROJECT
            if not await fet.goto_ready(page, f"https://flow.google.com/project/{pid}", log):
                log("[nav] 项目页未就绪")
                return 1
            log(f"[nav] 项目就绪: {pid}，共 {len(jobs)} 个任务")

            for subdir, name, variants in jobs:
                out_png = OUT_ROOT / subdir / f"{name}.png"
                if out_png.exists():
                    log(f"── {name} 已存在，跳过")
                    ok += 1
                    continue
                done = False
                for variant, prompt in sorted(variants.items()):
                    attempt_base = [set(page_captured)]
                    for try_round in range(1, SUBMIT_RETRIES_PER_VARIANT + 1):
                        attempt_base[0] = set(page_captured)
                        if await gen_one(page, prompt, out_png, log):
                            done = True
                            break
                        log(f"[{name}] 变体{variant} 第{try_round}次未出图")
                    if done:
                        manifest[f"{subdir}/{name}"] = {"variant": variant,
                                                        "file": str(out_png.relative_to(OUT_ROOT)),
                                                        "time": time.strftime("%Y-%m-%d %H:%M:%S")}
                        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1),
                                                 encoding="utf-8")
                        break
                    log(f"[{name}] 降级下一变体")
                if done:
                    ok += 1
                else:
                    fail += 1
                    log(f"[{name}] ❌ 全变体失败")
                await page.wait_for_timeout(4000)
        finally:
            await ctx.close()
    log(f"[done] 成功 {ok} / 失败 {fail}（共 {len(jobs)}）")
    return 0 if fail == 0 else 1


async def amain():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--headed", action="store_true",
                    help="有头模式（弹出 Chrome 窗口；绕 Google 无头风控）")
    args = ap.parse_args()
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    log = fet.make_logger(OUT_ROOT / "flow_batch.log")
    jobs = [j for j in JOBS if args.only is None or j[1] in args.only]
    log(f"==== 批4 Flow 重生成启动：{len(jobs)} 张 (headed={args.headed}) ====")
    return await run(jobs, log, headless=not args.headed)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(asyncio.run(amain()))
