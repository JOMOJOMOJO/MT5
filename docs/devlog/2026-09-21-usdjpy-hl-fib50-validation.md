# USDJPY Higher Low / Fib50 検証完了

新M5安値の確定後のみM1上抜きを採用し、その安値確定時点の最新M5高値を固定するユーザー回答を反映。元インジケーター・ConfirmedPivotは変更せず、共通ロジックを直接使うEAを追加した。

L0/L1/H5/H1の注文根拠を同じ構造IDで描画・保存する。再開時に存在したRR入力は保持し、検証値は1.2。OrderCheckのtrue/0を正常、false/0を失敗と区別し、サーバー期限とEA期限を別々に検証した。

承認された独立MT5で通常と約定後保護の2経路を実行。各7,189判定・23注文・13約定、監査違反0。ネイティブ単体テスト44/44成功、EAコンパイル0/0。実ティック・実保有再起動・フォワードは未検証。

詳しい条件・成立例・制限は [最終QA](../../reports/qa/usdjpy_hl_fib50/README.md)、[監査](../../reports/qa/usdjpy_hl_fib50/audit_summary.json)、[差分](../../reports/qa/usdjpy_hl_fib50/resume_changes.patch) を参照。収益性の結論や次段階への拡張は行わない。
