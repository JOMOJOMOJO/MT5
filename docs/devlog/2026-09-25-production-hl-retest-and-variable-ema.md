# 売買用EA v1.04：HL再接近と可変EMA期間

ユーザー指定により、研究用で唯一プラスだったM1 HL再接近方式を売買用 `USDJPY_M1_M5_3WaveIn3Wave_Long` に移植した。保存済み研究結果は2025Q1の11取引、+91.20 USD、+0.087Rだが、2月・3月は負であり、安定した正期待値の証明ではない。今回ユーザーはバックテスト不要、プログラム変更のみを指定した。

`InpHLEntryMode` を追加し、初期値を `HL_ENTRY_RETEST` とした。現行READYは `HL_ENTRY_READY` として残した。HL再接近では最初の確定HLを固定し、Askが `HL <= Ask <= HL + 0.25 * (HL - SL)` に入った最初のtickで判断する。初期値 `InpHLNearFraction=0.25`。同一親波1回、HL・reversal low・M5起点割れ、期限・親波失効、保有・注文・クールタイム、EMA条件は既存研究実装を継承する。

HL再接近の比較条件に合わせ、既定SLを `STOP_M1_REVERSAL_LOW` に変更した。READYへ戻す場合は `InpHLEntryMode=HL_ENTRY_READY` を選択でき、必要ならSLモードも別途指定できる。HL再接近では比較済みの定義を守るためreversal-low SL以外を入力エラーとする。

EMAは `InpEMAFastPeriod=20`、`InpEMAMiddlePeriod=50`、`InpEMASlowPeriod=100` を追加。`Fast < Middle < Slow` を必須とし、フィルターのEMA順序・上向き判定と `ThreeWave_EMA_Display` の3本表示が同じ期間を使用する。表示インジケーターもv1.01へ更新した。

バックテスト、OOS、デモ検証は実施していない。MetaEditorでEA・表示インジケーターとも0エラー・0警告。コンパイルログは [production_v104](../../reports/qa/three_wave/production_v104/) に保存した。

運用上の制限：HL再接近の監視中にEAを再起動した場合、既に確定済みの古いHLは安全側で消費済みとして扱い、そのセットアップを再発注しない。このため重複は避けるが、再起動をまたぐ再接近機会を取り逃す可能性がある。
