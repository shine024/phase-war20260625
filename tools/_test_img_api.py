# -*- coding: utf-8 -*-
"""生图 API 连通性冒烟: 最小请求, 存首图"""
import json
import urllib.request

KEYS = [
    'sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv',
    'sk-2mxCpSC8Nf0nm2TAf9fYHuRxNj7aeoIttPuuu9ivodbU3zXN',
    'sk-Pzu3QigNdQlVhFC7cVDVsTDwfvt3T6nIDq23HeJgaKMnRo6K',
]
payload = {
    'model': 'agnes-image-2.1-flash',
    'prompt': 'a simple green circle on white background, minimal test',
    'size': '512x512',
}
last = None
for i, key in enumerate(KEYS, 1):
    req = urllib.request.Request(
        'https://apihub.agnes-ai.com/v1/images/generations',
        data=json.dumps(payload).encode(),
        headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            data = json.loads(r.read().decode())
        print('key#%d OK ->' % i, json.dumps(data, ensure_ascii=False)[:300])
        break
    except Exception as e:
        last = e
        print('key#%d FAIL: %s' % (i, str(e)[:200]))
else:
    raise SystemExit('all keys failed: %s' % last)
