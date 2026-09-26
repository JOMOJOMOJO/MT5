# Fib終値エントリーとHL確定後のSL/TP更新

売買用EAを変更せず、`USDJPY_3Wave_FibHLExitResearch` に分離。M1 reversal low〜Wave1 highの50〜61.8%帯で最初に終値が確定した足を使い、次の利用可能tickで買う。Wave1 highの確定時刻以降に始まった足だけを対象にする。

初期SLはreversal low−10ポイント。ユーザーの指定により、同じセットアップのHLがエントリー後に確定するとSLをHL−10ポイントへ一度だけ引き上げ、実約定価格から新SLまでの幅に対してTPを1.2倍へ変更する。元のSLより下がる変更、SLが約定価格以上になる変更は行わない。変更失敗時は既存保護を残す。研究専用で再起動復元は未対応。

M5/M1構造・ピボット・EMA・リスク計算・既存発注処理・クールタイムを保存。比較は同一入口のSL/TP固定版と更新版。評価Rの分母は更新後の狭いSL幅ではなく初期リスクとする。

証拠と結果: [summary](../../reports/qa/three_wave/fib_hl_exit/summary.md)、[固定仕様](../../reports/qa/three_wave/fib_hl_exit/plan.md)、[監査](../../reports/qa/three_wave/fib_hl_exit/audit.json)、[保護ファイルの一致](../../reports/qa/three_wave/fib_hl_exit/protected_after.json)。コンパイル0エラー・0警告、MT5内の計算境界テスト12件成功。売買用への昇格は行わない。
