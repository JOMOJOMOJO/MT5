# Live Path Rejected Parameter Sets

## Rejected OOS Candidates From 2025 IS Top 5
|IS Rank|Run|2025 IS ExpR|2025 IS PF|OOS ExpR|OOS PF|Reason|
|---:|---|---:|---:|---:|---:|---|
|1|g024 `tol0.25 neck0.07 adx20/30`|0.240004|1.465090|-0.084949|0.866633|Strong IS, failed live-path OOS.|
|2|g003 `tol0.20 neck0.07 adx18/28`|0.209596|1.399898|-0.216482|0.687602|Strong IS, failed live-path OOS hard.|
|3|g021 `tol0.20 neck0.07 adx20/30`|0.208962|1.396996|-0.231219|0.668274|Strong IS, failed live-path OOS hard.|
|5|g030 `tol0.20 neck0.07 adx20/32`|0.197234|1.370240|-0.036065|0.941664|Near break-even but failed OOS PF/expectancy gate.|

## Weak IS Regions
The weakest 2025 IS live-path sets were concentrated around `DoubleTopBottomToleranceATR=0.30`, especially with low neckline buffer and higher ADX thresholds.

Examples:
|Run|Trades|ExpR|PF|MaxDD_R|Positive Quarters|
|---|---:|---:|---:|---:|---:|
|g007 `tol0.30 neck0.03 adx18/28`|83|-0.157153|0.769034|15.866688|2|
|g043 `tol0.30 neck0.03 adx22/32`|81|-0.100804|0.846495|15.683138|2|
|g044 `tol0.30 neck0.05 adx22/32`|82|-0.081133|0.874925|15.683672|2|
|g034 `tol0.30 neck0.03 adx20/32`|104|-0.066463|0.896965|15.580507|2|
|g045 `tol0.30 neck0.07 adx22/32`|82|-0.051878|0.918493|15.255944|2|

## Rejection Principle
No rejected set is being retuned here. Rejections are recorded to avoid using OOS failure as an invitation for another fitting cycle.
