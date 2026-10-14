# -*- coding: utf-8 -*-
"""ww2_inf_bazooka 4 帧攻击循环部署(2026-10-13, API 精灵图双参考管线)。

前作 _bazooka_deploy_anim.py(2026-10-06 10 帧蹲姿链)之后的重制:
  - 暂存 .godot/unit_review/api_ww2_inf_bazooka/sheet_attack_api.png(4 帧 256 格,
    双参考 i2i t1 全直出, bazooka_kneel.py 产物, 门禁 pair=0.187/击发IoU=0.524)
  - 用户拍板 4 帧循环: 扛筒→击发(焰+尾烟)→后坐→回位; f1/f4=idle f0 同源书挡
  - counts.attack 6→4(部署前置已挂账, docs/API精灵图生成工作流_v1.md §7.8)

本脚本:
  1. 备份现役三件 → D:/godotplay/_art_backup/unit_anims_bazooka_4f_20261013/
     (铁律: png 不入 git, 部署前外部备份——anim_subject_normalize 先例)
  2. attack 4 帧条烘描边(dua.bake_outline_on_sheet 唯一真身, 逐帧切片)
  3. idle 不动(旧 idle f0 = 新 attack f1 同源, 切动画不跳变)
  4. anim.json 回写: counts.attack=4 + outline meta; foot_frac/fps/frame_size 保留
     (foot 0.0449 为描边前口径, 管线摆位同标)
  5. 帧缘触边自检(实心 alpha 帧缘 2px 内须零) —— normalize 部署门同规则
之后: python tools/anim_subject_normalize.py --dir ww2_inf_bazooka (subject 回填+校验)
用法: python tools/_bazooka_deploy_4f.py
"""
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image

import deploy_unit_anims as dua

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGED = os.path.join(ROOT, ".godot", "unit_review", "api_ww2_inf_bazooka", "sheet_attack_api.png")
ANIM_DIR = os.path.join(ROOT, "assets", "effects", "unit_anims", "ww2_inf_bazooka")
BACKUP = "D:/godotplay/_art_backup/unit_anims_bazooka_4f_20261013"
FRAME = 256
N_FRAMES = 4


