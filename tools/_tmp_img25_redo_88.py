# -*- coding: utf-8 -*-
"""img25 重做清单 88 单位全量批量（docs/img25_重做清单_20260929.md，2026-09-29 用户指令：
待机+攻击双动画重做并部署进项目）。

- 参考图 = 清单指定卡图（情报面板同链）；player 卡图按惯例朝右→镜像朝左，enemy 卡图朝左直用
- 风格 C-only（首尾锚定）+ 布局导图双图输入；无黑描边体积感画风
- 防御性单位（fort/radar/护盾）attack 用轻动作变体：扫描波/能量微光，不强求开火火光
- 断点续跑：raw 已存在即跳过生成；候选已存在即跳过切格
- 产物：img25_staging/<key>_attackC.png / <key>_idle.png + preview（候选，不直接写 assets/）
- 部署由 --deploy 阶段单独执行（回文拼帧 attack12/idle8，counts 不动）

用法：
  python tools/_tmp_img25_redo_88.py              # 阶段1：生成+候选（长跑，可中断续跑）
  python tools/_tmp_img25_redo_88.py --deploy     # 阶段2：备份+部署+（描边烘焙另行）
  python tools/_tmp_img25_redo_88.py --key 0      # 指定起始 key（分片接力用）
"""
import base64
import io
import json
import os
import sys
import time

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import img25_sprite_trial as P

FS = P.FS
OUT = P.OUT
CARD = os.path.join(ROOT, "assets", "card_icons")
START_KEY = ""
for i, a in enumerate(sys.argv):
    if a == "--key" and i + 1 < len(sys.argv):
        START_KEY = sys.argv[i + 1]

