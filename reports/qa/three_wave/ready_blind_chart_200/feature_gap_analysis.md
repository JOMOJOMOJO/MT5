# 117特徴と画像で判断し得る形状の対応

2026-10-02。正本は `tools/swing_structure/analyze_ready_2024_ml.py` のFEATURES（117個）および `reports/qa/three_wave/ready_generated_tick_ml/audit.json`。数式は `build_ready_2024_ml_dataset.py` と `analyze_ready_failures.py` を確認。母表に存在しても117許可リストにない列はモデル入力済みと扱わない。直近のtsfresh192追加・波形モデルも今回の「既存117」と混同しない。

「十分」は当該の狭い定義を直接持つという意味であり、画像理解と同等・予測力ありという意味ではない。多対一の集計値から足の順序全体は復元できない。

| 画像で見る項目 | 既存の主な特徴 | 分類 | 残るギャップ |
| --- | --- | --- | --- |
| 波の角度 | wave1_strength_atr、wave1_minutes、wave1_first_half_speed_atr、wave1_second_half_speed_atr、m15/h1_high/low_line_slope_atr_per_hour | 一部表現 | M5 Wave1速度・上位足2点線はある。M1各legの局所勾配の連続変化・曲率はない。画面角度自体は軸倍率に依存。 |
| Wave1の滑らかさ／ガタつき | wave1_er、m1_wave1_efficiency、wave1_max_drawdown_range、wave1_running_high_drawdown_atr、wave1_max_consecutive_bearish、wave1_body_ratio、wave1_mean_clv | 一部表現 | ERと逆行でかなり要約しているが、同じ集計値でも揺れの順序・位置・周期は異なる。 |
| Wave2の戻し速度 | wave2_retrace、wave2_max_pullback_atr、wave2_m5_bars、setup_age_minutes、window5/10/20_net_return_atr、compression_ratio | 一部表現 | 深さと経過時間はある。押し中の加速・減速・急落後の横ばいの順序を直接表さない。 |
| 安値切り上がり幅 | wave2_higher_low_count、window5/10/20_higher_lows、m15/h1_recent_up/down_swing_atr、m1_wave2_retrace | 一部表現 | 回数や戻し率はあるが、連続する安値間の価格差列、HL間隔、底の支持帯への集中はない。 |
| 高値試行回数 | wave2_failed_high_tests、wave2_wave1_retests、window5/10/20_failed_high_tests | 既存特徴量で十分表現されている（固定した回数定義に限る） | 失敗試行回数そのものは直接入力済み。各試行の間隔、ヒゲ形状、同一抵抗への接近具合は未表現。 |
| ローソクの密集／間延び | window5/10/20_range_atr、realized_movement_atr、compression_ratio、upper25_fraction、lower25_fraction、wave1_body_ratio | 一部表現 | 値幅圧縮や終値の帯内割合はある。実体・ヒゲの重なり配置、空間密度、間隔の推移は要約されていない。固定時間足で横の本数密度は一定。 |
| Wave1とWave2の時間バランス | wave1_minutes、setup_age_minutes、wave2_m5_bars | 一部表現 | M5の時間比較はモデルが組み合わせれば可能。M1 Wave1/2各所要時間・確定待ちと形成時間の比は117内で直接持たない。 |
| 直前相場に対する相対的な勢い | wave1_strength_atr_choch/formation/confirmation、wave1_acceleration、wave2_atr_ratio、m15/h1_atr_state、up_swing_vs_previous、down_swing_vs_previous | 一部表現 | ATR・前回swing比はある。直前の複数legとの形状・速度系列の比較は十分でない。 |
| 下降トレンド継続度 | m15/h1_regime、last_break_direction、minutes_since_break、down_swing_vs_previous、up_down_swing_ratio、wave2_lower_high_count、window5/10/20_lower_lows | 一部表現 | 方向・直近波・一部回数はある。M1/M5の下降開始からのLL/LH系列長、各戻りの規則性は直接表さない。 |
| 逆三尊的な底固め | window5/10/20_lower_lows/higher_lows、各TF regime等の間接情報 | ほぼ未表現 | 左肩・頭・右肩の順序、左右対称性、ネックライン、時間・深さの比を明示した特徴はない。名称に当てはめるだけで優位性が出るとは言えない。 |
| 上位足と下位足の整合性 | M15/H1 regime・position・last_break_direction・swing比、M5 Wave1/2、M1 strength/efficiency/retrace | 一部表現 | 個々のTF状態は入力済みで木モデルは交互作用を学べる。各TFの転換・押しの同期や、同じ価格帯への反応の時間順序は直接持たない。 |

## 画像検証で答えられること

未来を切り、結果とID対応を隠した固定画像に対して、判定スコアとその後の固定Entry/SL/TP結果の間に順位関係があるかを調べる。形状の順序情報が有望という仮説は検証対象であり、既に存在すると結論しない。

画像が良くても、117特徴に含まれない独立情報とは限らない。特徴の非線形な組み合わせ、モデルの学習差、チャート注釈、事前知識、標本の偶然も区別が必要。画像が悪い場合も、確定足のみ・表示範囲・匿名化という入力制約下の結果であり、人間の目視一般を否定しない。

新特徴量、画像モデル、EA修正は本段階では実装しない。
