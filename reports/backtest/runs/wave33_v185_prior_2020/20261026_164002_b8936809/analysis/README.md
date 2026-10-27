# M5×M1 上位高安帯フィルター固定比較

独立整合監査: **PASS / 20397項目**。技術整合と利益の採用判断は別。

| フィルター | 完了position | 費用込み損益 USD | PF | 合計R | 平均R | 最大連敗 | native equity DD |
|---|---:|---:|---:|---:|---:|---:|---|
| v185_b_prior_off | 334 | -1440.92 | 0.8223 | -32.553 | -0.0975 | 8 | 1 949.10 (35.90%) |
| v185_b_prior_on | 215 | -527.93 | 0.9112 | -10.147 | -0.0472 | 8 | 1 276.90 (23.41%) |

部分利確OFF、RR入力1、risk1%、帯片幅0.05、XAUUSD+、初期5000 USD。変更は既存の見送りスイッチだけ。

既知の2020年・生成ティック。同一期間の機序診断であり未使用期間の確認ではない。2026データを使わず、帯幅・RRは探索しない。

334件からBLOCKED119件を単純に引くと215件になるが、これは過去約定を削除した参考集計。EAのON結果には枠解放後の追加候補・出口の変化・複利ロットを含む。

採用判定: `NO_PROMOTION_NEGATIVE_EXPECTANCY`。費用込み損益または合計Rが負なら採用しない。

全監査は[summary.json](summary.json)、入口照合は[paired_positions.csv](paired_positions.csv)、判定可能時点の全SIGNAL根拠は[signal_context.csv](signal_context.csv)、四半期・方向別は[groups.csv](groups.csv)。
