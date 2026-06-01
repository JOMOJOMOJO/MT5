# 2026-05-19 - MT5 Secondary Terminal Default

## Summary

- task: make validation scripts use the second local MT5 install by default
- status: implemented

## Changes

- updated `scripts/backtest.ps1`
  - if `MT5_TERMINAL` is unset, prefer `C:\Program Files\XMTrading MT5 - 2\terminal64.exe`
  - fall back to `C:\Program Files\XMTrading MT5\terminal64.exe` only if the second terminal is unavailable
- updated `scripts/compile.ps1`
  - if `MT5_METAEDITOR` is unset, prefer `C:\Program Files\XMTrading MT5 - 2\MetaEditor64.exe`
  - fall back to the old MetaEditor only if needed
- updated `scripts/run-usdjpy-ema-continuation-long-study.ps1`
  - default terminal path now follows `MT5_TERMINAL`, then the second MT5 install

## Verification

- PowerShell parser check passed for:
  - `scripts/backtest.ps1`
  - `scripts/compile.ps1`
  - `scripts/run-usdjpy-ema-continuation-long-study.ps1`
- Confirmed both second-install binaries exist:
  - `C:\Program Files\XMTrading MT5 - 2\terminal64.exe`
  - `C:\Program Files\XMTrading MT5 - 2\MetaEditor64.exe`

## Notes

- Explicit `-TerminalPath` or `-MetaEditorPath` arguments still override this default.
- User environment variables still override the repo fallback if set.
