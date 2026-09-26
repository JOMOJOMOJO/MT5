# Fib終値エントリー＋HL確定後のSL/TP更新：研究結果

2026-09-25。売買用EA・Shared・共通発注処理は変更していない。研究専用EA `USDJPY_3Wave_FibHLExitResearch` を新設し、SL/TP固定版と更新版を同じ入口で比較した。

## 結論

HL−10ポイントへのSL変更と、新SL幅を基準にしたTP1.2倍への変更は、実際のMT5テスターで1件成功した。固定版が−99.78 USDになった取引は、更新版では＋42.44 USDになった。ただし3か月で取引1件だけのため、期待値改善の根拠にはならない。売買用への採用はしない。

既存EMA条件を保った結果、候補39件中38件を見送った。今回の入口とEMA条件を同時に満たす機会は非常に少なく、月20件という目標には届かない。閾値やEMA条件は変更していない。

## 固定した条件

- USDJPY M1、上位M5、ピボット左右2/2、Equityリスク1%、クールタイム15分。
- M1 reversal low〜M1 Wave1 highにFibを当て、**50〜61.8%帯内で終値が確定した最初のM1足**を採用。次の利用可能tickのAskで成行BUY。
- Wave1 highの確定時刻以降に始まった足だけを使用。ヒゲだけの接触・確定前の過去足は使わない。最初の候補でEMA等に却下されても、そのM5構造で再試行しない。
- M1 EMA20>50>100、3本とも上向きという既存条件をONのまま維持。
- 初期SLはreversal low−10ポイント、初期TPはRR1.2。
- 更新版では同じM1構造のHLがエントリー後に確定した時点で、**SL＝HL−10ポイント**、**TP＝実約定価格＋（実約定価格−新SL）×1.2**へ一度だけ変更する。HLの足自体はエントリー前でもよいが、確定はエントリー後に限る。
- SLを広げない。新SLが約定価格以上なら変更しない。新TP到達済み／新SL割れ済みなら、その時点の市場価格で決済する。距離制限や変更拒否時には既存の保護を残して再試行。
- Rの分母は初期約定リスクを維持する。縮小後のリスクを使って成績を水増ししない。

詳細は[固定計画](plan.md)。現行READYとのOR条件はこの実験には含めていない。

## MT5結果

期間2025-01-01〜2025-04-01未満、初期残高10,000 USD、Model4。両版の候補39件は一致した。

| 方式 | 取引数 | 損益USD | 初期リスク基準の平均R | 最大Equity DD |
|---|---:|---:|---:|---:|
| 初期SL/TP固定 | 1 | -99.78 | -1.0000 | 1.31% |
| HL確定後に更新 | 1 | +42.44 | +0.4253 | 0.02% |

月別取引数は両版とも1月1件、2月0件、3月0件。1件なので勝率・PFの良否は評価しない。

見送り理由：EMAの並び不成立22件、3本すべて上向きではない16件。発注1件。動的更新TARGET1件・MODIFY1件、変更拒否・即時決済・SKIPは実期間中に発生しなかった。RECOVERY_BLOCKEDなし。

### 実取引例（MT5サーバー時刻）

- 2025-01-30 13:29:00、154.552で買い。初期SL154.505、TP154.608、初期リスク99.78 USD。
- 13:30:00に13:27のHL154.545が確定。SL154.535（HL−0.010）、TP154.572へ変更。MT5 retcode10009。
- 更新版は13:30:28に154.572でTP決済、＋42.44 USD。
- 固定版は13:33:29に154.505でSL決済、−99.78 USD。
- 更新後の価格幅RRはティック丸め前1.2。初期リスクに対する実現利益は約0.425Rであり、1.2Rではない。

## 確認済み・未検証

- コンパイル0エラー・0警告：[compile.log](compile.log)。MT5内の計算境界テスト12件成功：[policy.csv](policy.csv)。
- 全39候補について独立したM1 OHLCとの照合で、確認時刻以降の最初の帯内終値であることを監査。新SL・新TP・初期R分母を取引ログと照合：[audit.json](audit.json)。
- 売買用EA・Shared・共通入力・共通発注includeは作業前ハッシュと一致：[protected_after.json](protected_after.json)。既存発注・保護等の関数本体を保存：[static_audit.json](static_audit.json)。
- History品質98%リアルティック。2025-03-27に欠損6分・破棄1431分の警告。該当日の約定はないが、間接影響まで排除した検証ではない。
- 手数料・スワップ・feeはテスター記録上0、スプレッドはBid/Askに含む。遅延0。既に見たQ1期間でありOOSではない。
- 変更拒否・freeze待機・新TP到達済み決済・遅延応答の回復分岐は今回の実期間では未発生。計算テストはそれらのサーバー挙動を実証するものではない。
- 非ビジュアルテスト。研究状態の再起動復元、デモフォワード、実運用は未検証。EAはテスター専用。

## 再実行とファイル

EA：[USDJPY_3Wave_FibHLExitResearch.mq5](../../../../mql/Experts/USDJPY_3Wave_FibHLExitResearch.mq5)。
プリセット：[更新版](../../../presets/USDJPY_3Wave_FibHLExit_DynamicHL_RR12.set)、[固定版](../../../presets/USDJPY_3Wave_FibHLExit_Static_RR12.set)。MT5テスターでこの研究EAを選び、USDJPY M1、同期間・リアルティックモードで対応プリセットを読み込む。`InpMoveSLToHL`だけが比較対象の差。

集計：[comparison.csv](comparison.csv)、[monthly.csv](monthly.csv)、[trades.csv](trades.csv)。
生データ：[更新ログ](../fib_hl_q1_dynamic/TW_hl_exit_updates.csv)、[更新版候補](../fib_hl_q1_dynamic/TW_signals.csv)、[固定版](../fib_hl_q1_static/)。
再現スクリプト：[tester runner](../../../../tools/swing_structure/run-three-wave-fib-hl-exit.ps1)、[analysis](../../../../tools/swing_structure/analyze_fib_hl_exit.py)。
