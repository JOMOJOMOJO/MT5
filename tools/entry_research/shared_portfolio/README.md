# 固定4ルールの共有口座評価

既存の4ルールを変更せず、確定候補から共通資金・同時建玉を再生します。
単純に4口座の保存取引を合算する実装ではありません。各候補の入口時点の共通equityで数量を決めます。

```powershell
& tools/entry_research/.venv/Scripts/python.exe -m pytest tools/entry_research/shared_portfolio/tests -q
& tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research.shared_portfolio.run --out reports/research/shared_portfolio_20261019/new_run
```

既存出力への上書きを拒否します。2026価格を検出すると停止します。元データ・EA・凍結研究コードは変更しません。
Python環境は既存entry_researchのvenvを使い、追加インストールは不要です。

## 構成

- `path.py`：凍結account_replayを1候補ずつ再利用。必要な価格範囲だけを渡し、元インデックスと結果を復元。
- `engine.py`：時系列の共有equity、ルール重複、同時注文、予定リスク、仮定margin、通貨exposure。
- `analysis.py`：月次MTM・年次・観測DD・足内包絡DD・暦4週bootstrap。
- `reference.py`：同じ開始日時点で各独立口座をリセットした比較対象。
- `run.py`：固定16profileを全て実行し、CSV/Parquet/DuckDB/manifestを保存。
- `report.py`：全条件Markdownと自己完結Plotly HTML。
- `config.json`：資金とリスク制限。ルール順は前回提示4条件の順に固定。

## 仕様

初期40,000USD、各ルール均等25%のリスク配分。各配分の0.1%=口座equity0.025%/取引。
当初10USD。lot切下げ、1ルール1建玉、最大4建玉。
予定初期SL損失合計0.1%、同一symbol0.05%を新規受付時に検査。ギャップ損失保証の上限ではありません。
日次3%減少・観測peak5%減少で新規停止。既存建玉はSL/TP/時間出口を維持します。

主評価はhedging仮定。感度のblock_oppositeは反対注文を見送る方式で、MT5 netting再現ではありません。
marginは1:30・両建て減免なしの仮定。未検証の歴史的broker仕様を確定値として扱いません。
全4条件がUSDに関係するため、symbol別と別に通貨ごとのUSD換算exposureを保存します。

前足内決済→当足始値gap決済→始値評価→固定順新規を処理します。
単一候補経路は未来の結果を返しますが、受付に使うのは入口geometry・費用・riskだけです。
未来markは時刻到達後にしか反映しません。平日の保有通貨の現在始値が欠けた場合は口座を止め、
古い評価で新規を続けません。週末は既存のsource-clock暦仮定を継承します。

主期間2024-08-01 08:00 source〜2025年末、別参考2024年1月開始。
参考期間のUSDCHF未取得時は当該配分を他へ移しません。8月も最初8時間未取得と指標準備を含みます。
2期間×2mode×2cost×2同足順序=16profile。基準片道0.2pip、stress0.7pip。
いずれもSL/TP各1ATR、10実足、元の暦新規休止・候補フィルターを維持します。

月次はMTM。月初時刻のbar_closeは前月、gap_open/pre_entry/post_entryは新月です。
主DDは観測評価（始値・新規・決済・足終値）に基づき、実tickの最悪DDではありません。
各保有通貨の足内最悪値合算は同時発生を確認できない包絡DDとして分離します。

## 限界

4条件は過去結果から選択済み。2024–25は探索再利用、2026は使わず、独立OOSではありません。
bar spread proxy、仮定slippage、commission0、swap未知、価格時計/歴史的仕様/実口座mode未検証。
未完走時は全期間月次を作らずprefixのみ。口座停止後の未来決済結果を台帳へ確定値として残しません。
配分・期間・閾値を結果に合わせて最適化しません。Python研究結果をMT5実tickの実運用証拠とは扱いません。
