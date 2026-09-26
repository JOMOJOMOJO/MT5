# CSVの読み方

## 候補と損益

- `primary_candidates_stage.csv`：769行、初回CHoCH/HL/READY、STAGE SL。まずこれを使う。
- `candidates_with_resistance.csv`：1,944行（972生候補×2種類のSL）。`primary=True`、`stop_basis=STAGE`なら769行。HL更新も保存。
- `id`は親M5構造/M1転換/段階/判定時刻。結合キーは`period,id,stop_basis`。
- `entry,sl,risk,result_R,outcome,mfe_exit_R,mae_exit_R,mfe60_R,mae60_R`は前回固定の仮想取引。
- 元データ由来の`h1_room_R,m15_room_R`は**前回の最新高値**までの距離。今回の未突破高値の分析には`res_h1_room_R,res_m15_room_R`を使う。

## 今回の特徴量

結合CSVでは`res_`接頭辞が付く。`resistance_features.csv`では接頭辞なし。

| 列 | 意味 |
|---|---|
| `res_wave1_room_R` | 元のWave1 Highまでの符号付きR。突破済みでも残る |
| `res_wave1_broken` / `res_wave1_active` | ヒゲ突破済みか／現在Ask以上の未突破抵抗として有効か |
| `res_wave1_active_room_R` | 有効なWave1だけの距離。結合CSV側で生成 |
| `res_m5_above_wave1_room_R` | Wave1より上の最寄り未突破M5高値まで |
| `res_m15_room_R` / `res_h1_room_R` | 各TFの最寄り未突破高値まで |
| `res_round_room_R` | 最寄りの上方 .00/.50まで。等値なら0 |
| `res_first_room_R` / `res_first_price` | 有効な5種類の最小価格までの距離／価格 |
| `res_first_sources` | 最小価格にある種類。`M5|M15`等の複数種類もある |
| `res_resistance_count_1p2` | 1.2R以内の異なる抵抗価格数 |
| `res_source_count_1p2` | 1.2R以内の価格×種類の数。同価格の重複を含む補助列 |
| `res_cluster_count_1p2` | 下端が1.2R以内の抵抗クラスター数 |

個数の末尾は`1p0,1p2,1p5,2p0`の4種類。高値には価格、バー時刻、確定時刻、探索本数、FOUND/NOT_FOUND_WITHIN_LOOKBACKも保存。

## 統計・実行台帳

- `mode=CANDIDATES`：その区分の候補全部。
- `mode=UNFILTERED_ACCEPTED`：無条件で採用できた取引のうち、その区分に属するもの。
- `mode=CONDITION_REPLAY`：先にその区分を選び、占有・15分・親波制約を再生したもの。実装済みフィルターではない。
- `comparison=GE`は指定値以上、`BIN`は非重複の距離区分、`COUNT`は0/1/2以上の個数区分。
- `min_month`にはゼロ件の月も入る。期間を合算した平均だけで月20回を判定しない。
- 実行台帳は距離条件ごとの比較結果を同じファイルへ格納。複数feature/labelやSL基準を合算しない。

## 抵抗・クラスター台帳

抵抗台帳は同じ候補・価格でもTF寄与やSL基準ごとに行がある。行数を抵抗価格数と解釈しない。集約済み個数は特徴量CSVを使う。

RNは次のRNを必ず含み、2Rとクラスター幅を覆う範囲まで記録。高値は探索範囲内の条件を満たすものを全て保存しているため、2Rより遠い行もある。遠方のRNやクラスターを網羅した世界全体の抵抗台帳ではない。保証する個数範囲は指定された最大2Rまで。

クラスターは下端で範囲へ算入するため、上端が1.2Rより先でも`cluster_count_1p2`に含まれる場合がある。`first_R,last_R,low,high`で確認できる。
