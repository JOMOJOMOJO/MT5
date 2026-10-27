"""Run ONLY after root confirms both blinded review sets are frozen."""
from collections import Counter
import csv
import hashlib
import json
import math
from pathlib import Path
import random

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DATA = HERE.parent / 'data'
TRADE_PATH = ROOT / 'reports/backtest/runs/wave33_v180_2020/analysis/trades.csv'
NATIVE_PATH = ROOT / 'reports/backtest/runs/wave33_v180_2020/analysis/integrity/native_positions.csv'


def read(path):
    with path.open(encoding='utf-8-sig', newline='') as handle:
        return list(csv.DictReader(handle))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    quotas = {('A','LONG','WIN'):8, ('A','SHORT','WIN'):7,
              ('B','LONG','WIN'):7, ('B','SHORT','WIN'):8,
              ('A','LONG','LOSS'):7, ('A','SHORT','LOSS'):8,
              ('B','LONG','LOSS'):8, ('B','SHORT','LOSS'):7}
    failures = []
    trades = read(TRADE_PATH)
    labels = read(DATA / 'labels/label_key.csv')
    native = read(NATIVE_PATH)
    native_key = {(n['run'], n['setup_id']): n for n in native}
    if len(trades) != 440 or len(labels) != 60:
        failures.append('annual440 / selected60 counts')
    expected = []
    strata = []
    for key, count in quotas.items():
        pool = sorted([t for t in trades if (t['arm'],t['direction'],t['outcome']) == key], key=lambda t:(t['entry_at'],t['setup_id']))
        selected = min(count, len(pool))
        indices = [math.floor((i+0.5)*len(pool)/selected) for i in range(selected)] if selected else []
        expected.extend(pool[i] for i in indices)
        strata.append(dict(arm=key[0], direction=key[1], outcome=key[2], available=len(pool), requested=count, selected=selected, indices=indices))
    random.Random(20261023).shuffle(expected)
    if len(expected) != 60:
        failures.append('stratified sampling shortfall')
    for i, (e, label) in enumerate(zip(expected, labels), 1):
        if label['blind_id'] != f'V{i:03}' or (e['arm'],e['setup_id']) != (label['arm'],label['setup_id']):
            failures.append(f'V{i:03}: systematic strata/random permutation mismatch')
    for trade in trades:
        cash = float(trade['net_cash'])
        expected_outcome = 'WIN' if cash > 0 else 'LOSS' if cash < 0 else 'FLAT'
        if trade['outcome'] != expected_outcome:
            failures.append('outcome does not follow net cash sign: ' + trade['setup_id'])
        risk = float(trade['risk_cash'])
        if risk <= 0 or abs(cash/risk - float(trade['net_r'])) > 1e-9:
            failures.append('net R normalization: ' + trade['setup_id'])
        # Native integration evidence is keyed by arm/run and original setup ID.
        matches = [n for (run, setup_id), n in native_key.items() if setup_id == trade['setup_id'] and run == 'v180_' + trade['arm']]
        if len(matches) != 1:
            failures.append('unique native position match: ' + trade['setup_id'])
        elif abs(float(matches[0]['net_cash'])-cash) > 1e-7:
            failures.append('native position cash mismatch: ' + trade['setup_id'])
    selected_groups = Counter((t['arm'], t['direction'], t['outcome']) for t in labels)
    if selected_groups != Counter(quotas):
        failures.append('selected stratum quotas')
    result = dict(status='PASS' if not failures else 'FAIL', label_reveal_phase='AFTER_BOTH_REVIEWS_FROZEN',
                  source_trades=len(trades), selected=len(labels),
                  outcomes=dict(Counter(t['outcome'] for t in labels)),
                  directions=dict(Counter(t['direction'] for t in labels)),
                  arms=dict(Counter(t['arm'] for t in labels)), strata=strata,
                  deterministic_selection_reproduced=not any('permutation' in f for f in failures),
                  native_net_cash_verified=not any('native' in f for f in failures),
                  input_hashes={str(p.relative_to(ROOT)):sha(p) for p in (TRADE_PATH,NATIVE_PATH,DATA/'labels/label_key.csv')},
                  failures=failures)
    (HERE / 'label_quota_audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ('strata', 'input_hashes')}, ensure_ascii=False, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
