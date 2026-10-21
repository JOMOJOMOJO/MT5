# エントリー候補：不振原因の追加診断

既存基盤を変更せず`tools/entry_research/diagnostics/`を追加した。原因を方向・時点・出口/保有・コスト・環境に分けるため、[解析前計画](../../knowledge/experiments/2026-10-15-entry-diagnostics-plan.md)で閾値・六つの時点方針・732環境セル・検定群を固定した。

全候補を残したH50分類、因果的な待機判定、約定の有無と評価欠測の分離、元候補あたりの損益、コスト削減分の分解を実装。対照10反復にも全方針を適用。環境検定はHolm732のp値分解能を確保するため20,000ブートストラップ反復を解析前に決定した。

詳細結果と判断は[knowledgeレビュー](../../knowledge/experiments/2026-10-15-entry-diagnostics-review.md)、生の集計・可視化は[診断レポート](../../reports/research/entry_candidates/diagnostics_validated_20261015/report.md)。UI確認で小標本の高い点推定が目立つ問題を見つけ、件数ゲート未達セルは灰色表示に変更した。数値・探索規則は変えていない。MFE/MAE図の表示域切替、36件の固定seed代表例を付けた。

初回`diagnostics_20261015`は表生成が完了した時点でレポートモジュールの作成が追いつかず、描画前に停止。集計は保存し、別の`diagnostics_validated_20261015`で全処理を再実行した。初期の図も保存し、表示修正版を`figures/`に分けた。主要6テーブルの再現性と旧入力/EA/基盤コードのハッシュ不変を確認。テストパッケージ名の衝突は新規testsディレクトリのパッケージ化で解消し、旧テストは変更していない。

実行: [README](../../tools/entry_research/diagnostics/README.md)。検証: [成果物監査](../../reports/research/entry_candidates/diagnostics_validated_20261015/qa/artifact_audit.json)。外部公開・コミット・pushは行っていない。
