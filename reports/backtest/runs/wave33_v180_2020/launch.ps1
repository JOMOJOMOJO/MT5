# User-authorized fixed annual run; stop agent work after native tester starts.
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
Set-Location -LiteralPath $repo
$deployment=Get-Content -LiteralPath 'reports/qa/w33v180/deployment.json' -Raw|ConvertFrom-Json
if((Get-FileHash -LiteralPath 'mql/Experts/Wave33VisualVerifier.mq5').Hash -ne $deployment.source_sha256){throw 'v1.80 source differs from verified deployment'}
if((Get-FileHash -LiteralPath 'mql/Experts/Wave33VisualVerifier.ex5').Hash -ne $deployment.binary_sha256){throw 'v1.80 deployed EX5 differs from verified deployment'}
foreach($header in $deployment.header_sha256.PSObject.Properties){
 if((Get-FileHash -LiteralPath (Join-Path 'mql/Include' $header.Name)).Hash -ne $header.Value){throw ('Verified header changed: '+$header.Name)}
}
& (Join-Path $repo 'scripts/run-wave33-visual-qa.ps1') `
 -SourceDataRoot 'C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675' `
 -RuntimeRoot 'C:/Users/windows/AppData/Local/CodexMT5Wave33/20261023_150705_4035cece' `
 -Symbol 'XAUUSD+' -Model 4 -Deposit 5000 `
 -DateFrom '2020.01.01' -DateTo '2021.01.01' `
 -OnlyRuns @('v180_a_both','v180_b_both') `
 -OutputRoot 'reports/backtest/runs/wave33_v180_2020' `
 -TimeoutSecondsPerRun 7200 -Execute
