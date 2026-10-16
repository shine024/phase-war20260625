# -*- coding: utf-8 -*-
import sys
from PIL import Image
RAW = 'docs/卡图API重生成_20261014/raw'
refs = [('075', 'MP18 突击队'), ('056', '海军陆战队'), ('086', 'M4 卡宾特遣班')]
c = Image.new('RGB', (1020, 340))
for i, (no, name) in enumerate(refs):
    im = Image.open('%s/%s·%s.png' % (RAW, no, name)).convert('RGB').resize((340, 340))
    c.paste(im, (i * 340, 0))
c.save('tools/_chk_3refs.png')
print('ok')
