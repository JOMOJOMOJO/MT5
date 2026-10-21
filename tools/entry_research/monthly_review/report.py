"""Monthly stability is reported separately from cumulative profit factor."""
import os
from pathlib import Path

import numpy as np
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots

NAMES = {'donchian':'ドンチャン', 'bollinger':'ボリンジャー回帰', 'ichimoku_cloud':'雲ブレイク', 'atr_breakout':'ATR収縮ブレイク'}


def md(frame):
    def fmt(value):
        if pd.isna(value):
            return '未取得/未定義'
        return f'{value:.3f}' if isinstance(value, float) else str(value)
    return '\n'.join(['| '+' | '.join(frame.columns)+' |', '| '+' | '.join(['---']*len(frame.columns))+' |']+
                     ['| '+' | '.join(fmt(x) for x in row)+' |' for row in frame.itertuples(index=False, name=None)])


def render(out, tables, manifest):
    out = Path(out)
    summary = tables['condition_summary']
    lower = summary.loc[summary.scenario.eq('stop_first_lower')].copy()
    upper = summary.loc[summary.scenario.eq('target_first_upper')]
    display = lower[['symbol','method','side','n','data_months','mean_trades_per_available_month','pf',
                     'realized_positive_months','realized_negative_months','no_trade_months']].copy()
    display['TP_first_PF'] = upper.pf.to_numpy()
    display['method'] = display.method.map(NAMES)
    outcomes = tables['loss_classes'].loc[tables['loss_classes'].scenario.eq('stop_first_lower')]
    loss_by_family = outcomes.loc[outcomes.loss_class.ne('non_losing')].groupby(['method','loss_class'], as_index=False).agg(
        n=('n','sum'), losing_cash_usd=('losing_cash_usd','sum'))
    by_family = tables['family_counts'].copy()
    by_family['method'] = by_family.method.map(NAMES)
    counts = manifest['counts']
    contexts = tables['context_slices'].loc[tables['context_slices'].scenario.eq('stop_first_lower')]
    attention = contexts.loc[contexts.sample_attention_flag].copy()
    nontrivial = attention.loc[attention.retained_trade_n.gt(0)]
    plan_link = Path(os.path.relpath('knowledge/experiments/2026-10-18-monthly-loss-diagnosis-plan.md', out)).as_posix()
    lines = [
        '# PF>1全条件の取引数・月次成績・負け方の診断', '',
        '2026-10-18。新規フィルタを適用せず、既存の実行台帳と確定時点の環境を再集計。2024–25は探索済み、2026は不使用。', '',
        '## 件数の意味', '',
        f'- PF>1の12会計シナリオの単純合計は **{counts["positive_scenario_trade_sum"]:,}取引**。',
        f'- 同じ条件のTP先着/SL先着重複を除くと **{counts["distinct_conditions"]}条件・{counts["distinct_logic_trades"]:,}取引**。両シナリオの候補ID集合が一致することを検証した。',
        f'- 同一通貨・方向・エントリー時刻のロジック間重複{counts["cross_logic_duplicate_groups"]}組もまとめると **{counts["distinct_symbol_side_entry_times"]:,}時点**。時点が異なっても時間依存はあるため、独立標本数とはしない。',
        f'- 全10条件の元候補は{counts["distinct_original_candidates"]:,}件。見送り・失効は[candidate_accounting.csv](candidate_accounting.csv)に保持。',
        '',
        'これらは研究上の模擬約定件数。10口座の共通資金・同時建玉・相関を反映したポートフォリオ取引数ではない。'
        '全24か月に割ると月平均111.1件だがUSDCHFは後半17か月のみ。期間途中の対象追加を固定ポートフォリオの頻度と混同しない。',
        '',
        md(by_family[['method','n','winners','losers','flat']]), '',
        '4系統のうちATR収縮ブレイクはドンチャン条件の部分集合。ロジック名が違うだけで独立した機会にはならない。', '',
        '## 条件別の月次実現損益', '',
        md(display), '',
        '全条件H1。PFと黒字/赤字月は主にSL先着の値、最後の列にTP先着PFを併記。8条件はTP先着だけPF>1なので、'
        '不利な順序での成績も表示して同足順序の都合よい選択を避ける。月は保存exit_timeの所属月。', '',
        'USDCHFの2024年1〜7月は未取得であり、無取引ゼロ月にはしない。表の無取引月は履歴のある月の新規約定0件を数える。決済0件の月も別列に保存。'
        '利益/損失は既存spread/slippage/commission仮定控除後・実swap控除前。手数料0仮定の妥当性も未検証。', '',
        '## 月末含み損益と最悪月', '',
        md(lower[['symbol','method','side','realized_worst_month_usd','realized_longest_negative_months',
                  'equity_positive_months','equity_negative_months','equity_worst_month_usd','equity_longest_negative_months']]), '',
        '決済損益とは別に、保存H1評価台帳の月末境界までの最終評価額の差を集計。境界時刻の足終値評価を含み、'
        '翌月始値のgap決済や新規エントリー評価は含めない。境界を跨ぐ取引では決済月と評価月がずれることがある。'
        '価格を補間せず、持越し件数・評価の経過時間を[monthly.csv](monthly.csv)に併記。'
        'これはsource時計とbar spread proxyによる評価で、未検証の実swapを含まない。独立口座の損益を合算して運用成績とはしない。', '',
        '## ロジック別の負け方', '',
        md(loss_by_family), '',
        '`stop_within_first_2_bars`はエントリー後1〜2実足の非曖昧SL損失、`stop_after_first_2_bars`は3本以上、'
        '`ambiguous_stop_loss`は同足TP/SL順序不明、`time_exit_loss`は固定10本時間決済での負け。'
        'これらは事後ラベル。エントリー時に将来のSL到達を知っていたことにはしない。', '',
        'ドンチャンはブレイク後早期のSLと上位足方向、ボリンジャーは回帰せずトレンドが続く環境、'
        '雲ブレイクは抜けた後の失速、ATR収縮ブレイクは低頻度と他ロジック重複、という観点で次の仮説を整理できる。'
        'この文章は調べる仮説であり、損失原因の因果的な確定ではない。', '',
        '## 事前情報による単独区分', '',
        f'H1方向一致/H4方向一致/既存相対ATR区分/雲位置の4軸で、SL先着の全{len(contexts)}区分を保存。'
        '組合せ探索・閾値最適化は行わず、unknownも残した。H1自身は`trend`、上位足はavailabilityを検証したH4を使う。'
        'H1候補で未設定の`h1_trend`や`m15_trend`を誤って方向判定に使わない。', '',
        f'n>=100、活動週>=30、各年30件以上で両年損益負、という記述用フラグは{len(attention)}区分。'
        f'そのうち除外後にも取引が残るものは{len(nontrivial)}区分。これは多重比較補正を通った戦略や採択条件ではない。', '',
        '[全区分と勝ちの取りこぼし](context_slices.csv) / [区分除外後の固定台帳月次](fixed_ledger_monthly_removals.csv)', '',
        '各区分には、避けられる損失件数/金額だけでなく、失う勝ち件数/利益、残存取引数、無取引月、悪化する月を出した。'
        '**保存取引を除く計算は新しい売買ルールのバックテストではない。** 元候補から再実行すると、'
        '重複制限で見送られていた別候補の約定、lot、資金推移も変わる。', '',
        '## 次の比較の作り方', '',
        '負けを減らす研究に使える母数はある。月単位の安定性を重視するなら、ドンチャンとボリンジャーのように'
        '月約15〜20取引ある条件も調べる価値がある。ATR SHORT単独は月約2.8件なので、これだけで毎月安定を目指すには標本が薄い。', '',
        '次の実験はこの記述診断から一つの事前条件だけを仮説化し、元候補全件を使ってフィルタなし/ありを同じ費用・出口で再生する。'
        '比較するのは勝率だけでなく、実費後期待値、黒字月率、最悪月、連続赤字月、月末含み損、残存件数と見送った勝ち。'
        '2024–25内の時系列分割は探索用であり、独立OOSとは呼ばない。2026の探索除外を維持する。', '',
        '毎月黒字を保証したり、過去の赤字月を見て月ごとのルールを選び直したりしない。'
        '条件を足した後に件数がほぼ消える場合も改善扱いにしない。最終的な併用は、各条件の固定検証後に共通資金・相関を含む別のポートフォリオ評価で行う。', '',
        '## 再現性', '',
        f'[固定計画]({plan_link}) / [manifest](manifest.json) / [検算](qa.json) / [月別チャート](dashboard.html)。'
        '旧EA・価格・候補・結果を変更しない。入力/ソース/出力SHA、元候補数、両順序の対応、全20口座の通期損益と月別合計を確認。',
    ]
    (out/'report.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')

    data = tables['monthly'].copy()
    data['label'] = data.symbol+' '+data.method.map(NAMES)+' '+data.side
    labels = list(dict.fromkeys(data.label))
    months = sorted(data.month.unique())
    fig = make_subplots(rows=3, cols=1, subplot_titles=[
        'SL先着：月別決済損益（USD、実swap前）', 'TP先着：月別決済損益（USD、実swap前）', '月別取引数（SL先着）'],
        vertical_spacing=.10)
    scale = max(abs(data.pnl_usd.min()), abs(data.pnl_usd.max()))
    for row, scenario in [(1,'stop_first_lower'), (2,'target_first_upper'), (3,'stop_first_lower')]:
        sub = data.loc[data.scenario.eq(scenario)]
        column = 'n' if row == 3 else 'pnl_usd'
        matrix = sub.pivot(index='label', columns='month', values=column).reindex(index=labels, columns=months)
        kwargs = dict(colorscale='Blues', showscale=False) if row == 3 else dict(colorscale='RdBu', zmin=-scale, zmax=scale, zmid=0, showscale=False)
        fig.add_trace(go.Heatmap(z=matrix.to_numpy(), x=months, y=labels,
            hovertemplate='%{y}<br>%{x}<br>'+column+': %{z:.2f}<extra></extra>', **kwargs), row=row, col=1)
    fig.update_layout(height=1250, template='plotly_white', margin=dict(l=255, r=30, t=60, b=65),
                      font=dict(family='Arial, sans-serif', size=12), plot_bgcolor='#eee')
    fig.update_yaxes(autorange='reversed')
    html = '<!doctype html><html lang="ja"><meta charset="utf-8"><title>Monthly loss diagnostics</title>'
    html += '<style>body{font:16px/1.7 system-ui;margin:28px;color:#24303a}table{border-collapse:collapse;font-size:13px}th,td{padding:6px;border:1px solid #ddd}.note{background:#fff4d7;padding:16px}.wide{overflow-x:auto}</style>'
    html += '<h1>全10条件の月次・負け方診断</h1><p class="note">12シナリオ延べ2,874取引 → 順序の重複除外2,666取引 → 同一通貨・方向・時刻もまとめると2,406時点。実swap前、探索済み2024–25。統合ポートフォリオの成績ではありません。</p>'
    html += '<p>灰色の月は未取得。黒字月と無取引月を区別。8条件はTP先着の場合だけ通期PF>1です。</p>'
    html += '<p><a href="report.md">分析レポート</a> / <a href="monthly.csv">月別CSV</a> / <a href="context_slices.csv">環境別と勝ちの取りこぼし</a></p>'
    html += '<div class="wide">'+display.round(3).to_html(index=False)+'</div>'
    html += fig.to_html(full_html=False, include_plotlyjs=True)
    html += '<p>ヒートマップは決済月の損益。月末含み損益を含む別の評価額・最悪月・持越し状況はレポートとCSVに記録しています。環境区分の除外計算は固定台帳の会計差であり、新しいフィルタ戦略を再実行した結果ではありません。</p></html>'
    (out/'dashboard.html').write_text(html, encoding='utf-8')
