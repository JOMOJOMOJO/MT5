# Fixed annual observation only. No strategy edits, optimization, or streak analysis.
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
Set-Location -LiteralPath $repo
$deployment=Get-Content -LiteralPath 'reports/qa/w33ext/deployment.json' -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath 'mql/Experts/Wave33VisualVerifier.mq5').Hash -ne $deployment.source_sha256){throw 'v1.70 source differs from verified deployment'}
foreach($header in $deployment.headers){
 if((Get-FileHash -LiteralPath (Join-Path 'mql/Include' $header.path)).Hash -ne $header.sha256){throw ('Verified header changed: '+$header.path)}
}
& (Join-Path $repo 'scripts/run-wave33-visual-qa.ps1') `
 -SourceDataRoot 'C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675' `
 -RuntimeRoot 'C:/Users/windows/AppData/Local/CodexMT5Wave33/20261021_235636_802a6036' `
 -Symbol 'XAUUSD+' -Model 4 -Deposit 5000 `
 -DateFrom '2020.01.01' -DateTo '2021.01.01' `
 -OnlyRuns @('a_extension_on','b_extension_on') `
 -OutputRoot 'reports/backtest/runs/wave33_v170_2020' `
 -TimeoutSecondsPerRun 7200 -Execute
