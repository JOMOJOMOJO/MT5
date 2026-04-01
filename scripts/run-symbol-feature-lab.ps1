param(
    [Parameter(Mandatory = $true)]
    [string]$Symbol,
    [ValidateSet("M1", "M5", "M15", "M30", "H1")]
    [string]$Timeframe = "M5",
    [int]$Bars = 140000,
    [int]$AnalysisDays = 365,
    [int]$OosDays = 89,
    [int]$MinSamples = 120,
    [double]$MinTradesPerDay = 3.0,
    [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$delegate = Join-Path $repoRoot "scripts\run-btc-feature-lab.ps1"

$arguments = @(
    "-ExecutionPolicy", "Bypass",
    "-File", $delegate,
    "-Symbol", $Symbol,
    "-Timeframe", $Timeframe,
    "-Bars", $Bars,
    "-AnalysisDays", $AnalysisDays,
    "-OosDays", $OosDays,
    "-MinSamples", $MinSamples,
    "-MinTradesPerDay", $MinTradesPerDay
)

if ($OutputDir) {
    $arguments += @("-OutputDir", $OutputDir)
}

powershell @arguments
