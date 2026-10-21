# r4：初回snapshot誤判定の修正と再実行

[r3の停止原因](../portable_audit_20261009_r3/review.md)を修正する。
売買コード・パラメータ・期間・銘柄・10本の実行順序・照合条件は[r3](../portable_audit_20261009_r3/plan.md)のまま。

## 修正範囲

`PortableEnvironmentAuditV2.mqh` に初回基準確立のbool状態を追加。
初回を変更扱いにしない。初回以降の値の差は従来通り記録・不合格判定する。
旧観測Includeは変更しない。r4凍結EAだけ新しい観測コードを埋め込む。
本番EA、Shared、既存研究ソース、過去run・manifestは維持。

## 回帰テスト

Python3件：実際のr3誤判定ログの検出、正常なSTART→CHANGE順序、別銘柄のSTARTで誤判定を隠さないことを確認。合格済み。
MQLハーネスは元の18項目に次の3項目を追加し、21項目とした。

1. `ENV_INITIAL_IS_BASELINE`：初回は基準、変更数0。
2. `ENV_UNCHANGED_IS_NOT_CHANGE`：同じ値をもう一度読んでも変更数0。
3. `ENV_REAL_DIFFERENCE_DETECTED`：テスト用の比較元差分を注入した場合に変更数1となる。

3番のfixtureは監視機能を無効化した修正を拒否するためのもの。実際の銘柄仕様や売買入力は書き換えない。
このfixture内のCHANGEは意図的。通常EAの環境監査ではCHANGEを引き続き拒否する。
21項目の実行合否は今回のMT5 runで確認する。

## 事前確認

- [コンパイル](preflight/20261009_173309_7b7ae58c/status.json)：5ソース全て0 errors / 0 warnings。
- スクリプト構文確認済み。
- 2026-10-12、凍結hash・旧本番ソースの保存を再確認。検証条件に変更なし。
- [差分](observer_initialization.diff)、[manifest](manifest.json)。

独立portableで実行し、監査失敗時は後続を停止する。起動後Codexは待機せず終了。
成績最適化・売買フィルター追加・本番採用は今回行わない。
