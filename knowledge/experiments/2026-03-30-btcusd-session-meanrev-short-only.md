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
