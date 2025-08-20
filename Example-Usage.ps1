#Requires -Version 5.1

<#
.SYNOPSIS
    Example script demonstrating how to use the Azure DevOps Advanced Security Work Item Creator tools.

.DESCRIPTION
    This script provides examples of how to use the secret scanning scripts with different
    configurations and output formats. It's designed for testing and demonstration purposes.

.PARAMETER TestOrganization
    The Azure DevOps organization name for testing.

.PARAMETER TestProject
    The Azure DevOps project name for testing.

.PARAMETER TestRepository
    A specific repository name to test (optional - will test all repos in project if not specified).

.EXAMPLE
    .\Example-Usage.ps1 -TestOrganization "myorg" -TestProject "myproject"
    
    Runs the example with specified organization and project.

.EXAMPLE
    .\Example-Usage.ps1 -TestOrganization "myorg" -TestProject "myproject" -TestRepository "myrepo"
    
    Runs the example with a specific repository.

.NOTES
    Author: GitHub Copilot
    Version: 2.0
    
    This is for demonstration purposes. For production use, ensure you have:
    - Azure DevOps PAT with Advanced Security read and Work Items read/write permissions
    - Access to the target organization and project
    - Azure DevOps Advanced Security enabled
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TestOrganization,
    
    [Parameter(Mandatory = $true)]
    [string]$TestProject,
    
    [Parameter(Mandatory = $false)]
    [string]$TestRepository
)

# Function to display section headers
function Write-SectionHeader {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Yellow
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
}

