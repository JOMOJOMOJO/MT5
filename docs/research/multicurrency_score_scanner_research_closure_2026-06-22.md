# Multi-Currency Structure Research Closure

Date: 2026-06-22

## Decision

`ExpectedValue_MultiCurrency_ScoreScanner` から派生した Phase2 / ThirdWave / Nested N-Wave / Structural BOS / FX-only 条件探索の検証は、いったん active research から閉じる。

これは削除ではない。次のEAを作るための研究資産として保存する判断である。

現時点の結論は次の通り。

- 本番候補として昇格できる汎用EAはまだない。
- 特定年、特定symbol、特定direction、金曜停止、短期閾値で勝たせる方向には進まない。
- 既存ファミリーをさらに微調整するより、次のEAでは「上位足構造の定義」を最初から作り直す。
- 再利用すべき価値は、売買ロジックそのものよりも、検証フレームワーク、診断設計、失敗パターン、候補を棄却する基準にある。

## Research Scope

このクロージャーは以下の研究群を対象にする。

- Phase2 multi-currency score scanner
- LONG_ONLY / SHORT_ONLY / symbol 分解
- DowFractalStructureFilter
- ThirdWave original / regime / v2 / v3 / v4
- Wave Audit
- LowerTF SL / RewardR shadow diagnostics
- Signal / Regime Quality
- Nested N-Wave Neckline Break
- Retest Confirmation
- Breakout Quality Router
- Context Quality Router
- Router Decision Audit / gate safety
- Structural BOS v0 / v2
- Condition Factorial
- Fixed Condition BT
- Relaxed / Broad FX-only candidate generation
- Sweep / Reclaim / Retest entry triggers

## Evidence Index

主要な証拠は以下に保存されている。

- [Phase2 summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_summary.md)
- [ThirdWave closure](thirdwave_research_closure.md)
- [ThirdWave lessons](../../knowledge/lessons/thirdwave_lessons_learned.md)
- [Nested cleanup decision](nested_nwave_research_cleanup_decision.md)
- [Structural BOS design seed](nested_nwave_structural_bos_design_seed.md)
- [Structural BOS v2 short summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_short_summary.md)
- [Condition Factorial summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_summary.md)
- [Fixed Condition BT summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_summary.md)
- [Relaxed FX-only summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_summary.md)
- [Broad FX-only summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_summary.md)
- [Sweep/Reclaim/Retest summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_summary.md)

## Phase2 Findings

Phase2では、5分新バーscan、方向別分解、symbol別集計、Dow/fractal構造フィルターを追加した。

主な結論:

- 2025年の BOTH + 5m は負の期待値のままだった。
- LONG_ONLY は一時的に良く見えたが、汎用戦略の証明ではない。
- SHORT_ONLY は明確に弱かった。
- DowFractalStructureFilter はLONG branchをきれいにしたが、複数年・複数通貨の普遍edgeまでは確認できなかった。
- XAUUSD依存とdirection偏りを取り除くと、汎用候補としてはまだ弱い。

再利用するもの:

- multi-currency scan framework
- scan diagnostics
- by_symbol / by_direction / by_month / by_score_band
- stop条件OFFの研究用比較
- entry selection / symbol / direction の研究用モード

再利用しないもの:

- LONG_ONLYを本線にする判断
- USDJPY shortだけ外す判断
- XAUUSDだけを本線候補にする判断

## ThirdWave Findings

ThirdWaveは「3波初動」を狙う仮説だったが、Wave Auditで実態が確認された。

主な結論:

- 現行ThirdWaveは厳密な3波初動ではない。
- `third_wave_initial` と `third_wave_middle` は少なく、`chasing_entry` が支配的だった。
- v2/v3/v4でentryを前寄せしようとしたが、汎用的な改善にはならなかった。
- micro_break / candle_reversal は一部の期間や条件で良く見えたが、単独では頑健ではなかった。
- LowerTF SL + 1.2R は短期では良かったが、2024年で崩れた。
- 失敗原因はRewardRやSL幅の単独問題ではなく、regime / signal quality / pullback quality の複合問題だった。

