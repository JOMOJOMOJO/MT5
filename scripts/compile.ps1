param(
    [string]$MetaEditorPath = $env:MT5_METAEDITOR,
    [string]$Source,
    [string]$LogPath
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$repoDefaultMetaEditorPath = "C:\Program Files\XMTrading MT5 - 2\MetaEditor64.exe"
$legacyDefaultMetaEditorPath = "C:\Program Files\XMTrading MT5\MetaEditor64.exe"

if (-not $MetaEditorPath -and (Test-Path $repoDefaultMetaEditorPath)) {
    $MetaEditorPath = $repoDefaultMetaEditorPath
}
if (-not $MetaEditorPath -and (Test-Path $legacyDefaultMetaEditorPath)) {
    $MetaEditorPath = $legacyDefaultMetaEditorPath
}

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
$ex5Path = [System.IO.Path]::ChangeExtension($resolvedSource, ".ex5")
$previousWriteTime = if (Test-Path $ex5Path) { (Get-Item $ex5Path).LastWriteTimeUtc } else { $null }

$process = Start-Process -FilePath $MetaEditorPath -ArgumentList "/compile:$resolvedSource", "/log:$LogPath" -Wait -PassThru
$exitCode = $process.ExitCode

if (-not (Test-Path $LogPath)) {
    throw "Compilation log was not created at '$LogPath'."
}

$logText = Get-Content -Path $LogPath -Raw
$isSuccessfulCompile = ($logText -match "Result:\s+0 errors,\s+0 warnings")

if (-not (Test-Path $ex5Path)) {
    throw "Compiled output was not found at '$ex5Path'."
}

$compiledFile = Get-Item $ex5Path
if ($previousWriteTime -and $compiledFile.LastWriteTimeUtc -lt $previousWriteTime) {
    throw "Compiled output timestamp did not advance for '$ex5Path'."
}

if (-not $isSuccessfulCompile) {
    throw "Compilation log reports errors or warnings. See '$LogPath'."
}

if ($exitCode -ne 0) {
    Write-Warning "MetaEditor returned exit code $exitCode, but the log reports a successful compile."
}

$marker = "\MQL5\Experts\"
$markerIndex = $ex5Path.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase)
if ($markerIndex -ge 0) {
    $relativeExpertPath = $ex5Path.Substring($markerIndex + $marker.Length)
    $terminalRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (Test-Path $terminalRoot) {
        foreach ($terminalDir in Get-ChildItem -LiteralPath $terminalRoot -Directory -ErrorAction SilentlyContinue) {
            $expertsDir = Join-Path $terminalDir.FullName "MQL5\Experts"
            if (-not (Test-Path $expertsDir)) {
                continue
            }
            $targetEx5Path = Join-Path $expertsDir $relativeExpertPath
            if ($targetEx5Path -eq $ex5Path) {
                continue
            }
            $targetDir = Split-Path -Parent $targetEx5Path
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            Copy-Item -LiteralPath $ex5Path -Destination $targetEx5Path -Force
            Write-Host "Synced EX5: $targetEx5Path"
        }
    }
}

Write-Host "Compiled: $resolvedSource"
Write-Host "Log: $LogPath"
