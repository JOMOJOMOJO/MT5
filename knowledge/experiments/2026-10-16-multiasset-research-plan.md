# Phase 3: 事前固定設計

2026-10-16。結果集計前に固定。対象・定数の正本は [config](../../tools/entry_research/multiasset/config.json)。既存3手法と旧データ・結果は変更しない。旧 `.company/secretary/queue.md` の運用系EAとは独立した研究。収益不振に応じた閾値変更は行わない。

## 調査と再利用

既存 `tools/entry_research` の ATR/一目/EMA、3つの detect、OHLCイベント評価と信頼区間の考え方を再利用する。旧 features の USDJPY/M5 固定・H1/M15必須条件は一般化し、使用しない指標の欠測によって新手法の母集団を絞らない。旧保存データは Bybit-Live、サーバー時刻のUTC対応未検証、USDJPYのみ。2024–25は開発で使用済み。2026は既往研究で一部閲覧済みで完全未閲覧とは呼ばず、本研究は一切利用しない。

## 固定された仮説と定義

- 6通貨 × M5/M15/H1 × 6手法 × LONG/SHORT = 216セル。パラメータ探索なし。旧3手法の判定はそのままimportする。
- Donchian20: 当該足を含まない直近20足の高値/安値を終値でクロス。
- Bollinger20/2: SMA20、母標準偏差。前足が対応バンド外、現足終値がバンド内に復帰。
- ATR収縮ブレイク: Donchian20と同じ判定に、前足ATR14 / さらにその前288足ATR中央値 <= 0.8 を追加。
- シグナルは確定時点で記録し、次の観測可能始値を約定proxyとする。1時間足分を超える遅延は失効。上位足は available_time の backward asof、2上位足期間を超えるものは unknown。
- 主評価はH10 net ATR、H1/3/5/20/50、pips、MFE/MAEと1ATR先着は補足記述。Hはエントリー足を1本と数える。
- 全候補を台帳に残す。将来欠損による評価不能と、意思決定時点の未約定を区別。主比較の完全H10マスクは研究上の観測条件であり、実売買のフィルターには使わない。
- 無条件対照は同一通貨/時間足/年/方向/件数。条件付き対照はさらにsource-clock hour/weekday/事前ATR相対区分を一致。10反復、セル内無復元、候補足も対照プールに含める。
- 共通カレンダーの週単位再標本化 B=20000。反復を独立標本と数えない。216セル×(絶対net、無条件差、条件付き差)の648検定にHolm。欠損セルも予約。週を独立と断定しない。異なる市場をプールした有意性を主張しない。実データ成績の初回計算前のQAで、B=10000では最小Holm p=648/10001>0.05となる解像度不足を検出したためBのみ20000に修正。判定結果を見た変更ではない。
- 仮説候補条件: n>=200、週>=30、各年n>=75、2024/25ともnet>0かつ両対照差>0、3指標の95%下限>0かつHolm<=.05。未達は採択しない。
- Walk-forwardは全市場共通、2024H2/2025H1/2025H2を検証区間、各開始前までを拡大型train。学習・選択なしの固定ルール監査。ラベルはsignal_timeからentry+H10終了まで、train終端180000秒embargo、境界を跨ぐラベルをpurge。2024–25の再利用なので独立OOSとは呼ばない。

## 売買ルールと昇格

固定1ATR SL/TP、10本時間決済。1通貨/手法/方向ごと独立口座、重複保有なし。USD10000、1回0.1%リスク、最低lotで超過する場合は見送り。Bid足＋正値bar spread proxy、不明時JPY1.5/他2.0pips、片道slip0.2pips、commission0は仮定。シグナルATRを固定。OHLC同足順序不明は両シナリオ表示。口座通貨換算は同時点価格、現在仕様を歴史仕様と呼ばない。swap・証拠金・ティック約定が未検証なら昇格停止。

Stage1は上記仮説ゲート。Stage2は実行台帳の正のnet/R、両年正、PF>1、保守シナリオDD<10%かつ欠損/コスト品質解消。Stage3は別途ポートフォリオ資本・証拠金・共通USD曝露を明記してから開始。Stage4は実ティックの区間監査、Python/MT5一致・正net・DD基準。Stage5はルール凍結後に取得する将来データ、例えば2027年の連続期間をロックし、必要件数到達後に1度評価。凍結日・閲覧履歴を記録し、結果を見て期間を延長しない。今回Stage3以降は実施対象外。

## 保存構成とQA

新規コード `tools/entry_research/multiasset/` (data/signals/strategies/inference/execution/run/report/tests)。新規結果 `reports/research/multiasset_20261016/` (data、pilot、full、qa)。CSV/ParquetをDuckDBに登録、Plotly HTMLに集約。取得と分析のmanifestにSHA256、設定、ソースhash、依存version、乱数を保存する。研究専用端末だけに接続し注文APIは呼ばない。

先に合成fixtureで未来改変不変・上位足availability・H10境界・コスト・換算・同足曖昧・lot丸め・purgeを確認。USDJPY/EURUSDのM5/M15でQA pilot後、利益とは無関係に全セルを実行。取得不能セルは未評価。2026混入は即失敗。MT5 parityは小規模決定的fixtureの算術検証であり、real tick収益性の検証とは区別する。

API根拠: [MT5 copy_rates_range](https://www.mql5.com/en/docs/python_metatrader5/mt5copyratesrange_py)、[terminal startup](https://www.metatrader5.com/en/terminal/help/start_advanced/start)。APIのUTC契約とブローカー履歴時刻の独立検証を区別する。
