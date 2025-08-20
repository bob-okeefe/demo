#Requires -Version 5.1

<#
.SYNOPSIS
    Creates work items from GitHub secret scanning findings in various work item systems.

.DESCRIPTION
    This script extends the Get-SecretScanningFindings.ps1 script by actually creating work items
    in supported work item systems like Azure DevOps, GitHub Issues, or Jira.

.PARAMETER RepositoryOwner
    The GitHub username or organization that owns the repository.

.PARAMETER RepositoryName
    The name of the GitHub repository to scan for secret findings.

.PARAMETER GitHubToken
    Personal Access Token for GitHub API authentication.

.PARAMETER WorkItemSystem
    The work item system to use. Valid values: 'GitHubIssues', 'AzureDevOps', 'Console'.

.PARAMETER GitHubIssuesToken
    GitHub token for creating issues (can be same as GitHubToken).

.PARAMETER AzureDevOpsOrganization
    Azure DevOps organization name (required for AzureDevOps system).

.PARAMETER AzureDevOpsProject
    Azure DevOps project name (required for AzureDevOps system).

.PARAMETER AzureDevOpsPAT
    Azure DevOps Personal Access Token (required for AzureDevOps system).

.EXAMPLE
    .\Create-WorkItemsFromSecrets.ps1 -RepositoryOwner "myorg" -RepositoryName "myrepo" -GitHubToken "ghp_xxxx" -WorkItemSystem "GitHubIssues"

.EXAMPLE
    .\Create-WorkItemsFromSecrets.ps1 -RepositoryOwner "myorg" -RepositoryName "myrepo" -GitHubToken "ghp_xxxx" -WorkItemSystem "AzureDevOps" -AzureDevOpsOrganization "myorg" -AzureDevOpsProject "myproject" -AzureDevOpsPAT "xxx"

.NOTES
    Author: GitHub Copilot
    Version: 1.0
    This script depends on Get-SecretScanningFindings.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryOwner,
    
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName,
    
    [Parameter(Mandatory = $true)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet('GitHubIssues', 'AzureDevOps', 'Console')]
    [string]$WorkItemSystem,
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubIssuesToken,
    
    [Parameter(Mandatory = $false)]
    [string]$AzureDevOpsOrganization,
    
    [Parameter(Mandatory = $false)]
    [string]$AzureDevOpsProject,
    
    [Parameter(Mandatory = $false)]
    [string]$AzureDevOpsPAT
)

# Import the main script functions (assuming it's in the same directory)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = Join-Path $scriptDir "Get-SecretScanningFindings.ps1"

if (-not (Test-Path $mainScript)) {
    Write-Error "Required script Get-SecretScanningFindings.ps1 not found in $scriptDir"
    exit 1
}

# Dot source the main script to access its functions
. $mainScript

# Function to create GitHub Issues
function New-GitHubIssue {
    param(
        [object]$WorkItem,
        [string]$Owner,
        [string]$Repo,
        [string]$Token
    )
    
    $headers = @{
        'Authorization' = "token $Token"
        'Accept' = 'application/vnd.github.v3+json'
        'Content-Type' = 'application/json'
    }
    
    $body = @{
        title = $WorkItem.Title
        body = @"
## Security Alert: Secret Detected

**Repository:** $($WorkItem.Repository)
**File:** ``$($WorkItem.FileName)``$(if ($WorkItem.LineNumber) { " (Line $($WorkItem.LineNumber))" })
**Secret Type:** $($WorkItem.SecretType)
**Priority:** $($WorkItem.Priority)

### Description
$($WorkItem.Description)

### Direct Link to Finding
🔗 [View in GitHub Security Tab]($($WorkItem.GitHubAlertUrl))

### Remediation Steps
1. **Immediate Action Required:** Remove or rotate the exposed secret
2. Review the affected file: ``$($WorkItem.FileName)``
3. Update any systems or applications using this secret
4. Verify no other instances of this secret exist in the codebase
5. Mark the security alert as resolved once remediated

### Additional Information
- **Created:** $($WorkItem.CreatedAt)
- **Alert Number:** #$($WorkItem.AlertNumber)
- **Current State:** $($WorkItem.State)

---
*This issue was automatically created from GitHub Secret Scanning findings.*
"@
        labels = $WorkItem.Tags + @("security", "automated")
    } | ConvertTo-Json -Depth 10
    
    try {
        $uri = "https://api.github.com/repos/$Owner/$Repo/issues"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $body
        return $response
    }
    catch {
        Write-Error "Failed to create GitHub issue: $($_.Exception.Message)"
        return $null
    }
}

