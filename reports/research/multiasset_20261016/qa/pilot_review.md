# Pilot QAと全対象への移行判断

試験対象: USDJPY/EURUSD × M5/M15 × 全6手法 × 2方向 = 48セル。収益結果を根拠に対象やパラメータを変更していない。

- 48セルの候補・対照の計算とCSV/Parquet保存を完了。
- 独立artifact audit: 960件のOHLC gross/net/MFE/MAEを再計算して一致。全セルの候補保存、各対照10反復・件数・無復元抽出・条件一致・H10完全性を確認。
- 2026混入なし。入力hash一致。旧プログラム・旧データ・旧結果・既存EAの保護対象97ファイルが開始前と一致。
- 最終DuckDB保存で予約語 `primary` の引用がないため失敗。識別子引用を修正し、DuckDB作成/読取の回帰テストを追加。元pilotは再書換えせず保存。
- 売買simの遅延失効について追加レビューを行い、エントリー期限とavailabilityのテストで修正を検証する。元pilotのexecution台帳は最終結果として使わず、修正版のfullを正本とする。
- 旧コア/診断/新規causality 123 tests PASS。追加の推論テストとsim testsをfull実行前後のQAに含める。

`pilot/qa/artifact_audit.json` の `same_current_source_hashes=false` はpilot後に上述の修正と監査コードが加わったため。再現コードの旧hashはpilot manifestに残る。fullは全216セルを同じ修正版コードで新規保存・再監査する。元pilotのレポート/DB完了を装わない。
