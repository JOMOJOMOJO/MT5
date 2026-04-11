param(
    [string]$CommitMessage = "",
    [string[]]$Paths = @(),
    [switch]$AddAllTracked,
    [switch]$AddAllChanges,
    [switch]$SkipPush,
    [ValidateSet("research", "ops", "org", "hotfix", "docs")]
    [string]$NextCategory = "research",
    [string]$NextFamily = "",
    [Parameter(Mandatory = $true)]
    [string]$NextSlug
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-Slug {
    param([Parameter(Mandatory = $true)][string]$Value)
    $normalized = $Value.ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, "[^a-z0-9]+", "-")
    $normalized = $normalized.Trim("-")
    if([string]::IsNullOrWhiteSpace($normalized)) {
        throw "Slug is empty after normalization."
    }
    return $normalized
}

function Invoke-GitChecked {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & git @Arguments
    if($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed."
    }
}

git rev-parse --is-inside-work-tree *> $null
if($LASTEXITCODE -ne 0) {
    throw "Current directory is not a git repository."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$currentBranch = (git branch --show-current).Trim()
if([string]::IsNullOrWhiteSpace($currentBranch)) {
    throw "Could not determine the current branch."
}

$dirtyBefore = git status --porcelain
$performedCheckpoint = $false
$checkpointCommit = ""

if(-not [string]::IsNullOrWhiteSpace($CommitMessage)) {
    if($Paths.Count -gt 0) {
        Invoke-GitChecked add -- @Paths
    }
    elseif($AddAllChanges) {
        Invoke-GitChecked add -A
    }
    elseif($AddAllTracked) {
        Invoke-GitChecked add -u
    }
    else {
        throw "Provide -Paths, -AddAllTracked, or -AddAllChanges when -CommitMessage is used."
    }

    $staged = git diff --cached --name-only
    if([string]::IsNullOrWhiteSpace(($staged | Out-String))) {
        throw "No staged changes to commit."
    }

    Invoke-GitChecked commit -m $CommitMessage
    $performedCheckpoint = $true
    $checkpointCommit = (git rev-parse HEAD).Trim()

    if(-not $SkipPush) {
        Invoke-GitChecked push -u origin $currentBranch
    }
}
elseif(-not [string]::IsNullOrWhiteSpace(($dirtyBefore | Out-String))) {
    throw "Working tree is dirty. Pass -CommitMessage with staging options, or clean the tree before branching."
}

$nextSlugPart = Normalize-Slug -Value $NextSlug
$datePart = Get-Date -Format "yyyy-MM-dd"
$familyPart = ""
if(-not [string]::IsNullOrWhiteSpace($NextFamily)) {
    $familyPart = (Normalize-Slug -Value $NextFamily) + "/"
}
$nextBranch = "$NextCategory/$familyPart$datePart-$nextSlugPart"

$existingBranch = (git branch --list $nextBranch).Trim()
if(-not [string]::IsNullOrWhiteSpace($existingBranch)) {
    throw "Branch '$nextBranch' already exists."
}

Invoke-GitChecked switch -c $nextBranch

$logPath = Join-Path $repoRoot ".company\git\branch-rotation-log.jsonl"
$logDirectory = Split-Path -Parent $logPath
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$entry = [ordered]@{
    timestamp = (Get-Date).ToString("s")
    from_branch = $currentBranch
    to_branch = $nextBranch
    checkpoint_commit = $checkpointCommit
    checkpoint_performed = $performedCheckpoint
    commit_message = $CommitMessage
}
($entry | ConvertTo-Json -Compress) | Add-Content -Path $logPath -Encoding utf8

Write-Output "Started next branch: $nextBranch"
