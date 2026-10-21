"""Report completion and execution uncertainty before performance metrics."""
import argparse
import json
from pathlib import Path
import pandas as pd
import plotly.graph_objects as go


def markdown(frame):
    cols=list(frame.columns)
    def v(x):
        return f'{x:.4f}' if isinstance(x,float) else str(x)
    return '| '+' | '.join(cols)+' |\n| '+' | '.join(['---']*len(cols))+' |\n'+'\n'.join('| '+' | '.join(v(x) for x in row)+' |' for row in frame.itertuples(index=False,name=None))


def render(out):
    out=Path(out);a=pd.read_parquet(out/'accounts.parquet');comp=pd.read_parquet(out/'comparison.parquet')
    m=json.loads((out/'manifest.json').read_text());q=json.loads((out/'qa/verification.json').read_text())
    stop=pd.read_csv(out/'qa/remaining_stops.csv')
    by_tf=a.groupby('timeframe').agg(scenarios=('scenario','size'),complete=('account_path_complete','sum'),
        closed_trades=('n_closed','sum'),closure_crossings=('n_closure_crossings','sum')).reindex(['M5','M15','H1']).reset_index()
    old_by=comp.groupby('timeframe').account_path_complete_old.sum()
    by_tf['old_complete']=by_tf.timeframe.map(old_by)
    reason=stop.groupby(['timeframe','evidence']).size().reset_index(name='scenarios') if len(stop) else pd.DataFrame(columns=['timeframe','evidence','scenarios'])
    no_censor=a[a.account_path_complete].copy()
    checked=int(a.account_path_complete.sum());old_checked=int(comp.account_path_complete_old.sum())
    positive=int((no_censor.net_pnl_usd>0).sum())
    text=f'''# 休場処理修正・固定候補の口座再評価

2026-10-17。全216条件・432会計シナリオを、元と同じ原候補・ATR・売買条件・コスト仮定で再実行した。旧成果物は上書きしていない。

**観測打切りなしは {old_checked} → {checked} / 432、打切りは {432-old_checked} → {432-checked}。** 週末相当の休場をまたぐ処理は修正したが、未検証の平日空白と祝日、実swapなどの制約が残る。打切りなしは価格経路の定義であり、USDCHFの17か月制約や全費用の検証完了を意味しない。

## 新旧比較

{markdown(by_tf)}

closed_trades・closure_crossingsは2会計シナリオを含む延べ件数。同じ候補を独立した2取引と解釈しない。各手法・方向・通貨の口座を合算したポートフォリオ損益ではない。

残った打切りの理由:

{markdown(reason)}

具体的な空白の始終端は [remaining_stops.csv](qa/remaining_stops.csv)。平日の価格不足を見つけた候補だけを事前除外せず、原候補を全て保持した。クリスマス/元日に一致する空白も、当時のbroker休場表が確認できなかったため未承認のまま残した。

## 変更点

- 足の時刻をエントリーからの絶対秒数で照合していた処理を、隣接する足の休場判定へ変更した。
- 承認するのはsource clockの正確な土曜00:00〜月曜00:00の48時間空白。歴史的broker時計を独立検証したとは呼ばない。余分な欠損が付く空白は承認しない。
- 保有10本は取引可能な実足10本。休場に仮想バーや価格を生成しない。実経過時間と休場回数は別記録。
- 週明けは実際の保存始値とspread proxyでSL/TPを評価し、窓開けで予定損失を超える場合もそのまま計上する。
- 既に決済した取引の後に空白があっても、その取引は取り消さない。元の打切り以前に決済した {q['original_prefix_trades_identical']:,} 件は新旧一致。

## 損益の読み方

`net_pnl_usd` は旧比較互換のspread/slippage/仮定commission控除後・未知swap控除前損益で、`net_pnl_before_unknown_swap_usd` と同じ値。全費用込みの `all_in_net_pnl_usd` と `swap_cost_usd` は欠測として保存した。未知swapを実測ゼロと解釈しない。

sourceの日境界数とlot日曝露を持ち越しの大きさとして保存したが、実際のrollover時刻・三倍swapのカウントではない。現在のswap値を2024–25年に遡及使用していない。swap・歴史仕様・証拠金・実約定が未検証のため全シナリオ昇格不可。

打切りなし {checked} シナリオのうち、未知swap控除前の損益正は {positive}。これは探索上の記述であり採択結果ではない。打切りが残るシナリオのPF/DDは途中までの値。観測期間が伸びた新旧の損益差を、同一期間での戦略改善と呼ばない。全件の旧値・新値は [comparison.csv](comparison.csv)、新会計値は [accounts.csv](accounts.csv)。

旧イベント統計・ランダム対照・648仮説の主評価は再計算・再選別していない。今回の工程は会計実装の修正であり、未知データでの収益性確認ではない。2026価格は使っていない。

## 検証

- [verification.json](qa/verification.json): 432シナリオの母数と会計整合、全決済の休場経路、{q['independent_cashflows']:,} 件の損益を独立式で再計算。
- 旧コード・データ・結果 {q['protected_files_unchanged']:,} ファイルのSHA一致。全原候補を2シナリオの台帳に保持。
- 連続データにおける旧実装との一致、週末LONG/SHORT・窓開けSL/TP・時間決済・次候補再開・未知空白・期間端・偽注釈の拒否をテスト。
- [カレンダー監査](../qa/calendar_sources.md) / [空白一覧](../qa/gap_audit.csv) / [テスト](../qa/pytest.xml)

[比較画面](dashboard.html) / [実行README](../../../../tools/entry_research/account_replay/README.md) / [固定計画](../../../../knowledge/experiments/2026-10-17-account-replay-plan.md)
'''
    (out/'report.md').write_text(text,encoding='utf-8')
    fig=go.Figure()
    fig.add_bar(name='旧: 打切りなし',x=by_tf.timeframe,y=by_tf.old_complete)
    fig.add_bar(name='修正後: 打切りなし',x=by_tf.timeframe,y=by_tf.complete)
    fig.update_layout(title='価格経路の観測打切りなし（各時間足144会計シナリオ）',barmode='group',template='plotly_white',yaxis_range=[0,144])
    cols=['symbol','timeframe','method','side','scenario','account_path_complete','data_months','n_closed','n_closure_crossings','net_pnl_before_unknown_swap_usd','profit_factor','max_drawdown_close_pct']
    table=a[cols].to_html(index=False,float_format=lambda x:f'{x:.3f}')
    html=f'''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>休場修正の口座評価</title>
<style>body{{font:16px/1.8 system-ui;margin:24px;background:#f5f7fa;color:#183442}}.warn{{background:#fff0c2;padding:16px}}.scroll{{overflow:auto}}table{{border-collapse:collapse;font-size:13px;background:white}}td,th{{padding:8px;border:1px solid #ddd;white-space:nowrap}}input{{padding:10px;width:80%;max-width:600px}}a{{color:#006895}}</style>
<h1>週末処理を修正した口座評価</h1><div class="warn">打切りなし {old_checked} → {checked} / 432。残り {432-checked} は原因未確定の空白等で停止。<br>未知swap控除前の仮定損益です。全費用込みの収益性、通年データ品質、ライブ運用の合格ではありません。</div>
<p><a href="report.md">詳細レポート</a> / <a href="accounts.csv">新口座CSV</a> / <a href="comparison.csv">新旧CSV</a> / <a href="qa/remaining_stops.csv">残った停止の理由</a></p>
{fig.to_html(full_html=False,include_plotlyjs=True)}
<h2>全432シナリオ（USDCHFは17か月）</h2><p>PF/DDは打切り口座では観測済み部分の値。2つの順序シナリオを独立した戦略・取引として数えないでください。</p><label for="filter">通貨・時間足・手法で絞り込み</label><br><input id="filter" placeholder="USDJPY H1 donchian"><p id="count"></p><div class="scroll" id="rows">{table}</div>
<script>const input=document.getElementById('filter'),rows=[...document.querySelectorAll('#rows tbody tr')];function filter(){{const words=input.value.toLowerCase().trim().split(/\\s+/);let n=0;for(const r of rows){{r.hidden=!words.every(w=>r.textContent.toLowerCase().includes(w));if(!r.hidden)n++;}}document.getElementById('count').textContent=n+' / '+rows.length+' シナリオ';}}input.addEventListener('input',filter);filter();</script></html>'''
    (out/'dashboard.html').write_text(html,encoding='utf-8')
    print(json.dumps(dict(old_complete=old_checked,new_complete=checked,remaining=432-checked,
                         positive_before_unknown_swap=positive),indent=2))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('out');render(p.parse_args().out)
