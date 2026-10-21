"""Saved Plotly dashboard and Japanese evidence report; no hosted service."""
import json
from pathlib import Path

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots


def markdown(frame):
    if frame.empty:
        return '該当なし。'
    cols = list(frame)
    lines = ['| '+' | '.join(cols)+' |', '| '+' | '.join(['---']*len(cols))+' |']
    for row in frame.itertuples(index=False, name=None):
        lines.append('| '+' | '.join(f'{x:.5g}' if isinstance(x, (float, np.floating)) else str(x) for x in row)+' |')
    return '\n'.join(lines)


def render(out):
    out = Path(out)
    primary = pd.read_parquet(out/'primary.parquet')
    summary = pd.read_parquet(out/'summary.parquet')
    accounts = pd.read_parquet(out/'accounts.parquet')
    manifest = json.loads((out/'manifest.json').read_text(encoding='utf-8'))
    data = json.loads(Path(manifest['data_manifest']).read_text(encoding='utf-8'))
    inventory = pd.read_parquet(out/'inventory.parquet')
    parts = ['<!doctype html><html lang="ja"><meta charset="utf-8"><title>MT5 Phase 3 research</title>',
             '<style>body{font-family:system-ui;margin:32px;background:#f5f7fb;color:#142535}h1,h2{color:#164c66}table{border-collapse:collapse;font-size:12px}td,th{padding:5px;border:1px solid #cbd5df}.notice{padding:16px;background:#fff3ce}</style>',
             '<h1>複数通貨・時間足のエントリー研究</h1>',
             '<p class="notice">2024–2025 開発内評価。2026不使用。バーspreadは約定コストproxy、手数料0・slippage片道0.2pipは仮定。USDCHFは17か月。PF/DDは個別口座の状態と観測打切りを併記。独立OOS・MT5収益性・ポートフォリオ利益を示すものではありません。</p>',
             '<p><a href="report.md">レポート</a> | <a href="primary.csv">主評価CSV</a> | <a href="summary.csv">全保有時間CSV</a> | <a href="accounts.csv">口座台帳集計</a></p>']
    first = True
    def add(fig, title):
        nonlocal first
        parts.append('<h2>'+title+'</h2>')
        fig.update_layout(template='plotly_white', font=dict(family='Arial'), margin=dict(l=50,r=25,t=50,b=50))
        parts.append(fig.to_html(full_html=False, include_plotlyjs=True if first else False))
        first = False
    for tf in inventory.timeframe.unique():
        sub = primary[primary.timeframe.eq(tf)].copy()
        sub['condition'] = sub.method+' '+sub.side
        piv = sub.pivot(index='condition', columns='symbol', values='net_atr')
        n = sub.pivot(index='condition', columns='symbol', values='n').reindex(index=piv.index, columns=piv.columns)
        fig = go.Figure(go.Heatmap(z=piv.to_numpy(), x=piv.columns, y=piv.index, colorscale='RdBu', zmid=0,
                                   customdata=n.to_numpy(), hovertemplate='%{x}<br>%{y}<br>net ATR=%{z:.4f}<br>n=%{customdata}<extra></extra>'))
        add(fig, tf+' H10ネット期待値（ATR）・件数')
    curve = summary.copy()
    curve['condition'] = curve.symbol+' '+curve.timeframe+' '+curve.side
    add(px.line(curve, x='horizon', y='mean_net_atr', color='method', line_dash='side',
                facet_col='timeframe', line_group='condition', hover_data=['symbol','n_complete']), '保有時間ごとの平均ネットリターン（各線は個別通貨・方向）')
    add(px.scatter(primary, x='delta_unconditional_atr', y='delta_conditional_atr', color='method', symbol='side',
                   facet_col='timeframe', hover_data=['symbol','n','weeks','net_atr']), '無条件対照差と環境一致対照差（H10 ATR）')
    distribution = []
    for p in sorted(out.glob('*/*/*/outcomes.parquet')):
        f = pd.read_parquet(p, columns=['horizon', 'complete', 'mfe_atr', 'mae_atr', 'method', 'side', 'candidate_id'])
        f = f[f.horizon.eq(10) & f.complete]
        # Stable IDs define the visual subsample, independent of outcome values.
        f = f.sort_values('candidate_id').sample(n=min(250, len(f)), random_state=manifest['seed'])
        f['symbol'], f['timeframe'] = p.parents[2].name, p.parents[1].name
        distribution.append(f)
    if distribution:
        dist = pd.concat(distribution, ignore_index=True)
        dist = dist.melt(id_vars=['method','side','symbol','timeframe'], value_vars=['mfe_atr','mae_atr'], value_name='ATR', var_name='measure')
        add(px.box(dist, x='method', y='ATR', color='measure', facet_col='timeframe', points=False, hover_data=['symbol','side']),
            'H10 MFE/MAE分布（各セル最大250件・固定シード、全件値はParquet）')
    env = pd.read_parquet(out/'environment.parquet')
    env['cell'] = env.symbol+' '+env.timeframe+' '+env.method+' '+env.side
    sample = env[env.condition.eq('vol_bucket')]
    add(px.scatter(sample, x='cell', y='value', color='mean_net_atr', size='n', color_continuous_scale='RdBu', color_continuous_midpoint=0,
                   hover_data=['weeks']), '事前ボラ区分とネット期待値（記述のみ・サイズは件数）')
    parts += ['<h2>全主評価セル</h2>', primary.to_html(index=False, float_format=lambda x: f'{x:.5g}'), '</html>']
    (out/'dashboard.html').write_text('\n'.join(parts), encoding='utf-8')
    positive = primary[primary.net_atr > 0]
    passes = primary[primary.exploratory_hypothesis_pass]
    best = primary.sort_values('net_atr', ascending=False).head(12)
    cols = ['symbol','timeframe','method','side','n','weeks','net_atr','net_ci_low','net_ci_high','delta_unconditional_atr','delta_conditional_atr','net_holm','exploratory_hypothesis_pass']
    text = f'''# Phase 3 複数通貨・時間足・戦略研究

対象: {manifest['server']}。2024-01-01以上2026-01-01未満。実行モード: {'QA pilot' if manifest['pilot'] else '全対象'}。

## 確認できた結果

- 評価した手法・方向セル: **{len(primary)}**。原候補合計 **{int(primary.n_candidates.sum()):,}**、H10観測可能 **{int(primary.n.sum()):,}**。
- H10ネットATRの点推定が正: **{len(positive)}セル**。事前固定の件数・年別・CI・648多重比較・期間品質をすべて通過: **{len(passes)}セル**。
- 計算結果は探索的。正の点推定だけでは未知データに対する優位性を確認したとは言えない。ライブ昇格は全件False。
- 旧3手法のdetectを変更せず、新3手法を同一の新取得データ・コスト・母集団規則で比較した。旧分析とデータ取得時点・コストモデル・共通warmup条件が異なるため、旧CSVとの単純差を戦略改善と呼ばない。

## データ品質

{markdown(inventory)}

USDCHFは2024-08-01以降だけを取得。欠けた2024年1〜7月は補完せず、年別比較も部分年。取得要求より後の最初の1本をAPIが返したケースは全応答を拒否・記録した。2026の価格は取得要求も分析もしていない。
時刻はAPI UTC契約に基づく整数秒だが、ブローカーサーバー時計との歴史的対応は独立検証できていない。東京/ロンドン/NYとの対応を推定せず、対照の時刻一致は同一source clock上で行った。データ出所は単一ブローカー。Askティック履歴はない。欠損間隔は週末・休場を含み、カレンダー検証前に一律データ障害とは呼ばない。
現在のpoint/pip/tick size/value/contract/lot仕様を保存。tick valueを過去損益換算に流用していない。口座USD換算は同時点の同一通貨価格を使用し、歴史的契約仕様の一致は未確認。

## 主評価（net ATR点推定の上位12件・選別後検証ではない）

{markdown(best[cols])}

全{len(primary)}セルを [primary.csv](primary.csv) に保存。全保有期間は [summary.csv](summary.csv)、[年別](annual.csv)、[月別](monthly.csv)、[Walk-forward](walk_forward.csv)、[相場環境](environment.csv)。

## 評価方法と限界

- エントリー足終値をH1とする。シグナルATR固定。Bid OHLCグロスとコスト控除後ネットを分ける。正値bar spreadは歴史proxy、不明ならUSDJPY1.5pip・他2pip、片道slippage0.2pip、手数料0を仮定。swap未検証のため、長時間保有のネットは全費用込み実損益ではない。
- 全候補を保存し、遅延・期間端・欠損の評価不能を記録。H10の比較は両群とも同じ完全観測プール。未来の完全性を実売買の選別に使わない。H50等では観測母集団が異なるので件数も参照。
- 無条件対照は通貨/時間足/年/方向/件数を一致、条件付き対照はさらに時間・曜日・相対ATRを一致。前者は全体現象、後者は環境を固定した追加効果を問う。収縮戦略の効果が条件付き比較で弱まっても直ちに無効とは言えない。
- 同一カレンダー週の再標本化を全市場で共有、B={manifest['config']['bootstrap_reps']}、10対照反復を独立標本と数えない。648仮説にHolmをかけ、未評価セルも予約。週を跨ぐ依存・仮説を選ぶ人間の過去研究は完全には除去できない。
- H10ネットATR、2対照差が主評価。他の保有時間・pips・環境sliceは記述に限定し、良いsliceだけを採用しない。相場環境の比較は新たなフィルター採択ではない。
- Walk-forwardは固定ルールの暦分割監査。trainのラベル終了から180000秒を空け、検証境界を跨ぐラベルを除外。学習・パラメータ選択はない。2024–25は使用済みなので独立OOSとは呼ばない。

## 売買シミュレーション

1ATR SL/TP・10本決済・0.1%リスク・USD10000、通貨/手法/方向ごと独立口座。重複候補はスキップ台帳。PF/R/DDは [accounts.csv](accounts.csv) の実行ルールに対してだけ計算。同足順序不明は2つの会計シナリオで表示し、実到達順を断定しない。残高依存lotと重複により2シナリオが全経路の数学的上下限とは限らない。
全口座シナリオ **{len(accounts)}**、観測打切りなし **{int(accounts.account_path_complete.sum()) if 'account_path_complete' in accounts else 0}**。欠損を跨ぐ建玉の出口は不明として口座計算をそこで止め、後続候補はblockedとして残す。この場合のPF/DD/残高は全期間の成績ではなく観測済み接頭区間だけ。週末を含む取引カレンダー・swap・証拠金未検証を解決するまで、通年PF/DDやポートフォリオ収益性を主張しない。

## 判断と次段階

{('事前条件を通過した探索仮説はない。追加条件で無理にプラスへ変えず、今回の固定条件はこの結果で記録する。' if passes.empty else '事前条件を通過したものも探索仮説に留まる。既知データ内の結果であり、独立した将来期間と実ティック約定検証前に採用しない。')}
方向・タイミング・出口のどれが原因かを本比較だけで因果分離できない。グロス正/ネット負は当該コスト仮定での費用影響を示すが、実際の業者コストが同額とは限らない。時間足・通貨別の差は次の事前仮説にできるが、ここでルールを変更して再選別しない。
独立データはルール凍結後の将来期間を確保する。例えば2027年の連続期間について凍結日、必要件数、1度だけの評価日、停止条件を事前登録する。2026を新しいOOSと呼び直さない。Stage3ポートフォリオ以降は今回未実施。

## 再現性・成果物

- [dashboard.html](dashboard.html)、CSV、Parquet、research.duckdb、セル別候補/対照/アウトカム/実行台帳。
- [manifest.json](manifest.json) に設定・seed・Git HEAD・未コミットソースSHA256・入力SHA256・依存version。保護対象 {manifest['protected_files_unchanged']} ファイル一致。
- QA pilotの目的は実装・データの整合性。利益によって全展開を決めていない。
- 詳細定義と昇格ゲート: [事前計画](../../../../knowledge/experiments/2026-10-16-multiasset-research-plan.md)。
'''
    (out/'report.md').write_text(text, encoding='utf-8')


if __name__ == '__main__':
    import sys
    render(sys.argv[1])
