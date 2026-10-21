"""Audit executable W1 room, source provenance and simple-route availability."""
import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path


def read(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f, delimiter=';'))


def audit(run):
    rows = read(run / 'events.csv')
    config = {r['parameter']: r['value'] for r in read(run / 'config.csv')}
    minimum = float(config['minimum_wave1_room_r'])
    pivots = {}
    groups = defaultdict(list)
    for r in rows:
        if r['event_type'] == 'PIVOT_CONFIRMED':
            key = (r['observed_pivot_tf'], r['observed_pivot_time'], round(float(r['observed_pivot_price']), 8))
            pivots[key] = r
        if r['setup_id']:
            groups[r['setup_id']].append(r)
    violations = []
    checks = 0

    def check(ok, row, rule):
        nonlocal checks
        checks += 1
        if not ok:
            violations.append({'setup_id': row['setup_id'], 'event': row['event_type'], 'at': row['event_at'], 'rule': rule})

    for r in rows:
        if r['event_type'] not in {'RISK_CHECK', 'ORDER', 'FILL', 'POSITION_TRACKING', 'COMPLETED', 'TEST_END'} or not r['entry_price'] or float(r['entry_price']) <= 0:
            continue
        direction = 1 if r['direction'] == 'LONG' else -1
        entry, sl, peak = [float(r[k]) for k in ('entry_price', 'sl_price', 'wave1_peak_price')]
        risk = direction * (entry - sl)
        if risk <= 0:
            continue
        expected = direction * (peak - entry) / risk
        check(abs(expected - float(r['wave1_room_r'])) < 1e-7, r, 'signed_room_matches_event_quote')
        if r['event_type'] == 'ORDER' and minimum > 0:
            check(expected + 1e-10 >= minimum and r['wave1_room_rejected'] != '1', r, 'order_respects_minimum_room')
        if float(r['nearest_obstacle_price']) > 0:
            if r['nearest_obstacle_source'] == 'WAVE1':
                check(r['nearest_obstacle_time'] == r['wave1_peak_time'] and r['nearest_obstacle_known_at'] == r['wave1_peak_known_at'] and abs(float(r['nearest_obstacle_price']) - peak) < 1e-7, r, 'wave1_source_identity')
            else:
                key = (r['nearest_obstacle_tf'], r['nearest_obstacle_time'], round(float(r['nearest_obstacle_price']), 8))
                p = pivots.get(key)
                check(p is not None and p['observed_pivot_known_at'] == r['nearest_obstacle_known_at'] <= r['event_at'], r, 'native_source_pivot_known')
                if p:
                    high = p['observed_pivot_label'] in {'H', 'HH', 'LH'}
                    check((r['nearest_obstacle_is_high'] == '1') == high and r['nearest_obstacle_source'] == ('SWING_HIGH' if high else 'SWING_LOW'), r, 'source_high_low_identity')
    for history in groups.values():
        risk = next((r for r in history if r['event_type'] == 'RISK_CHECK'), None)
        if risk and risk['wave1_room_rejected'] == '1':
            check(not any(r['event_type'] in {'ORDER', 'FILL'} for r in history), risk, 'rejected_candidate_never_ordered')
        for r in history:
            if r['event_type'] == 'SIGNAL' and r['lower_recognition'] == 'SIMPLE_REACTION_BREAK':
                times = r['lower_pivot_times'].split('|')
                prices = r['lower_pivot_prices'].split('|')
                check(len(times) == len(prices) == 2 and int(times[0]) < int(times[1]), r, 'simple_two_ordered_confirmed_anchors')
                check(r['lower_entry_stage'] == 'SIMPLE_REACTION_BREAK' and r['trigger_type'] == 'PIVOT_BREAK' and r['trigger_known_at'] <= r['trigger_bar_time'], r, 'simple_stage_and_preknown_pivot_only')
    return {'run': str(run), 'checks': checks, 'minimum': minimum, 'violations': violations, 'passed': not violations}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run', type=Path, action='append', required=True)
    p.add_argument('--out', type=Path, required=True)
    args = p.parse_args()
    runs = [audit(run) for run in args.run]
    result = {'scope': 'CAUSAL_EXECUTION_AND_SOURCE_NOT_PROFITABILITY', 'runs': runs, 'passed': all(r['passed'] for r in runs)}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'passed': result['passed'], 'checks': sum(r['checks'] for r in runs), 'violations': sum(len(r['violations']) for r in runs)}))
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()
