import os

base = r"F:\godot fair duet\create\phase-war"
root_dir = os.path.join(base, "assets", "card_icons")

keep = {"law.png"}
deleted = []
for fn in os.listdir(root_dir):
    path = os.path.join(root_dir, fn)
    if fn.endswith('.png') and fn not in keep:
        os.remove(path)
        deleted.append(fn)

print(f"已删除 {len(deleted)} 张文件:")
for f in sorted(deleted):
    print(f"  {f}")

print(f"\n已保留: law.png")
