# 既存3手法の不振原因診断

旧EA・候補抽出・元の検証結果を読み取り専用で利用する追加モジュール。2024–2025年だけを対象とし、2026年はロックする。機械学習・手法追加・事後の最適化は行わない。

## 実行

リポジトリのルートから、既存の専用環境を使う。

```powershell
& tools/entry_research/.venv/Scripts/python.exe -m pytest tools/entry_research/tests tools/entry_research/diagnostics/tests -q
& tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research.diagnostics --output reports/research/entry_candidates/diagnostics_validated_20261015
& tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research.diagnostics.verify reports/research/entry_candidates/diagnostics_validated_20261015
```

再実行は別の出力ディレクトリを指定する。同じseed・入力・設定なら同じ集計。既存の出力ディレクトリがある場合は解析を停止する。レポート生成だけが中断した場合は同じ出力に`--render-only`を付ける（既にある図は維持、Markdownは集計から再生成）。

```powershell
& tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research.diagnostics --output reports/research/entry_candidates/diagnostics_reproduced --config tools/entry_research/diagnostics/config.json
& tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research.diagnostics.verify reports/research/entry_candidates/diagnostics_reproduced --compare reports/research/entry_candidates/diagnostics_validated_20261015
```

既存ライブラリ numpy/pandas/pyarrow/duckdb/plotly/pytest を使用。追加インストールは不要。環境のパッケージ一覧は各出力のmanifest.jsonに保存する。

## 構成

| ファイル | 役割 |
| --- | --- |
| config.json | 解析前に固定した閾値・探索上限・乱数種 |
| paths.py | H50経路分類とH1–H50の固定母集団曲線 |
| timing.py | 全元候補に対する6方針、約定状態と欠測の区別 |
| exits.py | 対称TP/SLの理想境界シナリオ |
| environment.py | 全732セル、件数/週/各年のゲートとHolm補正 |
| statistics.py | 元候補分母、週ブートストラップ、対照・即時の比較 |
| visuals.py | Plotlyの分布・曲線・時点比較・期待値ヒートマップ・代表例 |
| run.py / report.py | 入力保護、Parquet/CSV/DuckDB保存、Markdown生成 |
| verify.py / tests/ | 実成果物の照合と合成データの回帰テスト |

## 読み方

`report.md`を先に読み、`figures/dashboard.html`をブラウザで開く。配布する場合はfigures内の`plotly.min.js`と`representatives/`、`selection.csv`も同じ相対位置で保持する。外部CDNへの接続は不要。分布の初期表示はP99まで（データ除外なし、全範囲切替あり）、環境ヒートマップの件数基準未達セルは灰色で示す。

`class_summary.csv`は全候補/共通母集団、全体/手法別/方向別/両者を区別する。未出現の分類も0件で保存。`timing_events.csv`は全17,409候補×6方針を保持し、約定候補だけへ絞らない。既知の未約定はopportunity損益0、データ欠損はNaN。状態を変える未来の価格判断はしない。

比較用の共通母集団はH50欠損なしの16,818候補。これは結果計算のための技術的な対象選定で、売買時点で使う選別条件ではない。H10/H50期限とも候補ごとのATRと元の年/週を固定する。`delta_immediate`は同じ候補の損益差であり、`saved_cost_per_origin`と`delta_gross_immediate`に分解する。

環境の週数は独立週数の代用品であり、隣接週の独立性を保証しない。各年/各対照反復の件数・週数を検査し、732予約セル全体のHolm補正を適用する。既存の対照を環境で条件付けしただけなので、環境内で再マッチした因果比較ではない。

代表チャートは未来の50本を意図的に含む**事後診断図**。旧基盤の判定時点チャートは変更していない。固定seedとcandidate_idのSHA256順位で選び、最大損益を選ばない。

境界シナリオのlower/upperは**同足内到達順序に限定した**幅である。実約定の上下限ではなく、ギャップ超過等は保証しない。固定1.9pipsは仮定コスト。source clockのタイムゾーン対応は未確認で、地理的セッション名へ置き換えない。

設計根拠: [解析前計画](../../../knowledge/experiments/2026-10-15-entry-diagnostics-plan.md)。結果を見た後に設定を変更して再探索する場合は、同じ実験の修正とせず、新しい事前計画・別出力として扱う。
