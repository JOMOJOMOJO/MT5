# 2024通常READY・ML診断：収集前固定計画

売買EA、Shared、Entry/SL/TPは変更しない。既存EMA OFF shadow observerを研究専用collectorへ複製し、OHLCとEntry Bid/Ask出力だけ追加。2024-01-01〜2025-01-01（終端排他）をreal ticks指定で実行する。既存2025短期observerとsignals/shadows一致を確認してから年間収集する。期間末未完了は学習除外。

## 固定売買条件

HL_ENTRY_READY、SkipLowerHL=false、EMA OFF、M1/M5ヒゲ2/2、SL reversal low−10points、RR1.2、USDJPY。全shadow候補を保持し、保有やクールタイムで除外しない。Entry Askと以降のBid tick順序は既存observerのまま。

## 収集と因果性

M1/M5/M15/H1のnative OHLCを初期6000本＋閉じたバーの追記で保存。available_atはcollectorが観測した時刻。ウォームアップ履歴はEntryより前のバーだけを使う。Entry quotes、元の構造アンカー、shadow outcome、決済までのMFE/MAEを保持。データ欠落・実tick履歴品質は収集後journalとCSVで検査し、不備を合成tickで隠さない。

## M15/H1トレンドライン位置の定義

ヒゲpivot Left=2/Right=2、既存研究と同じ同値処理、confirmed_time<=Entry。最新確定高値2点を結ぶ上側線、安値2点を結ぶ下側線を候補bar時刻で作りEntry時刻へ外挿。アンカー時刻・確定時刻・価格、傾き/ATR、Entryとの符号付き距離/ATR、ABOVE/BELOW/ONを保存する。傾きの方向によってsupport/resistanceと決めつけない。2線が交差した場合の帯内位置は無効扱い。各Entryの線は固定し未来pivotで引き直さない。

これと独立にUP/DOWN/RANGE、構造High/Low、raw_position、LOW/MID/HIGH、範囲外表示、break情報を保存。線は客観的な2点線の診断であり、裁量の有効トレンドラインと同一とは主張しない。

## 収集後の分析（未実施）

添付仕様の特徴量・基本統計・クラスタリングを実装。Logistic L2、Tree depth2/3/4、LightGBMを比較。LightGBMも小さい葉数・大きいmin_child_samples・固定seedの事前固定設定を使い、探索はしない。test foldのpermutation importanceを保存。SHAPは利用可能かつ安定した場合だけ。

Expanding train Jan-Apr→test May-Jun、Jan-Jun→Jul-Aug、Jan-Aug→Sep-Oct、Jan-Oct→Nov-Dec。決済がtest開始以降のtrain行をpurge。補完・標準化・カテゴリ処理はtrainだけでfit。MFE/MAE/outcome/決済時刻は特徴量禁止。固定確率binを維持し、test結果から閾値を変えない。2024は既知の研究期間を含み、完全未使用OOSとは呼ばない。

本ターンはMT5起動後に終了。収集完了後、ユーザーの合図でデータQAとML分析へ進む。本番採用なし。
