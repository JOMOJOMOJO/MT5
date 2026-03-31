# Skill Operating Model

このリポジトリでは、基本的に `1 skill = 1 primary role` とする。

各 skill は次の観点で定義する。

- `who`: 誰として振る舞うか
- `when`: いつ呼ぶか
- `where`: どのファイルや証拠を主戦場にするか
- `what`: 何を決めるか
- `how`: どう進めるか
- `output`: 何を残すか
- `handoff`: 次に誰へ渡すか

## Core Flow

### `company`

- `who`: 会社全体の窓口
- `when`: 新しい依頼の開始時、部署や skill の振り分けを考える時
- `where`: `.company/secretary/queue.md`, `.company/ORGANIZATION.md`
- `what`: どの部署と skill がこの依頼を持つか
- `how`: 最小人数・最小責務で routing する
- `output`: routing 方針、更新された queue
- `handoff`: `research-director`, `mq5-review`, `continuous-improvement-office` など

### `research-director`

- `who`: 研究責任者
- `when`: EA を改善する前、探索順序と検証 ladder を決めたい時
- `where`: `knowledge/experiments/`, `knowledge/optimizations/`, `reports/`
- `what`: 次の実験は何か、何を先に捨てるか
- `how`: logic / risk / execution / validation の4軸で候補を絞る
- `output`: 次の 1 から 5 実験、評価 window、昇格条件
- `handoff`: `statistical-edge-research`, `systematic-ea-trader`, `strategy-critic`

### `statistical-edge-research`

- `who`: データマイニング担当
- `when`: ルールを書く前に、チャートや bar データの偏りを見たい時
- `where`: `knowledge/patterns/`, `reports/research/`, `plugins/mt5-company/scripts/statistical_edge_research.py`
- `what`: 再現しそうな偏りや session edge は何か
- `how`: session / volatility / regime を統計的に切り分ける
- `output`: 候補ルール、捨てるべき仮説、再利用可能な pattern note
- `handoff`: `research-director`, `systematic-ea-trader`

### `systematic-ea-trader`

- `who`: ルールベース運用の実務家
- `when`: ルール品質、パラメータの節度、market fit を見たい時
- `where`: `mql/Experts/`, `reports/backtest/`, `knowledge/experiments/`
- `what`: 今のルールが実運用向きか、過剰最適化か
- `how`: trade count, PF, payoff, drawdown, side別の筋の良さで評価する
- `output`: setup quality の所見、次の 1 から 3 実験
- `handoff`: `strategy-critic`, `risk-manager`, `release-manager`

### `strategy-critic`

- `who`: 戦略を殺す権限を持つ批評役
- `when`: ロジックが本当に残す価値があるか疑う時
- `where`: `reports/backtest/runs/`, `knowledge/backtests/`, `knowledge/experiments/`
- `what`: 続行・縮小・分離・撤退のどれか
- `how`: weak window, sample size, friction, OOS 崩壊を優先して攻撃する
- `output`: kill / keep / split の判断と理由
- `handoff`: `research-director`, `company`

### `mq5-review`

- `who`: MQL5 実装レビュー担当
- `when`: EA コードを触った時、約定・サイズ・stop 安全性を見たい時
- `where`: `mql/Experts/`, `mql/Include/`
- `what`: 実装バグや execution risk があるか
- `how`: compile, trade API, stop/freeze level, duplicate entry, magic number を確認する
- `output`: 修正点、残リスク、必要テスト
- `handoff`: `qa`, `release-manager`

### `backtest-analysis`

- `who`: MT5 report 読解担当
- `when`: HTML / XML / CSV の tester 結果を判断材料にしたい時
- `where`: `reports/backtest/runs/`, `knowledge/backtests/`
- `what`: candidate が baseline より本当に良いか
- `how`: baseline 比較、主要指標、tested range、artifact の再現性で判断する
- `output`: imported run, summary, compare note
- `handoff`: `strategy-critic`, `risk-manager`, `release-manager`

### `risk-manager`

- `who`: 損失制御責任者
- `when`: daily cap, DD cap, cooldown, kill-switch を決める時
- `where`: `mql/Experts/`, `knowledge/experiments/`, `.company/qa/checklist.md`
- `what`: どこで止めるか、どの損失は許容しないか
- `how`: live failure mode を想定し、先に止める条件を作る
- `output`: risk guard 条件、運用 kill criteria
- `handoff`: `release-manager`, `forward-live-ops`

### `release-manager`

- `who`: 昇格ゲート管理者
- `when`: backtest から demo/live へ上げる前
- `where`: `.company/release/`, `.company/qa/`, `reports/backtest/`, `knowledge/experiments/`
- `what`: 今上げてよいか、まだ research に留めるべきか
- `how`: QA checklist, risk, broker, rollback, artifact completeness を確認する
- `output`: promote / hold / reject
- `handoff`: `forward-live-ops`, `company`

### `forward-live-ops`

- `who`: demo/live 運用担当
- `when`: forward demo や live ops の準備・監視・振り返り時
- `where`: telemetry CSV, `knowledge/experiments/`, `.company/release/`
- `what`: 現場運用で何を監視し、何が blocker か
- `how`: rule-trigger frequency, spread block, loss lock, trade cap を監査する
- `output`: live ops playbook、1週間レビュー、blocker summary
- `handoff`: `risk-manager`, `research-director`

## Governance Flow

### `continuous-improvement-office`

- `who`: 会社改善室
- `when`: shared skill / MCP / routing が変わった時、定期 review 時
- `where`: `.company/improvement/`, `knowledge/company/`
- `what`: 組織は太りすぎていないか、何を統合・削除・追加すべきか
- `how`: snapshot diff と前回 review を比較する
- `output`: snapshot, review, reusable org knowledge
- `handoff`: `org-designer`, `talent-manager`, `executive`

### `org-designer`

- `who`: 組織設計責任者
- `when`: 部署構成、承認フロー、routing を変えたい時
- `where`: `.company/ORGANIZATION.md`, `AGENTS.md`, `README.md`
- `what`: 構造変更案をどう設計するか
- `how`: 最小変更で責務重複と無責任地帯を減らす
- `output`: 変更前後の構造と影響
- `handoff`: `executive`, `continuous-improvement-office`

### `talent-manager`

- `who`: skill roster の人事担当
- `when`: skill を増やす・減らす・統合する時
- `where`: `plugins/mt5-company/skills/`, `.company/improvement/skill-roster.md`
- `what`: この role は本当に必要か
- `how`: roster を `core / watch / candidate` で見直す
- `output`: add / merge / remove 提案
- `handoff`: `executive`, `continuous-improvement-office`

### `professional-trader`

- `who`: 裁量トレーダー視点の市場適合性レビュー担当
- `when`: execution realism や相場付きの違和感を見たい時
- `where`: `knowledge/experiments/`, `reports/backtest/`
- `what`: この値動きでこのロジックは自然か
- `how`: 市場の文脈、相場のクセ、session の意味で評価する
- `output`: 裁量視点の妥当性レビュー
- `handoff`: `systematic-ea-trader`, `strategy-critic`

## Operating Rule

- 新しい skill を足す前に、この表のどの role が不足しているかを明示する。
- 既存 skill で担えるなら、新設ではなく既存 skill の責務明確化を優先する。
- 1つの skill は 1つの primary decision owner であるべき。
