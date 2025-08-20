#Requires -Version 5.1

<#
.SYNOPSIS
    Retrieves secret scanning findings from Azure DevOps Advanced Security and prepares them for work item creation.

.DESCRIPTION
    This script fetches secret scanning alerts from Azure DevOps Advanced Security (GHAzDo) for a specified 
    project/repository and formats them for logging as work items. The output includes file names, secret types, 
    and direct links to the findings for easy remediation.

.PARAMETER Organization
    The Azure DevOps organization name.

.PARAMETER Project
    The Azure DevOps project name.

.PARAMETER Repository
    The repository name within the project (optional - if not specified, gets alerts for all repos in project).

.PARAMETER PersonalAccessToken
    Personal Access Token for Azure DevOps API authentication. Requires 'Advanced Security' read permissions.
    If not provided, the script will look for the AZURE_DEVOPS_PAT environment variable.

.PARAMETER OutputFormat
    The format for output. Valid values are 'Console', 'JSON', 'CSV'.
    Default is 'Console'.

.PARAMETER IncludeResolved
    Include resolved/dismissed secret scanning alerts in the results.
    Default is false (only active alerts).

.EXAMPLE
    .\Get-SecretScanningFindings.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "xxx"
    
    Retrieves active secret scanning findings for all repositories in myorg/myproject.

.EXAMPLE
    .\Get-SecretScanningFindings.ps1 -Organization "myorg" -Project "myproject" -Repository "myrepo" -OutputFormat "JSON"
    
    Retrieves findings for specific repository and outputs them in JSON format.

.NOTES
    Author: GitHub Copilot
    Version: 2.0
    Requires Azure DevOps Personal Access Token with Advanced Security read permissions.
    Designed for Azure DevOps Advanced Security (GitHub Advanced Security for Azure DevOps).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Organization,
    
    [Parameter(Mandatory = $true)]
    [string]$Project,
    
    [Parameter(Mandatory = $false)]
    [string]$Repository,
    
    [Parameter(Mandatory = $false)]
    [string]$PersonalAccessToken,
    
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

# Function to validate Azure DevOps token
function Test-AzureDevOpsToken {
    param([string]$Token, [string]$Organization)
    
    try {
        $encodedPAT = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$Token"))
        $headers = @{
            'Authorization' = "Basic $encodedPAT"
            'Accept' = 'application/json'
        }
        
        $response = Invoke-RestMethod -Uri "https://dev.azure.com/$Organization/_apis/projects?api-version=7.0" -Headers $headers -Method Get
        return $true
    }
    catch {
        return $false
    }
}

