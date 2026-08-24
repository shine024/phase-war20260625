# -*- coding: utf-8 -*-
# B12 第二轮批量替换：零视觉风险三分层（值相等直替 / alpha=0 渲染等价 / d<0.02 微收敛 / 高频新token）
# 只动代码行（跳过 # 注释行），保留原格式；无 DesignTokens 引用的文件自动补 const。
import os, re, sys, collections

# ── 替换映射：文本模式（规范化后）→ token ──
# 值完全相等（token 值逐一核对过 design_tokens.gd）
EXACT = {
    (1.0, 1.0, 1.0, 1.0): 'COLOR_HOVER_WHITE',
    (0.0, 0.0, 0.0, 0.55): 'COLOR_BACKDROP',
    (0.0, 0.0, 0.0, 0.7): 'COLOR_BACKDROP_DEEP',
    (0.05, 0.09, 0.16, 0.4): 'COLOR_CHIP_BG',
    (0.25, 0.35, 0.42, 0.3): 'COLOR_CHIP_BORDER',
    (0.04, 0.07, 0.12, 0.4): 'COLOR_LIST_BG',
}
# alpha=0 渲染等价（RGB 不参与渲染）
TRANSPARENT_EQ = {(1.0, 1.0, 1.0, 0.0), (1.0, 1.0, 1.0, 0.0)}
# d<0.02 微收敛（视觉不可辨，逐条人工核对）
NEAR = {
    (0.95, 0.96, 0.98, 1.0): 'COLOR_TEXT',
    (0.13, 0.83, 0.93, 1.0): 'COLOR_CYAN_TECH_SOFT',
    (0.03, 0.06, 0.11, 1.0): 'COLOR_SLOT_LOCKED',
    (0.0, 0.92, 1.0, 1.0): 'COLOR_ACCENT_CYAN',
    (0.98, 0.75, 0.14, 1.0): 'COLOR_AMBER_SOFT',
    (0.98, 0.75, 0.15, 1.0): 'COLOR_AMBER_SOFT',
    (0.2, 0.83, 0.6, 1.0): 'COLOR_GREEN_UP',
    (0.05, 0.08, 0.13, 1.0): 'COLOR_PANEL_DEEP',
    (0.545, 0.361, 0.965, 1.0): 'COLOR_ACCENT_PURPLE',
    (0.04, 0.06, 0.11, 1.0): 'COLOR_SLOT_LOCKED',
    (0.3, 0.5, 0.9, 1.0): 'COLOR_KIND_ARMOR',
    (0.78, 0.7, 1.0, 1.0): 'COLOR_VIOLET_SOFT',
}
# 新 token（值原样）
NEW_TOK = {
    (0.6, 0.85, 1.0, 1.0): 'COLOR_ICE_TEXT',
    (0.5, 0.55, 0.65, 0.8): 'COLOR_SLATE_A80',
    (0.5, 0.55, 0.65, 0.7): 'COLOR_SLATE_A70',
    (0.91, 0.93, 0.96, 1.0): 'COLOR_TEXT_SOFT',
    (1.0, 0.9, 0.6, 1.0): 'COLOR_GOLD_SOFT',
    (0.55, 0.6, 0.7, 0.85): 'COLOR_SLATE_DIM_A85',
}
# 3 通道写法（无 alpha）等价表：Color(r,g,b) == Color(r,g,b,1)
def lookup(vals4):
    if vals4 in EXACT: return EXACT[vals4], 'exact'
    if vals4 in NEW_TOK: return NEW_TOK[vals4], 'newtok'
    if vals4 in NEAR: return NEAR[vals4], 'near'
    if vals4[3] == 0.0 and vals4[:3] == (1.0, 1.0, 1.0): return 'COLOR_TRANSPARENT', 'transp'
    return None, None

PAT = re.compile(r'Color\(\s*([0-9]+\.?[0-9]*)\s*,\s*([0-9]+\.?[0-9]*)\s*,\s*([0-9]+\.?[0-9]*)\s*(?:,\s*([0-9]+\.?[0-9]*)\s*)?\)')
DT_PRELOAD = 'const DesignTokens = preload("res://resources/design_tokens.gd")'

changed_files = []
report = collections.Counter()
for root, dirs, files in os.walk('scenes/ui'):
    for fn in files:
        if not fn.endswith('.gd'):
            continue
        p = (os.path.join(root, fn)).replace(os.sep, '/')
        src = open(p, encoding='utf-8', newline='').read()
        lines = src.split('\n')
        out = []
        n_changed = 0
        for ln in lines:
            if ln.strip().startswith('#') or ('const ' in ln and 'Color(' in ln and ':=' in ln):
                out.append(ln)
                continue
            def repl(m):
                global n_changed
                nums = [float(g) if g else None for g in m.groups()]
                vals = [nums[0], nums[1], nums[2], nums[3] if nums[3] is not None else 1.0]
                vals = tuple(round(v, 4) for v in vals)
                tok, tier = lookup(vals)
                if tok is None:
                    return m.group(0)
                n_changed += 1
                report[tier] += 1
                return 'DesignTokens.' + tok
            new_ln = PAT.sub(repl, ln)
            out.append(new_ln)
        if n_changed == 0:
            continue
        new_src = '\n'.join(out)
        # 补 preload（若文件无 DesignTokens/DT 引用）
        has_ref = re.search(r'const DesignTokens\s*=|DesignTokens[.]|const DT\s*=', new_src)
        if not has_ref:
            # 插到第一个非注释行（extends 类声明）之后
            m_ext = re.search(r'^extends [^\n]+$', new_src, re.M)
            if m_ext:
                insert_at = m_ext.end()
                new_src = new_src[:insert_at] + '\n\n' + DT_PRELOAD + new_src[insert_at:]
            else:
                new_src = DT_PRELOAD + '\n' + new_src
        open(p, 'w', encoding='utf-8', newline='').write(new_src)
        changed_files.append((p, n_changed))
        print(f"{n_changed:3d}  {p}")

print('---')
print('分类统计:', dict(report), '总替换:', sum(report.values()), '文件数:', len(changed_files))
