# 売買EAへのM15環境表示・CSV診断の追加

## 変更内容

売買EA `USDJPY_M1_M5_3WaveIn3Wave_Long.mq5` に表示・診断呼び出しのみを追加した。M5/M1構造、Entry判定、SL/TP、ロット計算、注文処理、クールタイム、既存EMAフィルターは変更していない。M15値を取引の許可／拒否や価格計算に参照する箇所はない。

新しい入力は全てデフォルトON：

| 入力 | 内容 |
|---|---|
| InpShowM15Environment | 左上パネルと4本の水平線 |
| InpM15EnvironmentCSV | READY・実Entryの固定スナップショットCSV |
| InpM15EntryLabels | READY・実Entry付近の固定ラベル |

3つをOFFにするとM15診断を停止する。既存InpWriteCSVとは独立しており、売買CSVがOFFでもM15診断CSVを記録できる。

## 表示

- 左上：`M15: DOWN / MID`、raw_position、ABOVE/INSIDE/BELOW、Structure High/Low、最後のbreak方向、経過分。
- 紫の水平線：M15 Structure High/Low。灰色の点線：1/3・2/3。
- READYは銀色、実Entryは水色で `ENTRY M15=... pos=... break=...` を表示。ツールチップに構造範囲とIDも保存。
- 価格位置は現在のAsk。確定M15構造だけを使い、形成中M15足の高安は採用しない。パネルは最大1秒ごと、構造は新しい確定M15足を取り込むときに更新する。
- 水平線・パネルは現在値へ更新するが、過去のREADY/ENTRYラベルは作成時の値から変更しない。CSVが有効なら、再初期化時も保存済みの値からラベルを復元する。
- 非ビジュアルテスターでは描画を省略し、診断CSVだけを記録する。

## 定義の共通化

`mql/Include/M15Environment.mqh` が唯一のMQL5計算本体。売買用表示Includeと研究用 `M15EnvironmentResearchReplay.mq5` の両方が使用する。

研究の固定定義を維持：ヒゲpivot左2/右2、左厳密・右同値許容、最新2高値2安値の切り上げ／切り下げ／混在。構造範囲は2高値のmaxと2安値のmin。LOWは1/3以下、MIDは1/3超〜2/3以下、HIGHはそれより上。

raw値をそのまま保存し、範囲外フラグを併記。研究と同じく表示用の正規化値だけ0〜1へclipする。構造幅<=0、またはデータ不足では位置UNKNOWN。旧水平線は残さない。

breakは最新確定pivotを初めて終値突破したイベント。同じpivotの反復突破を重複計上しない。M15の方向ラベルをbreakで上書きしない。

既存Python研究コードは固定定義を独立監査する参照実装として残した。新しいMQL研究再生と売買用の間で計算本体をコピーして分岐させていない。

## CSV

ファイル名：`TW_M15_environment_<symbol>_<Magic>.csv`

通常は端末の `MQL5/Files/`、テスターでは該当Agentの `MQL5/Files/`。今回のテスト分は下記フォルダへ回収した。

- [READYモードの診断CSV](after_ready_final/TW_M15_environment_USDJPY_260922331.csv)
- [HL再接近モードの診断CSV](after_retest/TW_M15_environment_USDJPY_260922331.csv)

event、id、time_msc、symbol、Ask、実約定価格、valid、regime、position、raw_position、range_location、Structure High/Low、break方向・経過分・時刻・level・pivot時刻・confirmed時刻、quote_sourceを保存。

READYは構造シグナル発生時なので、取引拒否された候補も記録する。実Entryは自分のMagicのBUY新規約定をdeal IDごとに記録し、分割約定も別行になる。HL再接近モードでは実Entryが共有構造のLONG READYより先になることがあり、両イベントは混同しない。

実EntryのAskは約定時刻のtickから取得。取得不能時はfillを代用したことをquote_sourceへ明記し、valid=false、位置/rawはUNKNOWN/NAとする。現在のAskで過去を上書きしない。テストではこのフォールバックは0件だった。

CSV書き込み・M15データ取得の失敗は売買の停止条件にしない。取得不足は診断の欠損として残す。遅延した約定通知では約定時刻までの確定足で再構成し、未来のキャッシュを使わない。

## 検証

### コンパイル

- 売買EA：[compile.log](compile.log) — 0 errors / 0 warnings。
- 共通Includeを使う研究再生EA：[research_compile.log](research_compile.log) — 0 errors / 0 warnings。

