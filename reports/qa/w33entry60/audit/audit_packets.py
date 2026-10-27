"""Independent blind packet/source audit. Deliberately does not read labels/."""
from __future__ import annotations

from collections import Counter, defaultdict
import csv
from datetime import datetime, timedelta
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
DATA = HERE.parent / 'data'


def moment(value):
    return datetime.fromisoformat(value.replace('.', '-')) if value else None


def rows(path):
    with path.open(encoding='utf-8-sig', newline='') as handle:
        yield from csv.DictReader(handle, delimiter=';')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalize(raw):
    result = []
    for p in raw:
        if p['ambiguous_same_time']:
            result = []
        elif result and result[-1]['is_high'] == p['is_high']:
            better = p['price'] > result[-1]['price'] if p['is_high'] else p['price'] < result[-1]['price']
            if better:
                result[-1] = p
        else:
            result.append(p)
    return result[-8:]


def main():
    manifest = json.loads((DATA / 'manifest.json').read_text(encoding='utf-8-sig'))
    packet_path = DATA / 'blind/packets.json'
    payload = json.loads(packet_path.read_text(encoding='utf-8-sig'))
    packets = payload['cases']
    failures, checks = [], Counter()

    def check(condition, detail):
        checks['checks'] += 1
        if not condition:
            failures.append(detail)

    check(len(packets) == 60, 'packet count must be 60')
    check([p['blind_id'] for p in packets] == [f'V{i:03}' for i in range(1, 61)], 'unique neutral IDs')
    check(sha(packet_path) == manifest['packets_sha256'], 'frozen packet hash')
    check(Counter(p['arm'] for p in packets) == {'A': 30, 'B': 30}, 'A/B balance')
    check(Counter(p['direction'] for p in packets) == {'LONG': 30, 'SHORT': 30}, 'direction balance')
    forbidden = {'outcome', 'net_r', 'net_cash', 'exit_at', 'exit_reason', 'exit_price', 'realized_r',
                 'execution_net_cash', 'holding_minutes', 'holding', 'win', 'loss', 'mfe', 'mae', 'exit_sequence'}

    def inspect(value, where):
        if isinstance(value, dict):
            for k, v in value.items():
                check(k.lower() not in forbidden, f'{where}: forbidden key {k}')
                inspect(v, where + '.' + k)
        elif isinstance(value, list):
            for v in value:
                inspect(v, where)

    for p in packets:
        inspect(p, p['blind_id'])
    for name, expected in manifest['observed_inputs'].items():
        check(sha(ROOT / name) == expected, f'protected source hash: {name}')

    for arm in ('A', 'B'):
        cases = [p for p in packets if p['arm'] == arm]
        run = ROOT / cases[0]['provenance']['run']
        required = {p['order_sequence'] for p in cases} | {p['candidate_sequence'] for p in cases}
        for p in cases:
            for group in ('upper_pivots', 'lower_pivots', 'pre_pivots'):
                required.update(q['event_sequence'] for q in p[group])
        source_events, pivot_map = {}, defaultdict(list)
        for i, e in enumerate(rows(run / 'events.csv')):
            if i in required:
                source_events[i] = e
            if e['event_type'] == 'PIVOT_CONFIRMED':
                pivot_map[e['observed_pivot_tf']].append(dict(
                    time=moment(e['observed_pivot_time']).isoformat(' '),
                    known_at=moment(e['observed_pivot_known_at']).isoformat(' '),
                    price=float(e['observed_pivot_price']),
                    is_high=e['observed_pivot_label'] in ('H', 'HH', 'LH'),
                    label=e['observed_pivot_label'], event_sequence=i))
        for group in pivot_map.values():
            per_time = Counter(q['time'] for q in group)
            for q in group:
                q['ambiguous_same_time'] = per_time[q['time']] > 1
        source_bars = {}
        for name in ('upper', 'lower'):
            source_bars[name] = [dict(time=moment(b['bar_time']).isoformat(' '),
                                      closed_at=moment(b['closed_at']).isoformat(' '),
                                      known_at=moment(b['known_at']).isoformat(' '), source_row=i,
                                      **{k: float(b[k]) for k in ('open', 'high', 'low', 'close')})
                                 for i, b in enumerate(rows(run / f'{name}_bars.csv'), 2)]
        for p in cases:
            cid, order_seq = p['blind_id'], p['order_sequence']
            e = source_events[order_seq]
            candidate = source_events[p['candidate_sequence']]
            cut, closecut = moment(p['order_at']), moment(p['signalbarclosed_at'])
            check(e['event_type'] == 'ORDER', f'{cid}: not native ORDER')
            check(candidate['event_type'] == 'WAVE1_BREAK', f'{cid}: not native candidate')
            check(candidate['setup_id'] == e['setup_id'], f'{cid}: candidate identity')
            check(moment(e['event_at']) == cut == moment(p['render_cutoff_at']), f'{cid}: time cutoff')
            lower_minutes = int(p['lower_tf'].removeprefix('PERIOD_M'))
            check(moment(e['trigger_bar_time']) + timedelta(minutes=lower_minutes) == closecut <= cut, f'{cid}: trigger close cap')
            pre_cut = moment(p['pre_cutoff_at'])
            check(pre_cut == moment(e['upper_break_bar_time']), f'{cid}: precontext fixed at break open')
            for k, value in p['snapshot'].items():
                old = e[k]
                if value and k.endswith(('_time', '_at')):
                    old = moment(old).isoformat(' ')
                    check(moment(value) <= cut, f'{cid}: snapshot future field {k}')
                check(value == old, f'{cid}: snapshot differs from ORDER {k}')
            for name in ('upper', 'lower'):
                bars = p[f'{name}_bars']
                eligible = [b for b in source_bars[name] if moment(b['known_at']) <= cut and moment(b['closed_at']) <= closecut]
                check(bars == eligible[-300:], f'{cid}: {name} source bar replay mismatch')
                check(all(moment(b['known_at']) <= cut and moment(b['closed_at']) <= closecut for b in bars), f'{cid}: {name} future bar')
                check(p['window'][f'{name}_total_known'] == len(eligible), f'{cid}: {name} bar count')
                check(p['window'][f'{name}_origin_clipped'] == (moment(bars[0]['time']) > moment(e['wave1_start_time'])), f'{cid}: {name} crop flag')
                pivots = p[f'{name}_pivots']
                expected = [q for q in pivot_map[p[f'{name}_tf']] if q['event_sequence'] < order_seq and moment(q['known_at']) <= cut and q['time'] >= bars[0]['time']]
                check(pivots == expected, f'{cid}: {name} pivot causal source replay mismatch')
                for q in pivots:
                    check(q['event_sequence'] < order_seq and moment(q['known_at']) <= cut, f'{cid}: pivot knowledge beyond order')
            origin = moment(e['wave1_start_time'])
            pre_raw = [q for q in pivot_map[p['upper_tf']] if moment(q['time']) < origin and moment(q['known_at']) <= pre_cut and q['event_sequence'] < p['candidate_sequence']]
            check(p['pre_pivots'] == normalize(pre_raw), f'{cid}: pre8 normalization/source cutoff mismatch')
            checks['cases_audited'] += 1
    protected = json.loads((HERE / 'ea_before_hashes.json').read_text(encoding='utf-8-sig'))
    for item in protected:
        check(sha(Path(item['path'])).upper() == item['sha256'], f"EA changed: {item['path']}")
    result = dict(status='PASS' if not failures else 'FAIL', checks=dict(checks), failures=failures,
                  labels_read=False, quota_labels_pending=True,
                  blind_ids=[p['blind_id'] for p in packets],
                  pre8_missing=sum(len(p['pre_pivots']) < 8 for p in packets),
                  crop_counts={k: sum(p['window'][k] for p in packets) for k in ('upper_origin_clipped', 'lower_origin_clipped')})
    (HERE / 'packet_audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
