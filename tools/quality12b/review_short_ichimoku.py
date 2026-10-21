"""Review completed short-only research without launching MT5 or fitting rules."""
import argparse
import json
from collections import Counter
from pathlib import Path

from analyze_relative_search import read_csv, write_csv
from analyze_ichimoku_diagnostics import statistics
from analyze_m5_context import extended_stats
from analyze_multitf_diagnostics import summary


def review(batch):
    assert json.loads((batch / 'status.json').read_text(encoding='utf-8-sig'))['status'] == 'COMPLETED'
    out = batch / 'review'
    out.mkdir(exist_ok=True)
    audits = []
    for name in ('short_control_2023_2024', 'short_2023_2024', 'short_2025_2026'):
        a = json.loads((batch / name / 'short_audit.json').read_text())
        assert a['passed']
        audits.append(dict(run_id=name, passed=a['passed'], observer=a['observer'],
                           trades=a['trades'], quality=a['quality']['category']))
    parity = json.loads((batch / 'short_2023_2024' / 'observer_parity.json').read_text())
    assert parity['passed'] and parity['exact_costs'] and parity['trades'] == 124
    raw = read_csv(batch / 'candidates_with_ichimoku.csv')
    actual = read_csv(batch / 'trades_with_ichimoku.csv')
    assert len(raw) == 1337 and len(actual) == 230
    assert len({(r['run_id'], r['id']) for r in raw}) == len(raw)
    assert all(r['side'] == 'sell' for r in actual)
    for label, rows, is_actual in [('shadow', raw, False), ('actual', actual, True)]:
        path = out / (label + '_recomputed.csv')
        write_csv(path, statistics(rows, is_actual))
        assert read_csv(path) == read_csv(batch / f'ichimoku_{label}_statistics.csv')
    groups = []
    for period in ('ALL', '2023', '2024', '2025', '2026'):
        for population, rows in [('all_shadow', raw),
                                 ('spread_allowed_shadow', [r for r in raw if r['spread_allowed'] == '1']),
                                 ('actual', actual)]:
            selected = [r for r in rows if r['h4_ichi_cloud_location'] == 'BELOW'
                        and (period == 'ALL' or r['year'] == period)]
            groups.append(dict(period=period, population=population,
                               **summary(selected, population == 'actual')))
    for pop in ('all_shadow', 'spread_allowed_shadow', 'actual'):
        write_csv(out / (pop + '_h4_below.csv'), [g for g in groups if g['population'] == pop])
    gates = read_csv(batch / 'execution_gate_counts.csv')
    spread = sum(int(r['n']) for r in gates if 'SPREAD' in r['flags'].split('|'))
    equity = sum(int(r['n']) for r in gates if 'EQUITY_CAP' in r['flags'].split('|'))
    assert sum(int(r['n']) for r in gates) == len(raw)
    info = dict(audit_passed=True, audits=audits, observer_parity=parity,
                actual=extended_stats(actual), shadow=summary(raw, False),
                spread_blocked=spread, equity_cap_blocked=equity,
                outcomes=dict(Counter(r['shadow_outcome'] for r in raw)))
    (out / 'review_audit.json').write_text(json.dumps(info, indent=2) + '\n')
    lines = ['# M5ショート・一目診断：完了レビュー', '',
             '## 結論', '',
             '**実装・診断の監査は合格。ショート全体もH4雲下の部分集合もマイナスで、今回の鏡像ショートは採用しない。**',
             'USDJPY、M5、SL=2.2ATR、RR=1.5、Equityリスク0.65%、最大保有18本。',
             '2023–2024と2025–2026年9月をそれぞれ初期資金10,000 USDで実行。以下の合計損益は別テストの単純合算で、連続複利成績ではない。', '',
             '## ロングとの比較', '',
             '|側・対象|取引数|純損益 USD|PF|勝率|平均価格R|月平均件数|',
             '|---|---:|---:|---:|---:|---:|---:|']
    for r in read_csv(batch / 'long_short_comparison.csv'):
        if r['period'] == 'ALL':
            group = '全体' if r['group'] == 'ALL' else ('H4雲上' if r['side'] == 'LONG' else 'H4雲下')
            lines.append(f"|{r['side']} {group}|{r['n']}|{float(r['net']):+.2f}|{float(r['pf']):.3f}|{float(r['win_rate']):.1%}|{float(r['mean_price_r']):+.3f}|{float(r['observed_monthly']):.2f}|")
    lines += ['', '雲上/雲下は既存実取引の事後分類。雲フィルターを組み込んだ再テストではない。取引を除外すると保有、日次件数、損失上限制御、Equityとロットも変わる。',
              'LONGとSHORTは別々のテストで、合算運用の利益や件数を示さない。', '',
              '## H4雲下ショートの年別内訳', '',
              '|年|実取引数|純損益 USD|PF|平均R|全候補平均R(n)|spread上限内候補平均R(n)|',
              '|---|---:|---:|---:|---:|---|---|']
    for year in ('2023', '2024', '2025', '2026'):
        g = {r['population']: r for r in groups if r['period'] == year}
        a, s, p = g['actual'], g['all_shadow'], g['spread_allowed_shadow']
        lines.append(f"|{year}{' 1–9月' if year == '2026' else ''}|{a['n']}|{a['net']:+.2f}|{a['pf']:.3f}|{a['mean_price_r']:+.3f}|{s['mean_price_r']:+.3f} ({s['n']})|{p['mean_price_r']:+.3f} ({p['n']})|")
    lines += ['', '実取引のH4雲下は2023だけプラス。2024は4件と小標本で、2025と2026も負。年をまたいだ正期待値は確認できない。', '',
              '## 母集団と実行制限', '',
              f'- 条件成立候補1,337件、実取引230件。実行は45か月で平均5.11件/月。月20件の目標に届かない。',
              f'- spread制限を含む見送りは{spread}件 ({spread / len(raw):.1%})。Equity上限を含む見送りは{equity}件。複数制限の同時該当があるため単純加算不可。',
              '- 2024年はピークEquityから12%の損失上限制御にも該当。2024の少数取引を相場シグナルの少なさだけで説明できない。制御は解除していない。',
              '- 全候補shadowは1,336件が評価可能、平均−0.156R、PF0.698。1分内SL/TP両到達1件は除外。実行制限を外した仮想評価でも負。',
              '- shadowはBid Entry / Ask決済。commission/swapや証拠金・保有制限を含まない。MFE/MAEは固定18本窓で、SL/TP到達後も含む。', '',
              '## 検証', '',
              '- MT5 3run完了、compile 0 errors / 0 warnings。controlは本集計へ重複算入していない。',
              '- 2023–2024の診断OFF/ONで124取引・コストが完全一致。2025以降はOFF対照試験を実施しておらず、監査JSONのobserver_parity=falseは比較未実施を表す。',
              '- 保存OHLCからM15/H1/H4一目4,701観測行を再構成し一致。確定時刻・未来OHLC追加の不変性検査合格。',
              '- SELLのSL>Entry>TP、Bid Entry / Ask評価、230件のリスク計算の監査合格。集計CSVも再計算一致。',
              '- 両期間ともMIXED_TICKS。2025以降のヘッダー100%表示も生成tick混在のログあり。完全リアルtickの検証とは扱わない。',
              '- 既知期間でありOOSではない。雲条件の最適化、本番反映、追加MT5ジョブは行っていない。', '',
              '## 判断', '',
              'ロング条件を上下反転しただけのショート追加は、今回の固定条件では利益・頻度の両方の目的を満たさない。',
              'この鏡像版は研究結果として保存し、条件を継ぎ足して採用へ進めない。ショートを改めて研究するなら、独立した仮説と固定比較を別途設計する必要がある。', '',
              '## 証拠', '',
              '- [監査集計](review_audit.json)',
              '- [ロング・ショート比較](../long_short_comparison.csv)',
              '- [年別集計](../annual_statistics.csv)',
              '- [実行制限内訳](../execution_gate_counts.csv)',
              '- [実取引](../trades_with_ichimoku.csv)',
              '- [全候補](../candidates_with_ichimoku.csv)']
    (out / 'summary.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps(info, ensure_ascii=False))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--batch', type=Path, required=True)
    review(p.parse_args().batch)
