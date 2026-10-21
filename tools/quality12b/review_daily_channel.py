"""Read-only review of the fixed daily-channel batch; never starts MT5 or tunes inputs."""
import argparse
from collections import Counter, defaultdict
from pathlib import Path
import hashlib
import json
import math
import statistics

from analyze_cost_channel import ROOT, read, write, save, metrics, native


def review(batch, package):
    manifest = json.loads((package / 'manifest.json').read_text(encoding='utf-8'))
    status = json.loads((batch / 'status.json').read_text(encoding='utf-8-sig'))
    assert status['status'] == 'COMPLETED'
    assert status['completed_runs'] == 3
    for name, expected in manifest['hashes'].items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected, name
    provenance = json.loads((batch / 'provenance.json').read_text(encoding='utf-8-sig'))
    assert hashlib.sha256((package / 'manifest.json').read_bytes()).hexdigest().upper() == provenance['manifest_sha256']

    out = batch / 'review'
    out.mkdir(exist_ok=True)
    trades, ledger, periods, audits, accepted = [], [], [], {}, []
    for spec in manifest['runs']:
        name = spec['run_id']
        run = batch / name
        audit = json.loads((run / 'audit.json').read_text(encoding='utf-8'))
        assert audit['passed']
        assert audit['quality']['matching_execution_blocks'] == 1
        assert audit['quality']['test_finished_in_block']
        assert audit['retry_audit']['rejected'] == audit['retry_audit']['marked']
        assert audit['retry_audit']['rejected'] == audit['retry_audit']['resolved'].get('RETRY_RESUMED', 0)
        audits[name] = {k: audit[k] for k in ['passed', 'retry_audit', 'reported_drawdown']}
        audits[name]['tick_quality'] = audit['quality']['category']
        rows = read(run / 'trades_cost_decomposition.csv')
        calculated = metrics(rows)
        for key, value in calculated.items():
            expected = audit['actual'][key]
            assert (value is None and expected is None) or math.isclose(value, expected, abs_tol=1e-8), (name, key)
        header, meta, _ = native(run / 'report.htm')
        assert meta['from_date'] == spec['date_from'] and meta['to_date'] == spec['date_to']
        assert meta['inputs']['InpRiskPercent'] == '0.25'
        assert meta['inputs']['InpEntryBars'] == '20' and meta['inputs']['InpExitBars'] == '10'
        if name == 'daily_smoke':
            continue  # Overlaps the first full period; never include its seven trades twice.
        for row in rows:
            row['run_id'] = name
        trades.extend(rows)
        periods.append(dict(run_id=name, **calculated,
                            native_equity_drawdown=audit['reported_drawdown'],
                            tick_quality=audit['quality']['category']))
        logs = read(run / 'telemetry.csv', ';')
        grouped = defaultdict(list)
        signal_keys = {(r['symbol'], r['signal_bar']) for r in logs if r['event'] == 'SIGNAL'}
        for row in logs:
            key = row['symbol'], row['signal_bar']
            if key in signal_keys:
                grouped[key].append(row)
        for (symbol, signal_bar), events in grouped.items():
            terminal = events[-1]
            assert terminal['event'] in ('SEND_RESULT', 'VOLUME_OR_RISK', 'PORTFOLIO_CAP'), terminal
            if terminal['event'] == 'SEND_RESULT':
                assert terminal['retcode'] == '10009'
                accepted.append(terminal)
            ledger.append(dict(run_id=name, symbol=symbol, signal_bar=signal_bar,
                               first_observed=events[0]['time'], last_observed=terminal['time'],
                               final_event=terminal['event'],
                               market_closed_attempts=sum(r['event'] == 'RETRY_MARKET_CLOSED' for r in events)))
        assert sum(r['run_id'] == name and r['final_event'] == 'SEND_RESULT' for r in ledger) == len(rows)
    assert len({(r['run_id'], r['position_id']) for r in trades}) == len(trades)
    aggregate_rows = [r for r in read(batch / 'all_trades.csv') if r['family'] == 'daily_channel']
    assert len(aggregate_rows) == len(trades)
    assert math.isclose(metrics(aggregate_rows)['net'], metrics(trades)['net'], abs_tol=1e-8)

    all_metrics = metrics(trades)
    breakdown = []
    symbols = manifest['symbols']
    for symbol in symbols:
        for year in ['ALL', '2023', '2024', '2025', '2026']:
            rows = [r for r in trades if r['symbol'] == symbol and (year == 'ALL' or r['year'] == year)]
            cash = [float(r['net']) for r in rows]
            best = max((x for x in cash if x > 0), default=None)
            breakdown.append(dict(symbol=symbol, year=year, **metrics(rows),
                                  best_trade_net=best,
                                  net_excluding_best=(sum(cash)-(best or 0) if cash else None)))
    sides = [dict(side=s, **metrics([r for r in trades if r['side'] == s])) for s in ('buy', 'sell')]
    months = read(batch / 'daily_monthly.csv')
    assert len(months) == 45 and sum(int(r['n']) for r in months) == len(trades)
    counts = [int(r['n']) for r in months]
    funnel = Counter(r['final_event'] for r in ledger)
    funnel_symbols = [dict(symbol=s, **{e: sum(r['symbol'] == s and r['final_event'] == e for r in ledger)
                                     for e in ['SEND_RESULT', 'VOLUME_OR_RISK', 'PORTFOLIO_CAP']}) for s in symbols]
    accepted_risks = [float(r['risk_money'])/float(r['equity'])*100 for r in accepted]
    quote_rows = [r for r in trades if r['quote_complete'] == 'True']
    quote_metrics = metrics(quote_rows)
    holding = [float(r['holding_hours'])/24 for r in trades]
    evidence = dict(status='REVIEWED_RESEARCH_ONLY', audits=audits, all=all_metrics,
                    periods=periods, sides=sides, unique_flat_signal_count=len(ledger),
                    signal_final_events=dict(funnel),
                    months=dict(n=45, mean=len(trades)/45, minimum=min(counts), maximum=max(counts),
                                zero=sum(x == 0 for x in counts), at_least_20=sum(x >= 20 for x in counts)),
                    holding_days=dict(mean=statistics.mean(holding), median=statistics.median(holding), maximum=max(holding)),
                    planned_risk_percent_accepted=dict(minimum=min(accepted_risks), mean=statistics.mean(accepted_risks), maximum=max(accepted_risks)),
                    synchronized_quote_subset=quote_metrics,
                    source_hashes={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                   for p in [package/'manifest.json', batch/'all_trades.csv', batch/'statistics.csv',
                                             Path(__file__).resolve()]})
    write(out / 'daily_period_statistics.csv', periods)
    write(out / 'daily_symbol_year_statistics.csv', breakdown)
    write(out / 'daily_side_statistics.csv', sides)
    write(out / 'signal_ledger.csv', ledger)
    write(out / 'signal_funnel_by_symbol.csv', funnel_symbols)
    save(out / 'review_audit.json', evidence)

    def pf(value):
        return 'NA' if value is None else f'{value:.3f}'

    lines = ['# 固定日足チャネル研究：最終確認', '',
             '## 結論', '',
             '修正版3本は完了し実行監査に合格。ただし今回の固定日足戦略は利益・頻度の両方で目標未達。'
             '本番採用せず、この設定の研究サイクルは中止とする。利益を見て銘柄や閾値を選び直さない。', '',
             '対象はUSDJPY / EURUSD / GBPUSD / AUDUSD / XAUUSD。日足20本チャネル終値突破、'
             '初期SL=日足ATR14×2、固定TPなし、反対側10本チャネル終値突破で決済。'
             '初期資金10,000 USD、リスク上限0.25%/取引。月20件を目指す従来のM5 EAとは別研究。', '',
             '## 損益', '',
             '|期間|取引数|純損益 USD|PF|勝率|native最大Equity DD|',
             '|---|---:|---:|---:|---:|---|']
    for r in periods:
        lines.append(f"|{r['run_id']}|{r['n']}|{r['net']:+.2f}|{pf(r['pf'])}|{r['win_rate']:.1%}|{r['native_equity_drawdown']}|")
    lines += [f"|合計|{all_metrics['n']}|{all_metrics['net']:+.2f}|{pf(all_metrics['pf'])}|{all_metrics['win_rate']:.1%}|合算しない|", '',
              '2023–2024と2025–2026年9月は各10,000 USDから独立開始。合計は取引損益の和であり、'
              '連続運用の複利収益率ではない。QAの7取引は重複集計していない。PFはswap等を含む取引純損益から再計算。', '',
              f"全96取引の平均約定価格R={all_metrics['mean_fill_r']:+.4f}。これは価格差/初期SL幅であり、"
              f"swapを含む口座通貨の平均Rではない。純損益/件={all_metrics['net']/len(trades):+.2f} USD。"
              f"swap合計={all_metrics['swap']:+.2f} USD、手数料・feeは記録上0。", '',
              '## 頻度と見送り', '',
              f"45か月平均{len(trades)/45:.2f}件/月、最少{min(counts)}、最多{max(counts)}件。"
              f"0取引の月={sum(x==0 for x in counts)}、20件以上の月={sum(x>=20 for x in counts)}。"
              f"平均保有{statistics.mean(holding):.1f}日、中央値{statistics.median(holding):.1f}日。", '',
              f"非保有時に記録された銘柄・シグナル日足の重複除去後{len(ledger)}件："
              f"実行{funnel['SEND_RESULT']}、ロット/リスク制限{funnel['VOLUME_OR_RISK']}、"
              f"最大保有数またはポートフォリオ/USD方向集中制限{funnel['PORTFOLIO_CAP']}。", '',
              'この戦略にはspread上限フィルターはない。休場再試行を候補数へ重複算入していない。'
              '保有中は新規シグナルを記録しないため、上記は全無制約shadow候補ではない。'
              '制限を外した場合は保有経路が変わるので、この件数から無制約成績を推定できない。', '',
              '|銘柄|実行|ロット/リスク見送り|保有/集中制限|',
              '|---|---:|---:|---:|']
    for r in funnel_symbols:
        lines.append(f"|{r['symbol']}|{r['SEND_RESULT']}|{r['VOLUME_OR_RISK']}|{r['PORTFOLIO_CAP']}|")
    lines += ['', 'XAUUSDは全149候補がVOLUME_OR_RISKで見送り、約定0。従ってゴールドの売買成績は未評価。'
              'コード上、この理由は刻み切り下げ後の最小ロット未満または予定損失の予算超過を指す。'
              '現行ログは両理由を分離していないので、全件を最小ロットだけが原因と断定しない。', '',
              f"成立注文の予定リスクはEquityの{min(accepted_risks):.3f}〜{max(accepted_risks):.3f}%、"
              f"平均{statistics.mean(accepted_risks):.3f}%。0.25%は上限で、ロット刻み以下へ切り下げるため常に0.25%にはならない。", '',
              '## 銘柄・方向・少数利益への依存', '',
              '|銘柄|n|純損益 USD|PF|最大利益1件を除く純損益|',
              '|---|---:|---:|---:|---:|']
    for r in [r for r in breakdown if r['year']=='ALL']:
        excluded = 'NA' if r['net_excluding_best'] is None else f"{r['net_excluding_best']:+.2f}"
        lines.append(f"|{r['symbol']}|{r['n']}|{r['net']:+.2f}|{pf(r['pf'])}|{excluded}|")
    lines += ['', 'USDJPYのプラスも20件の小標本で、最大利益1件を除くと負。'
              'この結果からUSDJPYだけ選んで採用する根拠にはしない。銘柄別は同時運用の内訳であり、独立した銘柄別テストではない。'
              'トレンド追随では少数の大きな利益への依存自体はあり得るため、最大利益除外だけを棄却理由にはしていない。', '']
    for r in sides:
        lines.append(f"- {r['side']}: {r['n']}件、純損益{r['net']:+.2f} USD、PF {pf(r['pf'])}。")
    lines += ['', '年別でも2023/2024/2025/2026は全体純損益が負。年はEntry年で分類し、期間末強制決済を含む。'
              '最大利益の除外は集中度診断だけで、外れ値として本集計から削除していない。', '',
              '## 実行の正しさと限界', '',
              '- コンパイル0 errors / 0 warnings。3runともnativeレポートとdeal/損益/件数/設定一致。5銘柄の期間先頭から末尾までの評価を確認。',
              '- 本比較2本の休場拒否は44+28=72回で、72回とも再開を記録。QAの8回も再開。未処理の休場再試行なし。',
              '- 初版の失敗run・途中レポートを採用していない。完了済みM5コスト分析4本はhash固定で再利用。',
              '- 本比較は生成tick混在（MIXED_TICKS）。既知期間なのでOOSではなく、実運用の保証でもない。',
              f"- 日足の同期quote両端が揃った取引は{len(quote_rows)}/{len(trades)}件だけ。"
              '残りも実損益には含め、コスト内訳のみ欠損とする。元summaryのmid/spread平均はこの部分集合、fill平均は全件なので横引き算しない。',
              f"- 同じ{len(quote_rows)}件に限定するとmid平均{quote_metrics['mean_mid_move_r']:+.4f}R − "
              f"spread平均{quote_metrics['mean_spread_cost_r']:.4f}R = fill平均{quote_metrics['mean_fill_r']:+.4f}R。"
              '欠損群へこの比率を外挿しない。',
              '- M5コスト分析は447/447件の同期quoteが揃う。LONGのmid寄与+0.077Rにspread負担0.070R、'
              'SHORTはmid寄与自体−0.068R。決済時刻固定の帰属であり無コスト再シミュレーションではない。',
              '- 本番EA・Shared・既存売買パラメータは変更していない。今回追加したのは読取り専用集計と記録のみ。', '',
              '## 次の判断', '',
              '今回の固定日足チャネルを、勝てる代替手法や月20回の解決策として採用しない。'
              'リスク制限を緩める、結果が良い銘柄だけ残す、退出本数を探索する追加テストは開始しない。'
              '引き継ぐのは注文監査・コスト分解・候補から実行までの件数記録。次の仮説は別途定義してから研究する。', '',
              '## 成果物', '',
              '- [全取引](../all_trades.csv)',
              '- [年別・全体集計](../statistics.csv)',
              '- [月別集計](../daily_monthly.csv)',
              '- [銘柄×年と最大利益依存](daily_symbol_year_statistics.csv)',
              '- [候補の最終状態](signal_ledger.csv)',
              '- [確認値と出典hash](review_audit.json)']
    (out/'summary.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    print(json.dumps(dict(output=str(out), n=len(trades), net=all_metrics['net'], pf=all_metrics['pf'],
                          months=evidence['months'], signals=len(ledger)), ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--batch', type=Path, required=True)
    parser.add_argument('--package', type=Path, required=True)
    args = parser.parse_args()
    review(args.batch.resolve(), args.package.resolve())
