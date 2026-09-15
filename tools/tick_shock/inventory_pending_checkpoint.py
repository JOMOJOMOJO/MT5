"""Read-only git inventory; write scoped checkpoint plans, never stage files."""
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path

OUT = Path('reports/checkpoints/tick_shock/publish_20260915')
OUT.mkdir(parents=True, exist_ok=True)
pending = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard'], text=True).splitlines()
pending += subprocess.check_output(['git', 'diff', '--name-only'], text=True).splitlines()
secret = re.compile(r'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY|(?:password|api_key|access_token|secret_key)\s*[=:]\s*[\"\']?(?!false\b|true\b|null\b|none\b)[A-Za-z0-9_+/.-]{12,}|(?:^|\n)\s*Login\s*=\s*\d+', re.I)
rows = []
for name in sorted(set(pending)):
    if name.startswith(str(OUT).replace('\\', '/') + '/'):
        continue
    p = Path(name)
    group = ('barrier' if 'barrier' in name.lower() else
             'hold' if 'two_stage_hold' in name or 'matched-hold' in name or 'tickshock-hold-comparison' in name or name == 'mql/Include/TickShockTwoStageCandidate.mqh' else
             'development' if 'two_stage_development' in name else 'technical')
    action, reason = 'commit', 'Research source, documentation or compact evidence'
    if not p.is_file():
        action, reason = 'leave_uncommitted', 'Existing deletion; intent not established'
    elif 'step15g' in name or name.endswith('.ex5') or name.endswith('EventResponseHarness.ex5'):
        action, reason = 'leave_uncommitted', 'Historical generated test or binary changes'
    elif p.stat().st_size > 2_000_000:
        action, reason = 'leave_uncommitted', 'Large generated evidence retained locally; SHA inventory only'
    elif any(t in name.lower() for t in ['replay/', '_replay/', 'tester_report', 'journal', '.stderr.', '.stdout.']) or p.suffix.lower() in ['.joblib', '.pkl', '.parquet', '.npz', '.gz', '.png', '.runmeta', '.lock'] or p.name in ['status.json', 'batch_status.csv', 'validation_status.json']:
        action, reason = 'leave_uncommitted', 'Duplicate, runtime, binary or potentially identifying terminal evidence retained locally'
    elif name.startswith('reports/tests/'):
        action, reason = 'leave_uncommitted', 'Older test changes outside identified research bundles'
    if p.is_file() and action == 'commit':
        raw = p.read_bytes()
        try:
            content = raw.decode('utf-8-sig')
        except UnicodeError:
            action, reason = 'leave_uncommitted', 'Non-UTF8 generated artifact requires separate review'
        else:
            if secret.search(content):
                action, reason = 'needs_review', 'Potential credential pattern; contents not printed'
    rows.append(dict(path=name,group=group,action=action,reason=reason,bytes=p.stat().st_size if p.is_file() else 0,sha256=hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else 'MISSING'))
with (OUT/'inventory.csv').open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
plan={g:[r['path'] for r in rows if r['group']==g and r['action']=='commit'] for g in ['technical','development','hold','barrier']}
(OUT/'commit_plan.json').write_text(json.dumps(plan,indent=2),encoding='utf-8')
print(json.dumps({g:{'files':len(paths),'bytes':sum(Path(p).stat().st_size for p in paths)} for g,paths in plan.items()},indent=2))
print('Potential secret paths:',[r['path'] for r in rows if r['action']=='needs_review'])