# Function to safely prompt for sensitive input
function Read-SecureInput {
    param([string]$Prompt)
    
    Write-Host $Prompt -NoNewline -ForegroundColor Yellow
    $secureString = Read-Host -AsSecureString
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

# Main execution
try {
    Write-Host "Azure DevOps Advanced Security Work Item Creator - Example Usage" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script demonstrates the usage of the Azure DevOps secret scanning tools." -ForegroundColor White
    Write-Host "Organization: $TestOrganization" -ForegroundColor Gray
    Write-Host "Project: $TestProject" -ForegroundColor Gray
    if ($TestRepository) {
        Write-Host "Repository: $TestRepository" -ForegroundColor Gray
    } else {
        Write-Host "Repository: All repositories in project" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Check if scripts exist
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $mainScript = Join-Path $scriptDir "Get-SecretScanningFindings.ps1"
    $workItemScript = Join-Path $scriptDir "Create-WorkItemsFromSecrets.ps1"
    
    if (-not (Test-Path $mainScript)) {
        Write-Error "Get-SecretScanningFindings.ps1 not found in $scriptDir"
        exit 1
    }
    
    if (-not (Test-Path $workItemScript)) {
        Write-Error "Create-WorkItemsFromSecrets.ps1 not found in $scriptDir"
        exit 1
    }
    
    # Prompt for Azure DevOps PAT
    Write-Host "Authentication Required" -ForegroundColor Yellow
    Write-Host "To demonstrate the functionality, you need an Azure DevOps Personal Access Token" -ForegroundColor White
    Write-Host "with 'Advanced Security' read and 'Work Items' read/write permissions." -ForegroundColor White
    Write-Host "You can also set the AZURE_DEVOPS_PAT environment variable." -ForegroundColor White
    Write-Host ""
    
    $azurePAT = $env:AZURE_DEVOPS_PAT
    if (-not $azurePAT) {
        Write-Host "No AZURE_DEVOPS_PAT environment variable found." -ForegroundColor Yellow
        $response = Read-Host "Do you want to provide an Azure DevOps PAT now? (y/N)"
        
        if ($response -eq 'y' -or $response -eq 'Y') {
            $azurePAT = Read-SecureInput "Enter your Azure DevOps PAT: "
        } else {
            Write-Host "Skipping examples that require authentication." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "To run the full examples, set the AZURE_DEVOPS_PAT environment variable or provide a token when prompted." -ForegroundColor White
            exit 0
        }
    } else {
        Write-Host "Using Azure DevOps PAT from AZURE_DEVOPS_PAT environment variable." -ForegroundColor Green
    }
    
    # Build common parameters
    $commonParams = @{
        Organization = $TestOrganization
        Project = $TestProject
        PersonalAccessToken = $azurePAT
    }
    
    if ($TestRepository) {
        $commonParams.Repository = $TestRepository
    }
    
    # Example 1: Basic console output
    Write-SectionHeader "Example 1: Basic Console Output"
    $paramString = "Organization: $TestOrganization, Project: $TestProject"
    if ($TestRepository) { $paramString += ", Repository: $TestRepository" }
    Write-Host "Running: Get-SecretScanningFindings.ps1 with $paramString" -ForegroundColor Gray
    Write-Host ""
    
    try {
        & $mainScript @commonParams -OutputFormat "Console"
    }
    catch {
        Write-Host "Example 1 failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "This is normal for projects without secret scanning alerts or insufficient permissions." -ForegroundColor Yellow
    }
    
    # Example 2: JSON output
    Write-SectionHeader "Example 2: JSON Output"
    Write-Host "Running: Get-SecretScanningFindings.ps1 with JSON output format" -ForegroundColor Gray
    Write-Host ""
    
    try {
        $jsonOutput = & $mainScript @commonParams -OutputFormat "JSON"
        if ($jsonOutput) {
            Write-Host "JSON Output:" -ForegroundColor Green
            Write-Host $jsonOutput -ForegroundColor White
        } else {
            Write-Host "No JSON output generated (likely no secret scanning alerts found)." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Example 2 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Example 3: Work item creation
    Write-SectionHeader "Example 3: Azure DevOps Work Item Creation"
    Write-Host "Running: Create-WorkItemsFromSecrets.ps1 to create actual work items" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "⚠️  Warning: This will create actual work items in your Azure DevOps project!" -ForegroundColor Yellow
    $response = Read-Host "Do you want to proceed with creating work items? (y/N)"
    
    if ($response -eq 'y' -or $response -eq 'Y') {
        try {
            & $workItemScript @commonParams -WorkItemType "Bug"
        }
        catch {
            Write-Host "Example 3 failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Skipped work item creation as requested." -ForegroundColor Yellow
    }
    
    # Example 4: Different work item configurations
    Write-SectionHeader "Example 4: Work Item Configuration Examples"
    Write-Host "Here are examples of different work item configurations:" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Create Tasks with assignment:" -ForegroundColor Green
    Write-Host "  .\Create-WorkItemsFromSecrets.ps1 -Organization '$TestOrganization' -Project '$TestProject' \" -ForegroundColor Gray
    Write-Host "    -PersonalAccessToken 'xxx' -WorkItemType 'Task' -AssignTo 'user@company.com'" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Create Bugs with area and iteration paths:" -ForegroundColor Green
    Write-Host "  .\Create-WorkItemsFromSecrets.ps1 -Organization '$TestOrganization' -Project '$TestProject' \" -ForegroundColor Gray
    Write-Host "    -PersonalAccessToken 'xxx' -AreaPath 'Security\SecretScanning' \" -ForegroundColor Gray
    Write-Host "    -IterationPath '$TestProject\Sprint 1'" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Export to CSV for analysis:" -ForegroundColor Green
    Write-Host "  .\Get-SecretScanningFindings.ps1 -Organization '$TestOrganization' -Project '$TestProject' \" -ForegroundColor Gray
    Write-Host "    -PersonalAccessToken 'xxx' -OutputFormat 'CSV'" -ForegroundColor Gray
    Write-Host ""
    
    # Show script help
    Write-SectionHeader "Script Help and Documentation"
    Write-Host "For detailed help on any script, use Get-Help:" -ForegroundColor White
    Write-Host ""
    Write-Host "Get-Help .\Get-SecretScanningFindings.ps1 -Full" -ForegroundColor Gray
    Write-Host "Get-Help .\Create-WorkItemsFromSecrets.ps1 -Full" -ForegroundColor Gray
    Write-Host ""
    
    # Summary
    Write-SectionHeader "Summary and Next Steps"
    Write-Host "✅ Scripts are installed and functional" -ForegroundColor Green
    Write-Host "✅ Basic examples completed" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Test with your actual Azure DevOps projects that have Advanced Security enabled" -ForegroundColor White
    Write-Host "2. Configure automated execution (e.g., Azure DevOps pipelines, scheduled tasks)" -ForegroundColor White
    Write-Host "3. Customize the scripts for your organization's specific needs" -ForegroundColor White
    Write-Host "4. Set up proper area paths and iteration assignments for your security team" -ForegroundColor White
    Write-Host ""
    Write-Host "For more information, see the README.md file." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Example script completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Example script failed: $($_.Exception.Message)"
    exit 1
}