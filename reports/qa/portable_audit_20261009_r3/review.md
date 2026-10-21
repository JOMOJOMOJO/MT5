# r3の停止原因：監査observerの初回誤判定

対象：`runs/20261009_162416_5035696c`。ハーネス18項目は合格したが、2本目daily_referenceの監査で停止した。10本完了ではない。

## 原因

5銘柄すべてで、開始時刻1672531200に `START` より先に `CHANGE` を出力していた。
`qePrevious[i]!=""` を初回判定にも使用し、基準snapshotの確立を明示的な状態として持っていなかった。
保存された34項目×5銘柄は、CHANGE/START/ENDを通して同一。実際に値が変わったfieldは0件だった。
ブローカー条件の変化や戦略の不具合を示す停止ではなく、今回追加した監査コードの初期化不具合。

## 実行できた売買

旧版は7取引、net −48.29 USD、PF 0.1424。14約定のCSVは標準レポートと一致し、欠損・余分・重複は0。
過去の旧レポートとの売買時刻・価格・volume・SL/TPは一致。費用差は前回と同じEURUSDのswap計+0.05 USD。
修正版・タイマー版・M5の比較は未実行。成績の改善や全体QA合格を示す結果ではない。

## 修正

基準snapshotの有無を `qeHaveBaseline` で管理し、初回値を登録した後にだけ比較する。
文字列配列と状態も明示初期化。後続の差検出は維持。
旧ソース・失敗成果物を残して[r4](../portable_audit_20261009_r4/plan.md)へ分離した。
過去のFAILEDを後から合格へ変更していない。

## 証拠

- [停止状態](runs/20261009_162416_5035696c/status.json)
- [初回を含む全仕様記録](runs/20261009_162416_5035696c/daily_reference/environment.csv)
- [元の不合格判定](runs/20261009_162416_5035696c/daily_reference/environment_audit.json)
- [標準レポート](runs/20261009_162416_5035696c/daily_reference/report.htm)
- [修正差分](../portable_audit_20261009_r4/observer_initialization.diff)