捨てる仮説:

- confirmed fractal reclaim / breakdown だけで3波初動を捉えられる。
- chasing_entryを少しfilterすれば3波初動型になる。
- RewardRやSLだけを調整すれば家族全体が直る。
- micro_breakだけを抽出すれば普遍edgeになる。

再利用するもの:

- Wave Audit label
- result_R / avg_R
- MFE / MAE / R到達診断
- LowerTF SL / MidTF SLのshadow比較手順
- reversal signal taxonomy
- short-period gateからannual/OOS gateへ進む検証手順

## Nested N-Wave Findings

Nested N-Wave Neckline Breakは、ThirdWaveの反省から「2波内部の下位足逆トレンドが否定された場所」を狙うために作った。

主な結論:

- 2025-10のような局面では強い。
- 2025-02や2026-Q1ではfalse breakoutを多く食らった。
- Retest Confirmationは損失を減らすが、強い即ブレイクを削りすぎた。
- Breakout Quality Routerは方向性として有効だったが、勝ちを選ぶよりtrade数を減らす効果が中心だった。
- Context Quality RouterやFriday Guardはedgeではなく、リスク抑制・後付け条件に近かった。
- `clean_nested_nwave_entry` は人間目線のcleanとは言い切れず、条件通過ラベルに近かった。

捨てる仮説:

- M15ネックラインブレイクの見た目だけで十分。
- breakout_close_strengthやbody ratioを重ねれば安定する。
- Retestだけを待てばfalse breakout問題が解決する。
- Friday stopや時間帯抑制を戦略edgeとして扱う。

再利用するもの:

- neckline quality diagnostic
- failure_type / winning_type / setup_failure_layer
- retest_quality分類
- false breakout監査
- context qualityという設計観点

## Structural BOS Findings

Structural BOSは、M15ネックラインの見た目ではなく、H4/H1の構造否定を主役にする試みだった。

主な結論:

- v0はH4/H1構造定義が薄く、最新pivot比較に近かった。
- v2でpivot sequenceやtrue BOS levelを改善したが、trade数が少なすぎ、PF/avg_Rも改善しなかった。
- 主因はM15確認ではなく、H4/H1構造定義の弱さだった。
- 構造を厳密にすると候補が消え、広げるとedgeが消える。ここが次EA設計の中心課題である。

次に必要な考え方:

- H4の1波/2波候補を先に厳密化する。
- H1逆N波動を「見た目」ではなく構造列として定義する。
- M15はentry triggerではなく、H1構造否定の確認役に下げる。
- BOS levelは直近高値/安値ではなく、逆N波動の防衛線にする。

## Condition Factorial / Fixed Condition Findings

Condition Factorialは、後処理でどの条件が効いているかを見るために有用だった。

主な結論:

- `cond_room_to_2r` は短期4期間で最も有望だった。
- MT5固定BTでも `Fixed Room2R` は再現した。
- ただしSHORT/XAUUSD寄りで、LONGとFXだけの汎用edgeは弱い。
- tighterな条件はtrade数が少なすぎた。
- `room_to_2r` は重要な診断ラベルだが、単独hard gateとして本線化するにはまだ早い。

重要な数値:

- Condition Factorial broad: 47 trades, PF 1.171, avg_R +0.137, net +239.56
- `cond_room_to_2r`: 24 trades, PF 1.624, avg_R +0.37
- Fixed Room2R MT5: 24 trades, PF 1.625, avg_R +0.37, net +403.59
- Fixed Room2Rは短期では良かったが、分布はSHORT/XAUUSD寄りだった。

## FX-only Broad / Relaxed Findings

FX-onlyでXAUUSD依存を外すと、edgeの弱さがはっきりした。

主な結論:

