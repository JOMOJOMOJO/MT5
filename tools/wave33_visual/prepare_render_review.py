"""Select recorded events for draw-only normal-chart replay; never recalculate signals."""
import argparse
import csv
from datetime import datetime, timedelta
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    with (args.run / 'events.csv').open(encoding='utf-8-sig', newline='') as f:
        reader = csv.DictReader(f, delimiter=';')
        fields, events = reader.fieldnames, list(reader)
    with (args.run / 'review_cases.csv').open(encoding='utf-8-sig', newline='') as f:
        cases = list(csv.DictReader(f))
    result = []
    for index, case in enumerate(cases):
        history = [r for r in events if r['setup_id'] == case['setup_id']]
        cutoff_row = next((r for r in history if r['event_type'] == 'SIGNAL'), None)
        if cutoff_row is None:
            cutoff_row = next((r for r in history if r['event_type'] in {'INVALIDATE', 'SKIP', 'TEST_END'}), history[-1])
        cutoff = cutoff_row['event_at']
        start = (datetime.strptime(case['candidate_detected_at'], '%Y.%m.%d %H:%M:%S') - timedelta(hours=4)).strftime('%Y.%m.%d %H:%M:%S')
        for row in events:
            if row['event_at'] > cutoff:
                continue
            if row['setup_id'] == case['setup_id'] or (not row['setup_id'] and start <= row['event_at'] and row['event_type'] == 'PIVOT_CONFIRMED'):
                result.append({'review_index': index, 'review_id': case['setup_id'], 'review_cutoff': cutoff, **row})
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['review_index', 'review_id', 'review_cutoff'] + fields, delimiter=';')
        writer.writeheader()
        writer.writerows(result)
    print(f'{len(cases)} cases, {len(result)} original event rows; normal-chart rendering replay only')


if __name__ == '__main__':
    main()
