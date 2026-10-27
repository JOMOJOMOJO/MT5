"""Fixed three-axis accounting review of existing Wave33 annual logs only."""
from __future__ import annotations

import argparse
from bisect import bisect_right
from collections import defaultdict
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path
from statistics import median


def rows(path, delimiter=';'):
    with path.open(encoding='utf-8-sig', newline='') as f:
        yield from csv.DictReader(f, delimiter=delimiter)


def stamp(text):
    return datetime.fromisoformat(text[:10].replace('.', '-') + text[10:])


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def num(row, key):
    return float(row[key])


def emit(path, records):
    if not records:
        return
    with path.open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(records[0]))
        w.writeheader()
        w.writerows(records)


def measure(selected):
    r = [x['net_r'] for x in selected]
    cash = [x['net_cash'] for x in selected]
    pos = sum(x for x in r if x > 0)
    neg = -sum(x for x in r if x < 0)
    pc = sum(x for x in cash if x > 0)
    nc = -sum(x for x in cash if x < 0)
    h1 = [x['net_r'] for x in selected if x['entry_at'] < '2020-07-01']
    h2 = [x['net_r'] for x in selected if x['entry_at'] >= '2020-07-01']
    h1mean = sum(h1)/len(h1) if h1 else None
    h2mean = sum(h2)/len(h2) if h2 else None
    n = len(r)
    return dict(n=n, wins=sum(x > 0 for x in r), losses=sum(x < 0 for x in r),
                win_rate=sum(x > 0 for x in r)/n if n else None,
                mean_r=sum(r)/n if n else None, net_r=sum(r), pf_r=pos/neg if neg else None,
                net_cash=sum(cash), pf_cash=pc/nc if nc else None,
                h1_n=len(h1), h1_mean_r=h1mean, h2_n=len(h2), h2_mean_r=h2mean,
                median_holding_minutes=median(x['holding_minutes'] for x in selected) if n else None,
                small_sample=n < 30, half_sign_flip=(h1mean*h2mean < 0) if h1 and h2 else False)


def bar_context(path):
    bars = list(rows(path))
    times = [stamp(x['known_at']) for x in bars]
    assert times == sorted(times)
    closed = [stamp(x['closed_at']) for x in bars]
    assert all(c <= k for c, k in zip(closed, times))
    tr, previous = [], None
    for row in bars:
        high, low, close = (num(row, k) for k in ('high', 'low', 'close'))
        tr.append(high-low if previous is None else max(high-low, abs(high-previous), abs(low-previous)))
        previous = close

    def at(known_at):
        i = bisect_right(times, known_at)-1
        assert i >= 13
        return sum(tr[i-13:i+1])/14, times[i].isoformat(' ')
    return at


def process_arm(batch, accounting, arm, run_name):
    # Select only the native events needed, preserving native order including equal timestamps.
    events = defaultdict(lambda: defaultdict(list))
    for seq, row in enumerate(rows(batch/run_name/'events.csv')):
        if row['event_type'] in {'ORDER', 'FILL', 'EXIT'}:
            row['_seq'] = seq
            events[row['setup_id']][row['event_type']].append(row)
    context = bar_context(batch/run_name/'upper_bars.csv')
    result = []
    for old in accounting:
        if old['arm'] != arm:
            continue
        e = events[old['setup_id']]
        assert len(e['ORDER']) == len(e['FILL']) == len(e['EXIT']) == 1
        order, fill, close = (e[k][0] for k in ('ORDER', 'FILL', 'EXIT'))
        assert order['_seq'] < fill['_seq'] < close['_seq']
        order_at = stamp(order['event_at'])
        # These are timestamps of information that the exact ORDER snapshot cites.
        for key in ('wave1_start_known_at', 'wave1_peak_known_at', 'wave2_extreme_known_at',
                    'signal_known_at', 'trigger_known_at'):
            assert order[key] and stamp(order[key]) <= order_at, (old['setup_id'], key)
        tr14, bar_known_at = context(order_at)
        sl_width = abs(num(order, 'entry_price')-num(order, 'sl_price'))
        tp_width = abs(num(order, 'tp_price')-num(order, 'entry_price'))
        w1_width = abs(num(order, 'wave1_peak_price')-num(order, 'wave1_start_price'))
        assert min(sl_width, tp_width, w1_width, tr14) > 0
        ratio = sl_width/tr14
        w1ratio = sl_width/w1_width
        net = num(close, 'execution_net_cash')
        risk = num(close, 'execution_initial_risk_money')
        assert abs(net-num(old, 'net_cash')) < 1e-7
        assert abs(net/risk-num(old, 'net_r')) < 1e-7
        result.append(dict(arm=arm, setup_id=old['setup_id'], direction=order['direction'],
                           order_at=order_at.isoformat(' '), entry_at=old['entry_at'], exit_at=old['exit_at'],
                           outcome='WIN' if net > 0 else ('LOSS' if net < 0 else 'FLAT'),
                           net_r=net/risk, net_cash=net, risk_cash=risk,
                           order_entry_price=num(order, 'entry_price'), order_sl_price=num(order, 'sl_price'),
                           order_tp_price=num(order, 'tp_price'), fill_entry_price=num(fill, 'entry_price'),
                           sl_width=sl_width, tp_width=tp_width, upper_tr14=tr14, upper_bar_known_at=bar_known_at,
                           sl_upper_tr14=ratio, sl_upper_tr14_bin='LT_1' if ratio < 1 else ('1_TO_2' if ratio < 2 else 'GE_2'),
                           wave1_width=w1_width, sl_wave1=w1ratio,
                           sl_wave1_bin='LT_0.5' if w1ratio < .5 else ('0.5_TO_1' if w1ratio < 1 else 'GE_1'),
                           tp_wave1=tp_width/w1_width,
                           wave1_peak_price=num(order, 'wave1_peak_price'), wave1_peak_known_at=order['wave1_peak_known_at'],
                           wave2_extreme_price=num(order, 'wave2_extreme_price'), wave2_extreme_known_at=order['wave2_extreme_known_at'],
                           retracement=num(order, 'retracement_ratio'), lower_recognition=order['lower_recognition'],
                           holding_minutes=num(old, 'holding_minutes'), exit_mechanism=close['exit_reason']))
    return sorted(result, key=lambda x: (x['entry_at'], x['setup_id']))


