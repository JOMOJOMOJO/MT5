# 複数銘柄汎用化QA

固定3か月の工学検証。利益によるパラメータ選抜・本番採用は行っていない。

|run|銘柄|取引数|損益USD|完全一致比較合格|
|---|---|---:|---:|---|
|harness|USDJPY|0|0.00|False|
|daily_reference|USDJPY|7|-48.34|False|
|daily_legacy_clock|USDJPY|7|-48.34|True|
|daily_timer|USDJPY|7|-48.19|False|
|m5_USDJPY_reference|USDJPY|49|-239.91|False|
|m5_USDJPY_portable|USDJPY|49|-239.91|True|
|m5_EURUSD_reference|EURUSD|36|-505.68|False|
|m5_EURUSD_portable|EURUSD|36|-505.68|True|
|m5_XAUUSD_reference|XAUUSD|55|73.63|False|
|m5_XAUUSD_portable|XAUUSD|55|73.63|True|

M5の3銘柄は同銘柄・同設定の変更前後を比較。上位足旧分類も完全一致を監査。
日足の独立timerは時計だけを変えた別実行。差分はclock_comparison.jsonで確認し、利益だけで時計を選ばない。
risk.csvに契約サイズ・最小ロット・最小ロットのSL損失・必要Equity・見送り理由を保存。
portable_context.csvはM5/M15/H1/H4の確定足だけのtick volume比、実出来高欠損、急変/ATR、EMA傾き、旧構造とbreakの観測。売買フィルターではない。
生成tickがある場合、tick volumeは配信・生成モデル依存であり市場の実取引量と解釈しない。

## r5 audit and provenance

Six completed MT5 runs were copied from the locked r4 batch and re-audited. Only the remaining four EURUSD/XAUUSD runs were newly executed. Sources and input values are unchanged. See reuse_provenance.json and manifest.json.
Normalized-volume risk rejections require planned loss above budget and no same-symbol entry in the signal minute. Accepted plans still require loss within budget. Unexpected risk errors still fail.
All prior gates remain: 21 MQL harness checks, complete native deal coverage, exact paired fills/costs/candidates, observed specifications, history fingerprints, build identity, and causal context checks. History fingerprints do not prove cryptographic identity of every tick; minute polling cannot detect transient specification changes within one minute.
Currency conversion observations are at observed_time; a late-captured closing deal does not reconstruct entry-time conversion. This is engineering QA on known dates, not profitability selection or OOS validation.
