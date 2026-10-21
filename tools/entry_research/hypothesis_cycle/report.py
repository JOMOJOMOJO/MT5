"""Transparent complete-grid report; figures do not select a winning subset."""
from pathlib import Path
import html

import numpy as np
import pandas as pd
import plotly.graph_objects as go


def markdown_table(frame, columns):
    def fmt(value):
        if pd.isna(value):
            return 'NA'
        if isinstance(value, (float, np.floating)):
            return f'{value:.3f}'
        return str(value)
    return '\n'.join(['| ' + ' | '.join(columns) + ' |', '| ' + ' | '.join(['---'] * len(columns)) + ' |'] +
                     ['| ' + ' | '.join(fmt(row[c]) for c in columns) + ' |' for row in frame.to_dict('records')])


def render(out, tables, cycle):
    out = Path(out)
    v, m, a = tables['verdict'], tables['monthly'], tables['accounts']
    lower = 'stop_first_lower'
    primary = m.loc[m.cost.eq('base') & m.pause.astype(bool) & m.scenario.eq(lower) & m.cell_id.isin(v.cell_id)]
    grid = primary.pivot(index='cell_id', columns='month', values='equity_change_usd').reindex(
        index=v.cell_id, columns=pd.period_range('2024-01', '2025-12', freq='M').astype(str))
    values = grid.to_numpy(dtype=float)
    limit = max(1., float(np.nanmax(np.abs(values)))) if np.isfinite(values).any() else 1.
    heat = go.Figure(go.Heatmap(z=grid.to_numpy(), x=grid.columns.tolist(), y=grid.index.tolist(),
        colorscale='RdBu', zmid=0, zmin=-limit, zmax=limit, colorbar=dict(title='USD'),
        hovertemplate='%{y}<br>%{x}<br>MTM monthly change %{z:.2f} USD<extra></extra>'))
    heat.update_layout(title='Monthly equity change — SL first, base cost (blank = unavailable)',
                       height=830, margin=dict(l=365, r=70, t=65, b=65), yaxis=dict(autorange='reversed'))
    cost = go.Figure()
    for label, column in [('Base', 'net_usd'), ('Extra 1 pip round trip', 'stress_net_usd')]:
        cost.add_trace(go.Bar(name=label, y=v.cell_id, x=v[column], orientation='h'))
    cost.update_layout(title='Independent account PnL — swap unknown, USD 10,000 initial',
        height=830, barmode='group', margin=dict(l=365), yaxis=dict(autorange='reversed'), xaxis_title='USD')
    comp = tables['paired_comparison']
    comp = comp.loc[comp.cost.eq('base') & comp.scenario.eq(lower)]
    comparison = go.Figure()
    for label, col in [('Original with shared pause', 'original_cash_usd'), ('Margin >= 0.25 ATR', 'variant_cash_usd')]:
        comparison.add_trace(go.Bar(name=label, y=comp.cell_id, x=comp[col], orientation='h'))
    comparison.update_layout(title='Breakout adaptation: all seven fixed comparisons', barmode='group',
                             height=450, margin=dict(l=365), yaxis=dict(autorange='reversed'), xaxis_title='USD')
    counts = go.Figure()
    for label, col in [('Original candidates', 'n_original_candidates'), ('Admitted candidates', 'n_admitted_candidates'),
                       ('Closed trades', 'n_trades')]:
        counts.add_trace(go.Bar(name=label, y=v.cell_id, x=v[col], orientation='h'))
    counts.update_layout(title='Population accounting — rejected candidates remain recorded', height=830,
                          barmode='group', margin=dict(l=365), yaxis=dict(autorange='reversed'))
    figures = [heat, cost, comparison, counts]
    body = ['<!doctype html><html lang="ja"><meta charset="utf-8"><title>19条件 固定研究比較</title>',
            '<style>body{font-family:system-ui;margin:24px;max-width:1600px}p{line-height:1.7}.note{background:#fff4d5;padding:16px}</style>',
            '<h1>応用ブレイクとRSI2押し目 — 19条件の固定比較</h1>',
            '<p class="note">2024–2025年の探索済みデータ。2026年は不使用。独立口座の比較であり合算ポートフォリオではありません。'
            '主評価はSL先着。spread代理値・仮定slippageを含み、commissionは0仮定、swapは未知です。'
            '年末年始の新規休止を共通適用。空欄は未取得または未完結であり、損益ゼロではありません。</p>']
    for i, fig in enumerate(figures):
        body.append(fig.to_html(full_html=False, include_plotlyjs=True if i == 0 else False, div_id=f'cycle-{i}'))
    body.append('</html>')
    (out / 'dashboard.html').write_text('\n'.join(body), encoding='utf-8')
    positive = int((v.complete & v.pf.gt(1)).sum())
    monthly_pass = int(v.gate_monthly.sum())
    profit_pass = int(v.gate_profit.sum())
    first3 = int(v.survives_gates_1_to_3.sum())
    final = int(v.advance_to_independent_validation.sum())
    paused = a.loc[a.pause & a.cost.eq('base') & a.variant.ne('original')]
    raw = a.loc[~a.pause & a.cost.eq('base')]
    lines = [
        '# 応用ブレイクとRSI2押し目の固定研究サイクル', '',
        '2026-10-19 JST。19条件、2024–2025年のみ。既存7条件の単一応用と新規12条件を全件評価した。', '',
        f'**追加の独立検証へ進める条件は{final}/19件**。SL先着・基準費用の完結口座でPF>1は{positive}件。'
        f'総損益と両年損益ゲートは{profit_pass}件、月次・取引頻度ゲートは{monthly_pass}件、最初の3ゲート同時通過は{first3}件。', '',
        '## 実施した比較', '',
        '- A：7条件のブレイク終値が既存境界を0.25ATR以上超える場合だけ採用。ドンチャン/ATRは前20本境界、雲は26本シフト済みの表示境界。',
        '- B：6通貨H1×両方向。LONGは確定終値>EMA200かつRSI2が5以下から5超へ反転。SHORTは反対方向・95以上から95未満。次足以降の元の約定規則。',
        '- TP=SL=1ATR、最大10実足。1条件1方向ごと独立USD10,000、目標risk0.1%/回、lot切下げ、同時1ポジション。',
        '- 同足両到達はSL先着を主評価、TP先着を感度。費用ストレスは片道0.2→0.7pip、追加往復1pipを約定から再生。',
        '- 期間・閾値・19条件・ゲートは結果を見る前に保存。成績を見て閾値や通貨を選び直していない。', '',
        '## 主評価の全19条件', '',
        'net_usdはspread/slippage/commission設定を含むが未知swapを含まない仮定損益。PFの分母は負け損益。'
        'CIは取引Rの暦4週ブロック再標本化5,000回。未完結口座のPF/PnLは観測済み決済だけの参考値。', '',
        markdown_table(v, ['cell_id', 'complete', 'n_trades', 'pf', 'net_usd', 'stress_net_usd',
                           'equity_positive_months', 'data_months', 'equity_longest_negative_months',
                           'median_monthly_entries', 'mean_r_ci_low', 'mean_r_ci_high', 'holm_p']), '',
        '## 既存ブレイク応用の変化', '',
        '原候補を保持し、除外後に新たに入る取引も口座再生する。下表の見送った勝ち/負けは旧台帳との差分であり、'
        '単純削除の損益を実行結果と混同しない。原候補当たりR差の区間は同じ週を再標本化する。', '',
        markdown_table(comp, ['cell_id', 'original_complete', 'variant_complete', 'original_trades', 'variant_trades', 'removed_winners', 'removed_losers',
                              'new_trades', 'original_cash_usd', 'variant_cash_usd', 'cash_difference_usd']), '',
        markdown_table(v.loc[v.family.eq('A')], ['cell_id', 'paired_r_per_original', 'paired_ci_low', 'paired_ci_high']), '',
        '## 月次と停止判定', '',
        '月次損益は月末含み損益込み。無取引月も分母に残す。USDCHFの未取得2024年1〜7月はNA。'
        '利用可能月の2/3以上黒字、連続赤字3月以下、活動月80%以上、月別新規約定中央値5件以上を先に固定した。'
        '毎月の黒字を保証する基準ではなく、今回の研究継続目標である。年/月別再現性は独立OOSではない。', '',
        markdown_table(v, ['cell_id', 'net_2024_usd', 'net_2025_usd', 'gate_profit', 'gate_monthly', 'gate_stress',
                           'gate_statistics', 'control_status', 'failure_reasons']), '',
        '## カレンダー・候補母集団・未完了の扱い', '',
        '全主比較にsource暦12月24日〜1月2日の新規エントリー休止を適用。確定シグナル日、'
        'および実際の入口で観測できる約定日を検査する。未来の価格や欠損を検査して候補を選ばない。'
        'これは旧候補への共通の新運用条件であり、従来結果の完全再現ではない。実際の取引所/ブローカー祝日検証でもない。', '',
        f'新19条件×2順序のうち休止あり基準費用は{int(paused.account_path_complete.sum())}/{len(paused)}口座が完結。'
        f'休止なし対照は{int(raw.account_path_complete.sum())}/{len(raw)}口座が完結。'
        '未知欠損を跨いで未決済になる場合、強制的に平らとみなして再開しない。打切り後の月次値は作らない。', '',
        f'追加ランダム対照は最初の3ゲート通過条件のみ実行する事前規則。今回は対象{first3}条件、保存行{len(tables["random_controls"])}件。'
        '対象0なら実装の途中停止ではなく、固定した打切り判定である。対照は月と方向を共通にし、'
        '条件付き対照だけhour/weekday/volも一致させる。実行数は候補数と別である。', '',
        '## 解釈の限界と次の判断', '',
        '既存PF>1から選んだA、およびその過去診断に基づく仮説自体に選択偏りがある。19件のHolm補正は'
        '過去の探索全体を補正しない。4週ブロックCIは依存性への近似で、強い非定常性を解決しない。'
        '合計Rや各独立口座の損益を単純合算して運用ポートフォリオとはしない。', '',
        '実口座手数料・swap・歴史的lot仕様・source時計・marginは未検証。Bid OHLCとbar spreadからの代理約定であり、'
        'MT5実tickテストでも独立期間評価でもない。全費用控除後の実運用期待値が正と結論しない。', '',
        ('今回の固定目標を満たす条件がないため、2案の追加調整はここで保留する。月次赤字を見て毎月ルールを変更せず、'
         '次に進むなら別の市場仮説を少数固定し、未閲覧の将来期間を確保する。'
         if final == 0 else '通過条件も研究候補に限定する。実費確認、独立未閲覧期間、MT5実tick照合なしにEA運用へ昇格しない。'), '',
        '## 成果物', '',
        '- [対話型ダッシュボード](dashboard.html)',
        '- [全条件CSV](verdict.csv) / [月次CSV](monthly.csv) / [年次CSV](yearly.csv)',
        '- [元候補処理CSV](original_dispositions.csv) / [応用比較CSV](paired_comparison.csv)',
        '- [口座シナリオCSV](accounts.csv) / [ランダム対照CSV](random_controls.csv)',
        '- 同名Parquet、research.duckdb、accounts/の約定・イベント・equity台帳、candidates/の全候補。',
        '- manifest.jsonに入力/凍結実装/新実装SHA、Git版、依存版、seed、費用、holdout不使用を保存。', '']
    (out / 'report.md').write_text('\n'.join(lines), encoding='utf-8')
