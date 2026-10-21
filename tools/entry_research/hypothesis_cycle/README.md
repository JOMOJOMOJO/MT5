# 応用ブレイク・RSI2押し目の固定研究比較

2026-10-19の研究依頼に対する、結果確認前に固定した2仮説19条件の実装です。
EA運用や独立OOSの証明ではありません。2024–25は探索済みで、2026価格は読み込み禁止です。

## 実行

リポジトリ直下で既存研究venvを使います。追加ライブラリのインストールは不要です。

```powershell
& tools/entry_research/.venv/Scripts/python.exe -m pytest tools/entry_research/hypothesis_cycle/tests -q
& tools/entry_research/.venv/Scripts/python.exe -m tools.entry_research.hypothesis_cycle.run --out reports/research/hypothesis_cycle_20261019/new_run
```

保存先が存在する場合は実行を拒否します。再実行は新しいディレクトリを指定してください。
乱数seed、19条件、閾値は固定です。同じ入力で口座台帳・CSV・Parquetの内容を再現できます。
DuckDB内部のバイナリ一致は保証対象ではありません。

## ファイルと入力

- `entries.py`：確定足のブレイク幅フィルター、Wilder RSI2とEMA200反転候補。
- `stats.py`：暦休止、共通週ブロック区間、対応差、Holm、月次継続ゲート。
- `run.py`：凍結評価エンジンを使う再生、候補母集団記録、費用感度、対照、再現性。
- `report.py`：全条件のMarkdownとオフラインPlotly HTML。
- `config.json`：今回の固定条件と業務上の研究継続ゲート。
- `tests/`：時刻、未来情報、RSI初期値、分母、対応比較、ゲートの境界検証。

入力は`reports/research/multiasset_20261016/data/`のH1/H4と、同研究`full_validated/`の元候補。
`reports/research/account_replay_20261017/validated/manifest.json`の設定と凍結実装SHAを照合します。
実行エンジン`../account_replay/execution.py`は変更していません。
設計記録：`knowledge/experiments/2026-10-19-hypothesis-cycle-plan.md`。

## 条件と出口

AはUSDJPY Donchian/ATR両方向、USDCHF Donchian/ATR SHORT、AUDUSD雲SHORTの7条件。
元のブレイク境界から確定終値が0.25ATR以上離れた候補だけ採用します。原候補は全件保存します。
原ルール7対照も同じ暦規則・費用で再生します。見送った勝ちや新たに入る取引も記録します。

Bは6通貨H1両方向12条件。LONGは終値>EMA200かつ前RSI2<=5<当RSI2。
SHORTは終値<EMA200かつ前RSI2>=95>当RSI2。EMAは最低200本、RSIはWilder種平均です。
未約定・失効候補は候補の分母から削除しません。

出口はTP/SL各1ATR、最大10実足。独立USD10,000口座、1回目標risk0.1%、lot切下げ、重複ポジション禁止。
SL先着を主評価、TP先着は感度。どちらも全世界の厳密な上下損益境界という意味ではありません。
未知欠損中の未決済は口座を打ち切り、都合のよい決済や再開を作りません。

全比較の新規休止はsource暦12月24日〜1月2日。信号確定日と、約定時に知り得る入口日で判定します。
これは事前に固定した新しい共通運用条件であり、旧結果の完全再現ではありません。
全19条件は休止なしも再生し、打切りをそのまま報告します。

## 統計と継続判定

月次は月末含み損益込みで計算し、全期間現金損益と照合します。無取引月は含め、USDCHF未取得月は欠測です。
暦4週の循環ブロック5,000回で取引R平均を評価します。Aは同じ週を引き、元候補当たりの合計R差を比較します。
19仮説をHolm補正しますが、過去の探索全部を補正したものではありません。

正の総損益/PF>1/両年正、月次・頻度、追加往復1pipで正という最初の3ゲートを全て通過した場合だけ、
同じ口座エンジンでランダム対照各5seedを追加実行します。月を一致させた無条件対照と、
さらにhour/weekday/volを一致させた対照を分けます。将来の観測完備性で抽出しません。
対象0なら停止判定を記録し、未完成と区別します。閾値は結果を見て緩和しません。

## 出力と限界

全条件、月次、年次、原候補の処理、対応比較、対照をCSV/Parquet/DuckDBに保存します。
`accounts/`には約定・イベント・equity、`candidates/`には除外を含む候補、`manifest.json`には入力/コードSHAと依存版があります。
`report.md`が結果、`dashboard.html`はブラウザーで開けるオフライン図です。

spreadはbar proxy、片道slippageは0.2pip仮定、commissionは0仮定、swapは未知です。
stressは片道0.7pip。実測総費用ではありません。価格時計、歴史的仕様、margin、実tick約定は未検証です。
独立口座を足してポートフォリオ成績とはしません。研究目標の合格もライブ昇格を意味しません。
