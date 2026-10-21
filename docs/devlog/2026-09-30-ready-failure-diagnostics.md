# 通常READYの負け方診断

Entry改善と分離し、EMA OFFの既存139 shadow候補を固定して分析した。売買EA・Shared・Entry・SL・TPは変更していない。

- 勝ち55、SL83、期間末未完了1。SLのうち46件はMFE<0.3R、22件は0.3〜0.8R、15件は0.8〜1.2R。
- 抵抗距離だけでは勝ちと負けを安定して分離できなかった。勝ちでも80%にTP手前の抵抗がある。
- NO_FOLLOWTHROUGHではWave1陽線率の低さ・途中逆行の大きさが両期間で同方向。ただし値幅の小ささ、古さ、効率性は一律の説明にならない。
- 深さ2の診断木は期間をまたぐと単純基準を上回らず、閾値・売買フィルターは採用しない。
- 8候補の未来データ切断・改変テスト、139候補の時刻/価格照合、元の売買値・production hash保持を確認。今回MT5追加実行なし。

根拠: [研究報告](../../reports/qa/three_wave/ready_failure_diagnostics/summary.md)、[QA](../../reports/qa/three_wave/ready_failure_diagnostics/audit.json)、[再実行一致](../../reports/qa/three_wave/ready_failure_diagnostics/analysis_reproducibility.json)。

次の仮説は[研究メモ](../../knowledge/experiments/ready-failure-diagnostics-20260930.md)へ記録した。既知期間・小標本であり、優位性の確立とは扱わない。
