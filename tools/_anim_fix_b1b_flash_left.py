# -*- coding: utf-8 -*-
"""B1 补刀：9 个单位火光画错边（sheet 全部朝左，火光却画在右侧车尾）。
复用 B1 管线：median_erase 先擦旧错火光（4/12 帧差异→中位数回填），再按实测真炮口重画。
B1 备份已存在（首跑时已备份原图），本批不覆盖备份。
"""
import importlib.util, os, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_OLD_STDOUT = sys.stdout  # 持引用：b1 重包 stdout 后旧包装器被 GC 会关闭共享 buffer
spec = importlib.util.spec_from_file_location("b1", os.path.join(ROOT, "tools", "_anim_fix_b1_flash.py"))
b1 = importlib.util.module_from_spec(spec)
sys.modules["b1"] = b1
spec.loader.exec_module(b1)  # b1 已自行重包 stdout(utf-8)，勿再包一层（GC 会关闭共享 buffer）

# 实测修正（2026-10-03 网格放大 b1_muzzle_grid*.png / b1_himars_hover_grid / b1_btr60_sam7_grid）
CORRECT = {
    "cold_arm_t55":      ((6, 132),   "cannon", 180,  "warm"),
    "cold_t72":          ((8, 180),   "cannon", 180,  "warm"),
    "cold_inf_btr60":    ((94, 132),  "mg",     180,  "warm"),
    "fut_arm_hovertank": ((12, 205),  "energy", 180,  "purple"),
    "mod_arm_himars":    ((114, 48),  "rocket", -140, "warm"),
    "ww1_arm_rolls":     ((4, 129),   "mg",     180,  "warm"),
    "ww2_arm_sherman":   ((12, 128),  "cannon", 180,  "warm"),
    "ww2_inf_hellcat":   ((10, 131),  "cannon", 180,  "warm"),
    "cold_sam7":         ((58, 8),    "rocket", -130, "warm"),
}

# 火光帧整体略向后挪一帧不影响; 直接沿用 b1 常量。只跑本 9 key。
b1.PATCH.clear()
b1.PATCH.update(CORRECT)


def main():
    ok = 0
    for k in sorted(b1.PATCH):
        ok += bool(b1.process(k, b1.PATCH[k], None))
    print("B1 补刀 done %d/%d" % (ok, len(b1.PATCH)))


if __name__ == "__main__":
    main()
