# 汎用化QA：リスク再計算の安全見送りを監査可能にする

## 何が変わったか

r4はMQL初回snapshot修正、21項目のharness、日足終端deal回収、新旧日足/M5 USDJPY一致まで確認できた。しかし監査が `NORMALIZED_VOLUME_EXCEEDS_RISK` を知らず停止した。

売買ロジックを変更せず、監査・再開runnerだけをr5として分離。予算超過の再計算と発注なしを要求し、`OK` の予算超過や未知エラーは引き続き拒否する。
完了済み6本の全ファイルをhash固定してコピー上で再監査し、残り4本だけを新規実行する。

## 検証

- 6本の実データ再監査合格、リスク拒否3件に該当Entryなし。
- 新規単体検査10項目合格：実データ、矛盾する拒否、超過したOK、未知エラー、NaN、改変結果再利用拒否等。既存検査も合わせた28項目が全合格。
- PowerShell構文検査合格。MQLとinputのr4/r5一致、売買EA/Sharedの保護hash一致。
- 今回の新規MT5待ちはユーザーへ返し、完了通知後に残る4本を集計する。

## 判断

安全に拒否されたリスク計画と、実際に発注された超過リスクを区別する。後者を許容する変更はしていない。
volumeを1刻み下げて再評価すれば機会を回復できる可能性はあるが、今回の一致QAに混ぜない。
既知3か月の損益は依然マイナス。利益がある手法に改善したという結論は出さない。

## 証拠

- [r4結果](../../reports/qa/portable_audit_20261009_r4/review.md)
- [r5固定計画](../../reports/qa/portable_audit_20261012_r5/plan.md)
- [USDJPY再監査](../../reports/qa/portable_audit_20261012_r5/preflight/reused_evidence/m5_USDJPY_portable/audit.json)
- [再利用出典](../../reports/qa/portable_audit_20261012_r5/preflight/reused_evidence/reuse_provenance.json)
- [既存の研究停止判断](../../knowledge/experiments/2026-10-08-daily-channel-fixed-baseline-reject.md)