# (key, 卡图相对 card_icons, 武器, 通道能量?, 防御性?)
# 通道能量 = 清单"能量"列 → 火光蓝白；防御性 = 堡垒武器/护盾类 → attack 轻动作
U = [
    ("cold_ak47", "player/vis_player_050.png", "步枪", False, False),
    ("cold_arm_p18", "player/cold_arm_p18.png", "坦克主炮", False, False),
    ("cold_arty_brem1", "player/cold_arty_brem1.png", "榴弹炮", False, False),
    ("cold_bradley", "player/vis_player_053.png", "坦克主炮", False, False),
    ("cold_chieftain", "player/vis_player_055.png", "武器开火", False, False),
    ("cold_f4", "player/vis_player_056.png", "机载武器", False, False),
    ("cold_fort_radar", "player/vis_player_077.png", "堡垒武器", False, True),
    ("cold_inf_m60", "player/vis_player_051.png", "步枪", False, False),
    ("cold_m1", "player/vis_player_055.png", "坦克主炮", False, False),
    ("cold_m14", "player/vis_player_051.png", "步枪", False, False),
    ("cold_m60t", "player/vis_player_055.png", "武器开火", False, False),
    ("cold_mig21", "player/vis_player_056.png", "机载武器", False, False),
    ("cold_rpg", "player/vis_player_046.png", "反坦克武器", False, False),
    ("cold_rpk", "player/vis_player_045.png", "重机枪", False, False),
    ("cold_sam7", "player/vis_player_090.png", "武器开火", False, False),
    ("cold_t62", "player/vis_player_055.png", "坦克主炮", False, False),
    ("drop_phase_lance", "enemy/drop_phase_lance.png", "能量脉冲武器", True, False),
    ("fut_aa_hover", "player/vis_player_025.png", "机载武器", False, False),
    ("fut_arm_omega", "player/vis_player_070.png", "坦克主炮", False, False),
    ("fut_assault_mech", "player/vis_player_067.png", "武器开火", False, False),
    ("fut_attack_drone", "player/fut_attack_drone.png", "机载武器", False, False),
    ("fut_howitzer", "player/vis_player_060.png", "榴弹炮", False, False),
    ("fut_nano_drone", "player/fut_nano_drone.png", "机载武器", False, False),
    ("fut_space_fighter", "player/vis_player_093.png", "机载武器", False, False),
    ("fut_stealth_bomber", "player/vis_player_094.png", "机载武器", False, False),
    ("fut_stormcore", "player/vis_player_071.png", "能量脉冲武器", True, False),
    ("fut_sup_ps9", "player/fut_sup_ps9.png", "能量脉冲武器", True, True),
    ("guardian_cold_thunder", "player/vis_player_112.png", "能量脉冲武器", True, False),
    ("guardian_future_omega", "player/vis_player_114.png", "武器开火", False, False),
    ("guardian_ww2_blitzkrieg", "player/vis_player_111.png", "武器开火", False, False),
    ("mod_ah1", "player/vis_player_063.png", "机载武器", False, False),
    ("mod_ah64", "player/vis_player_063.png", "机载武器", False, False),
    ("mod_air_bomber", "player/mod_air_bomber.png", "机载武器", False, False),
    ("mod_arty_rq7", "player/mod_arty_rq7.png", "榴弹炮", False, False),
    ("mod_challenger2", "player/vis_player_062.png", "坦克主炮", False, False),
    ("mod_hummer_m2", "player/vis_player_058.png", "坦克主炮", False, False),
    ("mod_hummer_tow", "player/vis_player_058.png", "反坦克武器", False, False),
    ("mod_javelin", "player/vis_player_089.png", "反坦克武器", False, False),
    ("mod_leo2a6", "player/vis_player_062.png", "坦克主炮", False, False),
    ("mod_m1a2", "player/vis_player_062.png", "坦克主炮", False, False),
    ("mod_ranger", "player/vis_player_061.png", "武器开火", False, False),
    ("mod_stinger", "player/vis_player_090.png", "反坦克武器", False, False),
    ("mod_stryker_m2", "player/vis_player_059.png", "坦克主炮", False, False),
    ("mod_stryker_mgs", "player/vis_player_059.png", "重机枪", False, False),
    ("mod_sup_m4_carbine", "player/mod_sup_m4_carbine.png", "武器开火", False, False),
    ("mod_t90", "player/vis_player_055.png", "坦克主炮", False, False),
    ("mod_uh60", "player/vis_player_063.png", "机载武器", False, False),
    ("platform_cold_carrier", "player/vis_player_015.png", "机载武器", False, False),
    ("platform_cold_ifv", "player/vis_player_015.png", "坦克主炮", False, False),
    ("platform_cold_light", "player/vis_player_013.png", "武器开火", False, False),
    ("platform_cold_radar", "player/vis_player_017.png", "堡垒武器", False, True),
    ("platform_cold_scout", "player/vis_player_016.png", "武器开火", False, False),
    ("platform_future_radar", "player/vis_player_026.png", "堡垒武器", False, True),
    ("platform_modern_radar", "player/vis_player_020.png", "堡垒武器", False, True),
    ("platform_modern_stealth", "player/vis_player_022.png", "机载武器", False, False),
    ("platform_ww1_fort", "player/vis_player_003.png", "堡垒武器", False, True),
    ("platform_ww1_radar", "player/vis_player_004.png", "堡垒武器", False, True),
    ("platform_ww2_medium", "player/vis_player_007.png", "武器开火", False, False),
    ("vis_xeno_tripod", "enemy/vis_xeno_tripod.png", "生物能量攻击", True, False),
    ("ww1_105mm", "player/vis_player_003.png", "榴弹炮", False, False),
    ("ww1_37mm", "player/vis_player_088.png", "武器开火", False, False),
    ("ww1_a7v", "player/vis_player_042.png", "坦克主炮", False, False),
    ("ww1_enfield", "player/vis_player_037.png", "步枪", False, False),
    ("ww1_flame", "player/vis_player_036.png", "喷火器", True, False),
    ("ww1_lanchest", "player/vis_player_001.png", "武器开火", False, False),
    ("ww1_m76", "player/vis_player_039.png", "步枪", False, False),
    ("ww1_mark4", "player/vis_player_042.png", "坦克主炮", False, False),
    ("ww1_mg08", "player/vis_player_038.png", "重机枪", False, False),
    ("ww1_mgnest", "player/vis_player_038.png", "重机枪", False, True),
    ("ww1_saint", "player/vis_player_042.png", "武器开火", False, False),
    ("ww1_sup_vickers", "player/ww1_sup_vickers.png", "重机枪", False, False),
    ("ww1_vickers", "player/vis_player_038.png", "重机枪", False, False),
    ("ww2_air_bomber", "player/ww2_air_bomber.png", "机载武器", False, False),
    ("ww2_air_dive_bomber", "player/ww2_air_dive_bomber.png", "机载武器", False, False),
    ("ww2_air_me262", "player/ww2_air_me262.png", "机载武器", False, False),
    ("ww2_air_meteor_e", "player/ww2_air_meteor_e.png", "机载武器", False, False),
    ("ww2_arm_tiger", "player/vis_player_008.png", "坦克主炮", False, False),
    ("ww2_browning", "player/vis_player_045.png", "重机枪", False, False),
    ("ww2_is2", "player/vis_player_008.png", "坦克主炮", False, False),
    ("ww2_m120", "player/vis_player_011.png", "榴弹炮", False, False),
    ("ww2_mg42", "player/vis_player_045.png", "重机枪", False, False),
    ("ww2_mp40", "player/vis_player_043.png", "冲锋枪", False, False),
    ("ww2_ppsh", "player/vis_player_043.png", "冲锋枪", False, False),
    ("ww2_pz3", "player/vis_player_007.png", "坦克主炮", False, False),
    ("ww2_pz4", "player/vis_player_007.png", "坦克主炮", False, False),
    ("ww2_sup_gmc_truck", "player/ww2_sup_gmc_truck.png", "武器开火", False, False),
    ("ww2_t34_76", "player/vis_player_007.png", "坦克主炮", False, False),
    ("ww2_t34_85", "player/vis_player_007.png", "坦克主炮", False, False),
]

