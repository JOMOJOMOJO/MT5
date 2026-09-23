# 3波の候補段階を広く記録する特徴量研究

## 目的

入口の早期化・フィルター追加ではなく、M5の下降強度・減速・押し目状態と、その後の値動きの関連を比較する。CHoCH、初回HL、READYを独立した候補段階として記録し、同じ親波・転換を重複した独立機会と数えない。

## 固定仕様

[計画](../../reports/qa/three_wave/feature_research/plan.md)を先に保存。既存Sharedは変更せず、ソースから生成した観測用コピーへ副作用のない記録コールバックだけを追加する。現行EA、Sharedソース・バイナリ等は開始時ハッシュを保存する。

研究EAはテスター専用、発注関数なし。ポジション制約・クールタイムで候補を削らず、並行仮想取引のAsk入口/Bid出口を追跡する。RR1、SLバッファ10points、最大240分、固定60分MFE/MAEを採用。主SLの違いを検証するため転換起点SLの共通対照を併記。

既存の汎用`statistical_edge_research.py`は異なるパターンの閾値探索用なので実行しない。今回の取得経路は、既存EAと同じCopyRates履歴・独立MT5のネイティブ指標・実ティックに限定した。

## 開発中に検出・修正した問題

- 最初の短期テストでは、仮想取引の未設定文字列が空文字比較と一致せず、開始直後に終了扱いになった。`OPEN`を明示して状態遷移するよう修正。旧`smoke/`の損益ラベルは無効で、分析対象にしない。
- Pandas 3の日時がmicrosecond単位だったため、監査側のnanosecond前提が誤検出を起こした。明示的な`datetime64[ms]`へ変換して修正。MT5側の時刻に問題はなかった。
- 仮想取引の7件と既存構造26件のネイティブ合成テストに合格。コンパイルは0エラー・0警告。
- 修正版短期テストの再実行は候補/特徴量と損益CSVがバイト単位で一致。

## 証拠

- [研究フォルダ](../../reports/qa/three_wave/feature_research/)
- [観測差分](../../reports/qa/three_wave/feature_research/observer.diff)
- [短期再現](../../reports/qa/three_wave/feature_research/smoke_reproducibility.json)

## 完了結果

2025年1〜3月と5〜7月を独立したMT5で記録した。生候補643件、HLの更新を除いた主分析503件。現行READYとの時刻・親構造一致は46件/55件で確認した。週末等133か所のM1足ギャップも別のネイティブ監査で調べ、今回の期間では候補の取りこぼし0件だった。

CHoCHは月30〜53件、同じM5親波を1回に制限しても月28〜49件の候補がある。しかし両期間で平均Rが正の特徴量binは4つとも小標本で、毎月20件を維持できなかった。EMA上向き・EMA上方の位置・浅い押しに一部差があったが、SLを共通化すると関係が弱まる例もある。フィルター採用・最適化は実施していない。

3か月分の特徴量・結果CSVも再実行でバイト一致。分析集計も再実行で一致し、現行EA/Shared等7ファイルは開始時ハッシュと一致した。計算再現性と、正期待値の統計的再現性を区別する。後者は未確認。

- [最終まとめ・制約](../../reports/qa/three_wave/feature_research/summary.md)
- [再現性と現行版不変性](../../reports/qa/three_wave/feature_research/reproducibility.json)
- [分析の再実行](../../reports/qa/three_wave/feature_research/analysis_reproducibility.json)
- [再利用する判断](../../knowledge/experiments/2026-09-23-three-wave-feature-research.md)
