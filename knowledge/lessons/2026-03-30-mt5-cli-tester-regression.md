# MT5 CLI tester regression and fallback

## lesson

- `reports/backtest/*.ini` と preset を使った command-line tester は、`2026-03-30 14:53` までは動いていた。
- その後は既知の旧 config でも `Tester automatical testing started` が出ず、通常 terminal 起動に落ちた。
- これは新しい `btcusd_20260330_session_meanrev` 固有ではない。

## impact

- MQL の compile は通っても、HTML report を前提にした MT5 backtest pipeline が止まる。
- そのため、戦略探索を止めずに進めるには Python validator の代替レーンが必要。

## action

- `session_meanrev_validate.py` を追加して、同じ MT5 terminal データから trade/day と PF を継続評価できるようにした。
- `backtest.ps1` は preset 配布と exit code 判定を少し堅くした。
- install dir への preset copy は権限不足があるため warning 扱いにする。

## next

- command-line tester が止まった原因を切り分ける。
- 原因候補:
  - preset 参照先の扱い
  - terminal 単一インスタンス起動の挙動
  - command-line tester のローカル状態
