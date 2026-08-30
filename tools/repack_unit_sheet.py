# -*- coding: utf-8 -*-
"""手改 f*.png 后的雪碧图重打包（不动帧文件, 不碰 mp4/raw）
用法:
  python tools/repack_unit_sheet.py <单位目录名>            # 该单位 idle+attack 全部重打包
  python tools/repack_unit_sheet.py <单位目录名> <idle|attack>  # 只重打包一个动画
注意: generate_unit_animations.py 的 build 会从 source.mp4 重新抽帧并覆盖 f*.png——
      手改过的单位一律用本脚本重建 sheet, 再跑 deploy_unit_anims.py + Godot --import。
"""
import glob
import os
import sys

from PIL import Image

BASE = r'资料/单位分帧动画'


def repack(unit_dir: str, anim: str) -> bool:
    adir = os.path.join(BASE, unit_dir, anim)
    frames = sorted(glob.glob(os.path.join(adir, 'f*.png')))
    if not frames:
        print('!! no frames: %s/%s' % (unit_dir, anim))
        return False
    ims = [Image.open(f).convert('RGBA') for f in frames]
    w, h = ims[0].size
    for im in ims[1:]:
        if im.size != (w, h):
            print('!! frame size mismatch in %s/%s, skip' % (unit_dir, anim))
            return False
    sheet = Image.new('RGBA', (w * len(ims), h), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        sheet.paste(im, (i * w, 0))
    out = os.path.join(adir, 'sheet_%s.png' % anim)
    sheet.save(out)
    print('%s/%s: %d frames -> %s (%dx%d)' % (unit_dir, anim, len(ims), os.path.basename(out), sheet.size[0], sheet.size[1]))
    return True


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        return
    unit_dir = sys.argv[1]
    anims = [sys.argv[2]] if len(sys.argv) > 2 else ['idle', 'attack']
    ok = all(repack(unit_dir, a) for a in anims)
    raise SystemExit(0 if ok else 1)


if __name__ == '__main__':
    main()
