# 複数銘柄対応の土台・上位足定義の監査

## 今回の目的と範囲

2026-10-08のユーザー指示により、別戦略を追加する前に、他銘柄へ移した時の計算・執行・環境認識の前提を監査する。
本番の3Wave/quality12b、既存Shared、過去の凍結研究は変更しない。既存のユーザー変更も保存する。

新しい研究EA：

- `mql/Experts/Research/DailyChannelPortfolioPortable.mq5`
- `mql/Experts/Research/RelativeM5PortableDiagnostics.mq5`

共通処理は `PortableTrading.mqh`、観測は `PortableContextDiagnostics.mqh`。生成元と差分はこのフォルダに保存。
新EAは独立テスター専用。まだ実運用対応・利益改善を確認した版ではない。

## 見つかった問題・前提

|項目|確認内容|今回の対応|
|---|---|---|
|USD集中分類|旧日足はUSDで始まらない全銘柄をUSD逆方向に分類。EURJPY等では誤り|base/profit currency属性で直接USD脚を判定。USDを含まないcrossは0|
|銘柄名|日足の固定名・空白・重複はbrokerのsuffix等で不便|完全名優先。通貨属性による候補が一意の場合だけ解決、複数候補は明示停止|
|ロット|日足は1.0lotで損失換算、失敗理由はVOLUME_OR_RISKに集約|有効な最小lotでOrderCalcProfit。予算・最低lot損失・必要Equity・切下げ後volumeを保存|
|金の未約定|旧149候補は全てロット/リスク見送り。spread制限ではない|MIN_VOLUME_EXCEEDS_RISK等に分離。リスクを超える最低lot切上げはしない|
|許容価格差|日足の固定10pointsは銘柄共通の意味にならない|確定日足ATR比0.05。M5は既にATR比|
|価格・volume刻み|Digitsだけではtick sizeや0.25lot刻みに対応できない|symbol属性を使う共通処理とMQLテスト。SL距離は正規化後で計算|
|イベント時計|日足5銘柄の処理がUSDJPYのOnTickだけに依存|既存minute重複ガードを維持しOnTimerからも呼ぶ。legacy時計との別比較|
|所有権|旧日足は全ポジション数・symbolによる決済を使用|magicで数・リスクを絞りticket決済。同一symbolに他所有positionがあれば触らず見送り|
|スプレッド|M5は既にspread/確定ATR。日足にはspread上限なし|spread/ATRとspread/SL幅を記録。固定pointsの上限に戻さない|
|取引時間|現M5の7〜22時はbrokerサーバー時刻で、各銘柄固有session・DSTではない|今回は同broker同設定の比較で維持。異brokerへ同時刻をそのまま移す検証済みとは呼ばない|
|上位足の方向|最新2高値・2安値の方向と、直近終値breakは別の情報|旧定義を維持し並記。転換したら直ちにUPになる分類と解釈しない|
|同値pivot|旧環境は左右非対称に同値を処理、厳密比較型と同じではない|過去研究の母集団を変えない。将来の厳密pivot比較は別バージョンで行う|
|構造範囲|異なる時期の2高値/2安値の包絡。直近の一往復波と同義ではない|raw位置・範囲外・逆転rangeのUNKNOWNを保持|
|M5買い形状|有効なRoundロングは長い上ヒゲ・短い下ヒゲを要求。名前だけで強い上抜けと解釈できない|機械的反転はしない。出来高増加時の上ヒゲなら売り圧力仮説も区別して観測|

### 旧分類の実データ確認

過去M5の1,666候補で、UP/BEARISHまたはDOWN/BULLISHの組合せはM15=204、H1=240、H4=162件。
[再集計](existing_context_audit.json)。これは誤分類件数ではない。pivot列の方向と最後のbreakという定義が異なることの確認であり、結果の勝敗は集計に使用していない。
最後のbreakは古いこともあるため、必ず経過時間も見る。M15 range無効2件は既存通りUNKNOWN。

### 参照コードから取り入れたもの・取り入れないもの

- `RelativeContinuation/RuntimeRisk.mqh`：最小lot基準のOrderCalcProfit、刻み切下げ、証拠金再確認を共通化。
- `ExpectedValue_MultiCurrency_FXBasket_ContextTrader.mq5`：銘柄別状態・magicによる集計を参考にした。
- 同旧EAの固定lot fallback、最低lotへの強制切上げ、単純tick_value式は採用しない。最低lotに切上げると指定リスクを超え得る。
- 公式の複数銘柄同期例に従い、別銘柄の足が同時に利用可能になると仮定しない。新鮮なquote・取得完了・足時刻を確認する。

