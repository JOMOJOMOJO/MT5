# Standalone Fractal Wave2 Transition Trader Validation

## Scope
- 新EA `ExpectedValue_MultiCurrency_FractalWave2TransitionTrader` を別ファイル・別ロジックとして作成した。
- 旧EA `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` は変更せずparked research assetのまま維持した。
- 再利用したのはmulti-currency scanner、CopyRates、confirmed pivot、anchor/event ID、signal consumption、risk/lot、CSV、MFE/MAE、tester/batch基盤である。
- session first120、required-light、SMA75、Fib、旧score、pattern hard gateは新entry logicへ持ち込んでいない。
- M15/M5 pivotは左右確定後のみ有効化し、anchor break探索はpivot confirmed timeより後の確定足だけを使う。未来参照はない。
- tester=M15だがEA scanはM5 closed bar。内部CopyRatesはH4/H1/M15/M5、enumはH1=16385/M15=15/M5=5。

## Full 2025
- E base: 154 trades / PF 0.77 / avg_R -0.0972 / net -365.54 / MFE>=1R 23.4%
- F child extreme SL: 154 trades / PF 0.77 / avg_R -0.0972 / net -365.54 / MFE>=1R 23.4%
- G parent wave2 extreme SL: 100 trades / PF 1.03 / avg_R +0.0127 / net +33.83 / MFE>=1R 36.0%
- H one-symbol selection: 154 trades / PF 0.77 / avg_R -0.0972 / net -365.54 / MFE>=1R 23.4%
- I H1 diagnostic: 154 trades / PF 0.77 / avg_R -0.0972 / net -365.54 / MFE>=1R 23.4%
- J full fractal diagnostic: 154 trades / PF 0.77 / avg_R -0.0972 / net -365.54 / MFE>=1R 23.4%

## Required Answers
1. 新EAを別ファイルとして作成した: yes。
2. 旧EAを変更せずparkedのまま維持した: yes。
3. 共通基盤の再利用範囲: scanner/CopyRates/pivot/anchor/event/risk/log/testerのみ。
4. 旧filterを持ち込んだか: no。
5. parent M15 flip: 4536件。
6. valid parent wave1: 4536件。
7. parent wave2 start: 3967件。
8. M5 child counter-trend: 7869件。
9. M5 child trend flip: 2839件。
10. trades: 154件。
11. funnel最大減衰: `funnel_breakdown.csv` のfirst flip→fresh/consumed→tradeを参照。
12. M5 child flip entryの期待値: negative (154 trades / PF 0.77 / avg_R -0.0972 / net -365.54 / MFE>=1R 23.4%)。
13. SL mode差: child=154 trades / PF 0.77 / avg_R -0.0972 / net -365.54 / MFE>=1R 23.4% / parent=100 trades / PF 1.03 / avg_R +0.0127 / net +33.83 / MFE>=1R 36.0%。
14. one-symbol改善: no (154 trades / PF 0.77 / avg_R -0.0972 / net -365.54 / MFE>=1R 23.4%)。
15. H1/H4 alignment診断: H1=154 trades / PF 0.77 / avg_R -0.0972 / net -365.54 / MFE>=1R 23.4% / full=154 trades / PF 0.77 / avg_R -0.0972 / net -365.54 / MFE>=1R 23.4%。hard gateにはしていない。
16. symbol/direction/session依存: `symbol_breakdown.csv`, `direction_breakdown.csv`, `session_breakdown.csv` を参照。
17. 2025 shallow gate通過: none。
18. 3年BT/OOS候補: no; gate未通過のため実施しない。
19. 研究継続条件通過: none。通過なしならfamilyはpark対象。

最終funnel所見: baseは2839 first flipを一度ずつ消費し、spread guard 2344件、invalid stop 341件を経て154 tradesとなった。signal再利用はない。
最良断片Gは100 trades / PF 1.03 / avg_R +0.0127Rだが、PF 1.05未満、SHORT PF 0.79、USDJPY 64%のため昇格しない。
H1 alignment=trueは25 trades / PF 0.71、full alignmentは10 trades / PF 0.65であり、H1/H4 hard gateによる修理根拠はない。
研究判断: 新familyはpark。parent-extreme SL断片は記録するが、閾値微調整や通貨・方向除外では延命しない。

旧EA baseline参照: 318 trades / PF 0.59 / avg_R -0.1582 / MFE>=1R 24.5%。
