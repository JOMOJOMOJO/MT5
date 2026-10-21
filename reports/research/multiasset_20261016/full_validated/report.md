# Phase 3 複数通貨・時間足・戦略研究

対象: Bybit-Live。2024-01-01以上2026-01-01未満。実行モード: 全対象。

## 確認できた結果

- 評価した手法・方向セル: **216**。原候補合計 **336,109**、H10観測可能 **331,015**。
- H10ネットATRの点推定が正: **25セル**。事前固定の件数・年別・CI・648多重比較・期間品質をすべて通過: **0セル**。
- 計算結果は探索的。正の点推定だけでは未知データに対する優位性を確認したとは言えない。ライブ昇格は全件False。
- 旧3手法のdetectを変更せず、新3手法を同一の新取得データ・コスト・母集団規則で比較した。旧分析とデータ取得時点・コストモデル・共通warmup条件が異なるため、旧CSVとの単純差を戦略改善と呼ばない。

## データ品質

| symbol | timeframe | status | n_bars | n_candidates | months | data_complete_months |
| --- | --- | --- | --- | --- | --- | --- |
| USDJPY | M5 | available | 167889 | 41105 | 24 | True |
| USDJPY | M15 | available | 55968 | 13537 | 24 | True |
| USDJPY | H1 | available | 13992 | 3257 | 24 | True |
| EURUSD | M5 | available | 167886 | 42209 | 24 | True |
| EURUSD | M15 | available | 55968 | 14089 | 24 | True |
| EURUSD | H1 | available | 13992 | 3293 | 24 | True |
| GBPUSD | M5 | available | 167872 | 42637 | 24 | True |
| GBPUSD | M15 | available | 55967 | 14225 | 24 | True |
| GBPUSD | H1 | available | 13992 | 3356 | 24 | True |
| AUDUSD | M5 | available | 167894 | 41057 | 24 | True |
| AUDUSD | M15 | available | 55967 | 13268 | 24 | True |
| AUDUSD | H1 | available | 13992 | 3299 | 24 | True |
| USDCHF | M5 | available | 105582 | 29613 | 17 | False |
| USDCHF | M15 | available | 35197 | 9641 | 17 | False |
| USDCHF | H1 | available | 8800 | 2246 | 17 | False |
| USDCAD | M5 | available | 167894 | 42103 | 24 | True |
| USDCAD | M15 | available | 55967 | 13905 | 24 | True |
| USDCAD | H1 | available | 13992 | 3269 | 24 | True |

USDCHFは2024-08-01以降だけを取得。欠けた2024年1〜7月は補完せず、年別比較も部分年。取得要求より後の最初の1本をAPIが返したケースは全応答を拒否・記録した。2026の価格は取得要求も分析もしていない。
時刻はAPI UTC契約に基づく整数秒だが、ブローカーサーバー時計との歴史的対応は独立検証できていない。東京/ロンドン/NYとの対応を推定せず、対照の時刻一致は同一source clock上で行った。データ出所は単一ブローカー。Askティック履歴はない。欠損間隔は週末・休場を含み、カレンダー検証前に一律データ障害とは呼ばない。
現在のpoint/pip/tick size/value/contract/lot仕様を保存。tick valueを過去損益換算に流用していない。口座USD換算は同時点の同一通貨価格を使用し、歴史的契約仕様の一致は未確認。

## 主評価（net ATR点推定の上位12件・選別後検証ではない）

| symbol | timeframe | method | side | n | weeks | net_atr | net_ci_low | net_ci_high | delta_unconditional_atr | delta_conditional_atr | net_holm | exploratory_hypothesis_pass |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| USDJPY | H1 | atr_breakout | LONG | 147 | 52 | 0.62974 | 0.051044 | 1.2198 | 0.60438 | 0.36054 | 1 | False |
| USDCHF | H1 | atr_breakout | SHORT | 37 | 23 | 0.58106 | -0.59947 | 1.8095 | 0.8035 | 0.41906 | 1 | False |
| GBPUSD | H1 | atr_breakout | LONG | 78 | 39 | 0.31718 | -0.45494 | 1.0184 | 0.38199 | 0.33699 | 1 | False |
| USDCHF | H1 | donchian | SHORT | 260 | 65 | 0.29821 | -0.091362 | 0.69071 | 0.37334 | 0.34592 | 1 | False |
| USDJPY | H1 | donchian | LONG | 519 | 102 | 0.29027 | -0.00057033 | 0.57016 | 0.29981 | 0.30459 | 1 | False |
| USDJPY | H1 | ichimoku_cloud | LONG | 264 | 96 | 0.28577 | -0.12948 | 0.77016 | 0.27482 | 0.33886 | 1 | False |
| USDCHF | H1 | atr_breakout | LONG | 53 | 27 | 0.28541 | -0.58317 | 1.0468 | 0.40839 | 0.17601 | 1 | False |
| GBPUSD | H1 | ema_cross | LONG | 105 | 84 | 0.22635 | -0.23498 | 0.71432 | 0.25674 | 0.44444 | 1 | False |
| AUDUSD | H1 | atr_breakout | LONG | 72 | 29 | 0.1605 | -0.43619 | 0.66457 | 0.24632 | 0.25941 | 1 | False |
| EURUSD | H1 | atr_breakout | LONG | 64 | 38 | 0.15785 | -0.76643 | 0.99191 | 0.25901 | 0.45076 | 1 | False |
| GBPUSD | H1 | kijun_bounce | SHORT | 258 | 93 | 0.13619 | -0.22148 | 0.505 | 0.28961 | 0.35134 | 1 | False |
| EURUSD | H1 | ichimoku_cloud | LONG | 262 | 91 | 0.12225 | -0.25725 | 0.50913 | 0.3236 | 0.33333 | 1 | False |