## 上位足・volume・急変を合わせた観測

M5/M15/H1/H4ごとに、確定足だけを使って保存する。旧M15/H1/H4分類もそのまま保存し、今回の列がEntryに影響しないことを売買完全一致で確認する。

- 旧regime・position・raw・直近break・経過分数・構造範囲。
- 確定終値が旧構造Highより上か／Lowより下か。
- 足値幅、符号付き実体、前終値からのgap、3本変化をATR比で記録。
- 急変足自身で分母を膨らませないよう、値幅・実体・gapは当該足より前のATRを使用。
- tick volume / その足を含まない直前20本平均。実出来高は同期間が有効な場合のみ別列へ、欠損を0の売り圧力と解釈しない。
- EMA20の3本傾き/ATR、終値からEMA20までの距離/ATR。
- contract、最小lot、spread/ATR。候補のtime/available_at/asofを明記。

これは「上位足＋出来高＋急変」をまとめて検証する観測版。勝てた区分を後からANDで組み合わせる売買フィルターはまだ作らない。
Tick volumeと取引量は別物。銘柄間の絶対volumeを比較せず銘柄内比率にするが、broker/feed差まで消えるわけではない。

## 固定QA：9本

1. 純粋MQLハーネス：18項目（USD脚、刻み、最低lot超過、suffix、右2本確定待ち、未来prefix不変性、範囲外raw）。発注なし。
2. 日足Portable、旧OnTick時計：2023-01〜03、修正前7取引との完全一致を要求。
3. 同条件＋独立timer：時計差を記録する。成績の良い方を選ぶ実験ではない。
4–9. M5のUSDJPY/EURUSD/XAUUSDで、それぞれ旧版とPortable版を同期間・同設定で比較。売買完全一致を要求。

全て2023年1〜3月の工学QA。生成tick許容・品質明記。利益による採用判断も最適化も行わない。
全期間は既知。USDJPYの比較だけで全銘柄の完全汎用性を主張しない。EURJPY直接USD脚0は単体確認で、今回EURJPYの実売買再現は範囲外。
M5のSL=2.2ATR、TP=1.5R、リスク0.65%、spread上限0.20ATR、日足の0.25%上限等は以前の設定を固定。

監査失敗時は残りを止める。MT5は隔離portableで起動し、起動後Codexは待機せず終了する。

## MT5最適化の扱い

MT5のストラテジーテスターには総当たり・遺伝的最適化とforward期間設定がある。ただし銘柄を増やすだけで最適化の信頼性は上がらない。
今回は先に計算の意味・旧版との一致・最低lotでの実行可否を確認する。ロット/銘柄対応の不具合をパラメータ探索で補わない。

次に実施するなら探索対象はSL/ATRとRRの2変数程度に固定し、同じパラメータ集合を複数銘柄で検証する。
リスク%、損失上限、最小lot切上げ、失敗注文の扱いは利益のために最適化しない。
既存18セル探索が全て不合格だった事実も保持し、USDJPYの同じ探索を新研究と呼んで反復しない。
今回のQAで実行差・銘柄差を確認してから、変更理由のある探索範囲を固定する。過去に見た2023–2026をOOSと呼ばず、未使用期間が確認できなければ最終検証は将来forward。

現研究版のFILE_COMMONログは同じ入力名の並列最適化で衝突し得るため、ネイティブ最適化はまだ開始しない。最適化段階ではpassごとのログ分離または最適化専用EAを先に用意する。

## 参照

- [公式：複数銘柄の足同期](https://www.mql5.com/en/book/automation/tester/tester_multicurrency_sync)
- [公式：口座通貨でのOrderCalcProfit](https://www.mql5.com/en/docs/trading/ordercalcprofit)
- [公式：銘柄の属性](https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants)
- [公式：tick volumeとreal volumeのデータ項目](https://www.mql5.com/en/docs/constants/structures/mqlrates)
- [公式：MT5最適化とforward設定](https://www.metatrader5.com/en/terminal/help/algotrading/strategy_optimization)