ENEMY_KEYS = {"drop_phase_lance", "vis_xeno_tripod"}

# QC 目检（2026-09-30 全 88 单位 8 张 grid + idle_bad）救援表：
# skip=废格用 f0 兜底；flip=该格水平镜像后使用
SKIP_CELLS = {
    "fut_arm_omega": {"attackC": {4, 5}},
    "guardian_future_omega": {"attackC": {3}},
    "mod_hummer_tow": {"attackC": {1, 4, 5}},
    "mod_stryker_mgs": {"attackC": {0, 1, 5}},
    "mod_uh60": {"attackC": {4, 5}},
    "platform_cold_light": {"attackC": {3}},
    "platform_modern_radar": {"attackC": {3}},
    "mod_ranger": {"attackC": {3, 4, 5}},
    "ww1_a7v": {"attackC": {0, 4, 5}},
    "ww2_sup_gmc_truck": {"attackC": {1}},
    "cold_mig21": {"idle": {3, 4, 5}},
    "fut_space_fighter": {"idle": {5}},
    "cold_rpk": {"idle": {1, 2}},
    "mod_air_bomber": {"idle": {4}, "attackC": {4, 5}},
}
# enemy 卡图朝右例外：f0 也镜像朝左（与生成帧一致）
FORCE_FLIP_F0 = {"drop_phase_lance"}
FLIP_CELLS = {
    "mod_stryker_m2": {"attackC": {4, 5}},
    # drop 生成帧跟卡图朝右（Image1 拉力），逐格镜像成朝左 + f0 同镜像(FORCE_FLIP_F0)
    "drop_phase_lance": {"attackC": {0, 1, 2, 3, 4, 5}, "idle": {0, 1, 2, 3, 4, 5}},
}
# skip 后生成帧不足 6 时的自定义回文序（deploy 拼帧用，缺省 attack12/idle8 标准序）
PAL_OVERRIDE = {
    ("cold_mig21", "idle"): [0, 1, 2, 1, 0, 1, 2, 1],
    ("fut_space_fighter", "idle"): [0, 1, 2, 3, 4, 3, 2, 1],
}

