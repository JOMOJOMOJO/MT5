param(
    [int]$TimeoutSeconds = 120,
    [ValidateSet("pre-fix","post-fix","step10","step11")]
    [string]$Phase = "post-fix"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$commonRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\tick_shock_step05"
$commonFixtures = Join-Path $commonRoot "fixtures"
$commonExpected = Join-Path $commonRoot "expected"
$commonRaw = Join-Path $commonRoot "raw"
$evidenceRaw = if ($Phase -eq "pre-fix") {
    Join-Path $repoRoot "reports\tests\tick_shock\raw"
} elseif ($Phase -eq "step10") {
    Join-Path $repoRoot "reports\tests\tick_shock\step10_raw"
} elseif ($Phase -eq "step11") {
    Join-Path $repoRoot "reports\tests\tick_shock\step11_raw"
} else {
    Join-Path $repoRoot "reports\tests\tick_shock\step12_raw"
}
$configRoot = Join-Path $repoRoot "reports\tests\tick_shock\configs"
$compileRoot = Join-Path $repoRoot "reports\compile\tick_shock"
$testerRoot = Join-Path $repoRoot "reports\tests\tick_shock\tester"
$stepTag = if ($Phase -eq "pre-fix") { "step05" } elseif ($Phase -eq "step10") { "step10" } elseif ($Phase -eq "step11") { "step11" } else { "step12" }

foreach ($path in @($commonFixtures,$commonExpected,$commonRaw,$evidenceRaw,$configRoot,$compileRoot,$testerRoot)) {
    New-Item -ItemType Directory -Force -Path $path | Out-Null
}

Copy-Item -Path (Join-Path $repoRoot "tests\tick_shock\fixtures\*") -Destination $commonFixtures -Force
Copy-Item -Path (Join-Path $repoRoot "tests\tick_shock\expected\*") -Destination $commonExpected -Force

$harnesses = @(
    "DomainUnit",
    "Detector",
    "StateMachine",
    "Execution",
    "SyntheticIntegration",
    "MultiCurrencyMerge",
    "OrderLifecycle",
    "IntegrityRegression"
)

foreach ($name in $harnesses) {
    $source = Join-Path $repoRoot "mql\Experts\tests\ExpectedValue_TickShock_${name}Harness.mq5"
    $compileLog = Join-Path $compileRoot "${stepTag}_ExpectedValue_TickShock_${name}Harness.log"
    & (Join-Path $repoRoot "scripts\compile.ps1") -Source $source -LogPath $compileLog

    $suite = switch ($name) {
        "DomainUnit" { "domain_unit" }
        "Detector" { "detector" }
        "StateMachine" { "state_machine" }
        "Execution" { "execution" }
        "SyntheticIntegration" { "synthetic_integration" }
        "MultiCurrencyMerge" { "multicurrency_merge" }
        "OrderLifecycle" { "order_lifecycle" }
        "IntegrityRegression" { "integrity_regression" }
    }
    $commonResult = Join-Path $commonRaw "$suite.csv"
    if (Test-Path -LiteralPath $commonResult) { Remove-Item -LiteralPath $commonResult -Force }

    $configPath = Join-Path $configRoot "${stepTag}_${suite}.ini"
    $reportRelative = "MQL5\Experts\dev\reports\tests\tick_shock\tester\${stepTag}_${suite}.html"
    $configLines = @(
        "[Experts]",
        "Enabled=0",
        "AllowLiveTrading=0",
        "AllowDllImport=0",
        "",
        "[Tester]",
        "Expert=dev\mql\Experts\tests\ExpectedValue_TickShock_${name}Harness.ex5",
        "Symbol=EURUSD",
        "Period=M1",
        "Model=1",
        "ExecutionMode=0",
        "Optimization=0",
        "FromDate=2025.03.03",
        "ToDate=2025.03.04",
        "Deposit=10000",
        "Currency=USD",
        "Leverage=1:100",
        "UseLocal=1",
        "UseRemote=0",
        "UseCloud=0",
        "Visual=0",
        "ReplaceReport=1",
        "ShutdownTerminal=1",
        "Report=$reportRelative"
    )
    [System.IO.File]::WriteAllLines($configPath,$configLines,[System.Text.UTF8Encoding]::new($false))
    & (Join-Path $repoRoot "scripts\backtest.ps1") -ConfigPath $configPath -TimeoutSeconds $TimeoutSeconds -RestartExisting
    if (-not (Test-Path -LiteralPath $commonResult)) { throw "Harness result missing: $commonResult" }
    Copy-Item -LiteralPath $commonResult -Destination (Join-Path $evidenceRaw "$suite.csv") -Force
}

Write-Host "MQL5 harness evidence: $evidenceRaw"
