# 固定高値の終値再突破B：工学QA合格、戦略は採用しない

- 全34run合格（新規30＋修正後r2から再監査付き再利用4）。3ソースcompile 0 errors / 0 warnings、Python34テスト、MQL harness15項目。
- 対象年の履歴・全月・33run、元版/A約定一致3組、A/Bの候補・shadow・環境一致15組を確認。
- 過去swap仕様差7runは環境不一致のまま明記。限定的な日内買い・適用swapゼロ・約定/cash/判断CSV完全一致だけ比較可能とした。
- USDJPY実行PF A0.969 / B0.975、EURUSD A0.657 / B0.755、XAUUSD A0.987 / B0.829。全期間で全案PF<1。
- 全4,476候補のshadowでも全銘柄A/B平均Rは負。BはEURUSDで損失縮小したが正期待値を作れず、USDJPY/XAUUSDは悪化。
- Bは中央値15分待ち、平均0.51〜0.55 A-R高いEntry。B未成立で避けたA損失1,773件に対して取り逃したA利益341件。両案成立群もBの平均Rが悪化。
- Bは単独月20件に達した月が全銘柄0。最大のA XAUUSDでも月平均14.82件。
- 年別・固定HTF環境区分の再現性不足。2025年USDJPY Bの29件・PF2.001だけでは採用しない。
- 判定：`DO_NOT_PROMOTE_B`。この上ヒゲ終値再突破の入口仮説をpark。本番EA変更、RR/待機本数/spread再最適化、OOS/live昇格なし。
- Aも本検証の全期間で正期待値を示しておらず、本番昇格の根拠にしない。

[採否・全結果・制限](../../reports/qa/wick_rebreak_20261014_r3/runs/20261014_094513_6f6042e2/review/summary.md)
[機械可読な採否](../../reports/qa/wick_rebreak_20261014_r3/runs/20261014_094513_6f6042e2/review/verdict.json)

既知2023〜2026年9月・生成tick・年別初期10,000 USDの独立口座。45か月連続複利、合成portfolio、未使用OOSと呼ばない。
