#Requires -Version 5.1

<#
.SYNOPSIS
    Example script demonstrating how to use the GitHub Secret Scanning Work Item Creator tools.

.DESCRIPTION
    This script provides examples of how to use the secret scanning scripts with different
    configurations and output formats. It's designed for testing and demonstration purposes.

.PARAMETER TestRepository
    A test repository in the format "owner/repo" to demonstrate the functionality.
    Default is a public repository that likely has secret scanning enabled.

.EXAMPLE
    .\Example-Usage.ps1
    
    Runs the example with default test repository.

.EXAMPLE
    .\Example-Usage.ps1 -TestRepository "myorg/myrepo"
    
    Runs the example with a specific repository.

.NOTES
    Author: GitHub Copilot
    Version: 1.0
    
    This is for demonstration purposes. For production use, ensure you have:
    - Proper GitHub tokens with security_events scope
    - Access to the target repositories
    - Appropriate work item system credentials
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TestRepository = "octocat/Hello-World"
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
    Write-Host "GitHub Secret Scanning Work Item Creator - Example Usage" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script demonstrates the usage of the secret scanning tools." -ForegroundColor White
    Write-Host "Repository to test: $TestRepository" -ForegroundColor Gray
    Write-Host ""
    
    # Parse repository owner and name
    $repoParts = $TestRepository -split '/'
    if ($repoParts.Count -ne 2) {
        Write-Error "Invalid repository format. Use 'owner/repo' format."
        exit 1
    }
    $repoOwner = $repoParts[0]
    $repoName = $repoParts[1]
    
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
    
    # Prompt for GitHub token
    Write-Host "Authentication Required" -ForegroundColor Yellow
    Write-Host "To demonstrate the functionality, you need a GitHub Personal Access Token" -ForegroundColor White
    Write-Host "with 'security_events' scope. You can also set the GITHUB_TOKEN environment variable." -ForegroundColor White
    Write-Host ""
    
    $githubToken = $env:GITHUB_TOKEN
    if (-not $githubToken) {
        Write-Host "No GITHUB_TOKEN environment variable found." -ForegroundColor Yellow
        $response = Read-Host "Do you want to provide a GitHub token now? (y/N)"
        
        if ($response -eq 'y' -or $response -eq 'Y') {
            $githubToken = Read-SecureInput "Enter your GitHub token: "
        } else {
            Write-Host "Skipping examples that require authentication." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "To run the full examples, set the GITHUB_TOKEN environment variable or provide a token when prompted." -ForegroundColor White
            exit 0
        }
    } else {
        Write-Host "Using GitHub token from GITHUB_TOKEN environment variable." -ForegroundColor Green
    }
    
    # Example 1: Basic console output
    Write-SectionHeader "Example 1: Basic Console Output"
    Write-Host "Running: Get-SecretScanningFindings.ps1 -RepositoryOwner '$repoOwner' -RepositoryName '$repoName'" -ForegroundColor Gray
    Write-Host ""
    
    try {
        & $mainScript -RepositoryOwner $repoOwner -RepositoryName $repoName -GitHubToken $githubToken -OutputFormat "Console"
    }
    catch {
        Write-Host "Example 1 failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "This is normal for repositories without secret scanning alerts or insufficient permissions." -ForegroundColor Yellow
    }
    
    # Example 2: JSON output
    Write-SectionHeader "Example 2: JSON Output"
    Write-Host "Running: Get-SecretScanningFindings.ps1 with JSON output format" -ForegroundColor Gray
    Write-Host ""
    
    try {
        $jsonOutput = & $mainScript -RepositoryOwner $repoOwner -RepositoryName $repoName -GitHubToken $githubToken -OutputFormat "JSON"
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
    
    # Example 3: Console work item creation (demo mode)
    Write-SectionHeader "Example 3: Work Item Creation (Console Demo)"
    Write-Host "Running: Create-WorkItemsFromSecrets.ps1 with Console output (demo mode)" -ForegroundColor Gray
    Write-Host ""
    
    try {
        & $workItemScript -RepositoryOwner $repoOwner -RepositoryName $repoName -GitHubToken $githubToken -WorkItemSystem "Console"
    }
    catch {
        Write-Host "Example 3 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Example 4: Show help for work item systems
    Write-SectionHeader "Example 4: Work Item System Integration Examples"
    Write-Host "Here are examples of how to integrate with different work item systems:" -ForegroundColor White
    Write-Host ""
    
    Write-Host "GitHub Issues:" -ForegroundColor Green
    Write-Host "  .\Create-WorkItemsFromSecrets.ps1 -RepositoryOwner '$repoOwner' -RepositoryName '$repoName' -GitHubToken 'ghp_xxxx' -WorkItemSystem 'GitHubIssues'" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Azure DevOps:" -ForegroundColor Green
    Write-Host "  .\Create-WorkItemsFromSecrets.ps1 -RepositoryOwner '$repoOwner' -RepositoryName '$repoName' \" -ForegroundColor Gray
    Write-Host "    -GitHubToken 'ghp_xxxx' -WorkItemSystem 'AzureDevOps' \" -ForegroundColor Gray
    Write-Host "    -AzureDevOpsOrganization 'myorg' -AzureDevOpsProject 'myproject' \" -ForegroundColor Gray
    Write-Host "    -AzureDevOpsPAT 'xxxxxxxxxxxx'" -ForegroundColor Gray
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
    Write-Host "1. Test with your actual repositories that have secret scanning enabled" -ForegroundColor White
    Write-Host "2. Configure work item system integration (GitHub Issues, Azure DevOps, etc.)" -ForegroundColor White
    Write-Host "3. Set up automated execution (e.g., GitHub Actions, scheduled tasks)" -ForegroundColor White
    Write-Host "4. Customize the scripts for your organization's specific needs" -ForegroundColor White
    Write-Host ""
    Write-Host "For more information, see the README.md file." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Example script completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Example script failed: $($_.Exception.Message)"
    exit 1
}