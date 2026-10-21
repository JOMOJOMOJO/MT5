# 早期SLの診断

旧10条件のSL先着台帳2,666取引から、早期SL752と早期勝696を比較する。元売買ルール・価格・候補は変更しない。2026は不使用。正本は`reports/research/early_loss_20261018/delivery/`。先行validated/final/reviewedは内部検証版として保持。

```powershell
& tools/entry_research/.venv/Scripts/python.exe -m pytest tools/entry_research/early_loss/tests -q
& tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research.early_loss.run --out reports/research/early_loss_NEW/validated
```

既存出力には上書きしない。事前8特徴と事後のquote距離/価格経路を分離。未来H4と未確定シグナル、原ATR不一致を拒否。候補全集合は旧成果物に保持し、本診断は実行された取引だけが対象。独立OOSや元候補からの新戦略再実行ではない。

同条件内の平均差は全条件取引数の固定ウェイト。共通の暦4週移動ブロック、2,000回、seed20261018。区間は未調整の記述用で、8特徴から有意なものを選んで採用する検証ではない。年別は暦年のentry_timeに従う。未来価格を必要とするSL後回復やentry足spreadを事前フィルタに使わない。

[固定計画](../../../knowledge/experiments/2026-10-18-early-loss-plan.md)。成果物は個別データ・件数・特徴・環境・事後価格・区間推定の6表、DuckDB、Markdown、Plotly、入力/ソース/出力SHA。
