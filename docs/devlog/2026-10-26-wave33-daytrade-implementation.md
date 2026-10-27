# Wave33 DayTrade v1.90 実装

ユーザーの「実装して」を受け、[24時間上限・段階SL案](../../knowledge/experiments/2026-10-26-wave33-daytrade-exit-plan.md)を新しい `Wave33DayTradeVerifier` に追加した。v1.85を基に、原版・診断EAと共有既存headerを保護して新規EAとmoduleだけに実装。作業branchは `research/wave33-daytrade/2026-10-26-step-sl-24h`。既存の未コミット作業は保持し、公開・pushは行わない。

純粋な段階判定・deadlineと、native注文／broker確認／CSV／SL履歴描画を分離した。実約定と初期SLから固定Rを作り、2R→建値、3R→1R、その後1R刻み。固定TPと部分利確はなし。逆①利益決済、初期構造SL、tester-onlyガードを維持した。最初の実約定millisecondから24時間で全残量決済し、週次session上の長い休場前には5分のbufferを置く。祝日・quote不在は別の制約として記録する。

[QA説明・ビルド・プリセット](../../reports/qa/w33_daytrade_20261026/README.md)。EA・policy script・native harnessを0 errors / 0 warningsでcompileした。native実行によるPASSはまだ確認していない。実行用harnessは時刻・MFEの人工fixtureを明示し、戦略損益の証拠には使わない。

ユーザーの「EA実行時は止めて、こちらから声をかける」に従い、動作確認を開始した時点でCodexを止める。起動後の待機・ログ確認・年間実行・成績分析を自動で続けない。結果はユーザー再開後にレビューする。

今回は未評価の実装段階なので公開seedは追加しない。既存のMFEと実行可能利益の知見を再利用する。

ユーザーの「実際には注文しないの？」を受けて既存記録だけを確認した。現在の `wave33_day_v190_config.csv` はversion1.90・tester=1・tester_orders=false。初期値の注文OFFが原因で、配布済みの注文ONプリセットを読み込むか `InpEnableTesterOrders=true` にして再実行する必要がある。実行中のテスターや設定は変更していない。

停止していた自分のQA記録もこの呼びかけで参照した。純粋判定52項目はPASS、nativeではLONG/SHORT各1件の入口・出口（計4deal）は存在する。一方、native全体は250項目中226件の `fixture_order_send` 失敗でFAILだった。これをnative QA全体のPASSとは扱わない。fixtureの発注失敗理由のjournal照合・テスト修復は未着手として残し、この質問に便乗してテスターを再起動しない。
