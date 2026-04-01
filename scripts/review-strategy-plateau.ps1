param(
    [Parameter(Mandatory = $true)]
    [string]$FamilyLabel,
    [Parameter(Mandatory = $true)]
    [string[]]$RunPaths,
    [ValidateSet("quality_first", "balanced", "high_turnover_compounding")]
    [string]$Objective = "high_turnover_compounding",
    [double]$MinProfitFactor = 1.30,
    [double]$MinTradesPerDay = 3.0,
    [int]$StagnationWindow = 3,
    [double]$MinRelativeScoreImprovement = 10.0,
    [string]$OutputPath = "",
    [string]$MarkdownOutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$pythonScript = Join-Path $repoRoot "plugins\mt5-company\scripts\evaluate_strategy_plateau.py"

$arguments = @(
    $pythonScript,
    "--family-label", $FamilyLabel,
    "--objective", $Objective,
    "--min-profit-factor", $MinProfitFactor,
    "--min-trades-per-day", $MinTradesPerDay,
    "--stagnation-window", $StagnationWindow,
    "--min-relative-score-improvement", $MinRelativeScoreImprovement
)

$normalizedRunPaths = @($RunPaths)
if ($normalizedRunPaths.Count -eq 1 -and $normalizedRunPaths[0] -match ",") {
    $normalizedRunPaths = $normalizedRunPaths[0].Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

foreach ($runPath in $normalizedRunPaths) {
    $resolved = (Resolve-Path $runPath).Path
    $arguments += @("--run", $resolved)
}

if ($OutputPath) {
    $arguments += @("--output", (Join-Path $repoRoot $OutputPath))
}

if ($MarkdownOutputPath) {
    $arguments += @("--markdown-output", (Join-Path $repoRoot $MarkdownOutputPath))
}

python @arguments
