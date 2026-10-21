# MT5 Phase 3 複数通貨研究

既存プラットフォームを変更せず追加した研究用パッケージ。EA、発注プログラム、実ティック収益性検証ではない。対象・閾値は [config.json](config.json) で固定し、[事前計画](../../../knowledge/experiments/2026-10-16-multiasset-research-plan.md) に仮説と昇格基準を記録する。

## 構成

```text
tools/entry_research/multiasset/
  config.json                 期間・216セル・コスト・統計基準
  prepare_terminal.ps1         新規研究端末だけを作成（既存端末は変更しない）
  data.py                     月次MT5取得・期間ガード・品質とSHA256
  strategies.py               確定足指標・上位足asof・候補台帳
  signals/                    Donchian / Bollinger / ATR収縮
  inference.py                2対照・共通週bootstrap・Holm・WF
  execution.py                1ATR SL/TP・H10・lot/換算・重複・曖昧順序
  run.py                      保存・集計・DuckDB・実行manifest
  report.py                   Markdown・Plotly HTML
  verify.py                   独立再計算と保護ファイル監査
  tests/                      合成データQA
reports/research/multiasset_20261016/
  data/                       通貨/時間足Parquet、coverage/gaps、manifest
  pilot/                      初期QAの計算結果（保存処理の不具合を記録）
  full/                       高速化前の部分計算（保存）
  full_validated/             全通貨・時間足の固定研究・最終正本
  qa/                         テスト・MT5 arithmetic parity
```

旧3手法は `../signals` をそのままimport。ATRと指標は `../features.py`、イベント計算は `../evaluation.py` を再利用。複数通貨の口座管理は別実装。将来、新手法は `detect(features)->{'LONG': boolSeries,'SHORT': boolSeries}` として追加し、研究開始前に全比較数・パラメータを固定する。結果を見てconfigを上書きせず、新しい研究IDと出力先を使う。

## 実行

リポジトリルートでPowerShell。既存の専用Python環境を利用し、グローバルライブラリを変更しない。依存の実バージョンは各runのmanifestに保存。

```powershell
$python = 'tools/entry_research/.venv/Scripts/python.exe'
$env:OPENBLAS_NUM_THREADS = '1'
$env:OMP_NUM_THREADS = '1'
& $python -m pytest tools/entry_research/multiasset/tests -q
# 保存済みデータを使う。再実行は必ず新しい出力先を指定する。
& $python -m tools.entry_research.multiasset.run --out reports/research/multiasset_20261016/pilot_new --pilot
& $python -m tools.entry_research.multiasset.verify reports/research/multiasset_20261016/pilot_new
& $python -m tools.entry_research.multiasset.run --out reports/research/multiasset_20261016/full_new
& $python -m tools.entry_research.multiasset.verify reports/research/multiasset_20261016/full_new
```

新規データ取得（通常の再分析には不要）:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/entry_research/multiasset/prepare_terminal.ps1 -Destination "$env:LOCALAPPDATA/CodexMT5Multiasset_NEW"
& $python -m tools.entry_research.multiasset.data --terminal "$env:LOCALAPPDATA/CodexMT5Multiasset_NEW/terminal64.exe" --out reports/research/multiasset_NEW/data
```

研究専用端末に既存端末のキャッシュ済み接続設定だけを機械内コピーする。EA・チャートprofileはコピーせず、AlgoTrading無効。接続先・口座番号や認証情報はレポートに出さない。接続できなければ取得不能を報告し、自動で口座を作成・変更しない。終了時はその研究端末の実行パスを確認して閉じる。通常端末を一括停止しない。

取得が途中停止した場合だけ同じconfigで `--resume` を指定可能。既存の各Parquetはhash確認してスキップし、異なるbrokerへの再開を拒否する。完成済みデータへの設定変更はしない。終端は2026-01-01排他的、要求も受領データもガードする。H4を含む5時間足に対応。時刻が未検証なら地域セッション戦略は保留する。

## 結果の読み方

- `primary.csv`: H10ネットATR、両対照差、週CI、648仮説Holm、年別、件数・重複、探索仮説ゲート。
- `summary.csv`: 全候補数と観測可能件数、H1/3/5/10/20/50のgross/net、MFE/MAE。年/月/環境/WFは各CSV。
- セル別 `outcomes.parquet`: 候補ごとの観測不能理由も保持。対照drawsに原候補ID、全10反復、抽出条件を記録。
- `accounts.csv` とセル別 `execution_*`: PF、R、DDはこの台帳の売買ルールだけに定義。各通貨/手法/方向は独立USD口座であり、合算可能なポートフォリオではない。
- 欠損中の建玉が解決できない口座は `censored_account_path`。そのPF/DD/残高を2年分の成績として解釈しない。後続候補を消さず `skipped_account_censored` とする。週末の取引カレンダー未確認もこの制約に含む。
- 正値bar spreadは履歴proxy、不明時は仮定。実spread・swap・commission・slippageを取得できるまで実費控除後の利益とは呼ばない。同足TP/SL順序は未知。
- 2024–25は探索済み。WFは開発内の頑健性確認。未知データでの再現性を保証しない。2026は本研究では使用しない。

DuckDB例（識別子 `primary` は予約語のため引用）:

```sql
SELECT symbol,timeframe,method,side,n,net_atr,net_ci_low,exploratory_hypothesis_pass
FROM "primary" ORDER BY symbol,timeframe,method,side;
SELECT symbol,timeframe,condition,value,n,weeks,mean_net_atr FROM environment;
```

`dashboard.html` はPlotlyを内包してオフライン表示できる。データ配信・外部ホスティングは不要。

## 今回の成果物・表示監査

正本は [full_validated/index.html](../../../reports/research/multiasset_20261016/full_validated/index.html)。[最終レビュー](../../../reports/research/multiasset_20261016/full_validated/review.md) に結論・制約・QAを集約した。216条件、原候補336,109件、H=10ネットATR正25条件、事前ゲート通過0条件。2026データは使用していない。

追加の表示監査プログラムは原分析表・p値・採択基準を変更しない。同じH=10観測母集団による先着率、2対照のMFE/MAEとリターン、標本不足と不採択理由、検索できる入口HTMLを生成し、SHA256を保存する。

```powershell
& $python reports/research/multiasset_20261016/qa/finalize_reporting.py --run reports/research/multiasset_20261016/full_new
```

`barrier_rates.csv` は各状態の件数・母数・反復数を併記。`baseline_metrics.csv` は反復ごとの平均を平均し、対照10反復を独立標本として扱わない。`evidence_status.csv` の標本不足行のCI/p値は参考記述に留める。元の `barrier_counts.csv` の件数を戦略と対照で直接比較しない。

`index.html` は `review.md` へのリンクを持つが、研究の判断文は自動で捏造せず今回のレビューとして別途作成した。新runでは結果を確認してレビューを書く。DuckDBに追加する3表の内容は補足CSV/Parquetと同じである。
