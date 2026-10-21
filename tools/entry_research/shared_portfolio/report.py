"""All fixed shared-capital profiles, with coverage and execution limits visible."""
import numpy as np
import pandas as pd
import plotly.graph_objects as go

from ..hypothesis_cycle.report import markdown_table


def render(out, tables, equity_by_profile, config):
    s, m, ref = tables['summary'], tables['monthly'], tables['independent_summary']
    lower = 'stop_first_lower'
    primary = s.loc[s.period.eq('common') & s['mode'].eq('hedging') & s.cost.eq('base') & s.scenario.eq(lower)].iloc[0]
    rows = m.loc[m.period.eq('common') & m.scenario.eq(lower)].copy()
    rows['label'] = rows['mode'] + '/' + rows.cost
    grid = rows.pivot(index='label', columns='month', values='equity_change_usd')
    limit = max(1., float(np.nanmax(np.abs(grid.to_numpy())))) if not grid.empty else 1.
    heat = go.Figure(go.Heatmap(z=grid.to_numpy(), x=list(grid.columns), y=list(grid.index),
        colorscale='RdBu', zmin=-limit, zmax=limit, zmid=0, colorbar=dict(title='USD'),
        hovertemplate='%{y}<br>%{x}<br>%{z:.2f} USD<extra></extra>'))
    heat.update_layout(title='Common period: monthly shared equity change — SL first', height=370,
                       margin=dict(l=190), xaxis=dict(type='category'))
    curve = go.Figure()
    for mode in ['hedging','block_opposite']:
        for cost in ['base','stress']:
            profile = f'common_{mode}_{cost}_{lower}'
            e = equity_by_profile[profile]
            curve.add_trace(go.Scatter(x=pd.to_datetime(e.time, unit='s',utc=True),
                y=e.equity_close_usd, name=f'{mode}/{cost}', mode='lines'))
    curve.update_layout(title='Shared capital: observed equity (initial USD 40,000)', height=420,
                        yaxis_title='USD', hovermode='x unified')
    p = equity_by_profile[primary.profile]
    concentration = go.Figure()
    for currency in ['USD','JPY','CHF','AUD']:
        concentration.add_trace(go.Scatter(x=pd.to_datetime(p.time,unit='s',utc=True),
            y=p[f'exposure_{currency}_usd'], mode='lines', name=currency))
    concentration.update_layout(title='Currency exposure in USD equivalent — primary scenario',
                                height=420,yaxis_title='Signed notional USD', hovermode='x unified')
    parts = ['<!doctype html><html lang="ja"><meta charset="utf-8"><title>固定4戦略 共有資金検証</title>',
        '<style>body{font-family:system-ui;margin:24px;max-width:1500px}p{line-height:1.7}.note{background:#fff4d5;padding:18px}</style>',
        '<h1>4戦略を共通口座で再生</h1>',
        '<p class="note">固定ルール・均等リスク配分。主期間は2024年8月1日08時〜2025年末のsource時刻。'
        '8月は部分期間とUSDCHF指標準備を含みます。価格時計・証拠金1:30・hedgingは未検証の仮定。'
        '手数料0仮定、swap未知。2026不使用、独立OOSではありません。block_oppositeは逆方向注文の見送りで、nettingの再現ではありません。</p>']
    for i, fig in enumerate([heat,curve,concentration]):
        parts.append(fig.to_html(full_html=False,include_plotlyjs=i==0,div_id=f'portfolio-{i}'))
    parts.append('</html>')
    (out/'dashboard.html').write_text('\n'.join(parts),encoding='utf-8')
    main = s.loc[s.period.eq('common') & s.scenario.eq(lower)]
    comparison = s.merge(ref, on=['period','cost','scenario'],suffixes=('_shared','_independent'),validate='many_to_one')
    comparison = comparison.loc[comparison['mode'].eq('hedging') & comparison.scenario.eq(lower)]
    comparison['trade_difference'] = comparison.n_closed_shared - comparison.n_closed_independent
    comparison['cash_difference_usd'] = comparison.net_pnl_before_unknown_swap_usd_shared - comparison.net_pnl_before_unknown_swap_usd_independent
    comparison.to_csv(out/'reference_comparison.csv',index=False,encoding='utf-8-sig')
    lines = ['# 固定4条件・共有資金の検証', '',
        '2026-10-19。ルール、配分、出口、暦休止を変更せず、候補全集合から共通口座を時系列再生した。', '',
        f'**主評価：{int(primary.n_closed)}取引、PF {primary.profit_factor:.4f}、'
        f'含み損益込み黒字{int(primary.get("monthly_positive",0))}/{int(primary.get("available_months",0))}月。** '
        f'総損益{primary.net_pnl_before_unknown_swap_usd:.2f}USD、初期40,000USDに対し{primary.net_return_pct:.3f}%。'
        f'完結={primary.account_path_complete}。', '',
        '## 固定条件', '',
        'USDJPY Donchian LONG応用、USDJPY ATR SHORT応用、USDCHF Donchian SHORT応用、AUDUSD RSI2 SHORT。'
        '同時刻はこの順。全体40,000USD、均等25%リスク配分、各配分の0.1%=全体equityの0.025%/取引。'
        '当初10USDで、前回の4独立口座に比べ資金・1取引リスクを増やしていない。', '',
        '各ルール1建玉、全体4建玉。予定初期SLリスク合計は全体equity0.1%、同一symbol0.05%以内で注文受付。'
        '日次3%減少・観測peakから5%減少で新規停止。既存建玉は元の出口を維持するため、'
        'これらはギャップを含む損失保証上限や足内即時kill-switchではない。', '',
        'TP/SL各1ATR、最大10実足。主評価SL先着、TP先着を感度として全件保存。'
        '基準slippage片道0.2pip、ストレス0.7pip。spreadはbar proxy、commission0仮定、swap未知。', '',
        '前足内決済→当足ギャップ決済→現在始値による評価→固定順新規の順序。'
        '数量計算・受付に現在足の高安終値や将来の決済結果を使わない。'
        '各候補の価格・約定経路は凍結エンジンから取得し、到来した時刻のmarkだけを共通口座へ反映。', '',
        '## 共通17か月の主順序比較', '',
        markdown_table(main, ['mode','cost','account_path_complete','n_closed','profit_factor',
            'net_pnl_before_unknown_swap_usd','net_return_pct','monthly_positive','available_months',
            'longest_negative_months','median_entries_per_month','max_drawdown_close_pct',
            'max_drawdown_adverse_envelope_pct','max_simultaneous_positions','peak_margin_used_usd']), '',
        'max_drawdown_close_pctは足終値だけでなく、観測した始値・新規約定・決済時点を含む評価DD。'
        'adverse_envelopeは通貨ごとの足内高安が同時に起きたと限らない保守的包絡DDで、実tick最大DDではない。', '',
        '## 同じ開始日にリセットした独立口座との比較', '',
        '比較対象も各10,000USDで開始し直し、同じ候補・暦休止・費用・順序・期間を使用。'
        '過去の利益による初期lot差と共有資金の影響を混同しない。共有口座と同じ資金総額40,000USD。', '',
        markdown_table(comparison, ['period','cost','n_closed_shared','n_closed_independent',
            'profit_factor_shared','profit_factor_independent','trade_difference','cash_difference_usd']), '',
        '## 全16シナリオ', '',
        markdown_table(s, ['period','mode','cost','scenario','account_path_complete','n_closed','profit_factor',
            'net_pnl_before_unknown_swap_usd','monthly_positive','available_months','max_drawdown_close_pct']), '',
        'mixed_referenceは2024年1月開始で、USDCHF未取得1〜7月は当該配分を使えず他へ再配分しない。'
        '4戦略が全て利用できた2年として扱わない。commonは2024年8月1日08時からflatで開始。'
        '最初の8時間未取得とUSDCHF指標準備期間を含むので、8月を完全取得月とは称さない。', '',
        '## 不確実性と実行上の制約', '',
        f'主評価の平均取引Rは{primary.mean_result_r:.4f}、暦4週ブロック5,000回の95%区間'
        f'[{primary.mean_r_ci_low:.4f}, {primary.mean_r_ci_high:.4f}]。4条件は過去の結果を見て選択済みで、'
        'この区間も選択偏りを解消しない。期間・mode・費用・順序は感度比較で、最良profileを選ぶ最適化ではない。', '',
        'hedgingを主仮定とし、block_oppositeは同じsymbolの逆方向注文を拒否する。'
        '実口座がnettingなら、反対売買による相殺・部分決済を別に実装検証する必要がある。'
        '証拠金はレバレッジ1:30、両建て減免なし。USDJPY/USDCHFはUSDベース額、AUDUSDは当時midで換算する。'
        'ブローカーの歴史的証拠金・mode・stopoutの再現ではない。'
        '[MT5公式の証拠金計算](https://www.metatrader5.com/en/terminal/help/trading_advanced/margin_forex)。', '',
        '予定SL損失は損失保証上限ではなく、4条件すべてUSDに関係する。通貨集中も別に保存した。'
        '新規受付時のmarginとリスクは検査するが、未知swap・commission・歴史的仕様・source時計を推測で補っていない。'
        '欠損で共通口座が止まれば、その後の月次をゼロとせず未完了とする。', '',
        '## 結果の扱い', '',
        '共有口座への統合は、既存の入口の期待値を増やす操作ではない。月次の補完、資金効率、建玉競合を確認する工程である。'
        '実際の黒字月数・赤字月数を上表の通り報告し、「ほぼ毎月黒字」や実運用への昇格とは判断しない。'
        '損失月だけを除外したり、好成績のprofileへ配分を変えたりしない。', '',
        '## 成果物', '',
        '[ダッシュボード](dashboard.html)、[全シナリオCSV](summary.csv)、[月次CSV](monthly.csv)、'
        '[年次CSV](yearly.csv)、[注文処理CSV](events.csv)、[取引CSV](trades.csv)、'
        '[独立口座比較CSV](reference_comparison.csv)。同名ParquetとDuckDBを保存。', '',
        'profiles/に各口座の約定・注文処理・equityを保存。manifest.jsonに固定条件・入力/凍結実装SHA・'
        '新コード版・依存版を保存。READMEとテストはtools/entry_research/shared_portfolio/。', '']
    (out/'report.md').write_text('\n'.join(lines),encoding='utf-8')
