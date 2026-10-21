# USDJPY M5 エントリー候補研究・初回分析

研究用イベント統計。MT5の売買バックテスト、収益性の確定、demo/live昇格ではない。
固定3手法、2024〜2025年、2026年価格は未読。過去研究で2026年の一部は既知なので完全未閲覧OOSとは呼ばない。

## 入力と再現性

- データ: `reports\research\entry_candidates\data_20261014`。Bybit-Live由来の保存バー。原本SHA256・重複差分・取得可能期間はdataset_manifest.json。
- シード 20261014、基準比較 10 回、週block bootstrap 1000 回。設定はconfig.json、実装hash・依存version・git HEADはmanifest.json。
- 雲9/26/52、表示シフト26、基準線は前足確定値への反発、EMA20/50。最適化なし。
- コストは仮定: spread 1.5pips + 往復commission 0.0pips + 片道slippage 0.2pips。保存spreadは実約定コストではない。
- source clockとUTCの対応未検証のため東京/ロンドン/NYはunknown。hour/weekdayはサーバー時計。
- 2024年6月6日以前に実tickの裏付けなし。2025年にもtick品質警告あり。OHLCから精密な約定や到達順序を推測しない。

## データ範囲

| timeframe | year | rows | first_time | last_time | missing_weekday_slots_unclassified |
| --- | --- | --- | --- | --- | --- |
| M1 | 2024 | 373621 | 1704153600 | 1735689360 | 3659 |
| M1 | 2025 | 372311 | 1735776000 | 1767225360 | 3529 |
| M5 | 2024 | 74871 | 1704153600 | 1735689000 | 585 |
| M5 | 2025 | 74585 | 1735776000 | 1767225000 | 583 |
| M15 | 2024 | 24959 | 1704153600 | 1735687800 | 193 |
| M15 | 2025 | 24863 | 1735776000 | 1767223800 | 193 |
| H1 | 2024 | 6239 | 1704153600 | 1735682400 | 49 |
| H1 | 2025 | 6215 | 1735776000 | 1767218400 | 49 |

timeはsource clock秒。欠落候補の詳細はgaps.csv。weekday空白には休日・閉場も含み、すべてをデータ障害と断定しない。価格補完なし。

## 候補母集団

| method | side | all_candidates | common_50bar | consecutive | overlap_50 |
| --- | --- | --- | --- | --- | --- |
| ema_cross | LONG | 1477 | 1427 | 0 | 418 |
| ema_cross | SHORT | 1476 | 1435 | 0 | 433 |
| ichimoku_cloud | LONG | 4218 | 4051 | 0 | 3132 |
| ichimoku_cloud | SHORT | 3857 | 3757 | 0 | 2783 |
| kijun_bounce | LONG | 3266 | 3137 | 271 | 2175 |
| kijun_bounce | SHORT | 3097 | 3011 | 258 | 2038 |

主比較は全50本が連続する共通母集団。全候補と各Hの欠損はcandidates.parquet、censor_counts.csvへ保存。週末・欠損・期間末直前の候補が主比較から除かれる。
シグナル観測時刻と名目確定を区別し、観測後の次の足始値を約定近似に使用。遅れがある場合は最大1本待つ。実tickによる約定確認ではない。

## 主要評価 H10（pips）

| method | side | n_complete | mean_gross_pips | mean_net_pips | mean_net_pips_ci_low | mean_net_pips_ci_high | delta_net_pips | delta_net_pips_ci_low | delta_net_pips_ci_high | p_delta_net_pips_holm |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ema_cross | LONG | 1427 | 0.0783 | -1.8217 | -2.7041 | -0.9101 | -0.3568 | -1.2089 | 0.4974 | 1.0000 |
| ema_cross | SHORT | 1435 | -0.2390 | -2.1390 | -3.1815 | -1.1925 | 0.0065 | -0.9773 | 0.9323 | 1.0000 |
| ichimoku_cloud | LONG | 4051 | -0.4451 | -2.3451 | -3.0582 | -1.6165 | -0.4862 | -1.1081 | 0.1572 | 0.8811 |
| ichimoku_cloud | SHORT | 3757 | -0.2079 | -2.1079 | -2.8436 | -1.3361 | -0.0509 | -0.6800 | 0.6097 | 1.0000 |
| kijun_bounce | LONG | 3137 | 0.1417 | -1.7583 | -2.4227 | -1.0982 | -0.1998 | -0.8906 | 0.4544 | 1.0000 |
| kijun_bounce | SHORT | 3011 | -0.1823 | -2.0823 | -2.7474 | -1.3992 | 0.0808 | -0.6015 | 0.7885 | 1.0000 |

CIはsource clockの同じカレンダー週を共通再標本化した95%区間。週内依存を保持するが、隣接週の依存や長期レジーム変化を完全には解消しない。
ベースラインはsymbol/year/hour/weekday/相対ATR区分/方向/件数を一致させ各層で復元なし。候補バーも抽選対象。10反復はサンプル数を増やさない。baseline_match_audit.csvに一致を記録。
検定はH10の3手法×2方向でHolm補正。他H・水準・環境別集計は記述的探索で、そこから勝者を選ぶと追加検証が必要。n<100又は週<20はthin_sample。
平均ネット>0だけでedge認定せず、差のCI・年別安定性・コスト・MT5検証を別に確認する。

## 出力

- summary.csv: 全Hのグロス/ネット平均・中央値、MFE/MAE、ATR換算、対照との差、CI、非重複候補の感度。
- barrier_rates.csv / barrier_comparison.csv: 全25 TP/SL組合せ、tp_first / sl_first / ambiguous / neither、対照との差。比率の分母にはneither/ambiguousを残す。
- touch_rates.csv: 各水準の到達率と到達バー数。正確なtick時刻ではなく、元Parquetに到達時間の区間を保存。
- environment_summary.csv: 年・時間帯・曜日・vol・H1/M15方向・雲位置別の件数つき集計。baselineの行数は10反復合計、n_events_per_replicateを併記。細分化条件は採用根拠にしない。
- events/、baseline/: 全イベントの評価Parquet。到達詳細のベースラインは事前固定第1反復のみ。到達率・MFE/MAEはグロス価格経路、netは固定時点リターンのコスト控除値。
- charts/: 各手法・方向の最初の候補の4時間足HTML。確定・観測済み足だけをHTMLに埋め込み、未来を非表示データとしても含めない。任意候補はchartコマンドで生成可能。
- research.duckdb: 永続集計テーブルとParquetビュー。移動後は元ディレクトリの絶対参照ビューの再作成が必要。

## 次の判断

この段階では3手法をEA化・昇格しない。7手法追加は同じ抽出API・未来不変性テストを通すPhase 5とする。
実tickによる同足順序確認、履歴コスト・時差対応確認、別期間/別brokerでの固定再検証は未実施。利益の出る出口・ポジション制約・資金配分を後付けした結果と今回の入口比較を混同しない。
