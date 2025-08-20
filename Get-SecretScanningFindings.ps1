#Requires -Version 5.1

<#
.SYNOPSIS
    Retrieves secret scanning findings from a GitHub repository and prepares them for work item creation.

.DESCRIPTION
    This script fetches secret scanning alerts from a specified GitHub repository using the GitHub API
    and formats them for logging as work items. The output includes file names, secret types, and 
    direct links to the findings for easy remediation.

.PARAMETER RepositoryOwner
    The GitHub username or organization that owns the repository.

.PARAMETER RepositoryName
    The name of the GitHub repository to scan for secret findings.

.PARAMETER GitHubToken
    Personal Access Token for GitHub API authentication. Requires 'security_events' scope.
    If not provided, the script will look for the GITHUB_TOKEN environment variable.

.PARAMETER OutputFormat
    The format for output. Valid values are 'Console', 'JSON', 'CSV'.
    Default is 'Console'.

.PARAMETER IncludeResolved
    Include resolved/closed secret scanning alerts in the results.
    Default is false (only open alerts).

.EXAMPLE
    .\Get-SecretScanningFindings.ps1 -RepositoryOwner "myorg" -RepositoryName "myrepo" -GitHubToken "ghp_xxxx"
    
    Retrieves open secret scanning findings for myorg/myrepo repository.

.EXAMPLE
    .\Get-SecretScanningFindings.ps1 -RepositoryOwner "myorg" -RepositoryName "myrepo" -OutputFormat "JSON"
    
    Retrieves findings and outputs them in JSON format (uses GITHUB_TOKEN environment variable).

.NOTES
    Author: GitHub Copilot
    Version: 1.0
    Requires GitHub Personal Access Token with 'security_events' scope.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryOwner,
    
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName,
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Console', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Console',
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeResolved
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    if ($Host.UI.RawUI.ForegroundColor) {
        Write-Host $Message -ForegroundColor $Color
    } else {
        Write-Output $Message
    }
}

# Function to validate GitHub token
function Test-GitHubToken {
    param([string]$Token)
    
    try {
        $headers = @{
            'Authorization' = "token $Token"
            'Accept' = 'application/vnd.github.v3+json'
        }
        
        $response = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers -Method Get
        return $true
    }
    catch {
        return $false
    }
}

# Function to get secret scanning alerts
function Get-SecretScanningAlerts {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Token,
        [bool]$IncludeResolved
    )
    
    $headers = @{
        'Authorization' = "token $Token"
        'Accept' = 'application/vnd.github.v3+json'
    }
    
    $uri = "https://api.github.com/repos/$Owner/$Repo/secret-scanning/alerts"
    $allAlerts = @()
    $page = 1
    
    do {
        try {
            $queryParams = @{
                'page' = $page
                'per_page' = 100
            }
            
            if (-not $IncludeResolved) {
                $queryParams['state'] = 'open'
            }
            
            $queryString = ($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '&'
            $pageUri = "$uri?$queryString"
            
            Write-Verbose "Fetching page $page from: $pageUri"
            $response = Invoke-RestMethod -Uri $pageUri -Headers $headers -Method Get
            
            if ($response -and $response.Count -gt 0) {
                $allAlerts += $response
                $page++
            } else {
                break
            }
        }
        catch {
            if ($_.Exception.Response.StatusCode -eq 404) {
                Write-Warning "Repository not found or secret scanning not enabled for $Owner/$Repo"
                return @()
            }
            elseif ($_.Exception.Response.StatusCode -eq 403) {
                Write-Error "Access denied. Ensure your GitHub token has 'security_events' scope and you have access to this repository."
                return @()
            }
            else {
                Write-Error "Failed to retrieve secret scanning alerts: $($_.Exception.Message)"
                return @()
            }
        }
    } while ($true)
    
    return $allAlerts
}

# Function to format findings for work items
function Format-FindingsForWorkItems {
    param(
        [array]$Alerts,
        [string]$Owner,
        [string]$Repo
    )
    
    $workItems = @()
    
    foreach ($alert in $Alerts) {
        $workItem = [PSCustomObject]@{
            AlertNumber = $alert.number
            Title = "Secret Found: $($alert.secret_type_display_name)"
            Description = "Secret scanning has detected a $($alert.secret_type_display_name) in the repository."
            SecretType = $alert.secret_type_display_name
            State = $alert.state
            FileName = if ($alert.locations -and $alert.locations.Count -gt 0) { 
                $alert.locations[0].path 
            } else { 
                "Location not available" 
            }
            LineNumber = if ($alert.locations -and $alert.locations.Count -gt 0) { 
                $alert.locations[0].start_line 
            } else { 
                $null 
            }
            GitHubAlertUrl = $alert.html_url
            CreatedAt = $alert.created_at
            UpdatedAt = $alert.updated_at
            Repository = "$Owner/$Repo"
            Priority = switch ($alert.secret_type) {
                { $_ -match '(password|private.*key|secret.*key|token)' } { 'High' }
                { $_ -match '(api.*key|access.*key)' } { 'Medium' }
                default { 'Low' }
            }
            Tags = @("security", "secret-scanning", $alert.secret_type)
        }
        $workItems += $workItem
    }
    
    return $workItems
}

