# M5 / M15-H1-H4観測への変更

ユーザーが上位足条件による選別より、全環境の取引結果を後から比較することを希望したため、研究計画を変更。
[固定計画](../../reports/qa/m5_multitf_diagnostics_20261007/plan.md)、[差分](../../reports/qa/m5_multitf_diagnostics_20261007/research_hooks.diff)。

## 前バッチの停止

[旧status](../../reports/qa/m5_m15_context_20261007/runs/20261007_133107_b26b2e57/status.json)はFAILED。
validate_fixed_1の2025-07-07 09:30/10:00候補で、M15 structure_high=144.628、low=144.775。
確定高値群と確定安値群の時期が違うと、範囲が逆転する場合がある。
分類器はRANGE/position UNKNOWN/raw EMPTY_VALUEを正しく出していたが、旧集計がregime!=UNKNOWNなら常に位置計算可能と仮定して停止した。
取引エラーや未来pivotの証拠ではない。今回の監査はrange_validを確認し、不正範囲をUNKNOWNとして残す。旧凍結資料は変更しない。

## 実装

- 研究EA `RelativeM5MultiTFDiagnostics` と観測Includeを追加。元EA/Sharedは変更しない。
- M15分類との同一足での一致、confirmed/asof<=decision<=entryを監査。
- raw候補、3TF環境、spread、サーバー時刻、実行gate、未来のBid pathを特徴/ラベル別に保存。
- 実取引とshadowを別集計し、両側到達minuteを除外。SL/RR/riskは固定。
- 旧runnerへ専用フラグを追加。既存モードは既存パッケージguardを維持。
- 4run（3つの完全一致比較を含む）。既知期間診断であり採用・最適化なし。

コンパイル0 errors/0 warnings。Python単体テスト49件合格（未来情報拒否、逆転range、範囲外raw、両側到達、gap上下非対称、未完了を含む）。
MT5の結果は非同期実行後に別途確認する。月20回や正期待値が達成されたとは現時点で主張しない。
