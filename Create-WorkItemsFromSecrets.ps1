#Requires -Version 5.1

<#
.SYNOPSIS
    Creates Azure DevOps work items from Azure DevOps Advanced Security secret scanning findings.

.DESCRIPTION
    This script extends the Get-SecretScanningFindings.ps1 script by creating work items
    in Azure DevOps for each secret scanning finding discovered by Advanced Security.

.PARAMETER Organization
    The Azure DevOps organization name.

.PARAMETER Project
    The Azure DevOps project name.

.PARAMETER Repository
    The repository name within the project (optional - if not specified, processes all repos in project).

.PARAMETER PersonalAccessToken
    Personal Access Token for Azure DevOps API authentication with Advanced Security and Work Items permissions.

.PARAMETER WorkItemType
    The type of work item to create. Default is 'Bug'. Can be 'Bug', 'Task', 'User Story', etc.

.PARAMETER AssignTo
    Email address or display name of the person to assign the work items to (optional).

.PARAMETER AreaPath
    Area path for the work items (optional - uses project default if not specified).

.PARAMETER IterationPath
    Iteration path for the work items (optional - uses project default if not specified).

.EXAMPLE
    .\Create-WorkItemsFromSecrets.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "xxx"

.EXAMPLE
    .\Create-WorkItemsFromSecrets.ps1 -Organization "myorg" -Project "myproject" -Repository "myrepo" -PersonalAccessToken "xxx" -WorkItemType "Task" -AssignTo "user@company.com"

.NOTES
    Author: GitHub Copilot
    Version: 2.0
    This script depends on Get-SecretScanningFindings.ps1
    Requires Azure DevOps PAT with 'Advanced Security' read and 'Work Items' read/write permissions.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Organization,
    
    [Parameter(Mandatory = $true)]
    [string]$Project,
    
    [Parameter(Mandatory = $false)]
    [string]$Repository,
    
    [Parameter(Mandatory = $true)]
    [string]$PersonalAccessToken,
    
    [Parameter(Mandatory = $false)]
    [string]$WorkItemType = 'Bug',
    
    [Parameter(Mandatory = $false)]
    [string]$AssignTo,
    
    [Parameter(Mandatory = $false)]
    [string]$AreaPath,
    
    [Parameter(Mandatory = $false)]
    [string]$IterationPath
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