# Main execution
try {
    Write-ColorOutput "GitHub Secret Scanning Findings Retrieval Tool" -Color Cyan
    Write-ColorOutput "================================================" -Color Cyan
    Write-Output ""
    
    # Validate GitHub token
    if (-not $GitHubToken) {
        $GitHubToken = $env:GITHUB_TOKEN
        if (-not $GitHubToken) {
            Write-Error "GitHub token not provided. Use -GitHubToken parameter or set GITHUB_TOKEN environment variable."
            exit 1
        }
    }
    
    Write-ColorOutput "Validating GitHub token..." -Color Yellow
    if (-not (Test-GitHubToken -Token $GitHubToken)) {
        Write-Error "Invalid GitHub token or insufficient permissions. Ensure token has 'security_events' scope."
        exit 1
    }
    Write-ColorOutput "GitHub token validated successfully." -Color Green
    Write-Output ""
    
    # Fetch secret scanning alerts
    Write-ColorOutput "Fetching secret scanning alerts for $RepositoryOwner/$RepositoryName..." -Color Yellow
    $alerts = Get-SecretScanningAlerts -Owner $RepositoryOwner -Repo $RepositoryName -Token $GitHubToken -IncludeResolved $IncludeResolved.IsPresent
    
    if ($alerts.Count -eq 0) {
        Write-ColorOutput "No secret scanning alerts found for $RepositoryOwner/$RepositoryName" -Color Green
        exit 0
    }
    
    Write-ColorOutput "Found $($alerts.Count) secret scanning alert(s)." -Color Green
    Write-Output ""
    
    # Format findings for work items
    $workItems = Format-FindingsForWorkItems -Alerts $alerts -Owner $RepositoryOwner -Repo $RepositoryName
    
    # Output results based on format
    switch ($OutputFormat) {
        'JSON' {
            $workItems | ConvertTo-Json -Depth 10 | Write-Output
        }
        'CSV' {
            $workItems | Export-Csv -Path "SecretScanningFindings_$($RepositoryOwner)_$($RepositoryName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
            Write-ColorOutput "Results exported to CSV file." -Color Green
        }
        'Console' {
            Write-ColorOutput "Secret Scanning Findings - Ready for Work Item Creation:" -Color Cyan
            Write-ColorOutput "=========================================================" -Color Cyan
            Write-Output ""
            
            foreach ($item in $workItems) {
                Write-ColorOutput "Alert #$($item.AlertNumber): $($item.Title)" -Color Yellow
                Write-Output "  Repository: $($item.Repository)"
                Write-Output "  File: $($item.FileName)$(if ($item.LineNumber) { ":$($item.LineNumber)" })"
                Write-Output "  Secret Type: $($item.SecretType)"
                Write-Output "  State: $($item.State)"
                Write-Output "  Priority: $($item.Priority)"
                Write-Output "  GitHub URL: $($item.GitHubAlertUrl)"
                Write-Output "  Created: $($item.CreatedAt)"
                Write-Output "  Tags: $($item.Tags -join ', ')"
                Write-Output ""
                Write-ColorOutput "  Work Item Description:" -Color Cyan
                Write-Output "  $($item.Description)"
                Write-Output "  File affected: $($item.FileName)"
                Write-Output "  Direct link to finding: $($item.GitHubAlertUrl)"
                Write-Output ""
                Write-Output "  Recommended Actions:"
                Write-Output "  1. Review the secret in file: $($item.FileName)"
                Write-Output "  2. Remove or rotate the exposed secret"
                Write-Output "  3. Update any systems using this secret"
                Write-Output "  4. Mark the alert as resolved in GitHub"
                Write-Output ""
                Write-ColorOutput "  " + "─" * 80 -Color Gray
                Write-Output ""
            }
            
            Write-ColorOutput "Summary:" -Color Cyan
            Write-Output "Total findings: $($workItems.Count)"
            Write-Output "High priority: $(($workItems | Where-Object Priority -eq 'High').Count)"
            Write-Output "Medium priority: $(($workItems | Where-Object Priority -eq 'Medium').Count)"
            Write-Output "Low priority: $(($workItems | Where-Object Priority -eq 'Low').Count)"
        }
    }
    
    Write-Output ""
    Write-ColorOutput "Script completed successfully." -Color Green
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}