# 废单重掷：英文主体锁死（中文短词在英文模板里锁不住身份，战机/直升机易变人）
SUBJECT_EN = {
    "cold_f4": "the F-4 Phantom II twin-engine jet fighter shown in Image 1, same grey-green camouflage paint, wings, twin tail and shape",
    "cold_rpk": "the heavy machine gun with its gunner shown in Image 1, kneeling behind the sandbag emplacement, no other person",
    "cold_arm_p18": "the self-propelled gun vehicle shown in Image 1, same hull, gun and camouflage",
    "drop_phase_lance": "the alien phase-lance weapon platform shown in Image 1, same organic shape and colors",
    "fut_space_fighter": "the futuristic space fighter craft shown in Image 1, same hull, wings and glow",
    "fut_sup_ps9": "the futuristic shield generator device shown in Image 1, same rounded emitter and colors, a static device with no crew",
    "mod_ah64": "the AH-64 Apache attack helicopter shown in Image 1, same dark green hull, stub wings and rotor",
    "mod_air_bomber": "the jet bomber aircraft shown in Image 1, same swept wings and grey paint",
    "mod_arty_rq7": "the RQ-7 reconnaissance drone aircraft shown in Image 1, same straight wings and pusher prop",
    "mod_challenger2": "the Challenger 2 main battle tank shown in Image 1, same hull, turret and sand paint",
    "platform_cold_scout": "the armored scout vehicle shown in Image 1, same wheeled hull and turret",
    "ww2_air_me262": "the Me 262 twin-engine jet fighter aircraft shown in Image 1, same WWII camouflage and shape",
    "ww2_air_meteor_e": "the Gloster Meteor twin-engine jet fighter shown in Image 1, same silver paint and twin engines",
    "ww2_arm_tiger": "the WWII medium tank shown in Image 1, same hull, turret and olive paint",
    "ww1_lanchest": "the blue-grey WWI armored car shown in Image 1, same body, turret and wheels, floating in empty white with nothing beneath its wheels",
    "mod_stinger": "the single soldier with the shoulder-fired missile launcher shown in Image 1, the same green camouflage uniform in every frame, never a different uniform color",
}


