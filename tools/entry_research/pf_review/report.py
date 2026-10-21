"""Report the post-selection audit without silently promoting a strategy."""
import os
from pathlib import Path

import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots


def md(frame):
    def fmt(x):
        if pd.isna(x):
            return '未定義'
        if isinstance(x, float):
            return f'{x:.4f}'
        return str(x)
    return '\n'.join(['| '+' | '.join(frame.columns)+' |', '| '+' | '.join(['---']*len(frame.columns))+' |'] +
                     ['| '+' | '.join(fmt(v) for v in row)+' |' for row in frame.itertuples(index=False, name=None)])


def render(out, tables, manifest):
    out = Path(out)
    plan_link = Path(os.path.relpath('knowledge/experiments/2026-10-17-positive-pf-followup-plan.md', out)).as_posix()
    summary, annual, boot = [tables[name] for name in ['summary', 'annual', 'bootstrap']]
    lower = summary.loc[summary.scenario.eq('stop_first_lower')]
    lower_annual = annual.loc[annual.scenario.eq('stop_first_lower')]
    primary = boot.loc[boot.scenario.eq('stop_first_lower') & boot.block_weeks.eq(4)]
    cost = tables['break_even'].loc[tables['break_even'].scenario.eq('stop_first_lower')]
    intra = tables['intrabar'].loc[tables['intrabar'].quote_model.eq('fixed_H1_spread_proxy')].copy()
    intra['entry_source_time'] = pd.to_datetime(intra.entry_time, unit='s', utc=True).dt.strftime('%Y-%m-%d %H:%M')
    intra['first_source_minute'] = pd.to_datetime(intra.first_minute, unit='s', utc=True).dt.strftime('%Y-%m-%d %H:%M')
    pairs = tables['scenario_pairs'].pivot(index=['symbol', 'timeframe', 'method', 'side'], columns='scenario', values='profit_factor').reset_index()
    lines = [
        '# PFが1を超えた条件の追加検証',
        '',
        '2026-10-17。ルールと既存データを変えずに、保存台帳を再集計した探索的な追加監査。2026年の価格は不使用。',
        '',
        '**USDJPY H1 ATR収縮ブレイクは両方向ともSL先着扱いでPF>1。SHORTは2024/2025の両年で正、LONGは2024が負。'
        'ただし平均Rの未補正95%区間は0を含み、現時点で正の期待値を確認したとは言えない。**',
        '',
        '## 観測事実',
        '',
        f'全{manifest["all_account_scenarios"]}口座シナリオ中PF>1は{manifest["positive_pf_scenarios"]}件、実質10条件。'
        'すべてH1。12件とも口座の途中打切りなし。ただしUSDCHFは17か月のみ。SL先着でもPF>1なのは今回の2方向だけ。',
        '',
        md(lower[['side', 'n_candidates', 'n_closed', 'pf', 'pnl_usd', 'mean_r', 'mean_pnl_usd', 'n_ambiguous']]),
        '',
        '損益はUSD10000開始・1回0.1%リスクの各独立口座。スプレッドproxy、片道0.2pipsの仮定スリップ、手数料0仮定を含む。'
        '**実swap控除前**であり、完全なネット利益ではない。LONG/SHORTの合算をポートフォリオ成績とみなさない。',
        '',
        '候補の残りはLONGが重複見送り14件、SHORTが重複1件・失効1件。[元候補の会計](event_accounting.csv)に全件数を残した。',
        '',
        '## 年別の違い',
        '',
        md(lower_annual[['side', 'year', 'n_closed', 'pf', 'pnl_usd', 'mean_r']]),
        '',
        '保存時刻の決済年で区分。LONGの通期プラスは年別に一貫しない。SHORTは両年プラスだが36件と30件だけで、'
        '独立した十分な再現性検証とは言えない。月別は[monthly.csv](monthly.csv)。実際のブローカーtimezoneを確認済みとはしていない。',
        '',
        '## 不確実性',
        '',
        md(primary[['side', 'n_closed', 'active_entry_weeks', 'mean_r', 'mean_r_ci_low', 'mean_r_ci_high',
                    'pf_ci_low', 'pf_ci_high', 'centered_one_sided_p', 'account_family_bonferroni_432']]),
        '',
        '2024–25の105カレンダー週には無取引週を含め、取引全体をエントリー週へ帰属。主は4週の循環移動ブロック、'
        '20,000反復、seed=20261017。PF/平均Rは保存取引の再標本化で、lotや資金管理を再実行した成績分布ではない。'
        '1週・8週の感度も固定して全件保存した。[bootstrap.csv](bootstrap.csv)',
        '',
        'CIは未補正の記述的95%区間。正の平均Rに対する中心化片側pは近似値で、432口座の選別に対するBonferroniも併記。'
        '循環接続、有限ブロック、相場の非定常性の制約があり、週数を独立標本数とは扱わない。'
        'それ以前のすべての探索まで補正したという意味ではない。2つの同足シナリオも独立標本ではない。',
        '',
        '## 追加コストに残された余裕',
        '',
        md(cost[['side', 'extra_roundtrip_pips_to_zero', 'extra_roundtrip_usd_per_lot_to_zero',
                 'n_source_day_crossing', 'lot_source_day_exposure']]),
        '',
        '上の水準は**既に差し引いたコストへの追加分**。pipsは保存exit換算率による会計負担、USD/lotは往復追加手数料。'
        'それぞれを単独加算した損益ゼロ点であり、実際のブローカー費用の見積りではない。'
        '日跨ぎ曝露はsource時計基準で、真のrolloverや三倍swap日数ではない。実swapを仮定で埋めない。',
        '',
        '保存した同じ約定・lotへの費用感度なので、スプレッドや滑りが変わった場合のSL/TP順序、エントリー可否、'
        'lot変化を再現しない。[cost_sensitivity.csv](cost_sensitivity.csv)には事前に固定した全水準を出力した。',
        '',
        '## 同足内の順序をM1で照合',
        '',
        md(intra[['side', 'entry_source_time', 'expected_m1', 'actual_m1', 'h1_bid_ohlc_match', 'first', 'first_source_minute']]),
        '',
        'エントリーから対象H1足末までのM1が連続し、時間ごとのBid OHLCもH1と一致。'
        'LONG3件はSL先着、SHORT2件はTP先着とSL先着が1件ずつ。同一M1足内両到達はなかった。'
        'SHORTはH1固定spreadとM1別spreadのAsk proxyで結論が一致した。',
        '',
        'M1はティック列・実際のAskではないため、厳密な約定順や価格の検証完了とはしない。'
        '今回、この判定を使って元口座の損益を差し替えていない。[intrabar.csv](intrabar.csv)',
        '',
        '## 利益集中の感度',
        '',
        md(tables['concentration'].loc[tables['concentration'].scenario.eq('stop_first_lower'),
                                      ['side', 'sensitivity', 'removed_month', 'removed_n', 'n_closed', 'pf', 'pnl_usd']]),
        '',
        '最高利益月を除いても両者はわずかにプラスだが、上位5勝を除けばPF<1。'
        '固定1ATR利確では勝ち額が近いため、「例外的な大勝ちだけに依存」とは断定しない。'
        'これは利益の余裕の参考検査であり、事後除外した新戦略や条件選別ではない。',
        '',
        '## PF>1だった全条件の対照',
        '',
        md(pairs),
        '',
        'その他8条件はTP先着扱いの場合だけPF>1。両シナリオは同足順序の仮定であり、'
        'lot丸め・資金推移もあるため数学的な全体上下限と断定しない。',
        '',
        '## 判断と次の検証',
        '',
        '確認できたことは「SL先着でも利益が残る2条件があり、SHORTは両年プラス」という点。'
        '仮説として、低ボラティリティ後の下方向ブレイクは固定検証を続ける候補になる。'
        'ただし少数標本、未補正CIの0跨ぎ、探索済み2024–25、実swap・Ask・tick・歴史仕様未確認が残る。',
        '',
        '以前のStage1イベント統計（固定H10・ランダム対照・648検定）に合格した結果ではない。'
        '今回の1ATR TP/SL付き口座PFと混同せず、[元のイベント統計](previous_event_statistics.csv)も保存した。'
        'Stage1/2の固定基準を緩めず、**運用採択はしない**。',
        '',
        '次の対象を絞るならSHORTの同一ルールを固定し、実ティック・実コスト照合と、ルール凍結後の未使用期間を検証する。'
        'LONGは年別不安定も残る。SHORTへフィルターを追加したり、TP/SLやリスクを変えて今回の結果を救済しない。'
        '2026の探索除外は維持する。この追加監査は完了しており、実ティック・将来期間の検証を実施済みとは扱わない。',
        '',
        '## 再現性と証拠',
        '',
        '[全概要CSV](summary.csv) / [ダッシュボード](dashboard.html) / [manifest](manifest.json) / [検算](qa.json) / '
        f'[固定計画]({plan_link})',
        '',
        '元台帳・価格・元コードのSHA256を検証。旧結果・EA・元データは変更しない。新規ソースはmanifestにSHAを保存。'
        '全表はCSVとParquet、DuckDBに保存した。',
    ]
    # Prevent a copied narrative from silently contradicting this run.
    assert (primary.mean_r_ci_low < 0).all() and (primary.mean_r_ci_high > 0).all()
    assert lower.set_index('side').loc['SHORT', 'both_years_positive']
    assert not lower.set_index('side').loc['LONG', 'both_years_positive']
    assert intra.complete_m1_path.all() and intra.h1_bid_ohlc_match.all()
    assert intra.loc[intra.side.eq('LONG'), 'first'].eq('stop_first').all()
    assert sorted(intra.loc[intra.side.eq('SHORT'), 'first']) == ['stop_first', 'target_first']
    (out/'report.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')

    fig = make_subplots(rows=2, cols=2, subplot_titles=[
        '年別損益（USD・実swap前）', '決済累積損益（USD・実swap前）',
        '保存取引への追加往復pips負担', '平均Rと未補正95%区間（SL先着）'])
    colors = {'LONG': '#3467d5', 'SHORT': '#c24d40'}
    for side in ['LONG', 'SHORT']:
        for scenario in ['stop_first_lower', 'target_first_upper']:
            label = f'{side} / '+('SL先着' if scenario == 'stop_first_lower' else 'TP先着')
            dash = 'solid' if scenario == 'stop_first_lower' else 'dot'
            data = annual.loc[annual.side.eq(side) & annual.scenario.eq(scenario)]
            fig.add_trace(go.Bar(x=data.year.astype(str), y=data.pnl_usd, name=label,
                marker_color=colors[side], opacity=1 if dash == 'solid' else .45), row=1, col=1)
            data = tables['realized_equity'].loc[lambda x: x.side.eq(side) & x.scenario.eq(scenario)]
            fig.add_trace(go.Scatter(x=pd.to_datetime(data.exit_time, unit='s', utc=True), y=data.cumulative_pnl_usd,
                name=label, showlegend=False, line=dict(color=colors[side], dash=dash)), row=1, col=2)
            data = tables['cost_sensitivity'].loc[lambda x: x.side.eq(side) & x.scenario.eq(scenario)
                & x.cost_axis.eq('extra_roundtrip_pips')]
            fig.add_trace(go.Scatter(x=data.extra_cost, y=data.pnl_usd, name=label, showlegend=False,
                mode='lines+markers', line=dict(color=colors[side], dash=dash)), row=2, col=1)
        data = boot.loc[boot.side.eq(side) & boot.scenario.eq('stop_first_lower')]
        fig.add_trace(go.Scatter(x=data.block_weeks.astype(str)+'週', y=data.mean_r, name=side, showlegend=False,
            mode='markers', marker_color=colors[side], error_y=dict(type='data', symmetric=False,
                array=data.mean_r_ci_high-data.mean_r, arrayminus=data.mean_r-data.mean_r_ci_low)), row=2, col=2)
    for row in [1, 2]:
        for col in [1, 2]:
            fig.add_hline(y=0, line_color='#999', line_width=1, row=row, col=col)
    fig.update_layout(height=790, template='plotly_white', font=dict(family='Arial, sans-serif', size=13),
                      margin=dict(t=65, b=40), legend=dict(orientation='h', y=1.12), barmode='group')
    figure = fig.to_html(full_html=False, include_plotlyjs=True)
    html = '<!doctype html><html lang="ja"><meta charset="utf-8"><title>Positive PF review</title>'
    html += '<style>body{font:16px/1.7 system-ui;margin:32px;color:#202733}table{border-collapse:collapse;font-size:14px}td,th{padding:7px;border:1px solid #ddd}p{max-width:1100px}.notice{background:#fff4dc;padding:14px}</style>'
    html += '<h1>PFが1を超えた条件の追加検証</h1><p class="notice">USDJPY H1 ATR収縮ブレイク。2024–2025の探索済みデータ。実swap前。元ルール・元台帳を変更していません。ライブ昇格不可。</p>'
    html += '<p>SHORTは両年プラス、LONGは2024年マイナス。両者の平均Rの95%区間は0を含みます。M1照合はティック順序の確定ではありません。</p>'
    html += '<p><a href="report.md">分析レポート</a> / <a href="summary.csv">概要CSV</a> / <a href="intrabar.csv">M1照合</a></p>'
    html += lower[['side', 'n_closed', 'pf', 'pnl_usd', 'mean_r']].round(4).to_html(index=False)
    html += figure + '<h2>年別（SL先着）</h2>'+lower_annual[['side', 'year', 'n_closed', 'pf', 'pnl_usd']].round(4).to_html(index=False)
    html += '<h2>追加コストで損益ゼロになる水準</h2><p>既存費用への追加分。同じ保存取引・lotを使った会計感度で、実際のコスト増加時の到達順序や資金管理は再計算しません。</p>'
    html += cost[['side', 'extra_roundtrip_pips_to_zero', 'extra_roundtrip_usd_per_lot_to_zero']].round(4).to_html(index=False)
    html += '<p>各方向は独立口座。図の累積損益は決済ベースで、含み損益・実swapを含まない。週単位再標本化は無取引週を含み、1/4/8週ブロックを併記。すべて探索的です。</p></html>'
    (out/'dashboard.html').write_text(html, encoding='utf-8')