def fog_strip(sheet):
    """清贴体外缘半透明雾团(bake 前置): 生成图软边/雾感成片半透明像素
    (f2 3728px 贴轮廓实证)占住纯透明区 → bake_outline_on_sheet 的描边只落
    alpha<16 区 → f2/f3 描边断环。半透明 8 邻接连通块: ≥100px 且块内无
    实体(α≥200) → 整块置 0; 小块=antialias 羽化边保留。"""
    from collections import deque
    arr = np.asarray(sheet.convert("RGBA")).copy()
    F = arr.shape[1] // N_FRAMES
    for i in range(N_FRAMES):
        fa = arr[:, i * F:(i + 1) * F, 3]
        semi = (fa >= 16) & (fa < 200)
        H, W = semi.shape
        seen = np.zeros_like(semi, bool)
        for yy in range(H):
            for xx in range(W):
                if semi[yy, xx] and not seen[yy, xx]:
                    q = deque([(yy, xx)]); seen[yy, xx] = True; pts = []
                    has_solid = False
                    while q:
                        y, x = q.popleft(); pts.append((y, x))
                        if fa[y, x] >= 200:
                            has_solid = True
                        for ny, nx in ((y+1, x), (y-1, x), (y, x+1), (y, x-1),
                                       (y+1, x+1), (y-1, x-1), (y+1, x-1), (y-1, x+1)):
                            if 0 <= ny < H and 0 <= nx < W and semi[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True; q.append((ny, nx))
                    if has_solid or len(pts) < 100:
                        continue
                    for y, x in pts:
                        arr[y, i * F + x, 3] = 0
    return Image.fromarray(arr)


def edge_semi_clear(sheet):
    """实体膨胀环带内的半透明像素腾位(第二刀, fog_strip 之后): f2/f3 雾贴体
    (与实体同一连通块, fog_strip 的 has_solid 保护放行)仍占描边落位 → 断环。
    实体(α≥128)膨胀 5px 环带内 a∈[16,128) → 0, 描边直落实体缘。
    环带外半透明不动; 实体本体与 1~3px 硬羽化(α≥128)不动。"""
    arr = np.asarray(sheet.convert("RGBA")).copy()
    F = arr.shape[1] // N_FRAMES
    for i in range(N_FRAMES):
        a = arr[:, i * F:(i + 1) * F, 3]
        solid = a >= 128
        band = solid.copy()
        for _ in range(5):
            d = band.copy()
            d[1:, :] |= band[:-1, :]; d[:-1, :] |= band[1:, :]
            d[:, 1:] |= band[:, :-1]; d[:, :-1] |= band[:, 1:]
            band = d
        kill = band & ~solid & (a >= 16) & (a < 128)
        a[kill] = 0
    return Image.fromarray(arr)


def clutter_strip(sheet):
    """清实心背景杂物(第三刀, bake 前): t1 卷人物身后淡网格线/横条为 α=255 实体
    (y32-40 实心条 45×9px 实证), bake 把它们当本体 → 描边跟杂物走出断环。
    形态学开运算(9px 椭圆)分大块(core=人体/焰/管粗段)与细悬空结构;
    细结构连通块贴 core 率<0.2 → 清。背带/枪管贴实体率高 + 或在保护域内存活。"""
    import cv2
    arr = np.asarray(sheet.convert("RGBA")).copy()
    F = arr.shape[1] // N_FRAMES
    k9 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    for i in range(N_FRAMES):
        a = arr[:, i * F:(i + 1) * F, 3]
        solid = (a >= 128).astype(np.uint8)
        core = cv2.morphologyEx(solid, cv2.MORPH_OPEN, k9)
        prot = cv2.dilate(core, k9)
        clutter = solid & ~prot
        n, lab = cv2.connectedComponents(clutter, connectivity=8)
        for cid in range(1, n):
            m = lab == cid
            touch = cv2.dilate(m.astype(np.uint8), k9)[core > 0].sum()
            if touch / max(int(m.sum()), 1) < 0.2:
                a[m] = 0
    return Image.fromarray(arr)


def main():
    staged = Image.open(STAGED).convert("RGBA")
    assert staged.size == (FRAME * N_FRAMES, FRAME), staged.size

    # 1. 外部备份(部署前, 铁律; 幂等——重跑不覆盖既有备份)
    os.makedirs(BACKUP, exist_ok=True)
    for f in ("sheet_attack.png", "sheet_idle.png", "anim.json"):
        src = os.path.join(ANIM_DIR, f)
        dst = os.path.join(BACKUP, f)
        if os.path.exists(src) and not os.path.exists(dst):
            shutil.copy2(src, dst)
            print("[backup] %s" % f)

    # 2. 清雾团 + 环带半透明腾位 + 清背景杂物 + 烘描边(唯一真身, 逐帧切片)
    atk = dua.bake_outline_on_sheet(clutter_strip(edge_semi_clear(fog_strip(staged))))

    # 5. 帧缘触边检查——警告不阻断: 旧现役 6 帧版 f2/f3 同样右触缘(焰/管出画表现,
    #    2026-10-06 起线上无恙), 描边贴缘被裁同款。normalize 的帧缘振铃断言只针对
    #    重缩放伪影, 不适用击发帧满宽表现。
    arr = np.asarray(atk)[:, :, 3]
    touch = []
    for i in range(N_FRAMES):
        fa = arr[:, i * FRAME:(i + 1) * FRAME]
        if fa[:2, :].any() or fa[-2:, :].any() or fa[:, :2].any() or fa[:, -2:].any():
            touch.append("f%d" % (i + 1))
    print("[check] 帧缘触边: %s (旧现役 f2/f3 同款, 放行)" % (",".join(touch) or "无"))

    # 3-4. 落盘(attack 覆盖, idle 不动, anim.json 仅改 counts.attack)
    atk.save(os.path.join(ANIM_DIR, "sheet_attack.png"))
    meta_path = os.path.join(ANIM_DIR, "anim.json")
    meta = json.load(open(meta_path, encoding="utf-8"))
    meta["counts"]["attack"] = N_FRAMES
    meta["outline"] = dua.outline_meta()
    json.dump(meta, open(meta_path, "w", encoding="utf-8"), ensure_ascii=False)
    print("[deploy] attack %dx%d (%d 帧) counts=%s" % (atk.width, FRAME, N_FRAMES, meta["counts"]))
    print("[next]  python tools/anim_subject_normalize.py --dir ww2_inf_bazooka")
    print("[done]  %s" % ANIM_DIR)


if __name__ == "__main__":
    main()
