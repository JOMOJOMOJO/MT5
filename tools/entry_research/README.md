# MT5エントリー候補研究基盤

候補抽出と将来の価格による評価を分離するPython研究基盤。注文は発注しない。最初の対象はUSDJPY M5、2024〜2025年。2026年以降はデータ取得・import・分析時に拒否する。

## 構成

```text
tools/entry_research/
  configs/initial.json       固定条件・期間・seed・コスト
  data.py                   MT5取得 / 既存CSV取込 / 品質・出所監査
  features.py               確定足指標 / 上位足as-of / 約定可能時点の近似
  signals/                  手法ごとの独立detectモジュール
  evaluation.py             H別リターン / MFE・MAE / 到達・先着 / tick検証hook
  baseline.py               時間・曜日・相対vol・方向・件数を合わせた乱数対照
  statistics.py             暦週block bootstrap / H10のHolm補正
  charts.py                 未来のローソク足を埋め込まない4時間足チャート
  cli.py                    再現可能な一括処理 / DuckDB集計 / レポート
  tests/                    手計算、未来不変性、時刻、欠損、統計契約の検証
reports/research/entry_candidates/
  data_20261014/             原本hash・coverage・gaps・4時間足Parquet
  validated_20261014/        検証後の初回実データ分析
  reproduced_20261015/       同一条件での再現確認
```

[調査と設計](../../knowledge/experiments/2026-10-14-entry-candidate-platform-design.md)に既存コードの再利用判断、原本の来歴、検証方針を記録。

## 環境

Windows / Python 3.11.9。既存環境を変更せず専用venvを作成した。元環境にはnumpy2.4.4、pandas3.0.1、scipy1.17.1、MetaTrader5 5.0.5640がある。新規環境なら通常のvenvを作りrequirementsをすべて導入できる。

```powershell
python -m venv --system-site-packages tools/entry_research/.venv
tools/entry_research/.venv/Scripts/python.exe -m pip install -r tools/entry_research/requirements.txt
tools/entry_research/.venv/Scripts/python.exe -m pytest tools/entry_research/tests -q
```

実際の全依存バージョンは各runのmanifest.jsonに記録。新規インストールを完全固定する場合はrequirements-lock.txtを使用する。

2026-10-15時点の[テスト結果](../../reports/research/entry_candidates/qa/tests_20261015.xml)は49件成功。[成果物監査](../../reports/research/entry_candidates/qa/artifact_audit_20261015.json)と[同一条件の再現性照合](../../reports/research/entry_candidates/qa/reproducibility_20261015.json)もPASS。主要CSV8件は同じSHA256、環境別CSVは集計丸め差があるため絶対・相対許容値1e-12で照合した。

```powershell
tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research.verify_run --run reports/research/entry_candidates/validated_20261014 --compare reports/research/entry_candidates/reproduced_20261015 --out reports/research/entry_candidates/qa/my_check.json
```

## 実行

リポジトリのルートで実行。出力先が存在する場合は拒否する。再実行は新しいディレクトリ名を付ける。

```powershell
# 初回: 原本の既存CSVを読み取り、データと分析を新規保存
tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research run --config tools/entry_research/configs/initial.json --out reports/research/entry_candidates/my_run

# ハッシュ確認済みParquetを再利用
tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research run --config tools/entry_research/configs/initial.json --data-dir reports/research/entry_candidates/data_20261014 --out reports/research/entry_candidates/my_repeat

# MT5から別datasetへ取得（現在の端末で履歴が不足すると明示的に失敗）
tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research fetch --terminal 'C:/Program Files/XMTrading MT5/terminal64.exe' --symbol USDJPY --start 2024-01-01 --end 2026-01-01 --out reports/research/entry_candidates/mt5_fresh
```

fetchは月ごとUTC日時で要求し、返却範囲を確認する。端末の履歴制限は`terminal_maxbars`に保存。取得失敗や範囲外応答を既存バーでこっそり補わない。MT5のログイン・再起動・取引・設定変更はしない。収集結果のsymbol/point/clock_basisと一致するconfigを別名で用意して`--data-dir`に渡す。

今回の原本は**Bybit-Live**。現在接続中のXMと混在させない。M5は2024年74,871本、2025年74,585本。M1/M15/H1も保存。CSVには初期化用の前年バーが含まれる。

## 結果の読み方

