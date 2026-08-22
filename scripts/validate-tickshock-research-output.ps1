param(
    [Parameter(Mandatory = $true)]
    [string]$EventsPath,

    [Parameter(Mandatory = $true)]
    [string]$SummaryPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$culture = [System.Globalization.CultureInfo]::InvariantCulture

function Convert-ToInt64 {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return [int64]0 }
    return [int64]::Parse($Value, $culture)
}

function Convert-ToDouble {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return [double]::NaN }
    return [double]::Parse($Value, $culture)
}

function Convert-FieldsToMap {
    param([string[]]$Fields)
    $map = @{}
    foreach ($field in $Fields) {
        $pair = $field -split '=', 2
        if ($pair.Count -eq 2) { $map[$pair[0]] = $pair[1] }
    }
    return $map
}

function Add-Result {
    param(
        [System.Collections.Generic.List[object]]$Target,
        [string]$Check,
        [bool]$Passed,
        [string]$Actual,
        [string]$Expected
    )
    $Target.Add([pscustomobject]@{
        check = $Check
        result = if ($Passed) { 'PASS' } else { 'FAIL' }
        actual = $Actual
        expected = $Expected
    })
}

$events = @(Import-Csv -LiteralPath $EventsPath)
$summary = @(Import-Csv -LiteralPath $SummaryPath)
$results = [System.Collections.Generic.List[object]]::new()
$validStatuses = @('TP_LIMIT', 'SL_GAP', 'TIME_MARKET')
$groups = @{}
$scenarioValid = 0L
$scenarioInvalid = 0L
$scenarioSumR = 0.0
$entryBeforeEligible = 0L
$entryBeforeProcessing = 0L
$staleDetectionFill = 0L
$reversalOverwrite = 0L
$rrBelowRequested = 0L

foreach ($event in $events) {
    $detectionGrid = Convert-ToInt64 $event.detection_grid_msc
    $detectionAge = Convert-ToInt64 $event.detection_quote_age_ms
    $invalidation = Convert-ToInt64 $event.continuation_invalidated_msc
    $mode = $event.execution_mode

    foreach ($encoded in @($event.scenario_grid -split ';')) {
        if ([string]::IsNullOrWhiteSpace($encoded)) { continue }
        $parts = $encoded -split '\|'
        if ($parts.Count -lt 6) { throw "Malformed scenario for event $($event.event_id): $encoded" }
        $strategy, $stop, $delay, $spread, $status = $parts[0..4]
        $values = Convert-FieldsToMap $parts[5..($parts.Count - 1)]
        $groupKey = "$mode`:$strategy`:$stop`:$delay`:$spread"
        if (-not $groups.ContainsKey($groupKey)) {
            $groups[$groupKey] = [ordered]@{ valid = 0L; invalid = 0L; sum = 0.0 }
        }

        # The event row intentionally contains the complete fixed scenario grid.
        # NO_SIGNAL cells are structural placeholders, not attempted outcomes.
        if ($status -eq 'NO_SIGNAL') { continue }

        $entry = Convert-ToInt64 $values.entry_quote
        $eligible = Convert-ToInt64 $values.eligible
        $processing = Convert-ToInt64 $values.signal_processing
        $signal = Convert-ToInt64 $values.signal_event
        $requestedRr = Convert-ToDouble $values.requested_rr
        $realizedRr = Convert-ToDouble $values.realized_rr

        if ($validStatuses -contains $status) {
            $netR = Convert-ToDouble $values.net
            $groups[$groupKey].valid++
            $groups[$groupKey].sum += $netR
            $scenarioValid++
            $scenarioSumR += $netR
            if (-not [double]::IsNaN($requestedRr) -and -not [double]::IsNaN($realizedRr) -and
                $realizedRr + 1.0e-9 -lt $requestedRr) { $rrBelowRequested++ }
        } else {
            $groups[$groupKey].invalid++
            $scenarioInvalid++
        }

        if ($entry -gt 0) {
            if ($entry -lt $eligible) { $entryBeforeEligible++ }
            if ($mode -eq 'REALIZABLE_EA' -and $entry -lt $processing) { $entryBeforeProcessing++ }
            if ($strategy -eq 'detection_time_continuation' -and $detectionAge -gt 0 -and
                $entry -eq $detectionGrid) { $staleDetectionFill++ }
        }
        if ($strategy -eq 'failed_shock_reversal' -and $signal -ne $invalidation) {
            $reversalOverwrite++
        }
    }
}

