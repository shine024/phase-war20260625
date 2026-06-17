import os, re

MOD_DIR = r'data\modification_modules'
missing = {'deception', 'enhancement', 'guidance', 'system', 'thrust', 'weapons'}

for fname in sorted(os.listdir(MOD_DIR)):
    if not fname.endswith('.gd') or fname == '__init__.gd':
        continue
    with open(os.path.join(MOD_DIR, fname), 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines):
        sm = re.search(r'slot_type\s*=\s*"([^"]+)"', line)
        if sm and sm.group(1) in missing:
            st = sm.group(1)
            mid = '?'
            nm = '?'
            # find mod id (look back for "mod_id" = {)
            for j in range(i-1, max(i-5, -1), -1):
                mid_m = re.search(r'"([a-z]+_\d+_\w+)"\s*=\s*\{', lines[j])
                if mid_m:
                    mid = mid_m.group(1)
                    break
            # find name
            for j in range(i):
                nm_m = re.search(r'name\s*=\s*"([^"]+)"', lines[j])
                if nm_m:
                    nm = nm_m.group(1)
                    break
            print(f'{fname:30s} | {mid:30s} | {nm:30s} | slot={st}')
