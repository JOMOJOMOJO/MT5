"""Inspect native normal-chart inventories; never infer orders from screenshots."""
import argparse
import csv
import json
import re
from datetime import datetime, timedelta
from pathlib import Path


def read(path, delimiter=';'):
    with path.open(encoding='utf-8-sig', newline='') as stream:
        return list(csv.DictReader(stream, delimiter=delimiter))


def audit(root):
    violations, cases = [], []
    checks = 0

    def check(ok, case, rule):
        nonlocal checks
        checks += 1
        if not ok:
            violations.append({'case': case, 'rule': rule})

    for arm in ('A', 'B'):
        folder = root / f'final_drawing_{arm.lower()}' / arm
        fixture = read(folder.parent / f'{arm}_fixture.csv')
        for summary in read(folder / 'render_summary.csv', ','):
            index = summary['case']
            key = f'{arm}{index}'
            history = [r for r in fixture if r['review_index'] == index and r['setup_id'] == summary['setup_id']]
            inventories = list(folder.glob(f'*_case{index}_case{index}_objects.csv'))
            check(len(inventories) == 1, key, 'unique_native_inventory')
            if len(inventories) != 1:
                continue
            objects = read(inventories[0])
            check((folder / summary['image']).stat().st_size > 1000, key, 'actual_png_exists')
            check(summary['saved'] == '1', key, 'native_screenshot_saved')
            check(not any(r['type'] == 'OBJ_LABEL' for r in objects), key, 'no_fixed_panel')
            for obj in objects:
                if obj['type'] == 'OBJ_TREND':
                    check(obj['ray_left'] == obj['ray_right'] == '0', key, 'finite_line')
                if re.search(r'_(?:wave1_room|obstacle)(?:_label|_source|_source_label)?$', obj['name']):
                    tip = obj['tooltip']
                    times = re.search(r' source (\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}) known (\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}) adopted (\d{4}\.\d{2}\.\d{2} \d{2}:\d{2})$', tip)
                    check(tip.isascii() and len(tip) <= 120 and times is not None, key, 'complete_compact_reference_tooltip')
                    if times:
                        source, known, adopted = times.groups()
                        check(source <= known <= adopted <= summary['cutoff'][:16], key, 'reference_information_available')
                        if obj['type'] == 'OBJ_TREND':
                            check(obj['time1'][:16] >= known, key, 'reference_line_not_backdated')
                        if obj['name'].endswith('_source'):
                            # Display locates the upper candle's extreme on a
                            # closed lower bar inside that source candle.
                            frame = tip.split()[1]
                            seconds = {'M1': 60, 'M5': 300, 'M15': 900, 'H1': 3600}[frame]
                            begin = datetime.strptime(source, '%Y.%m.%d %H:%M')
                            plotted = datetime.strptime(obj['time1'], '%Y.%m.%d %H:%M:%S')
                            check(begin <= plotted < begin + timedelta(seconds=seconds), key, 'marker_inside_original_source_candle')
            rejected = any(r['event_type'] == 'RISK_CHECK' and r['wave1_room_rejected'] == '1' for r in history)
            close_rejected = any(r['event_type'] == 'INVALIDATE' and r['reason'] == 'FIB_CLOSE_TOO_DEEP' for r in history)
            has_entry = any('_entry_' in obj['name'] for obj in objects)
            if rejected:
                check(not has_entry, key, 'room_rejection_has_no_entry')
                check(any('_skip_' in obj['name'] for obj in objects), key, 'room_rejection_visible')
            if close_rejected:
                check(not has_entry, key, 'upper_close_rejection_has_no_entry')
                check(any('_skip_' in obj['name'] and 'FIB_CLOSE_TOO_DEEP' in obj['tooltip'] for obj in objects), key, 'upper_close_reason_visible')
                check(any('_fib_close_point_' in obj['name'] for obj in objects), key, 'upper_close_actual_price_marker')
            signal = next((r for r in history if r['event_type'] == 'SIGNAL'), None)
            if signal is None:
                check(not has_entry, key, 'untriggered_case_has_no_entry')
            chosen = signal or history[-1]
            cases.append({'arm': arm, 'case': int(index), 'setup_id': summary['setup_id'],
                          'cutoff': summary['cutoff'], 'objects': len(objects), 'room_rejected': rejected,
                          'fib_close_rejected': close_rejected,
                          'entry_visible': has_entry, 'direction': chosen['direction'],
                          'candidate_detected_at': chosen['candidate_detected_at'],
                          'wave1_peak_time': chosen['wave1_peak_time'],
                          'wave1_peak_known_at': chosen['wave1_peak_known_at'],
                          'trigger_known_at': chosen['trigger_known_at'],
                          'signal_known_at': chosen['signal_known_at'],
                          'lower_recognition': chosen['lower_recognition'],
                          'room_r': chosen['wave1_room_r'],
                          **{k: chosen.get(k, '') for k in ('fib_close_bar_time', 'fib_close_at', 'fib_close_known_at', 'fib_close_price', 'fib_close_ratio')},
                          'last_reason': history[-1]['reason'],
                          'image': str((folder / summary['image']).relative_to(root))})
    return {'kind': 'NORMAL_CHART_RECORDED_EVENT_REPLAY', 'tester_direct_screenshot': False,
            'checks': checks, 'violations': violations, 'passed': not violations, 'cases': cases}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.root)
    (args.root / 'drawing_audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'passed': result['passed'], 'cases': len(result['cases']), 'checks': result['checks'], 'violations': len(result['violations'])}))
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()
