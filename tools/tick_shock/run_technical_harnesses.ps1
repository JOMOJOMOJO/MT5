param([int]$TimeoutSeconds=120)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$jobs=@(
 @{Name='TechnicalFeatures';Stem='technical_features';Common='tick_shock_technical_discovery\technical_features_harness.csv'},
 @{Name='TechnicalExecution';Stem='technical_execution';Common='tick_shock_technical_execution_harness\technical_execution_harness.csv'}
)
$out=Join-Path $root 'reports\tests\tick_shock\technical_discovery'
New-Item -ItemType Directory -Path $out -Force | Out-Null
foreach($job in $jobs){
 $name="ExpectedValue_TickShock_$($job.Name)Harness"
 $source=Join-Path $root "mql\Experts\tests\$name.mq5"
 $compile=Join-Path $root "reports\compile\tick_shock\$($job.Stem)_harness.log"
 & (Join-Path $root 'scripts\compile.ps1') -Source $source -LogPath $compile
 if((Get-Content $compile -Raw) -notmatch '0 errors, 0 warnings'){throw "Compile gate $name"}
 $config=Join-Path $out "$($job.Stem).ini"
 $lines=@('[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','','[Tester]',"Expert=dev\mql\Experts\tests\$name.ex5",'Symbol=EURUSD','Period=M1','Model=1','Optimization=0','FromDate=2025.04.01','ToDate=2025.04.02','Deposit=10000','Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0','Visual=0','ReplaceReport=1','ShutdownTerminal=1',"Report=MQL5\Experts\dev\reports\tests\tick_shock\technical_discovery\$($job.Stem).html")
 [IO.File]::WriteAllLines($config,$lines,[Text.UTF8Encoding]::new($false))
 $start=[DateTime]::UtcNow
 & (Join-Path $root 'scripts\backtest.ps1') -ConfigPath $config -TimeoutSeconds $TimeoutSeconds -RestartExisting
 $common=Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\$($job.Common)"
 if(-not(Test-Path -LiteralPath $common)){throw "Missing $common"}
 if((Get-Item $common).LastWriteTimeUtc -lt $start){throw "Stale test output $common"}
 $dest=Join-Path $out "$($job.Stem)_harness.csv"
 Copy-Item -LiteralPath $common -Destination $dest
 $rows=@(Import-Csv $dest)
 $fails=@($rows | Where-Object {$_.status -ne 'PASS'})
 if($fails.Count -gt 0){$fails|Format-Table;throw "Harness failed $name"}
 Write-Host "$name PASS assertions=$($rows.Count-1)"
}
