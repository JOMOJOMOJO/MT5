param(
    [string]$HeadBranch,
    [string]$BaseBranch = "main",
    [string]$Title,
    [string]$Body,
    [string]$BodyFile,
    [switch]$Draft,
    [switch]$EnableAutoMerge
)

$ErrorActionPreference = "Stop"

function Resolve-BranchName {
    param([string]$Name)

    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        return $Name
    }

    return (git branch --show-current).Trim()
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    throw "GitHub CLI 'gh' is not installed. Push the branch and stop there, or install gh before using PR automation."
}
$ghPath = $gh.Path

$resolvedHeadBranch = Resolve-BranchName -Name $HeadBranch
if ([string]::IsNullOrWhiteSpace($resolvedHeadBranch)) {
    throw "Could not determine the head branch."
}

if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = "task: $resolvedHeadBranch"
}

$args = @(
    "pr",
    "create",
    "--base", $BaseBranch,
    "--head", $resolvedHeadBranch,
    "--title", $Title
)

if (-not [string]::IsNullOrWhiteSpace($BodyFile)) {
    $args += @("--body-file", $BodyFile)
}
elseif (-not [string]::IsNullOrWhiteSpace($Body)) {
    $args += @("--body", $Body)
}
else {
    $args += @("--body", "Automated Codex PR for $resolvedHeadBranch")
}

if ($Draft) {
    $args += "--draft"
}

& $ghPath @args

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create pull request."
}

if ($EnableAutoMerge) {
    & $ghPath pr merge $resolvedHeadBranch --auto --squash
    if ($LASTEXITCODE -ne 0) {
        throw "Pull request was created, but auto-merge could not be enabled."
    }
}
