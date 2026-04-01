param(
    [ValidateSet("research", "ops", "org", "hotfix", "docs")]
    [string]$Category = "research",
    [string]$Family = "",
    [Parameter(Mandatory = $true)]
    [string]$Slug,
    [string]$BaseRef = ""
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

git rev-parse --is-inside-work-tree *> $null
if($LASTEXITCODE -ne 0) {
    throw "Current directory is not a git repository."
}

$slugPart = Normalize-Slug -Value $Slug
$datePart = Get-Date -Format "yyyy-MM-dd"
$familyPart = ""
if(-not [string]::IsNullOrWhiteSpace($Family)) {
    $familyPart = (Normalize-Slug -Value $Family) + "/"
}

if(-not [string]::IsNullOrWhiteSpace($BaseRef)) {
    $dirty = git status --porcelain
    if($dirty) {
        throw "Working tree is dirty. Commit or stash before switching base refs."
    }
    git fetch origin
    if($LASTEXITCODE -ne 0) {
        throw "git fetch origin failed."
    }
    git switch $BaseRef
    if($LASTEXITCODE -ne 0) {
        throw "git switch $BaseRef failed."
    }
}

$branchName = "$Category/$familyPart$datePart-$slugPart"
git switch -c $branchName
if($LASTEXITCODE -ne 0) {
    throw "Failed to create branch $branchName."
}

Write-Output "Created branch: $branchName"
