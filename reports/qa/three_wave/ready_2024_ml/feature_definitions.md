# Entry時点の特徴量定義

## 母集団とラベル

- 2024年全通常READY 180件。候補IDは元EAのsignal_id、親IDはその第1要素。Entry/SL/TP/READY種類は元のobserverと同じ。
- `tester_outcome` / `tester_target` / `result_r`：保存されたMT5経路の結果。実tickがない期間の生成tick結果も含むので、学習正解とは区別する。
- `target`：Entry〜決済までが実tick開始以降、かつ日単位のtick absent/discarded警告に重ならないTP=1 / SL=0。それ以外は欠損。警告日のうち実際に欠損した分足を特定できないため、1日の全候補経路を保守的に除外する。
- `label_status` / `tick_order_unverified` は品質診断用で、モデル入力ではない。期間末未完了はCENSORED、学習除外。今回の年末は全件決着。
- 結果Rは既存shadowと同じ価格R。Ask Entry、Bid判定、TP価格丸め、SL超過を維持。commission/swapを含む口座純損益ではない。
- `mfe_to_exit` / `mae_to_exit` 等はラベル・診断専用。モデル入力禁止。

## 時刻・pivot

すべてブローカーのserver時刻。各バーの終了時刻<=Entry、取得時刻available_at<=Entryを満たす履歴を使う。pivotはヒゲ2/2で、候補時刻と右2本目の終了時刻を分離する。今回の既存Sharedと同じく、左側は厳密比較、右側は同値を許す。新たなpivot定義へ変更しない。

`confirmed_time <= Entry`を満たすものだけで構造・線を作る。最新構造高値は最新2高値のmax、構造安値は最新2安値のmin。両方切上げ=UP、両方切下げ=DOWN、混在/同値=RANGE、不足=UNKNOWN。raw_position=(EntryAsk−low)/(high−low)。表示分類はclip後に1/3、2/3でLOW/MID/HIGH。rawはclipしない。

breakは確定バー終値が最新の既知高値を上回る/既知安値を下回る時に記録。同じpivotのbreakを重複登録しない。M15既存診断CSVと全候補で分類・位置・raw・最終break方向・経過分が一致する。

## A/B. H1・M15環境とライン

- `*_regime`, `*_position`, `*_raw_position`, `*_range_location`：上記定義。
- `*_last_break_direction`, `*_minutes_since_break`, `*_break_distance_atr`：最新break方向、Entryからの経過分、(break価格−Entry)/Entry時ATR14。
- `*_bullish/bearish_break_age_minutes`, `*_bullish/bearish_break_distance_atr`：上下それぞれ最後のbreakを別記。
- `*_recent_up_swing_atr`, `*_recent_down_swing_atr`：最新確定高値とそれ以前の最新確定安値の価格差、最新確定安値とそれ以前の最新確定高値の価格差をEntry時の同時間足ATRで割る。同一候補バーの上下pivotは順序不明なので組にしない。
- `*_up_down_swing_ratio`, `*_up_swing_vs_previous`, `*_down_swing_vs_previous`：直近上下波比、および同方向の直前波との比。同方向pivotが連続したときは始点を共有する場合がある。後からZigZagの極値へ差し替えない。
- `*_up_expanding`, `*_down_contracting`：上記比が1超/1未満。不明は欠損。
- `*_atr14`：Wilder ATR14。最初の14TRを平均し、その後(13*前ATR+TR)/14。
- `*_atr_state`：ATR14 / 直近100確定バーのATR14中央値。
- `*_high_line_*`, `*_low_line_*`：最新2確定高値/安値の候補bar時刻を結ぶ直線。価格線形補間でEntry時刻まで外挿。傾きはATR/時、Entry距離は(Entry−線価格)/ATR、sideはABOVE/BELOW/ON。CSVにはold/newのbar/confirmed/priceを残す。
- `*_line_band_position`：(Entry−下側線)/(上側線−下側線)。上下線の価格順が逆転・同値なら欠損、`*_line_band_valid=0`。裁量の「有効なトレンドライン」ではなく、再現可能な2点線の診断。
- `*_nearest_resistance/support_R`：最新800本の履歴内で確定済みかつ未突破の上/下pivotまでの正距離/R。ATR換算も保存する。

## C. M5 Wave1経路

対象は元EAのM5 origin候補バーからWave1 high候補バーまで。すべてEntryより前に確定済み。

