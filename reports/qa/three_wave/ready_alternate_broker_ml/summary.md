# Vantage 2023収集結果の確認

## 結論

2023年の収集は完了。VantageTradingLtd-Liveへの認証・同期を専用端末のログで確認した。ただし、実tick品質を確認できた学習ラベルの追加は0件。売買EA・Shared・売買条件は変更していない。追加のMT5実行は行っていない。

|項目|結果|
|---|---:|
|通常READY shadow候補|192|
|テスター上のTP / SL|74 / 118|
|実tick開始|2023-11-09|
|実tick欠落・破棄の警告日|36日|
|現在の品質基準を通過したラベル|0|

開始日より前は実tick検証対象外。開始日以降も日別ログに欠落・価格不一致による破棄がある。例えば11月9日は1438分中578分で実tick欠落、860分で破棄。11月10日は1437分中1435分で破棄。現在の監査はEntryからExitまでに警告日を含む候補を除外する保守的な日単位判定であり、全候補の全tickが偽物だったという意味ではない。分単位の候補経路を保証できないため採用しない。

## 旧Bybit収集との照合

旧 annual_2023 と、新 vantage_2023 を実ファイルで比較した。

- TW_ml_entry_quotes.csv / TW_ready_paths.csv / TW_ready_shadows.csv はバイト単位で一致。
- 192候補のsignal ID、構造、Entry、SL、TPは一致。signalsで異なる列はlots / expected_loss / equityのみ。
- M1バー378201行は同じ長さで、Highが2行、Lowが1行、tick_volumeが2行、spreadが4行、available_atが86行異なる。M5もほぼ一致。
- 新端末のbasesディレクトリに存在するブローカー履歴はVantageTradingLtd-Live。端末ログにも同サーバーへの認証と同期を確認。

したがって別サーバーでの実行自体は確認できたが、独立した候補・損益サンプルが192件増えたとは扱えない。過去バーがほぼ共通である理由やキャッシュ経路の完全な切り分けまでは未確定。同一結果だけを根拠にキャッシュ混入と断定しない。

## 次の判断

この2023年結果を実tick学習データへ追加せず保管する。今後再収集する場合は年単位の実行前に短期間でバーと実tickの整合性を検証する。ブローカーを変更すれば自動的に有効データが増えるとは限らない。

## 証拠

- [品質監査](vantage_2023/collection_quality.json)
- [候補別品質](vantage_2023/candidate_tick_quality.csv)
- [実行ログ](vantage_2023/tester.log)
- [ログ抽出元](vantage_2023/tester.extraction.json)
- [全候補](vantage_2023/TW_signals.csv)
- [shadow結果](vantage_2023/TW_ready_shadows.csv)

月別候補数: 1月14、2月14、3月19、4月20、5月13、6月12、7月19、8月23、9月17、10月13、11月11、12月17。
