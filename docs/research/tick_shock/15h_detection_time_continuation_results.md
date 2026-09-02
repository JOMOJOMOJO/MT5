# Step 15H results: detection-time continuation filter

## 結論

2025年3月の再利用済みdevelopment dataでは、検知時点の情報だけで即時順張りを選別する仮説は凍結しない。

- `NO_DETECTION_TIME_CONTINUATION_FILTER_SUPPORTED`
- `NO_CONTINUATION_FILTER_HYPOTHESIS_FROZEN`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `EDGE_UNDETERMINED`
- `PRODUCTION_NOT_ELIGIBLE`

これは長期OOSや未使用期間によるedge判定ではない。2025年3月はStep 15A〜15Gでも利用した開発データであり、内部walk-forwardもOOSとは扱わない。

## 正式run

- RunId: `ts15h_detection_time_continuation_r1_202503`
- 期間: 2025-03-01〜2025-04-01
- driver: EURUSD M1
- model: real ticks
- execution: REALIZABLE
- 対象: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF
- source commit: `a12e72ade081a544fe02f417009fbf499503ca8b`
- source SHA-256: `5CB3D3ED0A8B0097BFC3F1284AB511B29CE05793D902DC7F4A937A14ECE9FA73`
- EX5 SHA-256: `E2DA06EEDDC2119C7B52CA539CB0917A76553BAE443F4BD5FC8CE94A6F7878E9`
- 注文: 0

## t0母集団

3,151 episodeを記録し、各episodeについてdelay 0/100/250ms × horizon 300/600/900秒の28,359 pathを記録した。primaryはdelay 0ms、900秒、RR 1.2、C2である。

GBPUSDはfallback interval mapを確定できないためprimaryから全除外した。さらにfeature unavailable、fallback path、invalid outcomeを除外し、primaryは1,818 episode、1,709 market clusterとなった。事前登録した最低2,500 episode・2,000 clusterに届かないため`INCONCLUSIVE_SAMPLE_SIZE`である。

primaryのfirst touchはTP 277、SL 743、TIMEOUT 798。Long 901件のC2平均は-0.3898R、Short 917件は-0.3771Rだった。通貨別C2平均はAUDUSD -0.3763、EURUSD -0.3972、USDCAD -0.3613、USDCHF -0.3701、USDJPY -0.3969Rである。

## フィルター比較

`V(policy)=sum(selected_i*R_i)/N_eligible`で比較した。NO_TRADEは0、UNFILTEREDはC0 -0.2964、C2 -0.3834R/eligible（cluster bootstrap 95% CI -0.4228〜-0.3431）だった。

4 feature set × logistic/treeの8 familyを、5 expanding chronological outer folds、cluster grouping、900.25秒purge、train-only imputation/scaling/model/threshold selectionで評価した。OOFで実際に選択したのはlogisticの一部だけで、最大14件に留まり、いずれも5 foldで正の再現性を示さなかった。treeおよびPRE_CONTEXTはNO_TRADEを選択した。選択件数不足とsupport不足のため、見かけ上ゼロに近いpolicy valueを成功とは扱わない。

全件NO_TRADEなら回避された損失の合計は1,082.81Rだが、同時に385.74Rの利益を取り逃す。これは利益改善の証拠ではなく、取引をしないcounterfactualの分解である。

## 因果性・回帰

snapshot重複0、path重複0、processing前entry 0、signal quote再利用0、feature future read 0、realized RR 1.2未満0、注文0。既存Step 15Gのdetector 21,799行、episode 3,151行、economic path 430,224行はRunId等を除いた意味列で完全一致した。

46件のStep 15H production-path testは全件PASS。独立oracle 8件も全件PASS。既存研究経路、4 strategy、detector閾値、RR、stop grid、global watermark semanticsは変更していない。

## 制約

- C2は1.25倍spreadとentry/exit各1 tickの診断stressで、正式netではない。
- 6通貨commission/slippageの実証が不足する。
- matched-control economic path比較は未利用。
- GBPUSDのfallback interval mapは未確定。
- March内walk-forwardは選択バイアスを解消しない。

Step 15Hで停止する。閾値追加、feature family追加、長期OOS、production昇格には進まない。