- `wave1_range_price/pips`, `wave1_minutes`, `wave1_bars`：高値−起点、USDJPY1pip=.01、候補時刻差、期間内バー数。
- `wave1_bullish_fraction`：close>openの割合。dojiは陽線に含めない。
- `wave1_bullish/bearish_body_sum`, `wave1_bullish_body_share`：陽線body合計、陰線body絶対合計、陽線合計/全body絶対合計。
- `wave1_mean_bull/bear_body`, `wave1_body_ratio`, `wave1_max_consecutive_bearish`：平均bodyとその比、最大連続陰線数。
- `wave1_er`：起点low→高値バーの直前までのM5 close列→高値の経路について、絶対net変化/絶対変化合計。`wave1_close_er`は対象バーclose列のみで計算する別診断。
- `wave1_max_drawdown_price/range/formation_atr`：上記アンカー付きclose経路のrunning maxからの最大下落。価格、Wave1値幅比、formation ATR比。
- `wave1_running_high_drawdown_atr`：対象バー列の「過去バーまでの最高high−後続バーlow」の最大値/formation ATR。同一バー内の高安順序は推測しない。起点・高値のバー内時刻はないため、厳密なtick経路の最大逆行とは呼ばない。
- `wave1_mean_clv`, `wave1_high_close_fraction`：CLV=(close−low)/(high−low)の平均、CLV>=.75の割合。
- `wave1_first/second_half_speed_atr`, `wave1_acceleration`：アンカー付きclose経路を中央で分けた1区間あたりnet変化/formation ATR、その後半/前半比。時間欠損がある場合は壁時計速度ではなく観測バー区間速度。分母0は欠損。
- `wave1_strength_atr_choch`：Wave1値幅/CHoCH確定時ATR。
- `wave1_strength_atr_formation`：Wave1値幅/期間内ATR14中央値。
- `wave1_strength_atr_confirmation`：Wave1値幅/高値確定時ATR。
- `wave1_strength_atr`：Wave1値幅/Entry時ATR。
- `wave1_choch_break_price`, `m5_choch_break_atr`, `wave1_choch_body_atr`：CHoCH終値−固定return high、そのEntry ATR比、break足body/CHoCH時ATR。

## D. Wave2 / セットアップ

- `setup_age_minutes`, `wave1_high_to_entry_minutes`, `m5_choch_to_ready_minutes`：各アンカーからREADY/Entryまでの実時間差。
- `wave2_retrace`, `wave2_max_pullback_atr`：Wave1 highバー終了後からEntryまでの既知M1最安値への押しをWave1値幅/Entry時M5 ATRで割る。高値と安値のバー内順序不明を避け、高値バー内の押しは含めない。
- `wave2_m5_bars`：高値バー後の確定M5本数。
- `wave2_lower_high_count`, `wave2_higher_low_count`：高値バー以後に形成され、Entryまでに確定したM5 pivotの、前の同種pivotからの切下げ/切上げ回数。
- `wave2_failed_high_tests`：Wave2内でhigh>=それ以前のrunning high、close<=そのhighのバー数。
- `wave2_wave1_retests`：high>=固定Wave1 high、close<=固定Wave1 highのバー数。
- `wave2_atr_ratio`：Entry ATR / Wave1 high確定時ATR。

## E. M1・Entry直前5/10/20分

`ready_return_high=1`は既存early_break=true、READY_RETURN_HIGH。0はREADY_WAVE1_HIGH。閾値やREADY成立時刻は変えない。

`m1_wave1_strength`はL0→H1値幅/Entry時M1 ATR14、`m1_wave1_efficiency`はM5と同じアンカー付きclose経路ER、`m1_wave2_retrace`は(H1−確定L1)/(H1−L0)。

各windowNはEntryの分境界直前N分の閉じたM1のみ。N本なければ欠損。過去Nバーへ遡って休日や欠損を埋めない。

- `net_return_atr`, `range_atr`, `realized_movement_atr`：初足open→最終close変化、窓high−low、初足openと各close間の絶対差合計をEntry時M5 ATRで割る。
- `compression_ratio`：窓の各バーhigh−low合計/直前同長窓の合計。旧名compression10/20も保持。
- `bullish_fraction`：陽線割合。
- `higher_lows`, `lower_lows`, `higher_highs`：窓内候補・Entryまでに確定したM1 pivotの切上げ/切下げ回数。比較元は窓より前の既知pivotでもよい。
- `failed_high_tests`：high>=それ以前の窓running highかつclose<=そのhighのバー数。
- `upper25_fraction`, `lower25_fraction`：窓全体range上側/下側25%にM1 closeがある割合。tick滞在時間そのものではない。
- `entry_position`：(EntryAsk−窓low)/(窓high−low)、clipしない。
- 旧研究の`new_highs`はバーrunning high更新回数。新`higher_highs`は確定pivot同士の比較であり区別する。

## F/G. 抵抗と時刻

上側抵抗はEntryより上でEntry時点まで未突破の確定pivot。後続の閉じたnative足とM1足のhighが厳密に超えたら突破、同値タッチは未突破。探索は直近800確定バー。nearest_resistance_RはM5/M15の近い方。H1は別項目。TP前個数は丸め済みの実TP未満。同値・異時間足の重複pivotも数え、旧列に価格重複除外の数も保存。

時刻のsin/cosはserver時刻に対して作る。過去のserver→UTCオフセットが未確認のため、Tokyo/London/New Yorkセッションは断定しない。`session_timezone_status`へ未確認を保存し、セッションフラグは学習に入れない。

spreadは収集した同一Entry tickのAsk−Bid。`spread_R`, `spread_m1_atr`も保存する。

## モデル・欠損

全194特徴は[all_feature_columns.json](all_feature_columns.json)、モデルの固定allowlistは[model_features.json](model_features.json)。特徴の絶対価格、ID、calendar date、結果、品質フラグはモデル入力から除く。trainのみで中央値補完・標準化・one-hot。全train欠損の数値列は0補完し、実測値と解釈しない。

ATR中央値、傾き、抵抗範囲等の固定定義は結果を見て変更しない。比率分母0/情報不足は欠損。時系列区間や取引結果から外れ値閾値を探索しない。
