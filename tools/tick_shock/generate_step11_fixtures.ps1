$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$fixtureRoot = Join-Path $repoRoot "tests\tick_shock\fixtures"
$expectedRoot = Join-Path $repoRoot "tests\tick_shock\expected"

$definitions = [ordered]@{
    "TS-CONFIG-001" = @("config_valid,false,0,bool,min_efficiency greater than one is invalid")
    "TS-CONFIG-002" = @("negative_entry_valid,false,0,bool,negative entry slippage is invalid", "negative_exit_valid,false,0,bool,negative exit slippage is invalid")
    "TS-CONFIG-003" = @("config_valid,false,0,bool,negative commission is invalid")
    "TS-CONFIG-004" = @("config_valid,false,0,bool,percentages must remain within zero through one hundred")
    "TS-CONFIG-005" = @("invalid_mode_valid,false,0,bool,unknown enum invalid", "nan_valid,false,0,bool,NaN invalid", "infinity_valid,false,0,bool,Infinity invalid")
    "TS-CONFIG-006" = @("oninit_calls_full_validator,true,0,bool,source contract", "invalid_return_code,INIT_PARAMETERS_INCORRECT,0,enum,fail closed")
    "TS-COMM-002" = @("valid,false,0,bool,failed calculation invalid", "reason,CALCULATION_FAILED,0,enum,explicit reason", "zero_fallback,false,0,bool,nonzero commission cannot become zero")
    "TS-COMM-003" = @("commission_r,0.07,0.000000000001,R,seven over one hundred", "net_r,0.93,0.000000000001,R,deduct once", "applications,1,0,count,single application")
    "TS-COMM-004" = @("symbol,EURUSD,0,text,provenance", "source,CONFIGURED_ROUND_TURN,0,enum,provenance", "one_lot_sl_loss,100,0.000000000001,account_currency,absolute loss")
    "TS-CSV-003" = @("second_fresh_open,false,0,bool,no implicit append", "second_status,FRESH_RUN_COLLISION,0,enum,existing identity rejected")
    "TS-CSV-004" = @("implicit_resume_allowed,false,0,bool,resume is explicit", "checkpoint_required,true,0,bool,checkpoint mandatory", "cursor_required,true,0,bool,cursor mandatory")
    "TS-CSV-005" = @("identity_fields_complete,true,0,bool,all identity dimensions included", "missing_fields,,0,text,blank means none missing")
    "TS-CSV-006" = @("concurrent_writer_open,false,0,bool,exclusive writer", "writer_lock_enforced,true,0,bool,lock evidence")
    "TS-CAP-001" = @("accepted,false,0,bool,pool is full", "status,EVENT_POOL_EXHAUSTED,0,enum,distinct status", "invalid_denominator_count,0,0,count,not a math failure")
    "TS-CAP-002" = @("second_append,false,0,bool,capacity rejected", "capacity_status,PENDING_TICK_CAPACITY_EXHAUSTED,0,enum,distinct status", "dropped_ticks,1,0,count,observed loss", "observable,true,0,bool,not silent")
    "TS-CAP-003" = @("capacity_hits,1,0,count,one overflow", "validation_status,VALIDATION_INVALID,0,enum,fail closed")
    "TS-CURSOR-001" = @("terminated,true,0,bool,no infinite retrieval", "cursor_status,SAME_MSC_PAGE_SATURATED,0,enum,distinct status", "validation_status,VALIDATION_INVALID,0,enum,fail closed")
    "TS-STATUS-001" = @("status,INVALID_TARGET_BUILD,0,enum,not broker target")
    "TS-STATUS-002" = @("invalid_risk_status,INVALID_RISK,0,enum,distinct", "invalid_direction_status,INVALID_DIRECTION,0,enum,distinct", "invalid_tick_size_status,INVALID_TICK_SIZE,0,enum,distinct")
    "TS-DIRECTION-001" = @("direction_name,NONE,0,enum,zero is not short")
    "TS-ORDER-004" = @("deal_count,1,0,count,unique entry deals", "filled_volume,0.04,0.000000000001,lots,no duplicate fill", "duplicate_deals,1,0,count,replay observed")
    "TS-ORDER-005" = @("mismatched_deal_accepted,false,0,bool,identity mismatch rejected", "identity_rejections,1,0,count,rejection observed")
    "TS-ORDER-006" = @("entry_volume,0.04,0.000000000001,lots,entry aggregate", "exit_volume,0.04,0.000000000001,lots,exit aggregate", "entry_deals,1,0,count,separate", "exit_deals,1,0,count,separate")
    "TS-ORDER-007" = @("filled_volume_after_replay,0.04,0.000000000001,lots,idempotent", "deal_count_after_replay,1,0,count,idempotent", "duplicate_deals,1,0,count,replay observed")
    "TS-WATERMARK-001" = @("pending_count,3,0,count,unchanged release semantics", "stale_symbol_count,1,0,count,observable", "lag_observable,true,0,bool,diagnostic")
    "TS-WATERMARK-002" = @("incomplete_frontier,true,0,bool,diagnostic", "validation_status,VALIDATION_INVALID,0,enum,fail closed")
}

$utf8 = [System.Text.UTF8Encoding]::new($false)
foreach ($entry in $definitions.GetEnumerator()) {
    $id = $entry.Key
    $ticksPath = Join-Path $fixtureRoot "${id}_ticks.csv"
    $configPath = Join-Path $fixtureRoot "${id}_config.csv"
    $expectedPath = Join-Path $expectedRoot "${id}_expected.csv"
    foreach ($path in @($ticksPath, $configPath, $expectedPath)) {
        if (Test-Path -LiteralPath $path) { throw "Refusing to overwrite existing Step 11 artifact: $path" }
    }
    [System.IO.File]::WriteAllLines($ticksPath, @(
        "sequence,symbol,time_msc,bid,ask,processing_msc,note",
        "1,EURUSD,999,1.10000,1.10010,999,boundary minus one",
        "2,EURUSD,1000,1.10001,1.10011,1000,boundary equal",
        "3,EURUSD,1001,1.10002,1.10012,1001,boundary plus one"
    ), $utf8)
    [System.IO.File]::WriteAllLines($configPath, @(
        "key,value,unit,note",
        "production_function_used_for_expected,false,bool,independent oracle",
        "oracle_source,docs/research/tick_shock/11_test_oracle_addendum.md,path,Step 11 oracle",
        "blank_sentinel,__BLANK__,text,blank and zero are distinct",
        "zero_sentinel,0,count,blank and zero are distinct"
    ), $utf8)
    [System.IO.File]::WriteAllLines($expectedPath, @("field,expected_value,tolerance,unit,note") + $entry.Value, $utf8)
}
Write-Host "Generated $($definitions.Count) Step 11 fixture/config/expected triplets."
