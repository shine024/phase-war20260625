# -*- coding: utf-8 -*-
"""fam44 rest 帧手术 v3（2026-10-07「检查炮管长短」判定后）：
锚（std_R6_white）与 f2 链血统的炮管结构性不同，832 归一后炮口肉眼可见长短不齐。
定案：格1/6 改用 f2 本体去火光去烟的 rest 帧——六格单血统。

v2 教训（已废弃）：box2 的 lum>=150 擦除把炮口罩圈去火光后的灰糊连钢带啃成白洞；
GLOW_BOX x800 截线切在炮塔上产生暖色接缝。
v3 定案：
  ① 抹烟：F2_SMOKE_WIPE 白矩形 + 下沿 y830-900 浅灰擦除（车体像素=0 已遥测）
  ② 去火光区收窄 x<762（炮塔 x>=762 保持 f2 原样=与格2-5 同血统）
  ③ 口面几何重建：火光把口罩左端面完全覆盖，去火光后只剩灰糊——
     从 x677 参考列取口罩竖直截面，渐变填充口面带 x648-664（缘部 ×0.82 压暗）
  ④ 口面周边灰糊擦除（左/上/下三框，lum>=150 & sat<25 → 白，深钢保留）
产出: ww1_mark4_rest_f1.png
"""
import sys

import numpy as np
from PIL import Image

S = ".godot/unit_review/img25_staging/"

SMOKE_WIPE = (30, 650, 540, 830)     # 烟带（同 _fam44_smoke_transplant.F2_SMOKE_WIPE）
SMOKE_RECT2 = (540, 745, 640, 872)   # 烟带右延（SMOKE_WIPE 右侧残团；止于口面带前 8px）
UNDER_BOX = (30, 830, 540, 900)      # 烟带下沿残留（v2 三轮实证框内车体像素=0）
GLOW_BOX = (560, 690, 762, 880)      # 炮管去火光邻域（x<762，炮塔不碰）
FACE_FILL = (648, 677)               # 口面重建填充带 [x0, x1)——盖住火光核心白槽(663-675)
REF_COL = 677                        # 口罩参考截面列
MUSH_A = (612, 752, 650, 842)        # 口面左侧灰糊
MUSH_UP = (640, 745, 726, None)      # 口罩上方灰糊（y1=口罩顶-2 运行时定）
MUSH_DN = (640, None, 726, 872)      # 口罩下方灰糊（y0=口罩底+3 运行时定）


def light_wipe(a, box, lum, sat):
    x0, y0, x1, y1 = box
    m = (lum >= 150) & (sat < 25)
    m[y0:y1, x0:x1] &= True
    a[m[y0:y1, x0:x1] ] = 255  # noqa - 见下：仅在框内置白


def main():
    im = Image.open(S + "ww1_mark4_chainR1_f2.png").convert("RGB")
    for bx in (SMOKE_WIPE, SMOKE_RECT2):
        im.paste(Image.new("RGB", (bx[2] - bx[0], bx[3] - bx[1]), (255, 255, 255)),
                 bx[:2])
    a = np.asarray(im).astype(np.float32)

    # ---- ① 下沿残絮擦除（浅灰→白，遥测框内车体像素）----
    lum_i = (a[..., 0] * 299 + a[..., 1] * 587 + a[..., 2] * 114)
    li = lum_i.astype(np.int32) // 1000
    sat_i = np.abs(a[..., 0] - a[..., 2]).astype(np.int32)
    x0, y0, x1, y1 = UNDER_BOX
    box = np.zeros(li.shape, bool)
    box[y0:y1, x0:x1] = True
    dark_cnt = int(((li < 150) & box).sum())
    tgt = box & (li >= 150) & (sat_i < 25)
    a[tgt] = 255.0

    # ---- ② 去火光（收窄到炮管区）----
    x0, y0, x1, y1 = GLOW_BOX
    win = a[y0:y1, x0:x1]
    R, G, B = win[..., 0], win[..., 1], win[..., 2]
    lum = (R * 299 + G * 587 + B * 114) / 1000.0
    warm = (R - B) > 8
    win[warm & (lum > 232)] = 255.0                      # 白底暖光晕→纯白
    body = warm & (lum <= 232)
    if body.any():
        g = np.clip(lum[body] * 0.78, 0, 185)            # 管身暖 tint→中性灰
        win[body, 0] = g
        win[body, 1] = g
        win[body, 2] = g
    a[y0:y1, x0:x1] = win

    ai = a.astype(np.int32)
    lum = (ai[..., 0] * 299 + ai[..., 1] * 587 + ai[..., 2] * 114) // 1000
    sat = np.abs(ai[..., 0] - ai[..., 2])

    # ---- ④a 口面左侧灰糊 ----
    x0, y0, x1, y1 = MUSH_A
    m = (lum >= 150) & (sat < 25)
    m[:y0, :] = False
    m[y1:, :] = False
    m[:, :x0] = False
    m[:, x1:] = False
    a[m] = 255.0

    # ---- ③ 口面几何重建：参考列截面 → 渐变填充 ----
    col = a[:, REF_COL]
    col_lum = lum[:, REF_COL]
    run_best, run_cur = (0, 0), 0
    for y in range(755, 841):
        if col_lum[y] < 200:
            run_cur += 1
            if run_cur > run_best[1] - run_best[0]:
                run_best = (y - run_cur + 1, y + 1)
        else:
            run_cur = 0
    yt, yb = run_best
    assert yb - yt >= 20, "ref col run too small: %s" % (run_best,)
    for x in range(FACE_FILL[0], FACE_FILL[1]):
        k = 0.82 + 0.18 * (x - FACE_FILL[0]) / (FACE_FILL[1] - 1 - FACE_FILL[0])
        a[yt:yb, x] = col[yt:yb] * k

    # ---- ④b/c 口罩上/下灰糊（缘部留 2-3px 安全边）----
    m = (lum >= 150) & (sat < 25)
    m_up = m.copy()
    m_up[MUSH_UP[1]:yt - 1, MUSH_UP[0]:MUSH_UP[2]] = False
    m_up[:MUSH_UP[1], :] = False
    m_up[yt:, :] = False
    m_up[:, :MUSH_UP[0]] = False
    m_up[:, MUSH_UP[2]:] = False
    a[m_up] = 255.0
    m_dn = m.copy()
    m_dn[:yb + 3, :] = False
    m_dn[MUSH_DN[3]:, :] = False
    m_dn[:, :MUSH_DN[0]] = False
    m_dn[:, MUSH_DN[2]:] = False
    a[m_dn] = 255.0

    out = Image.fromarray(a.astype(np.uint8))
    out.save(S + "ww1_mark4_rest_f1.png")
    out.crop((30, 620, 1100, 1000)).save(S + "_dbg_rest_local3.png")
    out.crop((540, 690, 880, 880)).resize((340 * 3, 190 * 3), Image.NEAREST)\
        .save(S + "_dbg_muzzle_rest_v3.png")
    print("OK rest v3  collar y[%d,%d) h=%d  underbox_dark=%d"
          % (yt, yb, yb - yt, dark_cnt))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
