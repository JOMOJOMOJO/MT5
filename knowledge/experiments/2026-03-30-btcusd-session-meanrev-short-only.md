# BTCUSD M5 session mean-reversion short-only promotion

## 要約

- 結論: `btcusd_20260330_session_meanrev` は `late long + asia short` の両建てより、`asia short-only` の方が安定した。
- 現在の baseline に採用した条件:
  - `InpAllowBuy=false`
  - `InpAllowSell=true`
  - `InpShortStartHour=0`
  - `InpShortEndHour=7`
  - `InpShortDistanceATR=1.20`
  - `InpShortRsiMin=70.0`
  - `InpHoldBars=12`
  - `InpExitBufferATR=0.20`
  - `InpEmergencyStopATR=3.00`
- 理由:
  - train/test とも `5 回/日以上` を維持できた。
  - train/test とも PF が `1.27 / 1.32` まで改善した。
  - long を混ぜると OOS 側の PF が崩れた。

## 検証方法

- 研究用 script:
  - `plugins/mt5-company/scripts/statistical_edge_research.py`
- EA 近似 validator:
  - `plugins/mt5-company/scripts/session_meanrev_validate.py`
- データ:
  - `BTCUSD / M5 / 50000 bars`
  - window: `2025-10-06` から `2026-03-30`
  - split: `2026-01-01`

## 主な結果

### 両建て baseline

- file: `reports/research/2026-03-30-session-meanrev-validate/baseline.json`
- train: `23.85 trades/day`, `PF 0.93`
- test: `23.25 trades/day`, `PF 0.90`
- 判断: 回数は十分だが、期待値が悪い。

### long-only 深押し

- file: `reports/research/2026-03-30-session-meanrev-validate/long_only_12_40.json`
- train: `5.31 trades/day`, `PF 1.01`
- test: `5.07 trades/day`, `PF 0.88`
- 判断: 回数は足りるが、OOS が弱い。

### short-only 有力候補

- `short_only_12_70.json`
  - train: `5.74 trades/day`, `PF 1.22`
  - test: `6.00 trades/day`, `PF 1.13`
- `short_only_15_70_h12.json`
  - train: `4.94 trades/day`, `PF 1.19`
  - test: `5.27 trades/day`, `PF 1.24`
- `short_only_15_65_h12.json`
  - train: `6.56 trades/day`, `PF 1.10`
  - test: `6.86 trades/day`, `PF 1.19`
- `short_0_7_12_70_h12_stop30_exit20.json`
  - train: `5.21 trades/day`, `PF 1.28`
  - test: `5.11 trades/day`, `PF 1.32`
- `short_0_7_12_65_h12_stop30_exit20.json`
  - train: `6.94 trades/day`, `PF 1.13`
  - test: `7.04 trades/day`, `PF 1.25`

### 摩擦込みの確認

- `short_0_7_12_70_h12_stop30_exit20_slip250.json`
  - condition: `entry slip 250 / exit slip 250 / stop slip 400`
  - train: `5.21 trades/day`, `PF 1.21`
  - test: `5.11 trades/day`, `PF 1.25`
- `short_best_slip250_spread2800.json`
  - condition: 上記 slippage に加えて `max spread 2800`
  - train: `5.21 trades/day`, `PF 1.21`
  - test: `5.11 trades/day`, `PF 1.25`
- 判断:
  - 少なくともこの履歴 window では、candidate は軽い摩擦ではなく、かなり重めの摩擦を入れても壊れていない。

## 採用判断

- default は `0-7時 / 1.20 / RSI 70 / hold 12 / stop 3.0 / exit 0.2` を採用した。
- live guard として `InpMaxSpreadPips=3000` と `InpMaxDeviationPips=250` を追加した。
- `1.50 / RSI 70 / hold 12` は PF は良いが、trade/day が 5 を少し割る。
- `0-7時 / 1.20 / RSI 70 / hold 12 / stop 3.0 / exit 0.2` は、PF と trade/day のバランスが最も良かった。

