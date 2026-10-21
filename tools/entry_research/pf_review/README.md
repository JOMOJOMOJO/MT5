# PF>1口座の追加監査

保存済み口座の値を再集計するツール。シグナル・売買ルール・元台帳・元価格を変更しない。対象は事後選択されたUSDJPY H1 ATR収縮ブレイクLONG/SHORT。独立OOSや運用採択を意味しない。

## 実行

リポジトリルート、既存venvを使用する。

```powershell
$python = 'tools/entry_research/.venv/Scripts/python.exe'
$env:OPENBLAS_NUM_THREADS = '1'
$env:OMP_NUM_THREADS = '1'
& $python -m pytest tools/entry_research/pf_review/tests -q
& $python -m tools.entry_research.pf_review.run --out reports/research/positive_pf_NEW/validated
```

出力先が既にある場合はエラー。入力の正本は `run.py` のSOURCE/DATA/PREVIOUS定数。価格manifestと元会計コードのSHAを照合し、全入力が実行前後で不変であることを確認する。新コードSHA、Git HEAD、ライブラリ版、seed、選択経緯をmanifestに保存。Git HEADだけを新規未コミットコードの識別子にはしない。

## 出力

- `summary`、`annual`、`monthly`、`event_accounting`: 元候補全数と実約定数、年/月の損益・PF・R。
- `bootstrap`: 無取引を含む105週、循環1/4/8週ブロック、20,000回、seed=20261017。主は4週。PF・平均RのCIは未補正。片側中心化pは近似、432口座のBonferroniも探索的参考値。
- `cost_sensitivity`、`break_even`: 保存取引とlotへの追加往復pips/手数料負担。到達順序・lot・実swapは再計算しない。
- `intrabar`: 元のH1同足曖昧5件を、エントリー以降の連続M1とH1のOHLC一致を確認して分解。LONGはBid、SHORTはH1固定spreadおよびM1別spreadのAsk proxy。ティック順序や実約定の確定ではない。
- `concentration`: 最高利益月・上位3/5勝の事後除外感度。新戦略や外れ値認定ではない。
- `positive_inventory`、`scenario_pairs`: PF>1だった全12シナリオと対となる不利順序。二つの順序を独立の戦略標本と数えない。
- `previous_event_statistics`: 既存Stage1の固定H10イベント評価。口座PFと混同しない。
- 各表はCSV/Parquet、まとめた `review.duckdb`、Markdownレポート、オフラインPlotly HTML。

CSVの `pnl_usd` は既存spread/slip/手数料仮定控除後・実swap前。実費込みの `all_in_net_pnl_usd` は欠測。追加コスト計算も実売買シミュレーションとは区別する。

今回の正本は `reports/research/positive_pf_20261017/reviewed/`。先行 `validated/` と `final/` は集計値を変更しない表示ラベル・相対リンク修正前の出力として保存した。計画は [固定手順](../../../knowledge/experiments/2026-10-17-positive-pf-followup-plan.md)。2026は不使用。旧Stage1/2ゲートを変更しない。
