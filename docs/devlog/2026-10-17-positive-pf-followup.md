# PFが1を超えた候補の追加検証

2026-10-17。ユーザーのPF>1への着目と継続指示を受け、[会計再評価](2026-10-17-account-replay-repair.md)でSL先着でも正だったUSDJPY H1 ATR収縮ブレイク2方向を固定ルールで確認した。

新規 `tools/entry_research/pf_review/` に保存台帳の年/月別、週ブロックCI、追加費用感度、利益集中感度、M1の同足順序照合、CSV/Parquet/DuckDB/Markdown/Plotly出力を実装。シグナル・lot・約定・元会計コードは変更しない。

SHORTは両年プラス、LONGは2024がマイナス。双方の主95%平均R区間は0をまたぐ。SHORTを次の固定検証仮説として残すが、Stage1/2基準を緩めず昇格しない。実swap/Ask/tickと独立期間は未検証。根拠は[検証判断](../../knowledge/experiments/2026-10-17-positive-pf-followup-review.md)と[最終レポート](../../reports/research/positive_pf_20261017/reviewed/report.md)。

新規15テスト合格、CI8値と費用ゼロ点4値を独立検算、13表の件数・表示修正間の数値同一性を確認。入力/元コード/新コード/出力SHAを検証。ブラウザーで4図と注記・表を目視確認。[QA](../../reports/research/positive_pf_20261017/qa/delivery.json)

既存EA・研究成果は保護し、新規出力は `reports/research/positive_pf_20261017/` のみに保存。初回表示修正前の2出力も残し、正本は `reviewed/` と明記。新規commit/push・外部公開は行っていない。