### 研究との一致

保存済み2025年1〜6月80候補、2024年7〜9月39候補をMQL研究再生へ入力した。

- 全119候補でregime、position、raw、range_location、構造High/Low、break方向・level・時刻・pivot confirmedが一致。
- 確定M15足34,623本の状態を比較。構造が有効な全足で価格位置・breakも一致。欠損はPythonのNaNとMQLのEMPTY_VALUEを同じ欠損として比較。
- raw数値の許容差は2e−11。文字列・時刻は完全一致。
- 本番EAが実際に保存したREADY/ENTRYについても同時刻・同AskでPython参照と照合して一致。

### 売買不変

独立した検証用MT5、USDJPY M1、2025-01-01〜2025-02-01、real-tickモデル、同じ固定入力で追加前後を比較した。通常端末での注文は行っていない。

| モード | signal行 | 新規BUY | deal行 | exit診断行 | 最終残高（両者） |
|---|---:|---:|---:|---:|---:|
| READY | 17 | 17 | 33 | 16 | 9,675.18 USD |
| HL再接近 | 2 | 2 | 4 | 2 | 9,985.50 USD |

TW_signals（SL/TP・注文ID等を含む）、TW_deals（ミリ秒時刻・価格・数量・損益・費用等）、TW_exitsの全列が完全一致。最終残高もtester.logで一致。READYモードの最後の保有はテスト終了処理で閉じられるため、EAのOnDeinit時点のdeal出力は33行・exit診断16行。終了後を含む最終残高も比較している。

この比較は変更の不変性を調べるためのもので、収益性を評価したものではない。既存のテスト入力を今回の表示機能の推奨売買設定として扱わない。

証拠：[verification.json](verification.json)、[追加前READY](before_ready/)、[最終READY](after_ready_final/)、[追加前HL](before_retest/)、[追加後HL](after_retest/)、[共通計算の再生](native_parity/)。

## 変更ファイルと差分

- 変更：`mql/Experts/USDJPY_M1_M5_3WaveIn3Wave_Long.mq5`（観測呼び出しのみ）。[今回の差分](production.diff)。
- 新規：`mql/Include/M15Environment.mqh`、`mql/Include/M15EnvironmentDisplay.mqh`。
- 新規研究：`mql/Experts/M15EnvironmentResearchReplay.mq5`。
- 新規検証：`tools/swing_structure/run-m15-display-validation.ps1`、`run-m15-environment-replay.ps1`、`verify_m15_display.py`。
- 変更前のEAソース・EX5を [before/](before/) に保存。既存ThreeWaveStructure、ThreeWaveInputs、HLトリガー等は変更していない。

## MT5での確認手順

1. 更新された売買EAをチャート／ビジュアルテスターへ読み込む。3つのM15入力はONのまま。
2. 左上パネル、紫のHigh/Low、灰色の1/3・2/3線を確認する。
3. READY／実Entry付近のラベルとCSVの同時刻を比較する。
4. その後M15の構造が変わっても、過去Entryのラベルが変わらないことを確認する。通常起動時は既存CSVから固定値を復元する。

## 検証範囲の限界

売買不変を確認した実行範囲は上記1か月・2モードであり、全ブローカー・全期間の証明ではない。ライブ環境では描画・ファイルI/Oの処理時間がゼロになるわけではないため、更新頻度とイベント記録を限定した。再起動後にM15 CSVを削除していた場合は過去ラベルを復元できない。M15表示の分類は売買の推奨や予測ではない。

## 最終ビジュアル確認（2026-09-29）

[実際のテスター画面](visual_final/verified_display.png)でパネル・水平線・固定Entryラベルを確認した。現在値が DOWN / MID・BULLISH に変化しても、過去Entryは DOWN / LOW・BEARISH のまま保持される。

完了したテストを見返せるよう、テスター終了時には描画を残す。通常チャートでEAを外す場合は、自分のオブジェクトだけ削除する。Entryラベルは右端からはみ出しにくい右アンカーにした。

月間比較後の最終調整は描画終了処理・文字サイズ・アンカーのみ。最終バイナリで2025-01-02〜01-04を再実行し、調整前後の signals / deals / exits CSV のバイト一致を確認した。[最終描画版の売買照合](visual_verification.json)。CSVからの再起動時ラベル復元は実装済みだが、ライブ環境の再起動試験は今回行っていない。
