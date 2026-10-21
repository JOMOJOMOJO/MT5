# 複数通貨・時間足・戦略の共通研究基盤

2026-10-16。Phase 3-1〜3-4を実装し、全216セルの分析・独立監査・報告を完了した。既存のプログラム、EA、データ、結果97ファイルは開始前hashと一致。既存の未コミット変更には触れていない。

新規コードは `tools/entry_research/multiasset/`。旧3手法を読み取り再利用し、新3手法、30価格データセットの取得、時刻・品質監査、2対照、共通週推論、独立口座台帳、DuckDB、Plotlyを追加。現MT5とは別の研究端末を作り、AlgoTradingを無効にして価格取得と発注なしfixtureだけを実施した。認証設定は機械内に限定し、レポートに出力していない。

[設計](../../tools/entry_research/multiasset/ARCHITECTURE.md) / [実行README](../../tools/entry_research/multiasset/README.md) / [事前固定計画](../../knowledge/experiments/2026-10-16-multiasset-research-plan.md)

## 修正と検証

pilotでDuckDB予約語引用の保存不具合を検出し修正。約定遅延の失効・未確定足参照・観測欠損・換算・lot・曖昧同足についてテストした。対照抽出は同じ乱数・同じ出力を保ったままDataFrameの逐次コピーを一括処理へ変更し、両対照各41,710行と抽出監査表の完全一致を確認した。

初期pilotと性能改善前fullは状態を明記して保存し、最終正本を `reports/research/multiasset_20261016/full_validated/` に分離。実行中のソース変更なし。141テスト合格、改善後26テスト合格、全216セルの4,320件独立再計算一致。テスター専用 `MultiassetResearchParity.mq5` はコンパイル0 errors/0 warnings、0取引、算術20/20一致であり、実約定や戦略利益の検証ではない。

先着率は元集計を残して母数付きの補足表を追加した。標本不足行は表示上も採択不可と明示。統計推論やp値、凍結条件は変更していない。

[検証を含む最終レビュー](../../reports/research/multiasset_20261016/full_validated/review.md) / [独立監査](../../reports/research/multiasset_20261016/full_validated/qa/artifact_audit.json) / [MT5算術証拠](../../reports/research/multiasset_20261016/qa/parity/README.md)

## 結論

ネットATR正25/216、採択0。実装QAと利益確認を区別し、追加調整・Stage3以降への昇格は実施しない。USDCHFは17か月、時刻・実費・取引カレンダーに制約があり、384/432口座シナリオは観測打切り。次の判断と再利用する教訓は [研究判定](../../knowledge/experiments/2026-10-16-multiasset-research-review.md) に保存した。
