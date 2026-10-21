# M5実行 × M15/H1/H4環境：観測専用の固定検証

## 今回の変更

2026-10-07のユーザー指示に従い、上位足による除外・可変RRの比較から、全上位足環境を残す診断へ切り替える。
`RelativeContinuation` の固定ソースから独立した研究EAを生成する。売買用・Sharedの変更なし。
対象は現在のcontinuation EAであり、過去のThreeWave READY EAではない。

- USDJPY / M5、元のM5シグナル条件を維持。
- SL=確定M5 ATR14 × 2.2、TP=1.5R、Equityリスク0.65%。
- spread上限=0.20ATR、保有上限18M5本、1ポジション、日次/最大DD制御などは維持。
- M15/H1/H4は全状態で許可。UNKNOWNも除外しない。
- 最適化、可変SL/TP、時間帯や環境の新規フィルターは実施しない。

## 環境定義と因果性

既存M15Environmentと同じ、ヒゲpivot Left/Right=2/2。最新2高値・2安値が共に上昇=UP、共に下降=DOWN、その他=RANGE。
同値pivotの扱いも既存実装を保持する（左側は厳密比較、右側同値は許容）。今回変更しない。
H1/H4は既存研究の共通クラスへ時間足秒数を渡す。同一M15足で元クラスとの一致をEA内で監査する。
各時間足最大1200本、閉じた足だけをStepへ渡す。履歴不足はUNKNOWNかつhistory_complete=0。
structure_high=max(直近2高値)、structure_low=min(直近2安値)。価格位置はAsk基準raw値とLOW/MID/HIGH、ABOVE/INSIDE/BELOW。
High<=Lowの時はregimeを保持し、位置UNKNOWN、rawは空欄、range_valid=0。範囲を捏造しない。
Breakは既知pivotの終値突破。bar/confirmed/known時刻を区別する。

## 保存内容

- 各候補/実Entry：3時間足のregime、position、raw値、範囲内外、構造High/Low、break方向/時刻/確定時刻/経過分数、利用足数。
- Bid/Ask、spread価格/points/ATR、確定M5 ATR、サーバーhour/weekday、日時・年・月。
- 実行gate、spread許可、ポジション数、日次件数、日次損失/最大DD/不明発注ラッチ。
- 各raw候補から18M5本までの利用可能Bid tickを1分OHLCへ集約。Entry以降だけを保存。
- `candidates_with_context.csv`：全raw候補とshadow結果、実行有無、gateフラグ。
- `trades_with_context.csv`：実注文と報告書の損益・SL/TP・環境。
- `shadow_environment_statistics.csv` / `actual_environment_statistics.csv`：母集団を分離した記述統計。
- `monthly_counts.csv`：ゼロ月も含む候補数・実行数。
- `execution_gate_counts.csv`：見送り要因。複数要因は結合して保存し、唯一の原因と断言しない。

## Shadowの限界

同じ候補Ask、丸め済みSL/TPで固定比較。spreadを含むがcommission/swap/margin/注文失敗は再現しない。
最初の到達分にSL/TP両方を触ったものはAMBIGUOUS_M1として成績から除外し、行は残す。
minute内の正確な約定順序は推測しない。バリア未到達は18本時点Bid、終了時不足はEND_CENSORED。
週明けギャップは最初の観測Bidを使う。正のTP超過のみを抑えたRも並記し、巨大な1件への依存を確認する。
Horizon MFE/MAE・到達率は18本全体（先にSL/TP到達した後も含む）。トレード終了までのMFEと混同しない。
元EAの時間決済が市場閉鎖等で失敗するケースはshadowと一致を保証しない。

## 固定比較・標本数

2023-2024 / 2025-2026年9月。両方とも既知期間でありOOSではない。
M15旧baseline、M5短期、M5 2023-2024について観測追加前後のEntry/SL/TP/注文数/損益を完全照合。差があれば停止。
最初に時間足別regime×positionと年別を読む。
共同regime、spreadATRの固定bin（<=.1、<=.2、<=.3、>.3）、サーバー時刻6時間区分を出力。
3軸集計も探索用に保存するが、少標本セル(<30)を明記し、最良セル選択・フィルター採用はしない。
時間はブローカー時計のまま。UTC/JST変換や夏時間推定をしない。
同一相場局面の依存、時間足間の相関、多重比較、生成tick混在を明記する。

## 実行

独立portable MT5内だけで実行。実口座チャート/既存EAへ反映しない。
前バッチは監査停止済みで再開しない。今回の4runへ置き換え、旧証拠は保存する。
コンパイル/静的・単体チェック後に非同期起動し、起動後は待機せずターンを終える。
結果・利益改善は実行完了後に評価する。
