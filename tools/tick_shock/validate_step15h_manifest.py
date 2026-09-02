#!/usr/bin/env python3
import collections,hashlib,re
from pathlib import Path
p=Path('docs/research/tick_shock/00_artifact_manifest.md');rows=[]
for line in p.read_text(encoding='utf-8-sig').splitlines():
    m=re.match(r'\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*`([^`]+)`\s*\|.*?`([A-Fa-f0-9]{64})`',line)
    if m:rows.append((m.group(1).strip(),m.group(3),m.group(4).upper()))
ids=collections.Counter(x[0] for x in rows);latest={path:digest for _,path,digest in rows};mismatches=[]
for path,want in latest.items():
    f=Path(path)
    if f.is_file():
        got=hashlib.sha256(f.read_bytes()).hexdigest().upper()
        if got!=want:mismatches.append((path,want,got))
print(f'rows={len(rows)} paths={len(latest)} duplicate_ids={sum(v-1 for v in ids.values() if v>1)} sha_mismatches={len(mismatches)}')
for row in mismatches[:20]:print('|'.join(row))
raise SystemExit(1 if mismatches or any(v>1 for v in ids.values()) else 0)
