# -*- coding: utf-8 -*-
"""ww2_inf_panzerschrek 程序合成法（用户拍板：车体不再 API 生成，火光/烟用既有素材叠加）。
车体=镜像卡图书挡直贴（像素级零漂移——变形主诉终极解）,
f2 蓄势(下压+微后) / f3 击发(flame_star 焰贴炮口+后坐) / f4 后坐(白烟+深后坐) / f5 归稳(回位+余烬)。
素材: assets/effects/particle_textures/{flame_star,smoke_puff_light,spark_ember}.png
用法: python tools/api_sprite_pipeline/pz_comp.py
"""
import os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.argv = [sys.argv[0]]

FS = 256
UID = "ww2_inf_panzerschrek"
OUT = os.path.join(WS, ".godot", "unit_review", "api_" + UID)
PT = os.path.join(WS, "assets", "effects", "particle_textures")
FOOT = 8
MUZZLE = (104, 126)         # 书挡炮管尖(8倍标尺目验定: 管身y125~128, 尖x104)
SHIFT_FIRE = (2, 1)         # f3 车体位移 (右, 下) = 后坐
SHIFT_REC = (4, 2)          # f4 深后坐
SHIFT_BRACE = (1, 1)        # f2 蓄势微压
FLASH_SIZE = 120            # 炮口焰尺寸 px(球形爆焰)
FLASH_OFF = (-36, 2)        # 焰心在管尖左侧口外, 主焰团中心对管身延长线(上部火舌外溅=素材形状)


def book_card():
    card = Image.open(os.path.join(WS, "assets/card_icons/player/vis_player_010.png")).convert("RGBA")
    card = card.transpose(Image.FLIP_LEFT_RIGHT).crop(card.getbbox())
    s = int(FS * 0.55) / card.height
    c2 = card.resize((int(card.width * s), int(FS * 0.55)), Image.LANCZOS)
    bk = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    bk.paste(c2, ((FS - c2.width) // 2, FS - c2.height - FOOT), c2)
    return bk


def shift_body(base, dx, dy):
    """车体整体位移(右移=后坐, 下移=悬挂压缩)"""
    out = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    out.paste(base, (dx, dy), base)
    return out


def lighten(spr, k):
    """RGB 提亮 k 倍(clip), 烟在深底上显灰的修正"""
    a = np.asarray(spr).copy().astype(float)
    a[:, :, :3] = np.clip(a[:, :, :3] * k, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def overlay(fr, spr, center, scale, alpha=1.0, squash=None):
    """精灵缩放后以 center 为焰心叠加到帧; squash=(横,纵)比例拉伸(烟飘散压扁)"""
    sw, sh = int(spr.width * scale), int(spr.height * scale)
    if squash:
        sw, sh = int(sw * squash[0]), int(sh * squash[1])
    if (sw, sh) != (spr.width, spr.height):
        spr = spr.resize((max(1, sw), max(1, sh)), Image.LANCZOS)
    if alpha < 1.0:
        a = np.asarray(spr).copy()
        a[:, :, 3] = (a[:, :, 3] * alpha).astype(np.uint8)
        spr = Image.fromarray(a)
    out = fr.copy()
    out.paste(spr, (center[0] - spr.width // 2, center[1] - spr.height // 2), spr)
    return out


def main():
    bk = book_card()
    flash = Image.open(os.path.join(PT, "muzzle_light.png")).convert("RGBA")
    flash = flash.crop((0, 0, flash.width, int(flash.height * 0.78)))  # 裁下部火舌(防滴流垂到车头)
    smoke = lighten(Image.open(os.path.join(PT, "smoke_puff_light.png")).convert("RGBA"), 1.5)
    ember = Image.open(os.path.join(PT, "spark_ember.png")).convert("RGBA")
    charge = Image.open(os.path.join(PT, "spark_energy.png")).convert("RGBA")
    # f1/f6 书挡
    f1 = bk
    # f2 蓄势: 微压+微后 + 炮口蓝色蓄能电光(贴单位电光纹设定)
    f2 = shift_body(bk, *SHIFT_BRACE)
    f2 = overlay(f2, charge, (MUZZLE[0] - 2, MUZZLE[1] + 4), 20 / charge.width, alpha=0.85)
    # f3 击发: 后坐 + 球形爆焰以管尖为中心炸开(主焰团横在炮口)
    f3 = shift_body(bk, *SHIFT_FIRE)
    fc = (MUZZLE[0] + SHIFT_FIRE[0] + FLASH_OFF[0], MUZZLE[1] + SHIFT_FIRE[1] + FLASH_OFF[1])
    f3 = overlay(f3, flash, fc, FLASH_SIZE / flash.width)
    # f4 后坐: 深后坐 + 白烟在炮口前方飘(烟右缘轻触管尖) + 余烬点
    f4 = shift_body(bk, *SHIFT_REC)
    sc = (MUZZLE[0] + SHIFT_REC[0] - 28, MUZZLE[1] + SHIFT_REC[1] - 2)
    f4 = overlay(f4, smoke, sc, 58 / smoke.width, alpha=0.85, squash=(1.35, 0.75))
    f4 = overlay(f4, ember, (MUZZLE[0] + SHIFT_REC[0] - 40, MUZZLE[1] + SHIFT_REC[1] - 2),
                 12 / ember.width, alpha=0.8)
    # f5 归稳: 车体回位 + 炮口余烬(刚打完的余星, 区分于 f1)
    f5 = overlay(bk, ember, (MUZZLE[0] - 20, MUZZLE[1] + 2), 10 / ember.width, alpha=0.7)
    order = [f1, f2, f3, f4, f5, f1]
    os.makedirs(os.path.join(OUT, "frames_comp"), exist_ok=True)
    for i, fr in enumerate(order, 1):
        fr.save(os.path.join(OUT, "frames_comp", "f%d.png" % i))
    sheet = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    for i in range(6):
        sheet.paste(Image.open(os.path.join(OUT, "frames_comp", "f%d.png" % (i + 1))), (i * FS, 0))
    sheet.save(os.path.join(OUT, "sheet_attack_comp.png"))
    old = Image.open(os.path.join(WS, "assets/effects/unit_anims/ww2_inf_panzerschrek/sheet_attack.png")).convert("RGBA")
    cv = Image.new("RGBA", (FS * 6, FS * 2 + 8), (16, 20, 24, 255))
    for i in range(6):
        cv.paste(old.crop((i * FS, 0, (i + 1) * FS, FS)), (i * FS, 0))
    cv.paste(sheet, (0, FS + 8))
    cv.save(os.path.join(OUT, "strip_comp_vs_old.png"))
    print("done comp")


if __name__ == "__main__":
    main()
