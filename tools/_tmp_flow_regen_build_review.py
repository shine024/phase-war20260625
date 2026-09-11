#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 _tmp_flow_regen_b4.JOBS 导出审查页与提示词档案（单一真源）。"""
import html
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import _tmp_flow_regen_b4 as drv  # noqa: E402

ROOT = drv.OUT_ROOT
SUBDIR_TITLES = {"战斗卡_批4": "战斗卡（4 单位）", "背景_批4": "关卡背景（10 关）"}

# 每图备注（审查时重点关注）
NOTES = {
    "bg_level_22": "与 38 同环境（二战雨/平原/黄昏），按批4 §4-1 差异化：22=街垒据点+桁架桥",
    "bg_level_38": "差异化：38=渡河+浮桥；本图实际采用变体 b（无中景段）配方出图",
    "bg_level_42": "冷战雪/城市/白昼——变体A：雷达哨点；已按批4 §4-3 剔除黑门意象",
    "bg_level_55": "冷战雪/城市/白昼——差异化变体B：工业边缘（厂房/龙门吊）",
    "bg_level_58": "⚠ 环境修正：ENV_BY_LEVEL 58=沙暴/平原/黄昏（批4 误画成雪城）",
    "bg_level_68": "暴雨夜城+紫极光+天际线锁灯+单一暖路灯（批4 锚点全保留）",
    "bg_level_92": "首版雾中出人形巨影（穿帮），已改「塔状剪影（建筑，非人形）」重生成",
    "bg_endless_gate_t0": "无尽门 T0：远景门；monolith+紫晕意象仅用于门图配方",
    "bg_endless_gate_t1": "无尽门 T1：中景门+重霾+雪地紫晕反光",
    "vis_player_075": "禁则 11 重点关：写实 88 炮（十字炮座/护盾/弹药架），防科幻加特林",
    "ww2_arm_garand_para": "真人伞兵：负面栏已去「人物」避免歧义",
    "fut_inf_c96": "近未来单兵：负面栏去「人物」；青色微光仅限发光部件",
}