$duplicateEvents = @($events | Group-Object event_id | Where-Object Count -gt 1).Count
$overall = $summary | Where-Object { $_.record_type -eq 'OVERALL' -and $_.key -eq 'ALL' } | Select-Object -First 1
$cluster = $summary | Where-Object { $_.record_type -eq 'CLUSTER' -and $_.key -eq 'counts' } | Select-Object -First 1
$merge = $summary | Where-Object { $_.record_type -eq 'MODEL' -and $_.key -eq 'global_merge' } | Select-Object -First 1
$writer = $summary | Where-Object { $_.record_type -eq 'INVARIANT' -and $_.key -eq 'writer_scenario_recount' } | Select-Object -First 1
$scenarioRows = @($summary | Where-Object record_type -eq 'SCENARIO')

Add-Result $results 'event_rows' ($events.Count -eq (Convert-ToInt64 $overall.event_csv_rows)) "$($events.Count)" $overall.event_csv_rows
Add-Result $results 'event_duplicate' ($duplicateEvents -eq 0) "$duplicateEvents" '0'
Add-Result $results 'entry_before_eligible' ($entryBeforeEligible -eq 0) "$entryBeforeEligible" '0'
Add-Result $results 'entry_before_processing' ($entryBeforeProcessing -eq 0) "$entryBeforeProcessing" '0'
Add-Result $results 'stale_detection_fill' ($staleDetectionFill -eq 0) "$staleDetectionFill" '0'
Add-Result $results 'reversal_signal_overwrite' ($reversalOverwrite -eq 0) "$reversalOverwrite" '0'
Add-Result $results 'realized_rr_below_requested' ($rrBelowRequested -eq 0) "$rrBelowRequested" '0'
Add-Result $results 'scenario_valid_total' ($scenarioValid -eq (Convert-ToInt64 $overall.scenario_valid)) "$scenarioValid" $overall.scenario_valid
Add-Result $results 'scenario_invalid_total' ($scenarioInvalid -eq (Convert-ToInt64 $overall.scenario_invalid)) "$scenarioInvalid" $overall.scenario_invalid
$internalWriterMatch = $writer.value -match 'matches=true'
Add-Result $results 'internal_writer_recount' $internalWriterMatch $writer.value 'matches=true'
$globalOrderViolations = if ($merge.value -match 'order_violations=(\d+)') { [int64]$matches[1] } else { -1L }
Add-Result $results 'global_order_violation' ($globalOrderViolations -eq 0) "$globalOrderViolations" '0'
Add-Result $results 'cluster_counts_present' ($cluster.value -match 'event_rows=\d+;symbol_clusters=\d+;market_clusters=\d+') $cluster.value 'three separate counts'

$mismatchedGroups = 0L
$mismatchSamples = [System.Collections.Generic.List[string]]::new()
foreach ($row in $scenarioRows) {
    if (-not $groups.ContainsKey($row.key)) {
        $mismatchedGroups++
        if ($mismatchSamples.Count -lt 5) { $mismatchSamples.Add("missing:$($row.key)") }
        continue
    }
    $actual = $groups[$row.key]
    $expectedValid = Convert-ToInt64 $row.scenario_valid
    $expectedInvalid = Convert-ToInt64 $row.scenario_invalid
    $expectedMean = Convert-ToDouble $row.scenario_expectancy_r
    $actualMean = if ($actual.valid -gt 0) { $actual.sum / $actual.valid } else { [double]::NaN }
    # Both scenario netR and summary expectancy are serialized to six decimals.
    # One output quantum is therefore the strictest meaningful CSV comparison.
    $meanMatches = ([double]::IsNaN($actualMean) -and [double]::IsNaN($expectedMean)) -or
        ([math]::Abs($actualMean - $expectedMean) -le 1.000001e-6)
    if ($actual.valid -ne $expectedValid -or $actual.invalid -ne $expectedInvalid -or -not $meanMatches) {
        $mismatchedGroups++
        if ($mismatchSamples.Count -lt 5) {
            $mismatchSamples.Add("$($row.key):actual=$($actual.valid)/$($actual.invalid)/$actualMean expected=$expectedValid/$expectedInvalid/$expectedMean")
        }
    }
}
Add-Result $results 'scenario_group_recount' ($mismatchedGroups -eq 0 -and $scenarioRows.Count -eq $groups.Count) "mismatches=$mismatchedGroups;csv_groups=$($groups.Count);summary_groups=$($scenarioRows.Count);samples=$($mismatchSamples -join ' || ')" 'mismatches=0 and equal group counts'

$results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
$failures = @($results | Where-Object result -eq 'FAIL')
$results | Format-Table -AutoSize
if ($failures.Count -gt 0) { exit 1 }
