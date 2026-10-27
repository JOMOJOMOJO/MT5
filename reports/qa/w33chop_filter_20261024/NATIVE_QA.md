# 任意の往復フィルター：独立ネイティブQA

実施日：2026-10-24〜25 JST。最終結果は **PASS：MQL 694項目、CSV別監査36項目、失敗0**。

- [最終バッチと各設定の結果](native_latest.json)
- [イベントCSVからの別監査](native_event_audit.json)
- [最終バッチの原本ログ・CSV](native/run_1be3fa95/)
- [ハーネスのコンパイルログ：0 errors / 0 warnings](compile/harness.log)
- [実EAを読み込むテスト用EA](../../../mql/Experts/tests/Wave33ChopFilterHarness.mq5)
- [専用サンドボックス実行スクリプト](run_native.ps1)
- [CSVの別監査スクリプト](audit_native.py)

## 実行した設定

全ての設定でM15/M5・M5/M1、LONG・SHORTを通した。実EAのOnInit、Plan、HandleSignal、実エンジンのFinishUnorderedを使用し、売買処理を別実装に置き換えていない。

| フィルター | 診断 | テスター注文 | MQL確認数 | SIGNAL | 往復によるSKIP | ORDER_DISABLED | ORDER |
|---|---|---|---:|---:|---:|---:|---:|
| OFF | ON | OFF | 154 | 12 | 0 | 12 | 0 |
| OFF | OFF | OFF | 142 | 12 | 0 | 12 | 0 |
| ON | ON | OFF | 154 | 12 | 4 | 8 | 0 |
| ON | OFF | OFF | 154 | 12 | 4 | 8 | 0 |
| ON | OFF | ON | 90 | 4 | 4 | 0 | 0 |

最後の設定は、事前にCHOPPYと確認した4件だけをHandleSignalに渡している。注文ONでもSKIPが注文経路より先に働くことを確認する試験であり、CLEANの発注・約定を試す設定ではない。

## 何を確かめたか

- 逆行合計 / ①方向値幅がちょうど0.5ならCHOPPY、0.499ならCLEAN。フィルターOFFならCHOPPYを除外しない。
- ユーザー例の値幅6.07・逆行合計5.61は比率0.9242174629。上下反転・両時間足でONなら除外、OFFなら通す。
- 判断時点より後に判明するpivotと、同じ時刻でもまだ発行されていないpivotを使わない。発行後の同時刻pivotは使用する。
- UNAVAILABLEは除外せず、`ALLOW_UNAVAILABLE` と `missing_policy=ALLOW` を残す。
- 診断OFF・フィルターONでも、実OnInitが観測器を有効にする。
- 実HandleSignalのSKIP理由は`CHOPPY_WAVE1`、分類はEXCLUSION。ORDER_DISABLEDに進まず、order_sent_at・fill_atは空、pending・position_idなし。
- 除外されたSIGNALのentry_statusは`SIGNAL_RISK_REJECTED`で、表示コードの緑ENTRY条件を満たさない。これはCSV・コード経路の確認であり、最終画面の目視保証ではない。
- 除外候補の方向レーンを解放し、同じsetup_idを再度渡しても記録増加・発注・復活がない。
- 既に注文受理待ち、または保有状態になった候補をFinishUnorderedで終了できない。
- 診断ON/OFFによる計画SL・TP・entry_price等の経済項目は同一。フィルター切替でも除外判断前の計画価格は同一。

CSV別監査は、MQL側のPASS文字列だけを信用せず、実際のSIGNAL・SKIP・ORDER_DISABLED・ORDER、理由、計画価格、注文日時を読み直している。

## 範囲と限界

合成の確定OHLCで実エンジンからSIGNALを作り、ゲートを分離するために①の価格・起点をテスト側から注入した。実PlanはXAUUSDの2025-01-06のテスター気配値を使用する。2020年の合成バー日時は価格系列の定義用であり、2020年や2025年の実戦略成績を意味しない。M1モデル2で最初の1ティックだけ実行し、EA自身が終了する。

新しい専用ポータブルサンドボックスを使用し、通常チャートでは実行していない。Expertsの通常自動売買・DLL・リモート・クラウドは無効。既設ターミナルや既存の年間検証は起動・変更していない。

旧EAとの長期売買一致、CLEAN候補の実注文・約定、実ティックの発注精度、成績改善、未使用期間の優位性は今回の試験対象ではない。既知のツールチップ全文読み戻し問題は再試験していない。

最初の試行はCSVコピー時のWindowsパス長制限、その次はMT5自己更新時の初回ランチャー終了の早取りで、成果物回収が途中で止まった。そこでタグを短くし、固有のassertions CSVの到着とサンドボックス内ターミナル終了まで待つように実行スクリプトを修正した。途中のfailure.jsonと取得済み証拠は保存した。どちらもEAの判定失敗ではなく、途中で得たMQL検査は失敗0だった。上表は修正後の完全な最終バッチのみ。
