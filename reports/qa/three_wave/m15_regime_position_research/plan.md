# M15 regime × position：事前定義

前回119候補・476 RR結果を固定。売買EA、Shared、Entry/SL/TP、注文処理は変更しない。保存済みMT5確定M15足を再生する研究用Pythonのみを追加する。両期間は既知でありOOSではない。

## Entry時点の2軸

- M15ヒゲpivot左2/右2、左厳密・右同値許容を継承。足時刻と確認完了時刻を分離。
- 最新2高値・最新2安値とも切り上げ：UP、とも切り下げ：DOWN。揃っているが混在・同値：RANGE。不足：UNKNOWN。breakでこのラベルを上書きしない。
- 構造高値＝最新2確定高値の高い方、構造安値＝最新2確定安値の低い方。全期間の最高値や将来の頂点は使わない。
- 現在価格＝Entry Ask。raw_position=(Ask−構造安値)/(構造高値−構造安値)。価格が既知構造外へ出る場合があるためraw値とBELOW/INSIDE/ABOVEを必ず保存し、指定の0〜1表示値だけをclipする。
- LOW：[0,1/3]、MID：(1/3,2/3]、HIGH：(2/3,1]。境界規則を固定。UNKNOWN／幅<=0は位置UNKNOWN。
- 主集計は指定の9区分＋UNKNOWN。構造外をLOW/HIGHへまとめる影響が見えるよう、INSIDEだけの同形式集計も診断用に併記する。これを売買条件として選ばない。

## 独立した転換特徴

- 最新の確定swing highをM15終値で初めて超える：bullish break。最新swing lowを初めて下回る：bearish break。同じpivotは1回だけ記録し、新pivotが最新になれば参照を更新。後から確定したpivotに過去breakを遡及付与しない。
- 両方向の最終break時刻・level・levelのpivot時刻/確定時刻、各経過分、最後の方向、Entryからlevelまでの符号付き価格差/R/絶対距離Rを保存。追加の時間binや距離binを作らない。
- 「転換break」はbreak直前に既知のregimeがDOWNでbullish、またはUPでbearish。これは反転兆候であり、2高値2安値のトレンド反転確定とは分ける。
- Entry後30/60/120分のbullish/bearish/転換break有無と初回時間を将来ラベルとして別処理で記録。加えてEntryのUP/DOWNと反対方向へpivot regimeが変化したかも別記録。RANGE/UNKNOWNからの反対方向は定義しない。
- 将来窓不足は欠損。将来ラベルはEntryカテゴリに一切使わない。

## 評価とQA

各期間・全期間のregime×positionで件数、ゼロ月込み月別件数、4固定RRの勝率・期待値・RベースPF・MFE/MAE・SLまたは24hまでの到達率を保存。全期間合算だけで期間差を隠さない。

元損益/ファイルhash不変、途中切断と未来価格改変で過去不変、2回再生一致、全pivot confirmed<=Entry、境界・構造外の単体QAを行う。前回の生成ティックと費用未考慮の制約を継承。閾値探索・フィルター採用なし。
