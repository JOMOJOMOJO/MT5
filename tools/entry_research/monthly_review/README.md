# PF>1全条件の月次・損失診断

対象は既存会計のPF>1から事後選択した10条件。新シグナル・フィルタ・売買ルールを実装せず、保存台帳を集計する。旧EA/価格/候補/会計/結果を保護し、2026は読み込まない。

```powershell
$python = 'tools/entry_research/.venv/Scripts/python.exe'
& $python -m pytest tools/entry_research/monthly_review/tests -q
& $python -m tools.entry_research.monthly_review.run --out reports/research/monthly_loss_NEW/validated
```

元入力はrun.pyに固定。既存出力先には上書きしない。今回の正本は `reports/research/monthly_loss_20261018/final/`。先行validated/reviewedは内部検証版として保持し、月境界で翌月entry費用を除く汎用修正、および区分除外後の新規約定0/決済0月の区別を加えて正本を再生成した。

## 表の解釈

- `condition_summary`: 10条件×2同足順序。元候補、決済数、PF、月別分布。2順序を独立した取引として数えない。
- `monthly`: 全24月を残す。USDCHFの未取得7月はNaN。`n`は決済件数、`n_entries`は新規約定件数。`no_trade_months`は新規約定0月、`no_closed_trade_months`は決済0月。
- `pnl_usd`: 保存exit_timeに帰属した決済損益。`equity_change_usd`: 月末境界までの保存足終値評価の差。境界の翌月始値・新規約定費用を前月に入れない。価格を補間せず、持越し件数・評価からの経過時間を記録する。
- `loss_classes`: 同足曖昧損失、非曖昧SLの早期1〜2本/3本以上、時間決済損失。事後ラベルなので、将来の損失を見て事前に除外する用途には使えない。
- `context_slices`: 確定時点のH1自身/H4方向・既存ボラ区分・雲位置の4軸。H4 availabilityを検査しunknownも残す。組合せや閾値探索なし。
- `fixed_ledger_monthly_removals`: 該当保存取引を除いた会計差。残る月別決済数と新規約定数、失う勝ち、避ける負けを比較。**元候補から再生したフィルタ付き戦略の結果ではない**。新たに入れる候補、lot、資金推移は変えていない。
- `sample_attention_flag`: n>=100、活動週>=30、両年各30件以上で両年区分損益負という記述用フラグ。統計的有意性・採択条件ではない。全取引を除くような無意味な区分も識別できるよう、残存件数を併記する。
- `candidate_accounting`: 原候補全件の約定/見送り/失効。`duplicate_entry_times`: 同一symbol/side/entry_timeの別ロジック重複。時点をまとめても統計的独立性を意味しない。

費用・価格モデルは元のまま。実swap未反映、commission0仮定、bar spread/現在仕様proxy。損益合算を共通資金ポートフォリオの成績と呼ばない。全表をCSV/Parquet/DuckDB、月次をPlotly HTML、説明をMarkdownで保存。manifestに全入力、新規ソースのSHAとライブラリ版を記録する。

[計画](../../../knowledge/experiments/2026-10-18-monthly-loss-diagnosis-plan.md)。月単位の安定性は黒字月率だけでなく、最悪月、連続赤字月、含み損益、残存件数、勝ちの取りこぼしで判断する。
