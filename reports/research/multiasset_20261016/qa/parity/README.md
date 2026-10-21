# Python / MQL5 合成fixture照合

これは固定した数値の計算照合であり、売買手法のMT5バックテストや実約定の証明ではない。最新状態は [parity_summary.json](parity_summary.json) を参照する。

検証対象は、価格のtick単位丸め、最小ロット超過時の見送り、0.1%の予定リスクに収まるロット切り下げ、LONG/SHORTのスプレッド・スリッページ込み損益、ギャップ始値でのストップ決済、同一足TP/SLの曖昧フラグ、USDJPY/USDCHF/USDCADの同時点価格によるUSD換算の20項目。Python側は `simulate()` の合成データ出力を直接使う。

- [compile.log](compile.log): MetaEditorのエラー・警告0件の記録。
- [python_fixture.csv](python_fixture.csv): Python計算と手計算期待値。
- `fixture_*.csv`: MT5テスターが生成した20項目の結果。未生成なら照合未完了。
- `comparison.csv`: PythonとMQL5の差。許容絶対差は1e-8。
- `journal_*.txt`: テスターのfixture判定行。口座情報は保存しない。

隔離した `CodexMT5Multiasset20261016` 端末のみを使う。`run_parity.ps1 -Stage Compile` は専用MetaEditorを起動し、`-Stage Run` は専用端末だけにEX5を配置して同じ専用端末だけを再起動する。`-Stage Collect` でfixtureとそのログ、テスターレポートをこのフォルダーへ収集し、研究用venvから `verify_parity.py` を実行する。既存の `compile.ps1` は複数端末へEX5を同期し、`backtest.ps1` は既存設定を扱うため、この隔離照合では使用しない。

MQL5 harnessはテスター外では初期化を拒否し、注文APIを呼ばない。テスターの搬送期間は2024-01-03〜04、計算対象は固定した合成値であり、2026年の価格は使用しない。OHLC内の価格順序、実際のスプレッド・スリッページ、過去の契約仕様、証拠金、スワップ、複利口座全体のMT5一致はこの照合の対象外である。MT5レポートの取引件数0は想定どおりであり、収益性の結果として扱わない。