# Function to create Azure DevOps Work Item
function New-AzureDevOpsWorkItem {
    param(
        [object]$WorkItem,
        [string]$Organization,
        [string]$Project,
        [string]$PAT,
        [string]$WorkItemType = 'Bug',
        [string]$AssignTo,
        [string]$AreaPath,
        [string]$IterationPath
    )
    
    $encodedPAT = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$PAT"))
    $headers = @{
        'Authorization' = "Basic $encodedPAT"
        'Content-Type' = 'application/json-patch+json'
    }
    
    $description = @"
<h2>Security Alert: Secret Detected by Advanced Security</h2>
<p><strong>Organization/Project:</strong> $Organization/$Project</p>
<p><strong>Repository:</strong> $($WorkItem.Repository)</p>
<p><strong>File:</strong> <code>$($WorkItem.FileName)</code>$(if ($WorkItem.LineNumber) { " (Line $($WorkItem.LineNumber))" })</p>
<p><strong>Secret Type:</strong> $($WorkItem.SecretType)</p>
<p><strong>Severity:</strong> $($WorkItem.Severity)</p>
<p><strong>Priority:</strong> $($WorkItem.Priority)</p>

<h3>Description</h3>
<p>$($WorkItem.Description)</p>

<h3>Direct Link to Finding</h3>
<p><a href="$($WorkItem.AlertUrl)">View Alert in Azure DevOps</a></p>

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
<li><strong>Alert ID:</strong> $($WorkItem.AlertId)</li>
<li><strong>Alert Number:</strong> #$($WorkItem.AlertNumber)</li>
<li><strong>Current State:</strong> $($WorkItem.State)</li>
<li><strong>Created:</strong> $($WorkItem.CreatedAt)</li>
$(if ($WorkItem.UpdatedAt) { "<li><strong>Updated:</strong> $($WorkItem.UpdatedAt)</li>" })
</ul>

<p><em>This work item was automatically created from Azure DevOps Advanced Security secret scanning findings.</em></p>
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
        }
    )
    
    # Add priority field
    $workItemFields += @{
        op = "add"
        path = "/fields/Microsoft.VSTS.Common.Priority"
        value = switch ($WorkItem.Priority) {
            'High' { 1 }
            'Medium' { 2 }
            'Low' { 3 }
            default { 2 }
        }
    }
    
    # Add severity field if available
    if ($WorkItem.Severity) {
        $workItemFields += @{
            op = "add"
            path = "/fields/Microsoft.VSTS.Common.Severity"
            value = switch ($WorkItem.Severity) {
                'critical' { "1 - Critical" }
                'high' { "2 - High" }
                'medium' { "3 - Medium" }
                'low' { "4 - Low" }
                default { "3 - Medium" }
            }
        }
    }
    
    # Add assignment if specified
    if ($AssignTo) {
        $workItemFields += @{
            op = "add"
            path = "/fields/System.AssignedTo"
            value = $AssignTo
        }
    }
    
    # Add area path if specified
    if ($AreaPath) {
        $workItemFields += @{
            op = "add"
            path = "/fields/System.AreaPath"
            value = $AreaPath
        }
    }
    
    # Add iteration path if specified
    if ($IterationPath) {
        $workItemFields += @{
            op = "add"
            path = "/fields/System.IterationPath"
            value = $IterationPath
        }
    }
    
    $body = $workItemFields | ConvertTo-Json -Depth 10
    
    try {
        $uri = "https://dev.azure.com/$Organization/$Project/_apis/wit/workitems/`$$WorkItemType?api-version=7.0"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $body
        return $response
    }
    catch {
        Write-Error "Failed to create Azure DevOps work item: $($_.Exception.Message)"
        return $null
    }
}

# Main execution
try {
    Write-Host "Azure DevOps Advanced Security Work Item Creator" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Get secret scanning findings using the main script functions
    Write-Host "Retrieving secret scanning findings from Azure DevOps Advanced Security..." -ForegroundColor Yellow
    $alerts = Get-AzureDevOpsSecretScanningAlerts -Organization $Organization -Project $Project -Repository $Repository -Token $PersonalAccessToken -IncludeResolved $false
    
    if ($alerts.Count -eq 0) {
        $targetDescription = if ($Repository) { "$Organization/$Project/$Repository" } else { "$Organization/$Project (all repositories)" }
        Write-Host "No secret scanning alerts found for $targetDescription. No work items to create." -ForegroundColor Green
        exit 0
    }
    
    $workItems = Format-FindingsForWorkItems -Alerts $alerts -Organization $Organization -Project $Project
    
    Write-Host "Found $($workItems.Count) finding(s). Creating work items..." -ForegroundColor Green
    Write-Host ""
    
    $successCount = 0
    $failureCount = 0
    
    foreach ($workItem in $workItems) {
        Write-Host "Processing Alert #$($workItem.AlertNumber): $($workItem.SecretType)" -ForegroundColor Yellow
        
        $result = New-AzureDevOpsWorkItem -WorkItem $workItem -Organization $Organization -Project $Project -PAT $PersonalAccessToken -WorkItemType $WorkItemType -AssignTo $AssignTo -AreaPath $AreaPath -IterationPath $IterationPath
        
        if ($result) {
            Write-Host "✓ Created Azure DevOps Work Item #$($result.id): $($result._links.html.href)" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "✗ Failed to create work item for Alert #$($workItem.AlertNumber)" -ForegroundColor Red
            $failureCount++
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
    Write-Host "Organization/Project: $Organization/$Project" -ForegroundColor Gray
    Write-Host "Work item type: $WorkItemType" -ForegroundColor Gray
    if ($AssignTo) {
        Write-Host "Assigned to: $AssignTo" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Script completed." -ForegroundColor Green
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}