param(
    [Parameter(Mandatory = $true)]
    [string]$CommitMessage,
    [string[]]$Paths = @(),
    [switch]$AddAllTracked,
    [switch]$SkipPush,
    [switch]$AllowMain
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

git rev-parse --is-inside-work-tree *> $null
if($LASTEXITCODE -ne 0) {
    throw "Current directory is not a git repository."
}

$branch = (git branch --show-current).Trim()
if([string]::IsNullOrWhiteSpace($branch)) {
    throw "Could not determine current branch."
}

if($branch -eq "main" -and -not $AllowMain) {
    throw "Refusing to publish directly from main. Use a task branch or pass -AllowMain intentionally."
}

if($Paths.Count -gt 0) {
    git add -- @Paths
    if($LASTEXITCODE -ne 0) {
        throw "git add failed."
    }
}
elseif($AddAllTracked) {
    git add -u
    if($LASTEXITCODE -ne 0) {
        throw "git add -u failed."
    }
}
else {
    throw "Specify -Paths or use -AddAllTracked."
}

$staged = git diff --cached --name-only
if([string]::IsNullOrWhiteSpace(($staged | Out-String))) {
    throw "No staged changes to commit."
}

git commit -m $CommitMessage
if($LASTEXITCODE -ne 0) {
    throw "git commit failed."
}

if(-not $SkipPush) {
    git push -u origin $branch
    if($LASTEXITCODE -ne 0) {
        throw "git push failed."
    }
}

Write-Output "Published branch: $branch"
