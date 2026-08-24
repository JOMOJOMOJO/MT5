param(
    [int]$TimeoutSeconds = 120,
    [ValidateSet("pre-fix","post-fix","step10","step11","step14r")]
    [string]$Phase = "post-fix"
)
$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
& (Join-Path $PSScriptRoot "run_mql_harnesses.ps1") -TimeoutSeconds $TimeoutSeconds -Phase $Phase
python (Join-Path $PSScriptRoot "run_python_tests.py") --repo-root $repoRoot --phase $Phase
if ($LASTEXITCODE -ne 0) { throw "Python test runner failed with exit code $LASTEXITCODE" }