# Function to create Azure DevOps Work Item
function New-AzureDevOpsWorkItem {
    param(
        [object]$WorkItem,
        [string]$Organization,
        [string]$Project,
        [string]$PAT
    )
    
    $encodedPAT = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$PAT"))
    $headers = @{
        'Authorization' = "Basic $encodedPAT"
        'Content-Type' = 'application/json-patch+json'
    }
    
    $description = @"
<h2>Security Alert: Secret Detected</h2>
<p><strong>Repository:</strong> $($WorkItem.Repository)</p>
<p><strong>File:</strong> <code>$($WorkItem.FileName)</code>$(if ($WorkItem.LineNumber) { " (Line $($WorkItem.LineNumber))" })</p>
<p><strong>Secret Type:</strong> $($WorkItem.SecretType)</p>
<p><strong>Priority:</strong> $($WorkItem.Priority)</p>

<h3>Description</h3>
<p>$($WorkItem.Description)</p>

<h3>Direct Link to Finding</h3>
<p><a href="$($WorkItem.GitHubAlertUrl)">View in GitHub Security Tab</a></p>

<h3>Remediation Steps</h3>
<ol>
<li><strong>Immediate Action Required:</strong> Remove or rotate the exposed secret</li>
<li>Review the affected file: <code>$($WorkItem.FileName)</code></li>
<li>Update any systems or applications using this secret</li>
<li>Verify no other instances of this secret exist in the codebase</li>
<li>Mark the security alert as resolved once remediated</li>
</ol>

<h3>Additional Information</h3>
<ul>
<li><strong>Created:</strong> $($WorkItem.CreatedAt)</li>
<li><strong>Alert Number:</strong> #$($WorkItem.AlertNumber)</li>
<li><strong>Current State:</strong> $($WorkItem.State)</li>
</ul>

<p><em>This work item was automatically created from GitHub Secret Scanning findings.</em></p>
"@

    $workItemFields = @(
        @{
            op = "add"
            path = "/fields/System.Title"
            value = $WorkItem.Title
        },
        @{
            op = "add"
            path = "/fields/System.Description"
            value = $description
        },
        @{
            op = "add"
            path = "/fields/System.Tags"
            value = ($WorkItem.Tags -join "; ")
        },
        @{
            op = "add"
            path = "/fields/Microsoft.VSTS.Common.Priority"
            value = switch ($WorkItem.Priority) {
                'High' { 1 }
                'Medium' { 2 }
                'Low' { 3 }
                default { 2 }
            }
        }
    )
    
    $body = $workItemFields | ConvertTo-Json -Depth 10
    
    try {
        $uri = "https://dev.azure.com/$Organization/$Project/_apis/wit/workitems/`$Bug?api-version=7.0"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $body
        return $response
    }
    catch {
        Write-Error "Failed to create Azure DevOps work item: $($_.Exception.Message)"
        return $null
    }
}

# Function to output work items to console (for testing/demo)
function Write-WorkItemToConsole {
    param([object]$WorkItem)
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "WORK ITEM CREATED" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Title: $($WorkItem.Title)" -ForegroundColor White
    Write-Host "Repository: $($WorkItem.Repository)" -ForegroundColor Gray
    Write-Host "File: $($WorkItem.FileName)" -ForegroundColor Gray
    Write-Host "Secret Type: $($WorkItem.SecretType)" -ForegroundColor Gray
    Write-Host "Priority: $($WorkItem.Priority)" -ForegroundColor $(
        switch ($WorkItem.Priority) {
            'High' { 'Red' }
            'Medium' { 'Yellow' }
            'Low' { 'Green' }
            default { 'White' }
        }
    )
    Write-Host "GitHub Alert URL: $($WorkItem.GitHubAlertUrl)" -ForegroundColor Blue
    Write-Host "Tags: $($WorkItem.Tags -join ', ')" -ForegroundColor Magenta
    Write-Host ""
}

# Main execution
try {
    Write-Host "GitHub Secret Scanning Work Item Creator" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Validate parameters based on work item system
    switch ($WorkItemSystem) {
        'GitHubIssues' {
            if (-not $GitHubIssuesToken) {
                $GitHubIssuesToken = $GitHubToken
            }
        }
        'AzureDevOps' {
            if (-not $AzureDevOpsOrganization -or -not $AzureDevOpsProject -or -not $AzureDevOpsPAT) {
                Write-Error "Azure DevOps requires -AzureDevOpsOrganization, -AzureDevOpsProject, and -AzureDevOpsPAT parameters"
                exit 1
            }
        }
    }
    
    # Get secret scanning findings
    Write-Host "Retrieving secret scanning findings..." -ForegroundColor Yellow
    $alerts = Get-SecretScanningAlerts -Owner $RepositoryOwner -Repo $RepositoryName -Token $GitHubToken -IncludeResolved $false
    
    if ($alerts.Count -eq 0) {
        Write-Host "No secret scanning alerts found. No work items to create." -ForegroundColor Green
        exit 0
    }
    
    $workItems = Format-FindingsForWorkItems -Alerts $alerts -Owner $RepositoryOwner -Repo $RepositoryName
    
    Write-Host "Found $($workItems.Count) finding(s). Creating work items..." -ForegroundColor Green
    Write-Host ""
    
    $successCount = 0
    $failureCount = 0
    
    foreach ($workItem in $workItems) {
        Write-Host "Processing Alert #$($workItem.AlertNumber): $($workItem.SecretType)" -ForegroundColor Yellow
        
        $result = $null
        switch ($WorkItemSystem) {
            'GitHubIssues' {
                $result = New-GitHubIssue -WorkItem $workItem -Owner $RepositoryOwner -Repo $RepositoryName -Token $GitHubIssuesToken
                if ($result) {
                    Write-Host "✓ Created GitHub Issue #$($result.number): $($result.html_url)" -ForegroundColor Green
                    $successCount++
                } else {
                    $failureCount++
                }
            }
            'AzureDevOps' {
                $result = New-AzureDevOpsWorkItem -WorkItem $workItem -Organization $AzureDevOpsOrganization -Project $AzureDevOpsProject -PAT $AzureDevOpsPAT
                if ($result) {
                    Write-Host "✓ Created Azure DevOps Work Item #$($result.id): $($result._links.html.href)" -ForegroundColor Green
                    $successCount++
                } else {
                    $failureCount++
                }
            }
            'Console' {
                Write-WorkItemToConsole -WorkItem $workItem
                $successCount++
            }
        }
        Write-Host ""
    }
    
    # Summary
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "SUMMARY" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Total findings processed: $($workItems.Count)" -ForegroundColor White
    Write-Host "Work items created successfully: $successCount" -ForegroundColor Green
    if ($failureCount -gt 0) {
        Write-Host "Failed to create: $failureCount" -ForegroundColor Red
    }
    Write-Host "Work item system: $WorkItemSystem" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Script completed." -ForegroundColor Green
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}