# -*- coding: utf-8 -*-
"""m1a2sep SF 底渍补刀重导出（v2 谓词：暗焦橙 r≈101 → 底 10% 窄带 r-g>25 咬）。只重导出不调 API。
注意：只 exec _b5_sf_regens.py 的前半段（到 "# ---- 1)" 为止），后半段是第一轮重掷主逻辑，勿跑。"""
import io
import os
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "_b5_sf_regens.py"), encoding="utf-8").read()
partial = src.split("# ---- 1)")[0]
# 剔除 partial 顶层的 stdout 二次包装行（再包一层会让旧 wrapper 被 GC 关闭 → print 全炸）
partial = "\n".join(ln for ln in partial.splitlines()
                    if not ln.strip().startswith("sys.stdout = io.TextIOWrapper"))
rg = types.ModuleType("rg")
rg.__file__ = os.path.join(ROOT, "tools", "_b5_sf_regens.py")
exec(compile(partial, "rg_partial", "exec"), rg.__dict__)

rg.sb.process_unit([x for x in rg.sb.UNITS if x["key"] == "mod_arm_m1a2sep"][0], 0)
print("m1a2sep v2 补刀重导出完成", flush=True)