def main() -> int:
    cards, bgs, badges = [], [], []
    for subdir, name, variants in drv.JOBS:
        folder = ROOT / subdir
        mains = sorted(folder.glob(f"{name}.png"))
        alts = sorted(folder.glob(f"{name}_alt*.png"))
        item = {"subdir": subdir, "name": name, "mains": mains, "alts": alts,
                "variants": variants, "note": NOTES.get(name, "")}
        if subdir == "战斗卡_批4":
            cards.append(item)
        elif subdir == "徽章_批3":
            badges.append(item)
        else:
            bgs.append(item)

    anim_dir = ROOT / "动画雪碧图"
    anims = []
    if anim_dir.is_dir():
        for sheet in sorted(anim_dir.glob("*_sheet.png")):
            unit_anim = sheet.name.replace("_sheet.png", "")
            gif = anim_dir / f"{unit_anim}.gif"
            anims.append({"sheet": sheet, "gif": gif if gif.exists() else None,
                          "unit_anim": unit_anim})

    # 状态：背景 10 张已按用户认可部署 assets/backgrounds（2026-09-10）；其余待审
    DEPLOYED_SUBDIRS = {"背景_批4"}

    def render_group(items, title):
        deployed = bool(items) and all(it["subdir"] in DEPLOYED_SUBDIRS for it in items)
        chip = ('<span style="background:#1d3a26;color:#7ee2a8;border:1px solid #2b5c3a;'
                'border-radius:10px;padding:2px 10px;font-size:12px;margin-left:8px">✅ 已部署 assets</span>'
                if deployed else
                '<span style="background:#3a2f1d;color:#ffd479;border:1px solid #5c4a2b;'
                'border-radius:10px;padding:2px 10px;font-size:12px;margin-left:8px">⏳ 待审查</span>')
        out = [f'<h2>{html.escape(title)}{chip}</h2>']
        for it in items:
            main = it["mains"][0] if it["mains"] else None
            out.append('<div class="item">')
            out.append(f'<h3>{html.escape(it["name"])}</h3>')
            if it["note"]:
                out.append(f'<p class="note">{html.escape(it["note"])}</p>')
            if main:
                out.append(f'<a href="{it["subdir"]}/{main.name}" target="_blank">'
                           f'<img src="{it["subdir"]}/{main.name}" loading="lazy"></a>')
            if it["alts"]:
                out.append('<div class="alts">')
                for a in it["alts"]:
                    out.append(f'<a href="{it["subdir"]}/{a.name}" target="_blank">'
                               f'<img src="{it["subdir"]}/{a.name}" loading="lazy"></a>')
                out.append('</div>')
                out.append('<p class="altcap">↑ 同提示词备选张</p>')
            v = it["variants"]
            for vk in sorted(v):
                label = "实际采用" if (it["name"] != "bg_level_38" or vk == "b") else "备选"
                if it["name"] == "bg_level_38" and vk == "a":
                    label = "备选（降级前）"
                out.append(f'<details><summary>提示词（变体 {vk}·{label}·{len(v[vk])} 字）</summary>'
                           f'<pre>{html.escape(v[vk])}</pre></details>')
            out.append('</div>')
        return "\n".join(out)

    def render_anims(items):
        if not items:
            return ""
        n_units = len({it["unit_anim"].rsplit("_", 1)[0] for it in items})
        out = [f'<h2>动画雪碧图（{n_units} 单位 × idle/attack = {len(items)} 张）</h2>',
               '<p class="note">⚠ 2026-09-10 全身修正版：批4 参考图曾误用半身卡图裁切导致动画半身，'
               '已恢复 8/29 全身立绘参考图并重生成，4 个步兵/车辆单位逐张目检通过。'
               '通道：agnes-video-2.5-flash 图生视频（Flow 图像通道不支持图生视频）；'
               'idle=8 帧 / attack=12 帧，fps 8，512 画布。'
               'GIF 为动作预览（由 source.mp4 转制），部署用 PNG 雪碧图。</p>']
        for it in items:
            out.append('<div class="item">')
            out.append(f'<h3>{html.escape(it["unit_anim"])}</h3>')
            out.append(f'<a href="动画雪碧图/{it["sheet"].name}" target="_blank">'
                       f'<img src="动画雪碧图/{it["sheet"].name}" loading="lazy"></a>')
            if it["gif"]:
                out.append(f'<p class="altcap">动作预览：</p>'
                           f'<img src="动画雪碧图/{it["gif"].name}" width="384">')
            out.append('</div>')
        return "\n".join(out)

    doc = f"""<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<title>批4 Flow 重生成审查（{len(drv.JOBS)} 主图）</title>
<style>
body{{font-family:"Microsoft YaHei",system-ui;background:#0f1218;color:#e8eaed;margin:24px}}
h1{{font-size:22px}} h2{{border-bottom:1px solid #2c3442;padding-bottom:6px;margin-top:36px}}
h3{{margin:18px 0 6px;font-size:15px;color:#9cc4ff}}
.note{{color:#ffd479;font-size:13px;margin:4px 0}}
.item{{background:#161b22;border:1px solid #2c3442;border-radius:10px;padding:12px 16px;margin:14px 0}}
img{{max-width:100%;border-radius:6px;display:block}}
.alts{{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px}}
.alts img{{width:220px}}
.altcap{{color:#8b93a1;font-size:12px}}
details{{margin-top:8px}} summary{{cursor:pointer;color:#7fb0ff;font-size:13px}}
pre{{white-space:pre-wrap;word-break:break-all;background:#0d1117;padding:10px;border-radius:6px;
font-size:12px;color:#c9d1d9;max-height:300px;overflow:auto}}
.meta{{color:#8b93a1;font-size:13px}}
</style></head><body>
<h1>批4 Flow 重生成审查页</h1>
<p class="meta">通道：Google Flow 网页版（flow_edit_tool.py 有头模式，无头被风控卡死）。<br>
配方：背景=《合格提示词.txt》91-95 四段式骨架逐关改写（环境四维以 battle_environments.gd 为准）；
卡图=《精灵图nano_banana2_enemy_prompts_36》合格骨架改主体（朝右/白底/禁 3/4 视角）。<br>
尺寸：1376×768 原生；原始 jpg 备份在 _raw/。Flow 每次常出 2 张，备选一并附上。<br>
范围：背景 10 张 + 战斗卡 4 张 + 徽章 5 张 + 动画雪碧图 8 张 = 批4 重生成过的全部美术。<br>
<b>状态（2026-09-10）</b>：✅ 背景 10 张已部署 <code>assets/backgrounds/</code>（旧图备份 _art_backup）；
⏳ 待审查：战斗卡 4 + 徽章 5 + 动画 8（全身修正版）。审查页排序：待审项在前。</p>
{render_group(cards, SUBDIR_TITLES["战斗卡_批4"])}
{render_group(badges, "相位仪徽章（5 枚）")}
{render_anims(anims)}
{render_group(bgs, SUBDIR_TITLES["背景_批4"])}
</body></html>"""
    (ROOT / "审查.html").write_text(doc, encoding="utf-8")

    # ── 提示词档案 md ──
    lines = ["# 批4 Flow 重生成提示词档案（2026-09-10）", "",
             "> 真源：`tools/_tmp_flow_regen_b4.py` JOBS（与生成逐字一致）。审查页：`审查.html`。",
             "> 通道：`docs/基地重设计/flow_edit_tool.py --headed`（无头被 Google 风控卡死，有头 20-60s/张）。",
             "", "## 关键结论", "",
             "- 无头 Chrome 会被 Flow 风控「假生成」（按钮转圈 11 分钟无结果无错误卡）；有头秒过。",
             "- 1400+ 字英文提示词 Flow 可正常出图（AGENTS.md「>950 字限流」按字数不成立）。",
             "- 负面尾栏未随 prompt 提交（Flow 无独立负面通道，批4 §4-2 教训）；首段禁令句已含 no text/no grid/no split。",
             "- ⚠ 事故：基线快照早于点击导致 42~t1 产物整体错位一档（上一张结果被记到下一张名下），",
             "  已按日志时间戳链式改名归位 + 驱动修复（快照移到「按钮可用后、点击前」）。",
             "- bg_level_92 首版人形巨影穿帮，改「塔状剪影（建筑，非人形）」后重生成。", ""]
    for subdir, name, variants in drv.JOBS:
        lines.append(f"## {name}（{subdir}）")
        for vk in sorted(variants):
            lines.append(f"\n**变体 {vk}**：\n\n```text\n{variants[vk]}\n```")
        lines.append("")

    # 动画提示词（真源=generate_unit_animations.py UNITS，逐字）
    lines += ["## 动画雪碧图提示词（agnes-video-2.5-flash · keyframe 图生视频）", "",
              "> 通道说明：Flow 为图像通道，不支持「参考图→逐帧动画」任务；动画沿用原 agnes-video 管线",
              "（`tools/generate_unit_animations.py`，imgbb 传参考图→视频→ffmpeg 抽帧→白底转透明→雪碧图）。",
              "参考图：`资料/单位分帧动画/_ref/<unit>_white.jpg`（白底卡图，锁首帧外观）。", ""]
    try:
        import importlib.util
        _spec = importlib.util.spec_from_file_location(
            "gua", str(ROOT.parent.parent / "tools" / "generate_unit_animations.py"))
        _gua = importlib.util.module_from_spec(_spec)
        _spec.loader.exec_module(_gua)
        for unit, anim in [("fut_inf_c96", "idle"), ("fut_inf_c96", "attack"),
                           ("ww2_arm_garand_para", "idle"), ("ww2_arm_garand_para", "attack")]:
            a = _gua.UNITS[unit]["anims"][anim]
            lines += [f"### {unit} / {anim}（{a['seconds']}s）", "", "```text", a["prompt"], "```", ""]
    except Exception as exc:
        lines += [f"（动画提示词读取失败：{exc}；真源见 tools/generate_unit_animations.py UNITS）", ""]
    (ROOT / "提示词档案.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"OK → {ROOT / '审查.html'}")
    print(f"OK → {ROOT / '提示词档案.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
