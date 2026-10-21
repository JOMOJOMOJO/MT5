# 通常READYとCHoCHを混同しない

`HL_ENTRY_READY` の名前だけでEntry定義を固定できない。`InpSkipLowerHL=true` ならCHoCHでREADYになり、falseならWave1・HL・再突破を待つ。M15分類の成績を移す前に、この分岐とSL、pivot、EMA、実行制約を固定する。

今回のソース初期値ベース通常READYは139候補・70約定、平均純損益−0.127R、月5〜12回。前回CHoCHで良かったRANGE_HIGHは負に転じた。DOWN_MID/HIGHは合算正だが6件・5件に過ぎず期間別で逆転する。環境フィルター採用の根拠としない。

研究の仮想約定価格Rと実売買純損益Rは区別する。テスターのOnDeinit後の終了決済はEA CSVから欠け得るため、終了ログ・残高に照合して未記録を見逃さない。MFE/MAEを24時間経路で観測した場合は、実利確後を含むことを明記する。

[固定仕様と実証](../../reports/qa/three_wave/m15_normal_ready/summary.md)
