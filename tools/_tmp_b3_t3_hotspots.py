# 批次③ Task 3：6 悬空键（affix/growth/collection/faction/leaderboard/help）挂热区。
# ① 先对每时代既有 11 热区做矩形重叠校验（check 模式）；② 干净后把 6 条/时代插入
# HOTSPOTS 各时代列表末尾（尾门跳板之后）。坐标为画面比例 [l,t,w,h]。
import re
import sys

PATH = r"F:\godot fair duet\create\phase-war\scenes\bunker\truck_base.gd"

# 每时代 6 条新热区（语义就近：growth 靠指挥桌/affix 靠工具台/collection 靠卡牌墙/
# faction 靠售货机联络位/leaderboard 靠铺位荣誉墙/help 靠舱门告示板）
NEW = {
    "era1": [
        (0.255, 0.610, 0.139, 0.080, "通讯架", "成长规划", "growth"),
        (0.506, 0.610, 0.138, 0.080, "词缀工具车", "词缀·洗练", "affix"),
        (0.470, 0.180, 0.174, 0.090, "资料柜", "图鉴·收藏档案", "collection"),
        (0.398, 0.180, 0.067, 0.100, "电台", "势力联络", "faction"),
        (0.792, 0.610, 0.130, 0.070, "战功板", "战功记录", "leaderboard"),
        (0.852, 0.327, 0.080, 0.080, "告示板", "车长手册", "help"),
    ],
    "era2": [
        (0.244, 0.590, 0.146, 0.080, "通讯架", "成长规划", "growth"),
        (0.580, 0.620, 0.128, 0.080, "词缀工具车", "词缀·洗练", "affix"),
        (0.465, 0.150, 0.275, 0.085, "资料柜", "图鉴·收藏档案", "collection"),
        (0.394, 0.150, 0.066, 0.100, "电台", "势力联络", "faction"),
        (0.780, 0.600, 0.130, 0.055, "战功板", "战功记录", "leaderboard"),
        (0.830, 0.300, 0.085, 0.090, "告示板", "车长手册", "help"),
    ],
    "era3": [
        (0.272, 0.645, 0.115, 0.070, "通讯台", "成长规划", "growth"),
        (0.676, 0.640, 0.062, 0.092, "词缀工具台", "词缀·洗练", "affix"),
        (0.584, 0.290, 0.097, 0.095, "档案屏", "图鉴·收藏档案", "collection"),
        (0.431, 0.280, 0.044, 0.100, "通讯阵列", "势力联络", "faction"),
        (0.751, 0.450, 0.085, 0.090, "战功屏", "战功记录", "leaderboard"),
        (0.838, 0.670, 0.075, 0.080, "电子告示牌", "车长手册", "help"),
    ],
    "era4": [
        (0.250, 0.715, 0.123, 0.070, "全息通讯塔", "成长规划", "growth"),
        (0.710, 0.500, 0.096, 0.080, "词缀机械臂", "词缀·洗练", "affix"),
        (0.412, 0.330, 0.079, 0.080, "全息档案柜", "图鉴·收藏档案", "collection"),
        (0.254, 0.300, 0.088, 0.080, "外交全息台", "势力联络", "faction"),
        (0.565, 0.540, 0.127, 0.080, "战功光墙", "战功记录", "leaderboard"),
        (0.806, 0.290, 0.070, 0.080, "全息手册架", "车长手册", "help"),
    ],
    "era5": [
        (0.300, 0.735, 0.094, 0.070, "相位通讯塔", "成长规划", "growth"),
        (0.565, 0.745, 0.108, 0.070, "词缀相位台", "词缀·洗练", "affix"),
        (0.444, 0.320, 0.112, 0.085, "相位档案柜", "图鉴·收藏档案", "collection"),
        (0.392, 0.300, 0.047, 0.100, "相位外交台", "势力联络", "faction"),
        (0.565, 0.395, 0.187, 0.080, "战功光廊", "战功记录", "leaderboard"),
        (0.895, 0.320, 0.080, 0.080, "相位手册架", "车长手册", "help"),
    ],
}

EPS = 1e-6


def overlaps(a, b):
    ax, ay, aw, ah = a[:2], a[1:2], a[0] + a[2], a[1] + a[3]
    ax0, ay0, ax1, ay1 = a[0], a[1], a[0] + a[2], a[1] + a[3]
    bx0, by0, bx1, by1 = b[0], b[1], b[0] + b[2], b[1] + b[3]
    return ax0 + EPS < bx1 and bx0 + EPS < ax1 and ay0 + EPS < by1 and by0 + EPS < ay1


def main(apply: bool) -> int:
    with open(PATH, encoding="utf-8") as f:
        lines = f.read().splitlines()

    # 解析既有热区：按 era 分段收集 {"r": [l,t,w,h], "name": ...} 行
    era = None
    existing = {}   # era -> list of (rect, name)
    tail_idx = {}   # era -> line index of 尾门跳板 entry
    for i, ln in enumerate(lines):
        m = re.match(r'\s*"era(\d)": \[', ln)
        if m:
            era = "era" + m.group(1)
            existing[era] = []
        if era and '"r": [' in ln:
            nums = [float(x) for x in re.search(r'"r": \[([^\]]+)\]', ln).group(1).split(",")]
            name = re.search(r'"name": "([^"]+)"', ln)
            existing[era].append((nums, name.group(1) if name else "?"))
            if "尾门跳板" in ln:
                tail_idx[era] = i

    bad = 0
    for era, entries in NEW.items():
        mine = [(list(e[:4]), e[4]) for e in entries]
        for r, nm in mine:
            for er, enm in existing[era]:
                if overlaps(r, er):
                    print("[OVERLAP] %s 新『%s』%s × 既有『%s』%s" % (era, nm, r, enm, er))
                    bad += 1
            for r2, nm2 in mine:
                if r2 is not r and overlaps(r, r2):
                    print("[OVERLAP] %s 新『%s』× 新『%s』" % (era, nm, nm2))
                    bad += 1
        if len(existing[era]) != 11:
            print("[WARN] %s 既有热区数 %d ≠ 11" % (era, len(existing[era])))
    if bad:
        print("check: %d 处重叠，不插入" % bad)
        return 1
    print("check: 五时代全部无重叠")
    if not apply:
        return 0

    # 插入（倒序按行号插，避免行号漂移；每时代插在尾门跳板行之后）
    inserts = []
    for era, entries in NEW.items():
        i = tail_idx[era]
        block = []
        for (l, t, w, h, nm, hint, key) in entries:
            block.append(
                '\t\t{"r": [%.3f, %.3f, %.3f, %.3f], "name": "%s", "hint": "%s", '
                '"kind": "panel", "key": "%s"},' % (l, t, w, h, nm, hint, key)
            )
        inserts.append((i, block))
    inserts.sort(key=lambda x: -x[0])
    for i, block in inserts:
        lines[i + 1:i + 1] = block

    with open(PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("apply: 已插入 %d 时代 × 6 热区" % len(NEW))
    return 0


if __name__ == "__main__":
    sys.exit(main(apply="--apply" in sys.argv))
