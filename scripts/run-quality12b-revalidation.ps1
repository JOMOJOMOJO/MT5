param(
    [string]$PackagePath = 'reports\qa\quality12b_revalidation_20261005',
    [string]$SourceInstall = 'C:\Program Files\XMTrading MT5 - 2',
    [string]$SourceDataRoot = "$env:APPDATA\MetaQuotes\Terminal\D232275B22422903BD477FB48B858FBA",
    [ValidateSet('Reproduce','All')][string]$Stage = 'All',
    [ValidateRange(60,86400)][int]$TimeoutSecondsPerRun = 7200,
    [switch]$CopyCachedTicks,
    [switch]$SpreadDiagnosis,
    [switch]$ContextResearch,
    [switch]$BaselineRecheck,
    [switch]$RelativeSearch,
    [switch]$M5ContextResearch,
    [switch]$MultiTFDiagnostics,
    [switch]$IchimokuDiagnostics,
    [switch]$ShortIchimoku,
    [string]$DiagnosticRunId = '',
    [switch]$Execute
)
# No terminal, editor, config or account writes occur without -Execute.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$package = if ([IO.Path]::IsPathRooted($PackagePath)) { [IO.Path]::GetFullPath($PackagePath) } else { Join-Path $repo $PackagePath }
$python = (Get-Command python -ErrorAction Stop).Source
& $python (Join-Path $repo 'tools\quality12b\prepare_revalidation.py') --out $package --check
if ($LASTEXITCODE -ne 0) { throw 'Frozen package verification failed' }
$manifest = Get-Content -LiteralPath (Join-Path $package 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$isDiagnosticPackage = $null -ne $manifest.PSObject.Properties['purpose'] -and $manifest.purpose -eq 'SPREAD_DIAGNOSIS_ONLY'
if ([bool]$SpreadDiagnosis -ne [bool]$isDiagnosticPackage) { throw 'SpreadDiagnosis is permitted only with its frozen diagnostic package, and is mandatory for that package.' }
$isContextPackage = $null -ne $manifest.PSObject.Properties['purpose'] -and $manifest.purpose -eq 'CONTEXT_EXIT_RESEARCH'
if ([bool]$ContextResearch -ne [bool]$isContextPackage) { throw 'ContextResearch requires its matching frozen research package' }
$isBaselinePackage = $null -ne $manifest.PSObject.Properties['purpose'] -and $manifest.purpose -eq 'BASELINE_RECHECK'
if ([bool]$BaselineRecheck -ne [bool]$isBaselinePackage) { throw 'BaselineRecheck requires its matching frozen execution audit package' }
$isRelativePackage = $null -ne $manifest.PSObject.Properties['purpose'] -and $manifest.purpose -eq 'RELATIVE_CONTINUATION_SEARCH'
if ([bool]$RelativeSearch -ne [bool]$isRelativePackage) { throw 'RelativeSearch requires its matching frozen parameter study package' }
$isM5ContextPackage = $null -ne $manifest.PSObject.Properties['purpose'] -and $manifest.purpose -eq 'M5_M15_CONTEXT_RESEARCH'
if ([bool]$M5ContextResearch -ne [bool]$isM5ContextPackage) { throw 'M5ContextResearch requires its matching frozen package' }
$isMultiTFPackage = $null -ne $manifest.PSObject.Properties['purpose'] -and $manifest.purpose -eq 'M5_MULTITF_DIAGNOSTICS'
if ([bool]$MultiTFDiagnostics -ne [bool]$isMultiTFPackage) { throw 'MultiTFDiagnostics requires its matching frozen package' }
$isIchimokuPackage = $null -ne $manifest.PSObject.Properties['purpose'] -and $manifest.purpose -eq 'M5_ICHIMOKU_DIAGNOSTICS'
if ([bool]$IchimokuDiagnostics -ne [bool]$isIchimokuPackage) { throw 'IchimokuDiagnostics requires its matching frozen package' }
$isShortIchimokuPackage = $null -ne $manifest.PSObject.Properties['purpose'] -and $manifest.purpose -eq 'M5_SHORT_ICHIMOKU'
if ([bool]$ShortIchimoku -ne [bool]$isShortIchimokuPackage) { throw 'ShortIchimoku requires its matching frozen package' }
$IchimokuDiagnostics = $IchimokuDiagnostics -or $ShortIchimoku
$MultiTFDiagnostics = $MultiTFDiagnostics -or $IchimokuDiagnostics
$M5ContextResearch = $M5ContextResearch -or $MultiTFDiagnostics
if ($M5ContextResearch) {
    $m5Analyzer = Join-Path $repo 'tools\quality12b\analyze_m5_context.py'
    if ($MultiTFDiagnostics) { $m5Analyzer = Join-Path $repo 'tools\quality12b\analyze_multitf_diagnostics.py' }
    if ($IchimokuDiagnostics) { $m5Analyzer = Join-Path $repo 'tools\quality12b\analyze_ichimoku_diagnostics.py' }
    if ($ShortIchimoku) { $m5Analyzer = Join-Path $repo 'tools\quality12b\analyze_short_ichimoku.py' }
    if ((Get-FileHash -LiteralPath $m5Analyzer).Hash.ToLowerInvariant() -ne $manifest.analysis_sha256) { throw 'M5 analysis differs from frozen plan' }
}
if ($ContextResearch) {
    $contextAnalyzer = Join-Path $repo 'tools\quality12b\analyze_context_research.py'
    if ((Get-FileHash -LiteralPath $contextAnalyzer).Hash.ToLowerInvariant() -ne $manifest.context_analysis_sha256) { throw 'Context analysis differs from frozen specification' }
}
$analyzer = Join-Path $repo 'tools\quality12b\analyze_reports.py'
if (-not (Test-Path -LiteralPath $analyzer)) { throw 'Report analyzer missing' }
$comparator = Join-Path $repo 'tools\quality12b\compare_reproduction.py'
if (-not (Test-Path -LiteralPath $comparator)) { throw 'Reproduction comparator missing' }
foreach ($name in @('terminal64.exe','metatester64.exe','MetaEditor64.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceInstall $name))) { throw "Missing source binary: $name" }
}
$commonSource = Join-Path $SourceDataRoot 'config\common.ini'
$accountFile = Join-Path $SourceDataRoot 'config\accounts.dat'
if (-not (Test-Path -LiteralPath $accountFile)) { throw 'Existing authorized account context missing' }
$sourceCommon = Get-Content -LiteralPath $commonSource -Raw
$serverMatch = [regex]::Match($sourceCommon, '(?m)^Server=(.+)\r?$')
$loginMatch = [regex]::Match($sourceCommon, '(?m)^Login=(\d+)\s*$')
if (-not $serverMatch.Success -or $serverMatch.Groups[1].Value.Trim() -ne $manifest.expected_server) {
    throw 'Source server differs from historical Vantage reference. Select a matching SourceDataRoot; do not mix brokers.'
}
if (-not $loginMatch.Success) { throw 'Source account login is not available locally; no terminal started' }
$sdk = Join-Path $SourceDataRoot 'MQL5\Include'
if (-not (Test-Path -LiteralPath (Join-Path $sdk 'Trade\Trade.mqh'))) { throw 'MQL5 standard Trade include missing' }
$runs = @($manifest.runs | Where-Object { $Stage -eq 'All' -or $_.stage -eq 'Reproduce' })
if ($DiagnosticRunId) {
    if (-not $SpreadDiagnosis) { throw 'A single diagnostic run can only be selected in SpreadDiagnosis mode' }
    $runs = @($runs | Where-Object { $_.run_id -ceq $DiagnosticRunId })
    if ($runs.Count -ne 1) { throw 'DiagnosticRunId must name exactly one frozen manifest run' }
}
# Same frozen periods/inputs; validate recent history before probing scarce older ticks.
if (-not $RelativeSearch -and -not $M5ContextResearch) {
    $runs = @($runs | Sort-Object @{Expression={if($_.stage -eq 'Reproduce'){0}else{1}}}, @{Expression={if($_.stage -eq 'Reproduce'){$_.date_from}else{''}}}, @{Expression={$_.date_from};Descending=$true})
}
Write-Host "Package verified. Stage=$Stage runs=$($runs.Count), USDJPY/$($manifest.timeframe), requested real ticks, native optimization OFF."
Write-Host 'Reproduction mismatches stop extension. Existing MT5 processes are left running.'
if ($SpreadDiagnosis) { Write-Host 'Forensic run: mixed ticks retained and labelled to reproduce original conditions, NOT a real-tick quality approval. Quotes and trade parity will be audited.' }
if ($ContextResearch) { Write-Host 'Context research: baseline entries unchanged; quality-labelled mixed/generated history retained for retrospective screening. No promotion.' }
if (-not $Execute) {
    $runs | Format-Table run_id,date_from,date_to,label -AutoSize
    Write-Host 'CHECK ONLY: nothing launched. Use the supplied RUN_ALL.cmd to execute.'
    return
}

$batchId = (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,8)
$isolatedBase = Join-Path $env:LOCALAPPDATA 'CodexMT5Quality12b'
$terminalRoot = Join-Path $isolatedBase $batchId
$output = Join-Path $package ('runs\' + $batchId)
$lockPath = Join-Path $package 'runner.lock'
$lock = $null
$terminalProcess = $null
$editorProcess = $null
$currentRun = 'bootstrap'
$privateLogin = $loginMatch.Groups[1].Value

function Redact([string]$Text) {
    $result = $Text.Replace($privateLogin, '[ACCOUNT]')
    return [regex]::Replace($result, '(?im)(password|login|account)\s*[=:]\s*\S+', '$1=[REDACTED]')
}
function SaveJson($Object, [string]$Path) {
    $Object | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $Path -Encoding UTF8
}
function Log([string]$Text) {
    $line = (Get-Date -Format 's') + ' ' + (Redact $Text)
    Write-Host $line
    Add-Content -LiteralPath (Join-Path $output 'runner.log') -Value $line -Encoding UTF8
}
function CheckChildStopped($Process, [int]$Seconds) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while (-not $Process.WaitForExit(1000)) {
        if ($clock.Elapsed.TotalSeconds -gt $Seconds) { throw 'Owned subprocess timed out; batch will stop' }
    }
}
function AssertOwnedPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith([IO.Path]::GetFullPath($terminalRoot).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Destination escaped dedicated terminal root'
    }
}
function ArchiveLogs([datetime]$Since, [string]$Destination) {
    foreach ($base in @((Join-Path $terminalRoot 'logs'), (Join-Path $terminalRoot 'Tester'))) {
        if (Test-Path -LiteralPath $base) {
            foreach ($file in Get-ChildItem -LiteralPath $base -Filter '*.log' -File -Recurse | Where-Object {$_.LastWriteTimeUtc -ge $Since.AddSeconds(-2)}) {
                $relative = $file.FullName.Substring($terminalRoot.Length+1)
                $target = Join-Path $Destination ('journals\' + $relative)
                New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
                Redact ([IO.File]::ReadAllText($file.FullName)) | Set-Content -LiteralPath $target -Encoding UTF8
            }
        }
    }
}

try {
    # Exclusive file creation prevents two runners touching the same package.
    $lock = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    if (Test-Path -LiteralPath $terminalRoot) { throw 'Unique terminal root already exists' }
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    foreach ($dir in @('config','MQL5\Experts\Quality12bQA','MQL5\Profiles\Tester','MQL5\Include')) {
        New-Item -ItemType Directory -Path (Join-Path $terminalRoot $dir) -Force | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $terminalRoot 'QUALITY12B_RESEARCH_ONLY.txt') -Value $batchId -Encoding ASCII
    foreach ($name in @('terminal64.exe','metatester64.exe','MetaEditor64.exe')) {
        Copy-Item -LiteralPath (Join-Path $SourceInstall $name) -Destination (Join-Path $terminalRoot $name)
    }
    # Only cached account/server context. No charts, profiles or live EA attachments.
    foreach ($name in @('accounts.dat','servers.dat')) {
        $source = Join-Path $SourceDataRoot ('config\'+$name)
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $terminalRoot ('config\'+$name)) }
    }
    Get-ChildItem -LiteralPath $sdk | Copy-Item -Destination (Join-Path $terminalRoot 'MQL5\Include') -Recurse
    $baseSource = Join-Path $SourceDataRoot ('bases\'+$manifest.expected_server)
    foreach ($item in @('symbols','history\USDJPY')) {
        $source = Join-Path $baseSource $item
        $target = Join-Path $terminalRoot ('bases\'+$manifest.expected_server+'\'+$item)
        if (Test-Path -LiteralPath $source) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Recurse
        }
    }
    if ($CopyCachedTicks) {
        $source = Join-Path $baseSource 'ticks\USDJPY'
        if (Test-Path -LiteralPath $source) {
            $target = Join-Path $terminalRoot ('bases\'+$manifest.expected_server+'\ticks\USDJPY')
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Recurse
        }
    }
    $privateCommon = "[Common]`r`nLogin=$privateLogin`r`nServer=$($manifest.expected_server)`r`n"
    $disabledExperts = "[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n"
    ($privateCommon + $disabledExperts) | Set-Content -LiteralPath (Join-Path $terminalRoot 'config\common.ini') -Encoding ASCII
    $sourceTarget = Join-Path $terminalRoot 'MQL5\Experts\Quality12bQA\quality12b_snapshot.mq5'
    AssertOwnedPath $sourceTarget
    Copy-Item -LiteralPath (Join-Path $package 'frozen\quality12b_snapshot.mq5') -Destination $sourceTarget
    if ($BaselineRecheck) {
        $moduleTarget = Join-Path $terminalRoot 'MQL5\Experts\Include\Quality12b'
        AssertOwnedPath $moduleTarget
        New-Item -ItemType Directory -Path $moduleTarget -Force | Out-Null
        Get-ChildItem -LiteralPath (Join-Path $package 'frozen\Quality12b') -Filter '*.mqh' -File | Copy-Item -Destination $moduleTarget
    }
    $sdkHashes = @(Get-ChildItem -LiteralPath (Join-Path $terminalRoot 'MQL5\Include') -File -Recurse | ForEach-Object {
        [ordered]@{path=$_.FullName.Substring($terminalRoot.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    })
    SaveJson ([ordered]@{batch_id=$batchId;stage=$Stage;terminal_root=$terminalRoot;source_data_root=$SourceDataRoot;expected_server=$manifest.expected_server;input_count=$manifest.input_count;source_sha256=$manifest.source_sha256;script_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash;analyzer_sha256=(Get-FileHash -LiteralPath $analyzer).Hash;comparator_sha256=(Get-FileHash -LiteralPath $comparator).Hash;run_order=@($runs.run_id);sdk=$sdkHashes}) (Join-Path $output 'provenance.json')
    SaveJson ([ordered]@{status='COMPILING';batch_id=$batchId;output=$output}) (Join-Path $output 'status.json')
    $compileLog = Join-Path $output 'compile.log'
    Log 'Compiling frozen source only in dedicated terminal; no EX5 synchronization.'
    $editorProcess = Start-Process -FilePath (Join-Path $terminalRoot 'MetaEditor64.exe') -ArgumentList '/portable',('/compile:"'+$sourceTarget+'"'),('/log:"'+$compileLog+'"') -WindowStyle Hidden -PassThru
    CheckChildStopped $editorProcess 180
    $editorProcess = $null
    $binary = [IO.Path]::ChangeExtension($sourceTarget,'.ex5')
    if (-not (Test-Path -LiteralPath $compileLog) -or -not (Test-Path -LiteralPath $binary)) { throw 'Fresh compile artifacts missing' }
    if ((Get-Content -LiteralPath $compileLog -Raw) -notmatch 'Result:\s+0 errors,\s+0 warnings') { throw 'Compile error/warning; see compile.log' }
    Copy-Item -LiteralPath $binary -Destination (Join-Path $output 'quality12b_snapshot.ex5')
    $values = Get-Content -LiteralPath (Join-Path $package 'frozen\inputs.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($run in $runs) {
        $currentRun = $run.run_id
        $runTimeframe = if ($null -ne $run.PSObject.Properties['timeframe']) { [string]$run.timeframe } else { [string]$manifest.timeframe }
        if ($runTimeframe -notin @('M5','M15')) { throw 'Unexpected timeframe for this runner' }
        $runOut = Join-Path $output $currentRun
        New-Item -ItemType Directory -Path $runOut | Out-Null
        $tag = 'q12_'+$batchId+'_'+$currentRun
        $telemetry = $tag+'_telemetry.csv'
        $operational = @{InpTelemetryFileName=$telemetry;InpOperatorCommandFile=$tag+'_operator.txt';InpStatusFileName=$tag+'_status.txt'}
        if (($RelativeSearch -or $M5ContextResearch) -and $null -ne $run.PSObject.Properties['overrides']) {
            foreach ($prop in $run.overrides.PSObject.Properties) {
                if ($null -eq $values.PSObject.Properties[$prop.Name]) { throw "Unknown frozen search input: $($prop.Name)" }
                $operational[$prop.Name] = [string]$prop.Value
            }
        }
        $lines = @($values.PSObject.Properties | ForEach-Object {
            $value = if ($operational.ContainsKey($_.Name)) { $operational[$_.Name] } else { $_.Value }
            $_.Name+'='+$value
        })
        $setName = $tag+'.set'
        $setTarget = Join-Path $terminalRoot ('MQL5\Profiles\Tester\'+$setName)
        $lines | Set-Content -LiteralPath $setTarget -Encoding ASCII
        Copy-Item -LiteralPath $setTarget -Destination (Join-Path $runOut 'inputs.set')
        $body = $disabledExperts + @"
[Tester]
Expert=Quality12bQA\quality12b_snapshot.ex5
ExpertParameters=$setName
Symbol=USDJPY
Period=$runTimeframe
Model=4
ExecutionMode=0
Optimization=0
FromDate=$($run.date_from)
ToDate=$($run.date_to)
Deposit=10000
Currency=USD
Leverage=100
UseLocal=1
UseRemote=0
UseCloud=0
Port=39051
Visual=0
ReplaceReport=0
ShutdownTerminal=1
Report=$tag
"@
        $ini = Join-Path $terminalRoot ($tag+'.ini')
        ($privateCommon+$body) | Set-Content -LiteralPath $ini -Encoding ASCII
        $body | Set-Content -LiteralPath (Join-Path $runOut 'tester_public.ini') -Encoding ASCII
        SaveJson ([ordered]@{status='RUNNING';batch_id=$batchId;run_id=$currentRun;output=$output}) (Join-Path $output 'status.json')
        $started = [datetime]::UtcNow
        Log ("Starting $currentRun $($run.date_from)..$($run.date_to)")
        $terminalExe = Join-Path $terminalRoot 'terminal64.exe'
        if (Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $terminalExe}) { throw 'Dedicated terminal already running' }
        $terminalProcess = Start-Process -FilePath $terminalExe -ArgumentList '/portable',('/config:"'+$ini+'"') -WindowStyle Hidden -PassThru
        CheckChildStopped $terminalProcess $TimeoutSecondsPerRun
        $terminalProcess = $null
        ArchiveLogs $started $runOut
        $report = Join-Path $terminalRoot ($tag+'.htm')
        if (-not (Test-Path -LiteralPath $report)) { throw 'No tester report. Inspect journals: account, symbol, or real-tick history may be unavailable.' }
        if ((Get-Item -LiteralPath $report).LastWriteTimeUtc -lt $started) { throw 'Stale report refused' }
        Copy-Item -LiteralPath $report -Destination (Join-Path $runOut 'report.htm')
        # Windows PowerShell Copy-Item may reject valid destination paths > 260 chars.
        # Keep original image names for HTML links; extended paths preserve report bytes.
        foreach ($reportImage in Get-ChildItem -LiteralPath $terminalRoot -File -Filter ($tag+'*.png')) {
            $imageTarget = Join-Path $runOut $reportImage.Name
            [IO.File]::Copy(('\\?\'+$reportImage.FullName), ('\\?\'+[IO.Path]::GetFullPath($imageTarget)), $false)
        }
        $commonFile = Join-Path $env:APPDATA ('MetaQuotes\Terminal\Common\Files\'+$telemetry)
        if (Test-Path -LiteralPath $commonFile) { Copy-Item -LiteralPath $commonFile -Destination (Join-Path $runOut 'telemetry.csv') }
        $qualityArgs = @('--require-real-ticks')
        if ($BaselineRecheck) { $qualityArgs = @() }
        if ($RelativeSearch -or $M5ContextResearch) {
            $qualityArgs = @() # Retrospective, quality-labelled study, not a real-tick promotion.
            $funnelFile = $commonFile + '.funnel.csv'
            if (-not (Test-Path -LiteralPath $funnelFile)) { throw 'Relative study funnel missing' }
            Copy-Item -LiteralPath $funnelFile -Destination (Join-Path $runOut 'funnel.csv')
        }
        if ($M5ContextResearch) {
            $contextSuffixes = @('m15')
            if ($MultiTFDiagnostics) { $contextSuffixes = @('context','path') }
            if ($IchimokuDiagnostics) { $contextSuffixes = @('context','path','ichi','ichi_bars') }
            foreach ($suffix in $contextSuffixes) {
                $observerFile = $commonFile + '.' + $suffix + '.csv'
                if (-not (Test-Path -LiteralPath $observerFile)) { throw "Context CSV missing: $suffix" }
                Copy-Item -LiteralPath $observerFile -Destination (Join-Path $runOut ($suffix+'.csv'))
            }
        }
        if ($SpreadDiagnosis) {
            $qualityArgs = @()
            $spreadFile = $commonFile + '.spread.csv'
            if (-not (Test-Path -LiteralPath $spreadFile)) { throw 'Spread audit CSV missing; diagnosis cannot proceed' }
            Copy-Item -LiteralPath $spreadFile -Destination (Join-Path $runOut 'spread.csv')
        }
        if ($ContextResearch) {
            $qualityArgs = @()
            foreach ($suffix in @('context','path')) {
                $observerFile = $commonFile + '.' + $suffix + '.csv'
                if (-not (Test-Path -LiteralPath $observerFile)) { throw "Research observer CSV missing: $suffix" }
                Copy-Item -LiteralPath $observerFile -Destination (Join-Path $runOut ($suffix+'.csv'))
            }
        }
        & $python $analyzer --report (Join-Path $runOut 'report.htm') --out $runOut --expect-symbol USDJPY --expect-timeframe $runTimeframe --expect-from $run.date_from --expect-to $run.date_to @qualityArgs --journal-dir (Join-Path $runOut 'journals\Tester')
        if ($LASTEXITCODE -ne 0) { throw 'Report identity/quality/trade reconciliation failed' }
        $metrics = Get-Content -LiteralPath (Join-Path $runOut 'metrics.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($metrics.report.broker -ne $manifest.expected_broker) { throw 'Reported broker differs from reference' }
        # Native input echo must match the full frozen runtime preset, not only the subset in the old .set.
        foreach ($line in $lines) {
            $key,$expected = $line -split '=',2
            $prop = $metrics.report.inputs.PSObject.Properties[$key]
            if ($null -eq $prop -or [string]$prop.Value -cne $expected) { throw "Tester input echo mismatch: $key" }
        }
        if ($M5ContextResearch) {
            $parityArgs = @()
            if ($null -ne $run.PSObject.Properties['reference_report']) {
                $referencePath = Join-Path $repo $run.reference_report
                if ((Get-FileHash -LiteralPath $referencePath).Hash.ToLowerInvariant() -ne $run.reference_sha256) { throw 'M15 control reference changed' }
                $parityArgs = @('--reference',$referencePath)
            }
            if ($ShortIchimoku -and $null -ne $run.PSObject.Properties['reference_run_id']) {
                if ($run.reference_run_id -notmatch '^[a-z0-9_]+$') { throw 'Invalid internal reference run ID' }
                $referencePath = Join-Path (Join-Path $output $run.reference_run_id) 'report.htm'
                if (-not (Test-Path -LiteralPath $referencePath)) { throw 'Short observer control must finish first' }
                $parityArgs = @('--reference',$referencePath)
            }
            & $python $m5Analyzer --run $runOut @parityArgs
            if ($LASTEXITCODE -ne 0) { throw 'M5/M15 causal, risk, context or observer-parity audit failed' }
        }
        if ($SpreadDiagnosis) {
            $referencePath = Join-Path $repo $run.reference_report
            if ((Get-FileHash -LiteralPath $referencePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $run.reference_sha256) { throw 'Spread diagnostic reference changed' }
            & $python (Join-Path $repo 'tools\quality12b\analyze_spread_diagnosis.py') --run $runOut --reference $referencePath
            if ($LASTEXITCODE -ne 0) { throw 'Spread diagnostics/parity reconciliation failed; inspect spread_diagnosis.json' }
        }
        if ($ContextResearch) {
            $referencePath = Join-Path $repo $run.reference_report
            if ((Get-FileHash -LiteralPath $referencePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $run.reference_sha256) { throw 'Research reference report changed' }
            & $python (Join-Path $repo 'tools\quality12b\analyze_context_research.py') --run $runOut --reference $referencePath
            if ($LASTEXITCODE -ne 0) { throw 'Context research baseline/causality audit failed' }
        }
        if ($BaselineRecheck) {
            $referencePath = Join-Path $repo $run.reference_report
            if ((Get-FileHash -LiteralPath $referencePath).Hash.ToLowerInvariant() -ne $run.reference_sha256) { throw 'Baseline control reference changed' }
            & $python $comparator --reference $referencePath --candidate (Join-Path $runOut 'report.htm') --out (Join-Path $runOut 'execution_parity.json') --allow-generated-history-for-parity
            if ($LASTEXITCODE -ne 0) { throw 'Refactored baseline differs from research execution; inspect execution_parity.json' }
        }
        $summaryRow = [pscustomobject]@{run_id=$currentRun;from=$run.date_from;to=$run.date_to;label=$run.label;trades=$metrics.calculated.trade_count;net=$metrics.calculated.net_profit;pf=$metrics.calculated.profit_factor;report=(Join-Path $runOut 'report.htm')}
        $summaryRow | Export-Csv -LiteralPath (Join-Path $output 'summary.csv') -NoTypeInformation -Append:(Test-Path -LiteralPath (Join-Path $output 'summary.csv')) -Encoding UTF8
        if ($run.stage -eq 'Reproduce') {
            $refIndex = if ($currentRun -eq 'reproduce_train') { 0 } else { 1 }
            $refSpec = $manifest.reference_reports[$refIndex]
            $refPath = Join-Path $repo $refSpec.path
            if ((Get-FileHash -LiteralPath $refPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $refSpec.sha256) { throw 'Historical reference report changed' }
            & $python $comparator --reference $refPath --candidate (Join-Path $runOut 'report.htm') --out (Join-Path $runOut 'reproduction.json')
            if ($LASTEXITCODE -ne 0) { throw 'REPRODUCTION_MISMATCH: unchanged execution/size/SL/TP/profit required; extension stopped.' }
        }
        Log "Completed $currentRun; artifacts saved."
    }
    if ($ContextResearch) {
        & $python (Join-Path $repo 'tools\quality12b\analyze_context_research.py') --batch $output
        if ($LASTEXITCODE -ne 0) { throw 'Context aggregate analysis failed' }
    }
    if ($RelativeSearch) {
        $relativeAnalyzer = Join-Path $repo 'tools\quality12b\analyze_relative_search.py'
        if ((Get-FileHash -LiteralPath $relativeAnalyzer).Hash.ToLowerInvariant() -ne $manifest.analysis_sha256) { throw 'Relative analysis differs from frozen plan' }
        & $python $relativeAnalyzer --batch $output --package $package
        if ($LASTEXITCODE -ne 0) { throw 'Relative search analysis failed' }
    }
    if ($M5ContextResearch) {
        & $python $m5Analyzer --batch $output --package $package
        if ($LASTEXITCODE -ne 0) { throw 'M5/M15 policy aggregation failed' }
    }
    SaveJson ([ordered]@{status='COMPLETED';batch_id=$batchId;completed_runs=$runs.Count;output=$output;promotion='NOT_ASSESSED'}) (Join-Path $output 'status.json')
    Log 'Batch complete. Reports are evidence only; no strategy promotion performed.'
} catch {
    if (Test-Path -LiteralPath $output) {
        SaveJson ([ordered]@{status='FAILED';batch_id=$batchId;run_id=$currentRun;reason=(Redact $_.Exception.Message);output=$output}) (Join-Path $output 'status.json')
        Log ('Stopped: '+$_.Exception.Message)
    }
    throw
} finally {
    # Only processes started by THIS runner may be terminated; never any installed terminal.
    foreach ($child in @($terminalProcess,$editorProcess)) {
        if ($null -ne $child -and -not $child.HasExited) { $child.Kill(); $child.WaitForExit(10000) | Out-Null }
    }
    if ($null -ne $lock) { $lock.Dispose(); Remove-Item -LiteralPath $lockPath }
}
