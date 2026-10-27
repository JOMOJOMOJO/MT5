# Wave33 v1.71：気配値全銘柄テストの互換性修正

更新・配布：2026-10-23。ユーザーが添付した2026-10-22のログに対する修正。

原因は、MT5の「気配値表示で選択されたすべての銘柄」が最適化扱いなのに、v1.70が `MQL_OPTIMIZATION` を無条件に拒否したこと。添付ログでは実行された10パスすべてが `OnInit returned non-zero code 1` で停止した。[原本ログ](user_tester_log.txt)、[MT5公式](https://www.metatrader5.com/en/terminal/help/start_advanced/start)。

v1.71は `InpAllowTesterBatchRuns=true` を追加し、初期化・新規注文・逆①の待機と利益決済で同じテスター文脈判定を使う。通常チャートでは注文しない。最適化扱いの実行では描画を実効OFFにし、Common CSVは銘柄・入力と実行文脈のハッシュ・排他的な予約番号で分離する。設定の描画希望と実効値は別々に保存する。

これは実行互換性の修正で、数値パラメータ探索は行っていない。波形判定・抵抗・RR・SL/TP・逆①利益決済の定義はv1.70から変えていない。公開MQLフラグでは全銘柄モードだけを判別できないため、新入力trueは数値最適化を含む最適化扱いのテスター全般を許可する。

## 確認結果

|確認|結果|証拠|
|---|---|---|
|EAと9ハーネスのコンパイル|10対象すべて0 errors / 0 warnings|[コンパイル・単体実行](eng/20261022_235504_d57c3130/review.md)|
|新しい実行ガード・名前・排他予約|38/38 PASS。通常チャート許可なし、既存CSV保護、同一名再予約を確認|[ハーネス](eng/20261022_235504_d57c3130/tester_run_harness/harness.csv)|
|単銘柄v1.70対v1.71|28チェック、差分0。12候補・4取引と逆①決済が一致|[一致結果](single_regression.md)、[全照合項目](single_regression.json)|
|Model4単銘柄対一括内XAUUSD+|全1,240イベント、上位足・下位足原本、逆①全監査ティックが一致|[全項目比較](mw/mw_20261023_000013_84b6ba78/xau_single_comparison.json)|
|Model1の全銘柄ネイティブ一括実行|MT5が実行した10パスすべて完了、14注文・14約定・14決済。初期化エラー0、CSV混在・重複0|[独立監査](mw_gen/mw_20261023_093811_0a55ac82/independent_audit.json)、[MT5完了ログ](mw_gen/mw_20261023_093811_0a55ac82/journals/Tester/logs/20261023.log)|
|既存戦略ヘッダー・他EA|既存7ヘッダーと保護対象2EAのSHA256が配布v1.70と一致|[配布記録](deployment.json)|

固定期間は2020.10.01〜2020.10.10（終端日排他）、A=M15/M5、5,000 USD、RR1、リスク1%、ローカルエージェントのみ。主端末を停止せず、別の専用portable runtimeを使用した。主端末の選択キャッシュ・common.ini・口座/サーバーキャッシュは前後ハッシュ一致。[一括実行原本](mw_gen/mw_20261023_093811_0a55ac82/provenance.json)、[元runner集計](mw_gen/mw_20261023_093811_0a55ac82/summary.json)。

|銘柄|候補|約定・決済|
|---|---:|---:|
|XAUUSD+|12|4|
|XAUAUD+|13|4|
|USDJPY|10|2|
|GBPUSD|6|2|
|EURUSD|17|0|
|EURUSD+|17|0|
|Nikkei225|5|0|
|CHINA50|4|0|
|HK50|5|1|
|ES35|2|1|

## データと検証範囲の制約

- 最初のModel4一括実行は、HK50の換算用USDHKDティック同期とES35の同期中に900秒の上限へ到達した。全体は未完了のまま記録し、成功扱いにしていない。途中までの9銘柄CSVを回収し、完了していたXAUUSD+の単銘柄一致を確認した。[未完了の原記録](mw/mw_20261023_000013_84b6ba78/status.json)、[部分監査](mw/mw_20261023_000013_84b6ba78/independent_audit.json)。
- 次のModel1（生成ティック）実行で10パスが完了した。Model4とModel1では原本足と候補列が一致しても、ティック経路・SL/TP時刻や価格・損益が異なる。モデル間の完全一致とは扱わず、差分を保存した。[モデル間差分](mw_gen/mw_20261023_093811_0a55ac82/xau_single_comparison.json)。リアルティックでの執行品質・収益性の確認ではない。
- XAUEUR+は2021.04.05、XAUJPY+は2023.11.20、BVSPXは2022.08.04から履歴が始まる。2020年にはテストできない。EAの初期化失敗とは別の制約。
- 選択datを文字列として読むと、換算用AUDUSDなどを含む14銘柄名が出る。しかしMT5自身の実行対象は10パスで、AUDUSDのEAは起動されていない。キャッシュの全名称を「実際の選択対象14パス」と断定しない。AUDUSDが対象外だった理由は今回のキャッシュだけでは確定していない。
- 元runnerは上の14名称すべての初期化を要求したため `REVIEW_REQUIRED` を残した。後続の独立監査は、MT5の `total passes 10`、エージェントの10完了記録、10銘柄CSVを照合し `PASS_OBSERVED_NATIVE_PASSES` とした。元の結果は改変していない。runnerも今後はキャッシュ名称数とネイティブ対象数を区別する。
- MT5のsymbols.xmlはヘッダーのみだった。XMLの数値を実績として使わず、MT5の各パス完了ログと全候補・約定・決済CSVを証拠にした。
- 一括実行は各銘柄の独立口座テストで、合算ポートフォリオ評価ではない。遠隔・クラウドエージェントのCommon CSVは自動回収しない。

## 再実行と配布

配布EAは従来と同じ `dev\mql\Experts\Wave33VisualVerifier.ex5`。コンパイルしたv1.71を配置済み。新しい [A設定](../../presets/wave33-v171-A-M15-M5-orders.set) / [B設定](../../presets/wave33-v171-B-M5-M1-orders.set) を主端末の `MQL5\Profiles\Tester` に配置した。AはM5、BはM1。ビジュアル用INIは [A](../../backtest/wave33-v171-A-M15-M5-orders-visual.ini) / [B](../../backtest/wave33-v171-B-M5-M1-orders-visual.ini)。[実行手順](../../../docs/validation/wave33-tester-orders.md)。

テスターを停止してEAを選び直し、新SETを読み込む。発注ONは `InpEnableTesterOrders=true`、一括許可は `InpAllowTesterBatchRuns=true`。最適化欄で「気配値表示で選択されたすべての銘柄」を選ぶ。個別の描画確認は単銘柄・最適化無効・ビジュアルONで行う。

同じ固定入力の工学確認を再現するコマンド（PowerShell7内）：

```powershell
& ./scripts/run-wave33-marketwatch-qa.ps1 -OutputRoot reports/qa/w33batch/recheck -DateFrom 2020.10.01 -DateTo 2020.10.10 -Model 1 -Execute
```

新しい隔離runtimeと出力タグを使う。全銘柄一括QAに使った入力・EA・runner・原本足のハッシュを保存する。利益最適化、2026年ホールドアウト、追加の①接続フィルターは実施していない。
