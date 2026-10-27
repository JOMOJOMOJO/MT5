"""Independent raw pivot/EA provenance checks; never reads outcome labels."""
from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
BATCH = ROOT / 'reports/backtest/runs/wave33_v180_2020/20261023_164915_831ff154'


def read_rows(path: Path):
    with path.open(encoding='utf-8-sig', newline='') as src:
        return list(csv.DictReader(src, delimiter=';'))


def main():
    failures = []
    counts = {}
    for arm in ('a', 'b'):
        run = BATCH / f'v180_{arm}_both'
        events = read_rows(run / 'events.csv')
        counts[arm] = {}
        for source_name in ('upper', 'lower'):
            rows = read_rows(run / f'{source_name}_bars.csv')
            tf = rows[0]['tf']
            expected = []
            for i in range(4, len(rows)):
                p = rows[i - 2]
                neighbors = rows[i - 4:i - 2] + rows[i - 1:i + 1]
                for is_high, field in ((True, 'high'), (False, 'low')):
                    price = float(p[field])
                    if all((price > float(n[field])) if is_high else (price < float(n[field])) for n in neighbors):
                        expected.append((p['bar_time'], rows[i]['known_at'], price, is_high))
            actual = []
            for e in events:
                if e['event_type'] == 'PIVOT_CONFIRMED' and e['observed_pivot_tf'] == tf:
                    label = e['observed_pivot_label']
                    actual.append((e['observed_pivot_time'], e['observed_pivot_known_at'], float(e['observed_pivot_price']), label in ('H', 'HH', 'LH')))
                    if e['event_at'] != e['observed_pivot_known_at']:
                        failures.append(f'{arm}/{source_name}: pivot event availability mismatch')
            if expected != actual:
                mismatch = next((i for i, pair in enumerate(zip(expected, actual)) if pair[0] != pair[1]), min(len(expected), len(actual)))
                failures.append(f'{arm}/{source_name}: strict 2L/2R pivot mismatch at {mismatch}: expected={len(expected)}, actual={len(actual)}')
            counts[arm][source_name] = dict(bars=len(rows), expected_pivots=len(expected), actual_pivots=len(actual), exact_sequence_match=expected == actual)
    protected = json.loads((HERE / 'ea_before_hashes.json').read_text(encoding='utf-8-sig'))
    for item in protected:
        got = hashlib.sha256(Path(item['path']).read_bytes()).hexdigest().upper()
        if got != item['sha256']:
            failures.append(f"EA changed: {item['path']}")
    result = dict(status='PASS' if not failures else 'FAIL', counts=counts, protected_ea_files=len(protected), failures=failures,
                  labels_read=False, source_pivot_rule='strict 2 left / 2 right, source row and right-confirmation known_at, chronological exact equality')
    (HERE / 'raw_source_audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
