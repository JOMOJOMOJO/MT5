"""Audit finished runs without rerunning MT5 or overwriting original results."""
import argparse
import csv
import json
from collections import Counter
from pathlib import Path
from analyze_reports import analyze_report
from tick_quality import audit


def review(batch):
    rows, qualities, monthly = [], {}, []
    for d in sorted(batch.iterdir()):
        if not (d / 'report.htm').exists():
            continue
        m, trades = analyze_report(d / 'report.htm')
        q = audit(m['report'], d / 'journals/Tester')
        qualities[d.name] = q
        c = m['calculated']
        largest = m['largest_positive_trade']
        row = dict(run_id=d.name, date_from=m['report']['from_date'], date_to=m['report']['to_date'],
                   trades=c['trade_count'], wins=c['winning_trade_count'], losses=c['losing_trade_count'],
                   net=c['net_profit'], pf=c['profit_factor'], commission=c['commission'], swap=c['swap'],
                   equity_dd=m['reported']['equity_drawdown_maximal'],
                   header_real_tick_percent=q['header_real_tick_percent'], tick_category=q['category'],
                   strict_real_tick_pass=q['strict_real_tick_pass'], report_reconciles=m['audit']['passed'],
                   largest_trade=largest['net'] if largest else None,
                   static_excluding_largest_net=m['static_excluding_largest_trade']['net_profit'],
                   static_excluding_largest_pf=m['static_excluding_largest_trade']['profit_factor'])
        rows.append(row)
        counts = Counter(t['entry_time'][:7] for t in trades)
        start, end = m['report']['from_date'][:7].replace('.', '-'), m['report']['to_date'][:7].replace('.', '-')
        year, month = map(int, start.split('-'))
        while f'{year:04}-{month:02}' <= end:
            ym = f'{year:04}-{month:02}'
            if ym != end or m['report']['to_date'][8:] != '01':
                monthly.append(dict(run_id=d.name, month=ym, trades=counts[ym], tick_category=q['category']))
            month += 1
            if month == 13:
                year, month = year + 1, 1
    for name, records in [('reviewed_summary.csv', rows), ('monthly_trades.csv', monthly)]:
        with (batch / name).open('w', newline='', encoding='utf-8-sig') as f:
            writer = csv.DictWriter(f, fieldnames=list(records[0]))
            writer.writeheader()
            writer.writerows(records)
    result = dict(executions=len(rows), strict_real_tick_pass=sum(q['strict_real_tick_pass'] for q in qualities.values()),
                  category_counts=dict(Counter(q['category'] for q in qualities.values())),
                  original_status_preserved=True, original_metrics_preserved=True,
                  historical_audit_bug='Keyword-only real-tick detection accepted 0/14/99 percent and ignored fallback journals.',
                  strategy_verdict='NO_PROMOTION_REPRODUCIBLE_POSITIVE_EXPECTANCY_NOT_ESTABLISHED', quality_by_run=qualities)
    (batch / 'reviewed_quality.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'quality_by_run'}, ensure_ascii=True))
    for row in rows:
        print(row['run_id'], row['trades'], row['net'], round(row['pf'], 3), row['tick_category'])


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('batch', type=Path)
    review(p.parse_args().batch)
