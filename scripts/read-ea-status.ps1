param(
    [string]$StatusFileName = "mt5_company_btcusd_20260330_session_meanrev_status.txt"
)

$commonFilesPath = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$statusPath = if ([System.IO.Path]::IsPathRooted($StatusFileName)) {
    $StatusFileName
} else {
    Join-Path $commonFilesPath $StatusFileName
}

if (-not (Test-Path $statusPath)) {
    throw "Status file not found: $statusPath"
}

$pairs = [ordered]@{}
foreach ($line in Get-Content -Path $statusPath) {
    if (-not $line -or $line -notmatch "=") {
        continue
    }
    $key, $value = $line -split "=", 2
    $pairs[$key.Trim()] = $value.Trim()
}

$timestampRaw = if ($pairs.Contains("timestamp")) { $pairs["timestamp"] } else { "" }
if ($timestampRaw) {
    try {
        $heartbeatTimestamp = [datetime]::ParseExact($timestampRaw, "yyyy.MM.dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
        $heartbeatAgeMinutes = [math]::Round(((Get-Date) - $heartbeatTimestamp).TotalMinutes, 1)
        $pairs["heartbeat_age_minutes"] = [string]$heartbeatAgeMinutes
        $pairs["heartbeat_fresh"] = if ($heartbeatAgeMinutes -le 180) { "true" } else { "false" }
    } catch {
        $pairs["heartbeat_age_minutes"] = "unparsed"
        $pairs["heartbeat_fresh"] = "unknown"
    }
}

$pairs.GetEnumerator() | ForEach-Object {
    "{0,-24} {1}" -f ($_.Key + ":"), $_.Value
}
