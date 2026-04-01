param(
    [string]$BaselinePath = "reports/telemetry/2026-03-31-btcusd-session-meanrev-live035-guarded2-demo-forward.json",
    [string]$CandidatePath = "reports/telemetry/2026-03-31-btcusd-session-meanrev-live035-guarded2-demo-forward.json",
    [string]$Label = "btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2-forward-gate",
    [string]$Slug = "btcusd-session-meanrev-live035-guarded2-forward-gate"
)

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$baselineResolvedPath = (Resolve-Path (Join-Path $workspaceRoot $BaselinePath)).Path
$candidateResolvedPath = (Resolve-Path (Join-Path $workspaceRoot $CandidatePath)).Path
$datePrefix = Get-Date -Format "yyyy-MM-dd"
$outputPath = Join-Path $workspaceRoot "reports/forward/$datePrefix-$Slug.json"
$markdownOutputPath = Join-Path $workspaceRoot "knowledge/experiments/$datePrefix-$Slug.md"
$scriptPath = Join-Path $workspaceRoot "plugins/mt5-company/scripts/evaluate_forward_gate.py"

$summary = & python $scriptPath `
    --baseline $baselineResolvedPath `
    --candidate $candidateResolvedPath `
    --output $outputPath `
    --markdown-output $markdownOutputPath `
    --label $Label

if ($LASTEXITCODE -ne 0) {
    throw "Forward gate evaluation failed."
}

Write-Host "Baseline : $baselineResolvedPath"
Write-Host "Candidate: $candidateResolvedPath"
Write-Host "Gate JSON: $outputPath"
Write-Host "Gate Note: $markdownOutputPath"
Write-Host "Result   : $summary"
