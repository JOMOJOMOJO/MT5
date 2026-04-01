param(
    [string]$SourceBranch = "",
    [string]$TargetBranch = "main",
    [switch]$DeleteLocalSource,
    [switch]$DeleteRemoteSource,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

git rev-parse --is-inside-work-tree *> $null
if($LASTEXITCODE -ne 0) {
    throw "Current directory is not a git repository."
}

$dirty = git status --porcelain
if($dirty) {
    throw "Working tree is dirty. Commit or stash before landing."
}

if([string]::IsNullOrWhiteSpace($SourceBranch)) {
    $SourceBranch = (git branch --show-current).Trim()
}
if([string]::IsNullOrWhiteSpace($SourceBranch)) {
    throw "Could not determine source branch."
}
if($SourceBranch -eq $TargetBranch) {
    throw "Source branch and target branch are the same."
}

$currentBranch = (git branch --show-current).Trim()

if($DryRun) {
    Write-Output "Dry run:"
    Write-Output "  source: $SourceBranch"
    Write-Output "  target: $TargetBranch"
    Write-Output "  delete local source: $($DeleteLocalSource.IsPresent)"
    Write-Output "  delete remote source: $($DeleteRemoteSource.IsPresent)"
    return
}

git fetch origin
if($LASTEXITCODE -ne 0) {
    throw "git fetch origin failed."
}

git switch $TargetBranch
if($LASTEXITCODE -ne 0) {
    throw "git switch $TargetBranch failed."
}

git pull --ff-only origin $TargetBranch
if($LASTEXITCODE -ne 0) {
    throw "git pull --ff-only origin $TargetBranch failed."
}

git merge --no-ff $SourceBranch
if($LASTEXITCODE -ne 0) {
    throw "git merge --no-ff $SourceBranch failed."
}

git push origin $TargetBranch
if($LASTEXITCODE -ne 0) {
    throw "git push origin $TargetBranch failed. The target branch may be protected; switch to PR automation if direct land is blocked."
}

if($DeleteRemoteSource) {
    git push origin --delete $SourceBranch
    if($LASTEXITCODE -ne 0) {
        throw "Target landed, but remote branch deletion failed."
    }
}

if($DeleteLocalSource) {
    git branch -d $SourceBranch
    if($LASTEXITCODE -ne 0) {
        throw "Target landed, but local branch deletion failed."
    }
}

Write-Output "Landed $SourceBranch into $TargetBranch"