全216セルを [primary.csv](primary.csv) に保存。全保有期間は [summary.csv](summary.csv)、[年別](annual.csv)、[月別](monthly.csv)、[Walk-forward](walk_forward.csv)、[相場環境](environment.csv)。

## 評価方法と限界

- エントリー足終値をH1とする。シグナルATR固定。Bid OHLCグロスとコスト控除後ネットを分ける。正値bar spreadは歴史proxy、不明ならUSDJPY1.5pip・他2pip、片道slippage0.2pip、手数料0を仮定。swap未検証のため、長時間保有のネットは全費用込み実損益ではない。
- 全候補を保存し、遅延・期間端・欠損の評価不能を記録。H10の比較は両群とも同じ完全観測プール。未来の完全性を実売買の選別に使わない。H50等では観測母集団が異なるので件数も参照。
- 無条件対照は通貨/時間足/年/方向/件数を一致、条件付き対照はさらに時間・曜日・相対ATRを一致。前者は全体現象、後者は環境を固定した追加効果を問う。収縮戦略の効果が条件付き比較で弱まっても直ちに無効とは言えない。
- 同一カレンダー週の再標本化を全市場で共有、B=20000、10対照反復を独立標本と数えない。648仮説にHolmをかけ、未評価セルも予約。週を跨ぐ依存・仮説を選ぶ人間の過去研究は完全には除去できない。
- H10ネットATR、2対照差が主評価。他の保有時間・pips・環境sliceは記述に限定し、良いsliceだけを採用しない。相場環境の比較は新たなフィルター採択ではない。
- Walk-forwardは固定ルールの暦分割監査。trainのラベル終了から180000秒を空け、検証境界を跨ぐラベルを除外。学習・パラメータ選択はない。2024–25は使用済みなので独立OOSとは呼ばない。

## 売買シミュレーション

1ATR SL/TP・10本決済・0.1%リスク・USD10000、通貨/手法/方向ごと独立口座。重複候補はスキップ台帳。PF/R/DDは [accounts.csv](accounts.csv) の実行ルールに対してだけ計算。同足順序不明は2つの会計シナリオで表示し、実到達順を断定しない。残高依存lotと重複により2シナリオが全経路の数学的上下限とは限らない。
全口座シナリオ **432**、観測打切りなし **48**。欠損を跨ぐ建玉の出口は不明として口座計算をそこで止め、後続候補はblockedとして残す。この場合のPF/DD/残高は全期間の成績ではなく観測済み接頭区間だけ。週末を含む取引カレンダー・swap・証拠金未検証を解決するまで、通年PF/DDやポートフォリオ収益性を主張しない。

## 判断と次段階

事前条件を通過した探索仮説はない。追加条件で無理にプラスへ変えず、今回の固定条件はこの結果で記録する。
方向・タイミング・出口のどれが原因かを本比較だけで因果分離できない。グロス正/ネット負は当該コスト仮定での費用影響を示すが、実際の業者コストが同額とは限らない。時間足・通貨別の差は次の事前仮説にできるが、ここでルールを変更して再選別しない。
独立データはルール凍結後の将来期間を確保する。例えば2027年の連続期間について凍結日、必要件数、1度だけの評価日、停止条件を事前登録する。2026を新しいOOSと呼び直さない。Stage3ポートフォリオ以降は今回未実施。

## 再現性・成果物

- [dashboard.html](dashboard.html)、CSV、Parquet、research.duckdb、セル別候補/対照/アウトカム/実行台帳。
- [manifest.json](manifest.json) に設定・seed・Git HEAD・未コミットソースSHA256・入力SHA256・依存version。保護対象 97 ファイル一致。
- QA pilotの目的は実装・データの整合性。利益によって全展開を決めていない。
- 詳細定義と昇格ゲート: [事前計画](../../../../knowledge/experiments/2026-10-16-multiasset-research-plan.md)。
