"""Summarize actual native assertions; a tooltip failure is never called PASS."""
from pathlib import Path
import csv
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
batch = OUT / 'native/20261024_174150_e33026ba'
tag = 'w33chop_20261024_174150_e33026ba'
def read_csv(path):
    with path.open(encoding='utf-8-sig', newline='') as file:
        return list(csv.DictReader(file, delimiter=';'))
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
rows = read_csv(batch / f'{tag}.csv')
parity = read_csv(batch / f'{tag}_parity.csv')
core = [r for r in rows if r['test'] != 'SUMMARY' and r['actual_status'] != 'UI']
ui = [r for r in rows if r['actual_status'] == 'UI']
assert len(core) == 24 and all(r['result'] == 'PASS' for r in core)
assert len(parity) == 60 and all(r['result'] == 'PASS' for r in parity)
assert len(ui) == 11 and sum(r['result'] == 'PASS' for r in ui) == 10
assert [r['test'] for r in ui if r['result'] != 'PASS'] == ['tooltip_retains_full_setup_id']
copy = json.loads((OUT / 'source_copy_manifest.json').read_text(encoding='utf-8'))
assert digest(ROOT / copy['source']) == copy['source_sha256']
assert digest(ROOT / copy['target']) == copy['target_sha256']
logs = {
    name: (OUT / f'compile/{name}.log').read_text(encoding='utf-16')
    for name in ['Wave33ChopDiagnostic', 'Wave33ChopHarness']
}
assert all('Result: 0 errors, 0 warnings' in text for text in logs.values())
result = {
    'status': 'PARTIAL_UI_LIMITATION',
    'native_batch': str(batch.relative_to(ROOT)),
    'core': {'status': 'PASS', 'checks': 24, 'failures': 0},
    'actual_selected_case_parity': {'status': 'PASS', 'checks': 60, 'failures': 0, 'asserted_fields': ['status', 'ratio_when_available'],
                                  'csv': str((batch / f'{tag}_parity.csv').relative_to(ROOT))},
    'ui': {'status': 'PARTIAL', 'checks': 11, 'passed': 10, 'failed': 1,
           'failed_test': 'tooltip_retains_full_setup_id', 'mql_visual_mode': 1, 'chart_id': 12345,
           'event': 'first_OnTick_after_OnInit', 'redraw_before_read': True,
           'tooltip_readback_length': 0, 'tooltip_readback_error': 0,
           'limitation': 'ObjectSetString succeeds but ObjectGetString tooltip is empty in this native tester. Full hover content and final appearance not verified; source/known metadata are preserved in CSV.'},
    'orders': 0,
    'compile': {name: {'errors': 0, 'warnings': 0} for name in logs},
    'original_ea_unchanged': True,
    'files': {str(path.relative_to(ROOT)): digest(path) for path in [
        ROOT / 'mql/Experts/Wave33VisualVerifier.mq5', ROOT / 'mql/Experts/Wave33ChopDiagnostic.mq5',
        ROOT / 'mql/Experts/Wave33ChopDiagnostic.ex5', ROOT / 'mql/Experts/tests/Wave33ChopHarness.mq5',
        ROOT / 'mql/Experts/tests/Wave33ChopHarness.ex5', ROOT / 'mql/Include/Wave33Visual/Chop.mqh',
    ]},
    'no_more_ui_attempts': True,
}
(OUT / 'native_latest.json').write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf-8')
print('Finalized core24 PASS / parity60 PASS / UI10of11; honest PARTIAL_UI_LIMITATION; compiles0/0; original unchanged')