def load_card(rel):
    """卡图 → 透明 f0(200高/248宽锚,脚底235) + 白底 512 参考图(250高锚,生成输入不变)。
    player 朝右镜像朝左，enemy 直用。"""
    im = Image.open(os.path.join(CARD, rel)).convert("RGBA")
    a = np.asarray(im)
    if a.shape[2] < 4 or int((a[:, :, 3] > 8).sum()) == 0:
        im = im.convert("RGB")  # 无 alpha 的白底 JPG 类
        arr = np.asarray(im).astype(np.int16)
        nw = ~((arr[:, :, 0] > 235) & (arr[:, :, 1] > 235) & (arr[:, :, 2] > 235))
        ys, xs = np.where(nw)
        im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)).convert("RGBA")
    else:
        ys, xs = np.where(a[:, :, 3] > 8)
        if len(xs):
            im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    base = os.path.splitext(os.path.basename(rel))[0]
    if rel not in ENEMY_KEYS and not rel.startswith("enemy/"):
        im = im.transpose(Image.FLIP_LEFT_RIGHT)  # player 卡图朝右 → 真身朝左
    elif base in FORCE_FLIP_F0:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)  # enemy 朝右例外：镜像朝左与生成帧一致
    w, h = im.size

    def _sc(tall, wide):
        s = min(tall / max(1, h), wide / max(1, w))
        return im.resize((max(1, int(w * s)), max(1, int(h * s))), Image.LANCZOS)

    im2 = _sc(200.0, 248.0)  # f0 锚：与生成帧统一（78% 格高，头顶留边）
    f0 = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    f0.alpha_composite(im2, ((FS - im2.width) // 2, FS - im2.height - 21))
    im3 = _sc(250.0, 250.0)  # ref 锚：生成输入保持原状（已验证）
    ref = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
    ref.alpha_composite(im3, ((512 - im3.width) // 2, 512 - im3.height - 36))
    return f0, ref


def uri(img, size=512):
    t = img.convert("RGB")
    if max(t.size) != size:
        t = t.resize((size, size), Image.LANCZOS)
    buf = io.BytesIO()
    t.save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


DEF_FLASH = "a faint short pulse of light at its weapon/emitter, very small and brief"
KIN_FLASH = "a small orange-yellow muzzle flash at the muzzle tip only"
ENE_FLASH = "a small blue-white energy glow at the emitter only"


def attack_prompt(subject, weapon, energy, defensive):
    flash = ENE_FLASH if energy else KIN_FLASH
    if defensive:
        seq = """Frame 1: neutral ready state, no glow.
Frame 2: begins to activate, antennas/dish/emitter slightly alive, still no glow.
Frame 3: emitting - %s.
Frame 4: the pulse fades, a faint wisp remains.
Frame 5: settling back, only faint embers remain.
Frame 6: return to the calm ready state, identical to Frame 1, no effects.""" % flash
    else:
        seq = """Frame 1: neutral ready stance, weapon held as in Image 1, no muzzle flash.
Frame 2: leans slightly into the weapon, firmer grip, still no flash.
Frame 3: firing frame - %s.
Frame 4: follow-through, slight recoil, flash gone, a thin smoke wisp near the muzzle.
Frame 5: recoil settling, body easing back, no flash, no smoke.
Frame 6: return to the calm ready stance, identical to Frame 1, no effects.""" % flash
    return """Intended use:
Create a 6-frame 3x2 spritesheet for a side-view 2D game character attack animation.

Input images:
Image 1 is the identity anchor for %s. Preserve the exact identity, colors, proportions, silhouette, palette, and left-facing direction.
Image 2 is the 3x2 spritesheet layout guide. Use it only as a layout guide for six equal cells; its repeated pose is not an action reference.

Primary request:
Generate the same subject using its %s, facing LEFT in exact side view for every frame. Any flash is small and brief; the subject stays on a stable ground baseline.

Canvas and layout:
- wide 16:9 PNG spritesheet
- 3 columns by 2 rows, six equal cells
- frame order: left to right across the top row, then left to right across the bottom row
- subject fully visible in each cell
- consistent scale, camera, and ground baseline across all frames

Background: pure flat white fills the entire canvas edge to edge, above, below and between all six cells; the six subjects float freely in empty white space with nothing beneath or behind them; the only pixels in the whole image are the six subjects, the one small flash, and white.

Frame sequence:
%s

Style:
- 2D game sprite, clean volumetric color painting, no black outline, no contour line
- crisp edges, consistent lighting and palette, readable silhouette

Constraints:
- no direction change; the subject faces LEFT in every frame, never right, never toward the camera
- no camera angle change; the exact same pure side view as Image 1 in every frame, never top-down, never 3/4
- the only content is the six identical subjects, the single flash, and flat white; any other object, texture band, ground, label or border is a defect
- do not crop any part of the subject
- do not merge cells or create comic panels
- do not recenter or rescale the subject differently per frame
""" % (subject, weapon, seq)


def idle_prompt(subject):
    return """Intended use:
Create a 6-frame 3x2 spritesheet for a side-view 2D game character idle animation.

Input images:
Image 1 is the identity anchor for %s. Preserve the exact identity, colors, proportions, silhouette, palette, and left-facing direction.
Image 2 is the 3x2 spritesheet layout guide. Use it only as a layout guide for six equal cells; its repeated pose is not an action reference.

Primary request:
Generate the same subject standing idle, facing LEFT in exact side view for every frame. The six frames are almost identical, with only a very subtle idle motion (breathing or engine vibration, no larger than two percent of the subject height).

Canvas and layout:
- wide 16:9 PNG spritesheet
- 3 columns by 2 rows, six equal cells
- frame order: left to right across the top row, then left to right across the bottom row
- subject fully visible in each cell
- consistent scale, camera, and ground baseline across all frames

Background: pure flat white fills the entire canvas edge to edge, above, below and between all six cells; the six subjects float freely in empty white space with nothing beneath or behind them; the only pixels in the whole image are the six subjects and white.

Frame sequence:
Frame 1 through Frame 6: the same idle stance with only tiny variations, no weapon fire, no effects, no glow.

Style:
- 2D game sprite, clean volumetric color painting, no black outline, no contour line
- crisp edges, consistent lighting and palette, readable silhouette

Constraints:
- no direction change; the subject faces LEFT in every frame, never right, never toward the camera
- no camera angle change; the exact same pure side view as Image 1 in every frame, never top-down, never 3/4
- the only content is the six identical subjects and flat white; any other object, texture band, ground, label or border is a defect
- do not crop any part of the subject
- do not merge cells or create comic panels
- do not recenter or rescale the subject differently per frame
""" % subject


def gen_payload(payload_path):
    # 双进程分片：AGNES_KEY_ONLY 锁定单 key，避免两进程同时抢 KEYS[0]
    only = os.environ.get("AGNES_KEY_ONLY")
    if only is not None:
        saved = P.KEYS
        P.KEYS = [saved[int(only) % len(saved)]]
        try:
            return P.gen_image(payload_path, "")
        finally:
            P.KEYS = saved
    return P.gen_image(payload_path, "")


def crop_candidate(key, tag, f0):
    """raw → 切格 → 统一缩放对齐 → 候选（6 帧含 f0 兜底 + SKIP/FLIP 救援）。返回状态串。"""
    rawp = os.path.join(OUT, "%s_%s_raw.png" % (key, tag))
    if not os.path.exists(rawp):
        return "no_raw"
    candp = os.path.join(OUT, "%s_%s.png" % (key, tag))
    if os.path.exists(candp):
        return "skip"
    sheet = Image.open(rawp).convert("RGB")
    cells = P.split_cells(sheet)
    mats = []
    for c in cells:
        m = None if c is None else P.flood_matte(c)
        m = None if m is None or P._is_blank(m) else P._drop_islands(m)
        mats.append(m)
    # 缩放锚：参考 f0 内容高（横长单位按宽 248 上限双约束）
    a = np.asarray(f0)
    ys, xs = np.where(a[:, :, 3] > 8)
    TH = int(ys.max() - ys.min() + 1)
    BASE = int(ys.max())
    cand = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    fh = P.body_hull(f0)
    skip = SKIP_CELLS.get(key, {}).get(tag, set())
    flip = FLIP_CELLS.get(key, {}).get(tag, set())
    for i in range(6):
        m = mats[i] if i < len(mats) else None
        if m is not None and i in flip:
            m = m.transpose(Image.FLIP_LEFT_RIGHT)
        if m is None or i in skip:
            cand.alpha_composite(f0, (i * FS, 0))
            continue
        a = np.asarray(m)
        ys, xs = np.where(a[:, :, 3] > 8)
        if len(ys) == 0:
            cand.alpha_composite(f0, (i * FS, 0))
            continue
        bd = m.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
        s2 = min(TH / float(bd.height), 248.0 / max(1, bd.width))
        nw, nh = max(1, int(round(bd.width * s2))), max(1, int(round(bd.height * s2)))
        bd = bd.resize((nw, nh), Image.LANCZOS)
        tmp = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        tmp.alpha_composite(bd, (FS // 2 - nw // 2, BASE - nh))
        gh = P.body_hull(tmp)
        if fh is not None and gh is not None:
            dx = int(round(fh[0] - gh[0]))
            dx = min(max(dx, -(FS - nw) // 2), (FS - nw) // 2)
        else:
            dx = 0
        cand.alpha_composite(tmp, (i * FS + dx, 0))
    cand.save(candp)
    flip = cand.transpose(Image.FLIP_LEFT_RIGHT)
    cv = Image.new("RGBA", (FS * 6, FS * 2 + 24), (24, 26, 32, 255))
    cv.alpha_composite(cand, (0, 0))
    cv.alpha_composite(flip, (0, FS + 24))
    cv.save(os.path.join(OUT, "%s_%s_preview.png" % (key, tag)))
    return "ok"


def run_unit(key, rel, weapon, energy, defensive):
    f0, ref = load_card(rel)
    gp = P.make_layout_guide(ref.convert("RGBA"), "%s_g" % key)
    imgs = [uri(ref), uri(Image.open(gp))]
    subject = SUBJECT_EN.get(key) or P.SUBJECT_OVERRIDES.get(key, P.subject_for(key))
    report = {}
    for tag, prompt in (("attackC", attack_prompt(subject, weapon, energy, defensive)),
                        ("idle", idle_prompt(subject))):
        rawp = os.path.join(OUT, "%s_%s_raw.png" % (key, tag))
        if not os.path.exists(rawp):
            pf = os.path.join(OUT, "%s_%s_payload.json" % (key, tag))
            open(pf, "w", encoding="utf-8").write(json.dumps({
                "model": "agnes-image-2.5-flash", "prompt": prompt,
                "size": "2K", "ratio": "16:9",
                "extra_body": {"image": imgs, "response_format": "b64_json"}}, ensure_ascii=False))
            raw = gen_payload(pf)
            if raw:
                open(rawp, "wb").write(raw)
                report[tag] = "gen"
            else:
                report[tag] = "gen_failed"
                continue
            time.sleep(4)
        else:
            report[tag] = "raw_cached"
        report[tag] += "|" + crop_candidate(key, tag, f0)
    return report


def deploy():
    """阶段2：备份 → 回文拼帧 → LANCZOS 256 → 覆盖 assets。counts 不动。"""
    from PIL import Image as I2
    bak = os.path.join(ROOT, ".godot", "art_backup_img25_redo_20260929")
    os.makedirs(bak, exist_ok=True)
    done, miss = [], []
    for (key, rel, weapon, energy, defensive) in U:
        d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
        if not os.path.isdir(d):
            miss.append(key)
            continue
        plans = {"attack": (12, PAL_OVERRIDE.get((key, "attack"),
                                                 [0, 1, 2, 3, 4, 5, 5, 4, 3, 2, 1, 0])),
                 "idle": (8, PAL_OVERRIDE.get((key, "idle"), [0, 1, 2, 3, 4, 5, 4, 3]))}
        okall = True
        for tag, (n, order) in plans.items():
            candp = os.path.join(OUT, "%s_%s.png" % (key, "attackC" if tag == "attack" else tag))
            if not os.path.exists(candp):
                okall = False
                break
            cand = Image.open(candp).convert("RGBA")
            frames = [cand.crop((i * FS, 0, (i + 1) * FS, FS)) for i in range(6)]
            sheet = Image.new("RGBA", (FS * n, FS), (0, 0, 0, 0))
            for i, fi in enumerate(order):
                sheet.alpha_composite(frames[fi], (i * FS, 0))
            dst = os.path.join(d, "sheet_%s.png" % tag)
            bdst = os.path.join(bak, key)
            os.makedirs(bdst, exist_ok=True)
            if os.path.exists(dst):
                I2.open(dst).convert("RGBA").save(os.path.join(bdst, "sheet_%s.png" % tag))
            # 候选已是 256 基准，直接部署；anim.json frame_size=256 不动
            sheet.save(dst)
        if okall:
            done.append(key)
        else:
            miss.append(key)
    print("部署完成 %d 个；缺候选 %d 个: %s" % (len(done), len(miss), ",".join(miss)))


if __name__ == "__main__":
    if "--deploy" in sys.argv:
        deploy()
        sys.exit(0)
    os.makedirs(OUT, exist_ok=True)
    n = len(U)
    for idx, (key, rel, weapon, energy, defensive) in enumerate(U):
        if START_KEY and idx < [u[0] for u in U].index(START_KEY):
            continue
        t0 = time.time()
        try:
            r = run_unit(key, rel, weapon, energy, defensive)
        except Exception as e:
            r = {"error": str(e)[:120]}
        print("[%d/%d] %s %s (%.0fs)" % (idx + 1, n, key, json.dumps(r, ensure_ascii=False), time.time() - t0), flush=True)
    print("IMG25_REDO_BATCH_DONE")
