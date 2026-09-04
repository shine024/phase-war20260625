# -*- coding: utf-8 -*-
## 战斗截图后处理（v2 商店截图）：压掉上半空天空。
## 原理：顶部 SKY 行替换为其自身的高斯模糊+微暗版本（天空是平滑渐变+软云，
## 模糊延伸无缝），其余像素 1:1 原生不动 → 输出仍 1920×1080，单位不糊。
## 用法：python tools/steam_post_battle.py 输入.png 输出.png [sky行数=240]
from PIL import Image, ImageFilter
import sys

def main():
    src_path, dst_path = sys.argv[1], sys.argv[2]
    sky = int(sys.argv[3]) if len(sys.argv) > 3 else 240
    im = Image.open(src_path).convert('RGB')
    w, h = im.size
    body = im.crop((0, sky, w, h))                       # 840 行主体（不动）
    ext = im.crop((0, 0, w, sky)).filter(                 # 被裁掉的天空
        ImageFilter.GaussianBlur(22))
    ext = ext.point(lambda v: int(v * 0.97))             # 微暗，压视觉重量
    out = Image.new('RGB', (w, h))
    out.paste(ext, (0, 0))
    out.paste(body, (0, sky))
    # 接缝带 10 行线性混合，抹掉模糊/清晰突变
    seam0 = sky - 5
    for i in range(10):
        t = i / 9.0
        row_ext = ext.crop((0, ext.size[1] - 10 + i, w, ext.size[1] - 9 + i))
        row_body = body.crop((0, i, w, i + 1)) if i < body.size[1] else row_ext
        blend = Image.blend(row_ext, row_body, t)
        out.paste(blend, (0, seam0 + i))
    out.save(dst_path)
    print('post:', dst_path, out.size, f'sky={sky}')

if __name__ == '__main__':
    main()
