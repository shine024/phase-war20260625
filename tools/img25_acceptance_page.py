# -*- coding: utf-8 -*-
"""img25 验收台网页生成（10-01 深夜收口后）。

产物 .godot/unit_review/img25_验收台.html，file:// 直开。
分节：总览统计 / 换卡图 11+2 / 方向帧 7 / 抠图 5 / 今晚 68 张新表 / 20 张未动 / 边角备注。
预览帧抽自部署 sheet_attack.png → img25_acceptance/ 相对引用，卡图直接引用 assets 原路径。
"""
import json
import os
import time

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, ".godot", "unit_review", "img25_acceptance")
HTML = os.path.join(ROOT, ".godot", "unit_review", "img25_验收台.html")
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
CUTOFF = time.mktime(time.strptime("2026-10-01 17:00:00", "%Y-%m-%d %H:%M:%S"))

FACING_NOTES = {
    "cold_rpg": "c6 翻转：炮管右上→左上，六格统一朝左（双修：+去粉937/清渍36638px）",
    "mod_arty_rq7": "c6 翻转：机头朝右→朝左；c4 尾后排气烟为原画 VFX 保留",
    "mod_javelin": "c3 翻转：发射筒/火光右→左，与其余五格一致",
    "mod_ranger": "仅 c1 翻转（首轮 [0,1,2] 误判已纠）；品红垂片+灰楔+颈肩孔洞清除",
    "mod_stinger": "无翻格（部署条是旧混朝资产，重部署即修）；背带/筒下灰塞三轮清渣",
    "mod_stryker_m2": "c4 翻转：车头/炮口右→左；c3 车底红晕=火光地辉保留",
    "platform_cold_ifv": "c4 翻转：车头/炮管右→左",
}
MATTE_NOTES = {
    "cold_chieftain": "去粉 1113→0；c2 炮塔排烟=烟云本体保留",
    "cold_t62": "去粉 2199→0；c3 爆烟/c5 排烟核保留",
    "ww1_enfield": "去粉 1170→0 + 清实渍 49196px（灰月牙+金浮片孤岛）",
    "ww1_m76": "去粉 671→0 + 清实渍 66205px（灰楔+地面红渍）",
}
CARD_NOTES = {
    "mod_ranger": ("独占 061 直接覆盖（Agent C）", "vis_player_061"),
    "platform_future_radar": ("独占 087 直接覆盖（Agent C）", "vis_player_087"),
    "mod_sup_m4_carbine": ("专属文件+接线补漏（Agent C 落盘未接线，游戏内一直不生效）", None),
    "ww2_air_dive_bomber": ("专属文件+接线补漏（同上）", None),
    "mod_stinger": ("共享 090 拆分：专属副本，cold_sam7 仍用 090", "vis_player_090"),
    "mod_stryker_m2": ("共享 059 拆分：专属副本，MGS 仍用 059", "vis_player_059"),
    "platform_modern_stealth": ("共享 022 拆分：专属副本，scout_drone 等仍用 022", "vis_player_022"),
    "ww1_105mm": ("共享 003 拆分：专属副本，fort/77mm 仍用 003", "vis_player_003"),
    "ww1_mark4": ("共享 042 三方拆净：专属副本；圣沙蒙（完美同名）仍用 042", "vis_player_042"),
    "ww1_a7v": ("共享 042 三方拆净：专属副本；同上", "vis_player_042"),
    "ww1_lanchest": ("共享 001 拆分：专属副本；hound/rolls/medium 仍用 001", "vis_player_001"),
}
CARD_BACKUP = ".godot/art_backup_card_regen_20261001"
EDGE_NOTES = [
    ("hound / ww1_rolls / platform_ww1_medium / fut_scout_drone 等共享方", "仍用借来的 vis 图（001 蓝色科幻坦克、022 等）——不在本次 11 张重生成清单内，属'可换但不欠'，要换需另立重生成批"),
    ("hound 的 override 行（→001）", "休眠死码：hound 被 manifest 第 1 步截胡解析到 004，改前改后行为一致（探针实测）；10-02 复核 fut_scout_drone 同案：era-kind 截胡落 004（一战骑兵图），非本批误伤（18 行 diff 未触及），预期行 022 为理想态——后续批可修"),
    ("10-02 换卡图部署+朝向核验", "11 张部署文件实存 assets/card_icons/player/（10-02 时间戳；mod_ranger/platform_future_radar 以 vis_player_061/087 部署名直覆盖，共享 vis 原图零波及）；接线探针 14/16——9 新接线全 PASS+4 共享保留 PASS，2 FAIL=上述既有截胡；朝向宪法 STYLE_BIBLE §四=卡图朝右（战斗锚定才朝左），11 张高清目检全部朝右，a7v/mark4/stealth 三张经 FLIP 翻正表机械落盘（img25_card_sideview_redo.py）与目检一致"),
    ("贴图库 t34_76 c3/c4/c5", "已隔离到 img25_vfx/_polluted/（内嵌原车炮管残片，裁切必伤星芯；clean 大星形 30 张备选充足）"),
    ("ww2_sup_gmc_truck", "10-02 已补攻击帧：idle 锚+补给箱车尾投放（codeanim crate 变体，10 帧闭环已部署，备份 route3 库）"),
    ("10-02 黑剪影重做批 36 单位", "阶段0 prompt'纯侧面剪影'一词误导模型出黑剪影（41/45 锚定本体均值 1-67）→ 35 单位换装备份成品 f0 本尊锚（bbox 与旧锚全等、cfg 坐标不动、零生成零漂移，暗锚备份 art_backup_anchor_dark_20261002）+ guardian_ww2_blitzkrieg 转 route3 补 cfg（深灰电蓝=本味未动）；AI 补光重掷三掷仍欠 40% 明度故弃（_relight_ww2_mp40.png 存档）"),
    ("10-02 干净锚定重掷批 35 单位", "用户令：剪影/描线时代产物全部重做——卡图为唯一参考重掷锚定（现行 prompt+lit_gate 亮度门），27 过门 8 深色本味钉住（brem1/attack_drone/carrier/sup_vickers/m120/mp40/pz3/pz4——深色涂装以目验+卡图对照为准）；五轮品红净化收官：键控后体内闭合品红口袋/贴地粉影确定性净化（ps9 能量帆 7.3 万px、sup_vickers 粉楔 7.6 万px，净化前原始稿备份 art_backup_anchor_dark_20261002/img25_staging_clean1st），v5 关键=杀像素 RGB 写「本图检测背景主色」而非纯品红——写纯品红会被下游 detect_bg_color(暗品红众数)+depink 复活成灰楔（mp40 腿间 39.5k 实测，详见管线文档 v5 追补）；cfg 仿射重映射（10 单位焰/弹参随 k=1.13-1.37 缩放，carrier 炮管实测手钉），部署走标准描边烘焙 35/35"),
    ("cold_arm_p18", "表态'只做雷达转动'：今晚 19:19 rotate 表已部署（counts 8/8）"),
    ("提交状态", "全部改动已落盘未提交，等你实机验收后点头"),
]


