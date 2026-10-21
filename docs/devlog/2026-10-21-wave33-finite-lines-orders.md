# 3波3波 v1.20：古い水平線の終了と注文ON設定

ユーザーは水平破線が右へ伸び続けて増える点を指摘し、過去データで実際に売買できるバックテストも希望した。描画モジュールの水平線・転換斜線を有限線へ変更し、候補の終了と実ポジションの終了を別に扱った。元の山谷・W1/W2・ENTRY・失効履歴は保持する。

判定線とFib帯はシグナル／候補終了まで、発注したSL/TPはEXIT／テスト終了まで。診断だけのSL/TPは短線とする。実行レビューで、約定後にキューへ積まれたPOSITION_TRACKINGがEXITより後に届き、決済済みの線を再開する経路を発見した。延長開始をORDER/FILLに限定し、その順序を含む表示ハーネス19項目を追加して19/19 PASSを確認した。入力や取引判断は追加していない。

既存の注文機能はテスター内だけ発注する設計だったため、実行ロジックを変えず、A/Bの注文ON専用SET・ビジュアルINI・[MT5操作ガイド](../validation/wave33-tester-orders.md)を追加した。SETは現在の端末のMQL5/Profiles/Testerにも新規配置した。汎用backtest.ps1の自動プリセットコピーには依存しない手順とし、既存共有スクリプトは変更していない。

更新EAをネイティブMT5の固定XAUUSD区間で実行し、Aは4約定／4決済、Bは24約定／24決済（LONG 15 / SHORT 9）を確認。EA・描画ハーネス・描画補助EAは0 errors / 0 warnings。Engine・Types・Ledger・参照インジケーターは不変。A診断の全イベントCSVは初版と一致し、遅配対策前後のA/B注文イベントも一致する。表示4例の391線すべてに無限の左右延長がない。

証拠は [今回のレポート](../../reports/qa/wave33_visual_20261020/finite_lines_orders/README.md)、[最終ネイティブ実行](../../reports/qa/wave33_visual_20261020/20261020_235907_9a0d8776/review.md)、[不変監査](../../reports/qa/wave33_visual_20261020/finite_lines_orders/audit.json)を参照。注文検証は実テスター、画像は通常チャートでの記録イベント再生と区別する。表示の寿命に関する再利用知見は [既存seed](../../content/seeds/2026-10-20-wave33-known-time-before-profit.md)へ追記した。成績最適化は行っていない。
