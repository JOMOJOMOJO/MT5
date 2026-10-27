# H1 ER12比較用 v1.92 QA

2026-10-27。新規 `Wave33H1EfficiencyVerifier` をv1.91から分離し、H1 ER12≤0.25の除外を1個だけ追加。既存ソースをハッシュで保護する。

## ビルドと定義

- [EAコンパイル](compile/Wave33H1EfficiencyVerifier.log)：0 errors / 0 warnings。
- [テスト用スクリプトのコンパイル](../../compile/w33_h1eff_policy_20261027.log)：0 errors / 0 warnings。
- 13確定終値、12差分。往復度=1−ER、経路の相殺率。回数ではない。
- 境界の丸め、上昇/下降・V字・交互移動・平行移動/倍率・欠測・ゼロ移動・非数・未来足・ギャップ等の純粋テストを45個実装。**この文書作成時点ではnative実行待ち**。両アームのOnInitで走り、失敗時は初期化を拒否する。
- [独立レビュー](../../backtest/analysis/wave33_h1_er_compare_20261027/independent_definition_review.md)：定義のDecimal再計算、旧代理系列とnative系列の差、因果性、既存決済が不変であることを確認。静的レビューは実際の注文・CSV検証の代わりにならない。
- [静的検証結果](build_static_verification.json)と[配置ハッシュ](deployment.json)はprepareの前提条件。native成績・約定整合性はまだ未判定。

## 実験への接続

[固定比較計画](../../backtest/runs/wave33_h1er_2025jan/PLAN.md)。旧保存取引の間引き比較と、v1.92 nativeの再実行を混同しない。実行後はユーザーが声をかけるまで作業を止める。

## ユーザー再開後のnative検証結果

2026-10-27回収。[結果と証拠](../../backtest/runs/wave33_h1er_2025jan/20261027_005658_UTC_0796b021/analysis/README.md)。上記の実行待ちは準備時点の記録。現在は両群が1月末まで完了し、純粋テスト45×2=90 PASS、全78観測のDecimal再計算と時刻・閾値一致、独立実行整合性52/52 PASS、root会計394チェックPASS。部分セッションの特定時間帯は判断窓に入らず系列一致が未観測であることも記録した。

OFF29件−12.0700R、ON16件−5.4151R。元の45ポジション全てでraw費用込み会計・初期リスク・EXITが一致。エンジニアリングのPASSであり、両群赤字なので戦略採用のPASSとはしない。旧静的JSONのnative pendingは準備時スナップショットとして保持し、現在の状態は比較batchのcompletion_audit.json/status.jsonを参照する。
