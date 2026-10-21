"""Generate a reviewable Japanese report from the complete frozen outputs."""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


LABELS = {'immediate_adverse': '即時逆行', 'favorable_then_reversal': '順行後の反転',
          'adverse_then_favorable': '逆行後の順行', 'favorable_continuation': '順行継続',
          'no_direction': '方向感なし', 'ambiguous_order': '同足内順序不明',
          'unclassified_other': '分類不能（その他）', 'unclassifiable_data': '分類不能（データ）'}


def table(frame):
    def val(x):
        if pd.isna(x):
            return '—'
        if isinstance(x, (float, np.floating)):
            return f'{x:.4f}'
        return str(x).replace('|', '/')
    return '\n'.join(['| ' + ' | '.join(map(str, frame.columns)) + ' |',
                      '| ' + ' | '.join(['---'] * len(frame.columns)) + ' |',
                      *['| ' + ' | '.join(val(v) for v in row) + ' |' for row in frame.itertuples(index=False, name=None)]])


def write_report(out_dir, config):
    out = Path(out_dir)
    read = lambda name: pd.read_parquet(out / (name + '.parquet'))
    classes, summaries, curves = read('classifications'), read('class_summary'), read('return_curves')
    timing, env, barriers = read('timing_summary'), read('environment_cells'), read('barrier_scenarios')
    common = classes.loc[classes.common_pool]
    h10 = timing.loc[timing.policy.eq('immediate') & timing.endpoint.eq('hold10')]
    class_totals = summaries.loc[summaries.population.eq('all_origins') & summaries.grouping.eq('all'), ['class_label', 'n', 'ratio']].copy()
    class_totals.class_label = class_totals.class_label.map(LABELS)
    class_totals['割合%'] = class_totals.pop('ratio') * 100
    class_totals = class_totals.rename(columns={'class_label': '分類', 'n': '件数'})
    class_by_side = summaries.loc[summaries.population.eq('common50') & summaries.grouping.eq('method+side')].pivot(index=['method','side'],columns='class_label',values='ratio').mul(100).reset_index()
    directions = h10[['method', 'side', 'n', 'opportunity_gross', 'opportunity_net', 'delta_baseline', 'baseline_delta_ci_low', 'baseline_delta_ci_high']].copy()
    directions = directions.merge(curves.loc[curves.horizon.eq(50), ['method', 'side', 'net_pips', 'mfe_atr', 'mae_atr']], on=['method', 'side'])
    directions.columns = ['手法', '方向', '件数', 'H10 gross', 'H10 net', '対照差', '差95%下限', '差95%上限', 'H50 net', 'H50 MFE/ATR', 'H50 MAE/ATR']
    policies = ['immediate', 'wait1', 'wait3', 'wait5', 'pullback', 'breakout']
    timing_tables = []
    for endpoint in ['hold10', 'deadline50']:
        pivot = timing.loc[timing.endpoint.eq(endpoint)].pivot(index=['method', 'side'], columns='policy', values='opportunity_net').reindex(columns=policies).reset_index()
        timing_tables.append(table(pivot))
    fill = timing.loc[timing.endpoint.eq('hold10') & timing.policy.isin(['pullback', 'breakout']),
                      ['method', 'side', 'policy', 'n', 'filled', 'fill_rate', 'conditional_net', 'opportunity_net', 'delta_baseline', 'baseline_delta_ci_low', 'baseline_delta_ci_high', 'baseline_p_holm']]
    gates = env.loc[env.sample_gates_pass]
    positive = gates.loc[gates.mean_net_pips.gt(0)]
    hypotheses = env.loc[env.exploratory_hypothesis]
    alternative = timing.loc[timing.policy.ne('immediate')]
    improved = alternative.loc[alternative.immediate_p_holm.lt(.05) & alternative.delta_immediate.gt(0)]
    baseline_edge = timing.loc[timing.baseline_p_holm.lt(.05) & timing.delta_baseline.gt(0)]
    profitable = timing.loc[timing.opportunity_net.gt(0) & timing.net_ci_low.gt(0)]
    cost_decomp = timing.loc[timing.endpoint.eq('hold10') & timing.policy.isin(['pullback', 'breakout']),
                            ['method', 'side', 'policy', 'delta_immediate', 'delta_gross_immediate', 'saved_cost_per_origin']]
    positive_timing = timing.loc[timing.opportunity_net.gt(0), ['method','side','policy','endpoint','opportunity_net','net_ci_low','net_ci_high','net_2024','net_2025']]
    two_sided = common.class_label.isin(['favorable_then_reversal', 'adverse_then_favorable', 'ambiguous_order']).mean()
    ambiguous = common.class_label.eq('ambiguous_order').mean()
    total = len(classes)
    counts = common.groupby(['method', 'side']).size().rename('n').reset_index()
    counts['horizon_rows'] = 50
    maxcurve = curves.net_pips.max()
    positivecurves = int(curves.net_pips.gt(0).sum())
    all_hold10_negative = bool(timing.loc[timing.endpoint.eq('hold10'), 'opportunity_net'].lt(0).all())
    text = f'''# エントリー候補研究基盤：3手法の不振原因診断

対象はUSDJPY M5、2024–2025年、元の3手法。**新規手法の追加・条件の再調整・2026年の参照は行っていない。** 本レポートはエントリー候補の事後研究であり、実取引やMT5の売買バックテスト結果ではない。

今回の主要な観測は、即時エントリーのH1〜H50でネット平均がすべて負であり、待機後10本の全36区分も{'すべて負' if all_hold10_negative else '一部で正'}だったこと。両側±0.5ATRへ到達する候補が{100*two_sided:.2f}%あり、短い順行をそのまま継続的利益と見なせない。コスト削減と相対成績の改善は観測できるが、正のネット期待値の確認には至っていない。環境を限定した正の標本平均も、事前に固定した不確実性・年別・多重比較基準を通過していない。

## 調査範囲と再現性

- 元候補 **{total:,}件**、共通H50母集団 **{len(common):,}件**。全元候補を分類と6方針の状態表に残した。
- 欠損/遅延/不足 **{total-len(common):,}件**。比較に使う共通母集団は事後のデータ完全性による技術的コホートであり、ライブで分かるフィルターではない。
- 同じ通貨・年・曜日・時刻・相対ボラ・方向・件数の元のランダム対照10反復へ同じ待機規則を適用。各反復の平均を平均し、対照を10倍の独立標本とは扱わない。
- seed={config['seed']}。タイミング5,000回、環境20,000回の暦週再標本化。週内依存を保持するが、隣接週の独立性まで保証しない。
- 元データはBybit-Liveの保存バーで、現在のブローカーの実約定履歴ではない。タイムゾーン対応が未確認のため、東京/ロンドン/NYと推定せずsource clockの6時間帯を使用。
- コストは実測ではなく固定仮定 **1.9pips/約定候補**。スプレッド1.5、往復スリップ0.4、手数料0。2025年のspread=0を無料取引と解釈していない。
- [固定設定](config.json)、[入力・コードSHA256](manifest.json)、[解析前計画](../../../../knowledge/experiments/2026-10-15-entry-diagnostics-plan.md)。元コード・EA・入力の保護ハッシュを終了時に照合。

## 1. 方向の優位性

各数字は方向調整済みpips。H1は約定したバーの終値、H10はその10本目の終値。ATRはシグナル時点で固定。

{table(directions)}

**確認事実:** 元のH10のネット平均は6区分中{int(h10.opportunity_net.lt(0).sum())}区分で負。対照差の95%区間が0をまたぐ区分は{int((h10.baseline_delta_ci_low.le(0)&h10.baseline_delta_ci_high.ge(0)).sum())}/6。

**解釈:** この母集団・期間・仮定コストでは、シグナル方向がランダムより優れているという明確な証拠は得られていない。区間に0を含むことは「完全に差がない」の証明ではない。

## 2. 50本の経路分類

元価格から±0.5ATRの初回到達順で分類。両側到達なら順序を優先。片側だけの場合、即時逆行は3本以内に−0.5ATRかつ終値≤−0.25ATR、順行継続は終値≥+0.5ATRかつ最後10終値中8個以上≥+0.25ATR。どちらも未到達なら方向感なし。残りは分類不能（その他）。同足両側到達は始値が片側境界を既に越えた場合だけ順序を確定した。

{table(class_totals)}

共通母集団の両側到達（順序不明含む）は **{100*two_sided:.2f}%**、同足内順序不明は **{100*ambiguous:.2f}%**。この定義の「順行後の反転」は、単に一度プラスになっただけの経路ではなく、両方の±0.5ATR水準に達した経路を指す。

手法別・方向別・両者の組合せの件数と比率は[class_summary.csv](class_summary.csv)、候補ごとの理由は[classifications.csv](classifications.csv)。MFEとMAEは同じ50本で計測。[図と代表例](figures/dashboard.html)は固定seedで各手法・方向・分類から1件を選び、[選択ID](figures/selection.csv)を保存。代表図は未来の50本を含む事後分析として明示した。分布図の初期表示はP99までで、全範囲へ切替可能（データ除外なし）。環境図はネット/対照差を切替え、サンプル基準未達セルは灰色とする。

手法×方向の共通母集団内分類比率（%、分母件数は最初の表）:

{table(class_by_side)}

## 3. エントリータイミング

すべての方針を同じ元候補へ割り当てる。既知の未約定/失効は0、データ不明はNaN。表は共通母集団の**元候補1件あたりネットpips**であり、約定候補だけの平均ではない。

1/3/5本待機は元の約定可能足からの固定待機。押し目は0.25ATR以上逆行した後、別の確定足で元価格を順行側に回復し、実体も順行することを確認。高安更新は元シグナルを含む20本の高安を固定し終値の更新を確認。条件確認は最初10本まで、利用可能時刻以降の次足に実行し、最大11本・300秒の実行遅延制限を適用。

### 約定後10本

{timing_tables[0]}

### 元のエントリーから50本目を共通決済期限とする比較

{timing_tables[1]}

### 条件付き方針の約定率と分母の違い

{table(fill)}

**確認事実:** 全72区分（6方針×3手法×2方向×2期限）のうち、ネット平均が正で95%下限も正なのは{len(profitable)}区分。対照差が正かつ72検定Holm補正p<0.05は{len(baseline_edge)}区分。即時に対して改善し60検定Holm補正p<0.05は{len(improved)}区分。

**解釈:** 即時より損失が減ることと、方向の優位性・正のネット期待値が確認できることを分ける。条件付き方針は約定率を下げ、支払う仮定コストも減らすため、元候補あたり損失の減少だけではエッジの証拠にならない。対照にも同じ待機を適用した差と約定候補平均を併記した。

H10改善の分解（`delta_immediate = delta_gross_immediate + saved_cost_per_origin`）:

{table(cost_decomp)}

正の標本平均だった区分を省略せず表示:

{table(positive_timing)}

対照差が正でHolm p<0.05の区分:

{table(baseline_edge[['method','side','policy','endpoint','opportunity_net','net_ci_low','net_ci_high','delta_baseline','baseline_delta_ci_low','baseline_delta_ci_high','baseline_p_holm','net_2024','net_2025']])}

この相対差は、ネット期待値が正である証拠とは分けて読む。特定の待機が即時に勝るかどうかも、別の対応あり比較のCIと補正値で判断する。

全区分の週CI・Holm p・年別結果・欠測数は[timing_summary.csv](timing_summary.csv)。全元候補の未約定・失効・欠測は[timing_status_all_origins.csv](timing_status_all_origins.csv)、共通母集団は[timing_status_common50.csv](timing_status_common50.csv)。

## 4. TP/SL・保有時間

H1〜H50の全300区分（6手法方向×50時点）は同じ母集団で比較。ネット平均が正だった時点は{positivecurves}/300、最大値は{maxcurve:.4f}pips。これは事後の記述であり、最大値の時点を採用条件にしていない。[全時間推移](return_curves.csv)。

対称TP/SL 0.5/1/1.5ATRを解析前に固定したH50参考シナリオ:

{table(barriers[['method','side','level','n','tp_first_rate','sl_first_rate','ambiguous_rate','neither_rate','net_lower_pips','net_upper_pips']])}

上下限は同足内の順序だけをSL先着/TP先着に振ったもの。境界価格での仮想決済であり、ギャップ超過・変動スリップ・流動性による実約定損益の上下限ではない。未到達はH50終値で評価。対照10反復の同じシナリオは[barrier_scenarios.csv](barrier_scenarios.csv)。

固定した18区分のうち、曖昧な到達順序をすべて利益側としてもネット平均が負なのは{int(barriers.net_upper_pips.lt(0).sum())}/18。少なくとも、この3組の境界に置き換えるだけで収益化できたという結果ではない。

**解釈:** MFEが大きくても、その極値で利確できることは示さない。経路の往復が多いことは出口研究の動機になるが、未来のMFEから最適なTPを後付けする根拠にはならない。ここで試した固定シナリオを超える出口改善は未検証。

## 5. 取引コスト

H10グロス平均の範囲は{h10.opportunity_gross.min():.4f}〜{h10.opportunity_gross.max():.4f}pips。グロスが正なのは{int(h10.opportunity_gross.gt(0).sum())}/6区分。正の区分でも、その平均が損益分岐となる往復コスト上限（標本推定）であり、実測コストや安定した許容値ではない。

**確認事実:** 即時では仮定コスト1.9pipsが候補ごとに差し引かれる。0/0.5/1/1.9/3pipsの感度表は[cost_sensitivity.csv](cost_sensitivity.csv)。コストゼロでグロスが負の区分については、コストだけを原因にはできない。

**解釈:** 小さい正のグロスをコストが上回る区分と、方向自体の標本平均が既に負の区分が混在する。今回の固定仮定から、ブローカーの実コストで必ず同じ結果になるとは結論しない。

## 6. 相場環境の限定的機能

単独6組・2条件4組・3条件2組、全 **{len(env)}セル** を保存。最小件数200・週30・各年件数75/週15を戦略と対照10反復のそれぞれに適用。通過は **{len(gates)}セル**、未達は **{len(env)-len(gates)}セル**。

通過セルでネット標本平均が正なのは **{len(positive)}セル**。両年のネットと対照差が正、全体のネット/対照差CI下限が正、732検定Holm p<0.05をすべて満たす探索仮説は **{len(hypotheses)}セル**。

対照は元のマッチ候補を同じ環境条件で抽出した条件付き平均であり、環境内で時刻・ボラ等を再マッチングしていない。この制約とサンプル不足の影響を含む。全732セル（空セル含む）の件数・週数・年別成績・CI・補正値を[environment_cells.csv](environment_cells.csv)に出力。

サンプル基準を通過してネット標本平均が正だった全セル（採用候補ではない）:

{table(positive[['method','side','condition','n','weeks','mean_net_pips','net_ci_low','net_ci_high','mean_net_pips_2024','mean_net_pips_2025','delta_net_pips','p_delta_net_pips_holm']])}

**解釈:** 条件を細分化した局所的な正値は探索仮説にとどまる。基準未達は「無効」の証明ではなく評価不足。2026年を繰り返し使用して条件を選び直すことはしない。

## 5原因の整理

| 原因候補 | 観測できる事実 | この調査だけでは言えないこと |
| --- | --- | --- |
| 方向に優位性がない可能性 | H10の方向別平均と対照差CIを上表に提示 | 真のエッジが厳密にゼロであること |
| タイミングの問題 | 同じ元候補で固定待機・条件確認の損益、約定率、対照差を比較 | 待てば利益が出るという一般則 |
| TP/SL・保有時間 | 全50時点の推移、両側到達率、3組の対称境界シナリオ | 未来のMFEで最適決済できること |
| コストによる消失 | 固定1.9pipsとゼロを含む感度、グロス負の区分 | 実際のスプレッド/スリップでの正確な利益 |
| 特定環境だけの機能 | 全732セル、サンプル/年別/多重比較ゲート | 細分条件を実運用へそのまま採用できること |

次の検証が必要なら、本結果を読んだ後に別の固定計画として登録する。今回の条件を結果に合わせて変更しない。旧EA・旧研究基盤の結果は維持する。

実行手順: [診断README](../../../../tools/entry_research/diagnostics/README.md)。集計はCSV/Parquetと`diagnostics.duckdb`、生の待機評価は`timing_events.parquet`/`baseline_timing_events.parquet`に保存。

## 検証証拠

[合成データのテスト結果](qa/tests.xml)、[全成果物と再現性の監査](qa/artifact_audit.json)、[最終ソースと表示確認の記録](qa/final_source_manifest.json)。計算時コードの指紋はmanifest.json、最終の表示修正・直接APIのholdoutガードを含む指紋はqaの記録を参照。表示修正は統計値や選択IDを変えない。
'''
    (out / 'report.md').write_text(text, encoding='utf-8')
