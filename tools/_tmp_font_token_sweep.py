"""v23.6.1 字号 token 归档脚本（一次性）。
scenes/ui + scenes/bunker 内 add_theme_font_size_override 的纯整数字面量
(10/12/14/16/20/32/48) → DT.FONT_SIZE_*；文件无 DT preload 时自动补。
只匹配纯字面量（clampi/表达式不动）；值与 token 完全相等，零视觉变化。
"""
import re, glob

DT_PATH = 'res://resources/design_tokens.gd'
TOKEN = {'10': 'FONT_SIZE_XSMALL', '12': 'FONT_SIZE_SMALL', '14': 'FONT_SIZE_BODY',
         '16': 'FONT_SIZE_MEDIUM', '20': 'FONT_SIZE_LARGE', '32': 'FONT_SIZE_TITLE',
         '48': 'FONT_SIZE_HUGE'}
# 仅匹配整数字面量实参（前面不是数字/字母/下划线/点，后面不是数字）
CALL = re.compile(r'(add_theme_font_size_override\(\s*["\'][^"\']+["\']\s*,\s*)(\d+)(\s*\))')
DT_CONST = re.compile(r'const (\w+)\s*=\s*preload\("' + DT_PATH.replace('/', r'/') + r'"\)')

files = sorted(glob.glob('scenes/ui/**/*.gd', recursive=True)
               + glob.glob('scenes/bunker/**/*.gd', recursive=True))
total_replaced = 0
touched = []
for gd in files:
    if gd.endswith('.uid'):
        continue
    t = open(gd, encoding='utf-8').read()
    m = DT_CONST.search(t)
    dt_name = m.group(1) if m else None

    def repl(mo):
        global total_replaced, dt_name
        val = mo.group(2)
        if val not in TOKEN:
            return mo.group(0)
        if dt_name is None:
            return mo.group(0)  # 无 DT 的文件由下方补 const 后重扫
        total_replaced += 1
        return mo.group(1) + dt_name + '.' + TOKEN[val] + mo.group(3)

    new = CALL.sub(repl, t)
    if new == t:
        continue
    # 文件需要替换但没有 DT const → 在最后一个 preload const 后补
    if dt_name is None:
        pre = list(re.finditer(r'^const \w+ = preload\("[^"]+"\)\s*$', new, re.M))
        if not pre:
            print('SKIP(无 preload 锚点):', gd)
            continue
        insert_at = pre[-1].end()
        new = new[:insert_at] + '\nconst DT = preload("' + DT_PATH + '")   # v23.6.1 字号归档' + new[insert_at:]
        # 补完 const 后再跑一遍替换
        dt_name = 'DT'
        def repl2(mo):
            global total_replaced
            val = mo.group(2)
            if val not in TOKEN:
                return mo.group(0)
            total_replaced += 1
            return mo.group(1) + 'DT.' + TOKEN[val] + mo.group(3)
        new = CALL.sub(repl2, new)
    open(gd, 'w', encoding='utf-8', newline='').write(new)
    touched.append(gd)

print('替换处数:', total_replaced, '| 改动文件数:', len(touched))
for f in touched:
    print(' ', f)
