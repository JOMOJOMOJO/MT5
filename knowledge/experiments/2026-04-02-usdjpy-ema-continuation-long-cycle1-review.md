# USDJPY EMA Continuation Long Cycle 1

## 目的

- `quality12b` の frequency 不足を補う `USDJPY long-only` の第2 bucket を、fresh thesis から actual MT5 まで確認する。
- 仮説は `EMA13 / EMA100 continuation` の non-round-number branch。

## 実装

- EA:
  - `mql/Experts/usdjpy_20260402_ema_continuation_long.mq5`
- study:
  - `plugins/mt5-company/scripts/usdjpy_ema_continuation_long_event_study.py`
  - `scripts/run-usdjpy-ema-continuation-long-study.ps1`
- 形状:
  - `EMA13 > EMA100`
  - `EMA100 slope > 0`
  - `close > EMA100`
  - `bearish dip` bar:
    - upper wick large
    - lower wick small
    - close location low
    - ret1 non-positive or slightly capped

## study で残した候補

- `london-quality`
  - `session 7-16`
  - `ema13_dist<=22`
  - `adx<=30`
  - `ret1<=0.0004`
  - `upper>=0.45`
  - `lower<=0.10`
  - `close_location<=0.45`
- `london-loose`
  - `session 7-16`
  - `ema13_dist<=22`
  - `adx<=30`
  - `ret1<=0.0004`
  - `upper>=0.45`
  - `lower<=0.15`
  - `close_location<=0.45`
- `london-mid`
  - `session 7-16`
  - `ema13_dist<=12`
  - `adx<=30`
  - `ret1<=0.0002`
  - `upper>=0.45`
  - `lower<=0.15`
  - `close_location<=0.45`
- `londonny-active`
  - `session 7-22`
  - `ema13_dist<=10`
  - `adx<=30`
  - `ret1<=0.0002`
  - `upper>=0.45`
  - `lower<=0.15`
  - `close_location<=0.45`
- `all-active`
  - `session 0-23`
  - `ema13_dist<=22`
  - `adx<=20`
  - `ret1<=0.0002`
  - `upper>=0.45`
  - `lower<=0.15`
  - `close_location<=0.45`

## actual MT5

- `london-quality`
  - train `+576.41 / PF 1.08 / 70 trades / DD 15.06%`
  - OOS `+905.24 / PF 3.78 / 8 trades / DD 2.02%`
- `london-loose`
  - train `+1057.57 / PF 1.12 / 88 trades / DD 12.46%`
  - OOS `+738.46 / PF 2.02 / 11 trades / DD 3.96%`
- `london-mid`
  - train `-204.38 / PF 0.97 / 76 trades / DD 13.82%`
  - OOS `+481.65 / PF 1.68 / 10 trades / DD 5.11%`
- `londonny-active`
  - train `-601.65 / PF 0.94 / 112 trades / DD 24.32%`
  - OOS `+305.20 / PF 1.36 / 13 trades / DD 6.63%`
- `all-active`
  - train `-3532.47 / PF 0.56 / 73 trades / DD 41.42%`
  - OOS `-419.16 / PF 0.51 / 8 trades / DD 8.55%`

## 判断

- current best within this family is `london-loose`。
- 理由:
  - `quality` より少し frequency が増えた。
  - train / OOS の両方でプラスを維持した。
  - `londonny-active` と `all-active` は frequency を狙ったが train が崩れた。
- ただし verdict は `surviving sidecar, not live-ready`。

## 学び

- `EMA13/EMA100 continuation` は `London` に寄せると品質が残る。
- ただし `all session` や `London+NY` まで広げると trade count は増えても edge が落ちやすい。
- `quality12b` と比べると、この family は「frequency を少し補う sidecar」にはなるが、単独で月 20 回を満たす mainline にはまだ弱い。

## 次

- `quality12b` は current best のまま維持する。
- `london-loose` は `research-qualified second bucket` として保持する。
- 次サイクルは 2 択:
  - `quality12b + london-loose` の long-only stack を actual 化する
  - fresh な第3 `long-only` bucket を開く
