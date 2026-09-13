# USDJPY専用化は高頻度の正EVを保証しなかった

Evidence: [USDJPY-only result](../../docs/research/tick_shock/usdjpy_only_ml_results.md),
[frozen model](../../reports/analysis/tick_shock/usdjpy_only_ml_20260912/frozen_model.json),
[month comparison](../../reports/analysis/tick_shock/usdjpy_only_ml_20260912/comparison_monthly.csv).

既存の6通貨研究でUSDJPYの部分成績が良いことは、USDJPY専用モデルを学習すれば
同様に勝てることを意味しない。訓練標本数、model family、score分布、frequency校正、
方向選択が変わる。専用研究では開発で全forward月200件以上かつpooled正EVのセル0。
凍結診断モデルのMay/June140tradesは−0.02464R、PF0.9064。

月200件はepisode母数上可能でも、学習期間target150のcutoffがforward365件に
膨らみ、後のholdout44件へ縮むことがある。固定数Top-Nを未来月に合わせて選べば
見えなくなる不安定性であり、過去のみのcalibrationで可視化する必要がある。

技術的重要度は情報使用の証跡であり正EVの証明ではない。今回の重要度はvolatility
とcross-timeframe比率、EMA整列、shock×MACDを示すが、売買採用基準は別に未達。
May/Juneを使った救済調整なし。本番候補ではない。