- 2025 FX-only Broadは 63 trades, PF 0.737, avg_R -0.190, net -603.67。
- relaxed branchは想定ほど候補数を増やせず、room_to_2rだけが小さく効いた。
- hard gate削減版では 3999 trades まで広がったが、PF 0.826, avg_R -0.096, net -9227.62 とedgeはなかった。
- M15 close BOSだけはavg_Rが改善したが、PF/netが弱く固定BT候補ではない。
- 広い候補生成は「構造edgeがないと数を増やすほど負ける」ことを示した。

## Sweep / Reclaim / Retest Findings

最後に、FX-only 2025でsweep/reclaim/retest系の入口を広げて確認した。

主な結論:

- `sweep_reclaim` 単独も、`bos_retest` 単独も、`first_pullback_after_reclaim` 単独も崩れた。
- combined triggerも崩れた。
- `room_to_2r` は損失を抑えたが、PF/avg_Rを正にするほどではなかった。
- trigger追加ではなく、上位足contextと障害物構造の定義が先に必要である。

重要な数値:

- `C_sweep_reclaim_only`: 1815 trades, PF 0.833, avg_R -0.069, net -6672.82
- `D_bos_retest_only`: 1635 trades, PF 0.798, avg_R -0.142, net -6856.00
- `F_combined_new_triggers`: 3897 trades, PF 0.818, avg_R -0.041, net -9190.93
- `G_combined_new_triggers_room_to_2r`: 2586 trades, PF 0.854, avg_R -0.033, net -4846.47

## Assets To Preserve

次EAに持ち込む価値があるもの:

- multi-currency framework
- scan interval comparison framework
- all-candidates mode
- lightweight diagnostics and summary counters
- by symbol / direction / session / month / regime / label aggregation
- result_R / avg_R / MFE / MAE / R reach
- Wave Audit labels
- failure_type / winning_type / setup_failure_layer
- neckline quality diagnostics
- room_to_1R / room_to_2R obstruction diagnostics
- short-period gate to annual/OOS gate
- Python post-processing to MT5 fixed-mode reproduction workflow
- compile log and devlog discipline

## Patterns To Avoid

次EAでそのまま使わないもの:

- confirmed fractal reclaim / breakdownだけに依存するentry
- M15ネックラインブレイク足の見た目だけでentryする設計
- false breakout対策としてRetestだけを強制する設計
- 金曜停止や時間帯停止をedgeとして混ぜる設計
- XAUUSD_ONLY / FX_ONLY / LONG_ONLY / SHORT_ONLYで勝たせる設計
- USDJPY shortだけ外す設計
- 2025年だけに合わせた閾値
- RewardR / SL幅だけで救う改善
- raw early-failを全scan全symbolで出す重い診断
- 条件を追加し続けてtrade countだけを減らす改善

## Parking Decision

この研究ファミリーは「検証済みの研究資産」としてparkする。

続けないこと:

- ThirdWave v5
- Nested Router v4
- M15 candle quality threshold tuning
- FX-onlyやXAUUSD-onlyへの逃げ
- Friday/time filterによる改善

続ける価値があること:

- 次EAで、H4/H1の構造定義から再設計する。
- room_to_targetを最初から診断に入れる。
- entry triggerはM15単体ではなく、上位構造の否定に紐づける。
- all-candidatesで広く取り、Python診断で仮説を作り、MT5固定modeで再現確認する。

## Next EA Direction

次のEAは、このファミリーの延長ではなく、新しいresearch familyとして始める。

仮称:

- `STRUCTURAL_CONTEXT_BOS`
- `NESTED_NWAVE_CONTEXT_FIRST`
- `LIQUIDITY_SWEEP_AFTER_HTF_CONTEXT`

設計原則:

- H4/H1 context first
- M15 execution second
- symbol / direction / weekdayに依存しない
- fixed rules first
- annual/OOS before promotion
- edgeが確認できるまでRewardR/SLの微調整に入らない

次EA向けの具体アイデアは [next EA idea bank](next_ea_idea_bank_from_multicurrency_research.md) に保存した。
