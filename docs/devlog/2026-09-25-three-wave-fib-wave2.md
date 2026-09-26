# 2026-09-25: Fib Wave2 Entryを研究用EAへ分離

通常READYのHL確定・再上抜け待ちを置き換える比較用トリガーを作成。M1 Wave1高値確定後の38.2〜61.8%押しにBidが初到達した次tickのAskで発注し、SLだけreversal low基準へ変更する。通常EA/Shared/注文共通部は保護した。EMAフィルターはONを維持。

[仕様・QA・プリセット](../../reports/qa/three_wave/fib_wave2/summary.md)、[差分](../../reports/qa/three_wave/fib_wave2/entry_adapter.diff)、[監査](../../reports/qa/three_wave/fib_wave2/audit.json)。コンパイルエラー0警告0、ネイティブtick判定12件成功。1月READY12注文は元EAと全シグナル・約定一致。Fib15注文について次tick、SL、リスク、クールタイムを確認。

[実験記録](../../knowledge/experiments/2026-09-25-three-wave-fib-wave2.md)。頻度目標は未達。収益性や採用可否は判定していない。再利用できる検証上の注意点を[seed](../../content/seeds/2026-09-25-confirmation-time-before-fib-entry.md)に保存。
