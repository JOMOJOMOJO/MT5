# Rejected Parameter Sets

Rejection here means not selected for the next forward-demo candidate. It does not mean every listed set is unusable. The selection was made from 2025 in-sample only.

## Weakest IS Sets
|Run|Trades|WinRate|ExpR|PF|MaxDD_R|TotalR|PosMonths|PosQ|
|---|---|---|---|---|---|---|---|---|
|is2025_jshort_g043_tol0.30_neck0.03_adx22_32|86|40.6977|0.01729|1.029156|15.003399|1.486952|5|2|
|is2025_jshort_g044_tol0.30_neck0.05_adx22_32|87|41.3793|0.034349|1.058595|15.003399|2.988369|5|2|
|is2025_jshort_g016_tol0.30_neck0.03_adx18_30|105|43.8095|0.095017|1.169097|15.995146|9.976738|7|3|
|is2025_jshort_g007_tol0.30_neck0.03_adx18_28|108|44.4444|0.110772|1.199389|14.5|11.963359|7|3|
|is2025_jshort_g045_tol0.30_neck0.07_adx22_32|103|45.6311|0.140631|1.258661|14.503399|14.485029|7|2|
|is2025_jshort_g004_tol0.25_neck0.03_adx18_28|105|45.7143|0.142497|1.262494|10.501399|14.96218|7|3|
|is2025_jshort_g034_tol0.30_neck0.03_adx20_32|129|46.5116|0.162531|1.303862|13.001693|20.966471|8|3|
|is2025_jshort_g010_tol0.20_neck0.03_adx18_30|111|46.8468|0.170976|1.321666|11.996545|18.978302|6|4|

## Not Selected Despite Strong IS
- g027 (Tolerance=0.30, Neckline=0.07, ADX=20/30): strong, but selected g024 had slightly better ExpectancyR with fewer trades and the same MaxDD_R.
- g033 (Tolerance=0.25, Neckline=0.07, ADX=20/32): strong, but MaxDD_R increased to 11 and wider ADX-middle admitted more trades; selected g024 was cleaner on risk-adjusted IS evidence.
- g030 (Tolerance=0.20, Neckline=0.07, ADX=20/32): strong, but lower ExpectancyR and higher MaxDD_R than selected.
- g039/g042 (ADX=22/32): high ExpectancyR but fewer trades and only 3/4 positive 2025 quarters.

## Hard Reject Reasons
The lowest-ranked sets mostly shared one of these issues:
- NecklineBreakBufferATR=0.03 was weaker on average.
- Tolerance=0.30 plus high ADX pair 22/32 reduced trade count and weakened quarter stability.
- Some sets failed the IS PF > 1.2 promotion criterion.

Full grid evidence: is_2025_grid_metrics.csv.