まず`report.md`、`candidate_counts.csv`、`summary.csv`を見る。`candidate_index.csv`は個別候補への索引。詳細はParquet、条件別集計はDuckDB、外部出力はCSV。

- `signal_time`: 確定足が収集器で観測できた時刻。`nominal_close_time`とは異なる。
- `entry_time`: 観測可能時刻以後の次バー始値時刻。`entry_price`はBid始値の研究用近似で、実際のtick約定を保証しない。名目確定から最大300秒だけ待つ。
- H=1は約定バーの終値。H=10は約定バーを含む10本の終値。MFE/MAEは同じH本。ATRはシグナル時点で凍結。MAEは正の不利幅。
- `eligible`: 主比較用の全50本連続観測条件。将来の利益で選別していないが、閉場・欠損直前のイベントを除くため条件付き母集団である。
- 候補は重複を保持。`same_side_consecutive`、`overlap_50`、`nonoverlap_50`、summaryのH別非重複感度を参照。ポジション数や独立試行数ではない。
- `gross_*`は方向調整したBid価格変化。`net_*`は仮定コスト控除値。初期設定は1.5+0+0.2×2=1.9pips。実測約定コストではない。optional `bar_proxy`も保存bar spreadの近似でありゼロ・欠損は仮定へfallbackする。
- 個別水準の到達時刻は`hit_time_lower/upper`。バー内の順序不明は`ambiguous`。未到達は`neither`、不足は`censored`。TP/SL水準とMFE/MAEはグロス経路であり、出口にコストを加えて再判定した取引成績ではない。
- tickの厳密順序は`resolve_tick_first_touch`へ検証済み完全tick窓を渡す拡張点がある。初回分析にはtickを取得しておらず、hookを実装したことと実tickで検証済みであることを区別する。
- H10の3手法×2方向だけが事前指定検定。全H・全水準・環境スライスの上位を後から採用しない。CIとHolm値は探索研究の根拠であり、独立OOSやMT5実行検証の代わりではない。
- ランダム対照は候補と同じsymbol/year/約定近似時刻のhour/weekday/過去288本に対するATR比区分/方向/件数。各層で復元なし、10反復。反復をサンプル数に足さない。TP/SL詳細比較は第1反復だけ。
- 上位足トレンドは最後に観測済みのEMA20/50関係。`h1_age_seconds/m15_age_seconds`と`*_stale`（2期間を超える経過）を併記する。古い足が最新トレンドを保証するわけではない。
- 地理的sessionは時差不明のためunknown。入力が検証済みUTCなら`clock_basis=utc`でIANA時間帯を使ったsession注釈を生成可能。初回はこの変換を行っていない。

## チャートとDuckDB

`charts/`に各手法・方向の最初の候補を自動生成。結果の良し悪しで選ばない。判定後の価格、約定価格、結果ラベルはチャートのデータに含めない。未来を含む勝敗表との照合は別ファイルで行う。

```powershell
tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research chart --run reports/research/entry_candidates/validated_20261014 --candidate-id 'candidate_index.csvから選んだID' --out reports/research/entry_candidates/example.html
```

DuckDBの`summary`,`environment_summary`,`barrier_rates`,`barrier_comparison`,`touch_rates`,`censor_counts`は実体テーブル。`candidates`,`controls`,`outcomes`等はParquetを参照するview。SQL例：

```sql
SELECT method, side, n_complete, mean_net_pips, delta_net_pips,
       delta_net_pips_ci_low, delta_net_pips_ci_high, p_delta_net_pips_holm
FROM summary WHERE horizon=10 ORDER BY method,side;
```

## 新手法を追加する

`signals/new_method.py`に`detect(df) -> {'LONG': bool Series, 'SHORT': bool Series}`を実装し、`signals/__init__.py`のREGISTRYに登録。`initial.json`を変更せず新configのmethodsへ追加する。指標はfeatures.pyで因果的に計算し、未来を変更しても過去候補が変化しないテストを必ず追加する。フラクタル等は極値時刻ではなく右側確認足が確定した時刻から利用する。共通評価には手法条件を持ち込まない。

残り7手法（三役、MA押し戻り、ダウ、RSI、Bollinger、ATR拡大、Donchian）はPhase 5で未実装。最初の3手法の結果を使って標準値を最適化しない。2026年封印を解除するUIは用意していない。最終評価には別途固定仕様・使用履歴・実行手順が必要。