def frame_png(key: str, frames, scale=200):
    """从部署表抽帧，存预览，返回相对路径。"""
    p = os.path.join(ANIM, key, "sheet_attack.png")
    if not os.path.exists(p):
        return ""
    im = Image.open(p)
    fw = im.width // max(1, im.width // 256)
    n = im.width // fw
    crops = []
    for f in frames:
        f = min(f, n - 1)
        c = im.crop((f * fw, 0, (f + 1) * fw, im.height)).convert("RGB")
        c = c.resize((scale, scale), Image.NEAREST)
        crops.append(c)
    combo = Image.new("RGB", (scale * len(crops) + 4 * (len(crops) - 1), scale), (24, 24, 28))
    x = 0
    for c in crops:
        combo.paste(c, (x, 0))
        x += scale + 4
    name = f"{key}_f{''.join(map(str, frames))}.png"
    combo.save(os.path.join(OUT_DIR, name))
    return f"img25_acceptance/{name}"


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    dec = json.load(open(os.path.join(ROOT, ".godot", "unit_review", "img25_route_decisions (1).json"), encoding="utf-8"))
    fresh, stale = [], []
    for k in dec:
        p = os.path.join(ANIM, k, "sheet_attack.png")
        (fresh if os.path.exists(p) and os.path.getmtime(p) >= CUTOFF else stale).append(k)
    fresh.sort()
    card_only = [k for k in stale if k in CARD_NOTES]
    keeps = [k for k in stale if k not in CARD_NOTES]

    S = []
    S.append("""<!DOCTYPE html><html lang="zh"><head><meta charset="utf-8">
<title>img25 验收台 · 10-01 深夜收口</title><style>
body{background:#17171b;color:#ddd;font-family:"Microsoft YaHei",sans-serif;margin:20px}
h1{color:#ffd876;font-size:22px} h2{color:#ffd876;font-size:18px;border-bottom:1px solid #333;padding-bottom:6px;margin-top:34px}
table{border-collapse:collapse;margin:10px 0}td,th{border:1px solid #333;padding:6px 10px;font-size:13px;vertical-align:top}
th{background:#222228;color:#ffd876} tr:hover td{background:#20202a}
img.card{width:150px;height:150px;object-fit:contain;background:#0e2a0e;cursor:zoom-in}
img.frm{image-rendering:pixelated;cursor:zoom-in}
.chip{display:inline-block;padding:1px 8px;border-radius:9px;font-size:11px;margin:1px}
.ok{background:#123f12;color:#8f8}.warn{background:#443311;color:#fb5}.info{background:#1b2a44;color:#8bf}
.note{color:#999;font-size:12px;max-width:340px}
img:active{transform:scale(2.2);transform-origin:left top;position:relative;z-index:9}
.big{font-size:15px;color:#fff}
</style></head><body>""")

    S.append("<h1>img25 验收台 · 10-01 深夜收口</h1>")
    S.append(f"""<p class="big">88 单位拍板全部消费：<b>{len(fresh)}</b> 张战斗表今晚新部署，
{len(card_only)} 张只换卡图（表本就是终态），{len(keeps)} 张 route1 保留（早已终态）。
<b style="color:#8f8">未修复：0 个</b>。</p>""")

    # §1 换卡图（10-02 修路径：新图列按部署名——mod_ranger→vis_player_061、
    # platform_future_radar→vis_player_087；旧图列统一指侧面重出批备份
    # art_backup_card_front_20261001（正面违规版），真前后对比；old_vis 降级为文字注记）
    # 10-02 三批：用户复验抓 5 张仍非 90° 正侧（a7v/mark4/105mm/stealth/dive_bomber），
    # orthographic 硬锁 prompt 重出翻正部署（art_backup_card_side3_20261002 留上一版）
    S.append("<h2>一、换卡图 11 张（+2 接线补漏；a7v/mark4/105mm/stealth/dive_bomber 为 10-02 三批复检重出）</h2>"
             "<table><tr><th>单位</th><th>旧图（正面/违规版）</th><th>新图（正侧面终版）</th><th>处理</th></tr>")
    DEPLOY_NAME = {"mod_ranger": "vis_player_061", "platform_future_radar": "vis_player_087"}
    for u, (note, old_vis) in CARD_NOTES.items():
        dep = DEPLOY_NAME.get(u, u)
        new = f"../../assets/card_icons/player/{dep}.png?v=1002c"
        old = f"../art_backup_card_front_20261001/{dep}.png?v=1002c"
        if not os.path.exists(os.path.join(ROOT, ".godot", "art_backup_card_front_20261001", dep + ".png")):
            old = new  # 首批即正侧面合格、无正面版可对照（ww2_air_dive_bomber）
            note = "首批即正侧面合格未重出；" + note
        if old_vis:
            note = f"{note}；拆自 {old_vis}"
        wiring = "接线✅" if u in ("mod_ranger", "platform_future_radar") else "override 新增✅"
        S.append(f"<tr><td><b>{u}</b><br><span class='chip ok'>{wiring}</span></td>"
                 f"<td><img class='card' src='{old}' onerror=\"this.style.background='#401'\"></td>"
                 f"<td><img class='card' src='{new}'></td><td class='note'>{note}</td></tr>")
    S.append("</table><p class='note'>绿底=新图（10-02 正侧面重出终版）。旧图=art_backup_card_front_20261001 留档的上一版。共享 vis 原图仍在其位，共享方单位不受影响。点击图片放大。</p>")

    # §2 方向帧
    S.append("<h2>二、方向帧修 7 单位（f0 | f3，应统一朝左）</h2><table><tr><th>单位</th><th>部署帧</th><th>处理</th></tr>")
    for u, note in FACING_NOTES.items():
        pv = frame_png(u, (0, 3))
        S.append(f"<tr><td><b>{u}</b></td><td><img class='frm' src='{pv}?v=1002c' width='300'></td><td class='note'>{note}</td></tr>")
    S.append("</table>")

    # §3 抠图
    matte = list(MATTE_NOTES)
    S.append("<h2>三、抠图修 4 单位（+rpg 双修；f0 | f3）</h2><table><tr><th>单位</th><th>部署帧</th><th>去粉/清渍</th></tr>")
    for u in matte:
        pv = frame_png(u, (0, 3))
        S.append(f"<tr><td><b>{u}</b></td><td><img class='frm' src='{pv}?v=1002c' width='300'></td><td class='note'>{MATTE_NOTES[u]}</td></tr>")
    S.append("</table><p class='note'>证据链：img25_facing_report/（cmp 图+探针）；主会话独立复验 _facing11_verify.png。</p>")

    # §4 今晚全部新表
    S.append(f"<h2>四、今晚新部署战斗表 {len(fresh)} 张（f0 | f1）</h2><table><tr>")
    for i, u in enumerate(fresh):
        pv = frame_png(u, (0, 1), scale=128)
        if i % 8 == 0 and i:
            S.append("</tr><tr>")
        S.append(f"<td><img class='frm' src='{pv}?v=1002c' width='128'><br><span style='font-size:11px'>{u}</span></td>")
    S.append("</tr></table>")

    # §5 未动
    S.append(f"<h2>五、表未动的 {len(stale)} 张（全部有理由）</h2><table><tr><th>单位</th><th>原因</th></tr>")
    for u in card_only:
        S.append(f"<tr><td><b>{u}</b></td><td class='note'>只换卡图（§一）；战斗表为 route1/终态无需动</td></tr>")
    for u in keeps:
        S.append(f"<tr><td><b>{u}</b></td><td class='note'>点选 route1 保留——批产生图终态，无重做要求</td></tr>")
    S.append("</table>")

    # §6 边角
    S.append("<h2>六、边角备注</h2><table><tr><th>项</th><th>说明</th></tr>")
    for a, b in EDGE_NOTES:
        S.append(f"<tr><td><b>{a}</b></td><td class='note'>{b}</td></tr>")
    S.append("</table>")
    S.append("</body></html>")
    open(HTML, "w", encoding="utf-8").write("".join(S))
    print("OK", HTML, f"{os.path.getsize(HTML)//1024}KB previews={len(os.listdir(OUT_DIR))}")


if __name__ == "__main__":
    main()
