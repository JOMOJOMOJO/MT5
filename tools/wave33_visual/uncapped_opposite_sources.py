"""Offline event barriers, not a reconstructed executable profit exit."""
import argparse
import csv
import hashlib
import json
from bisect import bisect_right
from pathlib import Path


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(2**20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    run = 'v185_b_scale_off'
    positions_path = args.batch/'analysis/positions.csv'
    event_path = args.batch/run/'events.csv'
    with positions_path.open(encoding='utf-8-sig', newline='') as f:
        positions = [r for r in csv.DictReader(f) if r['run'] == run]
    assert len(positions) == len({r['setup_id'] for r in positions}) == 334
    wanted = {r['setup_id'] for r in positions}
    fills, sources, original_arms = {}, {'LONG': [], 'SHORT': []}, {}
    with event_path.open(encoding='utf-8-sig', newline='') as f:
        for seq, row in enumerate(csv.DictReader(f, delimiter=';')):
            kind = row['event_type']
            if row['upper_tf'] != 'PERIOD_M5' or row['lower_tf'] != 'PERIOD_M1':
                continue
            if kind == 'FILL' and row['setup_id'] in wanted:
                assert row['setup_id'] not in fills
                fills[row['setup_id']] = (row['event_at'], seq)
            if kind == 'OPPOSITE_WAVE1_ARMED' and row['setup_id'] in wanted:
                assert row['setup_id'] not in original_arms
                original_arms[row['setup_id']] = row['opposite_wave_known_at']
            if kind == 'WAVE1_PEAK_CONFIRMED':
                sources[row['direction']].append(dict(
                    known_at=row['event_at'], sequence=seq,
                    source_setup_id=row['setup_id'], direction=row['direction'],
                    pivot_time=row['wave1_peak_time'], pivot_price=float(row['wave1_peak_price'])))
    keys = {side: [(x['known_at'], x['sequence']) for x in group] for side, group in sources.items()}
    assert len(fills) == 334
    for side in sources:
        assert keys[side] == sorted(keys[side])
    result = {}
    matched = 0
    for p in positions:
        side = 'SHORT' if p['direction'] == 'LONG' else 'LONG'
        i = bisect_right(keys[side], fills[p['setup_id']])
        source = sources[side][i] if i < len(sources[side]) else None
        if p['setup_id'] in original_arms:
            assert source and source['known_at'] == original_arms[p['setup_id']], p['setup_id']
            matched += 1
        result[p['setup_id']] = dict(source or {},
            original_arm_known_at=original_arms.get(p['setup_id'], ''),
            fill_sequence=fills[p['setup_id']][1])
    args.out.parent.mkdir(parents=True, exist_ok=True)
    payload = dict(scope='BASELINE_EVENT_BARRIER_NOT_EXECUTABLE_OPPOSITE_PROFIT_EXIT',
        n=334, original_arms_matched=matched,
        sha256={str(p):digest(p) for p in [positions_path, event_path, Path(__file__)]},
        by_setup=result)
    args.out.write_text(json.dumps(payload, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(n=334, original_arms_matched=matched,
        with_later_opposite=sum(bool(x.get('known_at')) for x in result.values()))))


if __name__ == '__main__':
    main()