## 次にやること

- MT5 command-line tester の自動起動不安定を解消し、同じ candidate を HTML report 付きで再検証する。
- live 前提の spread / slippage / execution gap は validator 側へ追加済み。次はより長い履歴で再確認する。
- 0-7 時 short-only の candidate を 2024-2026 のより長い履歴で再確認する。

## 2026-03-30 追加改善

- 新しい baseline 候補:
  - file: `reports/research/2026-03-30-session-meanrev-validate/short_no_fri_skip3_0_8_10_66_h12_stop35_exit20_slip250.json`
  - 条件:
    - `InpShortEndHour=8`
    - `InpShortDistanceATR=1.00`
    - `InpShortRsiMin=66.0`
    - `InpEmergencyStopATR=3.50`
    - `InpAllowedWeekdays=0,1,2,3,4,6`
    - `InpBlockedEntryHours=3`
- 理由:
  - `金曜` と `3時` が期待値を大きく削っていた。
  - その 2 つを切った上で閾値を少し緩めると、`5回/日以上` を維持したまま PF が改善した。
- 結果:
  - train: `5.49 trades/day`, `PF 1.42`
  - test: `6.03 trades/day`, `PF 1.34`
  - all: `5.74 trades/day`, `PF 1.38`
- 追加確認:
  - split を `2025-11-15`, `2025-12-01`, `2026-01-01`, `2026-02-01` にずらしても test PF は `1.29, 1.29, 1.34, 1.40` で baseline より安定した。
  - 月別では `2025-12` がまだ弱いが、黒字を維持した。
- 判断:
  - 直近の repo 内候補では、現時点でこれを `btcusd_20260330_session_meanrev` の default として採用する。
  - ただし live-ready の確定には、MT5 HTML report ベースの再検証と、より長い履歴での確認がまだ必要。

## 2026-03-30 追加改善 2

- validator の fidelity 改善:
  - `daily loss cap` を Python validator に実装し、EA と同じく `日次の realized balance` ベースで新規エントリー停止が効くようにした。
- 新しい baseline 候補:
  - file: `reports/research/2026-03-30-session-meanrev-validate/short_no_fri_skip3_0_8_10_66_h12_stop40_exit30_spread2500_slip250.json`
  - 条件:
    - `InpShortEndHour=8`
    - `InpShortDistanceATR=1.00`
    - `InpShortRsiMin=66.0`
    - `InpHoldBars=12`
    - `InpExitBufferATR=0.30`
    - `InpEmergencyStopATR=4.00`
    - `InpAllowedWeekdays=0,1,2,3,4,6`
    - `InpBlockedEntryHours=3`
    - `InpMaxSpreadPips=2500`
    - `daily_loss_cap_pct=3.0`
- 結果:
  - train: `5.19 trades/day`, `PF 1.60`
  - test: `5.93 trades/day`, `PF 1.55`
  - all: `5.09 trades/day`, `PF 1.57`
- split 安定性:
  - `2025-11-15` split test: `5.06 trades/day`, `PF 1.57`
  - `2025-12-01` split test: `5.00 trades/day`, `PF 1.61`
  - `2026-01-01` split test: `5.93 trades/day`, `PF 1.55`
  - `2026-02-01` split test: `5.90 trades/day`, `PF 1.60`
- 月別:
  - `2025-10` から `2026-03` まで全月黒字を維持した。
- 判断:
  - repo 内 validator の範囲では、これが現時点の最良 baseline。
  - 次の gate は `MT5 HTML report-backed の再確認` と `より長い履歴での再検証`。

## 2026-03-30 追加改善 3

