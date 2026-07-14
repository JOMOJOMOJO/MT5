# 確定待ちstateはeventを保持しなければならない

上位足の終点pivot確定を待つEAで、毎scan最新候補へ置換すると、待っているparent event自体が消え続けて0 signalになる。これは厳しい条件ではなく状態機械バグである。

`PARENT_WAVE2_PENDING` がparent eventを保持し、確定・無効化・期限切れのいずれかまで所有するよう直すと、0件だったMode 1は通年4319 wave2 startまで到達した。ただし取引成績は165 trades / PF 0.69で、ロジックを正しく動かすこととedgeがあることは別だった。

Evidence: [state review](../../reports/backtest/runs/20260714_fractal_wave2_transition_state_review/summary.md), [state transitions](../../reports/backtest/runs/20260714_fractal_wave2_transition_state_review/state_transition_breakdown.csv).