# Function to get secret scanning alerts from Azure DevOps Advanced Security
function Get-AzureDevOpsSecretScanningAlerts {
    param(
        [string]$Organization,
        [string]$Project,
        [string]$Repository,
        [string]$Token,
        [bool]$IncludeResolved
    )
    
    $encodedPAT = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$Token"))
    $headers = @{
        'Authorization' = "Basic $encodedPAT"
        'Accept' = 'application/json'
    }
    
    # Build the URI for Advanced Security alerts
    $baseUri = "https://dev.azure.com/$Organization/$Project/_apis/advancedsecurity/alerts"
    $allAlerts = @()
    $page = 1
    
    do {
        try {
            $queryParams = @{
                'api-version' = '7.1-preview.1'
                '$top' = 100
                '$skip' = ($page - 1) * 100
                'alertType' = 'secret'
            }
            
            if ($Repository) {
                $queryParams['repository'] = $Repository
            }
            
            if (-not $IncludeResolved) {
                $queryParams['state'] = 'active'
            }
            
            $queryString = ($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '&'
            $pageUri = "$baseUri?$queryString"
            
            Write-Verbose "Fetching page $page from: $pageUri"
            $response = Invoke-RestMethod -Uri $pageUri -Headers $headers -Method Get
            
            if ($response.value -and $response.value.Count -gt 0) {
                $allAlerts += $response.value
                $page++
                
                # Check if we have more pages
                if ($response.value.Count -lt 100) {
                    break
                }
            } else {
                break
            }
        }
        catch {
            if ($_.Exception.Response.StatusCode -eq 404) {
                Write-Warning "Project not found or Advanced Security not enabled for $Organization/$Project"
                return @()
            }
            elseif ($_.Exception.Response.StatusCode -eq 403) {
                Write-Error "Access denied. Ensure your Azure DevOps PAT has 'Advanced Security' read permissions."
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
        [string]$Organization,
        [string]$Project
    )
    
    $workItems = @()
    
    foreach ($alert in $Alerts) {
        $workItem = [PSCustomObject]@{
            AlertId = $alert.alertId
            AlertNumber = $alert.alertNumber
            Title = "Secret Found: $($alert.title)"
            Description = "Advanced Security secret scanning has detected a $($alert.title) in the repository."
            SecretType = $alert.title
            State = $alert.state
            FileName = if ($alert.instances -and $alert.instances.Count -gt 0) { 
                $alert.instances[0].location.path 
            } else { 
                "Location not available" 
            }
            LineNumber = if ($alert.instances -and $alert.instances.Count -gt 0) { 
                $alert.instances[0].location.startLine 
            } else { 
                $null 
            }
            Repository = $alert.repository.name
            AlertUrl = $alert._links.html.href
            CreatedAt = $alert.introducedDate
            UpdatedAt = $alert.fixedDate
            Severity = $alert.severity
            Priority = switch ($alert.severity) {
                'critical' { 'High' }
                'high' { 'High' }
                'medium' { 'Medium' }
                'low' { 'Low' }
                default { 'Medium' }
            }
            Tags = @("security", "secret-scanning", "advanced-security")
        }
        $workItems += $workItem
    }
    
    return $workItems
}

# Main execution
try {
    Write-ColorOutput "Azure DevOps Advanced Security Secret Scanning Findings Tool" -Color Cyan
    Write-ColorOutput "===========================================================" -Color Cyan
    Write-Output ""
    
    # Validate Azure DevOps token
    if (-not $PersonalAccessToken) {
        $PersonalAccessToken = $env:AZURE_DEVOPS_PAT
        if (-not $PersonalAccessToken) {
            Write-Error "Azure DevOps PAT not provided. Use -PersonalAccessToken parameter or set AZURE_DEVOPS_PAT environment variable."
            exit 1
        }
    }
    
    Write-ColorOutput "Validating Azure DevOps PAT..." -Color Yellow
    if (-not (Test-AzureDevOpsToken -Token $PersonalAccessToken -Organization $Organization)) {
        Write-Error "Invalid Azure DevOps PAT or insufficient permissions. Ensure PAT has 'Advanced Security' read permissions."
        exit 1
    }
    Write-ColorOutput "Azure DevOps PAT validated successfully." -Color Green
    Write-Output ""
    
    # Fetch secret scanning alerts
    $targetDescription = if ($Repository) { "$Organization/$Project/$Repository" } else { "$Organization/$Project (all repositories)" }
    Write-ColorOutput "Fetching secret scanning alerts for $targetDescription..." -Color Yellow
    $alerts = Get-AzureDevOpsSecretScanningAlerts -Organization $Organization -Project $Project -Repository $Repository -Token $PersonalAccessToken -IncludeResolved $IncludeResolved.IsPresent
    
    if ($alerts.Count -eq 0) {
        Write-ColorOutput "No secret scanning alerts found for $targetDescription" -Color Green
        exit 0
    }
    
    Write-ColorOutput "Found $($alerts.Count) secret scanning alert(s)." -Color Green
    Write-Output ""
    
    # Format findings for work items
    $workItems = Format-FindingsForWorkItems -Alerts $alerts -Organization $Organization -Project $Project
    
    # Output results based on format
    switch ($OutputFormat) {
        'JSON' {
            $workItems | ConvertTo-Json -Depth 10 | Write-Output
        }
        'CSV' {
            $csvFileName = "SecretScanningFindings_$($Organization)_$($Project)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            $workItems | Export-Csv -Path $csvFileName -NoTypeInformation
            Write-ColorOutput "Results exported to CSV file: $csvFileName" -Color Green
        }
        'Console' {
            Write-ColorOutput "Azure DevOps Secret Scanning Findings - Ready for Work Item Creation:" -Color Cyan
            Write-ColorOutput "=====================================================================" -Color Cyan
            Write-Output ""
            
            foreach ($item in $workItems) {
                Write-ColorOutput "Alert #$($item.AlertNumber): $($item.Title)" -Color Yellow
                Write-Output "  Organization/Project: $Organization/$Project"
                Write-Output "  Repository: $($item.Repository)"
                Write-Output "  File: $($item.FileName)$(if ($item.LineNumber) { ":$($item.LineNumber)" })"
                Write-Output "  Secret Type: $($item.SecretType)"
                Write-Output "  State: $($item.State)"
                Write-Output "  Severity: $($item.Severity)"
                Write-Output "  Priority: $($item.Priority)"
                Write-Output "  Alert URL: $($item.AlertUrl)"
                Write-Output "  Created: $($item.CreatedAt)"
                Write-Output "  Tags: $($item.Tags -join ', ')"
                Write-Output ""
                Write-ColorOutput "  Work Item Description:" -Color Cyan
                Write-Output "  $($item.Description)"
                Write-Output "  File affected: $($item.FileName)"
                Write-Output "  Direct link to finding: $($item.AlertUrl)"
                Write-Output ""
                Write-Output "  Recommended Actions:"
                Write-Output "  1. Review the secret in file: $($item.FileName)"
                Write-Output "  2. Remove or rotate the exposed secret"
                Write-Output "  3. Update any systems using this secret"
                Write-Output "  4. Mark the alert as resolved in Azure DevOps"
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