# Entry/SL固定・RR1/RR1.2/見送り比較の実行前固定計画

2026-10-01。ユーザー指定に基づき、時刻・スプレッド特徴を除き、複数のモデル表現を比較する。売買EA・Shared・Entry・SLを変更しない。準備後は学習をバックグラウンド起動し、Codexのターンを終了する。

## 問いと共通ラベル

「1Rまでは届いたが、1.2Rには届かずSLになった候補」をEntry時点で識別できるかを主目的にする。現在の通常READY/EMA OFF/M1・M5ヒゲpivot2/2/SL=reversal low−10points/USDJPYの2091候補をそのまま利用。

- 1R/1.2R双方について、SLより先にTPに触れたかを保存M1のBid OHLCから判定。
- RR1.2は元のtickベースshadow結果・最初到達分と照合し、値を維持する。
- 元のEntry Askを使用。Entry BidとM1 Openが全候補で一致することを確認。
- 同じM1足でSL・TP両方に触れた候補は、RR1/1.2の**和集合**を除外する。4件ずつで3件重複、計5件。未完了4件も分離し、2082件を共通の採点/学習対象にする。
- 3クラス: SLが1Rより先 / 1R到達後1.2R前にSL / 1.2RがSLより先。各1189/81/812件。SL後の上昇は利益に数えない。
- 新しいRR1のSL損益は元のSL到達Bidの損失を維持、TPは設定価格で決済する。SLの−1R超過を切り捨てない。
- RR1のTPの正確なtick時刻は未保存。最初到達分の終端を保守的上限としてリプレイに使う。同分に元の決済があればその時刻で上限を狭める。新規候補はM1開始時だが、完全なtick精度再現と主張しない。

## 5パターン

1. STRUCTURE_LGBM: 既存117からhour/weekday周期4項目とspread/R、spread/ATRを削除した111項目。
2. COMPACT_LGBM: 前回固定29構造/Entry項目。
3. TSFRESH_LGBM: 29項目＋tsfreshの固定抽出192項目（12系列×16）。自動的な大量パラメータ探索・全期間の教師あり特徴選択はしない。
4. SEQUENCE_LOGISTIC: 32本×12チャネルの波形を学習側標準化→PCA16→正則化多クラスlogistic。
5. SEQUENCE_AUG_LOGISTIC: 4の学習側だけにtsaug AddNoise(scale=.01,normalize=True)で1複製。原本/複製各0.5重み、評価は元の候補のみ。

波形はM1/M5/M15/H1の閉じて取得可能な33本から終値差/実体/値幅を計算し、最後32本をその時点のATR14で正規化。raw timestamp・曜日・hour・spread・tick volumeは使わない。Entry AskやRを固定するため、spreadの間接的影響まで消えるわけではない。

自動抽出は候補内の過去系列だけで完結する。欠損補完・標準化・PCA・確率補正は学習側でfitする。全8364窓の取得可能時刻、各年の未来OHLC変更不変性を確認済み。合成系列は独立サンプル・新しいトレード・新しい期間とは数えない。ラベルがノイズに不変という仮定を置いた頑健性比較として扱う。

Transformerは今回は採用せず、まず軽量な時系列表現に情報があるかを確認する。

## 固定モデルと評価

- LightGBMは既存の100本/学習率.03/7leaves/depth3/min_child15/reg_lambda5を維持。logistic C=.1、PCA16、固定seed。
- 過去1〜2年の前進予測に多クラスlogistic C=1で確率補正。3クラスなのでP(1.2R)≤P(1R)を保証。
- 2016〜17初期学習、2018〜25を年次前進評価。内側/外側とも15分embargo、両RRのラベル判明時刻と親IDをチェック。未知OOSとは呼ばない。
- 期待Rは予測クラス確率×学習側のクラス別平均SL損益＋候補時点で既知のTP利幅。
- RR1/RR1.2の期待Rが高い方を選び、両方非正なら見送る。同値ならRR1。閾値探索なし。
- ALWAYS_RR1、ALWAYS_RR12、5モデルを同じ候補で比較。各方策で独立に1ポジション/Entryから15分クールタイムをリプレイする。
- 事後除外候補も事前に消さず占有時間へ参加、採点には不使用。未完了は年末まで占有、各年を独立reset。ブローカー注文制御までのEA一致テストではない。
- 各RRのAUC/Brierに加え、救済群（1Rだけ到達）のAUC/AP、年別損益、月別実行数、全機会損益差を保存。
- 年別層化した対応月block bootstrap1000回。見送りは取引ラベルではなく全機会損益比較にだけ0を使う。
- 最終年の各モデル再学習一致、EA/Sharedハッシュ不変、データソースハッシュを保存。

## 実行環境と資料

新しい依存は`%LOCALAPPDATA%/MT5ResearchEnvs/ready_rr_choice`の専用venvへ導入。既存の分析環境は書き換えない。tsfresh=0.21.2、tsaug=0.2.1。依存全体は環境ファイルに保存する。

- [tsfresh抽出設定](https://tsfresh.readthedocs.io/en/latest/text/feature_extraction_settings.html)
- [tsaug AddNoiseの定義](https://tsaug.readthedocs.io/en/stable/_modules/tsaug/_augmenter/add_noise.html)
- [学習側だけで前処理をfitする原則](https://scikit-learn.org/1.9/common_pitfalls.html)

status.json/error.txt/stdout.log/stderr.logで完了・失敗を確認できるようにする。学習後にsummary.mdとCSV・グラフを自動保存。結果の採用・本番反映はしない。
