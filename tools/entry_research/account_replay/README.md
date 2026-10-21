# 休場処理を修正した口座再評価

旧 `multiasset/` のコード・データ・結果を保持し、保存済み全原候補を再生する別バージョン。シグナル再抽出やパラメータ最適化は行わない。2026年の価格を拒否する。

## 処理

- `calendar.py`: source clockの土曜00:00〜月曜00:00の正確な48時間空白を、明示的な週末proxyとして分類。それ以外の空白はunknown。祝日表の履歴がないためクリスマス/元日も自動承認しない。
- `execution.py`: 隣接足の休場確認、取引可能な実足10本の保有、再開始値のSL/TP判定。元の固定リスク・コスト・重複規則を維持。外から偽の休場注釈を渡しても、時刻と固定policyから再検証する。
- `audit.py`: 空白の全件一覧とM1による照合。価格補完はしない。
- `run.py`: 元候補・旧runをSHAで保護し、全432会計シナリオを新規ディレクトリへ保存。CSV/Parquet/DuckDBとソース・入力manifest。
- `verify.py`: 全母数・全決済の休場経路・元の既決済取引の一致・損益独立式・保護SHA。
- `report.py`: 観測打切り数を先に示すMarkdownとオフラインPlotly。

## 実行手順

リポジトリルート、既存venvで実行。出力先は毎回新しいディレクトリを指定する。実行中は新規パッケージのPythonソースを変更しない。

```powershell
$python = 'tools/entry_research/.venv/Scripts/python.exe'
$env:OPENBLAS_NUM_THREADS = '1'
$env:OMP_NUM_THREADS = '1'
& $python -m pytest tools/entry_research/multiasset/tests tools/entry_research/account_replay/tests -q
& $python -m tools.entry_research.account_replay.audit --data reports/research/multiasset_20261016/data --out reports/research/account_replay_NEW/qa
& $python -m tools.entry_research.account_replay.run --source reports/research/multiasset_20261016/full_validated --out reports/research/account_replay_NEW/weekend_repaired
& $python -m tools.entry_research.account_replay.verify reports/research/account_replay_NEW/weekend_repaired
& $python -m tools.entry_research.account_replay.report reports/research/account_replay_NEW/weekend_repaired
```

`verify` は旧全runと30価格ファイルのSHAを確認するため、読み込み時間が必要。各口座の原候補全件を残し、未来の観測完全性でエントリー前に除外しない。

## 結果の単位と制約

`net_pnl_usd` は旧値との互換列であり、`net_pnl_before_unknown_swap_usd` と同じ未知swap控除前損益。spread/slippage/仮定commissionを含む。全費用込みの `all_in_net_pnl_usd`、実swapの `swap_cost_usd` は欠測。lot日曝露はsource時計の日境界を数えた参考量で、broker rollover・三倍swap日数を表していない。

`account_path_complete` は建玉に未解決の空白がなかったという意味。USDCHFの17か月を24か月扱いにはせず、`requested_period_available` と `data_months` を別表示する。未決済が不明な口座は後続計算を止め、PF/DDを通年成績とは呼ばない。旧より観測期間が伸びた場合の損益増減を、同一期間の収益性改善と解釈しない。

2つの同足順序は別の会計シナリオであり、統計的に独立した戦略ではない。個別口座の合算はポートフォリオ評価ではない。全シナリオでライブ昇格不可。

今回の [固定計画](../../../knowledge/experiments/2026-10-17-account-replay-plan.md)、[価格空白監査](../../../reports/research/account_replay_20261017/qa/calendar_sources.md) を参照。追加のMT5再取得検査は `reports/research/account_replay_20261017/qa/probe_missing.py`。研究専用端末に対して対象の過去区間だけを読み取り、元ファイルを上書きしない。

今回の最終出力先は `reports/research/account_replay_20261017/validated/`。先行する `weekend_repaired/` は性能診断のため途中停止した出力として保存し、完了結果には使わない。PandasのArrow文字列への逐次代入を配列一括代入に変更し、USDJPY M5の167,889行がdtypeを含め完全一致することを確認した。判定式・乱数・戦略条件の変更ではない。根拠は [calendar_optimization.json](../../../reports/research/account_replay_20261017/qa/calendar_optimization.json)。

最終レビュー用の表示処理は、期間末の未決済を不明ギャップとは別に分類し、最後の未実現評価額を別表へ出す。強制決済や損益再計算は行わない。検算後に以下を実行する。

```powershell
& $python -m reports.research.account_replay_20261017.qa.finalize_report reports/research/account_replay_20261017/validated
```

[修正結果レポート](../../../reports/research/account_replay_20261017/validated/report.md) / [比較ダッシュボード](../../../reports/research/account_replay_20261017/validated/dashboard.html)。結果は観測打切りなし48→352、打切り384→80（平日等の不明空白30、休場表未確認の祝日30、期間末未決済20）。53テスト合格、4,320損益の独立再計算、旧既決済161,083件の一致を確認。通年の実費込み利益が検証できたという意味ではない。