- 長い履歴の確認:
  - file: `reports/research/2026-03-30-session-meanrev-validate/short_no_fri_skip3_0_8_10_66_h12_stop40_exit30_spread2500_slip250_80k.json`
  - window: `2025-06-23` から `2026-03-30`
  - 結果:
    - train: `4.50 trades/day`, `PF 0.93`
    - test: `5.93 trades/day`, `PF 1.55`
    - all: `4.69 trades/day`, `PF 1.12`
- 判断:
  - 直近 50k では強いが、80k へ伸ばすと `2025-06` から `2025-09` の夏場で edge が崩れる。
  - この family は、まだ live-ready ではない。
- 追加の research:
  - `EMA20 から離れ過ぎた short` が夏場の悪化に寄与していた。
  - そのため `short_max_dist` を validator と EA の両方に追加した。
  - `short_max_dist=3.0` は 80k train PF を `0.93 -> 1.02` まで改善したが、trade/day は `4.25` 近辺まで落ちる。
- 結論:
  - 現時点では `stop 4.0 / exit 0.3 / spread 2500` の candidate を直近候補として維持する。
  - ただし長い履歴 gate は未通過なので、次は `max distance` と `volatility regime` を組み合わせて再設計する。

## 2026-03-30 追加改善 4

- 切り分け:
  - `夏だから悪い` というより、`2025-06` から `2025-09` に増えた悪い regime` が問題。
  - 具体的には、bad summer の trade は other 月と比べて `ATR%` がかなり低く、`gap_atr` は高かった。
  - bad summer 内でも `gap_atr` 上位 quartile は勝率が `32.65%` まで落ちた。
- 対応:
  - validator と EA に `long/short min atr pct`, `long/short max atr pct` を追加した。
  - `short_max_dist` と `short_min_atr_pct` を組み合わせた robust variant も検証した。
- robust variant:
  - file: `reports/research/2026-03-30-session-meanrev-validate/short_no_fri_skip3_0_8_10_66_h14_stop40_exit30_spread2500_maxdist3_atrmin5_slip250_80k.json`
  - 条件:
    - `short_max_dist=3.0`
    - `short_min_atr_pct=0.0005`
    - `hold_bars=14`
  - 結果:
    - train: `3.80 trades/day`, `PF 1.10`
    - test: `5.39 trades/day`, `PF 1.48`
    - all: `4.07 trades/day`, `PF 1.23`
- 判断:
  - seasonal filter を増やすより、`gap / volatility regime` のフィルタで説明する方が再現性が高い。
  - ただし現時点では、robustness を上げると trade/day が 5 を割りやすい。
  - 次は `short_max_dist + atr regime` を保ったまま `5回/日前後` を維持する別ロジックか、別の entry construction を作る。

## 2026-03-30 追加改善 5

- 目的:
  - `80k` でも `5回/日` に近い回転を維持しつつ、PF 低下を抑える。
- 探索:
  - `dist` と `rsi` を中心に小バッチで再探索。
  - 代表比較:
    - `dist 0.90 / rsi 64-82`:
      - train: `4.68 trades/day`, `PF 1.07`
      - test: `6.30 trades/day`, `PF 1.39`
      - all: `4.92 trades/day`, `PF 1.18`
    - `dist 0.88 / rsi 65-82`:
      - train: `4.41 trades/day`, `PF 1.09`
      - test: `6.03 trades/day`, `PF 1.42`
      - all: `4.66 trades/day`, `PF 1.21`
- 採用候補:
  - file: `reports/research/2026-03-30-session-meanrev-validate/short_no_fri_skip3_0_8_087_64_82_h14_stop40_exit30_spread2500_maxdist3_atrmin3_slip250_80k.json`
  - 条件:
    - `InpShortDistanceATR=0.87`
    - `InpShortMinATRPercent=0.0003`
    - `InpShortRsiMin=64.0`
    - `InpShortRsiMax=82.0`
    - `InpHoldBars=14`
    - `InpEmergencyStopATR=4.0`
    - `InpAllowedWeekdays=0,1,2,3,4,6`
    - `InpBlockedEntryHours=3`
  - 結果:
    - train: `4.77 trades/day`, `PF 1.06`
    - test: `6.42 trades/day`, `PF 1.39`
    - all: `5.01 trades/day`, `PF 1.17`
- 直近 50k 確認:
  - file: `reports/research/2026-03-30-session-meanrev-validate/short_no_fri_skip3_0_8_087_64_82_h14_stop40_exit30_spread2500_maxdist3_atrmin3_slip250_50k.json`
  - all: `5.62 trades/day`, `PF 1.43`
- 判断:
  - `80k` 側は PF をやや犠牲にして回転数を確保した形。
  - `実運用前` の次 gate は、MT5 HTML report を伴う同条件の再確認と、連敗・日次DD管理を含む運用ルール固定。

## 2026-03-30 追加改善 6 (Live Guard)

- 目的:
  - EA を実運用に近づけるため、`戦略本体` を変えずに `運用停止ルール` を組み込む。
- 追加したガード:
  - `max trades per day`
  - `max consecutive losses + cooldown bars`
  - `equity drawdown cap (optional)`
- 近似検証:
  - 過度に厳しい設定 (`max_consecutive_losses=4`, `equity_drawdown_cap_pct=12`) は取引停止が早すぎて不採用。
  - 採用設定:
    - `max_trades_per_day=10`
    - `max_consecutive_losses=5`
    - `consecutive_loss_cooldown_bars=24`
    - `equity_drawdown_cap_pct=0` (機能は実装済み、デフォルト無効)
- 採用設定での結果:
  - file: `reports/research/2026-03-30-session-meanrev-validate/liveguards-mid-80k-b.json`
    - train: `4.61 trades/day`, `PF 1.07`
    - test: `6.06 trades/day`, `PF 1.45`
    - all: `4.80 trades/day`, `PF 1.20`
  - file: `reports/research/2026-03-30-session-meanrev-validate/liveguards-mid-50k-b.json`
    - train: `5.71 trades/day`, `PF 1.54`
    - test: `6.06 trades/day`, `PF 1.45`
    - all: `5.37 trades/day`, `PF 1.49`
- 判断:
  - long-window 側で `PF` を改善しつつ、取引回数は `実運用寄り` の水準を維持。
  - 次は MT5 HTML report で同条件の再現を取り、運用チェックリストに昇格する。

## 2026-03-30 追加改善 7 (MT5 HTML 再現)

- 問題:
  - MT5 CLI report が `bars=0, ticks=0` となるケースが発生。
  - 原因は preset 内 `InpSignalTimeframe` が不正値 (`16389`) になっていたこと。
- 修正:
  - `reports/presets/btcusd_20260330_session_meanrev-baseline.set`
  - `InpSignalTimeframe=5` に修正。
- MT5 report-backed result:
  - report: `reports/backtest/imported/btcusd_20260330_session_meanrev-combined-m5.htm`
  - imported run:
    - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-30-212224-417653-btcusd-20260330-session-meanrev-.json`
  - metrics:
    - total trades: `242`
    - profit factor: `1.75`
    - net profit: `+156.61` (deposit `10000`)
- 解釈:
  - MT5 実測でも `収益性は正` を確認。
  - ただし validator と取引密度差があるため、次の改善は `netting前提の検証一致` と `forward-demo`。

## 2026-03-30 追加改善 8 (Forward Telemetry)

- 目的:
  - `demo-forward` と `live` の実行ログを repo に持ち帰れる状態にする。
- 実装:
  - EA に `telemetry CSV` を追加。
  - `entry`, `exit`, `loss_lock`, `daily_summary` を `FILE_COMMON` へ出力。
- 意味:
  - backtest だけでは分からない `停止理由`, `連敗ロック発動回数`, `日次の実運用ノイズ` を後で検証できる。
  - 次の 1 週間 demo-forward は、この telemetry を前提に評価する。
