param(
    [string]$MetaEditorPath = $env:MT5_METAEDITOR,
    [string]$Source,
    [string]$LogPath
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if (-not $Source) {
    $candidates = Get-ChildItem -Path (Join-Path $repoRoot "mql") -Recurse -Filter *.mq5 | Sort-Object FullName
    if ($candidates.Count -eq 1) {
        $Source = $candidates[0].FullName
    } elseif ($candidates.Count -gt 1) {
        throw "Multiple .mq5 files were found. Pass -Source to choose one explicitly."
    } else {
        throw "No .mq5 files were found under mql/. Add an EA first or pass -Source."
    }
}

if (-not $MetaEditorPath) {
    throw "MetaEditor path is not set. Pass -MetaEditorPath or set MT5_METAEDITOR."
}

if (-not (Test-Path $MetaEditorPath)) {
    throw "MetaEditor executable was not found at '$MetaEditorPath'."
}

if (-not $LogPath) {
    $LogPath = Join-Path $repoRoot "reports\compile\metaeditor.log"
}

$resolvedSource = (Resolve-Path $Source).Path
$logDirectory = Split-Path -Parent $LogPath
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

& $MetaEditorPath "/compile:$resolvedSource" "/log:$LogPath"
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    throw "Compilation failed with exit code $exitCode. See '$LogPath'."
}

Write-Host "Compiled: $resolvedSource"
Write-Host "Log: $LogPath"
