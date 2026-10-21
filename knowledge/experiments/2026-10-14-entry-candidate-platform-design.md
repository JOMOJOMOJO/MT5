# エントリー候補研究基盤：Phase 1 調査と固定設計

目的はエントリーイベントの比較であり、注文・資金曲線・EA採用の判定ではない。Phase 2〜4を3手法で実施し、残り7手法はQA後のPhase 5として追加する。既存EA、設定、レポートは変更しない。

## 既存資産と採否

- [既存探索コード](../../plugins/mt5-company/scripts/statistical_edge_research.py)：MT5接続の参考。直近N本、同一終値でのエントリー、spread×0.01、選定にtestを使用する評価部分は今回再利用しない。
- [バー収集器](../../mql/Experts/USDJPY_Ready2024MLCollector.mq5)：確定足だけをCSVへ保存。`available_at` は収集器が観測できた時刻で、バー始値時刻とは異なる。
- [2024年原本](../../reports/qa/three_wave/ready_2024_ml/annual_2024/)、[2025年原本](../../reports/qa/three_wave/ready_multiyear_ml/annual_2025/)：USDJPY、Bybit-Live、Model 4から保存されたM1/M5/M15/H1。各年12か月あり、各ファイルには前年のウォームアップも含む。原本hashを保存する。
- 原本間の重複OHLCは一致するがspreadは一部異なる。2024年までを2024収集、2025年を2025収集から採用し、後年の再取得で過去を上書きしない。
- 2024年の実tick開始は6月6日、2025年にもtick警告が存在する。バーOHLC研究として利用し、実tick順序や実約定を証明したとは扱わない。
- [時刻・対象年を照合する教訓](../lessons/2026-10-13-history-fingerprint-must-cover-test-period.md)、[既知OOSの再利用履歴](2026-10-05-edge-first-multicurrency-candidate-review.md)を適用。
- 現在のXM MT5接続は成功したが、maxbars=100000。2024〜2025一括M5取得は失敗し、2025年1月要求で範囲外の6月の1本が返った。取得成功フラグだけで採用せず、要求期間・返却期間を検証する。XMとBybitの履歴は混ぜない。

## 時刻と因果性

- バーはsource clockの整数秒で保存。`time`（始値）、`close_time`（名目確定）、`source_available_at`（収集時刻）、`available_time=max(close_time,source_available_at)` を保持。
- シグナルは確定足だけで計算。`signal_time=available_time`。`entry_time` はその時刻以後の次のバー始値、最大待ち時間は名目確定から300秒。始値は約定の近似であり、実tick約定時刻ではない。足途中に観測できたケースでは過去の始値を使わず、次のM5境界まで待つ。
- 上位足は `available_time <= signal_time` でas-of結合し、経過秒も保存。チャートにも同じ条件を適用。
- 雲は9/26/52・26本正方向シフト済みの表示位置。遅行スパンの未来シフトは使わない。基準線反発は前足で確定した基準線への接触と同方向実体・回復。MAはEMA20/50。
- 2026年以降を開発ランナーで拒否。2026年は本基盤で封印するが、過去研究も含めた完全未使用年とは呼ばない。
- 原本のサーバー/UTC対応未確認。地理的sessionはunknown、条件比較はsource hour/weekdayで行う。対応が確認できたUTC入力にはDST対応session表示を提供。

## 評価・統計

- H=1/3/5/10/20/50 は約定バーからH本、出口は最後の確定終値。リターン、MFE、MAEは同一区間、ATRはシグナル時点のWilder14で固定。
- 欠損・終了端はcensorし価格を補完しない。主比較は全50本が連続観測できる共通母集団。除外前の全候補と各Hのcensorも保存し、週末・欠損直前が主比較に入らない偏りを明記。
- ±0.25/0.5/0.75/1/1.5 ATR、全25 TP/SL組合せ。OHLC同足両到達はambiguous、到達時刻は区間。バー始値ですでに水準を越えている場合のみ既知の先着として扱う。
- 主コストは仮定：spread 1.5pips、往復commission 0、slippage片道0.2pips（合計1.9pips）。価格予測・最適化値ではない。生のbar spreadも保存し、2025のゼロspreadを実コストゼロとは解釈しない。
- ベースラインはsymbol/year/source-hour/weekday/過去ATRに対する相対vol/方向/件数を一致、各層内復元なし、10固定seed反復。候補バーも母集団に含む。反復を独立サンプル数として水増ししない。到達順序の詳細比較は事前固定の第1反復。
- カレンダー週block bootstrapでnet平均と対照との差の95%CI。主要検定はH10の3手法×2方向、Holm補正。他期間・25水準組合せ・環境別は記述的探索。n<100または週<20を薄いサンプルと表示。
- 重複候補を消さず連続発生・50本重複・非重複感度を出力。EAの取引回数や独立試行数とは呼ばない。

## 構成

`tools/entry_research/` に data / features / signals / evaluation / baseline / statistics / charts / CLI / tests を独立実装。`reports/research/entry_candidates/` にデータ、候補、評価Parquet・DuckDB・CSV・Markdown・チャート・config・依存version・code/source hashesを保存。旧ロジックの改修やMLは行わない。

仕様参照：[MT5バーAPI](https://www.mql5.com/en/docs/python_metatrader5/mt5copyratesrange_py)、[tick API](https://www.mql5.com/en/docs/python_metatrader5/mt5copyticksrange_py)、[一目buffer仕様](https://www.mql5.com/en/docs/indicators/iichimoku)。CSVのサーバー時刻にAPIのUTC仕様をそのまま適用しない。
