"""Audit v1.30 causal lifecycle invariants in complete native event CSVs."""
import argparse
import csv
import json
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


def stamp(value):
    return datetime.strptime(value, '%Y.%m.%d %H:%M:%S') if value else None


def audit(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        rows = list(csv.DictReader(f, delimiter=';'))
    grouped = defaultdict(list)
    for row in rows:
        if row['setup_id']:
            grouped[row['setup_id']].append(row)
    violations = []
    counts = Counter()

    def check(ok, setup, rule):
        counts[rule] += 1
        if not ok:
            violations.append({'setup_id': setup, 'rule': rule})

    for setup, history in grouped.items():
        progress = [r for r in history if r['event_type'] == 'INITIAL_MOVE_PROGRESS']
        signals = [r for r in history if r['event_type'] == 'SIGNAL']
        check(len(progress) <= 1, setup, 'first_progress_unique')
        check(len(signals) <= 1, setup, 'signal_unique')
        for row in progress:
            bar, closed, known = [stamp(row[k]) for k in
                                 ('first_progress_bar_time', 'first_progress_close_at', 'first_progress_known_at')]
            check(bar is not None and closed is not None and known is not None
                  and bar < closed <= known == stamp(row['event_at']), setup, 'progress_availability')
            check(stamp(row['wave1_peak_known_at']) <= known, setup, 'progress_after_fixed_anchor_known')
            price, peak = float(row['first_progress_price']), float(row['wave1_peak_price'])
            check(price > peak if row['direction'] == 'LONG' else price < peak, setup, 'strict_close_beyond_peak')
        for index, row in enumerate(history):
            if row['event_type'] == 'INVALIDATE' and row['reason'] == 'INITIAL_MOVE_MISSED':
                check(not any(r['event_type'] in {'SIGNAL', 'ORDER', 'FILL'} for r in history[index + 1:]),
                      setup, 'no_reuse_after_missed_move')
                check(bool(progress), setup, 'expiry_has_observed_progress')
        for row in signals:
            check(abs(float(row['lower_wave2_price']) - float(row['wave2_extreme_price'])) < 0.000001,
                  setup, 'signal_lower_extreme_bound_to_wave2')
            check(stamp(row['lower_wave2_time']) >= stamp(row['wave2_start_time']),
                  setup, 'signal_lower_extreme_inside_wave2')
            check(stamp(row['lower_structure_known_at']) < stamp(row['signal_at']),
                  setup, 'signal_structure_known_before_break')
            check(not progress or stamp(row['signal_known_at']) <= stamp(progress[0]['first_progress_known_at']),
                  setup, 'no_signal_after_first_progress')
    return {'path': str(path.resolve()), 'setups': len(grouped), 'rows': len(rows),
            'events': dict(Counter(r['event_type'] for r in rows)), 'checks': dict(counts),
            'violations': violations, 'passed': not violations}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--events', type=Path, action='append', required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    runs = [audit(p) for p in args.events]
    result = {'scope': 'CAUSAL_LIFECYCLE_NOT_VIDEO_OR_PROFITABILITY', 'runs': runs,
              'passed': all(r['passed'] for r in runs)}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'passed': result['passed'], 'runs': len(runs),
                      'checks': sum(sum(r['checks'].values()) for r in runs),
                      'violations': sum(len(r['violations']) for r in runs)}))
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()
