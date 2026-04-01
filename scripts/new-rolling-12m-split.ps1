param(
    [Parameter(Mandatory = $true)]
    [string]$BaseConfigPath,
    [datetime]$EndDate,
    [switch]$Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ConfigValue {
    param(
        [string[]]$Lines,
        [string]$Key
    )

    $line = $Lines | Where-Object { $_ -match "^\s*$([regex]::Escape($Key))=" } | Select-Object -First 1
    if (-not $line) {
        return $null
    }
    return ($line -replace "^\s*$([regex]::Escape($Key))=", "").Trim()
}

function Set-ConfigValue {
    param(
        [string[]]$Lines,
        [string]$Key,
        [string]$Value
    )

    $found = $false
    $updated = foreach ($line in $Lines) {
        if ($line -match "^\s*$([regex]::Escape($Key))=") {
            $found = $true
            "$Key=$Value"
        } else {
            $line
        }
    }

    if (-not $found) {
        $updated += "$Key=$Value"
    }

    return ,$updated
}

function Assert-CanWrite {
    param([string]$Path)
    if ((Test-Path $Path) -and -not $Overwrite) {
        throw "Target file already exists: $Path . Pass -Overwrite to replace it."
    }
}

$resolvedBase = (Resolve-Path $BaseConfigPath).Path
$baseLines = Get-Content $resolvedBase

$baseEnd = Get-ConfigValue -Lines $baseLines -Key "ToDate"
if (-not $PSBoundParameters.ContainsKey("EndDate")) {
    if (-not $baseEnd) {
        throw "Base config has no ToDate. Pass -EndDate explicitly."
    }
    $EndDate = [datetime]::ParseExact($baseEnd, "yyyy.MM.dd", [System.Globalization.CultureInfo]::InvariantCulture)
}

$oosStart = $EndDate.AddMonths(-3).AddDays(1)
$trainStart = $EndDate.AddMonths(-12).AddDays(1)
$trainEnd = $oosStart.AddDays(-1)

$baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedBase)
if ($baseName -match "-1y$") {
    $prefix = $baseName.Substring(0, $baseName.Length - 3)
} else {
    $prefix = $baseName
}

$directory = Split-Path -Parent $resolvedBase
$trainPath = Join-Path $directory "$prefix-train-9m.ini"
$oosPath = Join-Path $directory "$prefix-oos-3m.ini"

Assert-CanWrite -Path $trainPath
Assert-CanWrite -Path $oosPath

$reportValue = Get-ConfigValue -Lines $baseLines -Key "Report"
$reportRoot = $null
$reportExt = ".htm"
if ($reportValue) {
    $reportExt = [System.IO.Path]::GetExtension($reportValue)
    if ([string]::IsNullOrWhiteSpace($reportExt)) {
        $reportExt = ".htm"
    }
    $reportRoot = $reportValue.Substring(0, $reportValue.Length - $reportExt.Length)
}

$trainLines = $baseLines
$trainLines = Set-ConfigValue -Lines $trainLines -Key "FromDate" -Value ($trainStart.ToString("yyyy.MM.dd"))
$trainLines = Set-ConfigValue -Lines $trainLines -Key "ToDate" -Value ($trainEnd.ToString("yyyy.MM.dd"))
if ($reportRoot) {
    $trainLines = Set-ConfigValue -Lines $trainLines -Key "Report" -Value ("$($reportRoot)-train-9m$reportExt")
}

$oosLines = $baseLines
$oosLines = Set-ConfigValue -Lines $oosLines -Key "FromDate" -Value ($oosStart.ToString("yyyy.MM.dd"))
$oosLines = Set-ConfigValue -Lines $oosLines -Key "ToDate" -Value ($EndDate.ToString("yyyy.MM.dd"))
if ($reportRoot) {
    $oosLines = Set-ConfigValue -Lines $oosLines -Key "Report" -Value ("$($reportRoot)-oos-3m$reportExt")
}

Set-Content -Path $trainPath -Value $trainLines -Encoding UTF8
Set-Content -Path $oosPath -Value $oosLines -Encoding UTF8

Write-Output "Train config: $trainPath"
Write-Output "OOS config: $oosPath"
Write-Output "Train window: $($trainStart.ToString('yyyy.MM.dd')) -> $($trainEnd.ToString('yyyy.MM.dd'))"
Write-Output "OOS window: $($oosStart.ToString('yyyy.MM.dd')) -> $($EndDate.ToString('yyyy.MM.dd'))"