def fmt(value, digits=3):
    return '—' if value is None else f'{value:.{digits}f}'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch', type=Path, default=Path('reports/backtest/runs/wave33_v170_2020/20261022_161002_0ef87d9b'))
    parser.add_argument('--accounting', type=Path, default=Path('reports/backtest/runs/wave33_v170_2020/analysis/trades.csv'))
    parser.add_argument('--out', type=Path, default=Path('reports/backtest/runs/wave33_v170_2020/pattern_review_20261023/mechanisms'))
    args = parser.parse_args()
    definitions = args.out/'definitions.json'
    assert definitions.exists(), 'Write fixed definitions before running analysis'
    def_data = json.loads(definitions.read_text(encoding='utf-8'))
    accounting = list(rows(args.accounting, ','))
    trades = []
    for arm, name in [('A', 'a_extension_on'), ('B', 'b_extension_on')]:
        trades.extend(process_arm(args.batch, accounting, arm, name))
    assert len(trades) == len(accounting) == 475
    groups = []
    for arm in ('A', 'B'):
        selected = [x for x in trades if x['arm'] == arm]
        groups.append(dict(arm=arm, axis='ALL', bucket='ALL', **measure(selected)))
        for axis in ('sl_upper_tr14_bin', 'sl_wave1_bin', 'exit_mechanism'):
            values = sorted({x[axis] for x in selected})
            for value in values:
                groups.append(dict(arm=arm, axis=axis, bucket=value, **measure([x for x in selected if x[axis] == value])))
    outcome_hold = []
    examples = []
    payoff_balance = []
    for arm in ('A', 'B'):
        selected = [x for x in trades if x['arm'] == arm]
        for reason in sorted({x['exit_mechanism'] for x in selected}):
            subset = [x for x in selected if x['exit_mechanism'] == reason]
            sign_r = sum(1 if x['net_r'] > 0 else (-1 if x['net_r'] < 0 else 0) for x in subset)
            actual_r = sum(x['net_r'] for x in subset)
            payoff_balance.append(dict(arm=arm, exit_mechanism=reason, n=len(subset),
                                       outcome_sign_sum=sign_r, actual_net_r=actual_r,
                                       actual_minus_sign_sum=actual_r-sign_r))
        for outcome in ('WIN', 'LOSS'):
            outcome_hold.append(dict(arm=arm, outcome=outcome, **measure([x for x in selected if x['outcome'] == outcome])))
            for bucket in ('LT_1', 'GE_2'):
                candidates = [x for x in selected if x['outcome'] == outcome and x['sl_upper_tr14_bin'] == bucket]
                if candidates:
                    examples.append(dict(example_rule=f'{arm}:{bucket}:{outcome}:first_entry', **candidates[0]))
        candidates = [x for x in selected if 'OPPOSITE' in x['exit_mechanism']]
        if candidates:
            examples.append(dict(example_rule=f'{arm}:OPPOSITE:first_entry', **candidates[0]))
    args.out.mkdir(parents=True, exist_ok=True)
    emit(args.out/'trades_order_snapshot.csv', trades)
    emit(args.out/'fixed_groups.csv', groups)
    emit(args.out/'holding_outcomes.csv', outcome_hold)
    emit(args.out/'examples.csv', examples)
    emit(args.out/'payoff_balance.csv', payoff_balance)
    inputs = [definitions, args.accounting]
    for name in ('a_extension_on', 'b_extension_on'):
        inputs.extend(args.batch/name/x for x in ('events.csv', 'upper_bars.csv', 'config.csv'))
    summary = dict(definitions=def_data, source_hashes={str(x):sha(x) for x in inputs},
                   n=len(trades), groups=groups, holding_outcomes=outcome_hold, payoff_balance=payoff_balance,
                   checks=dict(all_475_accounting_matched=True, native_order_before_fill_before_exit=True,
                               entry_fields_known_by_order=True, no_future_upper_bars=True),
                   script_hash=sha(Path(__file__)))
    (args.out/'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    report = ['# 年間ログ：SL幅と出口の固定区分', '',
              '今回の475件では「SLが広いほど負けやすい」は確認できない。値動きに対してSLが広いSL/TR14≥2群はAが33件・平均+0.022R、Bが82件・平均−0.076Rで、どちらも前半/後半の平均が符号反転した。価格のSL幅が広くても、リスク1%のロット計算で金額リスクまで大きくなるわけではない。TPが遠くなる効果と到達しやすさは別に検証が必要。', '',
              'SL/W1が0.5以上の群はA11件/B36件で平均が双方約+0.076Rだが、Aは前半−0.352R/後半+0.590Rで少数。浅い群を排除する、あるいはSLを広げる採用根拠にはしない。SL/W1≥1の約定は両組0件。', '',
              '年間の損失は、約1RのSL負けをTP勝ちで回収できていない構成で説明できる。Aの51回のSLは−52.155Rに対し、40回のTPは+38.602R、6回の逆①利益決済は+0.729R。Bは190回のSLが−199.277R、165回のTPが+158.694R、23回の逆①利益決済が+3.261R。BのTPには費用込みで負けの1件を含む。逆①を外した方がよいという意味ではなく、実際の勝ちが何R増やしたかの分解。', '',
              '475件すべてを既存会計へ照合。特徴はFILLより前のORDERスナップショットに固定した。上位TR14は注文までに既知の確定足14本の単純平均で、Wilder ATRとは異なる。SL幅は価格距離であり、金額リスク1%の大小とは異なる。', '',
              '出口理由・保有時間は取引後に決まる説明量で、事前に使えるフィルターではない。前半/後半は1–6月/7–12月のエントリーで分割し、未使用期間とは扱わない。', '',
              '|組|固定区分|件数|勝率|平均R|合計R|R-PF|前半 件/平均R|後半 件/平均R|注意|',
              '|---|---|---:|---:|---:|---:|---:|---:|---:|---|']
    for row in groups:
        flags = '; '.join((["n<30"] if row['small_sample'] else []) + (["前後半で符号反転"] if row['half_sign_flip'] else []))
        label = row['bucket'] if row['axis'] in ('ALL','exit_mechanism') else ('SL/TR14 ' if row['axis']=='sl_upper_tr14_bin' else 'SL/W1 ')+row['bucket']
        report.append(f"|{row['arm']}|{label}|{row['n']}|{100*row['win_rate']:.1f}%|{fmt(row['mean_r'])}|{fmt(row['net_r'])}|{fmt(row['pf_r'])}|{row['h1_n']}/{fmt(row['h1_mean_r'])}|{row['h2_n']}/{fmt(row['h2_mean_r'])}|{flags}|")
    report.extend(['', '## 保有時間（事後記述）', '', '|組|純損益|件数|保有中央値・分|平均R|', '|---|---|---:|---:|---:|'])
    for row in outcome_hold:
        report.append(f"|{row['arm']}|{row['outcome']}|{row['n']}|{fmt(row['median_holding_minutes'],1)}|{fmt(row['mean_r'])}|")
    report.extend(['', '## 最初の該当例（事後に勝敗で分類）', '',
                   '以下は良し悪しの最大例を探さず、各固定区分の最初の約定を載せた。図の視認比較用の時刻と因果情報はexamples.csvに保存。価格・SL・TPと①/②の既知時刻も同CSVから追える。', '',
                   '|組・区分|setup_id|エントリー→決済|SL/TR14|SL/W1|結果R|出口|',
                   '|---|---|---|---:|---:|---:|---|'])
    for x in examples:
        report.append(f"|{x['example_rule']}|{x['setup_id']}|{x['entry_at']}→{x['exit_at']}|{x['sl_upper_tr14']:.2f}|{x['sl_wave1']:.2f}|{x['net_r']:.3f}|{x['exit_mechanism']}|")
    report.extend(['', '全区分・純損益PF・サンプル事例は同階層CSV、入力ハッシュ・照合定義はsummary.jsonとdefinitions.json。payoff_balance.csvの符号和は実際の勝ちに+1/負けに−1を割り当てた会計上の対照であり、別の出口なら実現した利益という仮想成績ではない。区分境界の探索、仮想TP変更、EA修正は行っていない。', ''])
    (args.out/'README.md').write_text('\n'.join(report), encoding='utf-8')
    print(json.dumps(dict(n=len(trades), groups=len(groups), examples=len(examples), checks=summary['checks']), ensure_ascii=False))


if __name__ == '__main__':
    main()
