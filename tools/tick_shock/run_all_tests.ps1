param([int]$TimeoutSeconds = 120)
$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
& (Join-Path $PSScriptRoot "run_mql_harnesses.ps1") -TimeoutSeconds $TimeoutSeconds
python (Join-Path $PSScriptRoot "run_python_tests.py") --repo-root $repoRoot
if ($LASTEXITCODE -ne 0) { throw "Python test runner failed with exit code $LASTEXITCODE" }
