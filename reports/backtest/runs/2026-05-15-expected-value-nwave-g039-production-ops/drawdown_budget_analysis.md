# Drawdown Budget Analysis

Basis: g039 raw live-path 2024.01.01-2026.04.30. Risk sizing uses unguarded raw MaxDD_R.

|Basis|MaxDD_R|MaxDD% at 0.25 risk|TotalR|ExpectancyR|
|---|---|---|---|---|
|Raw live-path full|23.6686|5.6557|2.9919|0.0099|
|Production guard full|24.2826|5.8883|12.2202|0.0441|

Formula: `RiskPercent <= target_DD_percent / MaxDD_R`.

|Target|RiskPercent upper bound or DD estimate|
|---|---|
|15% hard DD budget|0.6338|
|10% conservative DD budget|0.4225|
|Linear DD estimate at 0.25%|5.9171|
|Linear DD estimate at 0.10%|2.3669|
|Linear DD estimate at 0.05%|1.1834|

Operational recommendation: demo 0.10%-0.25%; small live 0.05%-0.10%; production maximum 0.25% only after demo and small-live review. The mathematical 15% upper bound is not a recommended starting risk.
